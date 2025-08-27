# Test OIDC validation logic

run "test_internal_oidc_default" {
  command = plan

  variables {
    cf_org_name                       = "test-org"
    cf_space_name                     = "test-space"
    name                              = "test-spiff"
    backend_database_service_instance = "test-db"
  }

  # Should succeed with default internal OIDC configuration
  assert {
    condition     = local.oidc_configured == false
    error_message = "OIDC should not be configured when no external OIDC variables are provided"
  }
}

run "test_external_oidc_complete" {
  command = plan

  variables {
    cf_org_name                       = "test-org"
    cf_space_name                     = "test-space"
    name                              = "test-spiff"
    backend_database_service_instance = "test-db"
    backend_oidc_client_id            = "test-client-id"
    backend_oidc_client_secret        = "test-client-secret"
    backend_oidc_server_url           = "https://login.fr.cloud.gov"
  }

  # Should succeed with complete external OIDC configuration
  assert {
    condition     = local.oidc_configured == true
    error_message = "OIDC should be configured when external OIDC variables are provided"
  }

  assert {
    condition     = local.oidc_valid == true
    error_message = "OIDC validation should pass when all required fields are provided"
  }
}

run "test_external_oidc_incomplete" {
  command = plan

  variables {
    cf_org_name                       = "test-org"
    cf_space_name                     = "test-space"
    name                              = "test-spiff"
    backend_database_service_instance = "test-db"
    backend_oidc_client_id            = "test-client-id"
    # Missing client_secret and server_url
  }

  expect_failures = [
    cloudfoundry_app.backend
  ]
}
