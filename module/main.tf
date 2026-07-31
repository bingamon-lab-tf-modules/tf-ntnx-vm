##################################################
# Images (v2)
##################################################

##################################################
# Image source change detector
#
# THE PROVIDER ACCEPTS A url CHANGE IT CANNOT HONOUR. `source.url_source.url` is
# not ForceNew, so editing it plans as "will be updated in-place":
#
#   ~ url = ".../nkp-bastion.qcow2" -> ".../nkp-bastion-2.18.0-20260731.qcow2"
#
# An image's data is materialised ONCE, at create: downloaded, qemu-img
# converted, and turned into a vdisk. Updating the URL afterwards changes a
# metadata field and nothing else. Prism never re-downloads.
#
# So the apply succeeds, the config claims the new build, and the vdisk is still
# the old one. Every VM cloned from it silently gets stale content. That is the
# same shape as the corrupt-image failure that cost a full day of debugging:
# an image whose metadata and contents disagree.
#
# Hashing the source and forcing replacement makes the URL mean what it says.
#
# NOTE the cost: replacement is a destroy-then-create, so any VM cloning from
# this image must be replaced too, and an ImageDelete landing near a VmCreate is
# itself a known hazard (AHV returns "Unknown volume disk" when a clone source
# disappears mid-flight). The safer rollout is still a NEW image key alongside
# the old one, switching the VM over, and dropping the old entry in a later
# apply. This guard exists so that mutating a URL in place FAILS LOUDLY rather
# than silently doing nothing - not to make it the recommended path.
##################################################

resource "terraform_data" "image_source" {
  for_each = var.images

  # jsonencode over the whole source block: it covers url_source, the object
  # store key and the vm_disk variant in one, and serialises nulls without the
  # coalesce trap (coalesce rejects empty strings as well as nulls).
  input = sha256(jsonencode(each.value.source))
}

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

  lifecycle {
    ignore_changes = [
      source[0].url_source[0].should_allow_insecure_url,
    ]

    # See terraform_data.image_source above: a url edit is an in-place update
    # the provider cannot actually honour, so force a real create instead.
    replace_triggered_by = [
      terraform_data.image_source[each.key],
    ]
  }
}

##################################################
# Virtual Machines (v2 / v4 API)
##################################################

##################################################
# Cloud-init change detector
#
# CLOUD-INIT RUNS ONCE, AT FIRST BOOT. Editing a profile can therefore never
# affect a RUNNING VM — the only way to apply a new profile is a new VM. This
# resource makes OpenTofu express that: its input is a hash of the guest
# customization, so changing the profile changes the hash, and the
# replace_triggered_by below turns that into a VM replacement.
#
# WHY A HASH AND NOT JUST DROPPING ignore_changes. The v4 API does not reliably
# return cloud-init user-data on read (it is write-mostly), so without
# ignore_changes the provider compares a base64 string in config against null in
# state and wants to replace the VM on EVERY plan — including plans where
# nothing changed. Hashing sidesteps the read entirely: the trigger is derived
# from config, so it moves only when config moves.
#
# Consequence, deliberately: editing a profile DESTROYS AND RECREATES every VM
# using it. An operator who does not want that should add a NEW profile and a
# NEW VM rather than editing one in place.
##################################################

# VM disk source change detector
#
# CHANGING A DISK'S IMAGE IS A NO-OP ON A LIVE VM, AND THE PROVIDER HIDES IT.
# data_source.reference.image_reference.image_ext_id is not ForceNew, so
# repointing a VM at a new image plans as "will be updated in-place":
#
#   ~ image_ext_id = "e7daa77a-..." -> "ba7b016b-..."
#
# The apply then "succeeds" in about two seconds - nowhere near long enough to
# re-clone a disk - and the post-apply read comes straight back with the OLD
# ext_id, because Prism never accepted it. A VM disk is a CLONE, made once at
# create; there is no operation that re-images it in place.
#
# The damage is worse than a no-op. The apply reports success, the VM keeps
# running the previous image, and the diff reappears on every subsequent plan
# because state can never converge on a value Prism will not store.
#
# Hashing the resolved disk sources and forcing replacement makes repointing a
# VM at a new image mean what it says: destroy, re-clone, boot the new content.
resource "terraform_data" "vm_disk_source" {
  for_each = var.virtual_machines

  # The RESOLVED ext_ids, not the config keys. image_key is stable across an
  # image rebuild while the ext_id underneath changes, so hashing the key would
  # miss exactly the case this exists for.
  input = sha256(jsonencode([
    for d in each.value.disks : {
      image = (
        d.image_key != null
        ? local.managed_image_ext_ids[d.image_key]
        : d.image_ext_id
      )
      vm_disk = d.source_vm_disk_ext_id
    }
  ]))
}

resource "terraform_data" "cloud_init" {
  for_each = var.virtual_machines

  # jsonencode, not join/coalesce: coalesce rejects EMPTY STRINGS as well as
  # nulls, so coalesce(null, "") is an error rather than a default — the module
  # test suite caught exactly that. jsonencode serialises nulls happily and is
  # deterministic, which is all a change-detector hash needs.
  input = sha256(jsonencode([
    each.value.guest_customization_cloud_init_user_data,
    each.value.guest_customization_cloud_init_metadata,
    each.value.guest_customization_cloud_init_datasource_type,
    each.value.guest_customization_sysprep,
  ]))
}

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
  #
  # BOTH halves use the discriminated-union schema. The provider replaced the
  # flat pair (backing_info / network_info) with nic_backing_info /
  # nic_network_info, each wrapping a per-NIC-kind block —
  # virtual_ethernet_nic and virtual_ethernet_nic_network_info here, with
  # sriov_* and dp_offload_* as the other arms.
  #
  # These two MUST move together. Commit e920f93 migrated only the backing half
  # and left network_info on the deprecated path, producing a mixed NIC payload:
  # new-style backing, old-style network info. That is not a cosmetic warning —
  # AHV accepted the VM spec and then failed the CreateVm task at 100% with
  # "Failed to perform the operation due to an internal error", which names
  # nothing and is indistinguishable from a cluster fault.
  dynamic "nics" {
    for_each = each.value.nics
    content {
      nic_backing_info {
        virtual_ethernet_nic {
          is_connected = nics.value.is_connected
          model        = nics.value.model
          mac_address  = nics.value.mac_address
          num_queues   = nics.value.num_queues
        }
      }

      nic_network_info {
        virtual_ethernet_nic_network_info {
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

  lifecycle {
    # guest_customization stays ignored so a write-mostly field cannot produce a
    # perpetual diff — but it is NOT unmanaged: terraform_data.cloud_init above
    # hashes it and replace_triggered_by turns a change into a VM replacement,
    # which is the only thing that can actually apply a new cloud-init.
    ignore_changes = [
      guest_customization,
      cd_roms,
      boot_config[0].uefi_boot[0].boot_order,
      boot_config[0].legacy_boot[0].boot_order,
    ]

    replace_triggered_by = [
      terraform_data.cloud_init[each.key],
      terraform_data.vm_disk_source[each.key],
    ]
  }
}
