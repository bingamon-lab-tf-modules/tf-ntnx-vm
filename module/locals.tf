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

  ##################################################
  # Data Lookups (name -> ext_id convenience maps)
  ##################################################

  # Convenience maps of existing Prism Central inventory keyed by name, built from
  # the gated data sources in data.tf. Only populated when
  # var.enable_data_lookups = true; empty otherwise. The try() guards the
  # count = 0 case, where the data source resolves to an empty list, so plan,
  # validate and test work without a live Prism Central connection.

  existing_cluster_ext_ids = {
    for c in try(data.nutanix_clusters_v2.existing_cluster[0].cluster_entities, []) :
    c.name => c.ext_id
  }

  existing_image_ext_ids = {
    for i in try(data.nutanix_images_v2.existing_image[0].images, []) :
    i.name => i.ext_id
  }

  existing_vm_ext_ids = {
    for v in try(data.nutanix_virtual_machines_v2.existing_vm[0].vms, []) :
    v.name => v.ext_id
  }

  # Existing templates (template name -> ext_id) from the gated data lookup.
  existing_template_ext_ids = {
    for t in try(data.nutanix_templates_v2.existing_template[0].templates, []) :
    t.template_name => t.ext_id
  }

  # Existing OVAs (OVA name -> ext_id) from the gated data lookup.
  existing_ova_ext_ids = {
    for o in try(data.nutanix_ovas_v2.existing_ova[0].ovas, []) :
    o.name => o.ext_id
  }

  ##################################################
  # Templates (deployment / action -> template ext_id resolution)
  ##################################################

  # Resolve each deployment's template reference to an ext_id. A deployment's
  # `template` is either a key of var.templates (a module-created template,
  # whose computed ext_id is used) or a literal ext_id of a pre-existing
  # template. Module-created templates win.
  template_deployment_template_ext_id = {
    for k, v in var.template_deployments : k => (
      contains(keys(var.templates), v.template)
      ? nutanix_template_v2.template[v.template].ext_id
      : v.template
    )
  }

  # Resolve each guest-OS action's template reference to an ext_id, using the
  # same module-created-template-first rule as deployments.
  template_guest_os_action_ext_id = {
    for k, v in var.template_guest_os_actions : k => (
      contains(keys(var.templates), v.template)
      ? nutanix_template_v2.template[v.template].ext_id
      : v.template
    )
  }

  ##################################################
  # OVAs (download / deployment -> OVA ext_id resolution)
  ##################################################

  # Resolve each download's OVA reference to an ext_id. An `ova` is either a key
  # of var.ovas (a module-created OVA, whose computed ext_id is used) or a literal
  # ext_id of a pre-existing OVA. Module-created OVAs win.
  ova_download_ova_ext_id = {
    for k, v in var.ova_downloads : k => (
      contains(keys(var.ovas), v.ova)
      ? nutanix_ova_v2.ova[v.ova].ext_id
      : v.ova
    )
  }

  # Resolve each deployment's OVA reference to an ext_id, using the same
  # module-created-OVA-first rule as downloads.
  ova_deployment_ova_ext_id = {
    for k, v in var.ova_deployments : k => (
      contains(keys(var.ovas), v.ova)
      ? nutanix_ova_v2.ova[v.ova].ext_id
      : v.ova
    )
  }
}
