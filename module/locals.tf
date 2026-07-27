locals {

  ##################################################
  # Images
  ##################################################

  ##################################################
  # Key -> ext_id resolution
  #
  # These are what give OpenTofu a dependency edge. Referencing
  # nutanix_images_v2.image[k].ext_id (rather than accepting a literal ext_id)
  # makes every VM, OVA deployment and template deployment depend on the image
  # it consumes, so a clean-slate apply orders itself correctly in ONE run and
  # no UUID is ever written into config.
  ##################################################

  # image key -> ext_id, for images this module creates.
  managed_image_ext_ids = {
    for k, v in nutanix_images_v2.image : k => v.ext_id
  }

  # Subnet NAME -> ext_id, passed in from the network_topology landing zone.
  # Kept as its own local so an unresolved name fails in one obvious place.
  resolved_subnet_names = var.subnet_names

  # Per-VM category ext_ids: keys resolved against the security_governance
  # landing zone's categories, plus any literal ext_ids. This reference is what
  # orders categories before the VMs that carry them.
  vm_category_ext_ids = {
    for k, v in var.virtual_machines : k => concat(
      [for ck in v.category_keys : var.category_ids[ck]],
      v.category_ext_ids,
    )
  }

  ova_deployment_category_ext_ids = {
    for k, v in var.ova_deployments : k => concat(
      [for ck in v.category_keys : var.category_ids[ck]],
      v.category_ext_ids,
    )
  }

  # Storage container key -> ext_id, passed in from the storage landing zone.
  # Kept as its own local so an unresolved key fails in one obvious place
  # rather than inside a nested dynamic block.
  resolved_storage_container_ids = var.storage_container_ids

  # NOTE: there is deliberately no managed_ova_ext_ids here. OVA references
  # already accept "key of var.ovas OR literal ext_id" and resolve via
  # ova_download_ova_ext_id / ova_deployment_ova_ext_id below, which gives the
  # same dependency edge. Images needed image_key because a VM disk's
  # image_ext_id was a raw passthrough with no such rule.

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

  ##################################################
  # Day-2 actions (VM reference -> ext_id resolution)
  ##################################################

  # Every NGT installation and vm_actions entry names a VM by `vm`, which is
  # either a key of var.virtual_machines (resolved to the module-created VM's
  # computed ext_id) or a literal ext_id of a pre-existing VM. Module-created
  # VMs win. These per-map resolution locals keep main_actions.tf declarative.
  ngt_installation_vm_ext_id = {
    for k, v in var.ngt_installations : k => (
      contains(keys(var.virtual_machines), v.vm)
      ? nutanix_virtual_machine_v2.vm[v.vm].ext_id
      : v.vm
    )
  }

  clone_vm_ext_id = {
    for k, v in var.vm_actions.clones : k => (
      contains(keys(var.virtual_machines), v.vm)
      ? nutanix_virtual_machine_v2.vm[v.vm].ext_id
      : v.vm
    )
  }

  gc_update_vm_ext_id = {
    for k, v in var.vm_actions.gc_updates : k => (
      contains(keys(var.virtual_machines), v.vm)
      ? nutanix_virtual_machine_v2.vm[v.vm].ext_id
      : v.vm
    )
  }

  nic_ip_assignment_vm_ext_id = {
    for k, v in var.vm_actions.nic_ip_assignments : k => (
      contains(keys(var.virtual_machines), v.vm)
      ? nutanix_virtual_machine_v2.vm[v.vm].ext_id
      : v.vm
    )
  }

  nic_migration_vm_ext_id = {
    for k, v in var.vm_actions.nic_migrations : k => (
      contains(keys(var.virtual_machines), v.vm)
      ? nutanix_virtual_machine_v2.vm[v.vm].ext_id
      : v.vm
    )
  }

  cdrom_operation_vm_ext_id = {
    for k, v in var.vm_actions.cdrom_operations : k => (
      contains(keys(var.virtual_machines), v.vm)
      ? nutanix_virtual_machine_v2.vm[v.vm].ext_id
      : v.vm
    )
  }

  shutdown_vm_ext_id = {
    for k, v in var.vm_actions.shutdowns : k => (
      contains(keys(var.virtual_machines), v.vm)
      ? nutanix_virtual_machine_v2.vm[v.vm].ext_id
      : v.vm
    )
  }

  revert_vm_ext_id = {
    for k, v in var.vm_actions.reverts : k => (
      contains(keys(var.virtual_machines), v.vm)
      ? nutanix_virtual_machine_v2.vm[v.vm].ext_id
      : v.vm
    )
  }

  ngt_iso_insert_vm_ext_id = {
    for k, v in var.vm_actions.ngt_iso_inserts : k => (
      contains(keys(var.virtual_machines), v.vm)
      ? nutanix_virtual_machine_v2.vm[v.vm].ext_id
      : v.vm
    )
  }

  ngt_upgrade_vm_ext_id = {
    for k, v in var.vm_actions.ngt_upgrades : k => (
      contains(keys(var.virtual_machines), v.vm)
      ? nutanix_virtual_machine_v2.vm[v.vm].ext_id
      : v.vm
    )
  }
}
