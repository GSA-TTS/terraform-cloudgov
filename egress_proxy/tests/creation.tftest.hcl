mock_provider "cloudfoundry" {}

variables {
  cf_org_name   = "gsa-tts-devtools-prototyping"
  cf_space_name = "terraform-cloudgov-ci-tests-egress"
  client_space  = "terraform-cloudgov-ci-tests"
  name          = "terraform-egress-app"
  allowlist     = { "continuous_monitoring-staging" = ["raw.githubusercontent.com:443"] }
}

run "test_proxy_creation" {
  assert {
    condition     = output.https_proxy == "https://${output.username}:${output.password}@${output.domain}:61443"
    error_message = "HTTPS_PROXY output must match the correct form, got ${nonsensitive(output.https_proxy)}"
  }

  assert {
    condition     = output.domain == cloudfoundry_route.egress_route.endpoint
    error_message = "Output domain must match the route endpoint"
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
}
