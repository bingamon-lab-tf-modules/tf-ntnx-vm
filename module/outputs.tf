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
  }
}
