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

run "test_specific_hostname_bug" {
  variables {
    cf_org_name = "gsa-tts-devtools-prototyping"
    cf_egress_space = {
      id   = "169c6e21-2513-43f7-bbff-80cc5e456882"
      name = "rca-tfm-stage-egress"
    }
    name = "egress-proxy-staging"
  }
  assert {
    condition     = can(regex("[a-z]", substr(output.domain, 0, 1)))
    error_message = "proxy domain must start with an alpha character"
  }
}

run "test_custom_hostname_is_trimmed" {
  variables {
    route_host = "-3host-name"
  }
  assert {
    condition     = output.domain == "host-name.apps.internal"
    error_message = "proxy domain is stripped of any non-alpha characters"
  }
}
