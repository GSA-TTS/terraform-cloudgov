output "space_id" {
  value = cloudfoundry_space.space.id
}

output "space_name" {
  value = cloudfoundry_space.space.name
}

output "space" {
  value = cloudfoundry_space.space
}

output "developer_role_ids" {
  value = { for username in local.developer_names : username => cloudfoundry_space_role.developers[username].id }
}

output "manager_role_ids" {
  value = { for username in local.manager_names : username => cloudfoundry_space_role.managers[username].id }
}

output "auditor_role_ids" {
  value = { for username in var.auditors : username => cloudfoundry_space_role.auditors[username].id }
}
