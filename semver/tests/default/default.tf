terraform {
  required_providers {
    test = {
      # See https://developer.hashicorp.com/terraform/language/modules/testing-experiment#writing-tests-for-a-module
      source = "terraform.io/builtin/test"
    }
    http = {
      source = "hashicorp/http"
    }
  }
}

# Fixture constraints
locals {
  module_versions = {
    # This test will break after we tag something higher than 1.0.0; fix and
    # expand these tests then!
    # https://github.com/npm/node-semver#tilde-ranges-123-12-1
    greaterthan = "~0", 
  }

  latest_tag = trimprefix(jsondecode(data.http.latest_version.response_body).tag_name, "v")
}

# Divine the most recent versions matching fixture
module "version" {
  for_each           = local.module_versions
  source             = "../.."
  version_constraint = each.value
}

data "http" "latest_version" {
  url = "https://api.github.com/repos/18f/terraform-cloudgov/releases/latest"

  request_headers = {
    accept = "vnd.github+json"
  }
}

resource "test_assertions" "greater-than-is-latest" {
  component = "outputs"
  equal "target_version" {
    description = "greater than should always be the latest in the repo"
    got  = module.version["greaterthan"].target_version
    want = local.latest_tag
  }
}

