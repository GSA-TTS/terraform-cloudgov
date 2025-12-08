provider "cloudfoundry" {}

variables {
  # this is the ID of the terraform-cloudgov-tf-tests space
  cf_space_id   = "f23cbf69-66a1-4b1d-83d4-e497abdb8dcb"
  rds_plan_name = "micro-psql"
  name          = "terraform-cloudgov-rds-test"
  tags          = ["terraform-cloudgov-managed", "tests"]
  json_params = jsonencode({
    backup_retention_period = 30
  })
}

run "test_db_creation" {
  override_resource {
    target = cloudfoundry_service_instance.rds
    values = {
      id = "f6925fad-f9e8-4c93-b69f-132438f6a2f4"
    }
  }

  assert {
    condition     = cloudfoundry_service_instance.rds.id == output.instance_id
    error_message = "Instance ID output must match the service instance"
  }

  assert {
    condition     = cloudfoundry_service_instance.rds.service_plan == data.cloudfoundry_service_plans.rds.service_plans.0.id
    error_message = "Service Plan should match the rds_plan_name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.rds.name == var.name
    error_message = "Service instance name should match the name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.rds.tags == tolist(var.tags)
    error_message = "Service instance tags should match the tags variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.rds.parameters == "{\"backup_retention_period\":30}"
    error_message = "Service instance json_params should be configurable"
  }
}
