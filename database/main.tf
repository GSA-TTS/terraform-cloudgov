locals {
  tags = setunion(["terraform-cloudgov-managed"], var.tags)
}

data "cloudfoundry_service_plans" "rds" {
  name                  = var.rds_plan_name
  service_offering_name = "aws-rds"
}

resource "cloudfoundry_service_instance" "rds" {
  name         = var.name
  space        = var.cf_space_id
  type         = "managed"
  service_plan = data.cloudfoundry_service_plans.rds.service_plans.0.id
  tags         = local.tags
  parameters   = var.json_params
}
