variable "cf_api_url" {
  type        = string
  description = "cloud.gov api url"
  default     = "https://api.fr.cloud.gov"
}

variable "cf_user" {
  type        = string
  description = "cloud.gov deployer account user"
}

variable "cf_password" {
  type        = string
  description = "secret; cloud.gov deployer account password"
  sensitive   = true
}

variable "cf_org_name" {
  type        = string
  description = "cloud.gov organization name"
}

variable "cf_space_name" {
  type        = string
  description = "cloud.gov space name to create"
}

variable "managers" {
  type        = set(string)
  description = "list of cloud.gov users to be assigned to the SpaceManager role"
  default     = []
}

variable "developers" {
  type        = set(string)
  description = "list of cloud.gov users to be assigned to the SpaceDeveloper role"
  default     = []
}

variable "deployers" {
  type        = set(string)
  description = "list of cloud.gov users to be assigned both SpaceManager and SpaceDeveloper roles"
  default     = []
}
