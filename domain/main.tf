locals {
  service_name = (var.name == null ? "${coalesce(var.host_name, var.cdn_plan_name)}-${var.domain_name}-svc" : var.name)
  tags         = setunion(["terraform-cloudgov-managed"], var.tags)
  destinations = (length(var.app_ids) == 0 ? null : [
    for id in var.app_ids : { app_id = id }
  ])
  endpoint  = cloudfoundry_route.origin_route.url
  domain_id = (var.create_domain ? cloudfoundry_domain.origin_url.0.id : data.cloudfoundry_domain.origin_url.0.id)
}

###########################################################################
# There are two prerequisites for running this module:
#
# 1) Domain must be created by an OrgManager via either setting var.create_domain = true or manually with:
#     cf create-domain <%= var.cf_org_name %> <%= var.domain_name %>
# 2) ACME challenge record must be created.
#     See https://cloud.gov/docs/services/external-domain-service/#how-to-create-an-instance-of-this-service
###########################################################################
data "cloudfoundry_org" "org" {
  name = var.cf_org_name
}
resource "cloudfoundry_domain" "origin_url" {
  count = (var.create_domain ? 1 : 0)

  org  = data.cloudfoundry_org.org.id
  name = var.domain_name
}

data "cloudfoundry_domain" "origin_url" {
  count = (var.create_domain ? 0 : 1)
  name  = var.domain_name
}

resource "cloudfoundry_route" "origin_route" {
  space  = var.cf_space.id
  domain = local.domain_id
  host   = var.host_name

  destinations = local.destinations
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
