#!/bin/bash
set -euo pipefail


# This script prepares a deployment zip for the SpiffWorkflow backend application
# for buildpack-based deployment on Cloud Foundry (cloud.gov).
# 
# It handles:
# - Downloading the source code from GitHub at the specified reference
# - Copying process models from a local directory
# - Generating requirements.txt using uv
# - Optionally including supplemental scripts
# - Adding files and configuration necessary for the Python buildpack
#
# This script should be run BEFORE terraform plan/apply. The resulting zip is
# passed to the Terraform module via the backend_zip_path variable.
#
# USAGE:
#
#   ./build-for-cloudfoundry.sh <output_zip> <backend_gitref> <process_models_path> [python_version] [scripts_path]
#
# Example:
#   ./build-for-cloudfoundry.sh /tmp/backend.zip github.com/sartography/spiff-arena?ref=v1.1.5 ./process_models python-3.12.x ./scripts
#
# Arguments:
#   output_zip          - Output path for the generated zip file
#   backend_gitref      - Source URL in URL?ref=REF format (e.g. github.com/org/repo?ref=COMMIT)
#   process_models_path - Path to local process_models directory
#   python_version      - (optional) Python version string for buildpack (default: python-3.10.x)
#   scripts_path        - (optional) Path to supplemental scripts directory

umask 022
export TZ=UTC
export LANG=C
export LC_ALL=C
export PYTHONHASHSEED=0

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

strip_transient_files() {
  local root_dir="$1"

  find "$root_dir" -type d -name "__pycache__" -prune -exec rm -rf {} +
  find "$root_dir" -type d -name ".pytest_cache" -prune -exec rm -rf {} +
  find "$root_dir" -type d -name ".mypy_cache" -prune -exec rm -rf {} +
  find "$root_dir" -type f \( -name "*.pyc" -o -name "*.pyo" -o -name ".DS_Store" \) -delete
}

