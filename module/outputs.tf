##################################################
# Image Outputs
##################################################

output "images" {
  description = "Map of created images with their details."
  value = {
    for k, v in nutanix_images_v2.image : k => {
      ext_id     = v.ext_id
      name       = v.name
      type       = v.type
      size_bytes = v.size_bytes
    }
  }
}

output "image_ids" {
  description = "Map of image keys to their external IDs."
  value       = { for k, v in nutanix_images_v2.image : k => v.ext_id }
}

##################################################
# Virtual Machine Outputs
##################################################

output "virtual_machines" {
  description = "Map of created VMs with their details."
  value = {
    for k, v in nutanix_virtual_machine_v2.vm : k => {
      id                   = v.ext_id
      ext_id               = v.ext_id
      name                 = v.name
      cluster_ext_id       = length(v.cluster) > 0 ? v.cluster[0].ext_id : null
      num_sockets          = v.num_sockets
      num_cores_per_socket = v.num_cores_per_socket
      memory_size_bytes    = v.memory_size_bytes
      power_state          = v.power_state
    }
  }
}

output "virtual_machine_ids" {
  description = "Map of VM keys to their external IDs."
  value       = { for k, v in nutanix_virtual_machine_v2.vm : k => v.ext_id }
}

output "virtual_machine_nic_list" {
  description = "Map of VM keys to their NIC list (includes backing and network info with assigned IPs)."
  value = {
    for k, v in nutanix_virtual_machine_v2.vm : k => v.nics
  }
}

output "virtual_machine_nic_ips" {
  description = "Map of virtual machine keys to their learned NIC IP addresses."
  value = {
    for k, v in nutanix_virtual_machine_v2.vm : k => flatten([
      for nic in v.nics : [
        for ni in nic.network_info : [
          for info in ni.ipv4_info : [
            for addr in info.learned_ip_addresses : addr.value
          ]
        ]
      ]
    ])
  }
}

##################################################
# VM Placement Policy Outputs
##################################################

output "vm_host_affinity_policies" {
  description = "Map of created VM host-affinity policies with their details."
  value = {
    for k, v in nutanix_vm_host_affinity_policy_v2.host_affinity_policy : k => {
      ext_id          = v.ext_id
      name            = v.name
      vm_categories   = v.vm_categories
      host_categories = v.host_categories
    }
  }
}

output "vm_host_affinity_policy_ids" {
  description = "Map of VM host-affinity policy keys to their external IDs."
  value       = { for k, v in nutanix_vm_host_affinity_policy_v2.host_affinity_policy : k => v.ext_id }
}

output "vm_anti_affinity_policies" {
  description = "Map of created VM anti-affinity policies with their details."
  value = {
    for k, v in nutanix_vm_anti_affinity_policy_v2.anti_affinity_policy : k => {
      ext_id     = v.ext_id
      name       = v.name
      categories = v.categories
    }
  }
}

output "vm_anti_affinity_policy_ids" {
  description = "Map of VM anti-affinity policy keys to their external IDs."
  value       = { for k, v in nutanix_vm_anti_affinity_policy_v2.anti_affinity_policy : k => v.ext_id }
}

##################################################
# Template Outputs
##################################################

output "templates" {
  description = "Map of created VM templates with their details."
  value = {
    for k, v in nutanix_template_v2.template : k => {
      ext_id = v.ext_id
      name   = v.template_name
    }
  }
}

output "template_ids" {
  description = "Map of template keys to their external IDs."
  value       = { for k, v in nutanix_template_v2.template : k => v.ext_id }
}

output "template_deployments" {
  description = "Map of template deployments with their resolved template ext_id, target cluster and VM count. NOTE: the deployed VMs are provider-side artifacts of the one-shot deploy action and are not tracked as VM resources here."
  value = {
    for k, v in nutanix_deploy_templates_v2.template_deployment : k => {
      id              = v.id
      template_ext_id = v.ext_id
      cluster_ext_id  = v.cluster_reference
      number_of_vms   = v.number_of_vms
    }
  }
}

##################################################
# OVA Outputs
##################################################

