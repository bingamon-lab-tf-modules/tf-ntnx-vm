##################################################
# Unit Tests: NGT installation + VM day-2 actions (v2)
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

  # Per-VM NGT configuration lookup (only read when enable_data_lookups = true).
  mock_data "nutanix_ngt_configuration_v2" {
    defaults = {
      is_enabled   = true
      is_installed = true
      is_reachable = true
      version      = "4.0"
    }
  }
}

#########################
# A minimal, valid VM the actions can target (satisfies the NIC + memory checks).
#########################

variables {
  virtual_machines = {
    web = {
      name            = "web-01"
      cluster_ext_id  = "00000000-0000-0000-0000-000000000001"
      memory_size_mib = 2048
      nics            = [{ subnet_ext_id = "00000000-0000-0000-0000-000000000002" }]
    }
  }
}

#########################
# Tests
#########################

# Empty NGT + actions config plans zero action resources.
run "actions_empty_config" {
  command = plan

  variables {
    ngt_installations = {}
    vm_actions        = {}
  }

  assert {
    condition     = output.compute_summary.total_ngt_installations == 0
    error_message = "Expected 0 NGT installations for empty config"
  }

  assert {
    condition = alltrue([
      output.compute_summary.total_vm_clones == 0,
      output.compute_summary.total_vm_gc_updates == 0,
      output.compute_summary.total_vm_nic_ip_assignments == 0,
      output.compute_summary.total_vm_nic_migrations == 0,
      output.compute_summary.total_vm_cdrom_operations == 0,
      output.compute_summary.total_vm_shutdowns == 0,
      output.compute_summary.total_vm_reverts == 0,
      output.compute_summary.total_ngt_iso_inserts == 0,
      output.compute_summary.total_ngt_upgrades == 0,
    ])
    error_message = "Expected all vm_actions sub-maps to plan zero resources when empty"
  }

  assert {
    condition     = length(output.vm_clone_ids) == 0
    error_message = "Expected no clone IDs for empty config"
  }

  assert {
    condition     = length(output.ngt_installations) == 0
    error_message = "Expected no NGT installations for empty config"
  }
}

# A clone that references a virtual_machines map key resolves in-plan against the
# module-created VM (the clone's source vm_ext_id matches the VM's own ext_id).
run "clone_resolves_module_vm" {
  command = plan

  variables {
    vm_actions = {
      clones = {
        web_copy = {
          vm              = "web" # key of virtual_machines map
          name            = "web-01-clone"
          memory_size_mib = 4096
        }
      }
    }
  }

  assert {
    condition     = output.compute_summary.total_vm_clones == 1
    error_message = "Expected 1 clone"
  }

  assert {
    condition     = contains(keys(output.vm_clone_ids), "web_copy")
    error_message = "Expected clone key 'web_copy' in vm_clone_ids"
  }

  # The clone's resolved source ext_id is the module-created VM's ext_id --
  # proving in-plan resolution against virtual_machines map keys.
  assert {
    condition     = output.vm_actions.clones["web_copy"].source_vm_ext_id == output.virtual_machine_ids["web"]
    error_message = "Expected the clone to resolve to the module-created VM's ext_id"
  }

  assert {
    condition     = output.vm_actions.clones["web_copy"].name == "web-01-clone"
    error_message = "Expected clone name override to pass through"
  }
}

# A clone that references a literal VM ext_id (not a map key) passes it through.
run "clone_resolves_external_ext_id" {
  command = plan

  variables {
    vm_actions = {
      clones = {
        external = {
          vm = "99999999-9999-9999-9999-999999999999"
        }
      }
    }
  }

  assert {
    condition     = output.vm_actions.clones["external"].source_vm_ext_id == "99999999-9999-9999-9999-999999999999"
    error_message = "Expected the literal VM ext_id to pass through unresolved"
  }
}

# A declarative NGT installation with a sensitive credential plans cleanly and is
# surfaced, resolving its VM against the virtual_machines map.
run "ngt_installation_planned" {
  command = plan

  variables {
    ngt_installations = {
      web = {
        vm           = "web"
        capabilities = ["VSS_SNAPSHOT"]
        is_enabled   = true
      }
    }
    ngt_installation_credentials = {
      web = {
        username = "svc-ngt"
        password = "s3cr3t"
      }
    }
  }

  assert {
    condition     = output.compute_summary.total_ngt_installations == 1
    error_message = "Expected 1 NGT installation"
  }

  assert {
    condition     = contains(keys(output.ngt_installations), "web")
    error_message = "Expected NGT installation key 'web'"
  }
}

