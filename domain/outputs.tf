output "instance_id" {
  value = cloudfoundry_service_instance.external_domain_instance.id
}

output "route_id" {
  value = (length(var.app_names) == 0 ? cloudfoundry_route.origin_route.0.id : cloudfoundry_route.origin_route_connected.0.id)
}
