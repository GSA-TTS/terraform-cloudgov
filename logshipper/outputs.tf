output "username" {
  value = local.username
}

output "password" {
  value     = local.password
  sensitive = true
}

output "syslog_drain_url" {
  value     = local.syslog_drain
  sensitive = true
}

output "domain" {
  value = local.domain
}

output "syslog_drain_name" {
  value = var.syslog_drain_name
}

output "app_id" {
  value = local.app_id
}
