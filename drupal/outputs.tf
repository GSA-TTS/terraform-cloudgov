output "database_id" {
  value = module.database.instance_id
}

output "bucket_id" {
  value = module.bucket.bucket_id
}

output "credentials_id" {
  value = cloudfoundry_service_instance.credentials.id
}

output "app_id" {
  value = cloudfoundry_app.app.id
}

output "endpoint" {
  value = cloudfoundry_route.app_route.url
}
