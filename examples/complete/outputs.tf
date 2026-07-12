################################################################################
# Image Outputs
################################################################################

output "images" {
  description = "Map of created images"
  value       = module.vm.images
}

output "image_ids" {
  description = "Map of image keys to their IDs"
  value       = module.vm.image_ids
}

################################################################################
# Virtual Machine Outputs
################################################################################

output "virtual_machines" {
  description = "Map of created virtual machines"
  value       = module.vm.virtual_machines
}

output "virtual_machine_ids" {
  description = "Map of VM keys to their UUIDs"
  value       = module.vm.virtual_machine_ids
}

output "virtual_machine_nic_ips" {
  description = "Map of VM keys to their NIC IP addresses"
  value       = module.vm.virtual_machine_nic_ips
}
