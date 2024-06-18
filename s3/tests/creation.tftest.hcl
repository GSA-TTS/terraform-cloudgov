provider "cloudfoundry" {
  api_url = "https://api.fr.cloud.gov"
  # cf_user and cf_password are passed in via CF_USER and CF_PASSWORD env vars
}

variables {
  cf_org_name   = "sandbox-gsa"
  cf_space_name = "ryan.ahearn"
  s3_plan_name  = "basic-sandbox"
  name          = "terraform-cloudgov-s3-test"
}

run "test_creation" {
  assert {
    condition     = can(regex("^\\w{8}-\\w{4}-\\w{4}-\\w{4}-\\w{12}$", output.bucket_id))
    error_message = "Bucket ID should be a GUID"
  }

  assert {
    condition     = cloudfoundry_service_instance.bucket.id == output.bucket_id
    error_message = "Bucket ID output must match the service instance"
  }

  assert {
    condition     = cloudfoundry_service_instance.bucket.service_plan == data.cloudfoundry_service.s3.service_plans["basic-sandbox"]
    error_message = "Service Plan should be 'basic-sandbox'"
  }
}
