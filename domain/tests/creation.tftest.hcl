mock_provider "cloudfoundry" {
  mock_data "cloudfoundry_service" {
    defaults = {
      service_plans = {
        "domain"          = "03c93c7b-3e1c-47c5-a6c3-1df151d280dd"
        "domain-with-cdn" = "7dd54395-1e90-4493-8a6d-45d81469291f"
      }
    }
  }
}

variables {
  cf_org_name   = "gsa-tts-devtools-prototyping"
  cf_space_name = "terraform-cloudgov-ci-tests"
  cdn_plan_name = "domain"
  domain_name   = "devtools.tts.gsa.gov"
  name          = "terraform-cloudgov-domain-test"
  tags          = ["terraform-cloudgov", "tests"]
}

run "test_domain_creation" {
  assert {
    condition     = cloudfoundry_service_instance.external_domain_instance.id == output.instance_id
    error_message = "Instance ID output must match the service instance"
  }

  assert {
    condition     = cloudfoundry_route.origin_route.id == output.route_id
    error_message = "Route ID output must match the created route"
  }

  assert {
    condition     = cloudfoundry_service_instance.external_domain_instance.service_plan == data.cloudfoundry_service.external_domain.service_plans[var.cdn_plan_name]
    error_message = "Service Plan should match the cdn_plan_name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.external_domain_instance.name == var.name
    error_message = "Service instance name should match the name variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.external_domain_instance.tags == var.tags
    error_message = "Service instance tags should match the tags variable"
  }

  assert {
    condition     = cloudfoundry_service_instance.external_domain_instance.json_params == "{\"domains\": \"${var.domain_name}\"}"
    error_message = "Service instance json_params should define the endpoint"
  }
}

run "test_with_hostname" {
  variables {
    host_name = "www"
  }

  assert {
    condition     = cloudfoundry_route.origin_route.hostname == var.host_name
    error_message = "Route hostname should be set to value of var.host_name"
  }

  assert {
    condition     = cloudfoundry_service_instance.external_domain_instance.json_params == "{\"domains\": \"${var.host_name}.${var.domain_name}\"}"
    error_message = "Service instance json_params should define the endpoint"
  }
}

run "test_cdn_creation" {
  variables {
    cdn_plan_name = "domain-with-cdn"
  }

  assert {
    condition     = cloudfoundry_service_instance.external_domain_instance.service_plan == data.cloudfoundry_service.external_domain.service_plans[var.cdn_plan_name]
    error_message = "Service Plan should match the cdn_plan_name variable"
  }
}

run "test_single_app_target" {
  variables {
    name           = ""
    app_name_or_id = "terraform_cloudgov_app"
  }

  assert {
    condition     = can(regex("^\\w{8}-${var.domain_name}$", cloudfoundry_service_instance.external_domain_instance.name))
    error_message = "Service Instance name is built from the first app name and domain_name"
  }

  assert {
    condition     = [for t in cloudfoundry_route.origin_route.target : t.app] == [data.cloudfoundry_app.app[var.app_name_or_id].id]
    error_message = "Sets the route targets to be the app_name_or_id"
  }
}

run "test_multi_app_target" {
  variables {
    name             = ""
    app_names_or_ids = ["terraform_cloudgov_app", "terraform_cloudgov_app_2"]
  }

  assert {
    condition     = can(regex("^\\w{8}-${var.domain_name}$", cloudfoundry_service_instance.external_domain_instance.name))
    error_message = "Service Instance name is built from the first app name and domain_name"
  }

  assert {
    condition     = toset([for name, value in data.cloudfoundry_app.app : value.id]) == toset([for t in cloudfoundry_route.origin_route.target : t.app])
    error_message = "Target apps is set to the list of app_names_or_ids"
  }
}

run "test_conflicting_variables" {
  variables {
    app_name_or_id   = "terraform_cloudgov_app"
    app_names_or_ids = ["terraform_cloudgov_app_2", "terraform_cloudgov_app_3"]
  }

  assert {
    condition     = [for t in cloudfoundry_route.origin_route.target : t.app] == [data.cloudfoundry_app.app[var.app_name_or_id].id]
    error_message = "Sets the route targets to be the app_name_or_id"
  }

  assert {
    condition     = cloudfoundry_service_instance.external_domain_instance.name == var.name
    error_message = "Service Instance name is set to var.name when present"
  }
}