# With enable_data_lookups = true the per-VM NGT configuration lookup plans
# against the mock and surfaces one entry per installation.
run "ngt_configuration_lookup_enabled" {
  command = plan

  variables {
    enable_data_lookups = true
    ngt_installations = {
      existing = {
        vm = "88888888-8888-8888-8888-888888888888"
      }
    }
  }

  assert {
    condition     = length(output.ngt_configurations) == 1
    error_message = "Expected one NGT configuration entry from the mock lookup"
  }
}

# A full spread of one action per sub-map plans cleanly and is counted.
run "all_action_types_planned" {
  command = plan

  variables {
    vm_actions = {
      gc_updates = {
        g1 = {
          vm                   = "web"
          cloud_init_user_data = "#cloud-config\nhostname: web\n"
        }
      }
      nic_ip_assignments = {
        a1 = {
          vm         = "web"
          nic_ext_id = "11111111-1111-1111-1111-111111111111"
          ip_address = "10.0.0.10"
        }
      }
      nic_migrations = {
        m1 = {
          vm            = "web"
          nic_ext_id    = "11111111-1111-1111-1111-111111111111"
          migrate_type  = "ASSIGN_IP"
          subnet_ext_id = "00000000-0000-0000-0000-000000000002"
          ip_address    = "10.0.1.10"
        }
      }
      cdrom_operations = {
        eject1 = {
          vm           = "web"
          cdrom_ext_id = "22222222-2222-2222-2222-222222222222"
          action       = "eject"
        }
      }
      shutdowns = {
        s1 = {
          vm                        = "web"
          action                    = "guest_shutdown"
          should_enable_script_exec = true
        }
      }
      reverts = {
        r1 = {
          vm                    = "web"
          recovery_point_ext_id = "33333333-3333-3333-3333-333333333333"
        }
      }
      ngt_iso_inserts = {
        i1 = {
          vm     = "web"
          action = "insert"
        }
      }
      ngt_upgrades = {
        u1 = {
          vm = "web"
          reboot_preference = {
            schedule_type = "IMMEDIATE"
          }
        }
      }
    }
  }

  assert {
    condition = alltrue([
      output.compute_summary.total_vm_gc_updates == 1,
      output.compute_summary.total_vm_nic_ip_assignments == 1,
      output.compute_summary.total_vm_nic_migrations == 1,
      output.compute_summary.total_vm_cdrom_operations == 1,
      output.compute_summary.total_vm_shutdowns == 1,
      output.compute_summary.total_vm_reverts == 1,
      output.compute_summary.total_ngt_iso_inserts == 1,
      output.compute_summary.total_ngt_upgrades == 1,
    ])
    error_message = "Expected exactly one resource planned per action sub-map"
  }

  assert {
    condition     = output.vm_actions.nic_migrations["m1"].migrate_type == "ASSIGN_IP"
    error_message = "Expected migrate_type to pass through"
  }

  assert {
    condition     = output.vm_actions.reverts["r1"].recovery_point_ext_id == "33333333-3333-3333-3333-333333333333"
    error_message = "Expected revert recovery point to pass through"
  }
}

# An unknown shutdown action must fail variable validation.
run "invalid_shutdown_action_fails" {
  command = plan

  variables {
    vm_actions = {
      shutdowns = {
        bad = {
          vm     = "web"
          action = "halt"
        }
      }
    }
  }

  expect_failures = [var.vm_actions]
}

# A NIC migration with an unknown migrate_type must fail variable validation.
run "invalid_migrate_type_fails" {
  command = plan

  variables {
    vm_actions = {
      nic_migrations = {
        bad = {
          vm           = "web"
          nic_ext_id   = "11111111-1111-1111-1111-111111111111"
          migrate_type = "MOVE_IP"
        }
      }
    }
  }

  expect_failures = [var.vm_actions]
}

# A CD-ROM operation without an explicit cdrom_ext_id must fail validation
# (mandatory in 2.4.2 and the eject null-ext_id workaround).
run "invalid_cdrom_without_ext_id_fails" {
  command = plan

  variables {
    vm_actions = {
      cdrom_operations = {
        bad = {
          vm           = "web"
          cdrom_ext_id = ""
          action       = "eject"
        }
      }
    }
  }

  expect_failures = [var.vm_actions]
}

# A revert without a recovery point must fail variable validation.
run "invalid_revert_without_recovery_point_fails" {
  command = plan

  variables {
    vm_actions = {
      reverts = {
        bad = {
          vm                    = "web"
          recovery_point_ext_id = ""
        }
      }
    }
  }

  expect_failures = [var.vm_actions]
}

# An NGT installation with an unknown capability must fail variable validation.
run "invalid_ngt_capability_fails" {
  command = plan

  variables {
    ngt_installations = {
      bad = {
        vm           = "web"
        capabilities = ["NOT_A_CAPABILITY"]
      }
    }
  }

  expect_failures = [var.ngt_installations]
}
