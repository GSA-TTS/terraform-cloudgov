locals {
  prefix = (var.name != null ? var.name : random_pet.prefix.id)

  # TODO: Currently unused. We should be set creds for the backend
  # and include them in the outputs since people will need them to 
  # log into the frontend. This should be straightforward to 
  # implement in the buildpack path but the container path will 
  # require a bit more thought. 
  username = random_uuid.username.result
  password = random_password.password.result

  backend_url   = "https://${module.backend_route.endpoint}"
  connector_url = "https://${module.connector_route.endpoint}:61443"
  frontend_url  = "https://${module.frontend_route.endpoint}"

  backend_app_id      = cloudfoundry_app.backend.id
  connector_app_id    = cloudfoundry_app.connector.id
  frontend_app_id     = cloudfoundry_app.frontend.id
  tags                = setunion(["terraform-cloudgov-managed"], var.tags)
  frontend_baseimage  = split(":", var.frontend_imageref)[0]
  connector_baseimage = split(":", var.connector_imageref)[0]
  backend_baseimage   = var.backend_deployment_method == "container" ? split(":", var.backend_imageref)[0] : null
}

resource "random_uuid" "username" {}
resource "random_password" "password" {
  length  = 16
  special = false
}

resource "random_pet" "prefix" {
  prefix = "spiffworkflow"
}

resource "random_password" "connector_flask_secret_key" {
  length  = 32
  special = true
}

data "docker_registry_image" "connector" {
  name = var.connector_imageref
}

resource "cloudfoundry_app" "connector" {
  name                       = "${local.prefix}-connector"
  org_name                   = var.cf_org_name
  space_name                 = var.cf_space_name
  docker_image               = "${local.connector_baseimage}@${data.docker_registry_image.connector.sha256_digest}"
  memory                     = var.connector_memory
  instances                  = var.connector_instances
  disk_quota                 = "3G"
  strategy                   = "rolling"
  command                    = <<-COMMAND
    # Make sure the Cloud Foundry-provided CA is recognized when making TLS connections
    cat /etc/cf-system-certificates/* > /usr/local/share/ca-certificates/cf-system-certificates.crt
    /usr/sbin/update-ca-certificates
    /app/bin/boot_server_in_docker
    COMMAND
  health_check_type          = "http"
  health_check_http_endpoint = "/liveness"

  environment = {
    FLASK_DEBUG : "0"
    FLASK_SESSION_SECRET_KEY : random_password.connector_flask_secret_key.result
    CONNECTOR_PROXY_PORT : "8080"
    REQUESTS_CA_BUNDLE : "/etc/ssl/certs/ca-certificates.crt"
  }
}

data "docker_registry_image" "frontend" {
  name = var.frontend_imageref
}

resource "cloudfoundry_app" "frontend" {
  name              = "${local.prefix}-frontend"
  org_name          = var.cf_org_name
  space_name        = var.cf_space_name
  docker_image      = "${local.frontend_baseimage}@${data.docker_registry_image.frontend.sha256_digest}"
  memory            = var.frontend_memory
  instances         = var.frontend_instances
  strategy          = "rolling"
  health_check_type = "port"

  environment = {
    APPLICATION_ROOT : "/"
    PORT0 : "80"
    SPIFFWORKFLOW_FRONTEND_RUNTIME_CONFIG_APP_ROUTING_STRATEGY : "path_based"
    SPIFFWORKFLOW_FRONTEND_RUNTIME_CONFIG_BACKEND_BASE_URL : local.backend_url
    BACKEND_BASE_URL : local.backend_url
  }
}
