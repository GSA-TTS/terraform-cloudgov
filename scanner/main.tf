locals {
  domain = "apps.internal"
}

data "external" "scannerzip" {
  program     = ["/bin/sh", "prepare-scanner.sh"]
  working_dir = path.module
  query = {
    gitref     = var.gitref
    org        = var.github_org_name
    repo       = var.github_repo_name
    src_folder = var.src_code_folder_name
  }
}

resource "cloudfoundry_app" "scanner_app" {
  name       = var.name
  space_name = var.cf_space.name
  org_name   = var.cf_org_name

  buildpacks       = var.buildpacks
  path             = "${path.module}/${data.external.scannerzip.result.path}"
  source_code_hash = filesha256("${path.module}/${data.external.scannerzip.result.path}")

  timeout           = 180
  disk_quota        = var.disk_quota
  memory            = var.scanner_memory
  instances         = var.scanner_instances
  strategy          = "rolling"
  health_check_type = "port"

  service_bindings = [
    for service_name, params in var.service_bindings : {
      service_instance = service_name
      params           = (params == "" ? "{}" : params) # Empty string -> Minimal JSON
    }
  ]

  environment = merge({
    PROXYROUTE = "${var.https_proxy_url}"
  }, var.environment_variables)
}

module "route" {
  source = "../app_route"

  cf_org_name   = var.cf_org_name
  cf_space_name = var.cf_space.name
  domain        = local.domain
  hostname      = coalesce(var.hostname, var.name)
  app_ids       = [cloudfoundry_app.scanner_app.id]
}
