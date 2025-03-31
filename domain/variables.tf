variable "cf_org_name" {
  type        = string
  description = "cloud.gov organization name"
}

variable "cf_space" {
  type = object({
    id   = string
    name = string
  })
  description = "cloud.gov space resource"
}

variable "app_ids" {
  type        = list(string)
  description = "Application IDs to be accessed at this domain name."
  default     = []
}

variable "name" {
  type        = string
  description = "name of the service instance"
  default     = null
}

variable "cdn_plan_name" {
  type        = string
  description = "name of the service plan name to create"
}

variable "create_domain" {
  type        = bool
  default     = false
  description = "Set to true to create the domain resource. Requires the OrgManager role."
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
