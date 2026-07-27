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
##################################################
# Cross-landing-zone inputs
##################################################

# Storage containers are owned by a DIFFERENT landing zone (tf-ntnx-storage),
# so this module cannot create a dependency on them directly. The caller passes
# that landing zone's storage_container_ids output in here, which gives
# OpenTofu the edge instead: storage -> compute, in one apply, with no ext_id
# written into config by hand.
# Subnets are owned by the network_topology landing zone. The caller passes its
# subnet_ids output (key => ext_id) and a NAME => ext_id map built from the same
# source, so a NIC can say subnet_name: "Virtual Machines" — what an operator
# sees in Prism — instead of a UUID.
variable "subnet_ids" {
  description = "Map of subnet key => ext_id, from the network_topology landing zone's subnet_ids output."
  type        = map(string)
  default     = {}
}

variable "subnet_names" {
  description = "Map of subnet NAME => ext_id, from the network_topology landing zone. Referenced by a NIC's 'subnet_name'. Names must be unique across the environment; the caller is responsible for rejecting duplicates before they reach here."
  type        = map(string)
  default     = {}
}

# Categories are owned by the security_governance landing zone. Passing them in
# is what lets a VM declare its backup tier by name (category_keys:
# ["backup-bronze"]) and gives OpenTofu the edge categories -> VMs.
variable "category_ids" {
  description = "Map of category key => ext_id, from the security_governance landing zone's category_ids output. Referenced by 'category_keys' on VMs, images and OVA deployments."
  type        = map(string)
  default     = {}
}

