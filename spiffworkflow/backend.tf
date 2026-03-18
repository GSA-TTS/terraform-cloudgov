# TODO:
# Reference: https://github.com/sartography/spiff-arena/blob/main/spiffworkflow-backend/bin/boot_server_in_docker
# - Set the admin username and password in the backend config file: SPIFFWORKFLOW_BACKEND_PERMISSIONS_FILE_NAME=example.yml

###############################################################################
# SpiffWorkflow Backend
# 
# This module can deploy the SpiffWorkflow backend in one of two ways:
#
# 1. BUILDPACK DEPLOYMENT (backend_deployment_method = "buildpack")
#    - Deploys using a pre-built .zip file (backend_zip_path) and the
#      Python buildpack
#    - The zip is produced by build-for-cloudfoundry.sh (shipped with
#      this module) and must be built BEFORE running terraform apply
#
# 2. CONTAINER DEPLOYMENT (backend_deployment_method = "container")
#    - Deploys using a Docker container image specified by backend_imageref
#    - Process models need to be baked into the container image
#    - No local process_models_path is needed
#    - Doesn't require UV or other build tools locally
#
# The process models will be available at `/app/process_models` when deployed.
#
# IMPORTANT NOTES:
# - Only one deployment method can be used at a time.
# - Container images should already contain the process models.
#   - TODO: Say more about configuring a git remote for the process models
###############################################################################


locals {
  # Common backend environment variables used by both deployment methods
  backend_env = merge({
    REQUESTS_CA_BUNDLE : "/etc/ssl/certs/ca-certificates.crt"
    APPLICATION_ROOT : "/"
    FLASK_SESSION_SECRET_KEY : random_password.backend_flask_secret_key.result
    FLASK_DEBUG : "0"

    PROXYROUTE : "${var.https_proxy}"

    # All of the configuration variables are documented here:
    # spiffworkflow-backend/src/spiffworkflow_backend/config/default.py
    SPIFFWORKFLOW_BACKEND_BPMN_SPEC_ABSOLUTE_DIR : "/app/process_models"
    SPIFFWORKFLOW_BACKEND_CHECK_FRONTEND_AND_BACKEND_URL_COMPATIBILITY : "false"
    SPIFFWORKFLOW_BACKEND_CONNECTOR_PROXY_URL : local.connector_url
    SPIFFWORKFLOW_BACKEND_DATABASE_TYPE : "postgres"
    SPIFFWORKFLOW_BACKEND_ENV : "cloud_gov"
    SPIFFWORKFLOW_BACKEND_EXTENSIONS_API_ENABLED : "true"
    SPIFFWORKFLOW_BACKEND_BOOTSTRAP_PROCESS_MODEL : var.backend_bootstrap_process_model
    SPIFFWORKFLOW_BACKEND_BOOTSTRAP_USERNAME : "adminX@bootstrap"

    # TODO: Can we turn this back on to enable a hosted development instance?
    # This branch needs to exist, otherwise we can't clone it at startup and startup fails
    SPIFFWORKFLOW_BACKEND_GIT_COMMIT_ON_SAVE : "true"
    SPIFFWORKFLOW_BACKEND_GIT_PUBLISH_CLONE_URL : var.process_models_repository
    SPIFFWORKFLOW_BACKEND_GIT_PUBLISH_TARGET_BRANCH : var.target_branch_for_saving_changes
    SPIFFWORKFLOW_BACKEND_GIT_SOURCE_BRANCH : var.source_branch_for_example_models
    SPIFFWORKFLOW_BACKEND_GIT_SSH_PRIVATE_KEY : var.process_models_ssh_key
    SPIFFWORKFLOW_BACKEND_LOAD_FIXTURE_DATA : "false"
    SPIFFWORKFLOW_BACKEND_LOG_LEVEL : "INFO"
    SPIFFWORKFLOW_BACKEND_LOG_LOGIN_LOGOUT : "true"
    SPIFFWORKFLOW_BACKEND_LOG_MILESTONES : "true"
    # OIDC Configuration - Use external OIDC if configured, otherwise use internal OIDC
    SPIFFWORKFLOW_BACKEND_OPEN_ID_CLIENT_ID : var.backend_oidc_client_id != null ? var.backend_oidc_client_id : "spiffworkflow-backend"
    SPIFFWORKFLOW_BACKEND_OPEN_ID_CLIENT_SECRET_KEY : var.backend_oidc_client_secret != null ? var.backend_oidc_client_secret : random_password.backend_openid_secret.result
    SPIFFWORKFLOW_BACKEND_OPEN_ID_SERVER_URL : var.backend_oidc_server_url != null ? var.backend_oidc_server_url : "${local.backend_url}/openid"
    SPIFFWORKFLOW_BACKEND_OPEN_ID_SCOPES : var.backend_oidc_scope != null ? var.backend_oidc_scope : "openid,profile,email,groups"
    SPIFFWORKFLOW_BACKEND_OPEN_ID_ADDITIONAL_VALID_CLIENT_IDS : var.backend_oidc_additional_valid_client_ids != null ? var.backend_oidc_additional_valid_client_ids : null
    SPIFFWORKFLOW_BACKEND_OPEN_ID_ADDITIONAL_VALID_ISSUERS : var.backend_oidc_additional_valid_issuers != null ? var.backend_oidc_additional_valid_issuers : null
    SPIFFWORKFLOW_BACKEND_AUTHENTICATION_PROVIDERS : var.backend_oidc_authentication_providers != null ? var.backend_oidc_authentication_providers : null


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
  }, var.backend_environment)

  # Buildpack-specific environment variables
  buildpack_env = {
    PYTHONPATH : "/home/vcap/app:/home/vcap/app/src:/home/vcap/deps/0"
    QUEUE_SERVICE_NAME : var.backend_queue_service_instance != "" ? var.backend_queue_service_instance : ""
  }

  # Container-specific environment variables
  container_env = {
    # No container-specific env vars needed at this time
  }

  # Process configurations - defined once and used in both processes block and hash generation
  backend_processes = [
    {
      type                       = "web"
      command                    = var.backend_deployment_method == "buildpack" ? "./bin/boot_server_in_docker" : "cat /etc/cf-system-certificates/* > /usr/local/share/ca-certificates/cf-system-certificates.crt && /usr/sbin/update-ca-certificates && ./bin/boot_server_in_docker"
      instances                  = var.backend_web_instances
      disk_quota                 = var.backend_web_disk
      memory                     = var.backend_web_memory
      health_check_type          = "http"
      health_check_http_endpoint = "/api/v1.0/status"
      timeout                    = 180
    },
    {
      type              = "worker"
      command           = var.backend_deployment_method == "buildpack" ? "./bin/start_celery_worker" : "cat /etc/cf-system-certificates/* > /usr/local/share/ca-certificates/cf-system-certificates.crt && /usr/sbin/update-ca-certificates && ./bin/start_celery_worker"
      instances         = var.backend_worker_instances
      disk_quota        = var.backend_worker_disk
      memory            = var.backend_worker_memory
      health_check_type = "process"
      timeout           = 180
    },
    {
      type              = "scheduler"
      command           = var.backend_deployment_method == "buildpack" ? "./bin/start_blocking_apscheduler" : "cat /etc/cf-system-certificates/* > /usr/local/share/ca-certificates/cf-system-certificates.crt && /usr/sbin/update-ca-certificates && ./bin/start_blocking_apscheduler"
      instances         = var.backend_queue_service_instance != "" ? 1 : 0
      disk_quota        = var.backend_scheduler_disk
      memory            = var.backend_scheduler_memory
      health_check_type = "process"
      timeout           = 180
    }
  ]
}

