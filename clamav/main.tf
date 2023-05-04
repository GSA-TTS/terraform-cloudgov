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
  docker_image = var.clamav_image
  routes {
    route = cloudfoundry_route.clamav_route.id
  }
  environment = {
    # Only set "https_proxy" if a value was supplied.
    # Otherwise, ensure that a harmless envvar gets set instead.
    # This avoids confusing the app with an https_proxy that's set to ""!
    "${var.https_proxy != "" ? "https_proxy" : "https_proxy_is_not_set"}"   = var.https_proxy
    MAX_FILE_SIZE = var.max_file_size
  }
}

resource "cloudfoundry_network_policy" "clamav_routing" {
  policy {
    source_app      = data.cloudfoundry_app.app.id
    # We use the "id_bg" attribute here to ensure the network policy is updated
    # during blue-green deploys of the app. Docs:
    # https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/resources/app#update-resource-using-blue-green-app-id
    # Note that this will probably not be necessary once the app resource
    # supports CAPI v3; v3 has a native "--strategy rolling" flag for deploys
    # which doesn't change the app GUID. That makes the "venerable" blue-green
    # method obsolete.
    destination_app = cloudfoundry_app.clamav_api.id_bg
    port            = "61443"
  }
}
