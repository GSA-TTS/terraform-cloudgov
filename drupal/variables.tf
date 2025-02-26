variable "cf_org_name" {
  type        = string
  description = "cloud.gov org name"
}

variable "cf_space" {
  type        = object({ id = string, name = string })
  description = "cloud.gov space"
}

variable "name" {
  type        = string
  description = "Name of the Drupal application"
}

variable "route" {
  type        = string
  default     = null
  description = "The route to serve the application on. Defaults to 'var.name.app.cloud.gov'"
}

variable "rds_plan_name" {
  type        = string
  description = "database service plan to use"
  # See options at https://cloud.gov/docs/services/relational-database/#plans
  validation {
    condition     = can(regex("^.*mysql.*$", var.rds_plan_name))
    error_message = "Must use a mysql db plan"
  }
}

variable "s3_plan_name" {
  type        = string
  description = "s3 service plan to use"
  # See options at https://cloud.gov/docs/services/s3/#plans
}

variable "tags" {
  description = "A list of tags to add to the resource"
  type        = set(string)
  default     = []
}

variable "source_dir" {
  description = "The directory containing the drupal app source code"
  type        = string
}

variable "extra_excludes" {
  description = "Any files or directories that should be excluded from inclusion in the application"
  type        = set(string)
  default     = []
}

variable "credentials" {
  description = "Secrets to set within the secrets service"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "app_environment" {
  description = "ENV variables to pass along to the environment"
  type        = map(string)
  default     = {}
}

variable "app_instances" {
  description = "The number of app instances to run"
  type        = number
  default     = 1
}

variable "app_memory" {
  description = "The amount of memory to allocate to each app, with unit"
  type        = string
  default     = "256M"
}
