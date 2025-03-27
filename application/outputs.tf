output "app_id" {
  value = cloudfoundry_app.application.id
}

output "endpoint" {
  value = module.route.endpoint
}

output "service_bindings" {
  value = var.service_bindings
}
