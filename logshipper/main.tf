locals {
  username     = random_uuid.username.result
  password     = random_password.password.result
  syslog_drain = "https://${local.username}:${local.password}@${cloudfoundry_route.logshipper_route.host}.app.cloud.gov/?drain-type=all"
  domain       = cloudfoundry_route.logshipper_route.domain
  app_id       = cloudfoundry_app.logshipper.id
  #logdrain_id  = cloudfoundry_user_provided_service.logdrain_service.id
  route = "${var.cf_space.name}-${var.name}.app.cloud.gov"
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

  # service_bindings = [
  #   # { service_instance = cloudfoundry_user_provided_service.logshipper_creds.name },
  #   # { service_instance = cloudfoundry_user_provided_service.logshipper_new_relic_credentials.name },
  #   # { service_instance = local.logshipper_storage_name }
  # ]

  routes = [{
    route = local.route
  }]

  environment = {
    PROXYROUTE = var.https_proxy_url
  }
}

# Logshipper null_resource meta setup
# - logshipper creds (cups)
# - logshipper new relic creds (cups)
# - logdrain service (cups)
resource "null_resource" "cf_services" {
  provisioner "local-exec" {
    working_dir = path.module
    interpreter = ["/bin/bash", "-c"]
    command     = <<-COMMAND
      ./logshipper-meta.sh ${var.cf_org_name} ${var.cf_space.name} ${local.username} ${local.password} ${var.new_relic_license_key} ${var.new_relic_logs_endpoint} ${local.syslog_drain} ${var.name} ${var.logshipper_s3_name}
    COMMAND
  }
  # https://github.com/hashicorp/terraform/issues/8266#issuecomment-454377049
  # A clever way to get this to run every time, otherwise we would be relying on
  # an md5 hash or some other check to force it to run when the plan runs.
  triggers = {
    always_run = "${timestamp()}"
    # md5 = "${filemd5("${path.module}/logshipper-meta.sh")}"
  }
  depends_on = [cloudfoundry_app.logshipper]
}

# Everything below this block uses the legacy provider. We will need to remove this, or upgrade it to the
# official provider when it releases. Alternatively, we can supply a null resource to do it.

# resource "cloudfoundry_user_provided_service" "logshipper_creds" {
#   provider = cloudfoundry-community
#   name     = "logshipper-creds"
#   space    = var.cf_space.id
#   credentials = {
#     "HTTP_USER" = local.username
#     "HTTP_PASS" = local.password
#   }
#   tags = ["logshipper-creds"]
# }

# resource "cloudfoundry_user_provided_service" "logshipper_new_relic_credentials" {
#   provider = cloudfoundry-community
#   name     = "logshipper-newrelic-creds"
#   space    = var.cf_space.id
#   credentials = {
#     "NEW_RELIC_LICENSE_KEY"   = var.new_relic_license_key
#     "NEW_RELIC_LOGS_ENDPOINT" = var.new_relic_logs_endpoint
#   }
#   tags = ["logshipper-newrelic-creds"]
# }

# resource "cloudfoundry_user_provided_service" "logdrain_service" {
#   provider         = cloudfoundry-community
#   name             = "logdrain"
#   space            = var.cf_space.id
#   syslog_drain_url = local.syslog_drain
# }

