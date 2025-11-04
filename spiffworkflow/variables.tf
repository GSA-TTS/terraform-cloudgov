variable "cf_org_name" {
  type        = string
  description = "cloud.gov organization name"
}

variable "cf_space_name" {
  type        = string
  description = "cloud.gov space in which to deploy the apps"
}

variable "name" {
  type        = string
  description = "A likely-unique prefix for app names (<name>-[frontend|backend|connector]) and route hostnames (<name>-connector.app.internal, <name>.apps.fr.cloud.gov[/api]). Must be compatible with hostname requirements, max of 52 characters. If none is provided, one will be generated."
  validation {
    condition     = var.name == null || (can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.name)) && length(var.name) >= 3 && length(var.name) <= 53)
    error_message = "The name must contain only lowercase letters, numbers, and hyphens, must start and end with a letter or number, and be between 3 and 53 characters long."
  }
}

variable "tags" {
  description = "A list of tags to add to the module's resource"
  type        = set(string)
  default     = []
}

variable "process_models_repository" {
  type        = string
  description = "Git repository with process models (use SSH-style 'git@github.com:...')"
  default     = ""
}

variable "process_models_ssh_key" {
  type        = string
  description = "Private SSH key with read/write access to var.process_models_repository repository"
  sensitive   = true
  # Should look like:
  # -----BEGIN OPENSSH PRIVATE KEY-----
  # ...
  # ...
  # ...
  # -----END OPENSSH PRIVATE KEY-----
  default = ""
}

variable "source_branch_for_example_models" {
  type        = string
  description = "branch for reading process models"
  default     = "main"
}

variable "target_branch_for_saving_changes" {
  type        = string
  description = "branch for publishing process model changes"
  default     = "draft"
}

###############################################################################
# Backend Variables
###############################################################################

variable "backend_deployment_method" {
  description = "Method to deploy the backend: 'buildpack' for Python buildpack or 'container' for a container image."
  type        = string
  default     = "container"

  validation {
    condition     = contains(["buildpack", "container"], var.backend_deployment_method)
    error_message = "The backend_deployment_method must be either 'buildpack' or 'container'."
  }
}

variable "backend_gitref" {
  description = "Git reference (branch, tag, or commit hash) for the upstream spiffworkflow-backend source. Only used when backend_deployment_method = 'buildpack'."
  type        = string
  default     = "github.com/sartography/spiff-arena?ref=v1.1.2"
}

variable "backend_imageref" {
  description = "Container image reference for the backend when using container deployment (backend_deployment_method = 'container'). Format: 'repository/image:tag' or 'repository/image@sha256:digest'"
  type        = string
  default     = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-backend:latest"
}

variable "backend_process_models_path" {
  description = "Path to the local process_models directory to include in the backend. Only used when backend_deployment_method = 'buildpack'."
  type        = string
  default     = "process_models"

  validation {
    condition     = var.backend_process_models_path != "" || var.backend_deployment_method == "container"
    error_message = "backend_process_models_path must be provided when using backend_deployment_method = 'buildpack'."
  }
}

variable "backend_scripts_path" {
  description = "Path to a directory of supplemental backend scripts (e.g. init_process.py, profile hooks). Ignored for container deployment."
  type        = string
  default     = ""
}

variable "backend_python_version" {
  description = "Python version to use for the backend when using buildpack deployment"
  type        = string
  default     = "python-3.12.x"
}

variable "backend_web_disk" {
  description = "Disk quota for the SpiffWorkflow backend web app, including unit"
  type        = string
  default     = "1024M"
}

variable "backend_web_memory" {
  description = "Memory allocation for the SpiffWorkflow backend web app, including unit"
  type        = string
  default     = "512M"
}

variable "backend_web_instances" {
  description = "Number of instances for the SpiffWorkflow backend web app"
  type        = number
  default     = 1
}

variable "backend_worker_disk" {
  description = "Disk quota for the SpiffWorkflow backend worker app, including unit"
  type        = string
  default     = "1024M"
}

variable "backend_worker_memory" {
  description = "Memory allocation for the SpiffWorkflow backend worker app, including unit"
  type        = string
  default     = "1024M"
}

variable "backend_worker_instances" {
  description = "Number of instances for the SpiffWorkflow backend worker app"
  type        = number
  default     = 0
  validation {
    condition     = var.backend_queue_service_instance == "" || (var.backend_worker_instances >= 1)
    error_message = "If backend_queue_service_instance is set, backend_worker_instances must be at least 1."
  }
}

variable "backend_scheduler_disk" {
  description = "Disk quota for the SpiffWorkflow backend scheduler app, including unit"
  type        = string
  default     = "1024M"
}

variable "backend_scheduler_memory" {
  description = "Memory allocation for the SpiffWorkflow backend scheduler app, including unit"
  type        = string
  default     = "512M"
}

variable "backend_environment" {
  description = "Additional environment variables for the SpiffWorkflow backend app"
  type        = map(string)
  default     = {}
}

variable "backend_database_service_instance" {
  description = "Name of the Postgres service instance to bind to the backend app. Must be an aws-rds service instance of type postgres."
  type        = string
}