output "ovas" {
  description = "Map of created OVA appliance images with their details."
  value = {
    for k, v in nutanix_ova_v2.ova : k => {
      ext_id      = v.ext_id
      name        = v.name
      disk_format = v.disk_format
      size_bytes  = v.size_bytes
    }
  }
}

output "ova_ids" {
  description = "Map of OVA keys to their external IDs."
  value       = { for k, v in nutanix_ova_v2.ova : k => v.ext_id }
}

output "ova_downloads" {
  description = "Map of OVA export/download actions with their resolved OVA ext_id and the exported file path. NOTE: exports are one-shot actions; re-exporting requires a new map key."
  value = {
    for k, v in nutanix_ova_download_v2.ova_download : k => {
      ova_ext_id    = v.ova_ext_id
      ova_file_path = v.ova_file_path
    }
  }
}

output "ova_deployments" {
  description = "Map of OVA VM deployments with their resolved source OVA ext_id and target cluster. NOTE: the deployed VMs are provider-side artifacts of the deploy action and are not tracked as VM resources here."
  value = {
    for k, v in nutanix_ova_vm_deploy_v2.ova_deployment : k => {
      id             = v.id
      ova_ext_id     = v.ext_id
      cluster_ext_id = v.cluster_location_ext_id
    }
  }
}

##################################################
# NGT Installation Outputs
##################################################

output "ngt_installations" {
  description = "Map of managed NGT installations with the target VM ext_id and the NGT state reported by the provider."
  value = {
    for k, v in nutanix_ngt_installation_v2.ngt_installation : k => {
      vm_ext_id    = v.ext_id
      is_enabled   = v.is_enabled
      is_installed = v.is_installed
      is_reachable = v.is_reachable
      version      = v.version
      capabilities = v.capablities
    }
  }
}

##################################################
# VM Day-2 Action Outputs
##################################################

# Convenience map: clone key -> the NEW cloned VM's ext_id (a provider-side
# artifact; the cloned VM is NOT tracked as a virtual_machine resource here).
output "vm_clone_ids" {
  description = "Map of vm_actions.clones keys to the external IDs of the newly cloned VMs (provider-side artifacts, not tracked as VM resources)."
  value       = { for k, v in nutanix_vm_clone_v2.clone : k => v.ext_id }
}

# Grouped result metadata for every action sub-map. NOTE: these are one-shot
# action results stored in state; see the var.vm_actions description for the
# lifecycle caveats (no reconciliation, re-trigger via a new key, destroy does
# not undo the action).
output "vm_actions" {
  description = "Grouped result metadata for the imperative VM day-2 actions (one-shot; see var.vm_actions caveats). clones surface the new VM ext_id; reverts surface the revert status."
  value = {
    clones = {
      for k, v in nutanix_vm_clone_v2.clone : k => {
        source_vm_ext_id = v.vm_ext_id
        new_vm_ext_id    = v.ext_id
        name             = v.name
      }
    }
    gc_updates = {
      for k, v in nutanix_vm_gc_update_v2.gc_update : k => { vm_ext_id = v.ext_id }
    }
    nic_ip_assignments = {
      for k, v in nutanix_vm_network_device_assign_ip_v2.nic_ip_assignment : k => {
        vm_ext_id  = v.vm_ext_id
        nic_ext_id = v.ext_id
      }
    }
    nic_migrations = {
      for k, v in nutanix_vm_network_device_migrate_v2.nic_migration : k => {
        vm_ext_id    = v.vm_ext_id
        nic_ext_id   = v.ext_id
        migrate_type = v.migrate_type
      }
    }
    cdrom_operations = {
      for k, v in nutanix_vm_cdrom_insert_eject_v2.cdrom_operation : k => {
        vm_ext_id    = v.vm_ext_id
        cdrom_ext_id = v.ext_id
        action       = v.action
      }
    }
    shutdowns = {
      for k, v in nutanix_vm_shutdown_action_v2.shutdown : k => {
        vm_ext_id = v.ext_id
        action    = v.action
      }
    }
    reverts = {
      for k, v in nutanix_vm_revert_v2.revert : k => {
        vm_ext_id             = v.ext_id
        recovery_point_ext_id = v.vm_recovery_point_ext_id
        status                = v.status
      }
    }
    ngt_iso_inserts = {
      for k, v in nutanix_ngt_insert_iso_v2.ngt_iso_insert : k => {
        vm_ext_id = v.ext_id
        action    = v.action
      }
    }
    ngt_upgrades = {
      for k, v in nutanix_ngt_upgrade_v2.ngt_upgrade : k => { vm_ext_id = v.ext_id }
    }
  }
}

