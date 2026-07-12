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

##################################################
# VM Templates (v2, provider 2.4.2)
##################################################

# Versioned golden-image templates (nutanix_template_v2). A template is created
# from a source VM (referenced by external ID); the provider captures that VM
# into the template's initial, active version. This resource is steady-state:
# it declares the template and its initial version. Day-2 guest-OS updates to a
# template version are driven imperatively via var.template_guest_os_actions,
# not by editing these attributes.
variable "templates" {
  description = "A map of versioned VM templates to manage in Nutanix (nutanix_template_v2). Each template captures a source VM (referenced by external ID) into its initial, active version."
  type = map(object({
    name             = string
    description      = optional(string, null)
    category_ext_ids = optional(list(string), [])

    # Source VM external ID captured into the template's initial version via
    # template_version_spec.version_source.template_vm_reference.ext_id. The
    # source VM is referenced by ext_id, so templates do not depend on how the
    # VM itself is managed (the v1 -> v2 VM migration is a separate epic).
    source_vm_ext_id = string

    # Initial version metadata.
    version_name           = optional(string, null)
    version_description    = optional(string, null)
    is_active_version      = optional(bool, null) # provider default: true
    is_gc_override_enabled = optional(bool, null) # allow guest-customization override at deploy time
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.templates :
      v.source_vm_ext_id != null && v.source_vm_ext_id != ""
    ])
    error_message = "Each templates entry must set source_vm_ext_id (the external ID of the source VM to capture into the template)."
  }
}