variable "backend_database_params" {
  description = "JSON parameter string for the database service binding. Empty string means no parameters."
  type        = string
  default     = ""
}

variable "backend_queue_service_instance" {
  description = "Name of the message queue service instance to bind to the backend app. Currently only Redis is supported. Leave empty to disable queue functionality."
  type        = string
  default     = ""
}

variable "backend_queue_service_params" {
  description = "JSON parameter string for the message queue service binding. Empty string means no parameters."
  type        = string
  default     = ""
}

# Example of additional service bindings:
# backend_additional_service_bindings = {
#   "my-service" = "",
#   (module.my-other-service.name) = "",
#   "yet-another-service" = <<-EOT
#      {
#        "astring"     : "foo",
#        "anarray"     : ["bar", "baz"],
#        "anarrayobjs" : [
#          {
#            "name": "bat",
#            "value": "boz"
#          }
#        ]
#      }
#      EOT
# }
variable "backend_additional_service_bindings" {
  description = "A map of additional service instance names to JSON parameter strings for optional service bindings."
  type        = map(string)
  default     = {}
}

###############################################################################
# Backend OIDC Authentication Variables
###############################################################################

variable "backend_oidc_client_id" {
  description = "Optional OIDC client ID for external authentication provider. If not provided, internal OIDC will be used."
  type        = string
  default     = null
}

variable "backend_oidc_client_secret" {
  description = "Optional OIDC client secret for external authentication provider. Required if backend_oidc_client_id is provided."
  type        = string
  sensitive   = true
  default     = null
}

variable "backend_oidc_server_url" {
  description = "Optional OIDC server URL for external authentication provider. Required if backend_oidc_client_id is provided."
  type        = string
  default     = null
}

variable "backend_oidc_additional_valid_client_ids" {
  description = "Optional comma-separated list of additional valid client IDs for OIDC authentication."
  type        = string
  default     = null
}

variable "backend_oidc_additional_valid_issuers" {
  description = "Optional comma-separated list of additional valid issuers for OIDC authentication."
  type        = string
  default     = null
}

variable "backend_oidc_authentication_providers" {
  description = "Optional authentication providers configuration (e.g., 'default:openid')."
  type        = string
  default     = null
}

variable "backend_oidc_scope" {
  description = "Optional OAuth scopes for OIDC authentication (e.g., 'openid profile email groups'). Defaults to 'openid' for cloud.gov compatibility."
  type        = string
  default     = "openid"
}

###############################################################################
# Connector Variables
###############################################################################

variable "connector_deployment_method" {
  description = "Method to deploy the connector: 'buildpack' for Python buildpack or 'container' for a container image."
  type        = string
  default     = "container"

  validation {
    condition     = contains(["buildpack", "container"], var.connector_deployment_method)
    error_message = "The connector_deployment_method must be either 'buildpack' or 'container'."
  }
}

variable "connector_memory" {
  type        = string
  description = "Memory to allocate to connector proxy app, including units"
  default     = "128M"
}

variable "connector_imageref" {
  type        = string
  description = "imageref for the specific version of the connector that you want to use. See https://github.com/orgs/GSA-TTS/packages for options."
  default     = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-connector:latest"
}

variable "connector_instances" {
  type        = number
  description = "the number of instances of the connector application to run (default: 1)"
  default     = 1
}

variable "connector_local_path" {
  description = "Path to the local connector directory to deploy. Only used when connector_deployment_method = 'buildpack'."
  type        = string
  default     = "service-connector"

  validation {
    condition     = var.connector_local_path != "" || var.connector_deployment_method == "container"
    error_message = "connector_local_path must be provided when using connector_deployment_method = 'buildpack'."
  }
}

variable "connector_python_version" {
  description = "Python version to use for the connector when using buildpack deployment"
  type        = string
  default     = "python-3.12.x"
}

variable "connector_disk" {
  description = "Disk quota for the connector app, including unit"
  type        = string
  default     = "3G"
}

# Example of additional service bindings:
# connector_additional_service_bindings = {
#   "my-service" = "",
#   (module.my-other-service.name) = "",
#   "yet-another-service" = <<-EOT
#      {
#        "astring"     : "foo",
#        "anarray"     : ["bar", "baz"],
#        "anarrayobjs" : [
#          {
#            "name": "bat",
#            "value": "boz"
#          }
#        ]
#      }
#      EOT
# }
variable "connector_additional_service_bindings" {
  description = "A map of additional service instance names to JSON parameter strings for optional service bindings for the connector."
  type        = map(string)
  default     = {}
}

###############################################################################
# Frontend Variables
###############################################################################

variable "frontend_memory" {
  type        = string
  description = "Memory to allocate to frontend app, including units"
  default     = "256M"
}

variable "frontend_imageref" {
  type        = string
  description = "imageref for the specific version of the frontend that you want to use. See https://github.com/orgs/GSA-TTS/packages for options."
  default     = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-frontend:latest"
}

variable "frontend_instances" {
  type        = number
  description = "the number of instances of the frontend application to run (default: 1)"
  default     = 1
}
