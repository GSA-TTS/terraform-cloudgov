# -----------------------------------------------------------------------------
# SpiffWorkflow Connector Service
# 
# This module can deploy the SpiffWorkflow connector service in one of two ways:
#
# 1. BUILDPACK DEPLOYMENT (connector_deployment_method = "buildpack")
#    - Deploys using a .zip file and the Python buildpack
#    - Uses a local directory specified by connector_local_path
#    - Creates necessary files for buildpack deployment (runtime.txt, Procfile)
#
# 2. CONTAINER DEPLOYMENT (connector_deployment_method = "container")
#    - Deploys using a Docker container image specified by connector_imageref
#    - No local directory is needed
#
# IMPORTANT NOTES:
# - Only one deployment method can be used at a time.
# - The connector_local_path variable is only used with buildpack deployment.
# -----------------------------------------------------------------------------

locals {
  # Connector package paths for buildpack deployment - use absolute paths to avoid module path resolution issues
  connector_dist_dir         = abspath("${path.root}/dist-connector")
  connector_dir              = "${local.connector_dist_dir}/connector"
  connector_package_filename = "${local.prefix}-connector.zip"
  connector_package_path     = "${local.connector_dist_dir}/${local.connector_package_filename}"
}

resource "random_password" "connector_flask_secret_key" {
  length  = 32
  special = true
}

data "docker_registry_image" "connector" {
  count = var.connector_deployment_method == "container" ? 1 : 0
  name  = var.connector_imageref
}

# -----------------------------------------------------------------------------
# CONNECTOR BUILDPACK DEPLOYMENT RESOURCES - Only created when connector_deployment_method = "buildpack"
# -----------------------------------------------------------------------------

# Create a directory and prepare the connector code for buildpack deployment
resource "null_resource" "prepare_connector" {
  count = var.connector_deployment_method == "buildpack" ? 1 : 0

  # Re-run if the local path or Python version changes
  triggers = {
    connector_local_path     = var.connector_local_path
    connector_python_version = var.connector_python_version
    # Use sha1 of a file listing to detect changes in the connector directory
    connector_dir_hash = var.connector_local_path != "" ? sha1(join("", [
      for f in fileset(var.connector_local_path, "**/*") :
      filesha1("${var.connector_local_path}/${f}")
    ])) : ""
  }

  # Create the directory structure and copy connector files
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating connector directory at ${local.connector_dir}"
      mkdir -p "${local.connector_dir}"
      echo "Checking source path: ${var.connector_local_path}"
      ls -la "${var.connector_local_path}" || echo "Warning: Source path does not exist or is inaccessible"
      echo "Copying files from ${var.connector_local_path} to ${local.connector_dir}"
      rsync -av --exclude="__pycache__" --exclude="*.pyc" --exclude="*.pyo" --exclude=".git" "${var.connector_local_path}/" "${local.connector_dir}/"
      
      # If a requirements.txt doesn't exist, try to generate one from pyproject.toml/poetry.lock
      if [ ! -f "${local.connector_dir}/requirements.txt" ] && [ -f "${local.connector_dir}/pyproject.toml" ]; then
        if command -v poetry &> /dev/null; then
          echo "Generating requirements.txt from pyproject.toml using Poetry"
          cd "${local.connector_dir}" && poetry export -f requirements.txt --output requirements.txt --without-hashes || echo "Failed to generate requirements.txt, continuing anyway"
        else
          echo "Poetry not found, but pyproject.toml exists. Python buildpack may require requirements.txt."
        fi
      fi
      
      # Ensure we have a Procfile for the Python buildpack
      if [ ! -f "${local.connector_dir}/Procfile" ]; then
        echo "Creating default Procfile for connector"
        echo "web: ./bin/boot_server_in_docker" > "${local.connector_dir}/Procfile"
      fi
      
      # Make sure boot_server_in_docker is executable if it exists
      if [ -f "${local.connector_dir}/bin/boot_server_in_docker" ]; then
        chmod +x "${local.connector_dir}/bin/boot_server_in_docker"
      fi
      
      # Create runtime.txt to specify Python version
      echo "${var.connector_python_version}" > "${local.connector_dir}/runtime.txt"
    EOT
  }
}

# Create a zip file containing the connector code for buildpack deployment
resource "local_file" "connector_paths" {
  count      = var.connector_deployment_method == "buildpack" ? 1 : 0
  depends_on = [null_resource.prepare_connector]

  # Write paths to a file so they can be read from the Terraform module context
  filename = "${path.module}/connector_paths.txt"
  content  = <<-EOF
  SOURCE_DIR=${local.connector_dir}
  OUTPUT_PATH=${local.connector_package_path}
  EOF
}

