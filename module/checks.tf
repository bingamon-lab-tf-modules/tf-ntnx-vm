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
