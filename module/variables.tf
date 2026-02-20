##################################################
# Images (v2)
##################################################

variable "images" {
  description = "A map of images to manage in Nutanix."
  type = map(object({
    name        = string
    description = optional(string, null)
    type        = string # DISK_IMAGE, ISO_IMAGE

    source = optional(object({
      url_source = optional(object({
        url                       = string
        should_allow_insecure_url = optional(bool, false)
        basic_auth = optional(object({
          username = string
          password = string
        }), null)
      }), null)
      vm_disk_source = optional(object({
        ext_id = string
      }), null)
      object_lite_source = optional(object({
        key = string
      }), null)
    }), null)

    checksum = optional(object({
      hex_digest  = string
      object_type = optional(string, null)
    }), null)

    category_ext_ids         = optional(list(string), [])
    cluster_location_ext_ids = optional(list(string), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.images :
      contains(["DISK_IMAGE", "ISO_IMAGE"], v.type)
    ])
    error_message = "Image 'type' must be one of: DISK_IMAGE, ISO_IMAGE."
  }
}

##################################################
# Virtual Machines
##################################################

variable "virtual_machines" {
  description = "A map of virtual machines to manage in Nutanix."
  type = map(object({
    name                    = string
    description             = optional(string, null)
    cluster_uuid            = string
    num_sockets             = optional(number, 1)
    num_vcpus_per_socket    = optional(number, 1)
    num_threads_per_core    = optional(number, null)
    memory_size_mib         = optional(number, 2048)
    power_state             = optional(string, "ON")
    machine_type            = optional(string, null)
    boot_type               = optional(string, null)
    guest_os_id             = optional(string, null)
    hardware_clock_timezone = optional(string, null)
    vga_console_enabled     = optional(bool, null)
    use_hot_add             = optional(bool, true)
    enable_cpu_passthrough  = optional(bool, null)
    is_vcpu_hard_pinned     = optional(bool, null)
    num_vnuma_nodes         = optional(number, null)

    categories = optional(list(object({
      name  = string
      value = string
    })), [])

    nic_list = optional(list(object({
      subnet_uuid               = optional(string, null)
      subnet_name               = optional(string, null)
      nic_type                  = optional(string, "NORMAL_NIC")
      model                     = optional(string, null)
      mac_address               = optional(string, null)
      num_queues                = optional(number, null)
      network_function_nic_type = optional(string, null)
      network_function_chain_reference = optional(object({
        kind = optional(string, "network_function_chain")
        uuid = string
      }), null)
      ip_endpoint_list = optional(list(object({
        ip   = string
        type = optional(string, "ASSIGNED")
      })), [])
    })), [])

    disk_list = optional(list(object({
      disk_size_bytes = optional(number, null)
      disk_size_mib   = optional(number, null)
      device_properties = optional(object({
        device_type = optional(string, "DISK")
        disk_address = optional(object({
          device_index = number
          adapter_type = string
        }), null)
      }), null)
      data_source_reference = optional(object({
        kind = string
        uuid = string
      }), null)
      storage_config = optional(object({
        flash_mode = optional(string, null)
        storage_container_reference = optional(object({
          kind = optional(string, "storage_container")
          uuid = string
        }), null)
      }), null)
    })), [])

    serial_port_list = optional(list(object({
      index        = number
      is_connected = optional(bool, true)
    })), [])

    boot_device_order_list  = optional(list(string), [])
    boot_device_mac_address = optional(string, null)
    boot_device_disk_address = optional(object({
      device_index = number
      adapter_type = string
    }), null)

    guest_customization_cloud_init_user_data         = optional(string, null)
    guest_customization_cloud_init_meta_data         = optional(string, null)
    guest_customization_cloud_init_custom_key_values = optional(map(string), null)
    guest_customization_is_overridable               = optional(bool, null)
    guest_customization_sysprep = optional(object({
      install_type = optional(string, "PREPARED")
      unattend_xml = optional(string, null)
    }), null)
    guest_customization_sysprep_custom_key_values = optional(map(string), null)

    project_reference = optional(object({
      kind = optional(string, "project")
      uuid = string
    }), null)

    owner_reference = optional(object({
      kind = optional(string, "user")
      uuid = string
    }), null)

    gpu_list = optional(list(object({
      vendor    = string
      mode      = optional(string, null)
      device_id = optional(number, null)
    })), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.virtual_machines :
      v.power_state == null || contains(["ON", "OFF"], v.power_state)
    ])
    error_message = "VM 'power_state' must be one of: ON, OFF."
  }

  validation {
    condition = alltrue([
      for k, v in var.virtual_machines :
      v.boot_type == null || contains(["UEFI", "LEGACY", "SECURE_BOOT"], v.boot_type)
    ])
    error_message = "VM 'boot_type' must be one of: UEFI, LEGACY, SECURE_BOOT."
  }
}
