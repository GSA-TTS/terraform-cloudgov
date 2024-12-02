provider "cloudfoundry" {
  api_url = "https://api.fr.cloud.gov"
  # cf_user and cf_password are passed in via CF_USER and CF_PASSWORD env vars
}

override_data {
  target = data.cloudfoundry_app.app["test-app-does-not-exist"]
  values = {
    id = "f9722bd0-ee5c-4b83-afd9-24e03760a692"
  }
}

override_data {
  target = data.cloudfoundry_app.app["test-app-does-not-exist-2"]
  values = {
    id = "6e214634-8cf6-435c-858c-b0fd4bba8f48"
  }
}

# don't create the connected route because the destination apps don't exist
override_resource {
  target = cloudfoundry_route.origin_route_connected
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
  app_names     = ["test-app-does-not-exist"]
  tags          = ["terraform-cloudgov-managed", "tests"]
}

run "test_domain_creation" {
  assert {
    condition     = cloudfoundry_service_instance.external_domain_instance.id == output.instance_id
    error_message = "Instance ID output must match the service instance"
  }

  assert {
    condition     = cloudfoundry_route.origin_route_connected.0.id == output.route_id
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
    host_name = "terraform-ci-test"
    app_names = []
  }

  assert {
    condition     = cloudfoundry_route.origin_route.0.id == output.route_id
    error_message = "Route ID should return the correct resource id when apps are not specified"
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
    condition     = cloudfoundry_route.origin_route_connected.0.host == var.host_name
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
    name      = ""
    app_names = ["test-app-does-not-exist", "test-app-does-not-exist-2"]
  }

  assert {
    condition     = can(regex("^[a-z-]{23}-${var.domain_name}$", cloudfoundry_service_instance.external_domain_instance.name))
    error_message = "Service Instance name is built from the first app name and domain_name"
  }

  assert {
    condition     = toset([for name, value in data.cloudfoundry_app.app : value.id]) == toset([for t in cloudfoundry_route.origin_route_connected.0.destinations : t.app_id])
    error_message = "Target apps is set to the list of app_names"
  }
}
