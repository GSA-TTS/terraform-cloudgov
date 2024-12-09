provider "cloudfoundry" {
  api_url = "https://api.fr.cloud.gov"
  # cf_user and cf_password are passed in via CF_USER and CF_PASSWORD env vars
}

variables {
  # this is the ID of the terraform-cloudgov-ci-tests space
  cf_space_id  = "15836eb6-a57e-4579-bca7-99764c5a01a4"
  s3_plan_name = "basic-sandbox"
  name         = "terraform-cloudgov-s3-test"
  tags         = ["terraform-cloudgov-managed", "tests"]
}

run "test_bucket_creation" {
  assert {
    condition     = can(regex("^\\w{8}-\\w{4}-\\w{4}-\\w{4}-\\w{12}$", output.bucket_id))
    error_message = "Bucket ID should be a GUID"
  }

  assert {
    condition     = cloudfoundry_service_instance.bucket.id == output.bucket_id
    error_message = "Bucket ID output must match the service instance"
  }

  assert {
    condition     = cloudfoundry_service_instance.bucket.service_plan == data.cloudfoundry_service_plans.s3.service_plans.0.id
    error_message = "Service Plan should match the s3_plan_name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.bucket.name == var.name
    error_message = "Service instance name should match the name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.bucket.tags == tolist(var.tags)
    error_message = "Service instance tags should match the tags variable"
  }
}

run "test_parameters" {
  command = plan

  variables {
    json_params = jsonencode({
      object_ownership = "BucketOwnerEnforced"
    })
  }

  assert {
    condition     = cloudfoundry_service_instance.bucket.parameters == "{\"object_ownership\":\"BucketOwnerEnforced\"}"
    error_message = "Service instance parameters should be configurable"
  }
}
