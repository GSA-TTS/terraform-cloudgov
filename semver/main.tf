# This is just a thin wrapper around the following module, prefilling
# the 18f/terraform-cloudgov repository
# https://registry.terraform.io/modules/rhythmictech/find-release-by-semver

# Just accepts the one parameter
variable "version_constraint" {
  type        = string
  description = "The NPM-style version constraint you want to use to find the right version"
}

module "find-cloudgov-module-version" {
  source  = "rhythmictech/find-release-by-semver/github"
  version = "~> 1.1.2"

  repo_name          = "terraform-cloudgov"
  repo_owner         = "18f"
  version_constraint = var.version_constraint
}

output "target_version" {
  description = "Version matched to constraint"
  value       = module.find-cloudgov-module-version.target_version
}

output "version_info" {
  description = "All available info about the target release"
  value       = module.find-cloudgov-module-version.version_info
}
