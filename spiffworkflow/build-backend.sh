#!/bin/bash
set -euo pipefail

# Robust error handling
FAILURE_REASON=""
cleanup_on_error() {
  local ec=$?
  if [ $ec -ne 0 ]; then
    echo "\n============================================================" >&2
    echo "BUILD SCRIPT FAILED (exit code $ec)" >&2
    if [ -n "$FAILURE_REASON" ]; then
      echo "Reason: $FAILURE_REASON" >&2
    fi
    echo "Working directory: $(pwd)" >&2
    echo "PACKAGE_PATH: ${PACKAGE_PATH:-<unset>}" >&2
    if [ -n "${BACKEND_DIR:-}" ] && [ -d "${BACKEND_DIR:-}" ]; then
      echo "Listing backend dir for diagnostics:" >&2
      ls -al "${BACKEND_DIR}" || true
    fi
    echo "============================================================\n" >&2
  fi
  exit $ec
}
trap cleanup_on_error ERR

fatal() { FAILURE_REASON="$1"; echo "ERROR: $1" >&2; exit 1; }

# This script prepares the content for the SpiffWorkflow backend application
# It is used only for buildpack-based deployment (backend_deployment_method = "buildpack")
# 
# It handles:
# - Downloading the source code from GitHub at the specified reference (backend_gitref)
# - Copying process models from the local directory (backend_process_models_path)
# - Generating requirements.txt using uv
# - Adding files and configuration necessary for the Python buildpack
#
# USAGE EXAMPLES:
#
#   ./build-backend.sh <path_root> <backend_gitref> <backend_process_models_path> <backend_python_version> <package_path>
#
# Example:
#   ./build-backend.sh /Users/you/project v1.0.0 /Users/you/project/process_models python-3.12.x /Users/you/project/dist/spiffarena-backend.zip
#
#   - <path_root>:                The root directory of your project (e.g., /Users/you/project)
#   - <backend_gitref>:           The git tag, branch, or commit to fetch from the upstream repo (e.g., v1.0.0)
#   - <backend_process_models_path>: Path to your local process_models directory (e.g., /Users/you/project/process_models)
#   - <backend_python_version>:   Python version string for buildpack (e.g., python-3.12.x)
#   - <package_path>:             Output path for the generated zip file (e.g., /Users/you/project/dist/spiffarena-backend.zip)
#
# This script is typically invoked by Terraform, but you can run it manually for debugging or local packaging.


# Cross-platform sed function that works on both BSD (macOS) and GNU (Linux) sed
safe_sed() {
  # Pattern is $1, file is $2
  # Create a temporary file to test sed behavior
  local temp_file
  temp_file=$(mktemp)
  echo "test" > "$temp_file"
  
  # Try BSD-style sed (macOS) first with empty string
  if sed -i '' 's/test/TEST/' "$temp_file" 2>/dev/null && grep -q "TEST" "$temp_file"; then
    # BSD sed detected, use it with empty string
    sed -i '' "$1" "$2"
  else
    # GNU sed or other variant, try without empty string
    sed -i "$1" "$2"
  fi
  
  # Clean up temp file
  rm -f "$temp_file"
}

