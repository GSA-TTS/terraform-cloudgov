locals {
  testing_org       = "sandbox-gsa"
  testing_space     = "ryan.ahearn"
  testing_plan_name = "redis-dev"
}

module "main" {
  source = "../.."

  cf_org_name     = local.testing_org
  cf_space_name   = local.testing_space
  redis_plan_name = local.testing_plan_name
  name            = "terraform-cloudgov-redis-test"
}

resource "test_assertions" "instance_id" {
  component = "instance_id"

  check "guid" {
    description = "instance_id is a GUID"
    condition   = can(regex("^\\w{8}-\\w{4}-\\w{4}-\\w{4}-\\w{12}$", module.main.instance_id))
  }
}
