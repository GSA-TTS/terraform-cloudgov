# terraform-cloudgov/semver 

Find a tag for this repository matching NPM-style version constraints

## Example

```terraform
# Specify a version constraint for each module we plan to use
locals {
  module_versions = {
    database = ">0.5.0",
    s3       = ">0.6.0"
  }
}

# Divine the most recent versions matching those constraints...
module "version" {
  for_each           = local.module_versions
  source             = "github.com/18f/terraform-cloudgov//semver"
  version_constraint = each.value
}

# ...then refer to the source for those modules using the calculated versions.

module "database" {
  source = "github.com/18f/terraform-cloudgov//database?ref=v${module.version["database"].target_version}"
  # [...]
}

module "s3" {
  source = "github.com/18f/terraform-cloudgov//s3?ref=v${module.version["s3"].target_version}"
  # [...]
}
```

