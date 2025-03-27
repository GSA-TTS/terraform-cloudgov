locals {
  # Generate Caddy-compatible allow and deny ACLs, one target per line.
  allowacl = templatefile("${path.module}/acl.tftpl", { list = var.allowlist })
  denyacl  = templatefile("${path.module}/acl.tftpl", { list = var.denylist })

  # Yields something like: orgname-spacename-name.apps.internal, limited to the last 63 characters
  default_route_host = "${var.cf_org_name}-${replace(var.cf_egress_space.name, ".", "-")}-${var.name}"
  egress_host        = replace(lower(substr(coalesce(var.route_host, local.default_route_host), -63, -1)), "/^[^a-z]*/", "")
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

  environment = {
    PROXY_PORTS : join(" ", var.allowports)
    PROXY_ALLOW : local.allowacl
    PROXY_DENY : local.denyacl
    PROXY_USERNAME : random_uuid.username.result
    PROXY_PASSWORD : random_password.password.result
  }
}

data "cloudfoundry_domain" "internal_domain" {
  name = "apps.internal"
}
resource "cloudfoundry_route" "egress_route" {
  domain = data.cloudfoundry_domain.internal_domain.id
  space  = var.cf_egress_space.id
  host   = local.egress_host
  destinations = [{
    app_id = cloudfoundry_app.egress_app.id
  }]
}

locals {
  domain      = cloudfoundry_route.egress_route.url
  https_proxy = "https://${random_uuid.username.result}:${random_password.password.result}@${local.domain}:61443"
  http_proxy  = "http://${random_uuid.username.result}:${random_password.password.result}@${local.domain}:8080"
  username    = random_uuid.username.result
  password    = random_password.password.result
  https_port  = 61443
  http_port   = 8080
}
