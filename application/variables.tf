variable "cf_org_name" {
  type        = string
  description = "cloud.gov organization name"
}

variable "cf_space_name" {
  type        = string
  description = "cloud.gov space name"
}

variable "environment_map" {
  description = "A map of environment values."
  type        = map(string)
}

variable "buildpacks" {
  description = "A list of buildpacks to add to the app resource."
  type        = set(string)
  default     = []
}

variable "name" {
  description = "The name of the application to deploy"
  type        = string
}

variable "branch_name" {
  description = "Branch name for deploying the src code. Using a '/' (abc/xyz) in the branch name will confuse terraform, as it will attempt to get refs/heads/abc/xyx"
  type        = string
}

variable "github_org_name" {
  description = "The name of the github organization. (ex. gsa-tts)"
  type        = string
  default     = "gsa-tts"
}

variable "github_repo_name" {
  description = "The name of the github repo (ex. fac, terraform-cloudgov, etc)"
  type        = string
}

variable "src_code_folder_name" {
  description = "The name of the folder that contains your src code. Generally the folder that would contain your Procfile. This will be used as the apps /app/ dir."
  type        = string
}

variable "app_memory" {
  type        = string
  description = "Memory to allocate to app, including unit"
  default     = "2048M"
}

variable "disk_space" {
  type = string
  description = "Memory to allocate for disk to app, including unit"
  default = "2048M"
}

variable "instances" {
  type        = number
  description = "The number of instances for the application"
  default     = 1
}

variable "public_s3_name" {
  type        = string
  description = "The name of the public s3 bucket to bind to the app (eg. staticfiles storage)"
}

variable "db_name" {
  type        = string
  description = "The name of the db to bind to the app"
}
