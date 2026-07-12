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
# Virtual Machines (v2 / v4 API)
##################################################

# Schema follows the nutanix_virtual_machine_v2 (v4 AHV config) resource. See
# module/README.md "Migration notes (v1 -> v2)" for the v1 -> v2 field mapping
# and for the handful of v1 fields that have no v2 equivalent.
variable "virtual_machines" {
  description = "A map of virtual machines to manage in Nutanix (nutanix_virtual_machine_v2)."
  type = map(object({
    name        = string
    description = optional(string, null)

    # Placement: v2 references the cluster by its external ID (was cluster_uuid).
    cluster_ext_id = string

    # Compute sizing.
    num_sockets          = optional(number, 1)
    num_cores_per_socket = optional(number, 1)    # was num_vcpus_per_socket
    num_threads_per_core = optional(number, null) # now supported (v1 TODO)
    num_numa_nodes       = optional(number, null) # was num_vnuma_nodes
    memory_size_mib      = optional(number, 2048) # converted to memory_size_bytes

    # Lifecycle and hardware flags.
    power_state                  = optional(string, "ON")
    machine_type                 = optional(string, null)
    hardware_clock_timezone      = optional(string, null)
    is_vga_console_enabled       = optional(bool, null) # was vga_console_enabled
    is_cpu_passthrough_enabled   = optional(bool, null) # was enable_cpu_passthrough
    is_vcpu_hard_pinning_enabled = optional(bool, null) # was is_vcpu_hard_pinned
    is_cpu_hotplug_enabled       = optional(bool, null) # v2-native (see migration notes re: use_hot_add)
    is_memory_overcommit_enabled = optional(bool, null)

    # Categories: v2 associates categories by external ID (was name/value pairs).
    category_ext_ids = optional(list(string), [])

    # Boot configuration. boot_type selects legacy_boot vs uefi_boot; SECURE_BOOT
    # maps to uefi_boot with is_secure_boot_enabled = true.
    boot_type  = optional(string, null)          # UEFI | LEGACY | SECURE_BOOT
    boot_order = optional(list(string), [])      # e.g. ["DISK", "CDROM", "NETWORK"]
    boot_device_disk_address = optional(object({ # now supported (v1 TODO)
      bus_type = optional(string, "SCSI")
      index    = optional(number, 0)
    }), null)
    boot_device_mac_address = optional(string, null) # boot from a specific NIC

    # NICs. Subnet is referenced by external ID (was subnet_uuid/subnet_name).
    nics = optional(list(object({
      subnet_ext_id             = string
      nic_type                  = optional(string, "NORMAL_NIC")
      network_function_nic_type = optional(string, null)
      vlan_mode                 = optional(string, null)
      is_connected              = optional(bool, true)
      model                     = optional(string, null)
      mac_address               = optional(string, null)
      num_queues                = optional(number, null)
      # now supported (v1 TODO): network function chain by external ID.
      network_function_chain_ext_id = optional(string, null)
      ipv4 = optional(object({
        should_assign_ip = optional(bool, null)
        ip_address = optional(object({
          value         = string
          prefix_length = optional(number, null)
        }), null)
        secondary_ip_addresses = optional(list(object({
          value         = string
          prefix_length = optional(number, null)
        })), [])
      }), null)
    })), [])

    # Data disks. Provide disk_size_bytes or disk_size_mib for blank disks, or an
    # image_ext_id / source_vm_disk_ext_id to clone from an existing source.
    disks = optional(list(object({
      disk_size_bytes = optional(number, null)
      disk_size_mib   = optional(number, null)
      # now supported (v1 TODO): disk address bus_type/index.
      bus_type = optional(string, "SCSI")
      index    = optional(number, null)
      # now supported (v1 TODO): clone source via data_source reference.
      image_ext_id             = optional(string, null)
      source_vm_disk_ext_id    = optional(string, null)
      storage_container_ext_id = optional(string, null)
      is_flash_mode_enabled    = optional(bool, null)
    })), [])

    # CD-ROMs (attach ISO images).
    cd_roms = optional(list(object({
      iso_type     = optional(string, null)
      bus_type     = optional(string, "IDE")
      index        = optional(number, null)
      image_ext_id = optional(string, null)
    })), [])

    serial_ports = optional(list(object({
      index        = number
      is_connected = optional(bool, true)
    })), [])

    gpus = optional(list(object({
      vendor    = optional(string, null)
      mode      = optional(string, null)
      device_id = optional(number, null)
    })), [])

    # Guest customization: cloud-init (Linux) or sysprep (Windows).
    guest_customization_cloud_init_user_data       = optional(string, null)
    guest_customization_cloud_init_metadata        = optional(string, null)
    guest_customization_cloud_init_datasource_type = optional(string, null)
    # now supported (v1 TODO): sysprep guest customization block.
    guest_customization_sysprep = optional(object({
      install_type = optional(string, "PREPARED")
      unattend_xml = optional(string, null)
    }), null)

    # Project / ownership: now supported (v1 TODOs). v2 replaces the v3
    # project_reference / owner_reference kind+uuid blocks with an external ID.
    project_ext_id = optional(string, null)
    owner_ext_id   = optional(string, null)
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

  validation {
    condition = alltrue([
      for k, v in var.virtual_machines :
      v.machine_type == null || contains(["PC", "PSERIES", "Q35"], v.machine_type)
    ])
    error_message = "VM 'machine_type' must be one of: PC, PSERIES, Q35."
  }
}

##################################################
# Data Lookups
##################################################

# Read-only lookups of existing Prism Central inventory (clusters, images, VMs,
# categories, affinity policies). Disabled by default so plan/validate/test needs
# no live PC connection and the list-everything reads are not run needlessly.
variable "enable_data_lookups" {
  description = "Enable read-only lookups of existing Prism Central inventory (clusters, images, VMs, categories, affinity policies)."
  type        = bool
  default     = false
}

##################################################
# VM Placement Policies (v2, new in provider 2.4.2)
##################################################

# Host-affinity pins VMs (selected by category) to a set of hosts (also selected
# by category). Categories are created in tf-ntnx-sec and referenced here by
# their external IDs. Follows the nutanix_vm_host_affinity_policy_v2 resource.
variable "vm_host_affinity_policies" {
  description = "A map of VM host-affinity policies (nutanix_vm_host_affinity_policy_v2) that pin VMs to hosts via categories."
  type = map(object({
    name            = string
    description     = optional(string, null)
    vm_categories   = list(string) # category external IDs selecting the VMs
    host_categories = list(string) # category external IDs selecting the hosts
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.vm_host_affinity_policies :
      length(v.vm_categories) >= 1
    ])
    error_message = "Each vm_host_affinity_policies entry must reference at least one VM category (vm_categories)."
  }

  validation {
    condition = alltrue([
      for k, v in var.vm_host_affinity_policies :
      length(v.host_categories) >= 1
    ])
    error_message = "Each vm_host_affinity_policies entry must reference at least one host category (host_categories)."
  }
}

# Anti-affinity keeps VMs (selected by category) apart on different hosts. The
# nutanix_vm_anti_affinity_policy_v2 resource exposes a single `categories` set;
# the module input calls it vm_categories for symmetry with host-affinity.
variable "vm_anti_affinity_policies" {
  description = "A map of VM anti-affinity policies (nutanix_vm_anti_affinity_policy_v2) that keep VMs apart via categories."
  type = map(object({
    name          = string
    description   = optional(string, null)
    vm_categories = list(string) # category external IDs selecting the VMs
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.vm_anti_affinity_policies :
      length(v.vm_categories) >= 1
    ])
    error_message = "Each vm_anti_affinity_policies entry must reference at least one VM category (vm_categories)."
  }
}
