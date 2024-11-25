locals {
  # Generate Caddy-compatible allow and deny ACLs, one target per line.
  allowacl = templatefile("${path.module}/acl.tftpl", { list = var.allowlist })
  denyacl  = templatefile("${path.module}/acl.tftpl", { list = var.denylist })

  # Yields something like: orgname-spacename-name.apps.internal, limited to the last 63 characters
  route_host   = substr("${var.cf_org_name}-${replace(var.cf_egress_space.name, ".", "-")}-${var.name}", -63, -1)
  egress_route = "${local.route_host}.apps.internal"
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

resource "cloudfoundry_app" "egress_app" {
  name       = var.name
  space_name = var.cf_egress_space.name
  org_name   = var.cf_org_name


  path             = "${path.module}/${data.external.proxyzip.result.path}"
  source_code_hash = filesha256("${path.module}/${data.external.proxyzip.result.path}")
  buildpacks       = ["binary_buildpack"]
  command          = "./caddy run --config Caddyfile"
  memory           = var.egress_memory
  instances        = var.instances
  strategy         = "rolling"

  routes = [{
    route = local.egress_route
  }]

  environment = {
    PROXY_PORTS : join(" ", var.allowports)
    PROXY_ALLOW : local.allowacl
    PROXY_DENY : local.denyacl
    PROXY_USERNAME : random_uuid.username.result
    PROXY_PASSWORD : random_password.password.result
  }
}

locals {
  https_proxy = "https://${random_uuid.username.result}:${random_password.password.result}@${local.egress_route}:61443"
  http_proxy  = "http://${random_uuid.username.result}:${random_password.password.result}@${local.egress_route}:8080"
  domain      = local.egress_route
  username    = random_uuid.username.result
  password    = random_password.password.result
  https_port  = 61443
  http_port   = 8080
}
