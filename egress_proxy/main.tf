locals {
  # Generate Caddy-compatible allow and deny ACLs, one target per line.
  allowacl = templatefile("${path.module}/acl.tftpl", { list = var.allowlist })
  denyacl  = templatefile("${path.module}/acl.tftpl", { list = var.denylist })

  # Yields something like: orgname-spacename-name.apps.internal, limited to the last 63 characters
  default_route_host = "${var.cf_org_name}-${replace(var.cf_egress_space.name, ".", "-")}-${var.name}"
  egress_route       = "${replace(lower(substr(coalesce(var.route_host, local.default_route_host), -63, -1)), "/^[^a-z]*/", "")}.apps.internal"
}


resource "random_uuid" "username" {}
resource "random_password" "password" {
  length  = 16
  special = false
}

# This zips up just the depoyable files from the specified gitref in the
# cg-egress-proxy repository
data "external" "proxyzip" {
  program     = ["/bin/sh", "prepare-proxy.sh"]
  working_dir = path.module
  query = {
    gitref = var.gitref
  }
}

module "egress_app" {
  source = "../application"

  name          = var.name
  cf_org_name   = var.cf_org_name
  cf_space_name = var.cf_egress_space.name

  gitref               = var.gitref
  github_repo_name     = "cg-egress-proxy"
  src_code_folder_name = "proxy"

  buildpacks = ["binary_buildpack"]
  command    = "./caddy run --config Caddyfile"
  route      = local.egress_route
  instances  = var.instances
  app_memory = var.egress_memory

  environment_variables = {
    PROXY_PORTS : join(" ", var.allowports)
    PROXY_ALLOW : local.allowacl
    PROXY_DENY : local.denyacl
    PROXY_USERNAME : random_uuid.username.result
    PROXY_PASSWORD : random_password.password.result
  }
}

locals {
  https_proxy = "https://${random_uuid.username.result}:${random_password.password.result}@${module.egress_app.endpoint}:61443"
  http_proxy  = "http://${random_uuid.username.result}:${random_password.password.result}@${module.egress_app.endpoint}:8080"
  domain      = module.egress_app.endpoint
  username    = random_uuid.username.result
  password    = random_password.password.result
  https_port  = 61443
  http_port   = 8080
}
