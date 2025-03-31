output "endpoint" {
  value = cloudfoundry_route.app_route.url
}

output "route_id" {
  value = cloudfoundry_route.app_route.id
}

output "host" {
  value = cloudfoundry_route.app_route.host
}
