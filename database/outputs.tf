output "instance_id" {
  value = cloudfoundry_service_instance.rds.id
}

output "database_name" {
  value = cloudfoundry_service_instance.rds.name
}
