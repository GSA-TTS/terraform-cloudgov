locals {
  testing_org       = "sandbox-gsa"
  testing_space     = "ryan.ahearn"
  testing_plan_name = "basic-sandbox"
}

module "main" {
  source = "../.."

  cf_org_name   = local.testing_org
  cf_space_name = local.testing_space
  s3_plan_name  = local.testing_plan_name
  name          = "terraform-cloudgov-s3-test"
}

resource "test_assertions" "bucket_id" {
  component = "bucket_id"

  check "guid" {
    description = "bucket_id is a GUID"
    condition   = can(regex("^\\w{8}-\\w{4}-\\w{4}-\\w{4}-\\w{12}$", module.main.bucket_id))
  }
}
