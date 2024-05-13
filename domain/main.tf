locals {
  endpoint     = (var.host_name != null ? "${var.host_name}.${var.domain_name}" : var.domain_name)
  target_apps  = (var.app_name_or_id != null ? [var.app_name_or_id] : var.app_names_or_ids)
  service_name = (var.name == "" ? "${data.cloudfoundry_app.app[local.target_apps[0]].name}-${var.domain_name}" : var.name)
}

data "cloudfoundry_space" "space" {
  org_name = var.cf_org_name
  name     = var.cf_space_name
}

data "cloudfoundry_app" "app" {
  for_each   = toset(local.target_apps)
  name_or_id = each.key
  space      = data.cloudfoundry_space.space.id
}

###########################################################################
# There are two prerequisites for running this module:
#
# 1) Domain must be manually created by an OrgManager:
#     cf create-domain <%= cloud_gov_organization %> TKTK-production-domain-name
# 2) ACME challenge record must be created.
#     See https://cloud.gov/docs/services/external-domain-service/#how-to-create-an-instance-of-this-service
###########################################################################
data "cloudfoundry_domain" "origin_url" {
  name = var.domain_name
}

resource "cloudfoundry_route" "origin_route" {
  domain   = data.cloudfoundry_domain.origin_url.id
  hostname = var.host_name
  space    = data.cloudfoundry_space.space.id

  dynamic "target" {
    for_each = data.cloudfoundry_app.app
    content {
      app = target.value.id
    }
  }
}

data "cloudfoundry_service" "external_domain" {
  name = "external-domain"
}

resource "cloudfoundry_service_instance" "external_domain_instance" {
  name         = local.service_name
  space        = data.cloudfoundry_space.space.id
  service_plan = data.cloudfoundry_service.external_domain.service_plans[var.cdn_plan_name]
  json_params  = "{\"domains\": \"${local.endpoint}\"}"
  tags         = var.tags
}