resource "null_resource" "create_connector_zip" {
  count      = var.connector_deployment_method == "buildpack" ? 1 : 0
  depends_on = [local_file.connector_paths, null_resource.prepare_connector]

  # Create the zip file using a shell script that can handle absolute paths
  provisioner "local-exec" {
    command = <<-EOT
      # Read paths from the paths file
      source "${path.module}/connector_paths.txt"
      
      echo "Creating connector zip file..."
      echo "SOURCE_DIR: $SOURCE_DIR"
      echo "OUTPUT_PATH: $OUTPUT_PATH"
      echo "Current directory: $(pwd)"
      
      # Make sure the source directory exists
      if [ ! -d "$SOURCE_DIR" ]; then
        echo "Error: Source directory $SOURCE_DIR does not exist"
        echo "Creating directory and copying files from ${var.connector_local_path}"
        mkdir -p "$SOURCE_DIR"
        rsync -av --exclude="__pycache__" --exclude="*.pyc" --exclude="*.pyo" --exclude=".git" "${var.connector_local_path}/" "$SOURCE_DIR/"
      fi
      
      # Check if the source directory has content
      if [ -z "$(ls -A $SOURCE_DIR 2>/dev/null)" ]; then
        echo "Warning: Source directory $SOURCE_DIR is empty"
        echo "Copying files from ${var.connector_local_path} to $SOURCE_DIR"
        mkdir -p "$SOURCE_DIR"
        rsync -av --exclude="__pycache__" --exclude="*.pyc" --exclude="*.pyo" --exclude=".git" "${var.connector_local_path}/" "$SOURCE_DIR/"
        
        # Ensure we have a Procfile for the Python buildpack
        if [ ! -f "$SOURCE_DIR/Procfile" ]; then
          echo "Creating default Procfile for connector"
          echo "web: ./bin/boot_server_in_docker" > "$SOURCE_DIR/Procfile"
        fi
        
        # Make sure boot_server_in_docker is executable if it exists
        if [ -f "$SOURCE_DIR/bin/boot_server_in_docker" ]; then
          chmod +x "$SOURCE_DIR/bin/boot_server_in_docker"
        fi
        
        # Create runtime.txt to specify Python version
        echo "${var.connector_python_version}" > "$SOURCE_DIR/runtime.txt"
      fi
      
      # Create the output directory if it doesn't exist
      mkdir -p "$(dirname "$OUTPUT_PATH")"
      
      # Create the zip file
      echo "Creating zip file from $SOURCE_DIR to $OUTPUT_PATH"
      cd "$SOURCE_DIR" && zip -r "$OUTPUT_PATH" . -x "*.git*" -x "*__pycache__*" -x "*.pyc" -x "*.pyo" -x "*.venv*" -x "*.cache*"
      
      # Check if the zip file was created successfully
      if [ -f "$OUTPUT_PATH" ]; then
        echo "Successfully created $OUTPUT_PATH with size: $(du -h "$OUTPUT_PATH" | cut -f1)"
        ls -la "$OUTPUT_PATH"
      else
        echo "Error: Failed to create $OUTPUT_PATH"
        exit 1
      fi
    EOT
  }

  # Create a trigger to re-run when the source directory changes
  triggers = {
    source_dir = local.connector_dir
    # Add any other triggers that might cause the connector to change
    connector_local_path = var.connector_local_path
  }
}

# -----------------------------------------------------------------------------
# CLOUD FOUNDRY APP - Common resource with conditional properties based on deployment method
# -----------------------------------------------------------------------------
resource "cloudfoundry_app" "connector" {
  name                       = "${local.prefix}-connector"
  org_name                   = var.cf_org_name
  space_name                 = var.cf_space_name
  memory                     = var.connector_memory
  instances                  = var.connector_instances
  disk_quota                 = var.connector_disk
  strategy                   = "rolling"
  health_check_type          = "http"
  health_check_http_endpoint = "/liveness"

  # Conditional properties based on deployment method
  docker_image = var.connector_deployment_method == "container" ? (
    var.connector_deployment_method == "container" && length(data.docker_registry_image.connector) > 0 ?
    "${local.connector_baseimage}@${data.docker_registry_image.connector[0].sha256_digest}" :
    var.connector_imageref
  ) : null
  path = var.connector_deployment_method == "buildpack" ? local.connector_package_path : null
  # Only calculate the hash if the file exists to avoid errors
  source_code_hash = var.connector_deployment_method == "buildpack" ? (
    fileexists(local.connector_package_path) ? filebase64sha256(local.connector_package_path) : null
  ) : null

  # Command is only needed for container deployment
  command = var.connector_deployment_method == "buildpack" ? null : <<-COMMAND
    # Make sure the Cloud Foundry-provided CA is recognized when making TLS connections
    cat /etc/cf-system-certificates/* > /usr/local/share/ca-certificates/cf-system-certificates.crt
    /usr/sbin/update-ca-certificates
    /app/bin/boot_server_in_docker
    COMMAND

  # Add buildpack requirements for Python when using buildpack deployment
  buildpacks = var.connector_deployment_method == "buildpack" ? ["python_buildpack"] : null

  # Common environment variables for both deployment methods
  environment = merge(
    {
      FLASK_DEBUG : "0"
      FLASK_SESSION_SECRET_KEY : random_password.connector_flask_secret_key.result
      CONNECTOR_PROXY_PORT : "8080"
      REQUESTS_CA_BUNDLE : "/etc/ssl/certs/ca-certificates.crt"
    },
    # Add Python version specification for buildpack deployment
    var.connector_deployment_method == "buildpack" ? {
      PYTHON_VERSION : var.connector_python_version
    } : {}
  )
}

# Clean up connector artifacts when the module is destroyed - only for buildpack deployment
resource "null_resource" "connector_cleanup" {
  count      = var.connector_deployment_method == "buildpack" ? 1 : 0
  depends_on = [null_resource.create_connector_zip]

  # Only run cleanup on destroy
  triggers = {
    dist_dir = local.connector_dist_dir
  }

  # This will run when the resource is destroyed (terraform destroy)
  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${self.triggers.dist_dir}"
  }
}
