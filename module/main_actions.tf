##################################################
# Nutanix Guest Tools -- installation (v2, provider 2.4.2)
##################################################

# Declarative, steady-state NGT installation. The VM reference is resolved in
# locals.tf against module-created VMs first, falling back to a literal ext_id.
# Guest credentials come from the separate sensitive var.ngt_installation_credentials
# (never from YAML). Note the provider attribute `capablities` is spelled as-is
# by the provider; the module input spells it `capabilities`.
resource "nutanix_ngt_installation_v2" "ngt_installation" {
  for_each = var.ngt_installations

  ext_id      = local.ngt_installation_vm_ext_id[each.key]
  is_enabled  = each.value.is_enabled
  capablities = length(each.value.capabilities) > 0 ? each.value.capabilities : null

  dynamic "credential" {
    for_each = contains(keys(var.ngt_installation_credentials), each.key) ? [var.ngt_installation_credentials[each.key]] : []
    content {
      username = credential.value.username
      password = credential.value.password
    }
  }

  dynamic "reboot_preference" {
    for_each = each.value.reboot_preference != null ? [each.value.reboot_preference] : []
    content {
      schedule_type = reboot_preference.value.schedule_type

      dynamic "schedule" {
        for_each = reboot_preference.value.start_time != null ? [reboot_preference.value.start_time] : []
        content {
          start_time = schedule.value
        }
      }
    }
  }
}

##################################################
# VM Clone (v2) -- imperative, one-shot
##################################################

# Clones a source VM once. The source VM reference is resolved in locals.tf. The
# cloned VM is a provider-side artifact surfaced via output.vm_actions (its new
# ext_id); it is NOT modelled as a nutanix_virtual_machine_v2 resource here. See
# the var.vm_actions description for the one-shot / re-trigger / destroy caveats.
resource "nutanix_vm_clone_v2" "clone" {
  for_each = var.vm_actions.clones

  vm_ext_id            = local.clone_vm_ext_id[each.key]
  name                 = each.value.name
  num_sockets          = each.value.num_sockets
  num_cores_per_socket = each.value.num_cores_per_socket
  num_threads_per_core = each.value.num_threads_per_core
  memory_size_bytes = each.value.memory_size_mib != null ? (
    each.value.memory_size_mib * 1024 * 1024
  ) : null
}

##################################################
# VM Guest Customization Update (v2) -- imperative, one-shot
##################################################

# Updates guest customization applied on the VM's next boot. The VM reference is
# resolved in locals.tf. cloud_init and sysprep mirror the VM resource's
# guest_customization shape. One-shot: see the var.vm_actions caveats.
resource "nutanix_vm_gc_update_v2" "gc_update" {
  for_each = var.vm_actions.gc_updates

  ext_id = local.gc_update_vm_ext_id[each.key]

  config {
    dynamic "cloud_init" {
      for_each = (each.value.cloud_init_user_data != null || each.value.cloud_init_metadata != null) ? [1] : []
      content {
        datasource_type = each.value.cloud_init_datasource_type
        metadata        = each.value.cloud_init_metadata

        dynamic "cloud_init_script" {
          for_each = each.value.cloud_init_user_data != null ? [1] : []
          content {
            user_data {
              value = each.value.cloud_init_user_data
            }
          }
        }
      }
    }

    dynamic "sysprep" {
      for_each = (each.value.sysprep_install_type != null || each.value.sysprep_unattend_xml != null) ? [1] : []
      content {
        install_type = each.value.sysprep_install_type

        dynamic "sysprep_script" {
          for_each = each.value.sysprep_unattend_xml != null ? [1] : []
          content {
            unattend_xml {
              value = each.value.sysprep_unattend_xml
            }
          }
        }
      }
    }
  }
}

##################################################
# VM NIC -- assign IP (v2) -- imperative, one-shot
##################################################

# Assigns an IP to a NIC (ext_id is the NIC's runtime-assigned ext_id). The VM
# reference is resolved in locals.tf. One-shot: see the var.vm_actions caveats.
resource "nutanix_vm_network_device_assign_ip_v2" "nic_ip_assignment" {
  for_each = var.vm_actions.nic_ip_assignments

  vm_ext_id = local.nic_ip_assignment_vm_ext_id[each.key]
  ext_id    = each.value.nic_ext_id

  dynamic "ip_address" {
    for_each = each.value.ip_address != null ? [each.value] : []
    content {
      value         = ip_address.value.ip_address
      prefix_length = ip_address.value.prefix_length
    }
  }
}

##################################################
# VM NIC -- migrate between subnets (v2) -- imperative, one-shot
##################################################

