terraform {
  required_providers {
    cloudfoundry = {
      source  = "cloudfoundry/cloudfoundry"
      version = "1.1.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~>3.0.2"
    }
  }
}

module "spiff" {
  source = "./.."
  cf_org_name = "gsa-tts-oros-fac"
  cf_space_name = "sandbox-workflow"
  frontend_imageref = "ghcr.io/sartography/spiffworkflow-frontend:main-latest"
  backend_imageref = "ghcr.io/sartography/spiffworkflow-backend:main-latest"
}
