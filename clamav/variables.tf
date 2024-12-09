variable "cf_org_name" {
  type        = string
  description = "cloud.gov organization name"
}

variable "cf_space_name" {
  type        = string
  description = "cloud.gov space name"
}

variable "name" {
  type        = string
  description = "name of the clamav scanning application"
}

variable "clamav_image" {
  type        = string
  description = "Docker image to deploy the clamav api app"
}

variable "clamav_memory" {
  type        = string
  description = "Memory to allocate to clamav app"
  default     = "3072M"
}

variable "max_file_size" {
  type        = string
  description = "Maximum file size the API will accept for scanning"
}

variable "proxy_server" {
  type        = string
  description = "domain name for the https proxy to use for outbound connections, eg to database.freshclam.net"
  default     = ""
}

variable "proxy_port" {
  type        = string
  description = "port for use with proxy_server, eg 61443"
  default     = ""
}

variable "proxy_username" {
  type        = string
  description = "username for proxy_server, eg a-username"
  default     = ""
}

variable "proxy_password" {
  type        = string
  description = "password for proxy_server, eg a-password"
  default     = ""
}

variable "instances" {
  type        = number
  description = "the number of instances that the clamav module should operate (default 1)"
  default     = 1
}