# Detect whether pyproject.toml declares a "postgres" key under
# [project.optional-dependencies]. Used to decide whether `uv export` needs
# an explicit --extra postgres to pull in the Postgres driver (see the
# requirements.txt generation step below for why this matters). Handles
# quoted keys ("postgres" = [...]), indented section headers, and the
# dotted-key form (optional-dependencies.postgres = [...]) in addition to
# the plain form. If this detection ever misses a real-world shape, the
# downstream "no Postgres driver found" check below still fails loudly
# rather than silently shipping without a driver.
has_postgres_extra() {
  local pyproject_file="$1"
  awk '
    /^[[:space:]]*\[project\.optional-dependencies\]/ { in_section=1; next }
    /^[[:space:]]*\[/ { in_section=0 }
    in_section && /^[[:space:]]*"?postgres"?[[:space:]]*=/ { found=1 }
    /^[[:space:]]*optional-dependencies\.postgres[[:space:]]*=/ { found=1 }
    END { exit !found }
  ' "$pyproject_file"
}

# Recognized Postgres driver package names (lowercased, PEP 503 style).
# Used only to fail loudly if none of them end up in the exported
# requirements.txt - see the requirements.txt generation step below.
POSTGRES_DRIVER_PATTERN='^(psycopg2|psycopg2-binary|psycopg|psycopg-binary|asyncpg)(==| @|;| )'

create_reproducible_zip() {
  local source_dir="$1"
  local output_path="$2"

  strip_transient_files "$source_dir"
  find "$source_dir" -exec touch -t "$SOURCE_TOUCH_TS" {} +
  (
    cd "$source_dir"
    LC_ALL=C find . -type f | sort | zip -qX "$output_path" -@
  )
}


# Cross-platform sed -i that works on both BSD (macOS) and GNU (Linux).
# Detect once at startup; then safe_sed simply calls sed with the right flags.
_sed_test_file=$(mktemp)
echo "test" > "$_sed_test_file"
if sed -i '' 's/test/TEST/' "$_sed_test_file" 2>/dev/null && grep -q "TEST" "$_sed_test_file"; then
  safe_sed() { sed -i '' "$1" "$2"; }
else
  safe_sed() { sed -i "$1" "$2"; }
fi
rm -f "$_sed_test_file"

# Required parameters
if [ $# -lt 3 ] || [ $# -gt 5 ]; then
  fatal "Usage: $0 <output_zip> <backend_gitref> <process_models_path> [python_version] [scripts_path]"
fi

# Parse arguments
PACKAGE_PATH="$1"
# Second argument should be a composite like: github.com/sartography/spiff-arena?ref=v1.1.2
# We derive GIT_URL and GIT_REF.
RAW_GIT_SPEC="$2"
PROCESS_MODELS_PATH="$3"
PYTHON_VERSION="${4:-python-3.10.x}"
BACKEND_SCRIPTS_PATH="${5:-}"

# Resolve PACKAGE_PATH to absolute so we can cd later without losing it
PACKAGE_PATH="$(cd "$(dirname "$PACKAGE_PATH")" 2>/dev/null && pwd)/$(basename "$PACKAGE_PATH")" || fatal "Cannot resolve output path: $1"

# Derive GIT_URL and GIT_REF from RAW_GIT_SPEC
# Requires URL?ref=REF format. Accept with or without https:// scheme.
if [[ "$RAW_GIT_SPEC" != *"?ref="* ]]; then
  fatal "backend_gitref must be in URL?ref=REF format (e.g. github.com/org/repo?ref=COMMIT), got: $RAW_GIT_SPEC"
fi
BASE_PART="${RAW_GIT_SPEC%%\?ref=*}"
REF_PART="${RAW_GIT_SPEC##*?ref=}"  # everything after last ?ref=

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

# ---------------------------------------------------------------------------
# Validate all local inputs and tools before downloading anything
# ---------------------------------------------------------------------------
echo "Validating inputs..."

if [ -n "${BACKEND_SCRIPTS_PATH}" ]; then
  echo "Using scripts path: ${BACKEND_SCRIPTS_PATH}"
  if [ ! -d "${BACKEND_SCRIPTS_PATH}" ]; then
    fatal "scripts_path does not exist or is not a directory: ${BACKEND_SCRIPTS_PATH}"
  fi
fi

# Check if process models directory exists and is accessible
if [ ! -d "$PROCESS_MODELS_PATH" ]; then
  fatal "Process models path does not exist: $PROCESS_MODELS_PATH (abs: $(readlink -f "$PROCESS_MODELS_PATH" 2>/dev/null || echo "Path resolution failed"))"
fi

! ls -la "$PROCESS_MODELS_PATH" >/dev/null 2>&1 && fatal "Process models path not accessible: $PROCESS_MODELS_PATH"

echo "✓ Process models directory validated: $PROCESS_MODELS_PATH"

# Validate required tools
# Validate required tools
for tool in git zip uv; do
  command -v "$tool" >/dev/null 2>&1 || fatal "Required tool '$tool' is not installed or not in PATH"
done
echo "✓ Required tools: git, zip, uv"

# ---------------------------------------------------------------------------
# Local validation passed — set up working directory and begin build
# ---------------------------------------------------------------------------

# Use a temporary working directory to avoid polluting the caller's tree
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Use a fixed timestamp so archive metadata is deterministic without external API calls.
SOURCE_TOUCH_TS="200001010000.00"
echo "✓ Using fixed reproducible timestamp: ${SOURCE_TOUCH_TS}"

echo "Build starting: GIT_REF=${GIT_REF} PYTHON_VERSION=${PYTHON_VERSION} PACKAGE_PATH=${PACKAGE_PATH}"

# Remove any existing zip file to ensure we create a fresh one
if [ -f "$PACKAGE_PATH" ]; then
  echo "Removing existing zip file: $PACKAGE_PATH"
  rm -f "$PACKAGE_PATH"
fi

# Set up standard directories inside the temp working directory
DOWNLOAD_DIR="${WORK_DIR}/download"
BACKEND_DIR="${WORK_DIR}/backend"
PROCESS_MODELS_DEST="${BACKEND_DIR}/process_models"

# Include git_ref in the zip filename to identify the version
SAFE_GIT_REF=$(echo "${GIT_REF}" | tr '/' '_')
DOWNLOAD_ZIP="${DOWNLOAD_DIR}/spiff-arena-${SAFE_GIT_REF}.zip"

# Create directories
mkdir -p "${DOWNLOAD_DIR}"
mkdir -p "${BACKEND_DIR}"

# Download the source code directly as a ZIP file if it doesn't exist
if [ -f "${DOWNLOAD_ZIP}" ]; then
  echo "Using existing download for reference: ${GIT_REF} from ${DOWNLOAD_ZIP##*/}"
else
  echo "Downloading source code (trying tag, branch, generic) for ref: ${GIT_REF}..."
  TMP_ZIP="${DOWNLOAD_ZIP}.tmp"
  rm -f "$TMP_ZIP"

  DOWNLOAD_URLS=(
    "${GIT_URL}/archive/refs/tags/${GIT_REF}.zip"
    "${GIT_URL}/archive/refs/heads/${GIT_REF}.zip"
    "${GIT_URL}/archive/${GIT_REF}.zip"
  )

  DOWNLOADED=false
  for url in "${DOWNLOAD_URLS[@]}"; do
    if curl -fsSL -o "$TMP_ZIP" "$url" 2>/dev/null; then
      DOWNLOADED=true
      break
    fi
  done

  if [ "$DOWNLOADED" = false ]; then
    echo "ERROR: Could not download a valid archive for ref '${GIT_REF}' from ${GIT_URL}" >&2
    printf "  Tried: %s\n" "${DOWNLOAD_URLS[@]}" >&2
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
# Create the .profile.d init script that ensures the bootstrap process model
# env var is only active on the first app instance (index 0).
# ----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "${BACKEND_DIR}/.profile.d"
cp "${SCRIPT_DIR}/templates/10-init-process.sh" "${BACKEND_DIR}/.profile.d/10-init-process.sh"
chmod +x "${BACKEND_DIR}/.profile.d/10-init-process.sh"
echo "✓ Created .profile.d/10-init-process.sh"

# ----------------------------------------------------------------------------
# Include content of custom scripts directory (eg profile hooks)
# Note these are copied relative to the root of the application!
# ----------------------------------------------------------------------------
if [ -n "${BACKEND_SCRIPTS_PATH}" ] && [ -d "${BACKEND_SCRIPTS_PATH}" ]; then
  echo "Including custom scripts from ${BACKEND_SCRIPTS_PATH} ..."
  cp -R "${BACKEND_SCRIPTS_PATH}/." "${BACKEND_DIR}/"
else
  echo "Scripts path not present or not a directory: ${BACKEND_SCRIPTS_PATH} (skipping script vendoring)"
fi

# Add a Procfile for the Python buildpack, which requires that one exist
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

# Generate requirements.txt by EXPORTING the already-tested uv.lock, not by
# re-resolving pyproject.toml against live PyPI. Re-resolving (the old
# `uv pip compile pyproject.toml` approach) meant the deployed dependency
# set was never actually the set anyone tested, and a patched uv.lock
# upstream would not reliably reach cloud.gov. See terraform-cloudgov#130.
echo "Generating requirements.txt from the tested uv.lock..."
if [ -f "${BACKEND_DIR}/uv.lock" ] && [ -f "${BACKEND_DIR}/pyproject.toml" ]; then
  # --locked makes uv fail loudly (non-zero exit) if uv.lock is missing or
  # out of sync with pyproject.toml, instead of silently re-resolving. That
  # silent-fallback behavior is exactly the bug this script is fixing, so we
  # never fall back to `uv pip compile` here under any circumstance.
  #
  # --no-dev drops the [dependency-groups].dev group (e.g. mypy, pytest,
  # ruff), which is never needed at runtime. Note: sqlalchemy-stubs is a
  # hard runtime dependency in this fork's pyproject.toml (not part of the
  # dev group) despite its name, so --no-dev does not affect it; it is
  # exported like any other dependency.
  #
  # --no-emit-project excludes the spiffworkflow-backend project entry
  # itself; only its dependencies are needed in requirements.txt.
  #
  # Extras (e.g. --extra postgres) are requested explicitly when the
  # backend's pyproject.toml declares them, to stay correct regardless of
  # whether the backend fork has psycopg2 as a hard dependency (as it does
  # today) or as an optional "postgres" extra (as upstream Arena v4.0.0
  # does). See has_postgres_extra() above.
  EXPORT_EXTRA_ARGS=()
  if has_postgres_extra "${BACKEND_DIR}/pyproject.toml"; then
    echo "pyproject.toml declares a 'postgres' extra; requesting it explicitly."
    EXPORT_EXTRA_ARGS+=(--extra postgres)
  fi

  # Hashes are intentionally omitted. uv export's hashes only cover
  # registry-resolved packages; it cannot hash git-sourced dependencies
  # (SpiffWorkflow, spiffworkflow-connector-command), so the output would
  # contain a mix of hashed and unhashed entries. pip - which the Cloud
  # Foundry Python buildpack uses to install requirements.txt - refuses to
  # install ANY package without a hash as soon as ANY entry in the file has
  # one ("Can't verify hashes for these requirements because we don't have
  # a way to hash version control repositories"), which would hard-fail the
  # buildpack. Confirmed empirically with pip 25.0.1 against this file's
  # git dependencies. If the backend ever drops its git dependencies,
  # hashes can be re-enabled with --no-emit-package carve-outs reconsidered.
  echo "Using uv export to generate requirements.txt from uv.lock..."
  (
    cd "${BACKEND_DIR}" &&
      uv export --quiet --locked --no-dev --no-emit-project --no-hashes --no-header \
        ${EXPORT_EXTRA_ARGS[@]+"${EXPORT_EXTRA_ARGS[@]}"} \
        --format requirements-txt --output-file requirements.txt
  ) || fatal "uv export failed: uv.lock is missing, out of sync with pyproject.toml, or the export itself failed. Run 'uv lock' in the backend source to refresh it."

  [ ! -f "${BACKEND_DIR}/requirements.txt" ] && fatal "requirements.txt was not created by uv export"

  # Fail loudly rather than silently deploying a backend with no database
  # driver at all. PIC deploys Postgres (small-psql); if no Postgres driver
  # made it into the exported set (e.g. the fork moves psycopg2 behind an
  # extra we didn't detect, or the extra name changes), that is a
  # deploy-time misconfiguration we must not ship silently.
  if ! grep -qE "$POSTGRES_DRIVER_PATTERN" "${BACKEND_DIR}/requirements.txt"; then
    fatal "No Postgres driver (psycopg2/psycopg) found in exported requirements.txt. Check whether pyproject.toml moved it behind a differently-named extra."
  fi
  echo "✓ Confirmed Postgres driver present in requirements.txt"

  echo "✓ Generated requirements.txt with $(wc -l < "${BACKEND_DIR}/requirements.txt") dependencies"
else
  fatal "Missing uv.lock or pyproject.toml required for dependency generation"
fi

echo "Creating .profile file with environment setup..."
cp "${SCRIPT_DIR}/templates/profile.sh" "${BACKEND_DIR}/.profile"
chmod +x "${BACKEND_DIR}/.profile"

[ -f "${BACKEND_DIR}/.profile" ] || fatal "Failed to create .profile"
echo "✓ Created .profile"

# Final validation - ensure all critical files were created
echo "Performing final validation of build artifacts..."
missing_files=""
for required_file in "Procfile" "requirements.txt" "bin/boot_server_in_docker" ".profile" "runtime.txt" ".profile.d/10-init-process.sh"; do
  if [ ! -f "${BACKEND_DIR}/$required_file" ]; then
    echo "ERROR: Required file $required_file is missing from ${BACKEND_DIR}" >&2
    missing_files="$missing_files $required_file"
  else
    echo "✓ Found $required_file"
  fi
done

if [ -n "$missing_files" ]; then
  echo "Contents of backend directory:" >&2
  ls -la "${BACKEND_DIR}/" || true
  fatal "Missing required files:$missing_files"
fi

echo "✓ All required files created successfully"

# Create the zip file at the expected path
# Normalize timestamps and strip extra attributes so the zip is reproducible
# given the same inputs, which lets Terraform detect real content changes.
echo "Creating deployment zip file: $PACKAGE_PATH"
mkdir -p "$(dirname "$PACKAGE_PATH")"

create_reproducible_zip "$BACKEND_DIR" "$PACKAGE_PATH"

# Verify the zip file was created successfully
[ -f "$PACKAGE_PATH" ] || fatal "Zip file $PACKAGE_PATH was not created"
zip -T "$PACKAGE_PATH" >/dev/null 2>&1 || fatal "Created zip file $PACKAGE_PATH failed integrity test"

echo "✓ Successfully created $PACKAGE_PATH with size: $(du -h "$PACKAGE_PATH" | cut -f1)"
echo "Build preparation complete!"
