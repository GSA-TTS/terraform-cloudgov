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
  # Connector package paths for buildpack deployment
  connector_dist_dir         = "${path.root}/dist-connector"
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
      mkdir -p "${local.connector_dir}"
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
resource "archive_file" "connector_code" {
  count       = var.connector_deployment_method == "buildpack" ? 1 : 0
  depends_on  = [null_resource.prepare_connector]
  type        = "zip"
  source_dir  = local.connector_dir
  output_path = local.connector_package_path
  excludes    = [".git", "__pycache__", "*.pyc", "*.pyo"]
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
  docker_image = var.connector_deployment_method == "container" ? "${local.connector_baseimage}@${data.docker_registry_image.connector[0].sha256_digest}" : null
  path = var.connector_deployment_method == "buildpack" ? archive_file.connector_code[0].output_path : null
  source_code_hash = var.connector_deployment_method == "buildpack" ? archive_file.connector_code[0].output_base64sha256 : null
  
  # Command is only needed for container deployment
  command = var.connector_deployment_method == "container" ? <<-COMMAND
    # Make sure the Cloud Foundry-provided CA is recognized when making TLS connections
    cat /etc/cf-system-certificates/* > /usr/local/share/ca-certificates/cf-system-certificates.crt
    /usr/sbin/update-ca-certificates
    /app/bin/boot_server_in_docker
    COMMAND : null
    
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
  depends_on = [archive_file.connector_code]

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
