# terraform-cloudgov

Terraform modules for working with cloud.gov commonly used by [GSA-TTS/rails-template](https://github.com/GSA-TTS/rails-template) based apps

## Module Examples

### database

Creates an RDS database based on the `rds_plan_name` variable and outputs the `instance_id` for use elsewhere.

```
module "database" {
  source = "github.com/GSA-TTS/terraform-cloudgov//database?ref=v2.0.0-beta.1"

  cf_space_id   = data.cloudfoundry_space.app_space.id
  name          = "database_name"
  rds_plan_name = "micro-psql"
  tags          = ["tag1", "tag2"]
  # See options at https://cloud.gov/docs/services/relational-database/#setting-optional-parameters-1
  json_params   = jsonencode(
    {
      "storage" : 10,
    }
  )
}
```

### redis

Creates a Elasticache redis instance and outputs the `instance_id` for use elsewhere.

```
module "redis" {
  source = "github.com/GSA-TTS/terraform-cloudgov//redis?ref=v2.0.0-beta.1"

  cf_space_id     = data.cloudfoundry_space.app_space.id
  name            = "redis_name"
  redis_plan_name = "redis-dev"
  tags            = ["tag1", "tag2"]
  # See options at https://cloud.gov/docs/services/aws-elasticache/#setting-optional-parameters
  json_params     = jsonencode(
    {
      "engineVersion" : "7.0",
    }
  )
}
```

### s3

Creates an s3 bucket and outputs the `bucket_id` for use elsewhere.

```
module "s3" {
  source = "github.com/GSA-TTS/terraform-cloudgov//s3?ref=v1.1.0"

  cf_org_name      = local.cf_org_name
  cf_space_name    = local.cf_space_name
  name             = "${local.app_name}-s3-${local.env}"
  tags             = ["tag1", "tag2"]
  # See options at https://cloud.gov/docs/services/s3/#setting-optional-parameters
  json_params      = jsonencode(
    {
      "object_ownership" : "ObjectWriter",
    }
  )
}
```

### domain

Connects a custom domain name or domain name with CDN to an already running application and outputs the `instance_id` (for the domain service) and the `route_id` (for the origin route) for use elsewhere.

Note that the domain must be created in cloud.gov by an OrgManager before this module is included.

`cf create-domain CLOUD_GOV_ORG my-production-domain.name`

```
module "domain" {
  source = "github.com/GSA-TTS/terraform-cloudgov//domain?ref=v2.0.0-beta.1"

  cf_org_name   = local.cf_org_name
  cf_space      = data.cloudfoundry_space.app_space
  app_names     = ["app_name"]
  cdn_plan_name = "domain"
  domain_name   = "my-production-domain.name"
  host_name     = "my-production-host-name"
  tags          = ["tag1", "tag2"]
}
```

### clamav

Creates an application and associated network routing to run ClamAV via API to scan user uploads and outputs the `app_id`, the `route_id`, and the `endpoint` for use elsewhere.

Notes:
* The scanning app requires at least `3GB` of memory, and your `app_name` must be deployed before this module is included.
* Module `>= v0.3.0` requires `TAG_NAME` being `>= 20230228`.

```
module "clamav" {
  source = "github.com/GSA-TTS/terraform-cloudgov//clamav?ref=v2.0.0-beta.1"

  cf_org_name    = local.cf_org_name
  cf_space       = data.cloudfoundry_space.app_space
  app_name       = "app_name"
  name           = "my_clamav_name"
  clamav_image   = "ghcr.io/gsa-tts/clamav-rest/clamav:TAG_NAME"
  max_file_size  = "30M"
  instances      = 2
  proxy_server   = local.proxy_server # https proxy to reach database.clamav.net:443, if necessary
  proxy_port     = local.proxy_port
  proxy_username = local.proxy_username
  proxy_password = local.proxy_password
}
```

### cg_space

Creates a new cloud.gov space, such as when creating an egress space, and outputs the `space_id` for use elsewhere.

`managers`, `developers`, and `deployers` are all optional, but you probably want to set at least one of them, depending on your use case.

* `managers` are granted the [Space Manager](https://docs.cloudfoundry.org/concepts/roles.html#activeroles) role
* `developers` are granted the [Space Developer](https://docs.cloudfoundry.org/concepts/roles.html#activeroles) role
* `deployers` are granted both manager and developer roles

```
module "egress_space" {
  source = "github.com/GSA-TTS/terraform-cloudgov//cg_space?ref=v2.0.0-beta.1"

  cf_org_name   = local.cf_org_name
  cf_space_name = "${local.cf_space_name}-egress"
  allow_ssh     = false
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

### egress_proxy

Creates and configures an instance of cg-egress-proxy to proxy traffic from your apps.

Prerequities:

* existing client_space with already deployed apps
* existing public-egress space to deploy the proxy into

```
module "egress_proxy" {
  source = "github.com/GSA-TTS/terraform-cloudgov//egress_proxy?ref=v1.1.0"

  cf_org_name     = local.cf_org_name
  cf_egress_space = data.cloudfoundry_space.egress_space
  cf_client_space = data.cloudfoundry_space.app_space
  name            = "egress-proxy"
  allowlist = {
    "source_app_name" = ["host.com:443", "otherhost.com:443"]
  }
  # see egress_proxy/variables.tf for full list of optional arguments
}
```

## Testing


> [!WARNING]
> Tests provision resources in the real world when not using `mock_provider`! Take care that `CF_USER`/`CF_PASSWORD` are set to an account in a suitable non-production space. If other providers, such as the AWS provider, are used, ensure the same care is taken with their credentials in your shell before running `terraform test`.

[Terraform tests](https://developer.hashicorp.com/terraform/language/tests) are in progress of being written. To run for any module with a `tests` directory:

1. Set `CF_USER` and `CF_PASSWORD` env variables with SpaceDeployer credentials that can access the space(s) being used for tests
1. cd to module root. Example: `cd s3`
1. Run `terraform init`
1. Run `terraform test`

When updating code, try to cover every input and output variable with at least one test to verify it is connected properly.
