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
  cf_org_name   = "gsa-tts-devtools-prototyping"
  cf_space_name = "terraform-cloudgov-ci-tests"
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
    condition     = module.route.endpoint == output.endpoint
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
