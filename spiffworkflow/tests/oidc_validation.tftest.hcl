# Test OIDC validation logic

run "test_internal_oidc_default" {
  command = plan

  variables {
    cf_org_name                       = "test-org"
    cf_space_name                     = "test-space"
    name                              = "test-spiff"
    backend_database_service_instance = "test-db"
  }

  # Should succeed with default internal OIDC configuration (plan completes without error)
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

  # Should succeed with complete external OIDC configuration (plan completes without error)
}

run "test_external_oidc_incomplete_missing_secret" {
  command = plan

  variables {
    cf_org_name                       = "test-org"
    cf_space_name                     = "test-space"
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
    cf_org_name                       = "test-org"
    cf_space_name                     = "test-space"
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
