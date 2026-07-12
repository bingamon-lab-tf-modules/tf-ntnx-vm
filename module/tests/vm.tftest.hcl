##################################################
# Unit Tests: Compute (images + virtual_machine_v2)
##################################################

#########################
# Mock Provider
#########################

mock_provider "nutanix" {

  # Existing clusters lookup (evaluated only when enable_data_lookups = true).
  mock_data "nutanix_clusters_v2" {
    defaults = {
      cluster_entities = [
        {
          ext_id                   = "00000000-0000-0000-0000-000000000000"
          name                     = "mock-cluster"
          backup_eligibility_score = 0
          categories               = []
          cluster_profile_ext_id   = ""
          container_name           = ""
          expand                   = ""
          inefficient_vm_count     = 0
          links                    = []
          network                  = []
          nodes                    = []
          tenant_id                = ""
          upgrade_status           = ""
          vm_count                 = 0
          config = [
            {
              authorized_public_key_list       = []
              build_info                       = []
              cluster_arch                     = ""
              cluster_function                 = ["AOS"]
              cluster_software_map             = []
              encryption_in_transit_status     = ""
              encryption_option                = []
              encryption_scope                 = []
              fault_tolerance_state            = []
              hypervisor_types                 = ["AHV"]
              incarnation_id                   = 0
              is_available                     = true
              is_lts                           = false
              is_password_remote_login_enabled = false
              is_remote_support_enabled        = false
              operation_mode                   = ""
              pulse_status                     = []
              redundancy_factor                = 2
              timezone                         = ""
            }
          ]
        }
      ]
    }
  }

  # Existing images lookup (empty inventory).
  mock_data "nutanix_images_v2" {
    defaults = {
      images = []
    }
  }

  # Existing virtual machines lookup (empty inventory).
  mock_data "nutanix_virtual_machines_v2" {
    defaults = {
      vms = []
    }
  }
}

#########################
# Tests
#########################

# Empty configuration plans zero compute resources.
run "empty_config" {
  command = plan

  variables {
    images           = {}
    virtual_machines = {}
  }

  assert {
    condition     = output.compute_summary.total_images == 0
    error_message = "Expected 0 images for empty config"
  }

  assert {
    condition     = output.compute_summary.total_virtual_machines == 0
    error_message = "Expected 0 VMs for empty config"
  }

  assert {
    condition     = length(output.image_ids) == 0
    error_message = "Expected no image IDs for empty config"
  }

  assert {
    condition     = length(output.virtual_machine_ids) == 0
    error_message = "Expected no VM IDs for empty config"
  }
}

# One image plus one Linux VM (cloud-init, 2 disks, 1 NIC) is surfaced.
run "image_and_linux_vm" {
  command = plan

  variables {
    images = {
      ubuntu = {
        name = "ubuntu-22.04-cloudimg"
        type = "DISK_IMAGE"
        source = {
          url_source = {
            url = "https://example.com/jammy.img"
          }
        }
      }
    }
    virtual_machines = {
      linux = {
        name            = "app-linux-01"
        cluster_ext_id  = "00000000-0000-0000-0000-000000000001"
        memory_size_mib = 4096
        boot_type       = "UEFI"
        disks = [
          { bus_type = "SCSI", index = 0, image_ext_id = "00000000-0000-0000-0000-000000000003" },
          { bus_type = "SCSI", index = 1, disk_size_mib = 51200 },
        ]
        nics = [
          { subnet_ext_id = "00000000-0000-0000-0000-000000000002" },
        ]
        guest_customization_cloud_init_user_data = "I2Nsb3VkLWNvbmZpZwo="
      }
    }
  }

  assert {
    condition     = length(output.image_ids) == 1
    error_message = "Expected 1 image ID"
  }

  assert {
    condition     = contains(keys(output.image_ids), "ubuntu")
    error_message = "Expected image key 'ubuntu' in image_ids"
  }

  assert {
    condition     = length(output.virtual_machine_ids) == 1
    error_message = "Expected 1 VM ID"
  }

  assert {
    condition     = contains(keys(output.virtual_machine_ids), "linux")
    error_message = "Expected VM key 'linux' in virtual_machine_ids"
  }

  assert {
    condition     = output.compute_summary.total_images == 1
    error_message = "Expected total_images == 1"
  }

  assert {
    condition     = output.compute_summary.disk_images == 1
    error_message = "Expected disk_images == 1"
  }

  assert {
    condition     = output.compute_summary.cloud_init_vms == 1
    error_message = "Expected cloud_init_vms == 1"
  }

  assert {
    condition     = output.compute_summary.powered_on_vms == 1
    error_message = "Expected powered_on_vms == 1 (default power_state ON)"
  }
}

