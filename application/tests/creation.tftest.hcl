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
}

#TODO: More Testing

run "application_tests" {
  assert {
    condition     = output.app_id == cloudfoundry_app.application.id
    error_message = "Output id must match the app id"
  }
  assert {
    condition     = "${var.name}.app.cloud.gov" == output.endpoint
    error_message = "Endpoint output must match the app route endpoint"
  }
}
