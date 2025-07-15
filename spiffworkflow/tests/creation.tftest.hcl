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
}

variables {
  cf_org_name                      = "gsa-tts-devtools-prototyping"
  cf_space_name                    = "terraform-cloudgov-ci-tests"
  process_models_ssh_key           = ""
  database_service_instance_name   = "spiffworkflow-db"
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
    condition     = cloudfoundry_app.connector.name == var.connector_name
    error_message = "Connector App name matches var.name"
  }
  assert {
    condition     = cloudfoundry_app.backend.name == var.backend_name
    error_message = "Backend App name matches var.name"
  }
  assert {
    condition     = cloudfoundry_app.frontend.name == var.frontend_name
    error_message = "Frontend App name matches var.name"
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

run "test_spiff_images" {
  assert {
    condition     = data.docker_registry_image.backend.name == var.backend_image
    error_message = "Backend docker image data name is passed directly in as var.backend_image"
  }
  assert {
    condition     = data.docker_registry_image.frontend.name == var.frontend_image
    error_message = "Frontend docker image data name is passed directly in as var.frontend_image"
  }
  assert {
    condition     = data.docker_registry_image.connector.name == var.connector_image
    error_message = "Connector docker image data name is passed directly in as var.connector_image"
  }
}

run "test_spiff_sha" {
  assert {
    condition     = cloudfoundry_app.backend.docker_image == "${var.backend_image_name}@${data.docker_registry_image.backend.sha256_digest}"
    error_message = "Backend docker image is derived from the image_location@sha256"
  }
  assert {
    condition     = cloudfoundry_app.frontend.docker_image == "${var.frontend_image_name}@${data.docker_registry_image.frontend.sha256_digest}"
    error_message = "Frontend docker image is derived from the image_location@sha256"
  }
  assert {
    condition     = cloudfoundry_app.connector.docker_image == "${var.connector_image_name}@${data.docker_registry_image.connector.sha256_digest}"
    error_message = "Connector docker image is derived from the image_location@sha256"
  }
}
