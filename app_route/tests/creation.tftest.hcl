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
  app_ids       = ["731ed210-af91-4e05-886e-a2fbaf5125cb"]
  hostname      = "my-host"
  domain        = "apps.internal"
}

run "test_route_creation" {
  assert {
    condition     = output.endpoint == cloudfoundry_route.app_route.url
    error_message = "The route URL should be in the output"
  }

  assert {
    condition     = output.route_id == cloudfoundry_route.app_route.id
    error_message = "The route's ID is in the output"
  }
}
