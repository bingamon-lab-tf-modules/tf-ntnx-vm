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
# Virtual Machines (v2 / v4 API)
##################################################

resource "nutanix_virtual_machine_v2" "vm" {
  for_each = var.virtual_machines

  name        = each.value.name
  description = each.value.description

  # Compute sizing (v2 uses num_cores_per_socket and memory_size_bytes).
  num_sockets          = each.value.num_sockets
  num_cores_per_socket = each.value.num_cores_per_socket
  num_threads_per_core = each.value.num_threads_per_core
  num_numa_nodes       = each.value.num_numa_nodes
  memory_size_bytes    = each.value.memory_size_mib * 1024 * 1024

  # Lifecycle and hardware flags.
  power_state                  = each.value.power_state
  machine_type                 = each.value.machine_type
  hardware_clock_timezone      = each.value.hardware_clock_timezone
  is_vga_console_enabled       = each.value.is_vga_console_enabled
  is_cpu_passthrough_enabled   = each.value.is_cpu_passthrough_enabled
  is_vcpu_hard_pinning_enabled = each.value.is_vcpu_hard_pinning_enabled
  is_cpu_hotplug_enabled       = each.value.is_cpu_hotplug_enabled
  is_memory_overcommit_enabled = each.value.is_memory_overcommit_enabled

  # Cluster placement (v2: reference by external ID).
  cluster {
    ext_id = each.value.cluster_ext_id
  }

  # Category associations (v2: by external ID).
  dynamic "categories" {
    for_each = toset(local.vm_category_ext_ids[each.key])
    content {
      ext_id = categories.value
    }
  }

  # Boot configuration (resolves the v1 boot_device_disk_address TODO).
  dynamic "boot_config" {
    for_each = local.vm_boot[each.key] != null ? [local.vm_boot[each.key]] : []
    content {
      dynamic "legacy_boot" {
        for_each = boot_config.value.mode == "LEGACY" ? [1] : []
        content {
          boot_order = length(each.value.boot_order) > 0 ? each.value.boot_order : null

          dynamic "boot_device" {
            for_each = (each.value.boot_device_disk_address != null || each.value.boot_device_mac_address != null) ? [1] : []
            content {
              dynamic "boot_device_disk" {
                for_each = each.value.boot_device_disk_address != null ? [each.value.boot_device_disk_address] : []
                content {
                  disk_address {
                    bus_type = boot_device_disk.value.bus_type
                    index    = boot_device_disk.value.index
                  }
                }
              }
              dynamic "boot_device_nic" {
                for_each = each.value.boot_device_mac_address != null ? [each.value.boot_device_mac_address] : []
                content {
                  mac_address = boot_device_nic.value
                }
              }
            }
          }
        }
      }

      dynamic "uefi_boot" {
        for_each = boot_config.value.mode == "UEFI" ? [1] : []
        content {
          is_secure_boot_enabled = boot_config.value.secure_boot
          boot_order             = length(each.value.boot_order) > 0 ? each.value.boot_order : null

          dynamic "boot_device" {
            for_each = (each.value.boot_device_disk_address != null || each.value.boot_device_mac_address != null) ? [1] : []
            content {
              dynamic "boot_device_disk" {
                for_each = each.value.boot_device_disk_address != null ? [each.value.boot_device_disk_address] : []
                content {
                  disk_address {
                    bus_type = boot_device_disk.value.bus_type
                    index    = boot_device_disk.value.index
                  }
                }
              }
              dynamic "boot_device_nic" {
                for_each = each.value.boot_device_mac_address != null ? [each.value.boot_device_mac_address] : []
                content {
                  mac_address = boot_device_nic.value
                }
              }
            }
          }
        }
      }
    }
  }

  # NICs (resolves the v1 network_function_chain_reference TODO).
  dynamic "nics" {
    for_each = each.value.nics
    content {
      backing_info {
        is_connected = nics.value.is_connected
        model        = nics.value.model
        mac_address  = nics.value.mac_address
        num_queues   = nics.value.num_queues
      }

      network_info {
        nic_type                  = nics.value.nic_type
        network_function_nic_type = nics.value.network_function_nic_type
        vlan_mode                 = nics.value.vlan_mode

        subnet {
          # subnet_name resolves via the network_topology landing zone's
          # name map, so config carries "Virtual Machines" rather than a UUID
          # and the subnet is created before any VM attaches to it.
          ext_id = (
            nics.value.subnet_name != null
            ? local.resolved_subnet_names[nics.value.subnet_name]
            : nics.value.subnet_ext_id
          )
        }

        dynamic "network_function_chain" {
          for_each = nics.value.network_function_chain_ext_id != null ? [nics.value.network_function_chain_ext_id] : []
          content {
            ext_id = network_function_chain.value
          }
        }

        dynamic "ipv4_config" {
          for_each = nics.value.ipv4 != null ? [nics.value.ipv4] : []
          content {
            should_assign_ip = ipv4_config.value.should_assign_ip

            dynamic "ip_address" {
              for_each = ipv4_config.value.ip_address != null ? [ipv4_config.value.ip_address] : []
              content {
                value         = ip_address.value.value
                prefix_length = ip_address.value.prefix_length
              }
            }

            dynamic "secondary_ip_address_list" {
              for_each = ipv4_config.value.secondary_ip_addresses
              content {
                value         = secondary_ip_address_list.value.value
                prefix_length = secondary_ip_address_list.value.prefix_length
              }
            }
          }
        }
      }
    }
  }

  # Disks (resolves the v1 disk_address and data_source_reference TODOs).
  dynamic "disks" {
    for_each = each.value.disks
    content {
      disk_address {
        bus_type = disks.value.bus_type
        index    = disks.value.index
      }

      backing_info {
        vm_disk {
          disk_size_bytes = disks.value.disk_size_bytes != null ? disks.value.disk_size_bytes : (
            disks.value.disk_size_mib != null ? disks.value.disk_size_mib * 1024 * 1024 : null
          )

          # storage_container_key resolves against var.storage_container_ids,
          # which the caller populates from the storage landing zone's output —
          # the cross-landing-zone edge that lets a VM land on a container
          # created in the same apply. storage_container_ext_id remains the
          # literal escape hatch; omitting both lets Nutanix choose.
          dynamic "storage_container" {
            for_each = (disks.value.storage_container_key != null
              ? [local.resolved_storage_container_ids[disks.value.storage_container_key]]
            : disks.value.storage_container_ext_id != null ? [disks.value.storage_container_ext_id] : [])
            content {
              ext_id = storage_container.value
            }
          }

          dynamic "storage_config" {
            for_each = disks.value.is_flash_mode_enabled != null ? [disks.value.is_flash_mode_enabled] : []
            content {
              is_flash_mode_enabled = storage_config.value
            }
          }

          dynamic "data_source" {
            for_each = (disks.value.image_key != null || disks.value.image_ext_id != null || disks.value.source_vm_disk_ext_id != null) ? [1] : []
            content {
              reference {
                # image_key resolves against images this module creates, which
                # is what makes the VM depend on the image. image_ext_id stays
                # as the literal escape hatch. Variable validation guarantees
                # they are never both set.
                dynamic "image_reference" {
                  for_each = (disks.value.image_key != null
                    ? [local.managed_image_ext_ids[disks.value.image_key]]
                  : disks.value.image_ext_id != null ? [disks.value.image_ext_id] : [])
                  content {
                    image_ext_id = image_reference.value
                  }
                }
                dynamic "vm_disk_reference" {
                  for_each = disks.value.source_vm_disk_ext_id != null ? [disks.value.source_vm_disk_ext_id] : []
                  content {
                    disk_ext_id = vm_disk_reference.value
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  # CD-ROMs (attach ISO images).
  dynamic "cd_roms" {
    for_each = each.value.cd_roms
    content {
      iso_type = cd_roms.value.iso_type

      disk_address {
        bus_type = cd_roms.value.bus_type
        index    = cd_roms.value.index
      }

      dynamic "backing_info" {
        for_each = (cd_roms.value.image_key != null
          ? [local.managed_image_ext_ids[cd_roms.value.image_key]]
        : cd_roms.value.image_ext_id != null ? [cd_roms.value.image_ext_id] : [])
        content {
          data_source {
            reference {
              image_reference {
                image_ext_id = backing_info.value
              }
            }
          }
        }
      }
    }
  }

  dynamic "serial_ports" {
    for_each = each.value.serial_ports
    content {
      index        = serial_ports.value.index
      is_connected = serial_ports.value.is_connected
    }
  }

  dynamic "gpus" {
    for_each = each.value.gpus
    content {
      vendor    = gpus.value.vendor
      mode      = gpus.value.mode
      device_id = gpus.value.device_id
    }
  }

  # Guest customization: cloud-init and/or sysprep (resolves the v1 sysprep TODO).
  dynamic "guest_customization" {
    for_each = local.vm_guest_customization[each.key] ? [1] : []
    content {
      config {
        dynamic "cloud_init" {
          for_each = (each.value.guest_customization_cloud_init_user_data != null || each.value.guest_customization_cloud_init_metadata != null) ? [1] : []
          content {
            datasource_type = each.value.guest_customization_cloud_init_datasource_type
            metadata        = each.value.guest_customization_cloud_init_metadata

            dynamic "cloud_init_script" {
              for_each = each.value.guest_customization_cloud_init_user_data != null ? [1] : []
              content {
                user_data {
                  value = each.value.guest_customization_cloud_init_user_data
                }
              }
            }
          }
        }

        dynamic "sysprep" {
          for_each = each.value.guest_customization_sysprep != null ? [each.value.guest_customization_sysprep] : []
          content {
            install_type = sysprep.value.install_type

            dynamic "sysprep_script" {
              for_each = sysprep.value.unattend_xml != null ? [1] : []
              content {
                unattend_xml {
                  value = sysprep.value.unattend_xml
                }
              }
            }
          }
        }
      }
    }
  }

  # Project association (resolves the v1 project_reference TODO; v3 kind+uuid
  # is replaced by a v2 external ID).
  dynamic "project" {
    for_each = each.value.project_ext_id != null ? [each.value.project_ext_id] : []
    content {
      ext_id = project.value
    }
  }

  # Ownership (resolves the v1 owner_reference TODO; v3 kind+uuid is replaced by
  # a v2 external ID under ownership_info.owner).
  dynamic "ownership_info" {
    for_each = each.value.owner_ext_id != null ? [each.value.owner_ext_id] : []
    content {
      owner {
        ext_id = ownership_info.value
      }
    }
  }
}
