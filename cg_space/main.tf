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

###
# Space Security Groups
###

data "cloudfoundry_asg" "asgs" {
  for_each = var.asg_names
  name     = each.key
}

locals {
  asg_ids = [for asg in data.cloudfoundry_asg.asgs : asg.id]
}

resource "cloudfoundry_space_asgs" "running_security_groups" {
  space        = cloudfoundry_space.space.id
  running_asgs = local.asg_ids
}
