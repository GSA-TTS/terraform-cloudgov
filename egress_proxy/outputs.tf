output "https_proxy" {
  value     = local.https_proxy
  sensitive = true
}

output "http_proxy" {
  value     = local.http_proxy
  sensitive = true
}

output "domain" {
  value = local.domain
}

output "http_port" {
  value = local.http_port
}

output "https_port" {
  value = local.https_port
}

output "username" {
  value = local.username
}

output "password" {
  value     = local.password
  sensitive = true
}

output "app_id" {
  value = cloudfoundry_app.egress_app.id
}
