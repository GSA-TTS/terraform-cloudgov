# terraform-cloudgov

Terraform modules for working with cloud.gov commonly used by [GSA-TTS/rails-template](https://github.com/GSA-TTS/rails-template) based apps

> [!IMPORTANT]
> The cloudfoundry v2 api [is being deprecated](https://cloud.gov/2025/01/07/v2api-deprecation/) on June 6, 2025.
> terraform-cloudgov modules >= 2.0.0 are fully compatible with this change. If you are using a v1.x module, you must
> see [the UPGRADING guide](./UPGRADING.md) and update to the most recent versions before then.

## Module Examples

### database

Creates an RDS database based on the `rds_plan_name` variable and outputs the `instance_id` for use elsewhere.

```
module "database" {
  source = "github.com/GSA-TTS/terraform-cloudgov//database?ref=v2.1.0"

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
  source = "github.com/GSA-TTS/terraform-cloudgov//redis?ref=v2.1.0"

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
  source = "github.com/GSA-TTS/terraform-cloudgov//s3?ref=v2.1.0"

  cf_space_id = data.cloudfoundry_space.app_space.id
  name        = "${local.app_name}-s3-${local.env}"
  tags        = ["tag1", "tag2"]
  # See options at https://cloud.gov/docs/services/s3/#setting-optional-parameters
  json_params = jsonencode(
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
  source = "github.com/GSA-TTS/terraform-cloudgov//domain?ref=v2.1.0"

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

Creates an application to run ClamAV via API to scan user uploads and outputs the `app_id`, the `route_id`, and the `endpoint` for use elsewhere.

Notes:
* The scanning app requires at least `3GB` of memory, and your `app_name` must be deployed before this module is included.
* Module `>= v0.3.0` requires `TAG_NAME` being `>= 20230228`.

```
module "clamav" {
  source = "github.com/GSA-TTS/terraform-cloudgov//clamav?ref=v2.1.0"

  cf_org_name    = local.cf_org_name
  cf_space_name  = local.cf_space_name
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

See <UPGRADING.md> for an example of how to set up network policies to reach the clamav app from the client apps.

### cg_space

Creates a new cloud.gov space, such as when creating an egress space, and outputs the `space_id` for use elsewhere.

`managers`, `developers`, and `deployers` are all optional, but you probably want to set at least one of them, depending on your use case.

* `managers` are granted the [Space Manager](https://docs.cloudfoundry.org/concepts/roles.html#activeroles) role
* `developers` are granted the [Space Developer](https://docs.cloudfoundry.org/concepts/roles.html#activeroles) role
* `deployers` are granted both manager and developer roles

```
module "egress_space" {
  source = "github.com/GSA-TTS/terraform-cloudgov//cg_space?ref=v2.1.0"

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
  security_group_names = [
    "trusted_local_networks_egress",
    "public_networks_egress"
  ]
}
```

### egress_proxy

Creates and configures an instance of cg-egress-proxy to proxy traffic from your apps.

Prerequite: existing public-egress space to deploy the proxy into

```
module "egress_proxy" {
  source = "github.com/GSA-TTS/terraform-cloudgov//egress_proxy?ref=v2.1.0"

  cf_org_name     = local.cf_org_name
  cf_egress_space = data.cloudfoundry_space.egress_space
  name            = "egress-proxy"
  allowlist       = [ "list.of.hosts", "to.allow.access" ]
  # see egress_proxy/variables.tf for full list of optional arguments
}
```

See <UPGRADING.md> for an example of how to set up network policies and credential stores to enable your client app to reach the proxy.

### drupal

> [!WARNING]
> This module is in active development and may change

Creates and configures a Drupal application, and basic supporting services needed.

There are also code changes from a vanilla drupal/cms install required to take advantage of this module.
Find out more at <https://github.com/gsa-tts/drupal-template>

```
module "drupal" {
  source = "github.com/GSA-TTS/terraform-cloudgov//drupal?ref=v2.2.0"

  cf_org_name   = local.cf_org_name
  cf_space      = data.cloudfoundry_space.app_space
  name          = "my-drupal-app"
  rds_plan_name = "small-mysql"
  s3_plan_name  = "basic-sandbox"
  source_dir    = "path/to/drupal/app"
  credentials = {
    NAME = "value-to-insert-into-user-provided-credential-service"
  }
  app_environment = {
    NAME = "value"
  }
}
```

### SpiffWorkflow

> [!WARNING]
> This module is in an experimental phase, and is being added as a means to bring this workflow engine into GSA with a reusable terraform module. It is in active development and not _necessarily_ reflective of a production ready module.

Spiff Workflow is a workflow engine implemented in pure Python. Using BPMN will allow non-developers to describe complex workflow processes in a visual diagram, coupled with a powerful python script engine that works seamlessly within the diagrams. SpiffWorkflow can parse these diagrams and execute them. The ability for businesses to create clear, coherent diagrams that drive an application has far reaching potential. More information can be found on the creators [github page](https://github.com/sartography/SpiffWorkflow).

**NOTE:**
1. You must have a valid git key pairing. Generate with ssh-keygen -t rsa -b 4096 -C "my-git@email", and add the public key to **https://github.com/settings/keys**. var.process_models_ssh_key is the private key. When you store process_models_ssh_key in a .tfvars, ensure that the file format of the .tfvars file is in "LF" End Of Line Sequence. **This key is a profile level SSH key, and does not appear to work at the repo level**
2. Ensure that your space has the `public_networks_egress`security group if you are not using a proxy.
```
module "SpiffWorkflow" {
  source        = "github.com/GSA-TTS/terraform-cloudgov//spiffworkflow?ref=v2.3.0"
  cf_org_name   = var.cf_org_name
  cf_space_name = var.cf_space_name

  process_models_ssh_key = var.process_models_ssh_key

  process_models_repository ="git@github.com:GSA-TTS/gsa-process-models.git"
  # This should be a branch (non-main), to load the examples. Edits to existing models will be pushed here.
  source_branch_for_example_models = "process-models-playground"
  # This should be an existing branch in the model repo. New models will be pushed here.
  target_branch_for_saving_changes = "publish-staging-branch"

  database_service_instance_name = module.Database.name
  tags                           = ["SpiffWorkflow"]
  depends_on                     = [module.Database]
}

module "Database" {
  source        = "github.com/gsa-tts/terraform-cloudgov//database?ref=v2.2.0"
  cf_space_id   = data.cloudfoundry_space.space.id
  name          = "spiffworkflow-db"
  tags          = ["rds", "SpiffWorkflow"]
  rds_plan_name = "small-psql"
}
```

### Application
Creates and deploys an application from source to Cloud Foundry. You must have a valid file structure for deploying to cloud.gov in your repository to deploy the application. This module would replace a traditional "manifest.yml" deployment.

**NOTE:**
1. `DISABLE_COLLECTSTATIC = 1` has been set as an environment variable in the
   example. It is recommended to build your staticfiles and run collectstatic in
   a `.profile`.
2. `service_bindings` is a map where the keys are service instance names. This
   module does not create or bind any service instances, so all services
   (database, s3, creds service, etc) should be specified. All services that
   should be bound to the running app must be deployed before the application
   module is deployed. Ensure dependencies exist where they're needed. For example:
   * You can make a dependency between the application and a service
   instance implicit by supplying a dynamic key based on an expression, eg `(module.servicename.attribute)`.
      ```tf
      service_bindings = {
        (module.a_service.name),
        (module.another_service.name) = <<-EOT  # with params
          ...JSON parameter string...
        EOT
      }

      ```
   * You can make a dependency between the application and a service explicit by adding a `depends_on = []` block for this module containing references to the module or resource that creates the service.
      ```tf
      module "Application" {
        # [...]

        service_bindings = {
          "a_service","       # hardcoded service name
        }

        # [...]
        depends_on = [
          module.a_service    # module creates service "a_service" first
        ]
      }
      ```

```
module "Application" {
  source               = "github.com/GSA-TTS/terraform-cloudgov//application?ref=v2.4.0"
  cf_org_name          = var.cf_org_name
  cf_space_name        = var.cf_space_name
  name                 = local.app_name
  github_org_name      = "gsa-tts"
  github_repo_name     = ""
  app_memory           = "2048M"
  src_code_folder_name = "" # folder for /home/vcap/app. See variables.tf for examples.
  buildpacks           = ["https://github.com/cloudfoundry/apt-buildpack.git", "https://github.com/cloudfoundry/python-buildpack.git"] # examples
  environment_variables = {
    DISABLE_COLLECTSTATIC = 1
    KEY                   = "VALUE"
    ANOTHER_KEY           = "VALUE"
  }
  service_bindings = {
      (var.service_1_name) = ""
      (var.service_2_name) = "...JSON string..."
  }
}
```

## Logshipper
Creates a log-draining application with all necessary components. It **does not** create a network policy between itself and your egress proxy, and does not bind itself to your desired application. You must either `cf bind-service <my-app> logdrain`, supply `logdrain` in the bindings section of your `manifest.yml` or include `logdrain` in the `service_bindings = {}` for your application.

- Logshipper Credentials, defined as `logshipper-creds` is populated with a random user/pass generated via terraform that signifies the `${HTTP_USER}` AND `${HTTP_PASS}` credential set for the `syslog_drain`
- New Relic Credentials, defined as `logshipper-newrelic-creds` contains your New Relic License Key, and the FedRAMP endpoint for New Relic log API.
- The s3 bucket, defined as `<my-s3-name>` with a tag of `logshipper-s3` is a dedicated s3 bucket to store all logs being drained.
- The `logdrain` service, when bound to an application, causes the platform to stream logs for that app to the `logshipper` application. It consists of a `syslog_drain` URI.

>[!NOTE]
> For reasons that remain unknown, it may be necessary to restart the logshipper after binding to an application or your application deploys.
> See this note [here](https://github.com/GSA-TTS/FAC/blob/575bc6f790841ab6bafb95e845c3fe3ad4428f6c/.github/workflows/deploy-application.yml#L107-L119)
> By default, the s3 is not part of this module, if you desire to store logs. You can create that with the s3 module from this repo, and do the following:
```tf
module "logshipper" {
  [...]

  service_bindings = {
    "${local.logshipper_storage_name}" = ""
  }
  depends_on = [module.logs-storage]
```

```tf
module "logshipper" {
  source      = "github.com/gsa-tts/terraform-cloudgov//logshipper?ref=v2.5.0"
  name        = var.name
  cf_org_name = var.cf_org_name
  cf_space = {
    id   = data.cloudfoundry_space.space.id
    name = var.cf_space_name
  }
  logshipper_s3_name    = local.logshipper_storage_name
  https_proxy_url       = var.https_proxy_url
  new_relic_license_key = var.new_relic_license_key
  service_bindings = {
    "${local.logshipper_storage_name}" = ""
  }
  depends_on = [module.logs-storage]
}
```

> [!NOTE]
> You must have a network policy between the logshipper application and the proxy so it can go through the proxy to send the logs into new relic.
```tf
resource "cloudfoundry_network_policy" "logshipper-network-policy" {
  provider = cloudfoundry-community
  policy {
    source_app      = module.logshipper.app_id
    destination_app = module.https-proxy.app_id
    port            = "61443"
    protocol        = "tcp"
  }
}
```

It is necessary to have cf8-cli as part of your terraform plan and terraform apply to run the `null_resource`[Github Workflow](https://github.com/GSA-TTS/terraform-cloudgov/blob/7ba931bbf2d618a7a39e34c1ada7289e515cbd04/.github/workflows/test.yml#L37)
```sh
curl -k -O -L https://github.com/cloudfoundry/cli/releases/download/v8.11.0/cf8-cli-installer_8.11.0_x86-64.deb
apt-get install --assume-yes ./cf8-cli-installer_8.11.0_x86-64.deb

cf api api.fr.cloud.gov
cf auth ${{ secrets.CF_USER }} ${{ secrets.CF_PASSWORD }}
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
