variable "cf_user" {}
variable "cf_password" {
  sensitive = true
}

output "cf_user" {
  value = var.cf_user
}

output "cf_password" {
  value     = var.cf_password
  sensitive = true
}
