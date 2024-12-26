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

data "cloudfoundry_user" "users" {
  for_each = setunion(local.manager_names, local.developer_names)
  name     = each.key
}
resource "cloudfoundry_space_role" "managers" {
  for_each = local.manager_names
  user     = data.cloudfoundry_user.users[each.key].users.0.id
  space    = cloudfoundry_space.space.id
  type     = "space_manager"
}

resource "cloudfoundry_space_role" "developers" {
  for_each = local.developer_names
  user     = data.cloudfoundry_user.users[each.key].users.0.id
  space    = cloudfoundry_space.space.id
  type     = "space_developer"
}
