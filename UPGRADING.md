# Upgrading from v1 to v2

The terraform-cloudgov modules have many backwards-incompatible changes between v1 and v2. These changes are mostly around:

1. Changing from the [cloudfoundry-community](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs) provider to the [cloudfoundry](https://registry.terraform.io/providers/cloudfoundry/cloudfoundry/latest/docs) provider.
1. Changes to inputs and outputs and resources created to better fit with the new provider and as the result of lessons learned over the life of the v1 code base.

## Using v1 and v2 together

It is possible to use modules from both v1 and v2 in the same root module, to ease migration (or even remain on v1 for existing resources and use v2 for new ones). We will continue to maintain the v1 branch for awhile with bug-fixes as needed.

Specify both providers in your root module (here, `cloudfoundry-community` is probably called `cloudfoundry` in your old module):

```
terraform {
  required_version = "~> 1.0"
  required_providers {
    cloudfoundry = {
      source = "cloudfoundry/cloudfoundry"
      version = "1.2.0"
    }

    cloudfoundry-community = {
      source  = "cloudfoundry-community/cloudfoundry"
      version = "0.53.1"
    }
  }
}

provider "cloudfoundry" {
  api_url      = "https://api.fr.cloud.gov"
  user         = var.cf_user
  password     = var.cf_password
}

provider "cloudfoundry-community" {
  api_url      = "https://api.fr.cloud.gov"
  user         = var.cf_user
  password     = var.cf_password
}
```

The v1 modules should properly select the `cloudfoundry-community` provider, but if they don't you may need to [explicitly set the provider](https://developer.hashicorp.com/terraform/language/modules/develop/providers#passing-providers-explicitly):

```
module "database" {
  source = "github.com/gsa-tts/terraform-cloudgov//database?ref=v1.1.0"
  providers = {
    cloudfoundry = cloudfoundry-community
  }

  # ...
}
```

## Provider Upgrades

Follow the steps in the [cloudfoundry provider migration guide](https://github.com/cloudfoundry/terraform-provider-cloudfoundry/blob/main/migration-guide/Readme.md) to migrate an existing use of the v1 module to v2. As an example, here are the steps for upgrading a database module:

1. Update source line to point to v2 module and change `cf_space_name` to `cf_space_id`
1. Verify that `terraform validate` passes
1. Run: `terraform state show module.database.cloudfoundry_service_instance.rds | grep -m 1 id` and copy the ID
1. Run: `terraform state rm module.database.cloudfoundry_service_instance.rds`
1. Run: `terraform import module.database.cloudfoundry_service_instance.rds ID_FROM_STEP_3`
1. Run: `terraform apply` to fill in new computed attributes

## Module Changes

### Common Changes

1. Check the `variables.tf` and `outputs.tf` files for each module for new names of variables and outputs. There should not be any variables or outputs that kept the same name but changed behavior.

### Egress Proxy

Egress Proxy no longer sets up network policies between the proxy and client apps, and does not create a User Provided Service Instance to deliver the credentials to the app. It is the developer's responsibility to do those things in the root module to better handle circular dependencies between creating the client app(s) and the proxy.

To setup the network policy in your root module, add:

```
resource "cloudfoundry_network_policy" "egress_policy" {
  provider = cloudfoundry-community
  policy {
    source_app      = cloudfoundry_app.client_app.id # assumes you're deploying the client app with terraform
    destination_app = module.egress_proxy.app_id
    port            = module.egress_proxy.https_port
  }
}
```

To add a UPSI:

```
resource "cloudfoundry_service_instance" "egress_proxy_credentials" {
  name        = "egress-proxy-credentials"
  space       = module.app_space.space_id
  type        = "user-provided"
  credentials = module.egress_proxy.json_credentials
}
```

### ClamAV

ClamAV no longer sets up network policies between the clamav app and client apps. It is the developer's responsibility to set this up to better handle circular dependencies between the various apps.

To setup the network policy in your root module, add:

```
resource "cloudfoundry_network_policy" "clamav_policy" {
  provider = cloudfoundry-community
  policy {
    source_app      = cloudfoundry_app.client_app.id # assumes you're deploying the client app with terraform
    destination_app = module.clamav_scanner.app_id
    port            = "61443"
  }
}
```

### cg_space

The new cg_space sets up all of the same resources and permissions as the old cg_space, however the way permissions are done is incompatible with the old provider and cannot be cleanly imported the way we can with the other providers.

This leads to a race condition where:

* The terraform user can't add itself with the new resource first, because it already has the permission that the resource is trying to create, but
* The terraform user can't remove itself from the old resource first, because then it doesn't have permission to re-add itself with the new resource.

To solve this involves some extra manual action:

1. Upgrade the space module source to v2 in your root module
1. `terraform apply -target=module.space.cloudfoundry_space_users.space_permissions` to remove the old permissions resources.
1. Manually add your terraform user as a SpaceDeveloper and a SpaceManager to the space.
    ```
    cf set-space-role CF_USER_GUID ORG SPACE SpaceDeveloper
    cf set-space-role CF_USER_GUID ORG SPACE SpaceManager
    ```
1. Ensure that your terraform user is _not_ listed in the terraform as a deployer, manager, or developer
1. `terraform apply` to add new permissions resources.
1. Use `cf unset-space-role` to remove the manual permissions settings or destroy the service account entirely to clean up after yourself.
1. (Optional, if you didn't destroy the service account) Re-add your terraform user to the terraform permissions configuration and have a different deployer apply it (like via CI/CD)
