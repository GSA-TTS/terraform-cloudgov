data "cloudfoundry_space" "space" {
  org_name = var.cf_org_name
  name     = var.cf_space_name
}

data "cloudfoundry_service" "redis" {
  name = "aws-elasticache-redis"
}

resource "cloudfoundry_service_instance" "redis" {
  name             = var.name
  space            = data.cloudfoundry_space.space.id
  service_plan     = data.cloudfoundry_service.redis.service_plans[var.redis_plan_name]
  recursive_delete = var.recursive_delete
  tags             = var.tags
  json_params      = var.json_params
}
