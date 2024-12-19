provider "cloudfoundry" {
  api_url = "https://api.fr.cloud.gov"
  # cf_user and cf_password are passed in via CF_USER and CF_PASSWORD env vars
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

  assert {
    condition     = cloudfoundry_space.space == output.space
    error_message = "Entire space is output from the module"
  }
}

run "test_manager_only" {
  variables {
    managers = ["ryan.ahearn@gsa.gov"]
  }

  assert {
    condition     = keys(cloudfoundry_space_role.managers) == ["ryan.ahearn@gsa.gov"]
    error_message = "Should be able to set Space Managers"
  }

  assert {
    condition     = length(cloudfoundry_space_role.developers) == 0
    error_message = "Should not have set any Space Developers"
  }
}

run "test_individual_permissions" {
  variables {
    managers   = ["paul.hirsch@gsa.gov"]
    developers = ["ryan.ahearn@gsa.gov"]
  }

  assert {
    condition     = keys(cloudfoundry_space_role.managers) == ["paul.hirsch@gsa.gov"]
    error_message = "Should be able to set Space Managers"
  }

  assert {
    condition     = keys(cloudfoundry_space_role.developers) == ["ryan.ahearn@gsa.gov"]
    error_message = "Should be able to set Space Developers"
  }
}

run "test_deployer_permissions" {
  variables {
    developers = ["paul.hirsch@gsa.gov"]
    deployers  = ["ryan.ahearn@gsa.gov"]
  }

  assert {
    condition     = keys(cloudfoundry_space_role.managers) == ["ryan.ahearn@gsa.gov"]
    error_message = "Should be able to set Space Managers via var.deployers"
  }

  assert {
    condition     = keys(cloudfoundry_space_role.developers) == ["paul.hirsch@gsa.gov", "ryan.ahearn@gsa.gov"]
    error_message = "Should set Space Developers to var.developers + var.deployers"
  }

  assert {
    condition = output.developer_role_ids == {
      "paul.hirsch@gsa.gov" = cloudfoundry_space_role.developers["paul.hirsch@gsa.gov"].id,
      "ryan.ahearn@gsa.gov" = cloudfoundry_space_role.developers["ryan.ahearn@gsa.gov"].id
    }
    error_message = "Output includes the developer role ids"
  }

  assert {
    condition = output.manager_role_ids == {
      "ryan.ahearn@gsa.gov" = cloudfoundry_space_role.managers["ryan.ahearn@gsa.gov"].id
    }
    error_message = "Output includes the manager role ids"
  }
}
