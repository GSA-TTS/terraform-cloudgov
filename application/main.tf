locals {
  app_route = "${var.name}.app.cloud.gov"
  gitref    = "refs/heads/${var.branch_name}"
  org_name  = var.github_org_name
  repo_name = var.github_repo_name
  src       = var.src_code_folder_name
  app_id    = cloudfoundry_app.application.id
}

data "external" "app_zip" {
  program     = ["/bin/sh", "prepare_app.sh"]
  working_dir = path.module
  query = {
    gitref     = local.gitref
    org        = local.org_name
    repo       = local.repo_name
    src_folder = local.src
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
  instances  = var.instances
  strategy   = "rolling"

  routes = [{
    route = local.app_route
  }]

  # service_bindings = [
  #   { params = var.service_bindings }
  # ]

  environment = {
    params = var.environment_json
  }
}