resource "random_password" "backend_flask_secret_key" {
  length  = 32
  special = true
}

resource "random_password" "backend_openid_secret" {
  length  = 32
  special = true
}

data "docker_registry_image" "backend" {
  count = var.backend_deployment_method == "container" ? 1 : 0
  name  = var.backend_imageref
}

# -----------------------------------------------------------------------------
# CLOUD FOUNDRY APP - Common resource with conditional properties based on deployment method
# -----------------------------------------------------------------------------
# Note: The backend app requires a PostgreSQL database service instance (aws-rds) to be bound.
# The database is specified via backend_database_service_instance variable.
# -----------------------------------------------------------------------------

resource "cloudfoundry_app" "backend" {
  name       = "${local.prefix}-backend"
  org_name   = var.cf_org_name
  space_name = var.cf_space_name

  # Commented out until the provider supports it
  # app_lifecycle = var.backend_deployment_method
  # strategy = "rolling"
  stack = "cflinuxfs4"

  # Conditional properties based on deployment method
  buildpacks = var.backend_deployment_method == "buildpack" ? ["python_buildpack"] : null
  docker_image = var.backend_deployment_method == "container" ? (
    length(data.docker_registry_image.backend) > 0 ?
    data.docker_registry_image.backend[0].name :
    var.backend_imageref
  ) : null
  path             = var.backend_deployment_method == "buildpack" ? var.backend_zip_path : null
  source_code_hash = var.backend_deployment_method == "buildpack" ? filebase64sha256(var.backend_zip_path) : null

  processes = local.backend_processes

  # Environment variables for the app - merge common env with deployment-method-specific env  
  environment = merge(
    local.backend_env,
    var.backend_deployment_method == "buildpack" ? local.buildpack_env : local.container_env,
    {
      # This hash will change whenever process configurations change; env var changes force an application restart
      TERRAFORM_PROCESS_HASH = md5(jsonencode(local.backend_processes))
    }
  )

  # Service bindings - always include the required database plus any additional bindings
  # Optionally include the queue service instance if set
  service_bindings = concat(
    # Required database service binding
    [{
      service_instance = var.backend_database_service_instance
      params           = (var.backend_database_params == "" ? "{}" : var.backend_database_params)
    }],
    # Optional queue service binding
    var.backend_queue_service_instance != "" ? [{
      service_instance = var.backend_queue_service_instance
      params           = (var.backend_queue_service_params == "" ? "{}" : var.backend_queue_service_params)
    }] : [],
    # Optional additional service bindings
    [
      for service_name, params in var.backend_additional_service_bindings : {
        service_instance = service_name
        params           = (params == "" ? "{}" : params)
      }
    ]
  )

  routes = [{
    route    = module.backend_route.endpoint
    protocol = "http1"
  }]
}