# Migrates a NIC to another subnet (ext_id is the NIC ext_id). migrate_type is
# ASSIGN_IP or RELEASE_IP. The VM reference is resolved in locals.tf. One-shot:
# see the var.vm_actions caveats.
resource "nutanix_vm_network_device_migrate_v2" "nic_migration" {
  for_each = var.vm_actions.nic_migrations

  vm_ext_id    = local.nic_migration_vm_ext_id[each.key]
  ext_id       = each.value.nic_ext_id
  migrate_type = each.value.migrate_type

  dynamic "subnet" {
    for_each = each.value.subnet_ext_id != null ? [each.value.subnet_ext_id] : []
    content {
      ext_id = subnet.value
    }
  }

  dynamic "ip_address" {
    for_each = each.value.ip_address != null ? [each.value] : []
    content {
      value         = ip_address.value.ip_address
      prefix_length = ip_address.value.prefix_length
    }
  }
}

##################################################
# VM CD-ROM -- insert/eject ISO (v2) -- imperative, one-shot
##################################################

# Inserts or ejects an ISO on a CD-ROM. ext_id is the CD-ROM device ext_id
# (REQUIRED -- always set cdrom_ext_id explicitly for eject to avoid the 2.4.2
# null-ext_id eject bug; the fix only exists in the banned 2.4.3-beta). vm_ext_id
# is resolved in locals.tf. For insert, backing_info references the ISO image.
# One-shot: see the var.vm_actions caveats.
resource "nutanix_vm_cdrom_insert_eject_v2" "cdrom_operation" {
  for_each = var.vm_actions.cdrom_operations

  ext_id    = each.value.cdrom_ext_id
  vm_ext_id = local.cdrom_operation_vm_ext_id[each.key]
  action    = each.value.action

  dynamic "backing_info" {
    for_each = each.value.image_ext_id != null ? [each.value] : []
    content {
      disk_size_bytes = backing_info.value.disk_size_bytes

      data_source {
        reference {
          image_reference {
            image_ext_id = backing_info.value.image_ext_id
          }
        }
      }
    }
  }
}

##################################################
# VM Shutdown/Reboot action (v2) -- imperative, one-shot
##################################################

# Powers a VM down or reboots it. action is shutdown|guest_shutdown|reboot|
# guest_reboot; the guest_power_state_transition_config script-exec flags apply
# only to the guest_* variants (via NGT). The VM reference is resolved in
# locals.tf. One-shot: destroy does NOT restart the VM (see var.vm_actions).
resource "nutanix_vm_shutdown_action_v2" "shutdown" {
  for_each = var.vm_actions.shutdowns

  ext_id = local.shutdown_vm_ext_id[each.key]
  action = each.value.action

  dynamic "guest_power_state_transition_config" {
    for_each = (each.value.should_enable_script_exec != null || each.value.should_fail_on_script_failure != null) ? [each.value] : []
    content {
      should_enable_script_exec     = guest_power_state_transition_config.value.should_enable_script_exec
      should_fail_on_script_failure = guest_power_state_transition_config.value.should_fail_on_script_failure
    }
  }
}

##################################################
# VM Revert to recovery point (v2) -- imperative, one-shot
##################################################

# Reverts a VM to a recovery point. The VM reference is resolved in locals.tf;
# recovery_point_ext_id is a VM recovery point external ID (look one up via the
# nutanix_recovery_points_v2 data source). One-shot: destroy does NOT un-revert
# the VM (see the var.vm_actions caveats).
resource "nutanix_vm_revert_v2" "revert" {
  for_each = var.vm_actions.reverts

  ext_id                   = local.revert_vm_ext_id[each.key]
  vm_recovery_point_ext_id = each.value.recovery_point_ext_id
}

##################################################
# NGT -- insert ISO (v2) -- imperative, one-shot
##################################################

# Inserts (or ejects) the NGT ISO on a VM. action is insert|eject; capabilities
# is a subset of SELF_SERVICE_RESTORE, VSS_SNAPSHOT (provider attribute spelled
# `capablities`); is_config_only updates existing config instead of installing.
# The VM reference is resolved in locals.tf. One-shot: see var.vm_actions.
resource "nutanix_ngt_insert_iso_v2" "ngt_iso_insert" {
  for_each = var.vm_actions.ngt_iso_inserts

  ext_id         = local.ngt_iso_insert_vm_ext_id[each.key]
  action         = each.value.action
  is_config_only = each.value.is_config_only
  capablities    = length(each.value.capabilities) > 0 ? each.value.capabilities : null
}

##################################################
# NGT -- upgrade (v2) -- imperative, one-shot
##################################################

# Upgrades Nutanix Guest Tools on a VM. reboot_preference.schedule_type is
# IMMEDIATE|LATER|SKIP (start_time used with LATER). The VM reference is resolved
# in locals.tf. One-shot: see the var.vm_actions caveats.
resource "nutanix_ngt_upgrade_v2" "ngt_upgrade" {
  for_each = var.vm_actions.ngt_upgrades

  ext_id = local.ngt_upgrade_vm_ext_id[each.key]

  dynamic "reboot_preference" {
    for_each = each.value.reboot_preference != null ? [each.value.reboot_preference] : []
    content {
      schedule_type = reboot_preference.value.schedule_type

      dynamic "schedule" {
        for_each = reboot_preference.value.start_time != null ? [reboot_preference.value.start_time] : []
        content {
          start_time = schedule.value
        }
      }
    }
  }
}
