output "app_id" {
  value = cloudfoundry_app.clamav_api.id
}

output "route_id" {
  value = cloudfoundry_route.clamav_route.id
}

output "endpoint" {
  value = cloudfoundry_route.clamav_route.url
}
