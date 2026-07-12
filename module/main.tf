##################################################
# Images (v2)
##################################################

resource "nutanix_images_v2" "image" {
  for_each = var.images

  name        = each.value.name
  description = each.value.description
  type        = each.value.type

  category_ext_ids         = length(each.value.category_ext_ids) > 0 ? each.value.category_ext_ids : null
  cluster_location_ext_ids = length(each.value.cluster_location_ext_ids) > 0 ? each.value.cluster_location_ext_ids : null

  dynamic "checksum" {
    for_each = each.value.checksum != null ? [each.value.checksum] : []
    content {
      hex_digest  = checksum.value.hex_digest
      object_type = checksum.value.object_type
    }
  }

  dynamic "source" {
    for_each = each.value.source != null ? [each.value.source] : []
    content {
      dynamic "url_source" {
        for_each = source.value.url_source != null ? [source.value.url_source] : []
        content {
          url                       = url_source.value.url
          should_allow_insecure_url = url_source.value.should_allow_insecure_url

          dynamic "basic_auth" {
            for_each = url_source.value.basic_auth != null ? [url_source.value.basic_auth] : []
            content {
              username = basic_auth.value.username
              password = basic_auth.value.password
            }
          }
        }
      }

      dynamic "vm_disk_source" {
        for_each = source.value.vm_disk_source != null ? [source.value.vm_disk_source] : []
        content {
          ext_id = vm_disk_source.value.ext_id
        }
      }

      dynamic "object_lite_source" {
        for_each = source.value.object_lite_source != null ? [source.value.object_lite_source] : []
        content {
          key = object_lite_source.value.key
        }
      }
    }
  }
}

##################################################
# Virtual Machines
##################################################

resource "nutanix_virtual_machine" "vm" {
  for_each = var.virtual_machines

  name                 = each.value.name
  description          = each.value.description
  cluster_uuid         = each.value.cluster_uuid
  num_sockets          = each.value.num_sockets
  num_vcpus_per_socket = each.value.num_vcpus_per_socket
  # TODO: num_threads_per_core is unsupported in nutanix provider v2.3.1 - re-evaluate on provider upgrade
  # num_threads_per_core = each.value.num_threads_per_core
  memory_size_mib         = each.value.memory_size_mib
  power_state             = each.value.power_state
  machine_type            = each.value.machine_type
  boot_type               = each.value.boot_type
  guest_os_id             = each.value.guest_os_id
  hardware_clock_timezone = each.value.hardware_clock_timezone
  vga_console_enabled     = each.value.vga_console_enabled
  use_hot_add             = each.value.use_hot_add
  enable_cpu_passthrough  = each.value.enable_cpu_passthrough
  is_vcpu_hard_pinned     = each.value.is_vcpu_hard_pinned
  num_vnuma_nodes         = each.value.num_vnuma_nodes

  boot_device_order_list  = length(each.value.boot_device_order_list) > 0 ? each.value.boot_device_order_list : null
  boot_device_mac_address = each.value.boot_device_mac_address

  # TODO: boot_device_disk_address is unsupported in nutanix provider v2.3.1 - re-evaluate on provider upgrade
  # dynamic "boot_device_disk_address" {
  #   for_each = each.value.boot_device_disk_address != null ? [each.value.boot_device_disk_address] : []
  #   content {
  #     device_index = boot_device_disk_address.value.device_index
  #     adapter_type = boot_device_disk_address.value.adapter_type
  #   }
  # }

  dynamic "categories" {
    for_each = each.value.categories
    content {
      name  = categories.value.name
      value = categories.value.value
    }
  }

  dynamic "nic_list" {
    for_each = each.value.nic_list
    content {
      subnet_uuid               = nic_list.value.subnet_uuid
      subnet_name               = nic_list.value.subnet_name
      nic_type                  = nic_list.value.nic_type
      model                     = nic_list.value.model
      mac_address               = nic_list.value.mac_address
      num_queues                = nic_list.value.num_queues
      network_function_nic_type = nic_list.value.network_function_nic_type

      # TODO: network_function_chain_reference is unsupported in nutanix provider v2.3.1 - re-evaluate on provider upgrade
      # dynamic "network_function_chain_reference" {
      #   for_each = nic_list.value.network_function_chain_reference != null ? [nic_list.value.network_function_chain_reference] : []
      #   content {
      #     kind = network_function_chain_reference.value.kind
      #     uuid = network_function_chain_reference.value.uuid
      #   }
      # }

      dynamic "ip_endpoint_list" {
        for_each = nic_list.value.ip_endpoint_list
        content {
          ip   = ip_endpoint_list.value.ip
          type = ip_endpoint_list.value.type
        }
      }
    }
  }

  dynamic "disk_list" {
    for_each = each.value.disk_list
    content {
      disk_size_bytes = disk_list.value.disk_size_bytes
      disk_size_mib   = disk_list.value.disk_size_mib

      device_properties {
        device_type = try(disk_list.value.device_properties.device_type, "DISK")

        disk_address = {
          device_index = try(disk_list.value.device_properties.disk_address.device_index, 0)
          adapter_type = try(disk_list.value.device_properties.disk_address.adapter_type, "SCSI")
        }
      }

      data_source_reference = disk_list.value.data_source_reference

      dynamic "storage_config" {
        for_each = disk_list.value.storage_config != null ? [disk_list.value.storage_config] : []
        content {
          flash_mode = storage_config.value.flash_mode

          dynamic "storage_container_reference" {
            for_each = storage_config.value.storage_container_reference != null ? [storage_config.value.storage_container_reference] : []
            content {
              kind = storage_container_reference.value.kind
              uuid = storage_container_reference.value.uuid
            }
          }
        }
      }
    }
  }

  dynamic "serial_port_list" {
    for_each = each.value.serial_port_list
    content {
      index        = serial_port_list.value.index
      is_connected = serial_port_list.value.is_connected
    }
  }

  dynamic "gpu_list" {
    for_each = each.value.gpu_list
    content {
      vendor    = gpu_list.value.vendor
      mode      = gpu_list.value.mode
      device_id = gpu_list.value.device_id
    }
  }

  guest_customization_cloud_init_user_data         = each.value.guest_customization_cloud_init_user_data
  guest_customization_cloud_init_meta_data         = each.value.guest_customization_cloud_init_meta_data
  guest_customization_cloud_init_custom_key_values = each.value.guest_customization_cloud_init_custom_key_values
  guest_customization_is_overridable               = each.value.guest_customization_is_overridable
  guest_customization_sysprep_custom_key_values    = each.value.guest_customization_sysprep_custom_key_values

  # Guest customization - sysprep (attribute, not block). The typed object
  # variable is converted to the provider's map(string) attribute in locals.tf.
  guest_customization_sysprep = local.vm_sysprep[each.key]

  # TODO: project_reference block is unsupported in nutanix provider v2.3.1 - re-evaluate on provider upgrade
  # dynamic "project_reference" {
  #   for_each = each.value.project_reference != null ? [each.value.project_reference] : []
  #   content {
  #     kind = project_reference.value.kind
  #     uuid = project_reference.value.uuid
  #   }
  # }

  # TODO: owner_reference block is unsupported in nutanix provider v2.3.1 - re-evaluate on provider upgrade
  # dynamic "owner_reference" {
  #   for_each = each.value.owner_reference != null ? [each.value.owner_reference] : []
  #   content {
  #     kind = owner_reference.value.kind
  #     uuid = owner_reference.value.uuid
  #   }
  # }
}
