locals {
  prefix          = (var.name != null ? var.name : random_pet.prefix.id)
  backend_route   = module.backend_route.endpoint
  connector_route = module.connector_route.endpoint
  frontend_route  = module.frontend_route.endpoint

  # TODO: Currently unused. We should be set creds for the backend
  # and include them in the outputs since people will need them to 
  # log into the frontend. This should be straightforward to 
  # implement in the buildpack path but the container path will 
  # require a bit more thought. 
  username = random_uuid.username.result
  password = random_password.password.result

  backend_url   = "https://${local.backend_route}"
  connector_url = "https://${local.connector_route}:61443"
  frontend_url  = "https://${local.frontend_route}"

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
module "connector_route" {
  source = "github.com/GSA-TTS/terraform-cloudgov//app_route?ref=v2.3.0"

  cf_org_name   = var.cf_org_name
  cf_space_name = var.cf_space_name
  domain        = "apps.internal"
  hostname      = "${local.prefix}-connector"
  app_ids       = [cloudfoundry_app.connector.id]
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
module "frontend_route" {
  source = "github.com/GSA-TTS/terraform-cloudgov//app_route?ref=v2.3.0"

  cf_org_name   = var.cf_org_name
  cf_space_name = var.cf_space_name
  hostname      = local.prefix
  app_ids       = [cloudfoundry_app.frontend.id]
}

resource "cloudfoundry_network_policy" "connector-network-policy" {
  policies = [
    {
      source_app      = local.backend_app_id
      destination_app = local.connector_app_id
      port            = "61443"
      protocol        = "tcp"
    }
  ]
}
