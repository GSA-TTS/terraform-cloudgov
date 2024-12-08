locals {
  backend_route   = "${local.frontend_route}/api"
  connector_route = "${var.route_prefix}-connector.apps.internal"
  frontend_route  = "${var.route_prefix}.app.cloud.gov"

  username = random_uuid.username.result
  password = random_password.password.result

  # backend_url   = "https://${local.username}:${local.password}@${local.backend_route}"
  # connector_url = "https://${local.connector_route}:61443"
  # frontend_url  = "https://${local.username}:${local.password}@${local.frontend_route}"

  backend_url   = "https://${local.backend_route}"
  connector_url = "https://${local.connector_route}:61443"
  frontend_url  = "https://${local.frontend_route}"

  backend_app_id   = cloudfoundry_app.backend.id
  connector_app_id = cloudfoundry_app.connector.id
  frontend_app_id  = cloudfoundry_app.frontend.id
  tags             = setunion(["terraform-cloudgov-managed"], var.tags)
}

data "cloudfoundry_service_plans" "rds" {
  name                  = var.rds_plan_name
  service_offering_name = "aws-rds"
}

data "cloudfoundry_org" "org" {
  name = var.cf_org_name
}

data "cloudfoundry_space" "space" {
  name = var.cf_space_name
  org  = data.cloudfoundry_org.org.id
}
resource "cloudfoundry_service_instance" "database" {
  name         = "${var.app_prefix}-database"
  space        = data.cloudfoundry_space.space.id
  type         = "managed"
  service_plan = data.cloudfoundry_service_plans.rds.service_plans.0.id
  tags         = local.tags
  parameters   = var.rds_json_params
}

resource "random_uuid" "username" {}
resource "random_password" "password" {
  length  = 16
  special = false
}

resource "random_password" "backend_flask_secret_key" {
  length  = 32
  special = true
}

resource "random_password" "backend_openid_secret" {
  length  = 32
  special = true
}

