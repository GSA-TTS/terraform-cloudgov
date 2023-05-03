# terraform-cloudgov

Terraform modules for cloud.gov managed services commonly used by [18f/rails-template](https://github.com/18f/rails-template) based apps

## Module Examples

### database

Creates an RDS database based on the `rds_plan_name` variable and outputs the `instance_id` for use elsewhere.

```
module "database" {
  source = "github.com/18f/terraform-cloudgov//database?ref=v0.3.0"

  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  name             = "database_name"
  rds_plan_name    = "micro-psql"
}
```

### redis

Creates a Elasticache redis instance and outputs the `instance_id` for use elsewhere.

```
module "redis" {
  source = "github.com/18f/terraform-cloudgov//redis?ref=v0.3.0"

  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  name             = "redis_name"
  redis_plan_name  = "redis-dev"
}
```

### s3

Creates an s3 bucket and outputs the `bucket_id` for use elsewhere.

```
module "s3" {
  source = "github.com/18f/terraform-cloudgov//s3?ref=v0.3.0"

  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  name             = "${local.app_name}-s3-${local.env}"
}
```

### domain

Connects a custom domain name or domain name with CDN to an already running application and outputs the `instance_id` (for the domain service) and the `route_id` (for the origin route) for use elsewhere.

Note that the domain must be created in cloud.gov by an OrgManager before this module is included.

`cf create-domain CLOUD_GOV_ORG my-production-domain-name`

```
module "domain" {
  source = "github.com/18f/terraform-cloudgov//domain?ref=v0.3.0"

  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  app_name_or_id   = "app_name"
  cdn_plan_name    = "domain"
  domain_name      = "my-production-domain-name"
}
```

### clamav

Creates an application and associated network routing to run ClamAV via API to scan user uploads and outputs the `app_id`, the `route_id`, and the `endpoint` for use elsewhere.

Notes:
* The scanning app requires at least `3GB` of memory, and your `app_name` must be deployed before this module is included.
* Module `>= v0.3.0` requires `TAG_NAME` being `>= 20230228`.

```
module "clamav" {
  source = "github.com/18f/terraform-cloudgov//clamav?ref=v0.3.0"

  cf_org_name    = local.cf_org_name
  cf_space_name  = local.cf_space_name
  app_name_or_id = "app_name"
  name           = "my_clamav_name"
  clamav_image   = "ajilaag/clamav-rest:TAG_NAME"
  max_file_size  = "30M"
}
```

### cg_space

Creates a new cloud.gov space, such as when creating an egress space, and outputs the `space_id` for use elsewhere.

`managers`, `developers`, and `deployers` are all optional, but you probably want to set at least one of them, depending on your use case.

```
module "egress_space" {
  source = "github.com/18f/terraform-cloudgov//cg_space?ref=v0.3.0"

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
