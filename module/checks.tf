# Validate that VMs have at least one NIC.
check "vms_have_nic" {
  assert {
    condition = alltrue([
      for k, v in var.virtual_machines :
      length(v.nics) > 0
    ])
    error_message = "Virtual machines should have at least one NIC configured."
  }
}

# Validate that VMs have reasonable memory allocation.
check "vms_have_reasonable_memory" {
  assert {
    condition = alltrue([
      for k, v in var.virtual_machines :
      v.memory_size_mib >= 128
    ])
    error_message = "Virtual machines should have at least 128 MiB of memory."
  }
}

# Validate that images have a source defined.
check "images_have_source" {
  assert {
    condition = alltrue([
      for k, v in var.images :
      v.source != null
    ])
    error_message = "Images should have a 'source' defined."
  }
}

# Validate that host-affinity policies select at least one VM category.
check "host_affinity_policies_have_vm_categories" {
  assert {
    condition = alltrue([
      for k, v in var.vm_host_affinity_policies :
      length(v.vm_categories) >= 1
    ])
    error_message = "VM host-affinity policies should reference at least one VM category."
  }
}

# Validate that host-affinity policies select at least one host category.
check "host_affinity_policies_have_host_categories" {
  assert {
    condition = alltrue([
      for k, v in var.vm_host_affinity_policies :
      length(v.host_categories) >= 1
    ])
    error_message = "VM host-affinity policies should reference at least one host category."
  }
}

# Validate that anti-affinity policies select at least one VM category.
check "anti_affinity_policies_have_vm_categories" {
  assert {
    condition = alltrue([
      for k, v in var.vm_anti_affinity_policies :
      length(v.vm_categories) >= 1
    ])
    error_message = "VM anti-affinity policies should reference at least one VM category."
  }
}

# Validate that every template deployment references a resolvable template:
# either a key of var.templates (a module-created template) or a non-empty
# literal ext_id of a pre-existing template.
check "template_deployments_reference_resolvable_template" {
  assert {
    condition = alltrue([
      for k, v in var.template_deployments :
      contains(keys(var.templates), v.template) || (v.template != null && v.template != "")
    ])
    error_message = "Each template deployment should reference a templates map key or a non-empty template ext_id."
  }
}

# Validate that guest-OS update actions carry the fields their action requires:
# `initiate` needs version_id; `complete` needs version_name and
# version_description (version fields coherent with the action).
check "template_guest_os_actions_version_fields_coherent" {
  assert {
    condition = alltrue([
      for k, v in var.template_guest_os_actions :
      (v.action != "initiate" || v.version_id != null) &&
      (v.action != "complete" || (v.version_name != null && v.version_description != null))
    ])
    error_message = "Guest-OS 'initiate' actions should set version_id; 'complete' actions should set version_name and version_description."
  }
}

# Validate that every OVA defines a source variant (url, object-lite, or vm). The
# provider requires a source block; this surfaces a clear message in plan output.
check "ovas_have_source" {
  assert {
    condition = alltrue([
      for k, v in var.ovas :
      v.source.url_source != null || v.source.object_lite_source != null || v.source.vm_source != null
    ])
    error_message = "Each OVA should define a source (url_source, object_lite_source, or vm_source)."
  }
}

# Validate that every OVA download references a resolvable OVA: either a key of
# var.ovas (a module-created OVA) or a non-empty literal ext_id.
check "ova_downloads_reference_resolvable_ova" {
  assert {
    condition = alltrue([
      for k, v in var.ova_downloads :
      contains(keys(var.ovas), v.ova) || (v.ova != null && v.ova != "")
    ])
    error_message = "Each OVA download should reference an ovas map key or a non-empty OVA ext_id."
  }
}

# Validate that every OVA deployment references a resolvable OVA: either a key of
# var.ovas (a module-created OVA) or a non-empty literal ext_id.
check "ova_deployments_reference_resolvable_ova" {
  assert {
    condition = alltrue([
      for k, v in var.ova_deployments :
      contains(keys(var.ovas), v.ova) || (v.ova != null && v.ova != "")
    ])
    error_message = "Each OVA deployment should reference an ovas map key or a non-empty OVA ext_id."
  }
}

# Validate that every NGT installation names a VM (a virtual_machines map key or
# a VM ext_id).
check "ngt_installations_reference_vm" {
  assert {
    condition = alltrue([
      for k, v in var.ngt_installations :
      v.vm != null && v.vm != ""
    ])
    error_message = "Each NGT installation should name a VM (a virtual_machines map key or a VM ext_id)."
  }
}

