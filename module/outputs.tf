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
    for k, v in nutanix_virtual_machine.vm : k => {
      id                   = v.id
      name                 = v.name
      cluster_uuid         = v.cluster_uuid
      cluster_name         = v.cluster_name
      num_sockets          = v.num_sockets
      num_vcpus_per_socket = v.num_vcpus_per_socket
      memory_size_mib      = v.memory_size_mib
      power_state          = v.power_state
      state                = v.state
    }
  }
}

output "virtual_machine_ids" {
  description = "Map of VM keys to their UUIDs."
  value       = { for k, v in nutanix_virtual_machine.vm : k => v.id }
}

output "virtual_machine_nic_list" {
  description = "Map of VM keys to their NIC list status (includes assigned IPs)."
  value = {
    for k, v in nutanix_virtual_machine.vm : k => v.nic_list_status
  }
}

##################################################
# Summary
##################################################

output "compute_summary" {
  description = "Summary of compute resources managed by this module."
  value = {
    total_images           = length(var.images)
    total_virtual_machines = length(var.virtual_machines)
    disk_images            = length(local.disk_images)
    iso_images             = length(local.iso_images)
    powered_on_vms         = length(local.powered_on_vms)
    powered_off_vms        = length(local.powered_off_vms)
    gpu_vms                = length(local.gpu_vms)
  }
}
