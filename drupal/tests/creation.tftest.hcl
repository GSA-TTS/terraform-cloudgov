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
  name           = "terraform-cloudgov-drupal-test"
  rds_plan_name  = "small-mysql"
  s3_plan_name   = "basic-sandbox"
  source_dir     = "."
  extra_excludes = ["dist", ".terraform*"]
}

run "test_app_creation" {
  override_resource {
    target = module.database.cloudfoundry_service_instance.rds
    values = {
      id = "f6925fad-f9e8-4c93-b69f-132438f6a2f4"
    }
  }
  override_resource {
    target = cloudfoundry_app.app
    values = {
      id = "738931fc-d330-4333-88da-76399363d3f4"
    }
  }

  assert {
    condition     = module.database.instance_id == output.database_id
    error_message = "Database ID output must match the service instance"
  }

  assert {
    condition     = module.bucket.bucket_id == output.bucket_id
    error_message = "Bucket ID output must match the service instance"
  }

  assert {
    condition     = cloudfoundry_service_instance.credentials.id == output.credentials_id
    error_message = "Credentials ID output must match the service instance"
  }

  assert {
    condition     = cloudfoundry_app.app.id == output.app_id
    error_message = "App ID output must match the app instance"
  }
}
