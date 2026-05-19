provider "cloudfoundry" {}

variables {
  cf_org_name = "gsa-tts-devtools-prototyping"
  cf_space = {
    id   = "15836eb6-a57e-4579-bca7-99764c5a01a4"
    name = "terraform-cloudgov-ci-tests"
  }
  name                  = "file-scanner"
  https_proxy_url       = "https://egress-proxy-user:egress-proxy-password@some-internal-route.test.foo:00000"
  buildpacks            = ["https://github.com/cloudfoundry/python-buildpack"]
  github_repo_name      = "fac-periodic-scanner"
  src_code_folder_name  = ""
  # service_bindings = {
  #   my-service_instance = ""
  # }
}

run "application_tests" {
  assert {
    condition     = cloudfoundry_app.scanner_app.id == output.app_id
    error_message = "Output id must match the app id"
  }
  assert {
    condition     = cloudfoundry_app.scanner_app.buildpacks != null
    error_message = "The application buildpacks should not be empty"
  }
}

run "src_tests" {
  assert {
    condition     = cloudfoundry_app.scanner_app.path == "${path.module}/${data.external.scanner_zip.result.path}"
    error_message = "The path for the zip should be in the module path"
  }
  assert {
    condition     = cloudfoundry_app.scanner_app.source_code_hash == filesha256("${path.module}/${data.external.scanner_zip.result.path}")
    error_message = "The hash for the zip should be a valid sha256"
  }
}
