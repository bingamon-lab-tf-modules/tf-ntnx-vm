locals {

  ##################################################
  # Images
  ##################################################

  # Disk images
  disk_images = { for k, v in var.images : k => v if v.type == "DISK_IMAGE" }

  # ISO images
  iso_images = { for k, v in var.images : k => v if v.type == "ISO_IMAGE" }

  ##################################################
  # Virtual Machines
  ##################################################

  # VMs that are powered on
  powered_on_vms = { for k, v in var.virtual_machines : k => v if v.power_state == "ON" }

  # VMs that are powered off
  powered_off_vms = { for k, v in var.virtual_machines : k => v if v.power_state == "OFF" }

  # VMs with GPU
  gpu_vms = { for k, v in var.virtual_machines : k => v if length(v.gpu_list) > 0 }

  # VMs with cloud-init
  cloud_init_vms = {
    for k, v in var.virtual_machines : k => v
    if v.guest_customization_cloud_init_user_data != null
  }

  # Sysprep typed object converted to the provider's map(string) attribute,
  # with null attributes dropped (guest_customization_sysprep is an attribute
  # string map on the v1 resource, not a block).
  vm_sysprep = {
    for k, v in var.virtual_machines : k => (
      v.guest_customization_sysprep == null ? null : {
        for attr, value in {
          install_type = v.guest_customization_sysprep.install_type
          unattend_xml = v.guest_customization_sysprep.unattend_xml
        } : attr => value if value != null
      }
    )
  }
}
