output "app_id" {
  value = local.app_id
}

output "endpoint" {
  value = module.route.endpoint
}

output "service_bindings" {
  value = var.service_bindings
}