variable "storage_container_ids" {
  description = "Map of storage container key => ext_id, supplied by the caller from the storage landing zone's storage_container_ids output. Referenced by a VM disk's 'storage_container_key'. Empty when the storage landing zone is disabled, in which case disks must use storage_container_ext_id or omit placement entirely."
  type        = map(string)
  default     = {}
}

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
    # Categories applied to the VM. 'category_keys' names them from the
    # security_governance landing zone and is resolved to ext_ids; this is how
    # a VM declares its BACKUP TIER (backup-gold / backup-silver /
    # backup-bronze / backup-none). A protection policy targets the category,
    # so tagging is the whole mechanism by which a VM gets backed up.
    category_keys    = optional(list(string), [])
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
      # Supply EXACTLY ONE of subnet_name / subnet_ext_id.
      #   subnet_name    -- the subnet's Prism display name, resolved via
      #     var.subnet_names. This is the readable form and the one that gives
      #     OpenTofu a dependency on the subnet existing first.
      #   subnet_ext_id  -- a literal UUID. Escape hatch for a subnet this
      #     landing zone does not manage.
      subnet_name               = optional(string, null)
      subnet_ext_id             = optional(string, null)
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
      # Boot/data source. Supply AT MOST ONE of image_key / image_ext_id.
      #   image_key    -- key into var.images, resolved to that image's ext_id
      #     after it is created. PREFERRED: it is the only form that gives
      #     OpenTofu a dependency edge, so the image is guaranteed to exist
      #     before the VM that boots from it, in a SINGLE apply.
      #   image_ext_id -- a literal image ext_id. Escape hatch for an image
      #     this module does not manage.
      image_key             = optional(string, null)
      image_ext_id          = optional(string, null)
      source_vm_disk_ext_id = optional(string, null)

      # Where the disk physically lands. Supply AT MOST ONE of
      # storage_container_key / storage_container_ext_id; omit both to let
      # Nutanix choose (usually default-container-*).
      #   storage_container_key -- key into var.storage_container_ids, which the
      #     caller populates from the storage landing zone's
      #     storage_container_ids output. Keys are the storage module's own, so
      #     for a Prism Element plane container that is the flattened
      #     "<cluster>_<container>" form.
      storage_container_key    = optional(string, null)
      storage_container_ext_id = optional(string, null)
      is_flash_mode_enabled    = optional(bool, null)
    })), [])

    # CD-ROMs (attach ISO images).
    cd_roms = optional(list(object({
      iso_type = optional(string, null)
      bus_type = optional(string, "IDE")
      index    = optional(number, null)
      # Same image_key / image_ext_id pair as disks above: image_key resolves
      # against var.images and creates the dependency edge.
      image_key    = optional(string, null)
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
  validation {
    condition = alltrue(flatten([
      for k, v in var.virtual_machines : [
        for d in v.disks : !(d.image_key != null && d.image_ext_id != null)
      ]
    ]))
    error_message = "A VM disk must not set both 'image_key' and 'image_ext_id'. Use image_key for an image this module creates; image_ext_id only for one it does not."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.virtual_machines : [
        for d in v.disks :
        d.image_key == null || contains(keys(var.images), coalesce(d.image_key, ""))
      ]
    ]))
    error_message = "A VM disk 'image_key' must be a key in var.images."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.virtual_machines : [
        for c in v.cd_roms : !(c.image_key != null && c.image_ext_id != null)
      ]
    ]))
    error_message = "A VM CD-ROM must not set both 'image_key' and 'image_ext_id'."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.virtual_machines : [
        for c in v.cd_roms :
        c.image_key == null || contains(keys(var.images), coalesce(c.image_key, ""))
      ]
    ]))
    error_message = "A VM CD-ROM 'image_key' must be a key in var.images."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.virtual_machines : [
        for d in v.disks :
        !(d.storage_container_key != null && d.storage_container_ext_id != null)
      ]
    ]))
    error_message = "A VM disk must not set both 'storage_container_key' and 'storage_container_ext_id'."
  }

  # Deliberately NOT validated against keys(var.storage_container_ids): that map
  # is populated from another landing zone's output, so on a clean-slate apply
  # its keys are not known until storage has been created. A wrong key surfaces
  # as an unresolved lookup instead, and checks.tf reports it at plan time.

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
    # Same backup-tier mechanism as a VM. The deployed VM is untracked by
    # OpenTofu, but Prism Central evaluates protection policies against
    # CATEGORIES, not against state — so a tagged OVA deployment is still
    # protected. This is the case category-driven backup exists for.
    category_keys    = optional(list(string), [])
    category_ext_ids = optional(list(string), [])

    # At least one NIC is required by the provider. Subnet is referenced by
    # external ID.
    nics = list(object({
      subnet_name   = optional(string, null)
      subnet_ext_id = optional(string, null)
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

##################################################
# Nutanix Guest Tools -- installation (v2, provider 2.4.2)
##################################################

# NGT installation (nutanix_ngt_installation_v2) is a DECLARATIVE, steady-state
# resource: it installs and manages Nutanix Guest Tools on an existing VM and
# reconciles is_enabled / capabilities on subsequent applies (unlike the
# imperative vm_actions below). Guest OS credentials are NOT taken here -- they
# live in the separate, sensitive var.ngt_installation_credentials so they never
# transit YAML (see spec "Do NOT put guest OS credentials in YAML").
#
# Each entry's `vm` is either a key of var.virtual_machines (resolved to the
# module-created VM's ext_id) or a literal VM ext_id of a pre-existing VM.
variable "ngt_installations" {
  description = "A map of declarative Nutanix Guest Tools installations (nutanix_ngt_installation_v2). DECLARATIVE/steady-state: is_enabled and capabilities reconcile on every apply. Each entry's `vm` is a virtual_machines map key or a VM ext_id. Guest credentials are supplied out-of-band via the sensitive var.ngt_installation_credentials, never in YAML."
  type = map(object({
    vm = string # key of virtual_machines (resolved to ext_id) or a VM ext_id
    # NGT capabilities to enable. Allowed: SELF_SERVICE_RESTORE, VSS_SNAPSHOT.
    capabilities = optional(list(string), [])
    is_enabled   = optional(bool, null)
    # Restart schedule applied after installing NGT (schedule_type is one of
    # IMMEDIATE | LATER | SKIP; start_time is used with LATER).
    reboot_preference = optional(object({
      schedule_type = string
      start_time    = optional(string, null)
    }), null)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.ngt_installations :
      v.vm != null && v.vm != ""
    ])
    error_message = "Each ngt_installations entry must set 'vm' (a virtual_machines map key or a VM ext_id)."
  }

  validation {
    condition = alltrue([
      for k, v in var.ngt_installations :
      alltrue([for c in v.capabilities : contains(["SELF_SERVICE_RESTORE", "VSS_SNAPSHOT"], c)])
    ])
    error_message = "ngt_installations capabilities must be a subset of: SELF_SERVICE_RESTORE, VSS_SNAPSHOT."
  }

  validation {
    condition = alltrue([
      for k, v in var.ngt_installations :
      v.reboot_preference == null || contains(["IMMEDIATE", "LATER", "SKIP"], v.reboot_preference.schedule_type)
    ])
    error_message = "ngt_installations reboot_preference.schedule_type must be one of: IMMEDIATE, LATER, SKIP."
  }
}

# Guest OS credentials for NGT installation, keyed by the SAME key as
# var.ngt_installations. Kept in a dedicated, sensitive variable so guest
# passwords never appear in landing-zone YAML or in the ngt_installations map
# (they are injected from a secret store at plan/apply time). An entry is
# optional: NGT installation can proceed without a credential when the provider
# does not require one for the target VM.
variable "ngt_installation_credentials" {
  description = "Sensitive guest OS credentials for NGT installation, keyed by the same key as ngt_installations. Supplied from a secret store, never from YAML."
  type = map(object({
    username = string
    password = string
  }))
  default   = {}
  sensitive = true
}

##################################################
# VM day-2 ACTIONS (v2, provider 2.4.2) -- IMPERATIVE, one-shot
##################################################

# vm_actions groups the nine imperative VM day-2 action resources into per-action
# sub-maps. READ THE ACTION LIFECYCLE CAVEATS BEFORE USE (see also the module
# README section "Action resources -- read before use"):
#
#   1. Creating an entry EXECUTES the action ONCE; there is NO continuous
#      reconciliation afterwards (unlike ngt_installations above).
#   2. Re-executing an action requires a NEW/renamed map key (or a taint).
#      Convention: operators trigger an action by ADDING a map entry; entries are
#      append-only history -- prune old entries only with `state rm` awareness.
#   3. Destroy does NOT undo the action: a clone is not deleted, a shut-down VM is
#      not restarted, a reverted VM is not un-reverted.
#   4. A populated map replans cleanly only because each resource stores its
#      action result in state. NEVER wire these into always-applied YAML defaults
#      -- every sub-map defaults to {} and must be explicitly operator-triggered.
#   5. cdrom workaround: on the pinned stable provider 2.4.2, ISO eject can fail
#      when the CD-ROM ext_id is null (fixed only in the banned 2.4.3-beta). Always
#      set cdrom_operations[*].cdrom_ext_id explicitly for eject operations.
#
# Every entry's `vm` is a key of var.virtual_machines (resolved to the
# module-created VM's ext_id) or a literal VM ext_id passthrough.
variable "vm_actions" {
  description = <<-EOT
    Grouped, IMPERATIVE VM day-2 actions (one sub-map per action type). ONE-SHOT semantics:
    creating an entry runs the action ONCE with NO reconciliation; re-trigger by adding a
    NEW map key (append-only history), and destroy does NOT undo the action. Every sub-map
    defaults to {} -- NEVER populate these from shared YAML defaults; they must be explicitly
    operator-triggered per environment. Each entry's `vm` is a virtual_machines map key or a
    VM ext_id. cdrom_operations eject: always set cdrom_ext_id explicitly (provider 2.4.2 ISO
    eject fails on a null CD-ROM ext_id; the fix only exists in the banned 2.4.3-beta).
  EOT
  type = object({
    # Clone a VM (nutanix_vm_clone_v2). `vm` is the SOURCE VM; the optional fields
    # override the clone. The new VM's ext_id is surfaced in output.vm_actions.
    clones = optional(map(object({
      vm                   = string
      name                 = optional(string, null)
      memory_size_mib      = optional(number, null)
      num_sockets          = optional(number, null)
      num_cores_per_socket = optional(number, null)
      num_threads_per_core = optional(number, null)
    })), {})

    # Update guest customization for the next boot (nutanix_vm_gc_update_v2).
    gc_updates = optional(map(object({
      vm                         = string
      cloud_init_user_data       = optional(string, null)
      cloud_init_metadata        = optional(string, null)
      cloud_init_datasource_type = optional(string, null)
      sysprep_install_type       = optional(string, null)
      sysprep_unattend_xml       = optional(string, null)
    })), {})

    # Assign an IP to a NIC (nutanix_vm_network_device_assign_ip_v2). nic_ext_id
    # is the NIC's runtime-assigned ext_id (see output.virtual_machine_nic_list).
    nic_ip_assignments = optional(map(object({
      vm            = string
      nic_ext_id    = string
      ip_address    = optional(string, null)
      prefix_length = optional(number, null)
    })), {})

    # Migrate a NIC between subnets (nutanix_vm_network_device_migrate_v2).
    # migrate_type is ASSIGN_IP or RELEASE_IP.
    nic_migrations = optional(map(object({
      vm            = string
      nic_ext_id    = string
      migrate_type  = string
      subnet_ext_id = optional(string, null)
      ip_address    = optional(string, null)
      prefix_length = optional(number, null)
    })), {})

    # Insert/eject an ISO on a CD-ROM (nutanix_vm_cdrom_insert_eject_v2). action
    # is insert|eject. cdrom_ext_id is the CD-ROM device ext_id and is REQUIRED --
    # ALWAYS set it explicitly for eject (2.4.2 null-ext_id eject bug). For insert,
    # set image_ext_id (and disk_size_bytes for the backing CD-ROM).
    cdrom_operations = optional(map(object({
      vm              = string
      cdrom_ext_id    = string
      action          = optional(string, null)
      image_ext_id    = optional(string, null)
      disk_size_bytes = optional(number, null)
    })), {})

    # Guest shutdown/reboot via NGT (nutanix_vm_shutdown_action_v2). action is
    # shutdown|guest_shutdown|reboot|guest_reboot. The script-exec flags apply
    # only to guest_shutdown/guest_reboot.
    shutdowns = optional(map(object({
      vm                            = string
      action                        = string
      should_enable_script_exec     = optional(bool, null)
      should_fail_on_script_failure = optional(bool, null)
    })), {})

    # Revert a VM to a recovery point (nutanix_vm_revert_v2). recovery_point_ext_id
    # is the VM recovery point external ID (see the nutanix_recovery_points_v2 data
    # source to look one up).
    reverts = optional(map(object({
      vm                    = string
      recovery_point_ext_id = string
    })), {})

    # Insert the NGT ISO (nutanix_ngt_insert_iso_v2). action is insert|eject;
    # capabilities is a subset of SELF_SERVICE_RESTORE, VSS_SNAPSHOT;
    # is_config_only updates existing NGT config instead of a fresh install.
    ngt_iso_inserts = optional(map(object({
      vm             = string
      action         = optional(string, null)
      capabilities   = optional(list(string), [])
      is_config_only = optional(bool, null)
    })), {})

    # Upgrade NGT (nutanix_ngt_upgrade_v2). reboot_preference.schedule_type is
    # IMMEDIATE|LATER|SKIP (start_time used with LATER).
    ngt_upgrades = optional(map(object({
      vm = string
      reboot_preference = optional(object({
        schedule_type = string
        start_time    = optional(string, null)
      }), null)
    })), {})
  })
  default = {}

  # Every action entry must name a VM.
  validation {
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
    error_message = "Every vm_actions entry (across all sub-maps) must set a non-empty 'vm' (a virtual_machines map key or a VM ext_id)."
  }

  # Shutdown action must be a recognised guest power-state transition.
  validation {
    condition = alltrue([
      for k, v in var.vm_actions.shutdowns :
      contains(["shutdown", "guest_shutdown", "reboot", "guest_reboot"], v.action)
    ])
    error_message = "vm_actions.shutdowns 'action' must be one of: shutdown, guest_shutdown, reboot, guest_reboot."
  }

  # NIC migration type must be ASSIGN_IP or RELEASE_IP.
  validation {
    condition = alltrue([
      for k, v in var.vm_actions.nic_migrations :
      contains(["ASSIGN_IP", "RELEASE_IP"], v.migrate_type)
    ])
    error_message = "vm_actions.nic_migrations 'migrate_type' must be one of: ASSIGN_IP, RELEASE_IP."
  }

  # CD-ROM operation action, when set, must be insert or eject.
  validation {
    condition = alltrue([
      for k, v in var.vm_actions.cdrom_operations :
      v.action == null || contains(["insert", "eject"], v.action)
    ])
    error_message = "vm_actions.cdrom_operations 'action' must be one of: insert, eject."
  }

  # Every CD-ROM operation must name the CD-ROM device ext_id (mandatory in 2.4.2,
  # and the eject-bug workaround for a null CD-ROM ext_id).
  validation {
    condition = alltrue([
      for k, v in var.vm_actions.cdrom_operations :
      v.cdrom_ext_id != null && v.cdrom_ext_id != ""
    ])
    error_message = "Each vm_actions.cdrom_operations entry must set cdrom_ext_id explicitly (required by 2.4.2 and the ISO-eject null-ext_id workaround)."
  }

  # NGT ISO insert action, when set, must be insert or eject; capabilities subset.
  validation {
    condition = alltrue([
      for k, v in var.vm_actions.ngt_iso_inserts :
      (v.action == null || contains(["insert", "eject"], v.action)) &&
      alltrue([for c in v.capabilities : contains(["SELF_SERVICE_RESTORE", "VSS_SNAPSHOT"], c)])
    ])
    error_message = "vm_actions.ngt_iso_inserts 'action' must be insert|eject and capabilities a subset of SELF_SERVICE_RESTORE, VSS_SNAPSHOT."
  }

  # NGT upgrade reboot schedule_type, when set, must be a recognised value.
  validation {
    condition = alltrue([
      for k, v in var.vm_actions.ngt_upgrades :
      v.reboot_preference == null || contains(["IMMEDIATE", "LATER", "SKIP"], v.reboot_preference.schedule_type)
    ])
    error_message = "vm_actions.ngt_upgrades reboot_preference.schedule_type must be one of: IMMEDIATE, LATER, SKIP."
  }

  # Every revert must name a recovery point.
  validation {
    condition = alltrue([
      for k, v in var.vm_actions.reverts :
      v.recovery_point_ext_id != null && v.recovery_point_ext_id != ""
    ])
    error_message = "Each vm_actions.reverts entry must set recovery_point_ext_id (the VM recovery point external ID)."
  }
}
