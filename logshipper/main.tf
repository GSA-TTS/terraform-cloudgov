locals {
  username     = random_uuid.username.result
  password     = random_password.password.result
  # The syslog_drain must be registered on the public domain for cloudfoundry.
  # Cloud Foundry uses the syslog URL to route messages to the service.
  # The syslog URL has a scheme of syslog, syslog-tls, or https, and can include a port number.
  # More information here:
  # https://docs.cloudfoundry.org/devguide/services/log-management.html
  # https://docs.cloudfoundry.org/devguide/services/user-provided.html#syslog
  syslog_drain = "https://${local.username}:${local.password}@${cloudfoundry_route.logshipper_route.host}.app.cloud.gov/?drain-type=all"
  domain       = cloudfoundry_route.logshipper_route.domain
  app_id       = cloudfoundry_app.logshipper.id
  route = "${var.cf_space.name}-${var.name}.app.cloud.gov"

  logshipper_creds = "logshipper-creds"
  newrelic_creds_name = "logshipper-newrelic-creds"

  services = merge({
    "${local.logshipper_creds}" = ""
    "${local.newrelic_creds_name}" = ""
    }, var.service_bindings)
}

data "cloudfoundry_domain" "public" {
  name = "app.cloud.gov"
}

resource "random_uuid" "username" {}
resource "random_password" "password" {
  length  = 16
  special = false
}

resource "cloudfoundry_route" "logshipper_route" {
  space  = var.cf_space.id
  domain = data.cloudfoundry_domain.public.id
  host   = "${var.cf_space.name}-${var.name}"
  # Yields something like: dev-logshipper
}

data "external" "logshipper_zip" {
  program     = ["/bin/sh", "prepare-logshipper.sh"]
  working_dir = path.module
  query = {
    gitref = var.gitref
  }
}

resource "cloudfoundry_app" "logshipper" {
  name       = var.name
  space_name = var.cf_space.name
  org_name   = var.cf_org_name

  buildpacks       = ["https://github.com/cloudfoundry/apt-buildpack.git", "nginx_buildpack"]
  path             = "${path.module}/${data.external.logshipper_zip.result.path}"
  source_code_hash = filesha256("${path.module}/${data.external.logshipper_zip.result.path}")

  disk_quota        = var.disk_quota
  memory            = var.logshipper_memory
  instances         = var.logshipper_instances
  strategy          = "rolling"
  health_check_type = "process"

  sidecars = [{
    name          = "fluentbit"
    command       = "/home/vcap/deps/0/apt/opt/fluent-bit/bin/fluent-bit -Y -c fluentbit.conf"
    process_types = ["web"]
  }]

  service_bindings = [
    for service_name, params in local.services : {
      service_instance = service_name
      params           = (params == "" ? "{}" : params) # Empty string -> Minimal JSON
    }
  ]

  routes = [{
    route = local.route
  }]

  environment = {
    PROXYROUTE = var.https_proxy_url
  }
}

resource "cloudfoundry_service_instance" "logshipper_creds" {
  name        = local.logshipper_creds
  type        = "user-provided"
  tags        = ["logshipper-creds"]
  space       = var.cf_space.id
  credentials = <<CREDS
  {
    "HTTP_USER": "${local.username}",
    "HTTP_PASS": "${local.password}"
  }
  CREDS
}

resource "cloudfoundry_service_instance" "logshipper_newrelic_creds" {
  name        = local.newrelic_creds_name
  type        = "user-provided"
  tags        = ["logshipper-newrelic-creds"]
  space       = var.cf_space.id
  credentials = <<NRCREDS
  {
    "NEW_RELIC_LICENSE_KEY": "${var.new_relic_license_key}",
    "NEW_RELIC_LOGS_ENDPOINT": "${var.new_relic_logs_endpoint}"
  }
  NRCREDS
}

resource "cloudfoundry_service_instance" "logdrain" {
  name             = var.syslog_drain_name
  type             = "user-provided"
  tags             = ["syslog-drain"]
  space            = var.cf_space.id
  syslog_drain_url = local.syslog_drain
}

