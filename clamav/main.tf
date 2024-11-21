data "cloudfoundry_domain" "internal" {
  name = "apps.internal"
}

data "cloudfoundry_app" "app" {
  name       = var.app_name
  org_name   = var.cf_org_name
  space_name = var.cf_space.name
}

resource "cloudfoundry_route" "clamav_route" {
  space  = var.cf_space.id
  domain = data.cloudfoundry_domain.internal.id
  host   = var.name
}

resource "cloudfoundry_app" "clamav_api" {
  name       = var.name
  space_name = var.cf_space.name
  org_name   = var.cf_org_name

  memory                          = var.clamav_memory
  disk_quota                      = "2048M"
  health_check_invocation_timeout = 600
  strategy                        = "rolling"
  instances                       = var.instances
  docker_image                    = var.clamav_image
  routes = [
    {
      route = cloudfoundry_route.clamav_route.url
    }
  ]
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
  provider = cloudfoundry-community
  policy {
    source_app      = data.cloudfoundry_app.app.id
    destination_app = cloudfoundry_app.clamav_api.id
    port            = "61443"
  }
}
