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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_nutanix"></a> [nutanix](#requirement\_nutanix) | >= 2.4.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_nutanix"></a> [nutanix](#provider\_nutanix) | 2.4.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [nutanix_images_v2.image](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/images_v2) | resource |
| [nutanix_virtual_machine_v2.vm](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/virtual_machine_v2) | resource |
| [nutanix_vm_anti_affinity_policy_v2.anti_affinity_policy](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/vm_anti_affinity_policy_v2) | resource |
| [nutanix_vm_host_affinity_policy_v2.host_affinity_policy](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/vm_host_affinity_policy_v2) | resource |
| [nutanix_categories_v2.category](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/categories_v2) | data source |
| [nutanix_clusters_v2.existing_cluster](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/clusters_v2) | data source |
| [nutanix_images_v2.existing_image](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/images_v2) | data source |
| [nutanix_virtual_machines_v2.existing_vm](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/virtual_machines_v2) | data source |
| [nutanix_vm_anti_affinity_policies_v2.anti_affinity_policy](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/vm_anti_affinity_policies_v2) | data source |
| [nutanix_vm_host_affinity_policies_v2.host_affinity_policy](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/vm_host_affinity_policies_v2) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_data_lookups"></a> [enable\_data\_lookups](#input\_enable\_data\_lookups) | Enable read-only lookups of existing Prism Central inventory (clusters, images, VMs, categories, affinity policies). | `bool` | `false` | no |
| <a name="input_images"></a> [images](#input\_images) | A map of images to manage in Nutanix. | <pre>map(object({<br/>    name        = string<br/>    description = optional(string, null)<br/>    type        = string # DISK_IMAGE, ISO_IMAGE<br/><br/>    source = optional(object({<br/>      url_source = optional(object({<br/>        url                       = string<br/>        should_allow_insecure_url = optional(bool, false)<br/>        basic_auth = optional(object({<br/>          username = string<br/>          password = string<br/>        }), null)<br/>      }), null)<br/>      vm_disk_source = optional(object({<br/>        ext_id = string<br/>      }), null)<br/>      object_lite_source = optional(object({<br/>        key = string<br/>      }), null)<br/>    }), null)<br/><br/>    checksum = optional(object({<br/>      hex_digest  = string<br/>      object_type = optional(string, null)<br/>    }), null)<br/><br/>    category_ext_ids         = optional(list(string), [])<br/>    cluster_location_ext_ids = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_virtual_machines"></a> [virtual\_machines](#input\_virtual\_machines) | A map of virtual machines to manage in Nutanix (nutanix\_virtual\_machine\_v2). | <pre>map(object({<br/>    name        = string<br/>    description = optional(string, null)<br/><br/>    # Placement: v2 references the cluster by its external ID (was cluster_uuid).<br/>    cluster_ext_id = string<br/><br/>    # Compute sizing.<br/>    num_sockets          = optional(number, 1)<br/>    num_cores_per_socket = optional(number, 1)    # was num_vcpus_per_socket<br/>    num_threads_per_core = optional(number, null) # now supported (v1 TODO)<br/>    num_numa_nodes       = optional(number, null) # was num_vnuma_nodes<br/>    memory_size_mib      = optional(number, 2048) # converted to memory_size_bytes<br/><br/>    # Lifecycle and hardware flags.<br/>    power_state                  = optional(string, "ON")<br/>    machine_type                 = optional(string, null)<br/>    hardware_clock_timezone      = optional(string, null)<br/>    is_vga_console_enabled       = optional(bool, null) # was vga_console_enabled<br/>    is_cpu_passthrough_enabled   = optional(bool, null) # was enable_cpu_passthrough<br/>    is_vcpu_hard_pinning_enabled = optional(bool, null) # was is_vcpu_hard_pinned<br/>    is_cpu_hotplug_enabled       = optional(bool, null) # v2-native (see migration notes re: use_hot_add)<br/>    is_memory_overcommit_enabled = optional(bool, null)<br/><br/>    # Categories: v2 associates categories by external ID (was name/value pairs).<br/>    category_ext_ids = optional(list(string), [])<br/><br/>    # Boot configuration. boot_type selects legacy_boot vs uefi_boot; SECURE_BOOT<br/>    # maps to uefi_boot with is_secure_boot_enabled = true.<br/>    boot_type  = optional(string, null)          # UEFI | LEGACY | SECURE_BOOT<br/>    boot_order = optional(list(string), [])      # e.g. ["DISK", "CDROM", "NETWORK"]<br/>    boot_device_disk_address = optional(object({ # now supported (v1 TODO)<br/>      bus_type = optional(string, "SCSI")<br/>      index    = optional(number, 0)<br/>    }), null)<br/>    boot_device_mac_address = optional(string, null) # boot from a specific NIC<br/><br/>    # NICs. Subnet is referenced by external ID (was subnet_uuid/subnet_name).<br/>    nics = optional(list(object({<br/>      subnet_ext_id             = string<br/>      nic_type                  = optional(string, "NORMAL_NIC")<br/>      network_function_nic_type = optional(string, null)<br/>      vlan_mode                 = optional(string, null)<br/>      is_connected              = optional(bool, true)<br/>      model                     = optional(string, null)<br/>      mac_address               = optional(string, null)<br/>      num_queues                = optional(number, null)<br/>      # now supported (v1 TODO): network function chain by external ID.<br/>      network_function_chain_ext_id = optional(string, null)<br/>      ipv4 = optional(object({<br/>        should_assign_ip = optional(bool, null)<br/>        ip_address = optional(object({<br/>          value         = string<br/>          prefix_length = optional(number, null)<br/>        }), null)<br/>        secondary_ip_addresses = optional(list(object({<br/>          value         = string<br/>          prefix_length = optional(number, null)<br/>        })), [])<br/>      }), null)<br/>    })), [])<br/><br/>    # Data disks. Provide disk_size_bytes or disk_size_mib for blank disks, or an<br/>    # image_ext_id / source_vm_disk_ext_id to clone from an existing source.<br/>    disks = optional(list(object({<br/>      disk_size_bytes = optional(number, null)<br/>      disk_size_mib   = optional(number, null)<br/>      # now supported (v1 TODO): disk address bus_type/index.<br/>      bus_type = optional(string, "SCSI")<br/>      index    = optional(number, null)<br/>      # now supported (v1 TODO): clone source via data_source reference.<br/>      image_ext_id             = optional(string, null)<br/>      source_vm_disk_ext_id    = optional(string, null)<br/>      storage_container_ext_id = optional(string, null)<br/>      is_flash_mode_enabled    = optional(bool, null)<br/>    })), [])<br/><br/>    # CD-ROMs (attach ISO images).<br/>    cd_roms = optional(list(object({<br/>      iso_type     = optional(string, null)<br/>      bus_type     = optional(string, "IDE")<br/>      index        = optional(number, null)<br/>      image_ext_id = optional(string, null)<br/>    })), [])<br/><br/>    serial_ports = optional(list(object({<br/>      index        = number<br/>      is_connected = optional(bool, true)<br/>    })), [])<br/><br/>    gpus = optional(list(object({<br/>      vendor    = optional(string, null)<br/>      mode      = optional(string, null)<br/>      device_id = optional(number, null)<br/>    })), [])<br/><br/>    # Guest customization: cloud-init (Linux) or sysprep (Windows).<br/>    guest_customization_cloud_init_user_data       = optional(string, null)<br/>    guest_customization_cloud_init_metadata        = optional(string, null)<br/>    guest_customization_cloud_init_datasource_type = optional(string, null)<br/>    # now supported (v1 TODO): sysprep guest customization block.<br/>    guest_customization_sysprep = optional(object({<br/>      install_type = optional(string, "PREPARED")<br/>      unattend_xml = optional(string, null)<br/>    }), null)<br/><br/>    # Project / ownership: now supported (v1 TODOs). v2 replaces the v3<br/>    # project_reference / owner_reference kind+uuid blocks with an external ID.<br/>    project_ext_id = optional(string, null)<br/>    owner_ext_id   = optional(string, null)<br/>  }))</pre> | `{}` | no |
| <a name="input_vm_anti_affinity_policies"></a> [vm\_anti\_affinity\_policies](#input\_vm\_anti\_affinity\_policies) | A map of VM anti-affinity policies (nutanix\_vm\_anti\_affinity\_policy\_v2) that keep VMs apart via categories. | <pre>map(object({<br/>    name          = string<br/>    description   = optional(string, null)<br/>    vm_categories = list(string) # category external IDs selecting the VMs<br/>  }))</pre> | `{}` | no |
| <a name="input_vm_host_affinity_policies"></a> [vm\_host\_affinity\_policies](#input\_vm\_host\_affinity\_policies) | A map of VM host-affinity policies (nutanix\_vm\_host\_affinity\_policy\_v2) that pin VMs to hosts via categories. | <pre>map(object({<br/>    name            = string<br/>    description     = optional(string, null)<br/>    vm_categories   = list(string) # category external IDs selecting the VMs<br/>    host_categories = list(string) # category external IDs selecting the hosts<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_compute_summary"></a> [compute\_summary](#output\_compute\_summary) | Summary of compute resources managed by this module. |
| <a name="output_existing_cluster_ext_ids"></a> [existing\_cluster\_ext\_ids](#output\_existing\_cluster\_ext\_ids) | Map of existing cluster names to their external IDs (populated when enable\_data\_lookups = true). |
| <a name="output_existing_image_ext_ids"></a> [existing\_image\_ext\_ids](#output\_existing\_image\_ext\_ids) | Map of existing image names to their external IDs (populated when enable\_data\_lookups = true). |
| <a name="output_existing_vm_ext_ids"></a> [existing\_vm\_ext\_ids](#output\_existing\_vm\_ext\_ids) | Map of existing virtual machine names to their external IDs (populated when enable\_data\_lookups = true). |
| <a name="output_image_ids"></a> [image\_ids](#output\_image\_ids) | Map of image keys to their external IDs. |
| <a name="output_images"></a> [images](#output\_images) | Map of created images with their details. |
| <a name="output_virtual_machine_ids"></a> [virtual\_machine\_ids](#output\_virtual\_machine\_ids) | Map of VM keys to their external IDs. |
| <a name="output_virtual_machine_nic_ips"></a> [virtual\_machine\_nic\_ips](#output\_virtual\_machine\_nic\_ips) | Map of virtual machine keys to their learned NIC IP addresses. |
| <a name="output_virtual_machine_nic_list"></a> [virtual\_machine\_nic\_list](#output\_virtual\_machine\_nic\_list) | Map of VM keys to their NIC list (includes backing and network info with assigned IPs). |
| <a name="output_virtual_machines"></a> [virtual\_machines](#output\_virtual\_machines) | Map of created VMs with their details. |
| <a name="output_vm_anti_affinity_policies"></a> [vm\_anti\_affinity\_policies](#output\_vm\_anti\_affinity\_policies) | Map of created VM anti-affinity policies with their details. |
| <a name="output_vm_anti_affinity_policy_ids"></a> [vm\_anti\_affinity\_policy\_ids](#output\_vm\_anti\_affinity\_policy\_ids) | Map of VM anti-affinity policy keys to their external IDs. |
| <a name="output_vm_host_affinity_policies"></a> [vm\_host\_affinity\_policies](#output\_vm\_host\_affinity\_policies) | Map of created VM host-affinity policies with their details. |
| <a name="output_vm_host_affinity_policy_ids"></a> [vm\_host\_affinity\_policy\_ids](#output\_vm\_host\_affinity\_policy\_ids) | Map of VM host-affinity policy keys to their external IDs. |
<!-- END_TF_DOCS -->
