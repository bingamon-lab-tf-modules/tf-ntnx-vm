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
