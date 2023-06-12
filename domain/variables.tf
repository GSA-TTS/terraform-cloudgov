variable "cf_org_name" {
  type        = string
  description = "cloud.gov organization name"
}

variable "cf_space_name" {
  type        = string
  description = "cloud.gov space name (staging or prod)"
}

variable "app_name_or_id" {
  type        = string
  description = "base application name to be accessed at this domain name"
}

variable "recursive_delete" {
  type        = bool
  description = "when true, deletes service bindings attached to the resource (not recommended for production)"
  default     = false
}

variable "name" {
  type        = string
  description = "name of the service instance"
  default     = ""
}

variable "cdn_plan_name" {
  type        = string
  description = "name of the service plan name to create"
}

variable "domain_name" {
  type        = string
  description = "Domain name users will use to access the application"
}

variable "host_name" {
  type        = string
  description = "Host name users will use to access the application"
  default     = null
}