##################################################
# Data Lookup Outputs (populated when enable_data_lookups = true)
##################################################

output "existing_cluster_ext_ids" {
  description = "Map of existing cluster names to their external IDs (populated when enable_data_lookups = true)."
  value       = local.existing_cluster_ext_ids
}

output "existing_image_ext_ids" {
  description = "Map of existing image names to their external IDs (populated when enable_data_lookups = true)."
  value       = local.existing_image_ext_ids
}

output "existing_vm_ext_ids" {
  description = "Map of existing virtual machine names to their external IDs (populated when enable_data_lookups = true)."
  value       = local.existing_vm_ext_ids
}

output "existing_template_ext_ids" {
  description = "Map of existing template names to their external IDs (populated when enable_data_lookups = true)."
  value       = local.existing_template_ext_ids
}

output "existing_ova_ext_ids" {
  description = "Map of existing OVA names to their external IDs (populated when enable_data_lookups = true)."
  value       = local.existing_ova_ext_ids
}

output "ngt_configurations" {
  description = "Map of ngt_installations keys to the NGT configuration reported by Prism Central for each installation's VM (populated when enable_data_lookups = true)."
  value = {
    for k, v in data.nutanix_ngt_configuration_v2.ngt_configuration : k => {
      is_enabled   = v.is_enabled
      is_installed = v.is_installed
      is_reachable = v.is_reachable
      version      = v.version
      capabilities = v.capablities
    }
  }
}

##################################################
# Summary
##################################################

output "compute_summary" {
  description = "Summary of compute resources managed by this module."
  value = {
    total_images                    = length(var.images)
    total_virtual_machines          = length(var.virtual_machines)
    disk_images                     = length(local.disk_images)
    iso_images                      = length(local.iso_images)
    powered_on_vms                  = length(local.powered_on_vms)
    powered_off_vms                 = length(local.powered_off_vms)
    gpu_vms                         = length(local.gpu_vms)
    cloud_init_vms                  = length(local.cloud_init_vms)
    total_vm_host_affinity_policies = length(var.vm_host_affinity_policies)
    total_vm_anti_affinity_policies = length(var.vm_anti_affinity_policies)
    total_templates                 = length(var.templates)
    total_template_deployments      = length(var.template_deployments)
    total_template_guest_os_actions = length(var.template_guest_os_actions)
    total_ovas                      = length(var.ovas)
    total_ova_downloads             = length(var.ova_downloads)
    total_ova_deployments           = length(var.ova_deployments)
    total_ngt_installations         = length(var.ngt_installations)
    total_vm_clones                 = length(var.vm_actions.clones)
    total_vm_gc_updates             = length(var.vm_actions.gc_updates)
    total_vm_nic_ip_assignments     = length(var.vm_actions.nic_ip_assignments)
    total_vm_nic_migrations         = length(var.vm_actions.nic_migrations)
    total_vm_cdrom_operations       = length(var.vm_actions.cdrom_operations)
    total_vm_shutdowns              = length(var.vm_actions.shutdowns)
    total_vm_reverts                = length(var.vm_actions.reverts)
    total_ngt_iso_inserts           = length(var.vm_actions.ngt_iso_inserts)
    total_ngt_upgrades              = length(var.vm_actions.ngt_upgrades)
  }
}

##################################################
# Aggregate Output (spec §7.6 contract)
##################################################