resource "cloudfoundry_app" "backend" {
  name                       = "${var.app_prefix}-backend"
  org_name                   = var.cf_org_name
  space_name                 = var.cf_space_name
  docker_image               = var.backend_imageref
  memory                     = var.backend_memory
  instances                  = var.backend_instances
  disk_quota                 = "3G"
  strategy                   = "rolling"
  command                    = <<-COMMAND
    # Get the postgres URI from the service binding. (SQL Alchemy insists on "postgresql://".🙄)
    export SPIFFWORKFLOW_BACKEND_DATABASE_URI=$( echo $VCAP_SERVICES | jq -r '.["aws-rds"][].credentials.uri' | sed -e s/postgres/postgresql/ )

    # Make sure the Cloud Foundry-provided CA is recognized when making TLS connections
    cat /etc/cf-system-certificates/* > /usr/local/share/ca-certificates/cf-system-certificates.crt
    /usr/sbin/update-ca-certificates

    # Verify that this is working. It should return '{"ok": true}'
    # curl https://spiffworkflow((slug))-connector.apps.internal:61443/liveness

    /app/bin/clone_process_models
    /app/bin/boot_server_in_docker
    COMMAND
  health_check_type          = "http"
  health_check_http_endpoint = "/api/v1.0/status"
  service_bindings = [
    { service_instance = cloudfoundry_service_instance.database.name }
  ]
  routes = [{
    route    = local.backend_route
    protocol = "http1"
  }]

  environment = {
    APPLICATION_ROOT : "/"
    FLASK_SESSION_SECRET_KEY : random_password.backend_flask_secret_key.result
    FLASK_DEBUG : "0"
    REQUESTS_CA_BUNDLE : "/etc/ssl/certs/ca-certificates.crt"

    # All of the configuration variables are documented here:
    # spiffworkflow-backend/src/spiffworkflow_backend/config/default.py
    SPIFFWORKFLOW_BACKEND_BPMN_SPEC_ABSOLUTE_DIR : "/app/process_models"
    SPIFFWORKFLOW_BACKEND_CHECK_FRONTEND_AND_BACKEND_URL_COMPATIBILITY : "false"
    SPIFFWORKFLOW_BACKEND_CONNECTOR_PROXY_URL : local.connector_url
    SPIFFWORKFLOW_BACKEND_DATABASE_TYPE : "postgres"
    SPIFFWORKFLOW_BACKEND_ENV : "local_docker"
    SPIFFWORKFLOW_BACKEND_EXTENSIONS_API_ENABLED : "true"
    SPIFFWORKFLOW_BACKEND_GIT_COMMIT_ON_SAVE : "true"
    SPIFFWORKFLOW_BACKEND_GIT_PUBLISH_CLONE_URL : var.process_models_repository
    SPIFFWORKFLOW_BACKEND_GIT_PUBLISH_TARGET_BRANCH : var.process_models_publish_branch

    # This branch needs to exist, otherwise we can't clone it at startup and startup fails
    SPIFFWORKFLOW_BACKEND_GIT_SOURCE_BRANCH : var.process_models_source_branch
    SPIFFWORKFLOW_BACKEND_GIT_SSH_PRIVATE_KEY : var.process_models_ssh_key
    SPIFFWORKFLOW_BACKEND_LOAD_FIXTURE_DATA : "false"
    SPIFFWORKFLOW_BACKEND_LOG_LEVEL : "INFO"

    # TODO: We should make these configurable with variables so 
    # you can specify an external OIDC IDP.
    SPIFFWORKFLOW_BACKEND_OPEN_ID_CLIENT_ID : "spiffworkflow-backend"
    SPIFFWORKFLOW_BACKEND_OPEN_ID_CLIENT_SECRET_KEY : random_password.backend_openid_secret.result
    SPIFFWORKFLOW_BACKEND_OPEN_ID_SERVER_URL : "${local.backend_url}/openid"

    # TODO: static creds are in this path in the image: 
    #   /config/permissions/example.yml
    # We should probably generate credentials only for the admin
    # and have everything else be specified via DMN as described here:
    #   https://spiff-arena.readthedocs.io/en/latest/DevOps_installation_integration/admin_and_permissions.html#site-administration
    SPIFFWORKFLOW_BACKEND_PERMISSIONS_FILE_NAME : "example.yml"

    SPIFFWORKFLOW_BACKEND_PORT : "8080"
    SPIFFWORKFLOW_BACKEND_RUN_BACKGROUND_SCHEDULER_IN_CREATE_APP : "true"
    SPIFFWORKFLOW_BACKEND_UPGRADE_DB : "true"
    SPIFFWORKFLOW_BACKEND_URL : local.backend_url
    SPIFFWORKFLOW_BACKEND_URL_FOR_FRONTEND : local.frontend_url
    SPIFFWORKFLOW_BACKEND_USE_WERKZEUG_MIDDLEWARE_PROXY_FIX : "true"
    SPIFFWORKFLOW_BACKEND_WSGI_PATH_PREFIX : "/api"
  }
}

resource "random_password" "connector_flask_secret_key" {
  length  = 32
  special = true
}

resource "cloudfoundry_app" "connector" {
  name                       = "${var.app_prefix}-connector"
  org_name                   = var.cf_org_name
  space_name                 = var.cf_space_name
  docker_image               = var.connector_imageref
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
  routes = [{
    route    = local.connector_route
    protocol = "http1"
  }]

  environment = {
    FLASK_DEBUG : "0"
    FLASK_SESSION_SECRET_KEY : random_password.connector_flask_secret_key.result
    CONNECTOR_PROXY_PORT : "8080"
    REQUESTS_CA_BUNDLE : "/etc/ssl/certs/ca-certificates.crt"
  }
}

resource "cloudfoundry_app" "frontend" {
  name              = "${var.app_prefix}-frontend"
  org_name          = var.cf_org_name
  space_name        = var.cf_space_name
  docker_image      = var.frontend_imageref
  memory            = var.frontend_memory
  instances         = var.frontend_instances
  strategy          = "rolling"
  health_check_type = "port"
  routes = [{
    route    = local.frontend_route
    protocol = "http1"
  }]

  environment = {
    APPLICATION_ROOT : "/"
    PORT0 : "80"
    SPIFFWORKFLOW_FRONTEND_RUNTIME_CONFIG_APP_ROUTING_STRATEGY : "path_based"
    SPIFFWORKFLOW_FRONTEND_RUNTIME_CONFIG_BACKEND_BASE_URL : local.backend_url
    BACKEND_BASE_URL : local.backend_url
  }
}