# Validate that VMs have at least one NIC.
check "vms_have_nic" {
  assert {
    condition = alltrue([
      for k, v in var.virtual_machines :
      length(v.nic_list) > 0
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
