# terraform-cloudgov

Terraform modules for cloud.gov managed services commonly used by [18f/rails-template](https://github.com/18f/rails-template) based apps

## Module Examples

### database

Creates an RDS database based on the `rds_plan_name` variable

```
module "database" {
  source = "github.com/18f/terraform-cloudgov//database"

  cf_user          = var.cf_user
  cf_password      = var.cf_password
  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  name             = "database_name"
  rds_plan_name    = "micro-psql"
}
```

### redis

Creates a Elasticache redis instance

```
module "redis" {
  source = "github.com/18f/terraform-cloudgov//redis"

  cf_user          = var.cf_user
  cf_password      = var.cf_password
  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  name             = "redis_name"
  redis_plan_name  = "redis-dev"
}
```

### s3

Creates an s3 bucket and outputs the bucket_id

```
module "s3" {
  source = "github.com/18f/terraform-cloudgov//s3"

  cf_user          = var.cf_user
  cf_password      = var.cf_password
  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  name             = "${local.app_name}-s3-${local.env}"
}
```

### domain

Connects a custom domain name or domain name with CDN to an already running application.

Note that the domain must be created in cloud.gov by an OrgManager before this module is included.

`cf create-domain CLOUD_GOV_ORG TKTK-production-domain-name`

```
module "domain" {
  source = "github.com/18f/terraform-cloudgov//domain"

  cf_user          = var.cf_user
  cf_password      = var.cf_password
  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  app_name_or_id   = "app_name"
  cdn_plan_name    = "domain"
  domain_name      = "my-production-domain-name"
}
```

### clamav

Creates an application and associated network routing to run ClamAV via API to scan user uploads.

The scanning app requires at least 3GB of memory, and your app_name must be deployed before this module is included.

```
module "clamav" {
  source = "github.com/18f/terraform-cloudgov//clamav"

  cf_user       = var.cf_user
  cf_password   = var.cf_password
  cf_org_name   = local.cf_org_name
  cf_space_name = local.cf_space_name
  name          = "my_clamav_name"
  clamav_image  = "ajilaag/clamav-rest:TAG_NAME"
  max_file_size = "30M"
}
```

### cg_space

Creates a new cloud.gov space, such as when creating an egress space.

`managers`, `developers`, and `deployers` are all optional, but you probably want to set at least one of them, depending on your use case.

```
module "egress_space" {
  source = "github.com/18f/terraform-cloudgov//cg_space"

  cf_user       = var.cf_user
  cf_password   = var.cf_password
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
