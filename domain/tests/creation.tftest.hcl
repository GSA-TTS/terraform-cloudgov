provider "cloudfoundry" {}

# don't create the connected route because the destination apps don't exist
override_resource {
  target = cloudfoundry_route.origin_route
  values = {
    url = "www.apps.internal"
  }
}

# don't create the external domain instance because the CNAME records don't exist
override_resource {
  target = cloudfoundry_service_instance.external_domain_instance
}

variables {
  cf_org_name = "gsa-tts-devtools-prototyping"
  cf_space = {
    id   = "15836eb6-a57e-4579-bca7-99764c5a01a4"
    name = "terraform-cloudgov-ci-tests"
  }
  cdn_plan_name = "domain"
  domain_name   = "apps.internal"
  name          = "terraform-cloudgov-domain-test"
  app_ids       = ["f9722bd0-ee5c-4b83-afd9-24e03760a692"]
  tags          = ["terraform-cloudgov-managed", "tests"]
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
    condition     = cloudfoundry_service_instance.external_domain_instance.service_plan == data.cloudfoundry_service_plans.external_domain.service_plans.0.id
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
}

run "test_no_apps" {
  variables {
    host_name = "www"
    app_ids   = []
  }

  assert {
    condition     = cloudfoundry_route.origin_route.id == output.route_id
    error_message = "The route is still constructed"
  }

  assert {
    condition     = cloudfoundry_service_instance.external_domain_instance.parameters == "{\"domains\": \"${var.host_name}.${var.domain_name}\"}"
    error_message = "Service instance parameters should define the endpoint"
  }
}

run "test_with_hostname" {
  variables {
    host_name = "www"
  }

  assert {
    condition     = cloudfoundry_route.origin_route.host == var.host_name
    error_message = "Route hostname should be set to value of var.host_name"
  }

  assert {
    condition     = cloudfoundry_service_instance.external_domain_instance.parameters == "{\"domains\": \"${var.host_name}.${var.domain_name}\"}"
    error_message = "Service instance parameters should define the endpoint"
  }
}

run "test_cdn_creation" {
  variables {
    cdn_plan_name = "domain-with-cdn"
  }

  assert {
    condition     = cloudfoundry_service_instance.external_domain_instance.service_plan == data.cloudfoundry_service_plans.external_domain.service_plans.0.id
    error_message = "Service Plan should match the cdn_plan_name variable"
  }
}

run "test_multi_app_target" {
  variables {
    name = null
    app_ids = [
      "f9722bd0-ee5c-4b83-afd9-24e03760a692",
      "6e214634-8cf6-435c-858c-b0fd4bba8f48"
    ]
  }

  assert {
    condition     = "${var.cdn_plan_name}-${var.domain_name}-svc" == cloudfoundry_service_instance.external_domain_instance.name
    error_message = "Service Instance name is built from the first app name and domain_name"
  }

  assert {
    condition     = toset(["f9722bd0-ee5c-4b83-afd9-24e03760a692", "6e214634-8cf6-435c-858c-b0fd4bba8f48"]) == toset([for t in cloudfoundry_route.origin_route.destinations : t.app_id])
    error_message = "Target apps is set to the list of app_names"
  }
}
