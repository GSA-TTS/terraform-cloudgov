variable "cf_org_name" {
  type        = string
  description = "cloud.gov organization name"
}

variable "cf_space_name" {
  type        = string
  description = "cloud.gov space in which to deploy the apps"
}

variable "app_prefix" {
  type        = string
  description = "prefix to use for the three application names (<app_prefix>-[connector|backend|frontend])"
  default     = "spiffworkflow"
}

variable "route_prefix" {
  type        = string
  description = "prefix to use for the application routes (<route_prefix>-connector.app.internal, <route_prefix>.apps.fr.cloud.gov[/api])"
  default     = "spiffworkflow"
}

variable "rds_plan_name" {
  type        = string
  description = "PSQL database service plan to use"
  # See options at https://cloud.gov/docs/services/relational-database/#plans
  default = "small-psql"
}

variable "rds_json_params" {
  description = "A JSON string of arbitrary parameters"
  type        = string
  default     = null
  # See options at https://cloud.gov/docs/services/relational-database/#setting-optional-parameters-1
}

variable "tags" {
  description = "A list of tags to add to the module's resource"
  type        = set(string)
  default     = []
}

variable "process_models_repository" {
  type        = string
  description = "git repository with process models (for read-write, use SSH-style 'git@github.com:...' and supply your ssh_key)"
  default     = "https://github.com/GSA-TTS/gsa-process-models.git"
}

variable "process_models_ssh_key" {
  type        = string
  description = "private SSH key (only needed for read-write to SSH-style 'git@github.com:...' repositories)"
  # Should look like:
  # -----BEGIN OPENSSH PRIVATE KEY-----
  # ...
  # ...
  # ...
  # -----END OPENSSH PRIVATE KEY-----
  default = ""
}

variable "process_models_source_branch" {
  type        = string
  description = "branch for reading process models"
  default     = "main"
}

variable "process_models_publish_branch" {
  type        = string
  description = "branch for publishing process model changes"
  default     = "publish-branch"
}

variable "backend_memory" {
  type        = string
  description = "Memory to allocate to backend app, including units"
  default     = "512M"
}

variable "connector_memory" {
  type        = string
  description = "Memory to allocate to connector proxy app, including units"
  default     = "128M"
}

variable "frontend_memory" {
  type        = string
  description = "Memory to allocate to frontend app, including units"
  default     = "256M"
}

variable "backend_imageref" {
  type        = string
  description = "imageref for the specific version of the backend that you want to use. See https://github.com/orgs/GSA-TTS/packages for options."
  default     = "ghcr.io/gsa-tts/spiffworkflow-backend:deploy-to-cloud-gov-latest"
}

variable "connector_imageref" {
  type        = string
  description = "imageref for the specific version of the connector that you want to use. See https://github.com/orgs/GSA-TTS/packages for options."
  default     = "ghcr.io/gsa-tts/connector-proxy-demo:deploy-to-cloud-gov-latest"
}

variable "frontend_imageref" {
  type        = string
  description = "imageref for the specific version of the frontend that you want to use. See https://github.com/orgs/GSA-TTS/packages for options."
  default     = "ghcr.io/gsa-tts/spiffworkflow-frontend:deploy-to-cloud-gov-latest"
}

variable "backend_instances" {
  type        = number
  description = "the number of instances of the backend application to run (default: 1)"
  default     = 1
}

variable "connector_instances" {
  type        = number
  description = "the number of instances of the connector application to run (default: 1)"
  default     = 1
}

variable "frontend_instances" {
  type        = number
  description = "the number of instances of the frontend application to run (default: 1)"
  default     = 1
}