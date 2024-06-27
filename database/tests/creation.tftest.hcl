mock_provider "cloudfoundry" {
  mock_data "cloudfoundry_service" {
    defaults = {
      service_plans = {
        "micro-psql" = "03c93c7b-3e1c-47c5-a6c3-1df151d280dd"
      }
    }
  }
}

variables {
  cf_org_name   = "gsa-tts-devtools-prototyping"
  cf_space_name = "terraform-cloudgov-ci-tests"
  rds_plan_name = "micro-psql"
  name          = "terraform-cloudgov-rds-test"
  tags          = ["terraform-cloudgov", "tests"]
  json_params = jsonencode({
    backup_retention_period = 30
  })
}

run "test_db_creation" {
  assert {
    condition     = cloudfoundry_service_instance.rds.id == output.instance_id
    error_message = "Instance ID output must match the service instance"
  }

  assert {
    condition     = cloudfoundry_service_instance.rds.service_plan == data.cloudfoundry_service.rds.service_plans[var.rds_plan_name]
    error_message = "Service Plan should match the rds_plan_name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.rds.name == var.name
    error_message = "Service instance name should match the name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.rds.tags == var.tags
    error_message = "Service instance tags should match the tags variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.rds.json_params == "{\"backup_retention_period\":30}"
    error_message = "Service instance json_params should be configurable"
  }
}
