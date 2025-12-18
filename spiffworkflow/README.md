# SpiffWorkflow Module

This Terraform module deploys the [SpiffWorkflow](https://github.com/sartography/spiff-arena) business process management system to cloud.gov. It includes:

- Frontend web application
- Backend API service
- Connector service for custom tasks and system integrations

## Features

- Deploy all components of SpiffWorkflow in a cloud.gov space
- Automatic configuration of network policies and routes
- Two deployment options for the backend and connector:
  - Container-based deployment using a pre-built upstream Docker image
  - Buildpack-based deployment using upstream source and local process models (backend) or local source (connector)

## Usage

**NOTE:**
Your space must have the `trusted-local-egress` security group applied so that the backend can reach the database. If you are not using an egress proxy, you should also ensure that your space has the `public_networks_egress` security group applied, so that the frontend can reach the backend API endpoint.

### Container-based Deployment

Use this approach when you have pre-built container images for the backend and connector:

```hcl
module "spiffworkflow" {
  source = "github.com/GSA-TTS/terraform-cloudgov//spiffworkflow"
  
  cf_org_name   = "my-org"
  cf_space_name = "my-space"
  
  # Use container-based deployment for the backend
  backend_deployment_method = "container"  # This is the default

  # Customize to point to an image that includes your process models
  backend_imageref = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-backend:latest"
  
  # Required PostgreSQL database service instance
  backend_database_service_instance = "my-postgres-db"
  
  # Optional additional service bindings if needed
  backend_additional_service_bindings = {
    "my-redis-service" = ""
  }
}
```

### Buildpack-based Deployment

Use this approach when you want to customize the content of the backend and/or connector:

```hcl
module "spiffworkflow" {
  source = "github.com/GSA-TTS/terraform-cloudgov//spiffworkflow"
  
  cf_org_name   = "my-org"
  cf_space_name = "my-space"
  
  # Use buildpack-based deployment for the backend
  backend_deployment_method = "buildpack"
  backend_gitref = "v1.0.0"  # Specific version of SpiffWorkflow backend source to deploy
  backend_process_models_path = "/somepath/my-process-models"  # Local path to process models
  backend_python_version = "python-3.12.x"  # Python version for the buildpack
  
  # Use buildpack-based deployment for the connector
  connector_deployment_method = "buildpack"
  connector_local_path = "service-connector"  # Local path to connector source
  connector_python_version = "python-3.12.x"  # Python version for the buildpack
  
  # Required PostgreSQL database service instance
  backend_database_service_instance = "my-postgres-db"
  
  # Optional additional service bindings if needed
  backend_additional_service_bindings = {
    "my-redis-service" = ""
  }
}
```

You can also mix deployment methods, for example using a container for the frontend and backend but buildpack for the connector, or vice versa.

### Enabling saving and publishing changes

The deployment can be configured to sync with an upstream repository. Saving will add your changes to a branch, while publishing will make a PR to the upstream repository.

**NOTE:**
You must have a valid git key pairing. Generate with `ssh-keygen -t rsa -b 4096 -C "my-git@email"`, and add the public key to **https://github.com/settings/keys**. `var.process_models_ssh_key` is the private key. When you store `process_models_ssh_key` in a .tfvars file, ensure that the file format of the .tfvars file is in "LF" End Of Line Sequence. **This key is a profile level SSH key, and does not appear to work at the repo level**

```hcl
module "spiffworkflow" {
  source = "github.com/GSA-TTS/terraform-cloudgov//spiffworkflow"
  
  cf_org_name   = "my-org"
  cf_space_name = "my-space"
  [TODO: Document the variables to use!]
  [other configuration]
}
```

### OIDC Authentication Configuration

By default, SpiffWorkflow uses an internal OIDC provider for authentication. You can optionally configure an external OIDC provider such as cloud.gov's identity provider service or login.gov:

```hcl
module "spiffworkflow" {
  source = "github.com/GSA-TTS/terraform-cloudgov//spiffworkflow"
  
  cf_org_name   = "my-org"
  cf_space_name = "my-space"
  
  backend_database_service_instance = "my-postgres-db"
  
  # External OIDC Configuration (e.g., cloud.gov identity provider)
  backend_oidc_client_id           = "your-client-id"
  backend_oidc_client_secret       = "your-client-secret"
  backend_oidc_server_url          = "https://login.fr.cloud.gov"
  backend_oidc_authentication_providers = "default:openid"
  
  # Optional: Additional client IDs and issuers
  backend_oidc_additional_valid_client_ids = "astro-frontend,other-client"
  backend_oidc_additional_valid_issuers   = "https://login.fr.cloud.gov"
}
```

**Note:** When using external OIDC, you must provide at minimum the `backend_oidc_client_id`, `backend_oidc_client_secret`, and `backend_oidc_server_url`. If these are not provided, the module will use the internal OIDC configuration.

## One-Time Initialization Process (Bootstrap Workflow)

The module can run a single BPMN initialization workflow automatically at application start (buildpack-backend deployment only). Use this to seed permissions, create baseline configuration, or perform other idempotent bootstrap steps.

### Enabling

Set the Terraform variable `init_process_identifier` with a process model identifier (path-like) found under your provided `process_models` directory, for example:

```hcl
init_process_identifier = "site-administration/give-admin-permissions-to-developers"
```

This value is injected as the environment variable `SPIFFWORKFLOW_BACKEND_INIT_PROCESS` inside the backend. An empty string disables the feature (recommended in production once initial bootstrap is done or if not needed).

### Runtime Behavior

| Concern | Behavior |
|---------|----------|
| Execution Instance | Only Cloud Foundry instance index `0` runs the init script (checked via `CF_INSTANCE_INDEX`). |
| Idempotency | If a prior instance finished with status `complete` or acceptable `suspended` (no READY manual tasks), the script exits immediately. |
| Concurrency Guard | If an instance of the same process is currently `not_started` or `running`, no new one is created. |
| Manual Tasks | All READY Manual Tasks are auto-completed greedily each cycle. |
| User Tasks | Any BPMN User Task causes a failure (interactive steps are disallowed). |
| Success States | `complete` or `suspended` with zero remaining READY manual tasks. |
| Migrations | Database migrations are run if enabled; core table presence can short‑circuit migration unless `INIT_PROCESS_FORCE_MIGRATION=true`. |
| Non-blocking | Failure logs a warning but doesn’t block app startup. |
| Logging Markers | Emits structured markers: `INIT_PROCESS_START`, `INIT_PROCESS_MANUAL_PROGRESS`, `INIT_PROCESS_SUMMARY`, `INIT_PROCESS_EXIT_SUCCESS`, and warnings for user tasks. |

### Environment Variables Influencing Behavior

| Variable | Purpose |
|----------|---------|
| `SPIFFWORKFLOW_BACKEND_INIT_PROCESS` | Target process model identifier (empty disables). |
| `INIT_PROCESS_FORCE_MIGRATION` | Force database upgrade even if core tables detected. |
| `INIT_PROCESS_DEDUP_LOG` | Suppress duplicate consecutive log lines (default true). |

### Example Module Block (Excerpt)

```

module "spiffworkflow" {
  source = "github.com/GSA-TTS/terraform-cloudgov//spiffworkflow"
  cf_org_name   = "my-org"
  cf_space_name = "my-space"
  backend_deployment_method         = "buildpack"
  backend_gitref                    = "v1.1.2"
  backend_process_models_path       = "../workflow/process_models"
  backend_scripts_path              = "../workflow/scripts"
  backend_database_service_instance = "my-postgres-db"
}
```


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cf_org_name | cloud.gov organization name | `string` | n/a | yes |
| cf_space_name | cloud.gov space in which to deploy the apps | `string` | n/a | yes |
| backend_deployment_method | Method to deploy the backend: 'buildpack' for Python buildpack or 'container' for a container image | `string` | `"container"` | no |
| backend_imageref | Container image reference for the backend when using container deployment | `string` | `"ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-backend:latest"` | no |
| backend_gitref | Git reference for the SpiffWorkflow repository when using buildpack deployment | `string` | `"v1.0.0"` | no |
| backend_process_models_path | Path to local process models when using buildpack deployment | `string` | `"process_models"` | no |
| backend_scripts_path | (Buildpack backend only) Path to supplemental backend scripts (init process, profile hooks). Ignored for container deployment. | `string` | `""` | yes (buildpack) |
| backend_database_service_instance | Name of the Postgres service instance to bind to the backend | `string` | n/a | yes |
| backend_database_params | JSON parameter string for the database service binding | `string` | `""` | no |
| backend_python_version | Python version to use for the backend when using buildpack deployment | `string` | `"python-3.12.x"` | no |
| backend_additional_service_bindings | Map of additional service instance names to JSON parameter strings for optional service bindings | `map(string)` | `{}` | no |
| backend_oidc_client_id | Optional OIDC client ID for external authentication provider | `string` | `null` | no |
| backend_oidc_client_secret | Optional OIDC client secret for external authentication provider | `string` | `null` | no |
| backend_oidc_server_url | Optional OIDC server URL for external authentication provider | `string` | `null` | no |
| backend_oidc_additional_valid_client_ids | Optional comma-separated list of additional valid client IDs | `string` | `null` | no |
| backend_oidc_additional_valid_issuers | Optional comma-separated list of additional valid issuers | `string` | `null` | no |
| backend_oidc_authentication_providers | Optional authentication providers configuration | `string` | `null` | no |

See [variables.tf](./variables.tf) for all available options.

## Outputs

| Name | Description |
|------|-------------|
| frontend_url | URL to access the SpiffWorkflow frontend |
| backend_url | URL for the backend API |
| connector_url | Internal URL for the connector service |

## Notes

- A database service instance is **required** for the backend to work.
  - The database service instance must be an aws-rds service instance with type postgres in cloud.gov.
  - You can specify parameters for the database service binding using the `backend_database_params` variable.
- When using container-based deployment, the process models must be included in the container image.
- When using buildpack-based deployment, Poetry must be installed locally to generate requirements.txt.
