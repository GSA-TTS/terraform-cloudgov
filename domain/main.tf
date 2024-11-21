locals {
  service_name  = (var.name == "" ? "${var.app_names[0]}-${var.domain_name}" : var.name)
  tags          = setunion(["terraform-cloudgov"], var.tags)
  connect_route = length(var.app_names) > 0
  endpoint      = (local.connect_route ? cloudfoundry_route.origin_route_connected.0.url : cloudfoundry_route.origin_route.0.url)
}

data "cloudfoundry_app" "app" {
  for_each   = toset(var.app_names)
  name       = each.key
  space_name = var.cf_space.name
  org_name   = var.cf_org_name
}

###########################################################################
# There are two prerequisites for running this module:
#
# 1) Domain must be manually created by an OrgManager:
#     cf create-domain <%= var.cf_org_name %> <%= var.domain_name %>
# 2) ACME challenge record must be created.
#     See https://cloud.gov/docs/services/external-domain-service/#how-to-create-an-instance-of-this-service
###########################################################################
data "cloudfoundry_domain" "origin_url" {
  name = var.domain_name
}

resource "cloudfoundry_route" "origin_route_connected" {
  count  = local.connect_route ? 1 : 0
  space  = var.cf_space.id
  domain = data.cloudfoundry_domain.origin_url.id
  host   = var.host_name

  destinations = [for name, app in data.cloudfoundry_app.app : { app_id = app.id }]
}

resource "cloudfoundry_route" "origin_route" {
  count  = local.connect_route ? 0 : 1
  space  = var.cf_space.id
  domain = data.cloudfoundry_domain.origin_url.id
  host   = var.host_name
}

data "cloudfoundry_service_plans" "external_domain" {
  name                  = var.cdn_plan_name
  service_offering_name = "external-domain"
}

resource "cloudfoundry_service_instance" "external_domain_instance" {
  name         = local.service_name
  space        = var.cf_space.id
  service_plan = data.cloudfoundry_service_plans.external_domain.service_plans.0.id
  parameters   = "{\"domains\": \"${local.endpoint}\"}"
  tags         = local.tags
  type         = "managed"
}
