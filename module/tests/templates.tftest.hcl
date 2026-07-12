##################################################
# Unit Tests: VM Templates (v2)
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
}

#########################
# Tests
#########################

# Empty configuration plans zero template resources.
run "templates_empty_config" {
  command = plan

  variables {
    templates                 = {}
    template_deployments      = {}
    template_guest_os_actions = {}
  }

  assert {
    condition     = output.compute_summary.total_templates == 0
    error_message = "Expected 0 templates for empty config"
  }

  assert {
    condition     = output.compute_summary.total_template_deployments == 0
    error_message = "Expected 0 template deployments for empty config"
  }

  assert {
    condition     = output.compute_summary.total_template_guest_os_actions == 0
    error_message = "Expected 0 guest-OS actions for empty config"
  }

  assert {
    condition     = length(output.template_ids) == 0
    error_message = "Expected no template IDs for empty config"
  }

  assert {
    condition     = length(output.template_deployments) == 0
    error_message = "Expected no template deployments for empty config"
  }
}

# A single versioned template captured from a source VM is created and surfaced.
run "template_created" {
  command = plan

  variables {
    templates = {
      web_base = {
        name             = "web-base"
        description      = "Golden web server image"
        source_vm_ext_id = "00000000-0000-0000-0000-000000000010"
        version_name     = "v1"
      }
    }
  }

  assert {
    condition     = output.compute_summary.total_templates == 1
    error_message = "Expected total_templates == 1"
  }

  assert {
    condition     = contains(keys(output.template_ids), "web_base")
    error_message = "Expected template key 'web_base' in template_ids"
  }

  assert {
    condition     = output.templates["web_base"].name == "web-base"
    error_message = "Expected template name 'web-base'"
  }
}

# A deployment that references a templates map key resolves in-plan against the
# module-created template (the deployment's resolved template ext_id matches the
# template's own ext_id output).
run "deployment_resolves_module_template" {
  command = plan

  variables {
    templates = {
      web_base = {
        name             = "web-base"
        source_vm_ext_id = "00000000-0000-0000-0000-000000000010"
      }
    }
    template_deployments = {
      web_pool_1 = {
        template      = "web_base" # key of templates map
        cluster       = "00000000-0000-0000-0000-000000000001"
        number_of_vms = 2
      }
    }
  }

  assert {
    condition     = output.compute_summary.total_template_deployments == 1
    error_message = "Expected 1 template deployment"
  }

  assert {
    condition     = contains(keys(output.template_deployments), "web_pool_1")
    error_message = "Expected deployment key 'web_pool_1'"
  }

  assert {
    condition     = output.template_deployments["web_pool_1"].number_of_vms == 2
    error_message = "Expected number_of_vms == 2 on the deployment"
  }

  assert {
    condition     = output.template_deployments["web_pool_1"].cluster_ext_id == "00000000-0000-0000-0000-000000000001"
    error_message = "Expected the literal cluster ext_id to pass through"
  }

  # The deployment's resolved template ext_id is the module-created template's
  # ext_id -- proving in-plan resolution against templates map keys.
  assert {
    condition     = output.template_deployments["web_pool_1"].template_ext_id == output.template_ids["web_base"]
    error_message = "Expected the deployment to resolve to the module-created template's ext_id"
  }
}

# A deployment that references a literal template ext_id (not a map key) passes
# it through unchanged.
run "deployment_resolves_external_ext_id" {
  command = plan

  variables {
    templates = {}
    template_deployments = {
      external_pool = {
        template      = "99999999-9999-9999-9999-999999999999"
        cluster       = "00000000-0000-0000-0000-000000000001"
        number_of_vms = 1
      }
    }
  }

  assert {
    condition     = output.template_deployments["external_pool"].template_ext_id == "99999999-9999-9999-9999-999999999999"
    error_message = "Expected the literal template ext_id to pass through unresolved"
  }
}

# A guest-OS 'initiate' action referencing a templates map key plans cleanly.
run "guest_os_action_valid" {
  command = plan

  variables {
    templates = {
      web_base = {
        name             = "web-base"
        source_vm_ext_id = "00000000-0000-0000-0000-000000000010"
      }
    }
    template_guest_os_actions = {
      patch_web = {
        template   = "web_base"
        action     = "initiate"
        version_id = "00000000-0000-0000-0000-000000000020"
      }
    }
  }

  assert {
    condition     = output.compute_summary.total_template_guest_os_actions == 1
    error_message = "Expected 1 guest-OS action"
  }
}

# With enable_data_lookups = true the gated templates lookup plans cleanly
# against the empty mock and surfaces an empty name -> ext_id map.
run "templates_data_lookup_enabled" {
  command = plan

  variables {
    enable_data_lookups = true
    templates           = {}
  }

  assert {
    condition     = length(output.existing_template_ext_ids) == 0
    error_message = "Expected an empty existing-template map from the empty mock"
  }
}

# number_of_vms below 1 must fail variable validation.
run "invalid_number_of_vms_fails" {
  command = plan

  variables {
    template_deployments = {
      bad = {
        template      = "99999999-9999-9999-9999-999999999999"
        cluster       = "00000000-0000-0000-0000-000000000001"
        number_of_vms = 0
      }
    }
  }

  expect_failures = [var.template_deployments]
}

# An unknown guest-OS action must fail variable validation.
run "invalid_guest_os_action_fails" {
  command = plan

  variables {
    template_guest_os_actions = {
      bad = {
        template = "99999999-9999-9999-9999-999999999999"
        action   = "reboot"
      }
    }
  }

  expect_failures = [var.template_guest_os_actions]
}

# A template without a source_vm_ext_id (empty string) must fail validation.
run "invalid_template_source_fails" {
  command = plan

  variables {
    templates = {
      bad = {
        name             = "bad"
        source_vm_ext_id = ""
      }
    }
  }

  expect_failures = [var.templates]
}
