output "https_proxy" {
  value = local.https_proxy
  sensitive = true
}

output "domain" {
  value = local.domain
}

output "username" {
  value = local.username
}

output "password" {
  value = local.password
  sensitive = true
}

output "protocol" {
  value = local.protocol
}

output "app_id" {
  value = local.app_id
}

output "port" {
  value = local.port
}
