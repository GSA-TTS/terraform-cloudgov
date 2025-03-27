variable "cf_org_name" {
  type        = string
  description = "cloud.gov organization name"
}

variable "cf_space_name" {
  type        = string
  description = "cloud.gov space name"
}

variable "app_ids" {
  type        = set(string)
  description = "The list of app IDs the route should send traffic to"
}

variable "hostname" {
  type        = string
  description = "The hostname to route to"
}

variable "domain" {
  type        = string
  description = "The domain "
  default     = "app.cloud.gov"
}
