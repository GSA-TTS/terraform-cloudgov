output "instance_id" {
  value = cloudfoundry_service_instance.external_domain_instance.id
}

output "route_id" {
  value = cloudfoundry_route.origin_route.id
}

output "endpoint" {
  value = local.endpoint
}
