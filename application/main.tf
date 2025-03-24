locals {
  app_route = coalesce(var.route, "${var.name}.app.cloud.gov")
  app_id    = cloudfoundry_app.application.id
}

data "external" "app_zip" {
  program     = ["/bin/sh", "prepare_app.sh"]
  working_dir = path.module
  query = {
    gitref     = var.gitref
    org        = var.github_org_name
    repo       = var.github_repo_name
    src_folder = var.src_code_folder_name
  }
}

resource "cloudfoundry_app" "application" {
  name       = var.name
  space_name = var.cf_space_name
  org_name   = var.cf_org_name

  path             = "${path.module}/${data.external.app_zip.result.path}"
  source_code_hash = filesha256("${path.module}/${data.external.app_zip.result.path}")

  buildpacks = var.buildpacks
  memory     = var.app_memory
  disk_quota = var.disk_space
  instances  = var.instances
  strategy   = "rolling"

  routes = [{
    route = local.app_route
  }]

  service_bindings = [
    for service_name, params in var.service_bindings : {
      service_instance = service_name
      params           = (params == "" ? "{}" : params) # Empty string -> Minimal JSON
    }
  ]
  environment = merge({
    REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt"
  }, var.environment_variables)
}
