mock_provider "cloudfoundry" {
  mock_data "cloudfoundry_domain" {
    defaults = {
      id = "7dbc73bb-28d3-481f-afcc-a81545825bd0"
    }
  }
  mock_resource "cloudfoundry_route" {
    defaults = {
      url = "terraform-cloudgov-clamav-test.apps.internal"
    }
  }
}
mock_provider "cloudfoundry-community" {}

variables {
  cf_org_name = "gsa-tts-devtools-prototyping"
  cf_space = {
    id   = "e243575e-376a-4b70-b891-23c3fa1a0680"
    name = "terraform-cloudgov-ci-tests"
  }
  app_name      = "terraform_cloudgov_app"
  name          = "terraform-cloudgov-clamav-test"
  clamav_image  = "ghcr.io/gsa-tts/clamav-rest/clamav:TAG"
  max_file_size = "30M"
}

run "test_app_creation" {
  assert {
    condition     = cloudfoundry_app.clamav_api.id == output.app_id
    error_message = "App ID output must match the clamav app ID"
  }

  assert {
    condition     = cloudfoundry_route.clamav_route.id == output.route_id
    error_message = "Route ID output must match the ID of the route to the clamav app"
  }

  assert {
    condition     = "${var.name}.apps.internal" == output.endpoint
    error_message = "Endpoint output must match the clamav route endpoint"
  }

  assert {
    condition     = cloudfoundry_app.clamav_api.name == var.name
    error_message = "App name matches var.name"
  }

  assert {
    condition     = cloudfoundry_app.clamav_api.memory == var.clamav_memory
    error_message = "App memory is passed as var.clamav_memory"
  }

  assert {
    condition     = cloudfoundry_app.clamav_api.docker_image == var.clamav_image
    error_message = "Docker image is passed directly in as var.clamav_image"
  }

  assert {
    condition     = cloudfoundry_app.clamav_api.environment["MAX_FILE_SIZE"] == var.max_file_size
    error_message = "Sets the max file size to var.max_file_size"
  }

  assert {
    condition     = lookup(cloudfoundry_app.clamav_api.environment, "PROXY_SERVER", null) == null
    error_message = "Does not set the PROXY_SERVER environment by default"
  }

  assert {
    condition     = lookup(cloudfoundry_app.clamav_api.environment, "PROXY_PORT", null) == null
    error_message = "Does not set the PROXY_PORT environment by default"
  }

  assert {
    condition     = lookup(cloudfoundry_app.clamav_api.environment, "PROXY_USERNAME", null) == null
    error_message = "Does not set the PROXY_USERNAME environment by default"
  }

  assert {
    condition     = lookup(cloudfoundry_app.clamav_api.environment, "PROXY_PASSWORD", null) == null
    error_message = "Does not set the PROXY_PASSWORD environment by default"
  }

  assert {
    condition     = [for policy in cloudfoundry_network_policy.clamav_routing.policy : policy.source_app] == [data.cloudfoundry_app.app.id]
    error_message = "Routing policy allows traffic from the source app"
  }

  assert {
    condition     = [for policy in cloudfoundry_network_policy.clamav_routing.policy : policy.destination_app] == [cloudfoundry_app.clamav_api.id]
    error_message = "Routing policy allows traffic to the clamav app"
  }

  assert {
    condition     = [for policy in cloudfoundry_network_policy.clamav_routing.policy : policy.port] == ["61443"]
    error_message = "Routing policy opens up traffic on the internal https port"
  }
}

run "test_with_proxy" {
  variables {
    proxy_server   = "proxy.server"
    proxy_port     = "8900"
    proxy_username = "username"
    proxy_password = "not-a-real-password"
  }

  assert {
    condition     = cloudfoundry_app.clamav_api.environment["PROXY_SERVER"] == var.proxy_server
    error_message = "Proxy variables are set properly"
  }

  assert {
    condition     = cloudfoundry_app.clamav_api.environment["PROXY_PORT"] == var.proxy_port
    error_message = "Proxy variables are set properly"
  }

  assert {
    condition     = cloudfoundry_app.clamav_api.environment["PROXY_USERNAME"] == var.proxy_username
    error_message = "Proxy variables are set properly"
  }

  assert {
    condition     = cloudfoundry_app.clamav_api.environment["PROXY_PASSWORD"] == var.proxy_password
    error_message = "Proxy variables are set properly"
  }
}
