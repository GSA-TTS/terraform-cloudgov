provider "cloudfoundry" {
  api_url = "https://api.fr.cloud.gov"
  # cf_user and cf_password are passed in via CF_USER and CF_PASSWORD env vars
}

variables {
  cf_org_name   = "gsa-tts-devtools-prototyping"
  cf_space_name = "terraform-cloudgov-ci-tests"
  s3_plan_name  = "basic"
  name          = "terraform-cloudgov-s3-test"
  tags          = ["terraform-cloudgov", "tests"]
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
    condition     = cloudfoundry_service_instance.bucket.service_plan == data.cloudfoundry_service.s3.service_plans[var.s3_plan_name]
    error_message = "Service Plan should match the s3_plan_name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.bucket.name == var.name
    error_message = "Service instance name should match the name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.bucket.tags == var.tags
    error_message = "Service instance tags should match the tags variable"
  }
}

run "test_json_params" {
  command = plan

  variables {
    json_params = jsonencode({
      object_ownership = "BucketOwnerEnforced"
    })
  }

  assert {
    condition     = cloudfoundry_service_instance.bucket.json_params == "{\"object_ownership\":\"BucketOwnerEnforced\"}"
    error_message = "Service instance json_params should be configurable"
  }
}