# Required parameters
if [ $# -lt 6 ]; then
  fatal "Usage: $0 <path_root> <backend_gitref> <backend_process_models_path> <backend_python_version> <package_path> <backend_scripts_path>"
fi

# Parse arguments
PATH_ROOT="$1"
# Second argument now may be a composite like: github.com/sartography/spiff-arena?ref=v1.1.2
# or it may still be a simple ref (legacy usage). We derive GIT_URL and GIT_REF.
RAW_GIT_SPEC="$2"
PROCESS_MODELS_PATH="$3"
PYTHON_VERSION="$4"
PACKAGE_PATH="$5"
BACKEND_SCRIPTS_PATH="$6"

echo "Using scripts path: ${BACKEND_SCRIPTS_PATH}"

if [ ! -d "${BACKEND_SCRIPTS_PATH}" ]; then
  fatal "backend_scripts_path does not exist or is not a directory: ${BACKEND_SCRIPTS_PATH}"
fi

# Derive GIT_URL and GIT_REF from RAW_GIT_SPEC
# Accept inputs with or without scheme (http/https). Default to https.
if [[ "$RAW_GIT_SPEC" == *"?ref="* ]]; then
  # Split on ?ref=
  BASE_PART="${RAW_GIT_SPEC%%\?ref=*}"
  REF_PART="${RAW_GIT_SPEC##*?ref=}"  # everything after last ?ref=
else
  # Legacy: argument itself is the ref; use default repo
  BASE_PART="github.com/sartography/spiff-arena"
  REF_PART="$RAW_GIT_SPEC"
fi

# Normalize scheme
if [[ "$BASE_PART" =~ ^https?:// ]]; then
  GIT_URL="${BASE_PART%%\?*}"
else
  GIT_URL="https://${BASE_PART%%\?*}"
fi

# Strip any trailing slash
GIT_URL="${GIT_URL%/}"

GIT_REF="$REF_PART"

[[ -z "$GIT_REF" ]] && fatal "Could not determine GIT_REF from backend_gitref argument: $RAW_GIT_SPEC"

echo "Build trigger..."
echo "Build script starting with parameters:"
echo "  PATH_ROOT: $PATH_ROOT"
echo "  backend_gitref (raw): $RAW_GIT_SPEC"
echo "  GIT_URL: $GIT_URL"
echo "  GIT_REF: $GIT_REF"
echo "  PROCESS_MODELS_PATH: $PROCESS_MODELS_PATH"
echo "  PYTHON_VERSION: $PYTHON_VERSION"
echo "  PACKAGE_PATH: $PACKAGE_PATH"
echo "  BACKEND_SCRIPTS_PATH: ${BACKEND_SCRIPTS_PATH}"
echo "  Current working directory: $(pwd)"

# Remove any existing zip file to ensure we create a fresh one
if [ -f "$PACKAGE_PATH" ]; then
  echo "Removing existing zip file: $PACKAGE_PATH"
  rm -f "$PACKAGE_PATH"
fi

# Validate inputs
echo "Validating inputs..."

# Check if process models directory exists and is accessible
echo "Checking if process models directory exists:"
if [ ! -d "$PROCESS_MODELS_PATH" ]; then
  fatal "Process models path does not exist: $PROCESS_MODELS_PATH (abs: $(readlink -f "$PROCESS_MODELS_PATH" 2>/dev/null || echo "Path resolution failed"))"
fi

! ls -la "$PROCESS_MODELS_PATH" >/dev/null 2>&1 && fatal "Process models path not accessible: $PROCESS_MODELS_PATH"

echo "✓ Process models directory validated: $PROCESS_MODELS_PATH"

# Validate other required tools
echo "Checking required tools..."

# Check for git (required, no auto-install - should be in all CI/CD environments)
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: Required tool 'git' is not installed or not in PATH"
  exit 1
fi
echo "✓ Found git"

# Check for zip and auto-install if missing
if ! command -v zip >/dev/null 2>&1; then
  echo "⚠ zip not found, attempting to install..."
  
  # Detect OS and install zip accordingly
  if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    echo "Installing zip via apt..."
    apt-get update && apt-get install -y zip
  elif [ -f /etc/redhat-release ]; then
    # RHEL/CentOS/Fedora
    echo "Installing zip via yum/dnf..."
    if command -v dnf >/dev/null 2>&1; then
      dnf install -y zip
    else
      yum install -y zip
    fi
  elif [ "$(uname)" = "Darwin" ]; then
    # macOS
    echo "Installing zip via Homebrew..."
    if command -v brew >/dev/null 2>&1; then
      brew install zip
    else
      echo "ERROR: Homebrew not found. Please install zip manually: brew install zip"
      exit 1
    fi
  else
    echo "ERROR: Unable to determine package manager for auto-installing zip"
    echo "Please install zip manually for your system"
    exit 1
  fi
  
  # Verify installation succeeded
  if ! command -v zip >/dev/null 2>&1; then
    echo "ERROR: Failed to install zip automatically"
    echo "Please install zip manually for your system"
    exit 1
  fi
  
  echo "✓ zip installed successfully"
else
  echo "✓ Found zip"
fi

# Check for uv and auto-install if missing
if ! command -v uv >/dev/null 2>&1; then
  echo "⚠ UV not found, attempting to install..."
  
    # Fall back to curl installation
    echo "Installing UV via curl..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    
    # Add cargo bin to PATH
    if [ -d "$HOME/.cargo/bin" ]; then
      export PATH="$HOME/.cargo/bin:$PATH"
    fi
  
  # source install path
  source $HOME/.local/bin/env  
  
  # Verify installation succeeded
  if ! command -v uv >/dev/null 2>&1; then
    echo "ERROR: Failed to install UV automatically"
    echo "Please install UV manually using one of these methods:"
    echo "  1. pip install uv"
    echo "  2. curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "  3. Visit https://docs.astral.sh/uv/getting-started/installation/"
    exit 1
  fi
  
  echo "✓ UV installed successfully"
else
  echo "✓ Found uv"
fi

# Set up standard directories
DIST_DIR="${PATH_ROOT}/dist/spiffworkflow"
DOWNLOAD_DIR="${DIST_DIR}/temp-spiff-arena"
BACKEND_DIR="${DIST_DIR}/backend"
PROCESS_MODELS_DEST="${BACKEND_DIR}/process_models"

# Include git_ref in the zip filename to identify the version
SAFE_GIT_REF=$(echo "${GIT_REF}" | tr '/' '_')
DOWNLOAD_ZIP="${DOWNLOAD_DIR}/spiff-arena-${SAFE_GIT_REF}.zip"

echo "Preparing SpiffWorkflow backend content..."
echo "Project root: ${PATH_ROOT}"
echo "Distribution directory: ${DIST_DIR}"
echo "Backend directory: ${BACKEND_DIR}"
echo "Package path: ${PACKAGE_PATH}"
echo "Expected package directory: $(dirname "$PACKAGE_PATH")"

# Verify the directories match expectations
if [ "$(dirname "$PACKAGE_PATH")" != "$DIST_DIR" ]; then
  echo "WARNING: Package path directory doesn't match DIST_DIR"
  echo "  DIST_DIR: $DIST_DIR" 
  echo "  Package directory: $(dirname "$PACKAGE_PATH")"
fi
echo "Git reference: ${GIT_REF}"
echo "Process models path: ${PROCESS_MODELS_PATH}"
echo "Python version: ${PYTHON_VERSION}"

# Create the dist directory if it doesn't exist
mkdir -p "${DIST_DIR}"
mkdir -p "${DOWNLOAD_DIR}"
mkdir -p "${BACKEND_DIR}"

echo "Created directories: ${DIST_DIR} and ${DOWNLOAD_DIR}"

# Cleanup any existing backend directory from previous runs
if [ -d "${BACKEND_DIR}" ]; then
  echo "Removing existing backend directory..."
  rm -rf "${BACKEND_DIR}"
fi

# Download the source code directly as a ZIP file if it doesn't exist
if [ -f "${DOWNLOAD_ZIP}" ]; then
  echo "Using existing download for reference: ${GIT_REF} from ${DOWNLOAD_ZIP##*/}"
else
  echo "Downloading source code (trying tag, branch, generic) for ref: ${GIT_REF}..."
  TMP_ZIP="${DOWNLOAD_ZIP}.tmp"
  rm -f "$TMP_ZIP"
  set +e
  curl -fsSL -o "$TMP_ZIP" "${GIT_URL}/archive/refs/tags/${GIT_REF}.zip" || \
  curl -fsSL -o "$TMP_ZIP" "${GIT_URL}/archive/refs/heads/${GIT_REF}.zip" || \
  curl -fsSL -o "$TMP_ZIP" "${GIT_URL}/archive/${GIT_REF}.zip"
  CURL_RC=$?
  set -e
  if [ $CURL_RC -ne 0 ]; then
    echo "ERROR: Could not download a valid archive for ref '${GIT_REF}' from ${GIT_URL}" >&2
    echo "Tried URLs:" >&2
    echo "  ${GIT_URL}/archive/refs/tags/${GIT_REF}.zip" >&2
    echo "  ${GIT_URL}/archive/refs/heads/${GIT_REF}.zip" >&2
    echo "  ${GIT_URL}/archive/${GIT_REF}.zip" >&2
    rm -f "$TMP_ZIP" || true
    fatal "Could not download a valid archive for ref '${GIT_REF}' from ${GIT_URL}"
  fi
  # Ensure non-empty & valid zip
  if [ ! -s "$TMP_ZIP" ]; then
    rm -f "$TMP_ZIP"
    fatal "Downloaded archive is empty (ref: ${GIT_REF})"
  fi
  if ! unzip -t "$TMP_ZIP" >/dev/null 2>&1; then
    rm -f "$TMP_ZIP"
    fatal "Downloaded file is not a valid zip (ref: ${GIT_REF})"
  fi
  mv "$TMP_ZIP" "$DOWNLOAD_ZIP"
  echo "Source code downloaded successfully: ${DOWNLOAD_ZIP##*/}"
fi

# Clean up previous extraction if it exists
if [ -d "${DOWNLOAD_DIR}/extract" ]; then
  echo "Removing previous extraction..."
  rm -rf "${DOWNLOAD_DIR}/extract"
fi

# Extract the ZIP file
echo "Extracting source code..."
mkdir -p "${DOWNLOAD_DIR}/extract"
unzip -q "${DOWNLOAD_ZIP}" -d "${DOWNLOAD_DIR}/extract"

# Find the extracted directory (it might have a suffix based on the reference)
EXTRACT_DIR=$(find "${DOWNLOAD_DIR}/extract" -type d -name "spiff-arena*" | head -n 1)
[[ -z "${EXTRACT_DIR}" ]] && fatal "Could not find extracted spiff-arena directory"

echo "Source code extracted to: ${EXTRACT_DIR}"

# Move the backend code to the final backend directory
echo "Moving backend code to destination directory..."
if [ -d "${EXTRACT_DIR}/spiffworkflow-backend" ]; then
  BACKEND_SRC="${EXTRACT_DIR}/spiffworkflow-backend"
elif [ -d "${EXTRACT_DIR}/backend" ]; then
  BACKEND_SRC="${EXTRACT_DIR}/backend"
else
  echo "Directory structure:" >&2
  find "${EXTRACT_DIR}" -type d -maxdepth 2 >&2 || true
  fatal "Could not find backend directory in the extracted source code"
fi

echo "Backend source directory: ${BACKEND_SRC}"

# Create the backend directory and copy files
mkdir -p "${BACKEND_DIR}"
echo "Copying files from ${BACKEND_SRC} to ${BACKEND_DIR}..."
cp -R "${BACKEND_SRC}/." "${BACKEND_DIR}/"

# Copy process models to the backend directory
echo "Copying process models to backend directory..."
mkdir -p "${PROCESS_MODELS_DEST}"
cp -R "${PROCESS_MODELS_PATH}"/* "${PROCESS_MODELS_DEST}/"
echo "Process models copied to: ${PROCESS_MODELS_DEST}"

# SpiffWorkflow does not want .png files in the process models directory
echo "Removing any .bpmn.png files from process models directory..."
find "${PROCESS_MODELS_DEST}" -type f -name "*.bpmn.png" -delete

# ----------------------------------------------------------------------------
# Include content of custom scripts directory (eg init process + profile hooks)
# Note these are copied relative to the root of the application!
# ----------------------------------------------------------------------------
if [ -n "${BACKEND_SCRIPTS_PATH}" ] && [ -d "${BACKEND_SCRIPTS_PATH}" ]; then
  echo "Including custom scripts from ${BACKEND_SCRIPTS_PATH} ..."
  cp -R "${BACKEND_SCRIPTS_PATH}/." "${BACKEND_DIR}/"
  if [ -f "${BACKEND_DIR}/bin/init_process.py" ]; then
    chmod +x "${BACKEND_DIR}/bin/init_process.py"
    echo "✓ Added init_process.py"
  fi
  if ls "${BACKEND_DIR}/.profile.d"/*.sh >/dev/null 2>&1; then
    echo "Found profile hook scripts:"
    ls -1 "${BACKEND_DIR}/.profile.d"/*.sh || true
  else
    echo "No .profile.d hook scripts found in scripts directory (optional)."
  fi
else
  echo "Scripts path not present or not a directory: ${BACKEND_SCRIPTS_PATH} (skipping script vendoring)"
fi

# Generate requirements.txt from uv.lock
echo "Generating requirements.txt from uv files..."
if [ -f "${BACKEND_DIR}/uv.lock" ] && [ -f "${BACKEND_DIR}/pyproject.toml" ]; then
  # Ensure uv is installed
  if ! command -v uv &> /dev/null; then
    echo "ERROR: uv is required but not installed"
    echo "Please install uv using one of the methods documented here:"
    echo "https://docs.astral.sh/uv/getting-started/installation/"
    exit 1
  fi
  
  # Use uv to export requirements
  echo "Using uv to generate requirements.txt..."
  (cd "${BACKEND_DIR}" && uv pip compile --output-file requirements.txt pyproject.toml > /dev/null 2>&1) || fatal "uv pip compile failed"

  # Verify requirements.txt was created
  [ ! -f "${BACKEND_DIR}/requirements.txt" ] && fatal "requirements.txt was not created by uv export"

  echo "✓ Generated requirements.txt with $(wc -l < "${BACKEND_DIR}/requirements.txt") dependencies"
  
  # Display the first few lines for reference
  # echo "First 10 lines of requirements.txt:"
  # head -n 10 "${BACKEND_DIR}/requirements.txt"
else
  fatal "Missing uv.lock or pyproject.toml required for dependency generation"
fi

# Add a Procfile for the Python buildpack, which requires that one exist
# However, we're specifying the start commands in the cloudfoundry_app processes attributes
if [ ! -f "${BACKEND_DIR}/Procfile" ]; then
  echo "Creating Procfile for Python buildpack..."
  cat > "${BACKEND_DIR}/Procfile" << EOF
web: specify-the-command-in-the-processes-attribute
EOF
  if [ ! -f "${BACKEND_DIR}/Procfile" ]; then
    echo "ERROR: Failed to create Procfile"
    exit 1
  fi
  echo "✓ Created Procfile"
else
  echo "✓ Procfile already exists"
fi

# Make sure boot_server_in_docker is executable
[ -f "${BACKEND_DIR}/bin/boot_server_in_docker" ] || fatal "boot_server_in_docker not found at ${BACKEND_DIR}/bin/boot_server_in_docker"
chmod +x "${BACKEND_DIR}/bin/boot_server_in_docker"
echo "✓ Made boot_server_in_docker executable"

# Don't use poetry run or uv run inside the container environment; the 
# buildpack lifecycle is responsible for setting up the environment
# before the app even starts.
if [ -d "${BACKEND_DIR}/bin" ]; then
  for binfile in "${BACKEND_DIR}/bin/"*; do
    if [ -f "$binfile" ]; then
      safe_sed 's/poetry run //g' "$binfile"
      safe_sed 's/uv run //g' "$binfile"
    fi
  done
fi

# Ensure bash scripts in bin/ only start .py scripts with python3
# For example, 
#   exec ./bin/start_blocking_apscheduler.py
# should be
#   exec python3 ./bin/start_blocking_apscheduler.py
for binfile in "${BACKEND_DIR}/bin/"*; do
  if [ -f "$binfile" ] && head -1 "$binfile" | grep -qE '^#!.*bash'; then
    # Replace 'exec ./bin/*.py' or 'exec ./bin/*.py args' with 'exec python3 ./bin/*.py args'
    safe_sed 's|exec  *\(\./bin/[^ ]*\.py\)|exec python3 \1|g' "$binfile"
  fi
done

# Add Python buildpack runtime.txt if it doesn't exist
if [ ! -f "${BACKEND_DIR}/runtime.txt" ]; then
  echo "Creating runtime.txt for Python buildpack with version: ${PYTHON_VERSION}..."
  echo "${PYTHON_VERSION}" > "${BACKEND_DIR}/runtime.txt"
  [ -f "${BACKEND_DIR}/runtime.txt" ] || fatal "Failed to create runtime.txt"
  echo "✓ Created runtime.txt"
else
  echo "✓ runtime.txt already exists"
fi

echo "Creating .profile file with environment setup..."
cat > "${BACKEND_DIR}/.profile" << 'EOF'
#!/usr/bin/env bash
export PYTHONPATH="/home/vcap/app:/home/vcap/app/src:/home/vcap/deps/0/python:/home/vcap/deps/0"

# Get the postgres URI from the service binding. (SQL Alchemy insists on "postgresql://".🙄)
export SPIFFWORKFLOW_BACKEND_DATABASE_URI=$( echo ${VCAP_SERVICES:-} | jq -r '.["aws-rds"][].credentials.uri' | sed -e s/postgres/postgresql/ )

# Check if the backend queue service is set and is a type that we support (it supplies a .credentials.uri that's usable as is)
if [ -n "${QUEUE_SERVICE_NAME:-}" ]; then
  QUEUE_URI=$(echo "${VCAP_SERVICES}" | jq -r --arg name "$QUEUE_SERVICE_NAME" '
    to_entries[]
    | select(.value[0].instance_name == $name)
    | .value[0].credentials.uri // empty
  ')
  # Force TLS if a non-TLS Redis URI is provided (convert redis:// -> rediss://)
  if [ -n "$QUEUE_URI" ] && [ "${QUEUE_URI#redis://}" != "$QUEUE_URI" ]; then
    QUEUE_URI="rediss://${QUEUE_URI#redis://}"
  fi
  # If we have a rediss URL but no ssl_cert_reqs parameter, append one so Celery's Redis backend
  # doesn't raise: "A rediss:// URL must have parameter ssl_cert_reqs ..."
  # Allow override via QUEUE_SSL_CERT_REQS env var (values: CERT_REQUIRED, CERT_OPTIONAL, CERT_NONE).
  QUEUE_SSL_CERT_REQS_VALUE="${QUEUE_SSL_CERT_REQS:-CERT_OPTIONAL}"
  if [ -n "$QUEUE_URI" ] && [ "${QUEUE_URI#rediss://}" != "$QUEUE_URI" ] && ! echo "$QUEUE_URI" | grep -qi 'ssl_cert_reqs='; then
    if echo "$QUEUE_URI" | grep -q '?'; then
      QUEUE_URI="${QUEUE_URI}&ssl_cert_reqs=${QUEUE_SSL_CERT_REQS_VALUE}"
    else
      QUEUE_URI="${QUEUE_URI}?ssl_cert_reqs=${QUEUE_SSL_CERT_REQS_VALUE}"
    fi
  fi
  if [ -n "$QUEUE_URI" ]; then
    # Enable Celery for background processing
    export SPIFFWORKFLOW_BACKEND_CELERY_ENABLED=true
    export SPIFFWORKFLOW_BACKEND_CELERY_BROKER_URL="$QUEUE_URI"
    export SPIFFWORKFLOW_BACKEND_CELERY_RESULT_BACKEND="$QUEUE_URI"

    # Enable the metadata backfill feature
    SPIFFWORKFLOW_BACKEND_PROCESS_INSTANCE_METADATA_BACKFILL_ENABLED=true
  else 
    echo "WARNING: QUEUE_SERVICE_NAME is set but no matching service found in VCAP_SERVICES; skipping configuration"
  fi
fi
EOF
chmod +x "${BACKEND_DIR}/.profile"

[ -f "${BACKEND_DIR}/.profile" ] || fatal "Failed to create .profile"
echo "✓ Created .profile"

# Final validation - ensure all critical files were created
echo "Performing final validation of build artifacts..."
missing_files=""
for required_file in "Procfile" "requirements.txt" "bin/boot_server_in_docker" ".profile" "runtime.txt"; do
  if [ ! -f "${BACKEND_DIR}/$required_file" ]; then
    echo "ERROR: Required file $required_file is missing from ${BACKEND_DIR}" >&2
    missing_files="$missing_files $required_file"
  else
    echo "✓ Found $required_file"
  fi
done

# Optional (non-fatal) diagnostics: presence of init process assets
if [ -f "${BACKEND_DIR}/bin/init_process.py" ]; then
  echo "✓ Found bin/init_process.py (init process support)"
else
  echo "(Info) bin/init_process.py not present; init process bootstrap disabled unless provided elsewhere" >&2
fi
if ls "${BACKEND_DIR}/bin/.profile.d"/10-init-process.sh >/dev/null 2>&1; then
  echo "✓ Found bin/.profile.d/10-init-process.sh (profile hook)"
else
  echo "(Info) profile hook 10-init-process.sh not present; no init run via .profile" >&2
fi

if [ -n "$missing_files" ]; then
  echo "Contents of backend directory:" >&2
  ls -la "${BACKEND_DIR}/" || true
  fatal "Missing required files:$missing_files"
fi

# Validate that the backend directory has content
[ -z "$(ls -A ${BACKEND_DIR} 2>/dev/null)" ] && fatal "Backend directory ${BACKEND_DIR} is empty"

echo "✓ All required files created successfully"

# Create the zip file at the expected path
echo "Creating deployment zip file: $PACKAGE_PATH"

# Verify the backend directory exists and has content
[ -d "$BACKEND_DIR" ] || fatal "Backend directory does not exist: $BACKEND_DIR"


echo "Checking for required files in backend directory:"
for required_file in "Procfile" "requirements.txt" "bin/boot_server_in_docker" ".profile" "runtime.txt"; do
  if [ -f "$BACKEND_DIR/$required_file" ]; then
    echo "✓ Found $required_file in backend directory"
  else
    echo "✗ Missing $required_file in backend directory"
  fi
done

# Create the output directory if it doesn't exist
echo "Creating output directory: $(dirname "$PACKAGE_PATH")"
mkdir -p "$(dirname "$PACKAGE_PATH")"

# Create the zip file
# Ensure the zip file is created outside the backend directory to avoid recursion and path issues
[[ "$PACKAGE_PATH" == "$BACKEND_DIR"* ]] && fatal "PACKAGE_PATH ($PACKAGE_PATH) must not be inside BACKEND_DIR ($BACKEND_DIR)"

# shellcheck disable=SC2164
PACKAGE_BASENAME="$(basename "$PACKAGE_PATH")"
echo "Zipping backend contents to parent directory as $PACKAGE_BASENAME ..."
(cd "$BACKEND_DIR" && zip -rq "../$PACKAGE_BASENAME" .)

# Verify the zip file was created successfully
[ -f "$PACKAGE_PATH" ] || fatal "Zip file $PACKAGE_PATH was not created"

# Check zip file integrity
zip -T "$PACKAGE_PATH" >/dev/null 2>&1 || fatal "Created zip file $PACKAGE_PATH failed integrity test"

echo "Successfully created $PACKAGE_PATH with size: $(du -h "$PACKAGE_PATH" | cut -f1)"

# Verify the zip contains the critical files
# Use unzip -Z1 to get normalized file paths (no sed)
critical_files=("Procfile" "requirements.txt" "bin/boot_server_in_docker" ".profile" "runtime.txt")
missing_count=0

zip_file_list=$(unzip -Z1 "$PACKAGE_PATH")

for required_file in "${critical_files[@]}"; do
  echo "Checking for: $required_file"
  # Show the grep command and result
  match=$(echo "$zip_file_list" | grep -E "/$required_file$|^$required_file$")
  if [ -n "$match" ]; then
    echo "✓ Found: $required_file as: $match"
  else
    echo "✗ Missing: $required_file (no match for /$required_file$ or ^$required_file$)" >&2
    ((missing_count++))
  fi
done

if [ $missing_count -gt 0 ]; then
  rm -f "$PACKAGE_PATH" || true
  fatal "$missing_count critical files missing from zip"
fi

echo "✓ Zip file validation completed successfully"
echo "Build preparation complete!"