# Template deployments (nutanix_deploy_templates_v2) are IMPERATIVE, one-shot
# actions: applying an entry deploys number_of_vms VMs from a template version
# ONCE. The deployed VMs are provider-side artifacts -- they are NOT tracked as
# nutanix_virtual_machine_v2 resources in this module's state, so day-2 changes
# to them happen entirely outside this resource. Re-deploying requires a NEW map
# key; mutating an existing entry (e.g. bumping number_of_vms) will not re-run
# the deploy for the VMs it already created. Destroying a deployment entry does
# not necessarily destroy the VMs it created -- the 2.4.2 registry docs do not
# define destroy-time teardown of the deployed VMs, so treat them as unmanaged
# once deployed.
variable "template_deployments" {
  description = "A map of one-shot template deployments (nutanix_deploy_templates_v2). IMPERATIVE: each entry deploys number_of_vms VMs once; the deployed VMs are provider-side artifacts, NOT tracked as VM resources. Re-deploy needs a new key; destroy does not necessarily remove the deployed VMs."
  type = map(object({
    # Template to deploy: a key of var.templates (resolved to the module-created
    # template's ext_id) or a literal ext_id of a pre-existing template.
    template = string
    # Cluster to deploy into: a cluster name (resolved to ext_id when
    # enable_data_lookups = true) or a literal cluster ext_id.
    cluster       = string
    number_of_vms = number
    # Optional specific template version to deploy (defaults to the active one).
    version_id = optional(string, null)
    # Optional per-VM overrides applied to the deployed VMs.
    override_vm_configs = optional(list(object({
      name                 = optional(string, null)
      memory_size_mib      = optional(number, null)
      num_sockets          = optional(number, null)
      num_cores_per_socket = optional(number, null)
      num_threads_per_core = optional(number, null)
    })), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.template_deployments :
      v.number_of_vms >= 1
    ])
    error_message = "Each template_deployments entry must set number_of_vms >= 1."
  }
}

# Guest-OS update sessions (nutanix_template_guest_os_actions_v2) drive an
# operator-triggered state machine over a template version: `initiate` starts a
# guest-OS update session (so an operator can patch the version's VM), `complete`
# finalises the session into a new template version, and `cancel` aborts it.
# These are OPERATOR-TRIGGERED, one-shot actions, not steady-state config -- each
# entry performs its action once on apply. Populate this map only when actively
# running a guest-OS update; leave it empty ({}) in steady state.
variable "template_guest_os_actions" {
  description = "A map of operator-triggered guest-OS update actions on template versions (nutanix_template_guest_os_actions_v2). One-shot state machine (initiate/complete/cancel), NOT steady-state config -- keep empty ({}) unless actively updating a template's guest OS."
  type = map(object({
    # Template whose version the action targets: a key of var.templates (resolved
    # to the module-created template's ext_id) or a literal template ext_id.
    template = string
    action   = string # initiate | complete | cancel
    # version_id is required for `initiate` (which version to update).
    version_id = optional(string, null)
    # version_name and version_description are required for `complete`.
    version_name        = optional(string, null)
    version_description = optional(string, null)
    # Mark the resulting version active on `complete` (provider default true).
    # The provider types this field as a string ("true"/"false") on this resource.
    is_active_version = optional(string, null)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.template_guest_os_actions :
      contains(["initiate", "complete", "cancel"], v.action)
    ])
    error_message = "template_guest_os_actions 'action' must be one of: initiate, complete, cancel."
  }
}

##################################################
# OVAs (v2, provider 2.4.2)
##################################################

# OVA appliance images (nutanix_ova_v2, introduced 2.3.2). An OVA is imported
# once from a URL, an object-store (object-lite) key, or captured from an
# existing VM, and is a steady-state resource: the ova_downloads and
# ova_deployments maps reference these OVAs by map key (resolved to ext_id) or by
# a literal ext_id. This is a SEPARATE resource family from images_v2 -- OVAs are
# whole-appliance bundles (VM config + disks), not standalone disk/ISO images.
variable "ovas" {
  description = "A map of OVA appliance images to manage in Nutanix (nutanix_ova_v2). Each OVA is imported once from a URL, an object-store key, or an existing VM. OVAs are a separate family from images_v2 (appliance bundles, not standalone disk/ISO images)."
  type = map(object({
    name = string
    # Disk format the OVA is stored in (e.g. QCOW2, VMDK). Provider-validated.
    disk_format = optional(string, null)
    # Clusters the OVA is placed on, by external ID.
    cluster_location_ext_ids = optional(list(string), [])

    # Optional integrity checksum. Set sha1 and/or sha256 hex digests; each maps
    # to the provider's ova_sha1_checksum / ova_sha256_checksum block.
    checksum = optional(object({
      sha1   = optional(string, null)
      sha256 = optional(string, null)
    }), null)

    # Exactly one source variant must be set (validated below):
    #   url_source         -- import from a URL (optional basic auth).
    #   object_lite_source -- import from an object-store key.
    #   vm_source          -- capture an existing VM (by ext_id) into an OVA.
    source = object({
      url_source = optional(object({
        url                       = string
        should_allow_insecure_url = optional(bool, false)
        basic_auth = optional(object({
          username = string
          password = string
        }), null)
      }), null)
      object_lite_source = optional(object({
        key = string
      }), null)
      vm_source = optional(object({
        vm_ext_id        = string
        disk_file_format = string # e.g. QCOW2, VMDK
      }), null)
    })
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.ovas :
      length([
        for s in [v.source.url_source, v.source.object_lite_source, v.source.vm_source] : s if s != null
      ]) == 1
    ])
    error_message = "Each ovas entry must set exactly one source variant: source.url_source, source.object_lite_source, or source.vm_source."
  }
}

# OVA downloads (nutanix_ova_download_v2) are IMPERATIVE, one-shot EXPORT actions:
# applying an entry exports/downloads the referenced OVA ONCE (surfacing the
# resulting ova_file_path). Re-running the export requires a NEW map key; mutating
# or destroying an existing entry does not re-run or reverse the export. Populate
# this map only when actively exporting an OVA; leave it empty ({}) in steady
# state.
variable "ova_downloads" {
  description = "A map of one-shot OVA export/download actions (nutanix_ova_download_v2). IMPERATIVE: each entry exports the referenced OVA once; re-exporting needs a NEW map key. Keep empty ({}) unless actively exporting an OVA."
  type = map(object({
    # OVA to export: a key of var.ovas (resolved to the module-created OVA's
    # ext_id) or a literal ext_id of a pre-existing OVA.
    ova = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.ova_downloads :
      v.ova != null && v.ova != ""
    ])
    error_message = "Each ova_downloads entry must set 'ova' (an ovas map key or an OVA ext_id)."
  }
}

# OVA VM deployments (nutanix_ova_vm_deploy_v2) deploy a VM FROM an OVA. The
# deployed VM is a provider-side artifact -- it is NOT tracked as a
# nutanix_virtual_machine_v2 resource in this module's state, so day-2 changes to
# the VM itself happen outside this resource. Provider 2.4.2 added UPDATE support
# for this resource: changing the override_vm_config attributes on an existing
# entry updates the deployment in place (older providers required replacement).
# The provider requires an override_vm_config with at least one NIC, so every
# deployment entry must supply a subnet for its NIC.
variable "ova_deployments" {
  description = "A map of VM deployments from OVAs (nutanix_ova_vm_deploy_v2). The deployed VM is a provider-side artifact, NOT tracked as a virtual_machine resource here. Provider 2.4.2 supports in-place UPDATE of override_vm_config. Each entry requires at least one NIC (subnet)."
  type = map(object({
    # OVA to deploy from: a key of var.ovas (resolved to the module-created OVA's
    # ext_id) or a literal ext_id of a pre-existing OVA.
    ova = string
    # Cluster to deploy into: a cluster name (resolved to ext_id when
    # enable_data_lookups = true) or a literal cluster ext_id.
    cluster = string

    # override_vm_config: applied to the deployed VM (provider requires this
    # block; UPDATE-capable in 2.4.2).
    name                 = optional(string, null)
    memory_size_mib      = optional(number, null) # converted to memory_size_bytes
    num_sockets          = optional(number, null)
    num_cores_per_socket = optional(number, null)
    num_threads_per_core = optional(number, null)
    power_state          = optional(string, null) # ON | OFF
    category_ext_ids     = optional(list(string), [])

    # At least one NIC is required by the provider. Subnet is referenced by
    # external ID.
    nics = list(object({
      subnet_ext_id = string
      nic_type      = optional(string, null)
      vlan_mode     = optional(string, null)
      is_connected  = optional(bool, null)
      model         = optional(string, null)
      mac_address   = optional(string, null)
      ipv4 = optional(object({
        should_assign_ip = optional(bool, null)
        ip_address = optional(object({
          value         = string
          prefix_length = optional(number, null)
        }), null)
      }), null)
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.ova_deployments :
      v.power_state == null || contains(["ON", "OFF"], v.power_state)
    ])
    error_message = "ova_deployments 'power_state' must be one of: ON, OFF."
  }

  validation {
    condition = alltrue([
      for k, v in var.ova_deployments :
      length(v.nics) >= 1
    ])
    error_message = "Each ova_deployments entry must define at least one NIC (the provider requires a NIC on the deployed VM)."
  }
}
