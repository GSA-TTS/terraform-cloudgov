# Test OIDC validation logic

mock_provider "cloudfoundry" {
  mock_data "cloudfoundry_org" {
    defaults = {
      id = "591a8a56-3093-43e7-a21e-1b1b4dbd1c3a"
    }
  }
  mock_data "cloudfoundry_domain" {
    defaults = {
      id = "ad9f5303-b5b0-40cb-b21a-a7276efae4b1"
    }
  }
  mock_data "cloudfoundry_space" {
    defaults = {
      id = "31a2c21d-ba50-437b-9d40-8c2d741af9e7"
    }
  }
  mock_resource "cloudfoundry_app" {
    defaults = {
      id = "c5b9e4d2-1a8f-46c3-a957-4f3d8b79e61c"
    }
  }
}

mock_provider "docker" {
  mock_resource "docker_registry_image" {
    defaults = {
      name          = "ghcr.io/gsa-tts/terraform-cloudgov/spiffarena:latest"
      sha256_digest = "sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    }
  }
}

run "test_internal_oidc_default" {
  command = plan

  variables {
    cf_org_name = "test-org"
    space = {
      id   = "00000000-0000-0000-0000-000000000000"
      name = "test-space"
    }
    name                              = "test-spiff"
    backend_database_service_instance = "test-db"
  }

  # Should succeed with default internal OIDC configuration (plan completes without error)
}

run "test_external_oidc_complete" {
  command = plan

  variables {
    cf_org_name = "test-org"
    space = {
      id   = "00000000-0000-0000-0000-000000000000"
      name = "test-space"
    }
    name                              = "test-spiff"
    backend_database_service_instance = "test-db"
    backend_oidc_client_id            = "test-client-id"
    backend_oidc_client_secret        = "test-client-secret"
    backend_oidc_server_url           = "https://login.fr.cloud.gov"
  }

  # Should succeed with complete external OIDC configuration (plan completes without error)
}

run "test_external_oidc_incomplete_missing_secret" {
  command = plan

  variables {
    cf_org_name = "test-org"
    space = {
      id   = "00000000-0000-0000-0000-000000000000"
      name = "test-space"
    }
    name                              = "test-spiff"
    backend_database_service_instance = "test-db"
    backend_oidc_client_id            = "test-client-id"
    backend_oidc_server_url           = "https://login.fr.cloud.gov"
    # Missing client_secret
  }

  expect_failures = [
    var.backend_oidc_client_secret
  ]
}

run "test_external_oidc_incomplete_missing_url" {
  command = plan

  variables {
    cf_org_name = "test-org"
    space = {
      id   = "00000000-0000-0000-0000-000000000000"
      name = "test-space"
    }
    name                              = "test-spiff"
    backend_database_service_instance = "test-db"
    backend_oidc_client_id            = "test-client-id"
    backend_oidc_client_secret        = "test-client-secret"
    # Missing server_url
  }

  expect_failures = [
    var.backend_oidc_server_url
  ]
}
