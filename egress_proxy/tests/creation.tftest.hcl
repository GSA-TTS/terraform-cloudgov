mock_provider "cloudfoundry" {}

variables {
  cf_org_name = "gsa-tts-devtools-prototyping"
  cf_egress_space = {
    id   = "5178d8f5-d19a-4782-ad07-467822480c68"
    name = "terraform-cloudgov-ci-tests-egress"
  }
  name      = "terraform-egress-app"
  allowlist = ["raw.githubusercontent.com:443"]
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
    condition     = output.app_id == cloudfoundry_app.egress_app.id
    error_message = "Output app_id is the egress_app's ID"
  }

  assert {
    condition     = output.https_port == 61443
    error_message = "https_port only supports 61443 internal https listener"
  }

  assert {
    condition     = output.http_port == 8080
    error_message = "http_port reports port 8080 for plaintext"
  }
}