output "outputs" {
  description = "Aggregate of all module outputs (spec §7.6 contract, consumed by the landing zone as module.<x>.outputs)."
  value = {
    images = {
      for k, v in nutanix_images_v2.image : k => {
        ext_id     = v.ext_id
        name       = v.name
        type       = v.type
        size_bytes = v.size_bytes
      }
    }
    image_ids = { for k, v in nutanix_images_v2.image : k => v.ext_id }
    virtual_machines = {
      for k, v in nutanix_virtual_machine_v2.vm : k => {
        id                   = v.ext_id
        ext_id               = v.ext_id
        name                 = v.name
        cluster_ext_id       = length(v.cluster) > 0 ? v.cluster[0].ext_id : null
        num_sockets          = v.num_sockets
        num_cores_per_socket = v.num_cores_per_socket
        memory_size_bytes    = v.memory_size_bytes
        power_state          = v.power_state
      }
    }
    virtual_machine_ids = { for k, v in nutanix_virtual_machine_v2.vm : k => v.ext_id }
    virtual_machine_nic_list = {
      for k, v in nutanix_virtual_machine_v2.vm : k => v.nics
    }
    virtual_machine_nic_ips = {
      for k, v in nutanix_virtual_machine_v2.vm : k => flatten([
        for nic in v.nics : [
          for ni in nic.network_info : [
            for info in ni.ipv4_info : [
              for addr in info.learned_ip_addresses : addr.value
            ]
          ]
        ]
      ])
    }
    vm_host_affinity_policies = {
      for k, v in nutanix_vm_host_affinity_policy_v2.host_affinity_policy : k => {
        ext_id          = v.ext_id
        name            = v.name
        vm_categories   = v.vm_categories
        host_categories = v.host_categories
      }
    }
    vm_host_affinity_policy_ids = { for k, v in nutanix_vm_host_affinity_policy_v2.host_affinity_policy : k => v.ext_id }
    vm_anti_affinity_policies = {
      for k, v in nutanix_vm_anti_affinity_policy_v2.anti_affinity_policy : k => {
        ext_id     = v.ext_id
        name       = v.name
        categories = v.categories
      }
    }
    vm_anti_affinity_policy_ids = { for k, v in nutanix_vm_anti_affinity_policy_v2.anti_affinity_policy : k => v.ext_id }
    templates = {
      for k, v in nutanix_template_v2.template : k => {
        ext_id = v.ext_id
        name   = v.template_name
      }
    }
    template_ids = { for k, v in nutanix_template_v2.template : k => v.ext_id }
    template_deployments = {
      for k, v in nutanix_deploy_templates_v2.template_deployment : k => {
        id              = v.id
        template_ext_id = v.ext_id
        cluster_ext_id  = v.cluster_reference
        number_of_vms   = v.number_of_vms
      }
    }
    ovas = {
      for k, v in nutanix_ova_v2.ova : k => {
        ext_id      = v.ext_id
        name        = v.name
        disk_format = v.disk_format
        size_bytes  = v.size_bytes
      }
    }
    ova_ids = { for k, v in nutanix_ova_v2.ova : k => v.ext_id }
    ova_downloads = {
      for k, v in nutanix_ova_download_v2.ova_download : k => {
        ova_ext_id    = v.ova_ext_id
        ova_file_path = v.ova_file_path
      }
    }
    ova_deployments = {
      for k, v in nutanix_ova_vm_deploy_v2.ova_deployment : k => {
        id             = v.id
        ova_ext_id     = v.ext_id
        cluster_ext_id = v.cluster_location_ext_id
      }
    }
    ngt_installations = {
      for k, v in nutanix_ngt_installation_v2.ngt_installation : k => {
        vm_ext_id    = v.ext_id
        is_enabled   = v.is_enabled
        is_installed = v.is_installed
        is_reachable = v.is_reachable
        version      = v.version
        capabilities = v.capablities
      }
    }
    vm_clone_ids = { for k, v in nutanix_vm_clone_v2.clone : k => v.ext_id }
    vm_actions = {
      clones = {
        for k, v in nutanix_vm_clone_v2.clone : k => {
          source_vm_ext_id = v.vm_ext_id
          new_vm_ext_id    = v.ext_id
          name             = v.name
        }
      }
      gc_updates = {
        for k, v in nutanix_vm_gc_update_v2.gc_update : k => { vm_ext_id = v.ext_id }
      }
      nic_ip_assignments = {
        for k, v in nutanix_vm_network_device_assign_ip_v2.nic_ip_assignment : k => {
          vm_ext_id  = v.vm_ext_id
          nic_ext_id = v.ext_id
        }
      }
      nic_migrations = {
        for k, v in nutanix_vm_network_device_migrate_v2.nic_migration : k => {
          vm_ext_id    = v.vm_ext_id
          nic_ext_id   = v.ext_id
          migrate_type = v.migrate_type
        }
      }
      cdrom_operations = {
        for k, v in nutanix_vm_cdrom_insert_eject_v2.cdrom_operation : k => {
          vm_ext_id    = v.vm_ext_id
          cdrom_ext_id = v.ext_id
          action       = v.action
        }
      }
      shutdowns = {
        for k, v in nutanix_vm_shutdown_action_v2.shutdown : k => {
          vm_ext_id = v.ext_id
          action    = v.action
        }
      }
      reverts = {
        for k, v in nutanix_vm_revert_v2.revert : k => {
          vm_ext_id             = v.ext_id
          recovery_point_ext_id = v.vm_recovery_point_ext_id
          status                = v.status
        }
      }
      ngt_iso_inserts = {
        for k, v in nutanix_ngt_insert_iso_v2.ngt_iso_insert : k => {
          vm_ext_id = v.ext_id
          action    = v.action
        }
      }
      ngt_upgrades = {
        for k, v in nutanix_ngt_upgrade_v2.ngt_upgrade : k => { vm_ext_id = v.ext_id }
      }
    }
    existing_cluster_ext_ids  = local.existing_cluster_ext_ids
    existing_image_ext_ids    = local.existing_image_ext_ids
    existing_vm_ext_ids       = local.existing_vm_ext_ids
    existing_template_ext_ids = local.existing_template_ext_ids
    existing_ova_ext_ids      = local.existing_ova_ext_ids
    ngt_configurations = {
      for k, v in data.nutanix_ngt_configuration_v2.ngt_configuration : k => {
        is_enabled   = v.is_enabled
        is_installed = v.is_installed
        is_reachable = v.is_reachable
        version      = v.version
        capabilities = v.capablities
      }
    }
    compute_summary = {
      total_images                    = length(var.images)
      total_virtual_machines          = length(var.virtual_machines)
      disk_images                     = length(local.disk_images)
      iso_images                      = length(local.iso_images)
      powered_on_vms                  = length(local.powered_on_vms)
      powered_off_vms                 = length(local.powered_off_vms)
      gpu_vms                         = length(local.gpu_vms)
      cloud_init_vms                  = length(local.cloud_init_vms)
      total_vm_host_affinity_policies = length(var.vm_host_affinity_policies)
      total_vm_anti_affinity_policies = length(var.vm_anti_affinity_policies)
      total_templates                 = length(var.templates)
      total_template_deployments      = length(var.template_deployments)
      total_template_guest_os_actions = length(var.template_guest_os_actions)
      total_ovas                      = length(var.ovas)
      total_ova_downloads             = length(var.ova_downloads)
      total_ova_deployments           = length(var.ova_deployments)
      total_ngt_installations         = length(var.ngt_installations)
      total_vm_clones                 = length(var.vm_actions.clones)
      total_vm_gc_updates             = length(var.vm_actions.gc_updates)
      total_vm_nic_ip_assignments     = length(var.vm_actions.nic_ip_assignments)
      total_vm_nic_migrations         = length(var.vm_actions.nic_migrations)
      total_vm_cdrom_operations       = length(var.vm_actions.cdrom_operations)
      total_vm_shutdowns              = length(var.vm_actions.shutdowns)
      total_vm_reverts                = length(var.vm_actions.reverts)
      total_ngt_iso_inserts           = length(var.vm_actions.ngt_iso_inserts)
      total_ngt_upgrades              = length(var.vm_actions.ngt_upgrades)
    }
  }
}
