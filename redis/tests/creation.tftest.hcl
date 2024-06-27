mock_provider "cloudfoundry" {
  mock_data "cloudfoundry_service" {
    defaults = {
      service_plans = {
        "redis-dev" = "03c93c7b-3e1c-47c5-a6c3-1df151d280dd"
      }
    }
  }
}

variables {
  cf_org_name     = "gsa-tts-devtools-prototyping"
  cf_space_name   = "terraform-cloudgov-ci-tests"
  redis_plan_name = "redis-dev"
  name            = "terraform-cloudgov-redis-test"
  tags            = ["terraform-cloudgov", "tests"]
  json_params = jsonencode({
    engineVersion = "7.0"
  })
}

run "test_redis_creation" {
  assert {
    condition     = cloudfoundry_service_instance.redis.id == output.instance_id
    error_message = "Instance ID output must match the service instance"
  }

  assert {
    condition     = cloudfoundry_service_instance.redis.service_plan == data.cloudfoundry_service.redis.service_plans[var.redis_plan_name]
    error_message = "Service Plan should match the redis_plan_name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.redis.name == var.name
    error_message = "Service instance name should match the name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.redis.tags == var.tags
    error_message = "Service instance tags should match the tags variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.redis.json_params == "{\"engineVersion\":\"7.0\"}"
    error_message = "Service instance json_params should be configurable"
  }
}
