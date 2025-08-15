#!/bin/bash
set -euo pipefail

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
  local temp_file=$(mktemp)
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
if [ $# -lt 5 ]; then
  echo "Usage: $0 <path_root> <backend_gitref> <backend_process_models_path> <backend_python_version> <package_path>"
  exit 1
fi

# Parse arguments
PATH_ROOT="$1"
GIT_REF="$2"
PROCESS_MODELS_PATH="$3"
PYTHON_VERSION="$4"
PACKAGE_PATH="$5"

echo "Build script starting with parameters:"
echo "  PATH_ROOT: $PATH_ROOT"
echo "  GIT_REF: $GIT_REF"
echo "  PROCESS_MODELS_PATH: $PROCESS_MODELS_PATH"
echo "  PYTHON_VERSION: $PYTHON_VERSION"
echo "  PACKAGE_PATH: $PACKAGE_PATH"
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
  echo "ERROR: Process models path does not exist: $PROCESS_MODELS_PATH"
  echo "Expected path: $PROCESS_MODELS_PATH"
  echo "Absolute path: $(readlink -f "$PROCESS_MODELS_PATH" 2>/dev/null || echo "Path resolution failed")"
  exit 1
fi

if ! ls -la "$PROCESS_MODELS_PATH" >/dev/null 2>&1; then
  echo "ERROR: Process models path is not accessible: $PROCESS_MODELS_PATH"
  exit 1
fi

echo "✓ Process models directory validated: $PROCESS_MODELS_PATH"

# Validate other required tools
echo "Checking required tools..."
for tool in git uv zip; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: Required tool '$tool' is not installed or not in PATH"
    exit 1
  fi
  echo "✓ Found $tool"
done

# Set up standard directories
DIST_DIR="${PATH_ROOT}/dist"
DOWNLOAD_DIR="${DIST_DIR}/temp-spiff-arena"
BACKEND_DIR="${DIST_DIR}/backend"
PROCESS_MODELS_DEST="${BACKEND_DIR}/process_models"
GITHUB_URL="https://github.com/sartography/spiff-arena"
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

# Download the source code directly as a ZIP file from GitHub if it doesn't exist
if [ -f "${DOWNLOAD_ZIP}" ]; then
  echo "Using existing download for reference: ${GIT_REF} from ${DOWNLOAD_ZIP##*/}"
else
  echo "Downloading source code from GitHub for reference: ${GIT_REF}..."
  if curl -L -o "${DOWNLOAD_ZIP}" "${GITHUB_URL}/archive/refs/tags/${GIT_REF}.zip" || \
     curl -L -o "${DOWNLOAD_ZIP}" "${GITHUB_URL}/archive/refs/heads/${GIT_REF}.zip" || \
     curl -L -o "${DOWNLOAD_ZIP}" "${GITHUB_URL}/archive/${GIT_REF}.zip"; then
    echo "Source code downloaded successfully"
  else
    echo "ERROR: Failed to download source code for reference: ${GIT_REF}"
    echo "Please ensure the reference exists on GitHub"
    exit 1
  fi
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
if [ -z "${EXTRACT_DIR}" ]; then
  echo "ERROR: Could not find extracted spiff-arena directory"
  exit 1
fi

echo "Source code extracted to: ${EXTRACT_DIR}"

# Move the backend code to the final backend directory
echo "Moving backend code to destination directory..."
if [ -d "${EXTRACT_DIR}/spiffworkflow-backend" ]; then
  BACKEND_SRC="${EXTRACT_DIR}/spiffworkflow-backend"
elif [ -d "${EXTRACT_DIR}/backend" ]; then
  BACKEND_SRC="${EXTRACT_DIR}/backend"
else
  echo "ERROR: Could not find backend directory in the extracted source code"
  echo "Directory structure:"
  find "${EXTRACT_DIR}" -type d -maxdepth 2
  exit 1
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
  if ! (cd "${BACKEND_DIR}" && uv pip compile --output-file requirements.txt pyproject.toml); then
    echo "ERROR: uv export failed"
    exit 1
  fi

  # Verify requirements.txt was created
  if [ ! -f "${BACKEND_DIR}/requirements.txt" ]; then
    echo "ERROR: requirements.txt was not created by uv export"
    exit 1
  fi

  echo "✓ Generated requirements.txt with $(wc -l < "${BACKEND_DIR}/requirements.txt") dependencies"
  
  # Display the first few lines for reference
  # echo "First 10 lines of requirements.txt:"
  # head -n 10 "${BACKEND_DIR}/requirements.txt"
else
  echo "ERROR: Could not find uv.lock or pyproject.toml"
  echo "These files are required for generating dependencies"
  exit 1
fi

# Add a Procfile for the Python buildpack if it doesn't exist
if [ ! -f "${BACKEND_DIR}/Procfile" ]; then
  echo "Creating Procfile for Python buildpack..."
  cat > "${BACKEND_DIR}/Procfile" << EOF
web: ./bin/boot_server_in_docker
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
if [ -f "${BACKEND_DIR}/bin/boot_server_in_docker" ]; then
  chmod +x "${BACKEND_DIR}/bin/boot_server_in_docker"
  echo "✓ Made boot_server_in_docker executable"
else
  echo "ERROR: boot_server_in_docker not found at ${BACKEND_DIR}/bin/boot_server_in_docker"
  exit 1
fi

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

# Add Python buildpack runtime.txt if it doesn't exist
if [ ! -f "${BACKEND_DIR}/runtime.txt" ]; then
  echo "Creating runtime.txt for Python buildpack with version: ${PYTHON_VERSION}..."
  echo "${PYTHON_VERSION}" > "${BACKEND_DIR}/runtime.txt"
  if [ ! -f "${BACKEND_DIR}/runtime.txt" ]; then
    echo "ERROR: Failed to create runtime.txt"
    exit 1
  fi
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

# Flatten all S3 backend_secret credentials into a key-value file
tmpfile=$(mktemp)
echo "${VCAP_SERVICES:-}" | jq -r '.s3[] | select(.tags[]? == "backend_secret") | . as $service | .credentials | to_entries[] | "\($service.name)_\(.key)=\(.value)"' > "$tmpfile"
if [ -s "$tmpfile" ] && [ "$(cat "$tmpfile")" != "{}" ]; then
  # Set secrets based on the temporary file; service name -> secret name
  ./bin/run_local_python_script bin/save_to_secrets_from_file "$tmpfile"
fi
rm -f "$tmpfile"
EOF
chmod +x "${BACKEND_DIR}/.profile"

if [ ! -f "${BACKEND_DIR}/.profile" ]; then
  echo "ERROR: Failed to create .profile"
  exit 1
fi
echo "✓ Created .profile"

# Final validation - ensure all critical files were created
echo "Performing final validation of build artifacts..."
missing_files=""
for required_file in "Procfile" "requirements.txt" "bin/boot_server_in_docker" ".profile" "runtime.txt"; do
  if [ ! -f "${BACKEND_DIR}/$required_file" ]; then
    echo "ERROR: Required file $required_file is missing from ${BACKEND_DIR}"
    missing_files="$missing_files $required_file"
  else
    echo "✓ Found $required_file"
  fi
done

if [ -n "$missing_files" ]; then
  echo "ERROR: The following required files are missing:$missing_files"
  echo "This indicates the build script did not complete successfully"
  echo "Contents of backend directory:"
  ls -la "${BACKEND_DIR}/" || echo "Could not list backend directory"
  echo "CRITICAL: Build failed - stopping before zip creation"
  exit 1
fi

# Validate that the backend directory has content
if [ -z "$(ls -A ${BACKEND_DIR} 2>/dev/null)" ]; then
  echo "ERROR: Backend directory ${BACKEND_DIR} is empty"
  echo "This indicates the build failed to populate the directory"
  exit 1
fi

echo "✓ All required files created successfully"

# Create the zip file at the expected path
echo "Creating deployment zip file: $PACKAGE_PATH"

# Verify the backend directory exists and has content
if [ ! -d "$BACKEND_DIR" ]; then
  echo "ERROR: Backend directory does not exist: $BACKEND_DIR"
  exit 1
fi


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
if [[ "$PACKAGE_PATH" == "$BACKEND_DIR"* ]]; then
  echo "ERROR: PACKAGE_PATH ($PACKAGE_PATH) must not be inside BACKEND_DIR ($BACKEND_DIR)"
  exit 1
fi

# shellcheck disable=SC2164
(cd "$BACKEND_DIR" && zip -rq "$PACKAGE_PATH" .)

# Verify the zip file was created successfully
if [ ! -f "$PACKAGE_PATH" ]; then
  echo "ERROR: Zip file $PACKAGE_PATH was not created"
  exit 1
fi

# Check zip file integrity
if ! zip -T "$PACKAGE_PATH" >/dev/null 2>&1; then
  echo "ERROR: Created zip file $PACKAGE_PATH is corrupted"
  exit 1
fi

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
    echo "✗ Missing: $required_file (no match for /$required_file$ or ^$required_file$)"
    ((missing_count++))
  fi
done

if [ $missing_count -gt 0 ]; then
  echo "ERROR: $missing_count critical files missing from zip"
  rm -f "$PACKAGE_PATH"
  exit 1
fi

echo "✓ Zip file validation completed successfully"
echo "Build preparation complete!"
