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

Use this approach when you want to customize the content of the backend and/or connector.

The backend zip must be built **before** running `terraform plan/apply` using the
`build-for-cloudfoundry.sh` script shipped with this module:

```text
#   ./build-for-cloudfoundry.sh <output_zip> <backend_gitref> <process_models_path> [python_version] [scripts_path]
#
# Example:
#   ./build-for-cloudfoundry.sh /tmp/backend.zip github.com/sartography/spiff-arena?ref=v1.1.5 ./process_models python-3.12.x ./scripts
#
# Arguments:
#   output_zip          - Output path for the generated zip file
#   backend_gitref      - Git tag/branch/commit or URL?ref=REF format
#   process_models_path - Path to local process_models directory
#   python_version      - (optional) Python version string for buildpack (default: python-3.10.x)
#   scripts_path        - (optional) Path to supplemental scripts directory (eg init process, profile hooks)
```

Then reference the zip in your Terraform configuration:

```hcl
module "spiffworkflow" {
  source = "github.com/GSA-TTS/terraform-cloudgov//spiffworkflow"
  
  cf_org_name   = "my-org"
  cf_space_name = "my-space"
  
  # Use buildpack-based deployment for the backend
  backend_deployment_method = "buildpack"
  backend_zip_path = "/tmp/spiff-backend.zip"
  
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

```hcl
module "spiffworkflow" {
  source = "github.com/GSA-TTS/terraform-cloudgov//spiffworkflow"
  cf_org_name   = "my-org"
  cf_space_name = "my-space"
  backend_deployment_method         = "buildpack"
  backend_zip_path                  = "/tmp/spiff-backend.zip"
  backend_database_service_instance = "my-postgres-db"
}
```


## Inputs

### General

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cf_org_name | cloud.gov organization name | `string` | n/a | yes |
| cf_space_name | cloud.gov space in which to deploy the apps | `string` | n/a | yes |
| name | Prefix for app names and route hostnames. Must be DNS-compatible, 3–53 chars. Auto-generated if omitted. | `string` | `null` | no |
| tags | Tags to add to the module's resources | `set(string)` | `[]` | no |
| https_proxy | Full URL of the HTTPS egress proxy (e.g. from the `egress_proxy` module) | `string` | `""` | no |

### Git Sync (saving / publishing)

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| process_models_repository | Git repository with process models (use SSH-style `git@github.com:…`) | `string` | `""` | no |
| process_models_ssh_key | Private SSH key with read/write access to the repository | `string` | `""` | no |
| source_branch_for_example_models | Branch for reading process models | `string` | `"main"` | no |
| target_branch_for_saving_changes | Branch for publishing process model changes | `string` | `"draft"` | no |

### Backend

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| backend_deployment_method | `"buildpack"` or `"container"` | `string` | `"container"` | no |
| backend_imageref | Container image reference (container deployment) | `string` | `"ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-backend:latest"` | no |
| backend_zip_path | Path to the pre-built zip produced by `build-for-cloudfoundry.sh` (buildpack deployment) | `string` | `null` | yes (buildpack) |
| backend_bootstrap_process_model | Init BPMN process model identifier to run at startup (empty to disable) | `string` | `""` | no |
| backend_database_service_instance | Postgres service instance name to bind to the backend | `string` | n/a | yes |
| backend_database_params | JSON parameters for the database service binding | `string` | `""` | no |
| backend_queue_service_instance | Redis service instance name for background task queue (empty to disable) | `string` | `""` | no |
| backend_queue_service_params | JSON parameters for the queue service binding | `string` | `""` | no |
| backend_web_instances | Number of backend web instances | `number` | `1` | no |
| backend_web_memory | Memory for each backend web instance | `string` | `"512M"` | no |
| backend_web_disk | Disk quota for each backend web instance | `string` | `"1024M"` | no |
| backend_worker_instances | Number of backend worker instances (must be ≥ 1 if queue is set) | `number` | `0` | no |
| backend_worker_memory | Memory for each backend worker instance | `string` | `"1024M"` | no |
| backend_worker_disk | Disk quota for each backend worker instance | `string` | `"1024M"` | no |
| backend_scheduler_memory | Memory for the backend scheduler instance | `string` | `"512M"` | no |
| backend_scheduler_disk | Disk quota for the backend scheduler instance | `string` | `"1024M"` | no |
| backend_environment | Additional environment variables for the backend app | `map(string)` | `{}` | no |
| backend_additional_service_bindings | Map of additional service instance names → JSON parameter strings | `map(string)` | `{}` | no |

### Backend OIDC

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| backend_oidc_client_id | OIDC client ID for an external auth provider. Omit to use the built-in provider. | `string` | `null` | no |
| backend_oidc_client_secret | OIDC client secret (required when `backend_oidc_client_id` is set) | `string` | `null` | conditional |
| backend_oidc_server_url | OIDC server URL (required when `backend_oidc_client_id` is set) | `string` | `null` | conditional |
| backend_oidc_scope | OAuth scopes | `string` | `"openid"` | no |
| backend_oidc_authentication_providers | Authentication providers config (e.g. `"default:openid"`) | `string` | `null` | no |
| backend_oidc_additional_valid_client_ids | Comma-separated additional valid client IDs | `string` | `null` | no |
| backend_oidc_additional_valid_issuers | Comma-separated additional valid issuers | `string` | `null` | no |

### Connector

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| connector_deployment_method | `"buildpack"` or `"container"` | `string` | `"container"` | no |
| connector_imageref | Container image reference (container deployment) | `string` | `"ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-connector:latest"` | no |
| connector_local_path | Path to local connector source (buildpack deployment) | `string` | `"service-connector"` | yes (buildpack) |
| connector_python_version | Python version for the connector buildpack | `string` | `"python-3.12.x"` | no |
| connector_instances | Number of connector instances | `number` | `1` | no |
| connector_memory | Memory for the connector app | `string` | `"128M"` | no |
| connector_disk | Disk quota for the connector app | `string` | `"3G"` | no |
| connector_additional_service_bindings | Map of additional service instance names → JSON parameter strings | `map(string)` | `{}` | no |

### Frontend

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| frontend_imageref | Container image reference for the frontend | `string` | `"ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-frontend:latest"` | no |
| frontend_instances | Number of frontend instances | `number` | `1` | no |
| frontend_memory | Memory for the frontend app | `string` | `"256M"` | no |
| frontend_task_metadata | Variable path for human task metadata extraction | `string` | `""` | no |
| frontend_url_override | Custom domain override (e.g. `my-domain.gov` instead of `*.app.cloud.gov`) | `string` | `""` | no |

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
- When using buildpack-based deployment, [uv](https://docs.astral.sh/uv/) must be installed locally for the build script to generate `requirements.txt`.
