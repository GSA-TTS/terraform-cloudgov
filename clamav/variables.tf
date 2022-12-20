variable "cf_org_name" {
  type        = string
  description = "cloud.gov organization name"
}

variable "cf_space_name" {
  type        = string
  description = "cloud.gov space name (staging or prod)"
}

variable "app_name" {
  type        = string
  description = "base application name to be scanned by clamav"
}

variable "env" {
  type        = string
  description = "deployment environment (staging, production)"
}

variable "clamav_image" {
  type        = string
  description = "Docker image to deploy the clamav api app"
}

variable "clamav_memory" {
  type        = number
  description = "Memory in MB to allocate to clamav app"
  default     = 3072
}

variable "max_file_size" {
  type        = string
  description = "Maximum file size the API will accept for scanning"
}
