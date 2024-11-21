locals {
  tags = setunion(["terraform-cloudgov"], var.tags)
}

data "cloudfoundry_service_plans" "redis" {
  name                  = var.redis_plan_name
  service_offering_name = "aws-elasticache-redis"
}

resource "cloudfoundry_service_instance" "redis" {
  name         = var.name
  space        = var.cf_space_id
  type         = "managed"
  service_plan = data.cloudfoundry_service_plans.redis.service_plans.0.id
  tags         = local.tags
  parameters   = var.json_params
}