# A Linux (cloud-init, powered on) and a Windows (sysprep, powered off) VM
# together exercise the power-state and guest-customization summary splits.
run "linux_and_windows_vms" {
  command = plan

  variables {
    virtual_machines = {
      linux = {
        name                                     = "app-linux-01"
        cluster_ext_id                           = "00000000-0000-0000-0000-000000000001"
        power_state                              = "ON"
        nics                                     = [{ subnet_ext_id = "00000000-0000-0000-0000-000000000002" }]
        guest_customization_cloud_init_user_data = "I2Nsb3VkLWNvbmZpZwo="
      }
      windows = {
        name           = "app-win-01"
        cluster_ext_id = "00000000-0000-0000-0000-000000000001"
        power_state    = "OFF"
        boot_type      = "SECURE_BOOT"
        machine_type   = "Q35"
        nics           = [{ subnet_ext_id = "00000000-0000-0000-0000-000000000002" }]
        guest_customization_sysprep = {
          install_type = "PREPARED"
          unattend_xml = "<unattend />"
        }
      }
    }
  }

  assert {
    condition     = output.compute_summary.total_virtual_machines == 2
    error_message = "Expected 2 VMs"
  }

  assert {
    condition     = output.compute_summary.powered_on_vms == 1
    error_message = "Expected 1 powered-on VM"
  }

  assert {
    condition     = output.compute_summary.powered_off_vms == 1
    error_message = "Expected 1 powered-off VM"
  }

  assert {
    condition     = output.compute_summary.cloud_init_vms == 1
    error_message = "Expected 1 cloud-init VM (Linux only)"
  }
}

# With enable_data_lookups = true the compute inventory lookups plan cleanly
# against the mock data and surface a populated cluster name -> ext_id map.
run "data_lookups_enabled" {
  command = plan

  variables {
    enable_data_lookups = true
    images = {
      ubuntu = {
        name = "ubuntu-22.04-cloudimg"
        type = "DISK_IMAGE"
        source = {
          url_source = {
            url = "https://example.com/jammy.img"
          }
        }
      }
    }
    virtual_machines = {
      linux = {
        name           = "app-linux-01"
        cluster_ext_id = "00000000-0000-0000-0000-000000000001"
        nics           = [{ subnet_ext_id = "00000000-0000-0000-0000-000000000002" }]
      }
    }
  }

  assert {
    condition     = output.existing_cluster_ext_ids["mock-cluster"] == "00000000-0000-0000-0000-000000000000"
    error_message = "Expected the mock cluster to resolve to its ext_id"
  }

  assert {
    condition     = length(output.existing_image_ext_ids) == 0
    error_message = "Expected an empty existing-image map from the empty mock"
  }

  assert {
    condition     = output.compute_summary.total_virtual_machines == 1
    error_message = "Expected 1 VM with data lookups enabled"
  }
}

# An invalid power_state must fail variable validation.
run "invalid_power_state_fails" {
  command = plan

  variables {
    virtual_machines = {
      bad = {
        name           = "bad"
        cluster_ext_id = "00000000-0000-0000-0000-000000000001"
        power_state    = "PAUSED"
        nics           = [{ subnet_ext_id = "00000000-0000-0000-0000-000000000002" }]
      }
    }
  }

  expect_failures = [var.virtual_machines]
}

# An invalid image type must fail variable validation.
run "invalid_image_type_fails" {
  command = plan

  variables {
    images = {
      bad = {
        name = "bad"
        type = "RAW_IMAGE"
      }
    }
  }

  expect_failures = [var.images]
}

# An invalid boot_type must fail variable validation.
run "invalid_boot_type_fails" {
  command = plan

  variables {
    virtual_machines = {
      bad = {
        name           = "bad"
        cluster_ext_id = "00000000-0000-0000-0000-000000000001"
        boot_type      = "BIOS"
        nics           = [{ subnet_ext_id = "00000000-0000-0000-0000-000000000002" }]
      }
    }
  }

  expect_failures = [var.virtual_machines]
}
