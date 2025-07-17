mock_provider "cloudfoundry" {
  mock_data "cloudfoundry_org" {
    defaults = {
      id = "591a8a56-3093-43e7-a21e-1b1b4dbd1c3a"
    }
  }
  mock_data "cloudfoundry_domain" {
    defaults = {
      id = "ad9f5303-b5b0-40cb-b21a-a7276efae4b1"
    }
  }
  mock_data "cloudfoundry_space" {
    defaults = {
      id = "31a2c21d-ba50-437b-9d40-8c2d741af9e7"
    }
  }

  # Mock cloudfoundry_app resources with valid UUIDs to fix the network policy test
  mock_resource "cloudfoundry_app" {
    defaults = {
      id = "c5b9e4d2-1a8f-46c3-a957-4f3d8b79e61c"
    }
  }
}

# Mock Docker registry image data
mock_provider "docker" {
  mock_resource "docker_registry_image" {
    defaults = {
      name          = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena:latest"
      sha256_digest = "sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    }
  }
}

variables {
  cf_org_name                       = "gsa-tts-devtools-prototyping"
  cf_space_name                     = "terraform-cloudgov-ci-tests"
  process_models_ssh_key            = ""
  backend_database_service_instance = "spiffworkflow-db"
  name                              = "spiffworkflow-backend"

  backend_name                     = "spiffworkflow-backend"
  frontend_name                    = "spiffworkflow-frontend"
  connector_name                   = "spiffworkflow-connector"
  backend_image                    = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-backend:latest"
  frontend_image                   = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-frontend:latest"
  connector_image                  = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-connector:latest"
  backend_image_name               = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-backend"
  frontend_image_name              = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-frontend"
  connector_image_name             = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-connector"
  health_check_endpoint            = "/api/v1.0/status"
  process_models_repository        = "git@github.com:GSA-TTS/gsa-process-models.git"
  source_branch_for_example_models = "process-models-playground"
  target_branch_for_saving_changes = "publish-staging-branch"
}

run "test_spiff_instances" {
  assert {
    condition     = cloudfoundry_app.connector.name == "${var.name}-connector"
    error_message = "Connector App name should be ${var.name}-connector"
  }
  assert {
    condition     = cloudfoundry_app.backend.name == "${var.name}-backend"
    error_message = "Backend App name should be ${var.name}-backend"
  }
  assert {
    condition     = cloudfoundry_app.frontend.name == "${var.name}-frontend"
    error_message = "Frontend App name should be ${var.name}-frontend"
  }
  assert {
    condition     = cloudfoundry_app.connector.id == output.connector_app_id
    error_message = "App ID output must match the Connector app ID"
  }
  assert {
    condition     = cloudfoundry_app.frontend.id == output.frontend_app_id
    error_message = "App ID output must match the Frontend app ID"
  }
  assert {
    condition     = cloudfoundry_app.backend.id == output.backend_app_id
    error_message = "App ID output must match the Backend app ID"
  }
  assert {
    condition     = cloudfoundry_app.backend.health_check_http_endpoint == var.health_check_endpoint
    error_message = "Health check endpoint must match backend health check endpoint"
  }
}
