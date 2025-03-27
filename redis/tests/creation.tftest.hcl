provider "cloudfoundry" {}

variables {
  # this is the ID of the terraform-cloudgov-ci-tests space
  cf_space_id     = "15836eb6-a57e-4579-bca7-99764c5a01a4"
  redis_plan_name = "redis-dev"
  name            = "terraform-cloudgov-redis-test"
  tags            = ["terraform-cloudgov-managed", "tests"]
  json_params = jsonencode({
    engineVersion = "7.0"
  })
}

run "test_redis_creation" {
  override_resource {
    target = cloudfoundry_service_instance.redis
    values = {
      id = "2a4dae63-2fb7-4a76-975d-eebb9a7b8d96"
    }
  }

  assert {
    condition     = cloudfoundry_service_instance.redis.id == output.instance_id
    error_message = "Instance ID output must match the service instance"
  }

  assert {
    condition     = cloudfoundry_service_instance.redis.service_plan == data.cloudfoundry_service_plans.redis.service_plans.0.id
    error_message = "Service Plan should match the redis_plan_name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.redis.name == var.name
    error_message = "Service instance name should match the name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.redis.tags == tolist(var.tags)
    error_message = "Service instance tags should match the tags variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.redis.parameters == "{\"engineVersion\":\"7.0\"}"
    error_message = "Service instance parameters should be configurable"
  }
}
