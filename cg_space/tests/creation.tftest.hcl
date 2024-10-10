mock_provider "cloudfoundry" {
  override_data {
    target = data.cloudfoundry_user.managers["user.manager@gsa.gov"]
    values = {
      id = "1e5143a4-aa47-483c-8352-557988d5cc7a"
    }
  }
  override_data {
    target = data.cloudfoundry_user.deployers["user.manager@gsa.gov"]
    values = {
      id = "1e5143a4-aa47-483c-8352-557988d5cc7a"
    }
  }
  override_data {
    target = data.cloudfoundry_user.developers["user.developer@gsa.gov"]
    values = {
      id = "2c945842-13ee-4383-84ad-34ecbcde5ce6"
    }
  }
}

variables {
  cf_org_name   = "gsa-tts-devtools-prototyping"
  cf_space_name = "terraform-cloudgov-ci-tests-egress"
}

run "test_space_creation" {
  assert {
    condition     = cloudfoundry_space.space.id == output.space_id
    error_message = "Space ID output must match the new space"
  }

  assert {
    condition     = cloudfoundry_space.space.name == var.cf_space_name
    error_message = "Space name should match the cf_space_name variable"
  }

  assert {
    condition     = cloudfoundry_space.space.name == output.space_name
    error_message = "Space name output must match the new space"
  }
}

run "test_manager_only" {
  variables {
    managers = ["user.manager@gsa.gov"]
  }

  assert {
    condition     = cloudfoundry_space_users.space_permissions.managers == toset(["1e5143a4-aa47-483c-8352-557988d5cc7a"])
    error_message = "Should be able to set Space Managers"
  }

  assert {
    condition     = length(cloudfoundry_space_users.space_permissions.developers) == 0
    error_message = "Should not have set any Space Developers"
  }
}

run "test_individual_permissions" {
  variables {
    managers   = ["user.manager@gsa.gov"]
    developers = ["user.developer@gsa.gov"]
  }

  assert {
    condition     = cloudfoundry_space_users.space_permissions.managers == toset(["1e5143a4-aa47-483c-8352-557988d5cc7a"])
    error_message = "Should be able to set Space Managers"
  }

  assert {
    condition     = cloudfoundry_space_users.space_permissions.developers == toset(["2c945842-13ee-4383-84ad-34ecbcde5ce6"])
    error_message = "Should be able to set Space Developers"
  }
}

run "test_deployer_permissions" {
  variables {
    developers = ["user.developer@gsa.gov"]
    deployers  = ["user.manager@gsa.gov"]
  }

  assert {
    condition     = cloudfoundry_space_users.space_permissions.managers == toset(["1e5143a4-aa47-483c-8352-557988d5cc7a"])
    error_message = "Should be able to set Space Managers via var.deployers"
  }

  assert {
    condition     = cloudfoundry_space_users.space_permissions.developers == toset(["2c945842-13ee-4383-84ad-34ecbcde5ce6", "1e5143a4-aa47-483c-8352-557988d5cc7a"])
    error_message = "Should set Space Developers to var.developers + var.deployers"
  }
}
