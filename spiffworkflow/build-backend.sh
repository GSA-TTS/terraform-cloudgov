#!/bin/bash
set -euo pipefail

# This script prepares the content for the SpiffWorkflow backend application
# It is used only for buildpack-based deployment (backend_deployment_method = "buildpack")
# 
# It handles:
# - Downloading the source code from GitHub at the specified reference (backend_gitref)
# - Copying process models from the local directory (backend_process_models_path)
# - Generating requirements.txt using Poetry
# - Adding files and configuration necessary for the Python buildpack

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
if [ $# -lt 4 ]; then
  echo "Usage: $0 <path_root> <backend_gitref> <backend_process_models_path> <backend_python_version>"
  exit 1
fi

# Parse arguments
PATH_ROOT="$1"
GIT_REF="$2"
PROCESS_MODELS_PATH="$3"
PYTHON_VERSION="$4"

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

# Generate requirements.txt from poetry.lock
echo "Generating requirements.txt from poetry files..."
if [ -f "${BACKEND_DIR}/poetry.lock" ] && [ -f "${BACKEND_DIR}/pyproject.toml" ]; then
  # Ensure poetry is installed
  if ! command -v poetry &> /dev/null; then
    echo "ERROR: Poetry is required but not installed"
    echo "Please install Poetry using one of these methods:"
    echo "  - curl -sSL https://install.python-poetry.org | python3 -"
    echo "  - brew install poetry"
    echo "  - pip install poetry"
    exit 1
  fi
  
  # Use poetry to export requirements
  echo "Using Poetry to generate requirements.txt..."
  (cd "${BACKEND_DIR}" && poetry export -f requirements.txt --without-hashes -o requirements.txt)

  # # Add Poetry and pip-tools to requirements.txt
  # echo "Adding Poetry and pip-tools to requirements.txt..."
  # echo "poetry==1.7.1" >> "${BACKEND_DIR}/requirements.txt"
  # echo "pip-tools==7.3.0" >> "${BACKEND_DIR}/requirements.txt"

  echo "Generated requirements.txt with $(wc -l < "${BACKEND_DIR}/requirements.txt") dependencies"
  
  # Display the first few lines for reference
  # echo "First 10 lines of requirements.txt:"
  # head -n 10 "${BACKEND_DIR}/requirements.txt"
else
  echo "ERROR: Could not find poetry.lock or pyproject.toml"
  echo "These files are required for generating dependencies"
  exit 1
fi

# Add a Procfile for the Python buildpack if it doesn't exist
if [ ! -f "${BACKEND_DIR}/Procfile" ]; then
  echo "Creating Procfile for Python buildpack..."
  cat > "${BACKEND_DIR}/Procfile" << EOF
web: ./bin/boot_server_in_docker
EOF
fi

# Make sure boot_server_in_docker is executable
if [ -f "${BACKEND_DIR}/bin/boot_server_in_docker" ]; then
  chmod +x "${BACKEND_DIR}/bin/boot_server_in_docker"
fi

# Don't use poetry run in inside the container environment; the 
# buildpack lifecycle is responsible for setting up the environment
# before the app even starts.
safe_sed 's/poetry run //g' "${BACKEND_DIR}/bin/boot_server_in_docker"

# Same with uv for forward compatibility; spiff uses uv after v1.0.0
safe_sed 's/uv run //g' "${BACKEND_DIR}/bin/boot_server_in_docker"

# Add Python buildpack runtime.txt if it doesn't exist
if [ ! -f "${BACKEND_DIR}/runtime.txt" ]; then
  echo "Creating runtime.txt for Python buildpack with version: ${PYTHON_VERSION}..."
  echo "${PYTHON_VERSION}" > "${BACKEND_DIR}/runtime.txt"
fi

# Create a .profile file to ensure the backend can find the database
echo "Creating .profile file with environment setup..."
cat > "${BACKEND_DIR}/.profile" << EOF
#!/usr/bin/env bash
export PYTHONPATH="/home/vcap/app:/home/vcap/app/src:/home/vcap/deps/0/python:/home/vcap/deps/0"
# Get the postgres URI from the service binding. (SQL Alchemy insists on "postgresql://".🙄)
export SPIFFWORKFLOW_BACKEND_DATABASE_URI=\$( echo \$VCAP_SERVICES | jq -r '.["aws-rds"][].credentials.uri' | sed -e s/postgres/postgresql/ )
EOF
chmod +x "${BACKEND_DIR}/.profile"

echo "Build preparation complete!"
