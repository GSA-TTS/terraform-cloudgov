mock_provider "cloudfoundry" {}

variables {
  cf_org_name          = "gsa-tts-devtools-prototyping"
  cf_space_name        = "terraform-cloudgov-ci-tests"
  name                 = "fac-app"
  branch_name          = "main"
  github_org_name      = "gsa-tts"
  github_repo_name     = "fac"
  src_code_folder_name = "backend"
  buildpacks           = ["https://github.com/cloudfoundry/apt-buildpack.git", "https://github.com/cloudfoundry/python-buildpack.git"]
  service_bindings = {
    my-service_instance             = ""
    my-service-instance-with-params = <<-EOT
      {
        "astring"     : "foo",
        "anarray"     : ["bar", "baz"],
        "anarrayobjs" : [
          {
            "name": "bat",
            "value": "boz"
          }
        ]
      }
    EOT
  }
  environment_variables = {
    ENV_VAR  = "1"
    ENV_VAR2 = "2"
  }
}

run "application_tests" {
  assert {
    condition     = output.app_id == cloudfoundry_app.application.id
    error_message = "Output id must match the app id"
  }
  assert {
    condition     = "${var.name}.app.cloud.gov" == output.endpoint
    error_message = "Endpoint output must match the app route endpoint"
  }
  assert {
    condition     = cloudfoundry_app.application.buildpacks != null
    error_message = "The application buildpacks should not be empty"
  }
  assert {
    condition     = cloudfoundry_app.application.service_bindings != null
    error_message = "The application should have services bound by default"
  }
}

run "src_tests" {
  assert {
    condition     = cloudfoundry_app.application.path == "${path.module}/${data.external.app_zip.result.path}"
    error_message = "The path for the zip should be in the module path"
  }
  assert {
    condition     = cloudfoundry_app.application.source_code_hash == filesha256("${path.module}/${data.external.app_zip.result.path}")
    error_message = "The hash for the zip should be a valid sha256"
  }

}
