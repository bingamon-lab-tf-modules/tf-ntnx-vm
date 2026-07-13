##################################################
# Unit Tests: OVA family (v2)
##################################################

#########################
# Mock Provider
#########################

mock_provider "nutanix" {

  # Gated inventory lookups (only read when enable_data_lookups = true). Empty
  # inventories keep the name -> ext_id maps empty and deterministic.
  mock_data "nutanix_clusters_v2" {
    defaults = {
      cluster_entities = []
    }
  }

  mock_data "nutanix_images_v2" {
    defaults = {
      images = []
    }
  }

  mock_data "nutanix_virtual_machines_v2" {
    defaults = {
      vms = []
    }
  }

  mock_data "nutanix_templates_v2" {
    defaults = {
      templates = []
    }
  }

  mock_data "nutanix_ovas_v2" {
    defaults = {
      ovas = []
    }
  }
}

#########################
# Tests
#########################

# Empty configuration plans zero OVA resources.
run "ovas_empty_config" {
  command = plan

  variables {
    ovas            = {}
    ova_downloads   = {}
    ova_deployments = {}
  }

  assert {
    condition     = output.compute_summary.total_ovas == 0
    error_message = "Expected 0 OVAs for empty config"
  }

  assert {
    condition     = output.compute_summary.total_ova_downloads == 0
    error_message = "Expected 0 OVA downloads for empty config"
  }

  assert {
    condition     = output.compute_summary.total_ova_deployments == 0
    error_message = "Expected 0 OVA deployments for empty config"
  }

  assert {
    condition     = length(output.ova_ids) == 0
    error_message = "Expected no OVA IDs for empty config"
  }

  assert {
    condition     = length(output.ova_deployments) == 0
    error_message = "Expected no OVA deployments for empty config"
  }
}

# A single OVA imported from a URL is created and surfaced.
run "ova_created" {
  command = plan

  variables {
    ovas = {
      appliance = {
        name        = "vendor-appliance"
        disk_format = "QCOW2"
        source = {
          url_source = {
            url = "https://example.com/appliance.ova"
          }
        }
      }
    }
  }

  assert {
    condition     = output.compute_summary.total_ovas == 1
    error_message = "Expected total_ovas == 1"
  }

  assert {
    condition     = contains(keys(output.ova_ids), "appliance")
    error_message = "Expected OVA key 'appliance' in ova_ids"
  }

  assert {
    condition     = output.ovas["appliance"].name == "vendor-appliance"
    error_message = "Expected OVA name 'vendor-appliance'"
  }
}

# A deployment that references an ovas map key resolves in-plan against the
# module-created OVA (the deployment's resolved OVA ext_id matches the OVA's own
# ext_id output).
run "deployment_resolves_module_ova" {
  command = plan

  variables {
    ovas = {
      appliance = {
        name = "vendor-appliance"
        source = {
          url_source = {
            url = "https://example.com/appliance.ova"
          }
        }
      }
    }
    ova_deployments = {
      appliance_vm = {
        ova     = "appliance" # key of ovas map
        cluster = "00000000-0000-0000-0000-000000000001"
        nics    = [{ subnet_ext_id = "00000000-0000-0000-0000-000000000002" }]
      }
    }
  }

  assert {
    condition     = output.compute_summary.total_ova_deployments == 1
    error_message = "Expected 1 OVA deployment"
  }

  assert {
    condition     = contains(keys(output.ova_deployments), "appliance_vm")
    error_message = "Expected deployment key 'appliance_vm'"
  }

  assert {
    condition     = output.ova_deployments["appliance_vm"].cluster_ext_id == "00000000-0000-0000-0000-000000000001"
    error_message = "Expected the literal cluster ext_id to pass through"
  }

  # The deployment's resolved OVA ext_id is the module-created OVA's ext_id --
  # proving in-plan resolution against ovas map keys.
  assert {
    condition     = output.ova_deployments["appliance_vm"].ova_ext_id == output.ova_ids["appliance"]
    error_message = "Expected the deployment to resolve to the module-created OVA's ext_id"
  }
}

# A deployment that references a literal OVA ext_id (not a map key) passes it
# through unchanged.
run "deployment_resolves_external_ext_id" {
  command = plan

  variables {
    ovas = {}
    ova_deployments = {
      external_vm = {
        ova     = "99999999-9999-9999-9999-999999999999"
        cluster = "00000000-0000-0000-0000-000000000001"
        nics    = [{ subnet_ext_id = "00000000-0000-0000-0000-000000000002" }]
      }
    }
  }

  assert {
    condition     = output.ova_deployments["external_vm"].ova_ext_id == "99999999-9999-9999-9999-999999999999"
    error_message = "Expected the literal OVA ext_id to pass through unresolved"
  }
}

# A download that references an ovas map key resolves against the module-created
# OVA's ext_id.
run "download_resolves_module_ova" {
  command = plan

  variables {
    ovas = {
      appliance = {
        name = "vendor-appliance"
        source = {
          url_source = {
            url = "https://example.com/appliance.ova"
          }
        }
      }
    }
    ova_downloads = {
      export_appliance = {
        ova = "appliance"
      }
    }
  }

  assert {
    condition     = output.compute_summary.total_ova_downloads == 1
    error_message = "Expected 1 OVA download"
  }

  assert {
    condition     = output.ova_downloads["export_appliance"].ova_ext_id == output.ova_ids["appliance"]
    error_message = "Expected the download to resolve to the module-created OVA's ext_id"
  }
}

# With enable_data_lookups = true the gated OVAs lookup plans cleanly against the
# empty mock and surfaces an empty name -> ext_id map.
run "ovas_data_lookup_enabled" {
  command = plan

  variables {
    enable_data_lookups = true
    ovas                = {}
  }

  assert {
    condition     = length(output.existing_ova_ext_ids) == 0
    error_message = "Expected an empty existing-OVA map from the empty mock"
  }
}

# An OVA with no source variant set must fail variable validation (exactly one
# source variant is required).
run "invalid_ova_no_source_fails" {
  command = plan

  variables {
    ovas = {
      bad = {
        name   = "bad"
        source = {}
      }
    }
  }

  expect_failures = [var.ovas]
}

# An OVA with two source variants set must fail variable validation.
run "invalid_ova_multiple_sources_fails" {
  command = plan

  variables {
    ovas = {
      bad = {
        name = "bad"
        source = {
          url_source         = { url = "https://example.com/a.ova" }
          object_lite_source = { key = "bucket/a.ova" }
        }
      }
    }
  }

  expect_failures = [var.ovas]
}

# A deployment with no NIC must fail variable validation (the provider requires
# at least one NIC on the deployed VM).
run "invalid_deployment_no_nic_fails" {
  command = plan

  variables {
    ova_deployments = {
      bad = {
        ova     = "99999999-9999-9999-9999-999999999999"
        cluster = "00000000-0000-0000-0000-000000000001"
        nics    = []
      }
    }
  }

  expect_failures = [var.ova_deployments]
}

# An invalid deployment power_state must fail variable validation.
run "invalid_deployment_power_state_fails" {
  command = plan

  variables {
    ova_deployments = {
      bad = {
        ova         = "99999999-9999-9999-9999-999999999999"
        cluster     = "00000000-0000-0000-0000-000000000001"
        power_state = "PAUSED"
        nics        = [{ subnet_ext_id = "00000000-0000-0000-0000-000000000002" }]
      }
    }
  }

  expect_failures = [var.ova_deployments]
}
