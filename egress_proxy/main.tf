locals {
  # Generate Caddy-compatible allow and deny ACLs, one target per line.
  #
  # For now, there's just one consolidated allowlist and denylist, no matter
  # what apps they were specified for. Future improvments could improve this,
  # but it would mean also changing the proxy to be both more complex (in terms
  # of how the Caddyfile is constructed) and more discriminating (in terms of
  # recognizing client apps based on GUIDs supplied by Envoy in request headers,
  # as well as the destination ports). However, adding these improvements won't
  # require modifying the module's interface, since we're already collecting
  # that refined information.
  allowacl = templatefile("${path.module}/acl.tftpl", { list = var.allowlist })
  denyacl  = templatefile("${path.module}/acl.tftpl", { list = var.denylist })
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

###
### Set up the authenticated egress application in the target space on apps.internal
###
data "cloudfoundry_domain" "internal" {
  name = "apps.internal"
}

resource "cloudfoundry_route" "egress_route" {
  space  = var.cf_egress_space.id
  domain = data.cloudfoundry_domain.internal.id
  host   = substr("${var.cf_org_name}-${replace(var.cf_egress_space.name, ".", "-")}-${var.name}", -63, -1)
  # Yields something like: orgname-spacename-name.apps.internal, limited to the last 63 characters
  destinations = [{
    app_id = cloudfoundry_app.egress_app.id
  }]
}

###
### Create a credential service for bound clients to use when make requests of the proxy
###
locals {
  https_proxy = "https://${random_uuid.username.result}:${random_password.password.result}@${cloudfoundry_route.egress_route.url}:61443"
  domain      = cloudfoundry_route.egress_route.url
  username    = random_uuid.username.result
  password    = random_password.password.result
  protocol    = "https"
  port        = 61443
}

resource "cloudfoundry_service_instance" "credentials" {
  name  = "${var.name}-creds"
  space = var.cf_client_space.id
  type  = "user-provided"
  credentials = jsonencode({
    "uri"      = local.https_proxy
    "domain"   = local.domain
    "username" = local.username
    "password" = local.password
    "protocol" = local.protocol
    "port"     = local.port
  })
}
