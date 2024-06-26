data "cloudfoundry_space" "space" {
  org_name = var.cf_org_name
  name     = var.cf_space_name
}

data "cloudfoundry_service" "rds" {
  name = "aws-rds"
}

resource "cloudfoundry_service_instance" "rds" {
  name         = var.name
  space        = data.cloudfoundry_space.space.id
  service_plan = data.cloudfoundry_service.rds.service_plans[var.rds_plan_name]
  tags         = var.tags
  json_params  = var.json_params
}
