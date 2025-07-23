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
```

### Enabling saving and publishing changes

The deployment can be configured to sync with an upstream repository. Saving will add your changes to a branch, while publishing will make a PR to the upstream repository.

**NOTE:**
You must have a valid git key pairing. Generate with `ssh-keygen -t rsa -b 4096 -C "my-git@email"`, and add the public key to **https://github.com/settings/keys**. `var.process_models_ssh_key` is the private key. When you store `process_models_ssh_key` in a .tfvars file, ensure that the file format of the .tfvars file is in "LF" End Of Line Sequence. **This key is a profile level SSH key, and does not appear to work at the repo level**

```
module "spiffworkflow" {
  source = "github.com/GSA-TTS/terraform-cloudgov//spiffworkflow"
  
  cf_org_name   = "my-org"
  cf_space_name = "my-space"
  [TODO: Document the variables to use!]
  [other configuration]
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
| backend_database_service_instance | Name of the Postgres service instance to bind to the backend | `string` | n/a | yes |
| backend_database_params | JSON parameter string for the database service binding | `string` | `""` | no |
| backend_python_version | Python version to use for the backend when using buildpack deployment | `string` | `"python-3.12.x"` | no |
| backend_additional_service_bindings | Map of additional service instance names to JSON parameter strings for optional service bindings | `map(string)` | `{}` | no |

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
