###
# Target org
###

data "cloudfoundry_org" "org" {
  name = var.cf_org_name
}

###
# New Space
###

resource "cloudfoundry_space" "space" {
  name = var.cf_space_name
  org  = data.cloudfoundry_org.org.id
}

###
# User roles
###

data "cloudfoundry_user" "managers" {
  for_each = var.managers
  name     = each.key
  org_id   = data.cloudfoundry_org.org.id
}

data "cloudfoundry_user" "developers" {
  for_each = var.developers
  name     = each.key
  org_id   = data.cloudfoundry_org.org.id
}

data "cloudfoundry_user" "deployers" {
  for_each = var.deployers
  name     = each.key
  org_id   = data.cloudfoundry_org.org.id
}


locals {
  manager_ids = concat(
    [for user in data.cloudfoundry_user.managers : user.id],
    [for user in data.cloudfoundry_user.deployers : user.id]
  )
  developer_ids = concat(
    [for user in data.cloudfoundry_user.developers : user.id],
    [for user in data.cloudfoundry_user.deployers : user.id]
  )
}

resource "cloudfoundry_space_users" "space_permissions" {
  space      = cloudfoundry_space.space.id
  managers   = local.manager_ids
  developers = local.developer_ids
}
