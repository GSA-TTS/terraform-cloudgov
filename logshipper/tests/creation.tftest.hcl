provider "cloudfoundry" {
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
    condition     = lookup(cloudfoundry_app.logshipper.environment, "PROXYROUTE", var.https_proxy_url) != null
    error_message = "The PROXYROUTE environment variable should not be null by default to ensure new relic connections"
  }
  assert {
    condition     = cloudfoundry_app.logshipper.buildpacks != null
    error_message = "The application buildpacks should not be empty"
  }
  assert {
    condition     = cloudfoundry_route.logshipper_route.domain == output.domain
    error_message = "The domain for the route must match the output domain"
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

