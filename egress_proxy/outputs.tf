output "https_proxy" {
  value     = local.https_proxy
  sensitive = true
}

output "domain" {
  value = local.domain
}

output "port" {
  value = local.port
}

output "username" {
  value = local.username
}

output "password" {
  value     = local.password
  sensitive = true
}

output "protocol" {
  value = local.protocol
}

output "app_id" {
  value = cloudfoundry_app.egress_app.id
}

output "credential_service_ids" {
  value = { for k, v in cloudfoundry_service_instance.credentials : k => v.id }
}

output "credential_service_name" {
  value = values(cloudfoundry_service_instance.credentials)[0].name
}
