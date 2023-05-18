terraform {
  required_providers {
    test = {
      source = "terraform.io/builtin/test"
    }
    cloudfoundry = {
      source = "cloudfoundry-community/cloudfoundry"
    }
  }
}

# CF_USER and CF_PASSWORD environment variables
# must be set and have access to local.testing_org/local.testing_space
provider "cloudfoundry" {
  api_url = "https://api.fr.cloud.gov"
}
