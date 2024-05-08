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
  description = "base application name or id to be accessed at this domain name. Conflicts with var.app_names_or_ids"
  default     = null
}

variable "app_names_or_ids" {
  type        = list(string)
  description = "base application names or ids to be accessed at this domain name. Overwritten by var.app_name_or_id"
  default     = []
}

variable "name" {
  type        = string
  description = "name of the service instance. Required if not passing in app names or ids"
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

variable "tags" {
  description = "A list of tags to add to the resource"
  type        = list(string)
  default     = []
}
