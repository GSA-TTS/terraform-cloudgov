mock_provider "cloudfoundry" {}

variables {
  cf_org_name                    = "gsa-tts-devtools-prototyping"
  cf_space_name                  = "terraform-cloudgov-ci-tests"
  process_models_ssh_key         = ""
  database_service_instance_name = "spiffworkflow-db"
  backend_name                   = "spiffworkflow-backend"
  frontend_name                  = "spiffworkflow-frontend"
  connector_name                 = "spiffworkflow-connector"
  backend_image                  = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-backend:latest"
  frontend_image                 = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-frontend:latest"
  connector_image                = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena-connector:latest"
  health_check_endpoint          = "/api/v1.0/status"
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
