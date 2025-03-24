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
  value = module.egress_app.app_id
}

output "json_credentials" {
  value = jsonencode({
    "https_uri"  = local.https_proxy
    "http_uri"   = local.http_proxy
    "domain"     = local.domain
    "username"   = local.username
    "password"   = local.password
    "https_port" = local.https_port
    "http_port"  = local.http_port
  })
  sensitive = true
}
