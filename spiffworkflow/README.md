# SpiffWorkflow Module

This Terraform module deploys the [SpiffWorkflow](https://github.com/sartography/spiff-arena) business process management system to cloud.gov. It includes:

- Frontend web application
- Backend API service
- Connector service for custom tasks and system integrations

## Features

- Deploy all components of SpiffWorkflow in a cloud.gov space
- Automatic configuration of network policies and routes
- Two deployment options for the backend:
  - Container-based deployment using a pre-built Docker image
  - Buildpack-based deployment from source code using local process models

## Usage

### Container-based Backend Deployment

Use this approach when you have a pre-built container image with your process models included:

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

### Buildpack-based Backend Deployment

Use this approach when you want to deploy the SpiffWorkflow from source code, including local process models:

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
  
  # Required PostgreSQL database service instance
  backend_database_service_instance = "my-postgres-db"
  
  # Optional additional service bindings if needed
  backend_additional_service_bindings = {
    "my-redis-service" = ""
  }
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
