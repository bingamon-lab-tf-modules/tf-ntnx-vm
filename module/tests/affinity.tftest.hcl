##################################################
# Unit Tests: VM Placement Policies (v2 affinity)
##################################################

#########################
# Mock Provider
#########################

mock_provider "nutanix" {}

#########################
# Tests
#########################

# Empty configuration plans zero placement policies.
run "affinity_empty_config" {
  command = plan

  variables {
    vm_host_affinity_policies = {}
    vm_anti_affinity_policies = {}
  }

  assert {
    condition     = output.compute_summary.total_vm_host_affinity_policies == 0
    error_message = "Expected 0 host-affinity policies for empty config"
  }

  assert {
    condition     = output.compute_summary.total_vm_anti_affinity_policies == 0
    error_message = "Expected 0 anti-affinity policies for empty config"
  }

  assert {
    condition     = length(output.vm_host_affinity_policy_ids) == 0
    error_message = "Expected no host-affinity policy IDs for empty config"
  }

  assert {
    condition     = length(output.vm_anti_affinity_policy_ids) == 0
    error_message = "Expected no anti-affinity policy IDs for empty config"
  }
}

# A valid host-affinity policy is accepted and surfaced.
run "host_affinity_valid" {
  command = plan

  variables {
    vm_host_affinity_policies = {
      licensed_db_hosts = {
        name            = "licensed-db-hosts"
        description     = "Pin Oracle VMs to licensed hosts"
        vm_categories   = ["11111111-1111-1111-1111-111111111111"]
        host_categories = ["22222222-2222-2222-2222-222222222222"]
      }
    }
  }

  assert {
    condition     = output.compute_summary.total_vm_host_affinity_policies == 1
    error_message = "Expected 1 host-affinity policy"
  }

  assert {
    condition     = output.vm_host_affinity_policies["licensed_db_hosts"].name == "licensed-db-hosts"
    error_message = "Expected host-affinity policy name licensed-db-hosts"
  }

  assert {
    condition     = contains(output.vm_host_affinity_policies["licensed_db_hosts"].host_categories, "22222222-2222-2222-2222-222222222222")
    error_message = "Expected host category to be wired onto the host-affinity policy"
  }
}

# A valid anti-affinity policy is accepted and surfaced.
run "anti_affinity_valid" {
  command = plan

  variables {
    vm_anti_affinity_policies = {
      db_ha_pair = {
        name          = "db-ha-pair"
        description   = "Keep NDB HA nodes on different hosts"
        vm_categories = ["33333333-3333-3333-3333-333333333333"]
      }
    }
  }

  assert {
    condition     = output.compute_summary.total_vm_anti_affinity_policies == 1
    error_message = "Expected 1 anti-affinity policy"
  }

  assert {
    condition     = output.vm_anti_affinity_policies["db_ha_pair"].name == "db-ha-pair"
    error_message = "Expected anti-affinity policy name db-ha-pair"
  }

  assert {
    condition     = contains(output.vm_anti_affinity_policies["db_ha_pair"].categories, "33333333-3333-3333-3333-333333333333")
    error_message = "Expected VM category to be wired onto the anti-affinity policy"
  }
}

# Host-affinity entry without host categories must fail validation.
run "host_affinity_without_host_categories_fails" {
  command = plan

  variables {
    vm_host_affinity_policies = {
      bad = {
        name            = "bad"
        vm_categories   = ["11111111-1111-1111-1111-111111111111"]
        host_categories = []
      }
    }
  }

  expect_failures = [var.vm_host_affinity_policies]
}

# Anti-affinity entry without VM categories must fail validation.
run "anti_affinity_without_vm_categories_fails" {
  command = plan

  variables {
    vm_anti_affinity_policies = {
      bad = {
        name          = "bad"
        vm_categories = []
      }
    }
  }

  expect_failures = [var.vm_anti_affinity_policies]
}
