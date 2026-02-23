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
  frontend_url  = var.frontend_url_override != "" ? var.frontend_url_override : "https://${module.frontend_route.endpoint}"

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
  space_name        = var.space.name
  docker_image      = "${local.frontend_baseimage}@${data.docker_registry_image.frontend.sha256_digest}"
  memory            = var.frontend_memory
  instances         = var.frontend_instances
  strategy          = "rolling"
  health_check_type = "port"
  command                    = <<-COMMAND
  # Make sure the Cloud Foundry-provided CA is recognized when making TLS connections
  cat /etc/cf-system-certificates/* > /usr/local/share/ca-certificates/cf-system-certificates.crt
  /usr/sbin/update-ca-certificates

  # Set the HTTPS_PROXY
  if [ -n "$PROXYROUTE" ]; then
    echo "Setting the https proxy"
    export HTTPS_PROXY="$PROXYROUTE"
    export NO_PROXY="apps.internal"  # For internal traffic
  fi

  /app/bin/boot_server_in_docker
  COMMAND

  environment = {
    PROXYROUTE : var.https_proxy
    APPLICATION_ROOT : "/"
    PORT0 : "80"
    SPIFFWORKFLOW_FRONTEND_RUNTIME_CONFIG_APP_ROUTING_STRATEGY : "path_based"
    SPIFFWORKFLOW_FRONTEND_RUNTIME_CONFIG_BACKEND_BASE_URL : local.backend_url
    BACKEND_BASE_URL : local.backend_url
    SPIFFWORKFLOW_FRONTEND_RUNTIME_CONFIG_TASK_METADATA : var.frontend_task_metadata
  }
}
