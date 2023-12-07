# terraform-cloudgov

Terraform modules for working with cloud.gov commonly used by [18f/rails-template](https://github.com/18f/rails-template) based apps

## Usage

Specify acceptable versions of these modules using an [NPM-style version constraint](https://github.com/npm/node-semver#versions), using our [semver module](./semver). ([Terraform doesn't support version constraints for github-hosted modules](https://developer.hashicorp.com/terraform/language/modules/sources#github).)

```terraform
# Specify a (NPM-style) version constraint for the modules you use
locals {
  module_versions = {
    database = "^0.x", # major version 0
    s3       = "^0.x"  # major version 0
  }
}

# Find the most recent versions matching those constraints...
module "version" {
  for_each           = local.module_versions
  source             = "github.com/18f/terraform-cloudgov//semver"
  version_constraint = each.value
}

# ...then refer to the source for those modules using the calculated versions, as demonstrated below
```

## Module Examples

### database

Creates an RDS database based on the `rds_plan_name` variable and outputs the `instance_id` for use elsewhere.

```
module "database" {
  source = "github.com/18f/terraform-cloudgov//database?ref=v${module.version["database"].target_version}"

  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  name             = "database_name"
  rds_plan_name    = "micro-psql"
  tags             = ["tag1", "tag2"]
}
```

### redis

Creates a Elasticache redis instance and outputs the `instance_id` for use elsewhere.

```
module "redis" {
  source = "github.com/18f/terraform-cloudgov//redis?ref=v${module.version["redis"].target_version}"

  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  name             = "redis_name"
  redis_plan_name  = "redis-dev"
  tags             = ["tag1", "tag2"]
}
```

### s3

Creates an s3 bucket and outputs the `bucket_id` for use elsewhere.

```
module "s3" {
  source = "github.com/18f/terraform-cloudgov//s3?ref=v${module.version["s3"].target_version}"

  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  name             = "${local.app_name}-s3-${local.env}"
  tags             = ["tag1", "tag2"]
}
```

### domain

Connects a custom domain name or domain name with CDN to an already running application and outputs the `instance_id` (for the domain service) and the `route_id` (for the origin route) for use elsewhere.

Note that the domain must be created in cloud.gov by an OrgManager before this module is included.

`cf create-domain CLOUD_GOV_ORG my-production-domain-name`

```
module "domain" {
  source = "github.com/18f/terraform-cloudgov//domain?ref=v${module.version["domain"].target_version}"

  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  app_name_or_id   = "app_name"
  cdn_plan_name    = "domain"
  domain_name      = "my-production-domain-name"
  host_name        = "my-production-host-name"
  tags             = ["tag1", "tag2"]
}
```

### clamav

Creates an application and associated network routing to run ClamAV via API to scan user uploads and outputs the `app_id`, the `route_id`, and the `endpoint` for use elsewhere.

Notes:
* The scanning app requires at least `3GB` of memory, and your `app_name` must be deployed before this module is included.
* Module `>= v0.3.0` requires `TAG_NAME` being `>= 20230228`.

```
module "clamav" {
  source = "github.com/18f/terraform-cloudgov//clamav?ref=v${module.version["clamav"].target_version}"

  cf_org_name    = local.cf_org_name
  cf_space_name  = local.cf_space_name
  app_name_or_id = "app_name"
  name           = "my_clamav_name"
  clamav_image   = "ghcr.io/gsa-tts/clamav-rest/clamav:TAG_NAME"
  max_file_size  = "30M"
  proxy_server   = local.proxy_server # https proxy to reach database.clamav.net:443, if necessary
  proxy_port     = local.proxy_port
  proxy_username = local.proxy_username
  proxy_password = local.proxy_password
}
```

### cg_space

Creates a new cloud.gov space, such as when creating an egress space, and outputs the `space_id` for use elsewhere.

`managers`, `developers`, and `deployers` are all optional, but you probably want to set at least one of them, depending on your use case.

```
module "egress_space" {
  source = "github.com/18f/terraform-cloudgov//cg_space?ref=v${module.version["cg_space"].target_version}"

  cf_org_name   = local.cf_org_name
  cf_space_name = "${local.cf_space_name}-egress"
  managers = [
    "space.manager@gsa.gov"
  ]
  developers = [
    "space.developer@gsa.gov"
  ]
  deployers = [
    var.cf_user
  ]
}
```
