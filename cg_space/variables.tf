variable "cf_org_name" {
  type        = string
  description = "cloud.gov organization name"
}

variable "cf_space_name" {
  type        = string
  description = "cloud.gov space name to create"
}

variable "allow_ssh" {
  type        = bool
  description = "whether to allow ssh access to apps running in this space"
  default     = false
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
