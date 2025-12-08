provider "cloudfoundry" {}

variables {
  cf_org_name = "cloud-gov-devtools-development"
  cf_space = {
    id   = "f23cbf69-66a1-4b1d-83d4-e497abdb8dcb"
    name = "terraform-cloudgov-tf-tests"
  }
  name                  = "logshipper"
  https_proxy_url       = "https://egress-proxy-user:egress-proxy-password@some-internal-route.test.foo:00000"
  new_relic_license_key = "NRAKTHISISATESTKEY"
  domain                = "fr-stage.cloud.gov"
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
