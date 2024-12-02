locals {
  tags = setunion(["terraform-cloudgov-managed"], var.tags)
}

data "cloudfoundry_service_plans" "s3" {
  name                  = var.s3_plan_name
  service_offering_name = "s3"
}

resource "cloudfoundry_service_instance" "bucket" {
  name         = var.name
  space        = var.cf_space_id
  type         = "managed"
  service_plan = data.cloudfoundry_service_plans.s3.service_plans.0.id
  tags         = local.tags
  parameters   = var.json_params
}
