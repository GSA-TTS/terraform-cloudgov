variable "name" {
  type        = string
  description = "name of the scanner application"
}

variable "cf_org_name" {
  type        = string
  description = "cloud.gov organization name"
}

variable "cf_space" {
  type        = object({ id = string, name = string })
  description = "cloud.gov space"
}

variable "buildpacks" {
  description = "A list of buildpacks to add to the app resource."
  type        = list(string)
}

variable "gitref" {
  type        = string
  description = "gitref for the specific version of scanner that you want to use"
  default     = "refs/heads/main"
  # You can also specify a specific commit, eg "7487f882903b9e834a5133a883a88b16fb8b16c9"
}

variable "scanner_memory" {
  type        = string
  description = "Memory in MB to allocate to scanner app instance"
  default     = "512M"
}

variable "scanner_instances" {
  type        = number
  description = "the number of instances of the scanner app to run (default: 1)"
  default     = 1
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
  description = "The name of the folder that contains your src code without a trailing '/'. Generally the folder that would contain your Procfile. This will be used as the apps /app/ dir."
  type        = string
  # Examples:
  # "" -> Project to deploy is in the root of the repo
  # "backend" -> Project to deploy is in the backend/ directory
  # "backend/app" -> Project to deploy is in the backend/app directory
}

variable "disk_quota" {
  type        = string
  description = "disk in MB to allocate to cg-logshipper app instance"
  default     = "512M"
}

variable "https_proxy_url" {
  type        = string
  description = "the full string of the https proxy for use with the logshipper app"
  sensitive   = true
}

variable "hostname" {
  description = "The hostname to route to. Combined with var.domain for the full route. Defaults to var.name if omitted"
  type        = string
  default     = null
}

# Example:
# service_bindings = {
#   my-service = "",
#   (module.my-other-service.name) = "",
#   yet-another-service = <<-EOT
#      {
#        "astring"     : "foo",
#        "anarray"     : ["bar", "baz"],
#        "anarrayobjs" : [
#          {
#            "name": "bat",
#            "value": "boz"
#        ],
#      }
#      EOT
#   }
# }
variable "service_bindings" {
  description = "A map of service instance name to JSON parameter string."
  type        = map(string)
  default     = {}
}

variable "environment_variables" {
  description = "A map of environment values."
  type        = map(string)
  default     = {}
}
