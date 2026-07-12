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
  gpu_vms = { for k, v in var.virtual_machines : k => v if length(v.gpus) > 0 }

  # VMs with cloud-init
  cloud_init_vms = {
    for k, v in var.virtual_machines : k => v
    if v.guest_customization_cloud_init_user_data != null
  }

  # Resolved boot configuration per VM. Null means "no boot_config block" so the
  # provider default applies. boot_type selects legacy_boot vs uefi_boot, and
  # SECURE_BOOT is uefi_boot with is_secure_boot_enabled = true.
  vm_boot = {
    for k, v in var.virtual_machines : k => (
      (
        v.boot_type == null &&
        length(v.boot_order) == 0 &&
        v.boot_device_disk_address == null &&
        v.boot_device_mac_address == null
        ) ? null : {
        mode        = (v.boot_type == "UEFI" || v.boot_type == "SECURE_BOOT") ? "UEFI" : "LEGACY"
        secure_boot = v.boot_type == "SECURE_BOOT"
      }
    )
  }

  # Whether a VM needs a guest_customization block at all.
  vm_guest_customization = {
    for k, v in var.virtual_machines : k => (
      v.guest_customization_cloud_init_user_data != null ||
      v.guest_customization_cloud_init_metadata != null ||
      v.guest_customization_sysprep != null
    )
  }
}
