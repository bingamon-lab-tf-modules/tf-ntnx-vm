# tf-ntnx-vm

## Table of Contents

## Overview

Manages Nutanix compute: disk/ISO images (`nutanix_images_v2`) and virtual
machines (`nutanix_virtual_machine_v2`). The VM resource targets the v4 AHV
config API.

## Migration notes (v1 -> v2)

The VM resource was migrated from the legacy `nutanix_virtual_machine` (v0.8/v1
API) to `nutanix_virtual_machine_v2` (v4 API) ahead of the Q4-CY2026 provider
deprecation of all legacy resources. This is a resource-type replacement, not an
in-place upgrade: there is no known real state referencing
`nutanix_virtual_machine.vm`. `nutanix_images_v2.image` was already v2 and is
unchanged.

### Previously shelved features, now implemented on v2 (2.4.2)

All eight features that were commented out on the v1 resource as "unsupported in
nutanix provider v2.3.1" now have v2 equivalents and are implemented:

| v1 feature | v2 (`nutanix_virtual_machine_v2`) location |
|---|---|
| `num_threads_per_core` | top-level `num_threads_per_core` attribute |
| `boot_device_disk_address` | `boot_config` -> `legacy_boot`/`uefi_boot` -> `boot_device` -> `boot_device_disk` -> `disk_address { bus_type, index }` (module input `boot_device_disk_address`) |
| `network_function_chain_reference` | `nics` -> `network_info` -> `network_function_chain { ext_id }` (module input `nics[].network_function_chain_ext_id`) |
| disk `disk_address` | `disks` -> `disk_address { bus_type, index }` (module input `disks[].bus_type` / `disks[].index`) |
| disk `data_source_reference` | `disks` -> `backing_info` -> `vm_disk` -> `data_source` -> `reference` -> `image_reference`/`vm_disk_reference` (module input `disks[].image_ext_id` / `disks[].source_vm_disk_ext_id`) |
| `guest_customization_sysprep` block | `guest_customization` -> `config` -> `sysprep { install_type, sysprep_script { unattend_xml } }` (module input `guest_customization_sysprep`) |
| `project_reference` block | `project { ext_id }` (module input `project_ext_id`) |
| `owner_reference` block | `ownership_info` -> `owner { ext_id }` (module input `owner_ext_id`) |

### Field renames

- `cluster_uuid` -> `cluster_ext_id` (v2 `cluster { ext_id }`).
- `num_vcpus_per_socket` -> `num_cores_per_socket`.
- `num_vnuma_nodes` -> `num_numa_nodes`.
- `vga_console_enabled` -> `is_vga_console_enabled`.
- `enable_cpu_passthrough` -> `is_cpu_passthrough_enabled`.
- `is_vcpu_hard_pinned` -> `is_vcpu_hard_pinning_enabled`.
- `categories` (name/value pairs) -> `category_ext_ids` (list of category external IDs).
- `nic_list` -> `nics`; `subnet_uuid` -> `subnet_ext_id`; `ip_endpoint_list` -> `nics[].ipv4`.
- `disk_list` -> `disks`; `boot_device_order_list` -> `boot_order`.
- `memory_size_mib` is retained as the module input and converted to the v2
  `memory_size_bytes` attribute.

### v1 fields with no v2 equivalent (descoped)

These v1 inputs have no counterpart in the 2.4.2 `virtual_machine_v2` schema and
were dropped:

- `guest_os_id` - the v4 API detects the guest OS via guest tools; there is no
  settable guest OS id.
- `use_hot_add` - no direct equivalent; the v4 update flow handles CPU/memory
  hot-add automatically. The v2-native `is_cpu_hotplug_enabled` flag is exposed
  instead.
- `guest_customization_is_overridable` - not present in the v2
  `guest_customization` block.
- `guest_customization_cloud_init_custom_key_values` and
  `guest_customization_sysprep_custom_key_values` - v2 restructures these into a
  deeply nested `custom_key_values { key_value_pairs { value { ... } } }` block;
  not exposed by this module (no current consumer). Add on demand.
