locals {
  logshipper_service_key = "${var.name}-service-key"

  username     = random_uuid.username.result
  password     = random_password.password.result
  syslog_drain = "https://${local.username}:${local.password}@${cloudfoundry_route.logshipper_route.host}.app.cloud.gov/?drain-type=all"
  domain       = cloudfoundry_route.logshipper_route.domain
  app_id       = cloudfoundry_app.cg_logshipper_app.id
  logdrain_id  = cloudfoundry_user_provided_service.logdrain_service.id
  route        = "${var.cf_space_name}-${var.name}.app.cloud.gov"
}

data "cloudfoundry_org" "org" {
  name = var.cf_org_name
}

data "cloudfoundry_space" "space" {
  name = var.cf_space_name
  org  = data.cloudfoundry_org.org.id
}

data "cloudfoundry_domain" "public" {
  name = "app.cloud.gov"
}

resource "random_uuid" "username" {}
resource "random_password" "password" {
  length  = 16
  special = false
}

module "logs-storage" {
  source       = "github.com/gsa-tts/terraform-cloudgov//s3?ref=v2.2.0"
  cf_space_id  = data.cloudfoundry_space.space.id
  name         = "logshipper-storage"
  s3_plan_name = "basic"
  tags         = ["logshipper-s3"]
}

resource "cloudfoundry_route" "logshipper_route" {
  space  = data.cloudfoundry_space.space.id
  domain = data.cloudfoundry_domain.public.id
  host   = "${var.cf_space_name}-${var.name}"
  # Yields something like: dev-logshipper
}

# TODO if official provider doesn't. We would only want this to run once though.
# Logshipper null_resource meta setup
# - s3 service key
# - logshipper creds (cups)
# - new relic creds (cups)
# - logdrain service (cups)
# resource "null_resource" "cf_service_key" {
#   provisioner "local-exec" {
#     working_dir = path.module
#     interpreter = ["/bin/bash", "-c"]
#     command     = "./logshipper-meta.sh"
#   }
#   triggers = {
#     md5 = "${filemd5("${path.module}/logshipper-meta.sh")}"
#   }
# }

# Uses the legacy provider. We will need to remove this, or upgrade it to the
# official provider when it releases. Alternatively, we can supply a null resource to do it
resource "cloudfoundry_service_key" "logshipper-s3-service-key" {
  provider         = cloudfoundry-community
  name             = locals.logshipper_service_key
  service_instance = module.s3-logshipper-storage.bucket_id
}

# Uses the legacy provider. We will need to remove this, or upgrade it to the
# official provider when it releases. Alternatively, we can supply a null resource to do it
resource "cloudfoundry_user_provided_service" "logshipper_creds" {
  provider = cloudfoundry-community
  name     = "cg-logshipper-creds"
  space    = data.cloudfoundry_space.space.id
  credentials = {
    "HTTP_USER" = local.username
    "HTTP_PASS" = local.password
  }
  tags = ["logshipper-creds"]
}

# Uses the legacy provider. We will need to remove this, or upgrade it to the
# official provider when it releases. Alternatively, we can supply a null resource to do it
resource "cloudfoundry_user_provided_service" "new_relic_credentials" {
  provider = cloudfoundry-community
  name     = "newrelic-creds"
  space    = data.cloudfoundry_space.space.id
  credentials = {
    "NEW_RELIC_LICENSE_KEY"   = var.new_relic_license_key
    "NEW_RELIC_LOGS_ENDPOINT" = var.new_relic_logs_endpoint
  }
  tags = ["newrelic-creds"]
}

# Uses the legacy provider. We will need to remove this, or upgrade it to the
# official provider when it releases. Alternatively, we can supply a null resource to do it
resource "cloudfoundry_user_provided_service" "logdrain_service" {
  provider         = cloudfoundry-community
  name             = "logdrain"
  space            = data.cloudfoundry_space.space.id
  syslog_drain_url = local.syslog_drain
}

data "external" "logshipper_zip" {
  program     = ["/bin/sh", "prepare-logshipper.sh"]
  working_dir = path.module
  query = {
    gitref = var.gitref
  }
}

resource "cloudfoundry_app" "logshipper" {
  name     = var.name
  space    = var.cf_space_name
  org_name = var.cf_org_name

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
    { service_instance = cloudfoundry_user_provided_service.logshipper_creds.name },
    { service_instance = cloudfoundry_user_provided_service.new_relic_credentials.name },
    { service_instance = "logshipper-storage" }
  ]

  routes {
    route = local.route
  }

  environment = {
    PROXYROUTE = var.https_proxy
  }
}

