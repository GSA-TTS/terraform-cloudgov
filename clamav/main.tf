data "cloudfoundry_space" "space" {
  org_name = var.cf_org_name
  name     = var.cf_space_name
}

data "cloudfoundry_domain" "internal" {
  name = "apps.internal"
}

data "cloudfoundry_app" "app" {
  name_or_id = var.app_name_or_id
  space      = data.cloudfoundry_space.space.id
}

resource "cloudfoundry_route" "clamav_route" {
  space    = data.cloudfoundry_space.space.id
  domain   = data.cloudfoundry_domain.internal.id
  hostname = var.name
}

resource "cloudfoundry_app" "clamav_api" {
  name         = var.name
  space        = data.cloudfoundry_space.space.id
  memory       = var.clamav_memory
  disk_quota   = 2048
  timeout      = 600
  strategy     = "rolling"
  docker_image = var.clamav_image
  tags         = var.tags
  routes {
    route = cloudfoundry_route.clamav_route.id
  }
  environment = {
    # Only set the proxy environment variables if a value was supplied.
    # Otherwise, ensure that a harmless envvar gets set instead.
    # This avoids confusing the app with variables that are set to ""!
    "${var.proxy_server != "" ? "PROXY_SERVER" : "proxy_server_is_not_set"}"       = var.proxy_server
    "${var.proxy_port != "" ? "PROXY_PORT" : "proxy_port_is_not_set"}"             = var.proxy_port
    "${var.proxy_username != "" ? "PROXY_USERNAME" : "proxy_username_is_not_set"}" = var.proxy_username
    "${var.proxy_password != "" ? "PROXY_PASSWORD" : "proxy_password_is_not_set"}" = var.proxy_password
    MAX_FILE_SIZE                                                                  = var.max_file_size
  }
}

resource "cloudfoundry_network_policy" "clamav_routing" {
  policy {
    source_app      = data.cloudfoundry_app.app.id
    destination_app = cloudfoundry_app.clamav_api.id
    port            = "61443"
  }
}
