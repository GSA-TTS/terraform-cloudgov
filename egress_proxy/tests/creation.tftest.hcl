mock_provider "cloudfoundry" {
  mock_data "cloudfoundry_domain" {
    defaults = {
      id = "fea49b46-907f-4fe9-8700-ff6e2b438cd3"
    }
  }
  mock_resource "cloudfoundry_route" {
    defaults = {
      url = "egress-proxy.apps.internal"
    }
  }
  mock_resource "cloudfoundry_app" {
    defaults = {
      id = "28329663-10fd-4c5d-9b6b-25e3fb108929"
    }
  }
}

variables {
  cf_org_name = "gsa-tts-devtools-prototyping"
  cf_egress_space = {
    id   = "5178d8f5-d19a-4782-ad07-467822480c68"
    name = "terraform-cloudgov-ci-tests-egress"
  }
  cf_client_spaces = { "client-space" = "e243575e-376a-4b70-b891-23c3fa1a0680" }
  name             = "terraform-egress-app"
  allowlist        = { "continuous_monitoring-staging" = ["raw.githubusercontent.com:443"] }
}

run "test_proxy_creation" {
  assert {
    condition     = output.https_proxy == "https://${output.username}:${output.password}@${output.domain}:61443"
    error_message = "HTTPS_PROXY output must match the correct form, got ${nonsensitive(output.https_proxy)}"
  }

  assert {
    condition     = output.domain == local.egress_route
    error_message = "Output domain must match the route url"
  }

  assert {
    condition     = output.username == random_uuid.username.result
    error_message = "Output username must come from the random_uuid resource"
  }

  assert {
    condition     = output.password == random_password.password.result
    error_message = "Output password must come from the random_password resource"
  }

  assert {
    condition     = output.protocol == "https"
    error_message = "protocol only supports https"
  }

  assert {
    condition     = output.app_id == cloudfoundry_app.egress_app.id
    error_message = "Output app_id is the egress_app's ID"
  }

  assert {
    condition     = output.port == 61443
    error_message = "port only supports 61443 internal https listener"
  }

  assert {
    condition     = output.credential_service_ids == { "client-space" = cloudfoundry_service_instance.credentials["client-space"].id }
    error_message = "Output credential_service_ids is a map of client_space_ids to credential_instance_ids"
  }

  assert {
    condition     = output.credential_service_name == "${var.name}-credentials"
    error_message = "Output credential_service_name is the single name shared by all of the credential services"
  }
}
