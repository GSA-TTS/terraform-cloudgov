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
  connector_baseimage = var.connector_deployment_method == "container" ? split(":", var.connector_imageref)[0] : null
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
