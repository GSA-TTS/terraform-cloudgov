data "cloudfoundry_org" "org" {
  name = var.cf_org_name
}

resource "cloudfoundry_space" "space" {
  name      = var.cf_space_name
  org       = data.cloudfoundry_org.org.id
  allow_ssh = var.allow_ssh
}

###
# User roles
###

locals {
  manager_names   = setunion(var.managers, var.deployers)
  developer_names = setunion(var.developers, var.deployers)
}

resource "cloudfoundry_space_role" "managers" {
  for_each = local.manager_names
  username = each.key
  space    = cloudfoundry_space.space.id
  type     = "space_manager"
}

resource "cloudfoundry_space_role" "developers" {
  for_each = local.developer_names
  username = each.key
  space    = cloudfoundry_space.space.id
  type     = "space_developer"
}