# Validate that every vm_actions entry (across all sub-maps) names a VM. Actions
# are meaningless without a target VM; this surfaces a clear message in plan.
check "vm_actions_reference_vm" {
  assert {
    condition = alltrue(concat(
      [for k, v in var.vm_actions.clones : v.vm != null && v.vm != ""],
      [for k, v in var.vm_actions.gc_updates : v.vm != null && v.vm != ""],
      [for k, v in var.vm_actions.nic_ip_assignments : v.vm != null && v.vm != ""],
      [for k, v in var.vm_actions.nic_migrations : v.vm != null && v.vm != ""],
      [for k, v in var.vm_actions.cdrom_operations : v.vm != null && v.vm != ""],
      [for k, v in var.vm_actions.shutdowns : v.vm != null && v.vm != ""],
      [for k, v in var.vm_actions.reverts : v.vm != null && v.vm != ""],
      [for k, v in var.vm_actions.ngt_iso_inserts : v.vm != null && v.vm != ""],
      [for k, v in var.vm_actions.ngt_upgrades : v.vm != null && v.vm != ""],
    ))
    error_message = "Every vm_actions entry should name a VM (a virtual_machines map key or a VM ext_id)."
  }
}

# Validate that every revert action names a recovery point to revert to.
check "vm_reverts_reference_recovery_point" {
  assert {
    condition = alltrue([
      for k, v in var.vm_actions.reverts :
      v.recovery_point_ext_id != null && v.recovery_point_ext_id != ""
    ])
    error_message = "Each vm_actions revert should name a recovery point (recovery_point_ext_id)."
  }
}

# A disk's storage_container_key must resolve against the map the caller passed
# in from the storage landing zone.
#
# This is a check rather than a variable validation on purpose: var.images and
# var.ovas are this module's own inputs and can be validated directly, but
# var.storage_container_ids arrives from ANOTHER landing zone's output. On a
# clean-slate apply its keys are unknown at validate time, so a validation
# would either be unevaluable or wrongly reject a legitimate config. A check
# reports the mismatch at plan time with the offending key named, instead of
# failing deep inside a dynamic block.
check "vm_disk_storage_container_keys_resolve" {
  assert {
    condition = alltrue(flatten([
      for k, v in var.virtual_machines : [
        for d in v.disks :
        d.storage_container_key == null || contains(keys(var.storage_container_ids), coalesce(d.storage_container_key, ""))
      ]
    ]))
    error_message = "A VM disk 'storage_container_key' does not appear in var.storage_container_ids. Check the storage landing zone is enabled and that the key matches — Prism Element plane containers are keyed '<cluster>_<container>'."
  }
}

# Every NIC must resolve to a subnet.
#
# Checks rather than variable validations: var.subnet_names comes from ANOTHER
# landing zone's output, so its keys are unknown at validate time on a
# clean-slate apply. These report the offending name at plan time instead of
# failing inside a nested dynamic block.
check "vm_nic_subnet_names_resolve" {
  assert {
    condition = alltrue(flatten([
      for k, v in var.virtual_machines : [
        for n in v.nics :
        n.subnet_name == null || contains(keys(var.subnet_names), coalesce(n.subnet_name, ""))
      ]
    ]))
    error_message = "A VM NIC 'subnet_name' does not match any subnet. Check the network_topology landing zone is enabled and the name matches the subnet's Prism display name exactly (e.g. \"Virtual Machines\", not the YAML key \"vms\")."
  }
}

check "ova_deployment_subnet_names_resolve" {
  assert {
    condition = alltrue(flatten([
      for k, v in var.ova_deployments : [
        for n in v.nics :
        n.subnet_name == null || contains(keys(var.subnet_names), coalesce(n.subnet_name, ""))
      ]
    ]))
    error_message = "An OVA deployment NIC 'subnet_name' does not match any subnet. See vm_nic_subnet_names_resolve."
  }
}

# Category keys must resolve against the security_governance landing zone.
# Without this a VM applies cleanly, carries no categories, and is therefore
# NOT protected by any policy — a silent backup gap.
check "category_keys_resolve" {
  assert {
    condition = alltrue(concat(
      flatten([for k, v in var.virtual_machines : [for c in v.category_keys : contains(keys(var.category_ids), c)]]),
      flatten([for k, v in var.ova_deployments : [for c in v.category_keys : contains(keys(var.category_ids), c)]]),
    ))
    error_message = "A 'category_keys' entry does not match any managed category. Check the security_governance landing zone is enabled and the key matches (e.g. \"backup-bronze\")."
  }
}