- NIC `subnet_name` - v2 references subnets by external ID (`subnet_ext_id`) only.
- disk `device_properties.device_type` - v2 separates disks (`disks`) from
  CD-ROMs (`cd_roms`); attach ISOs via `cd_roms`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_nutanix"></a> [nutanix](#requirement\_nutanix) | >= 2.4.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_nutanix"></a> [nutanix](#provider\_nutanix) | 2.4.2 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [nutanix_deploy_templates_v2.template_deployment](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/deploy_templates_v2) | resource |
| [nutanix_images_v2.image](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/images_v2) | resource |
| [nutanix_ngt_insert_iso_v2.ngt_iso_insert](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/ngt_insert_iso_v2) | resource |
| [nutanix_ngt_installation_v2.ngt_installation](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/ngt_installation_v2) | resource |
| [nutanix_ngt_upgrade_v2.ngt_upgrade](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/ngt_upgrade_v2) | resource |
| [nutanix_ova_download_v2.ova_download](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/ova_download_v2) | resource |
| [nutanix_ova_v2.ova](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/ova_v2) | resource |
| [nutanix_ova_vm_deploy_v2.ova_deployment](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/ova_vm_deploy_v2) | resource |
| [nutanix_template_guest_os_actions_v2.template_guest_os_action](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/template_guest_os_actions_v2) | resource |
| [nutanix_template_v2.template](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/template_v2) | resource |
| [nutanix_virtual_machine_v2.vm](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/virtual_machine_v2) | resource |
| [nutanix_vm_anti_affinity_policy_v2.anti_affinity_policy](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/vm_anti_affinity_policy_v2) | resource |
| [nutanix_vm_cdrom_insert_eject_v2.cdrom_operation](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/vm_cdrom_insert_eject_v2) | resource |
| [nutanix_vm_clone_v2.clone](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/vm_clone_v2) | resource |
| [nutanix_vm_gc_update_v2.gc_update](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/vm_gc_update_v2) | resource |
| [nutanix_vm_host_affinity_policy_v2.host_affinity_policy](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/vm_host_affinity_policy_v2) | resource |
| [nutanix_vm_network_device_assign_ip_v2.nic_ip_assignment](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/vm_network_device_assign_ip_v2) | resource |
| [nutanix_vm_network_device_migrate_v2.nic_migration](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/vm_network_device_migrate_v2) | resource |
| [nutanix_vm_revert_v2.revert](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/vm_revert_v2) | resource |
| [nutanix_vm_shutdown_action_v2.shutdown](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/vm_shutdown_action_v2) | resource |
| [terraform_data.cloud_init](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.image_source](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [nutanix_categories_v2.category](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/categories_v2) | data source |
| [nutanix_clusters_v2.existing_cluster](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/clusters_v2) | data source |
| [nutanix_images_v2.existing_image](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/images_v2) | data source |
| [nutanix_ngt_configuration_v2.ngt_configuration](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/ngt_configuration_v2) | data source |
| [nutanix_ovas_v2.existing_ova](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/ovas_v2) | data source |
| [nutanix_templates_v2.existing_template](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/templates_v2) | data source |
| [nutanix_virtual_machines_v2.existing_vm](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/virtual_machines_v2) | data source |
| [nutanix_vm_anti_affinity_policies_v2.anti_affinity_policy](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/vm_anti_affinity_policies_v2) | data source |
| [nutanix_vm_host_affinity_policies_v2.host_affinity_policy](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/vm_host_affinity_policies_v2) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_category_ids"></a> [category\_ids](#input\_category\_ids) | Map of category key => ext\_id, from the security\_governance landing zone's category\_ids output. Referenced by 'category\_keys' on VMs, images and OVA deployments. | `map(string)` | `{}` | no |
| <a name="input_enable_data_lookups"></a> [enable\_data\_lookups](#input\_enable\_data\_lookups) | Enable read-only lookups of existing Prism Central inventory (clusters, images, VMs, categories, affinity policies). | `bool` | `false` | no |
| <a name="input_images"></a> [images](#input\_images) | A map of images to manage in Nutanix. | <pre>map(object({<br/>    name        = string<br/>    description = optional(string, null)<br/>    type        = string # DISK_IMAGE, ISO_IMAGE<br/><br/>    source = optional(object({<br/>      url_source = optional(object({<br/>        url                       = string<br/>        should_allow_insecure_url = optional(bool, false)<br/>        basic_auth = optional(object({<br/>          username = string<br/>          password = string<br/>        }), null)<br/>      }), null)<br/>      vm_disk_source = optional(object({<br/>        ext_id = string<br/>      }), null)<br/>      object_lite_source = optional(object({<br/>        key = string<br/>      }), null)<br/>    }), null)<br/><br/>    checksum = optional(object({<br/>      hex_digest  = string<br/>      object_type = optional(string, null)<br/>    }), null)<br/><br/>    category_ext_ids         = optional(list(string), [])<br/>    cluster_location_ext_ids = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_ngt_installation_credentials"></a> [ngt\_installation\_credentials](#input\_ngt\_installation\_credentials) | Sensitive guest OS credentials for NGT installation, keyed by the same key as ngt\_installations. Supplied from a secret store, never from YAML. | <pre>map(object({<br/>    username = string<br/>    password = string<br/>  }))</pre> | `{}` | no |
| <a name="input_ngt_installations"></a> [ngt\_installations](#input\_ngt\_installations) | A map of declarative Nutanix Guest Tools installations (nutanix\_ngt\_installation\_v2). DECLARATIVE/steady-state: is\_enabled and capabilities reconcile on every apply. Each entry's `vm` is a virtual\_machines map key or a VM ext\_id. Guest credentials are supplied out-of-band via the sensitive var.ngt\_installation\_credentials, never in YAML. | <pre>map(object({<br/>    vm = string # key of virtual_machines (resolved to ext_id) or a VM ext_id<br/>    # NGT capabilities to enable. Allowed: SELF_SERVICE_RESTORE, VSS_SNAPSHOT.<br/>    capabilities = optional(list(string), [])<br/>    is_enabled   = optional(bool, null)<br/>    # Restart schedule applied after installing NGT (schedule_type is one of<br/>    # IMMEDIATE | LATER | SKIP; start_time is used with LATER).<br/>    reboot_preference = optional(object({<br/>      schedule_type = string<br/>      start_time    = optional(string, null)<br/>    }), null)<br/>  }))</pre> | `{}` | no |
| <a name="input_ova_deployments"></a> [ova\_deployments](#input\_ova\_deployments) | A map of VM deployments from OVAs (nutanix\_ova\_vm\_deploy\_v2). The deployed VM is a provider-side artifact, NOT tracked as a virtual\_machine resource here. Provider 2.4.2 supports in-place UPDATE of override\_vm\_config. Each entry requires at least one NIC (subnet). | <pre>map(object({<br/>    # OVA to deploy from: a key of var.ovas (resolved to the module-created OVA's<br/>    # ext_id) or a literal ext_id of a pre-existing OVA.<br/>    ova = string<br/>    # Cluster to deploy into: a cluster name (resolved to ext_id when<br/>    # enable_data_lookups = true) or a literal cluster ext_id.<br/>    cluster = string<br/><br/>    # override_vm_config: applied to the deployed VM (provider requires this<br/>    # block; UPDATE-capable in 2.4.2).<br/>    name                 = optional(string, null)<br/>    memory_size_mib      = optional(number, null) # converted to memory_size_bytes<br/>    num_sockets          = optional(number, null)<br/>    num_cores_per_socket = optional(number, null)<br/>    num_threads_per_core = optional(number, null)<br/>    power_state          = optional(string, null) # ON | OFF<br/>    # Same backup-tier mechanism as a VM. The deployed VM is untracked by<br/>    # OpenTofu, but Prism Central evaluates protection policies against<br/>    # CATEGORIES, not against state — so a tagged OVA deployment is still<br/>    # protected. This is the case category-driven backup exists for.<br/>    category_keys    = optional(list(string), [])<br/>    category_ext_ids = optional(list(string), [])<br/><br/>    # At least one NIC is required by the provider. Subnet is referenced by<br/>    # external ID.<br/>    nics = list(object({<br/>      subnet_name   = optional(string, null)<br/>      subnet_ext_id = optional(string, null)<br/>      nic_type      = optional(string, null)<br/>      vlan_mode     = optional(string, null)<br/>      is_connected  = optional(bool, null)<br/>      model         = optional(string, null)<br/>      mac_address   = optional(string, null)<br/>      ipv4 = optional(object({<br/>        should_assign_ip = optional(bool, null)<br/>        ip_address = optional(object({<br/>          value         = string<br/>          prefix_length = optional(number, null)<br/>        }), null)<br/>      }), null)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_ova_downloads"></a> [ova\_downloads](#input\_ova\_downloads) | A map of one-shot OVA export/download actions (nutanix\_ova\_download\_v2). IMPERATIVE: each entry exports the referenced OVA once; re-exporting needs a NEW map key. Keep empty ({}) unless actively exporting an OVA. | <pre>map(object({<br/>    # OVA to export: a key of var.ovas (resolved to the module-created OVA's<br/>    # ext_id) or a literal ext_id of a pre-existing OVA.<br/>    ova = string<br/>  }))</pre> | `{}` | no |
| <a name="input_ovas"></a> [ovas](#input\_ovas) | A map of OVA appliance images to manage in Nutanix (nutanix\_ova\_v2). Each OVA is imported once from a URL, an object-store key, or an existing VM. OVAs are a separate family from images\_v2 (appliance bundles, not standalone disk/ISO images). | <pre>map(object({<br/>    name = string<br/>    # Disk format the OVA is stored in (e.g. QCOW2, VMDK). Provider-validated.<br/>    disk_format = optional(string, null)<br/>    # Clusters the OVA is placed on, by external ID.<br/>    cluster_location_ext_ids = optional(list(string), [])<br/><br/>    # Optional integrity checksum. Set sha1 and/or sha256 hex digests; each maps<br/>    # to the provider's ova_sha1_checksum / ova_sha256_checksum block.<br/>    checksum = optional(object({<br/>      sha1   = optional(string, null)<br/>      sha256 = optional(string, null)<br/>    }), null)<br/><br/>    # Exactly one source variant must be set (validated below):<br/>    #   url_source         -- import from a URL (optional basic auth).<br/>    #   object_lite_source -- import from an object-store key.<br/>    #   vm_source          -- capture an existing VM (by ext_id) into an OVA.<br/>    source = object({<br/>      url_source = optional(object({<br/>        url                       = string<br/>        should_allow_insecure_url = optional(bool, false)<br/>        basic_auth = optional(object({<br/>          username = string<br/>          password = string<br/>        }), null)<br/>      }), null)<br/>      object_lite_source = optional(object({<br/>        key = string<br/>      }), null)<br/>      vm_source = optional(object({<br/>        vm_ext_id        = string<br/>        disk_file_format = string # e.g. QCOW2, VMDK<br/>      }), null)<br/>    })<br/>  }))</pre> | `{}` | no |
| <a name="input_storage_container_ids"></a> [storage\_container\_ids](#input\_storage\_container\_ids) | Map of storage container key => ext\_id, supplied by the caller from the storage landing zone's storage\_container\_ids output. Referenced by a VM disk's 'storage\_container\_key'. Empty when the storage landing zone is disabled, in which case disks must use storage\_container\_ext\_id or omit placement entirely. | `map(string)` | `{}` | no |
| <a name="input_subnet_names"></a> [subnet\_names](#input\_subnet\_names) | Map of subnet NAME => ext\_id, from the network\_topology landing zone. Referenced by a NIC's 'subnet\_name'. Names must be unique across the environment; the caller is responsible for rejecting duplicates before they reach here. | `map(string)` | `{}` | no |
| <a name="input_template_deployments"></a> [template\_deployments](#input\_template\_deployments) | A map of one-shot template deployments (nutanix\_deploy\_templates\_v2). IMPERATIVE: each entry deploys number\_of\_vms VMs once; the deployed VMs are provider-side artifacts, NOT tracked as VM resources. Re-deploy needs a new key; destroy does not necessarily remove the deployed VMs. | <pre>map(object({<br/>    # Template to deploy: a key of var.templates (resolved to the module-created<br/>    # template's ext_id) or a literal ext_id of a pre-existing template.<br/>    template = string<br/>    # Cluster to deploy into: a cluster name (resolved to ext_id when<br/>    # enable_data_lookups = true) or a literal cluster ext_id.<br/>    cluster       = string<br/>    number_of_vms = number<br/>    # Optional specific template version to deploy (defaults to the active one).<br/>    version_id = optional(string, null)<br/>    # Optional per-VM overrides applied to the deployed VMs.<br/>    override_vm_configs = optional(list(object({<br/>      name                 = optional(string, null)<br/>      memory_size_mib      = optional(number, null)<br/>      num_sockets          = optional(number, null)<br/>      num_cores_per_socket = optional(number, null)<br/>      num_threads_per_core = optional(number, null)<br/>    })), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_template_guest_os_actions"></a> [template\_guest\_os\_actions](#input\_template\_guest\_os\_actions) | A map of operator-triggered guest-OS update actions on template versions (nutanix\_template\_guest\_os\_actions\_v2). One-shot state machine (initiate/complete/cancel), NOT steady-state config -- keep empty ({}) unless actively updating a template's guest OS. | <pre>map(object({<br/>    # Template whose version the action targets: a key of var.templates (resolved<br/>    # to the module-created template's ext_id) or a literal template ext_id.<br/>    template = string<br/>    action   = string # initiate | complete | cancel<br/>    # version_id is required for `initiate` (which version to update).<br/>    version_id = optional(string, null)<br/>    # version_name and version_description are required for `complete`.<br/>    version_name        = optional(string, null)<br/>    version_description = optional(string, null)<br/>    # Mark the resulting version active on `complete` (provider default true).<br/>    # The provider types this field as a string ("true"/"false") on this resource.<br/>    is_active_version = optional(string, null)<br/>  }))</pre> | `{}` | no |
| <a name="input_templates"></a> [templates](#input\_templates) | A map of versioned VM templates to manage in Nutanix (nutanix\_template\_v2). Each template captures a source VM (referenced by external ID) into its initial, active version. | <pre>map(object({<br/>    name             = string<br/>    description      = optional(string, null)<br/>    category_ext_ids = optional(list(string), [])<br/><br/>    # Source VM external ID captured into the template's initial version via<br/>    # template_version_spec.version_source.template_vm_reference.ext_id. The<br/>    # source VM is referenced by ext_id, so templates do not depend on how the<br/>    # VM itself is managed (the v1 -> v2 VM migration is a separate epic).<br/>    source_vm_ext_id = string<br/><br/>    # Initial version metadata.<br/>    version_name           = optional(string, null)<br/>    version_description    = optional(string, null)<br/>    is_active_version      = optional(bool, null) # provider default: true<br/>    is_gc_override_enabled = optional(bool, null) # allow guest-customization override at deploy time<br/>  }))</pre> | `{}` | no |
| <a name="input_virtual_machines"></a> [virtual\_machines](#input\_virtual\_machines) | A map of virtual machines to manage in Nutanix (nutanix\_virtual\_machine\_v2). | <pre>map(object({<br/>    name        = string<br/>    description = optional(string, null)<br/><br/>    # Placement: v2 references the cluster by its external ID (was cluster_uuid).<br/>    cluster_ext_id = string<br/><br/>    # Compute sizing.<br/>    num_sockets          = optional(number, 1)<br/>    num_cores_per_socket = optional(number, 1)    # was num_vcpus_per_socket<br/>    num_threads_per_core = optional(number, null) # now supported (v1 TODO)<br/>    num_numa_nodes       = optional(number, null) # was num_vnuma_nodes<br/>    memory_size_mib      = optional(number, 2048) # converted to memory_size_bytes<br/><br/>    # Lifecycle and hardware flags.<br/>    power_state                  = optional(string, "ON")<br/>    machine_type                 = optional(string, null)<br/>    hardware_clock_timezone      = optional(string, null)<br/>    is_vga_console_enabled       = optional(bool, null) # was vga_console_enabled<br/>    is_cpu_passthrough_enabled   = optional(bool, null) # was enable_cpu_passthrough<br/>    is_vcpu_hard_pinning_enabled = optional(bool, null) # was is_vcpu_hard_pinned<br/>    is_cpu_hotplug_enabled       = optional(bool, null) # v2-native (see migration notes re: use_hot_add)<br/>    is_memory_overcommit_enabled = optional(bool, null)<br/><br/>    # Categories: v2 associates categories by external ID (was name/value pairs).<br/>    # Categories applied to the VM. 'category_keys' names them from the<br/>    # security_governance landing zone and is resolved to ext_ids; this is how<br/>    # a VM declares its BACKUP TIER (backup-gold / backup-silver /<br/>    # backup-bronze / backup-none). A protection policy targets the category,<br/>    # so tagging is the whole mechanism by which a VM gets backed up.<br/>    category_keys    = optional(list(string), [])<br/>    category_ext_ids = optional(list(string), [])<br/><br/>    # Boot configuration. boot_type selects legacy_boot vs uefi_boot; SECURE_BOOT<br/>    # maps to uefi_boot with is_secure_boot_enabled = true.<br/>    boot_type  = optional(string, "UEFI")        # UEFI | LEGACY | SECURE_BOOT<br/>    boot_order = optional(list(string), [])      # e.g. ["DISK", "CDROM", "NETWORK"]<br/>    boot_device_disk_address = optional(object({ # now supported (v1 TODO)<br/>      bus_type = optional(string, "SCSI")<br/>      index    = optional(number, 0)<br/>    }), null)<br/>    boot_device_mac_address = optional(string, null) # boot from a specific NIC<br/><br/>    # NICs. Subnet is referenced by external ID (was subnet_uuid/subnet_name).<br/>    nics = optional(list(object({<br/>      # Supply EXACTLY ONE of subnet_name / subnet_ext_id.<br/>      #   subnet_name    -- the subnet's Prism display name, resolved via<br/>      #     var.subnet_names. This is the readable form and the one that gives<br/>      #     OpenTofu a dependency on the subnet existing first.<br/>      #   subnet_ext_id  -- a literal UUID. Escape hatch for a subnet this<br/>      #     landing zone does not manage.<br/>      subnet_name               = optional(string, null)<br/>      subnet_ext_id             = optional(string, null)<br/>      nic_type                  = optional(string, "NORMAL_NIC")<br/>      network_function_nic_type = optional(string, null)<br/>      vlan_mode                 = optional(string, null)<br/>      is_connected              = optional(bool, true)<br/>      model                     = optional(string, null)<br/>      mac_address               = optional(string, null)<br/>      num_queues                = optional(number, null)<br/>      # now supported (v1 TODO): network function chain by external ID.<br/>      network_function_chain_ext_id = optional(string, null)<br/>      ipv4 = optional(object({<br/>        should_assign_ip = optional(bool, null)<br/>        ip_address = optional(object({<br/>          value         = string<br/>          prefix_length = optional(number, null)<br/>        }), null)<br/>        secondary_ip_addresses = optional(list(object({<br/>          value         = string<br/>          prefix_length = optional(number, null)<br/>        })), [])<br/>      }), null)<br/>    })), [])<br/><br/>    # Data disks. Provide disk_size_bytes or disk_size_mib for blank disks, or an<br/>    # image_ext_id / source_vm_disk_ext_id to clone from an existing source.<br/>    disks = optional(list(object({<br/>      disk_size_bytes = optional(number, null)<br/>      disk_size_mib   = optional(number, null)<br/>      # now supported (v1 TODO): disk address bus_type/index.<br/>      bus_type = optional(string, "SCSI")<br/>      index    = optional(number, null)<br/>      # now supported (v1 TODO): clone source via data_source reference.<br/>      # Boot/data source. Supply AT MOST ONE of image_key / image_ext_id.<br/>      #   image_key    -- key into var.images, resolved to that image's ext_id<br/>      #     after it is created. PREFERRED: it is the only form that gives<br/>      #     OpenTofu a dependency edge, so the image is guaranteed to exist<br/>      #     before the VM that boots from it, in a SINGLE apply.<br/>      #   image_ext_id -- a literal image ext_id. Escape hatch for an image<br/>      #     this module does not manage.<br/>      image_key             = optional(string, null)<br/>      image_ext_id          = optional(string, null)<br/>      source_vm_disk_ext_id = optional(string, null)<br/><br/>      # Where the disk physically lands. Supply AT MOST ONE of<br/>      # storage_container_key / storage_container_ext_id; omit both to let<br/>      # Nutanix choose (usually default-container-*).<br/>      #   storage_container_key -- key into var.storage_container_ids, which the<br/>      #     caller populates from the storage landing zone's<br/>      #     storage_container_ids output. Keys are the storage module's own, so<br/>      #     for a Prism Element plane container that is the flattened<br/>      #     "<cluster>_<container>" form.<br/>      storage_container_key    = optional(string, null)<br/>      storage_container_ext_id = optional(string, null)<br/>      is_flash_mode_enabled    = optional(bool, null)<br/>    })), [])<br/><br/>    # CD-ROMs (attach ISO images).<br/>    cd_roms = optional(list(object({<br/>      iso_type = optional(string, null)<br/>      bus_type = optional(string, "IDE")<br/>      index    = optional(number, null)<br/>      # Same image_key / image_ext_id pair as disks above: image_key resolves<br/>      # against var.images and creates the dependency edge.<br/>      image_key    = optional(string, null)<br/>      image_ext_id = optional(string, null)<br/>    })), [])<br/><br/>    serial_ports = optional(list(object({<br/>      index        = number<br/>      is_connected = optional(bool, true)<br/>    })), [])<br/><br/>    gpus = optional(list(object({<br/>      vendor    = optional(string, null)<br/>      mode      = optional(string, null)<br/>      device_id = optional(number, null)<br/>    })), [])<br/><br/>    # Guest customization: cloud-init (Linux) or sysprep (Windows).<br/>    guest_customization_cloud_init_user_data       = optional(string, null)<br/>    guest_customization_cloud_init_metadata        = optional(string, null)<br/>    guest_customization_cloud_init_datasource_type = optional(string, null)<br/>    # now supported (v1 TODO): sysprep guest customization block.<br/>    guest_customization_sysprep = optional(object({<br/>      install_type = optional(string, "PREPARED")<br/>      unattend_xml = optional(string, null)<br/>    }), null)<br/><br/>    # Project / ownership: now supported (v1 TODOs). v2 replaces the v3<br/>    # project_reference / owner_reference kind+uuid blocks with an external ID.<br/>    project_ext_id = optional(string, null)<br/>    owner_ext_id   = optional(string, null)<br/>  }))</pre> | `{}` | no |
| <a name="input_vm_actions"></a> [vm\_actions](#input\_vm\_actions) | Grouped, IMPERATIVE VM day-2 actions (one sub-map per action type). ONE-SHOT semantics:<br/>creating an entry runs the action ONCE with NO reconciliation; re-trigger by adding a<br/>NEW map key (append-only history), and destroy does NOT undo the action. Every sub-map<br/>defaults to {} -- NEVER populate these from shared YAML defaults; they must be explicitly<br/>operator-triggered per environment. Each entry's `vm` is a virtual\_machines map key or a<br/>VM ext\_id. cdrom\_operations eject: always set cdrom\_ext\_id explicitly (provider 2.4.2 ISO<br/>eject fails on a null CD-ROM ext\_id; the fix only exists in the banned 2.4.3-beta). | <pre>object({<br/>    # Clone a VM (nutanix_vm_clone_v2). `vm` is the SOURCE VM; the optional fields<br/>    # override the clone. The new VM's ext_id is surfaced in output.vm_actions.<br/>    clones = optional(map(object({<br/>      vm                   = string<br/>      name                 = optional(string, null)<br/>      memory_size_mib      = optional(number, null)<br/>      num_sockets          = optional(number, null)<br/>      num_cores_per_socket = optional(number, null)<br/>      num_threads_per_core = optional(number, null)<br/>    })), {})<br/><br/>    # Update guest customization for the next boot (nutanix_vm_gc_update_v2).<br/>    gc_updates = optional(map(object({<br/>      vm                         = string<br/>      cloud_init_user_data       = optional(string, null)<br/>      cloud_init_metadata        = optional(string, null)<br/>      cloud_init_datasource_type = optional(string, null)<br/>      sysprep_install_type       = optional(string, null)<br/>      sysprep_unattend_xml       = optional(string, null)<br/>    })), {})<br/><br/>    # Assign an IP to a NIC (nutanix_vm_network_device_assign_ip_v2). nic_ext_id<br/>    # is the NIC's runtime-assigned ext_id (see output.virtual_machine_nic_list).<br/>    nic_ip_assignments = optional(map(object({<br/>      vm            = string<br/>      nic_ext_id    = string<br/>      ip_address    = optional(string, null)<br/>      prefix_length = optional(number, null)<br/>    })), {})<br/><br/>    # Migrate a NIC between subnets (nutanix_vm_network_device_migrate_v2).<br/>    # migrate_type is ASSIGN_IP or RELEASE_IP.<br/>    nic_migrations = optional(map(object({<br/>      vm            = string<br/>      nic_ext_id    = string<br/>      migrate_type  = string<br/>      subnet_ext_id = optional(string, null)<br/>      ip_address    = optional(string, null)<br/>      prefix_length = optional(number, null)<br/>    })), {})<br/><br/>    # Insert/eject an ISO on a CD-ROM (nutanix_vm_cdrom_insert_eject_v2). action<br/>    # is insert|eject. cdrom_ext_id is the CD-ROM device ext_id and is REQUIRED --<br/>    # ALWAYS set it explicitly for eject (2.4.2 null-ext_id eject bug). For insert,<br/>    # set image_ext_id (and disk_size_bytes for the backing CD-ROM).<br/>    cdrom_operations = optional(map(object({<br/>      vm              = string<br/>      cdrom_ext_id    = string<br/>      action          = optional(string, null)<br/>      image_ext_id    = optional(string, null)<br/>      disk_size_bytes = optional(number, null)<br/>    })), {})<br/><br/>    # Guest shutdown/reboot via NGT (nutanix_vm_shutdown_action_v2). action is<br/>    # shutdown|guest_shutdown|reboot|guest_reboot. The script-exec flags apply<br/>    # only to guest_shutdown/guest_reboot.<br/>    shutdowns = optional(map(object({<br/>      vm                            = string<br/>      action                        = string<br/>      should_enable_script_exec     = optional(bool, null)<br/>      should_fail_on_script_failure = optional(bool, null)<br/>    })), {})<br/><br/>    # Revert a VM to a recovery point (nutanix_vm_revert_v2). recovery_point_ext_id<br/>    # is the VM recovery point external ID (see the nutanix_recovery_points_v2 data<br/>    # source to look one up).<br/>    reverts = optional(map(object({<br/>      vm                    = string<br/>      recovery_point_ext_id = string<br/>    })), {})<br/><br/>    # Insert the NGT ISO (nutanix_ngt_insert_iso_v2). action is insert|eject;<br/>    # capabilities is a subset of SELF_SERVICE_RESTORE, VSS_SNAPSHOT;<br/>    # is_config_only updates existing NGT config instead of a fresh install.<br/>    ngt_iso_inserts = optional(map(object({<br/>      vm             = string<br/>      action         = optional(string, null)<br/>      capabilities   = optional(list(string), [])<br/>      is_config_only = optional(bool, null)<br/>    })), {})<br/><br/>    # Upgrade NGT (nutanix_ngt_upgrade_v2). reboot_preference.schedule_type is<br/>    # IMMEDIATE|LATER|SKIP (start_time used with LATER).<br/>    ngt_upgrades = optional(map(object({<br/>      vm = string<br/>      reboot_preference = optional(object({<br/>        schedule_type = string<br/>        start_time    = optional(string, null)<br/>      }), null)<br/>    })), {})<br/>  })</pre> | `{}` | no |
| <a name="input_vm_anti_affinity_policies"></a> [vm\_anti\_affinity\_policies](#input\_vm\_anti\_affinity\_policies) | A map of VM anti-affinity policies (nutanix\_vm\_anti\_affinity\_policy\_v2) that keep VMs apart via categories. | <pre>map(object({<br/>    name          = string<br/>    description   = optional(string, null)<br/>    vm_categories = list(string) # category external IDs selecting the VMs<br/>  }))</pre> | `{}` | no |
| <a name="input_vm_host_affinity_policies"></a> [vm\_host\_affinity\_policies](#input\_vm\_host\_affinity\_policies) | A map of VM host-affinity policies (nutanix\_vm\_host\_affinity\_policy\_v2) that pin VMs to hosts via categories. | <pre>map(object({<br/>    name            = string<br/>    description     = optional(string, null)<br/>    vm_categories   = list(string) # category external IDs selecting the VMs<br/>    host_categories = list(string) # category external IDs selecting the hosts<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_compute_summary"></a> [compute\_summary](#output\_compute\_summary) | Summary of compute resources managed by this module. |
| <a name="output_existing_cluster_ext_ids"></a> [existing\_cluster\_ext\_ids](#output\_existing\_cluster\_ext\_ids) | Map of existing cluster names to their external IDs (populated when enable\_data\_lookups = true). |
| <a name="output_existing_image_ext_ids"></a> [existing\_image\_ext\_ids](#output\_existing\_image\_ext\_ids) | Map of existing image names to their external IDs (populated when enable\_data\_lookups = true). |
| <a name="output_existing_ova_ext_ids"></a> [existing\_ova\_ext\_ids](#output\_existing\_ova\_ext\_ids) | Map of existing OVA names to their external IDs (populated when enable\_data\_lookups = true). |
| <a name="output_existing_template_ext_ids"></a> [existing\_template\_ext\_ids](#output\_existing\_template\_ext\_ids) | Map of existing template names to their external IDs (populated when enable\_data\_lookups = true). |
| <a name="output_existing_vm_ext_ids"></a> [existing\_vm\_ext\_ids](#output\_existing\_vm\_ext\_ids) | Map of existing virtual machine names to their external IDs (populated when enable\_data\_lookups = true). |
| <a name="output_image_ids"></a> [image\_ids](#output\_image\_ids) | Map of image keys to their external IDs. |
| <a name="output_images"></a> [images](#output\_images) | Map of created images with their details. |
| <a name="output_ngt_configurations"></a> [ngt\_configurations](#output\_ngt\_configurations) | Map of ngt\_installations keys to the NGT configuration reported by Prism Central for each installation's VM (populated when enable\_data\_lookups = true). |
| <a name="output_ngt_installations"></a> [ngt\_installations](#output\_ngt\_installations) | Map of managed NGT installations with the target VM ext\_id and the NGT state reported by the provider. |
| <a name="output_outputs"></a> [outputs](#output\_outputs) | Aggregate of all module outputs (spec §7.6 contract, consumed by the landing zone as module.<x>.outputs). |
| <a name="output_ova_deployments"></a> [ova\_deployments](#output\_ova\_deployments) | Map of OVA VM deployments with their resolved source OVA ext\_id and target cluster. NOTE: the deployed VMs are provider-side artifacts of the deploy action and are not tracked as VM resources here. |
| <a name="output_ova_downloads"></a> [ova\_downloads](#output\_ova\_downloads) | Map of OVA export/download actions with their resolved OVA ext\_id and the exported file path. NOTE: exports are one-shot actions; re-exporting requires a new map key. |
| <a name="output_ova_ids"></a> [ova\_ids](#output\_ova\_ids) | Map of OVA keys to their external IDs. |
| <a name="output_ovas"></a> [ovas](#output\_ovas) | Map of created OVA appliance images with their details. |
| <a name="output_template_deployments"></a> [template\_deployments](#output\_template\_deployments) | Map of template deployments with their resolved template ext\_id, target cluster and VM count. NOTE: the deployed VMs are provider-side artifacts of the one-shot deploy action and are not tracked as VM resources here. |
| <a name="output_template_ids"></a> [template\_ids](#output\_template\_ids) | Map of template keys to their external IDs. |
| <a name="output_templates"></a> [templates](#output\_templates) | Map of created VM templates with their details. |
| <a name="output_virtual_machine_ids"></a> [virtual\_machine\_ids](#output\_virtual\_machine\_ids) | Map of VM keys to their external IDs. |
| <a name="output_virtual_machine_nic_ips"></a> [virtual\_machine\_nic\_ips](#output\_virtual\_machine\_nic\_ips) | Map of virtual machine keys to their learned NIC IP addresses. |
| <a name="output_virtual_machine_nic_list"></a> [virtual\_machine\_nic\_list](#output\_virtual\_machine\_nic\_list) | Map of VM keys to their NIC list (includes backing and network info with assigned IPs). |
| <a name="output_virtual_machines"></a> [virtual\_machines](#output\_virtual\_machines) | Map of created VMs with their details. |
| <a name="output_vm_actions"></a> [vm\_actions](#output\_vm\_actions) | Grouped result metadata for the imperative VM day-2 actions (one-shot; see var.vm\_actions caveats). clones surface the new VM ext\_id; reverts surface the revert status. |
| <a name="output_vm_anti_affinity_policies"></a> [vm\_anti\_affinity\_policies](#output\_vm\_anti\_affinity\_policies) | Map of created VM anti-affinity policies with their details. |
| <a name="output_vm_anti_affinity_policy_ids"></a> [vm\_anti\_affinity\_policy\_ids](#output\_vm\_anti\_affinity\_policy\_ids) | Map of VM anti-affinity policy keys to their external IDs. |
| <a name="output_vm_clone_ids"></a> [vm\_clone\_ids](#output\_vm\_clone\_ids) | Map of vm\_actions.clones keys to the external IDs of the newly cloned VMs (provider-side artifacts, not tracked as VM resources). |
| <a name="output_vm_host_affinity_policies"></a> [vm\_host\_affinity\_policies](#output\_vm\_host\_affinity\_policies) | Map of created VM host-affinity policies with their details. |
| <a name="output_vm_host_affinity_policy_ids"></a> [vm\_host\_affinity\_policy\_ids](#output\_vm\_host\_affinity\_policy\_ids) | Map of VM host-affinity policy keys to their external IDs. |
<!-- END_TF_DOCS -->

## Action resources — read before use

This module manages two families of day-2 capability with **different lifecycle
semantics**. Read this before populating `ngt_installations` or `vm_actions`.

### Declarative: `ngt_installations`

`nutanix_ngt_installation_v2` is a normal, steady-state resource. It installs and
manages Nutanix Guest Tools on a VM and **reconciles** `is_enabled` / capabilities
on every apply, like any other resource. Guest OS credentials are supplied through
the **separate, sensitive** `ngt_installation_credentials` variable (keyed by the
same key) so guest passwords never appear in landing-zone YAML.

### Imperative: `vm_actions` (one-shot actions)

Every sub-map of `vm_actions` (`clones`, `gc_updates`, `nic_ip_assignments`,
`nic_migrations`, `cdrom_operations`, `shutdowns`, `reverts`, `ngt_iso_inserts`,
`ngt_upgrades`) drives a **one-shot action resource**. These do not behave like
ordinary declarative resources:

1. **Creating an entry executes the action once.** There is no continuous
   reconciliation afterwards — the action fires at apply and then the resource
   just holds its recorded result in state.
2. **Re-executing requires a new/renamed `for_each` key** (or a `terraform taint`).
   Convention: operators trigger an action by **adding a map entry**; entries are
   an append-only history. Prune old entries only with `terraform state rm`
   awareness (removing an entry destroys the state record, not the past effect).
3. **Destroy does not undo the action.** A clone is not deleted, a shut-down VM is
   not restarted, a reverted VM is not un-reverted.
4. **Keep them out of shared defaults.** A populated map replans cleanly only
   because each resource stores its action result in state. **Never** wire these
   into always-applied YAML defaults — every sub-map defaults to `{}` and must be
   explicitly operator-triggered per environment.
5. **CD-ROM eject workaround (provider 2.4.2).** On the pinned stable provider,
   ISO eject can fail when the CD-ROM `ext_id` is null (fixed only in the banned
   `2.4.3-beta`). **Always set `cdrom_operations[*].cdrom_ext_id` explicitly** for
   eject operations — the module also enforces this with a variable validation.

**VM references.** Every `ngt_installations` and `vm_actions` entry names its VM
via `vm`, which is either a key of `virtual_machines` (resolved to the
module-created VM's `ext_id`) or a literal VM `ext_id` passthrough. NIC-targeting
actions (`nic_ip_assignments`, `nic_migrations`) additionally take the NIC's
runtime-assigned `nic_ext_id` (see the `virtual_machine_nic_list` output).

**Cloned VMs are not adopted.** The VM produced by a clone is a provider-side
artifact surfaced through `output.vm_clone_ids` / `output.vm_actions`; it is not
modelled as a `nutanix_virtual_machine_v2` resource. Adopting a clone into full
management is a manual `terraform import`, not automatic.
