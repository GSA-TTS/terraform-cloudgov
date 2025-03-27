provider "cloudfoundry" {}

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
  tags          = ["terraform-cloudgov-managed", "tests"]
}

run "test_managing_domain_resource" {
  variables {
    domain_name   = "test.devtools.gov"
    create_domain = true
  }

  assert {
    condition     = output.endpoint == "test.devtools.gov"
    error_message = "The endpoint matches the created domain"
  }

  assert {
    condition     = cloudfoundry_route.origin_route.id == output.route_id
    error_message = "Route ID output must match the created route"
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
    host_name     = "cdn"
  }

  assert {
    condition     = cloudfoundry_service_instance.external_domain_instance.service_plan == data.cloudfoundry_service_plans.external_domain.service_plans.0.id
    error_message = "Service Plan should match the cdn_plan_name variable"
  }
}
