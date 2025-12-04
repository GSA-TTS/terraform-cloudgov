provider "cloudfoundry" {}

variables {
  cf_org_name = "cloud-gov-devtools-development"
  cf_space = {
    id   = "f23cbf69-66a1-4b1d-83d4-e497abdb8dcb"
    name = "terraform-cloudgov-tf-tests"
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
  override_resource {
    target = cloudfoundry_route.app_route
    values = {
      id  = "6db9a64e-8321-425b-b1e3-97b60ca67e8a"
      url = "terraform-cloudgov-drupal-test.app.cloud.gov"
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

  assert {
    condition     = output.endpoint == cloudfoundry_route.app_route.url
    error_message = "The endpoint is retured from the app_route"
  }
}
