output "app_id" {
  value = cloudfoundry_app.clamav_api.id
}

output "endpoint" {
  value = local.endpoint
}
