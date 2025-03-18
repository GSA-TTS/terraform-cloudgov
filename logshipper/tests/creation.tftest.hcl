provider "cloudfoundry" {
  api_url = "https://api.fr.cloud.gov"
  # cf_user and cf_password are passed in via CF_USER and CF_PASSWORD env vars
}
provider "cloudfoundry-community" {
  api_url = "https://api.fr.cloud.gov"
  # cf_user and cf_password are passed in via CF_USER and CF_PASSWORD env vars
}

variables {
  cf_org_name = "gsa-tts-devtools-prototyping"
  cf_space = {
    id   = "15836eb6-a57e-4579-bca7-99764c5a01a4"
    name = "terraform-cloudgov-ci-tests"
  }
  name                  = "logshipper"
  https_proxy_url       = "https://egress-proxy-user:egress-proxy-password@some-internal-route.test.foo:00000"
  new_relic_license_key = "NRAKTHISISATESTKEY"
}

run "application_tests" {
  assert {
    condition     = cloudfoundry_app.logshipper.id == output.app_id
    error_message = "Output id must match the app id"
  }
  assert {
    condition     = cloudfoundry_user_provided_service.logdrain_service.syslog_drain_url == output.syslog_drain_url
    error_message = "The logdrain url for the logdrain service must match the logdrain url of the application"
  }
  assert {
    condition     = lookup(cloudfoundry_app.logshipper.environment, "PROXYROUTE", "https://some-proxy.com") != null
    error_message = "The PROXYROUTE environment variable should not be null by default to ensure new relic connections"
  }
  assert {
    condition     = cloudfoundry_app.logshipper.buildpacks != null
    error_message = "The application buildpacks should not be empty"
  }
  assert {
    condition     = cloudfoundry_app.logshipper.service_bindings != null
    error_message = "The application should have services bound by default"
  }
  assert {
    condition     = cloudfoundry_route.logshipper_route.domain == output.domain
    error_message = "The domain for the route must match the output domain"
  }
  assert {
    condition     = cloudfoundry_user_provided_service.logdrain_service.id == output.logdrain_service_id
    error_message = "The logdrain service id must match the output id"
  }
}

run "src_tests" {
  assert {
    condition     = cloudfoundry_app.logshipper.path == "${path.module}/${data.external.logshipper_zip.result.path}"
    error_message = "The path for the zip should be in the module path"
  }
  assert {
    condition     = cloudfoundry_app.logshipper.source_code_hash == filesha256("${path.module}/${data.external.logshipper_zip.result.path}")
    error_message = "The hash for the zip should be a valid sha256"
  }
}

