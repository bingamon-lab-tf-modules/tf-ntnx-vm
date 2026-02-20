# tf-ntnx-vm

## Table of Contents

## Overview

A description of the module goes here.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_nutanix"></a> [nutanix](#requirement\_nutanix) | 2.3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_nutanix"></a> [nutanix](#provider\_nutanix) | 2.3.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [nutanix_images_v2.image](https://registry.terraform.io/providers/nutanix/nutanix/2.3.1/docs/resources/images_v2) | resource |
| [nutanix_virtual_machine.vm](https://registry.terraform.io/providers/nutanix/nutanix/2.3.1/docs/resources/virtual_machine) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_images"></a> [images](#input\_images) | A map of images to manage in Nutanix. | <pre>map(object({<br/>    name        = string<br/>    description = optional(string, null)<br/>    type        = string # DISK_IMAGE, ISO_IMAGE<br/><br/>    source = optional(object({<br/>      url_source = optional(object({<br/>        url                       = string<br/>        should_allow_insecure_url = optional(bool, false)<br/>        basic_auth = optional(object({<br/>          username = string<br/>          password = string<br/>        }), null)<br/>      }), null)<br/>      vm_disk_source = optional(object({<br/>        ext_id = string<br/>      }), null)<br/>      object_lite_source = optional(object({<br/>        key = string<br/>      }), null)<br/>    }), null)<br/><br/>    checksum = optional(object({<br/>      hex_digest  = string<br/>      object_type = optional(string, null)<br/>    }), null)<br/><br/>    category_ext_ids         = optional(list(string), [])<br/>    cluster_location_ext_ids = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_virtual_machines"></a> [virtual\_machines](#input\_virtual\_machines) | A map of virtual machines to manage in Nutanix. | <pre>map(object({<br/>    name                    = string<br/>    description             = optional(string, null)<br/>    cluster_uuid            = string<br/>    num_sockets             = optional(number, 1)<br/>    num_vcpus_per_socket    = optional(number, 1)<br/>    num_threads_per_core    = optional(number, null)<br/>    memory_size_mib         = optional(number, 2048)<br/>    power_state             = optional(string, "ON")<br/>    machine_type            = optional(string, null)<br/>    boot_type               = optional(string, null)<br/>    guest_os_id             = optional(string, null)<br/>    hardware_clock_timezone = optional(string, null)<br/>    vga_console_enabled     = optional(bool, null)<br/>    use_hot_add             = optional(bool, true)<br/>    enable_cpu_passthrough  = optional(bool, null)<br/>    is_vcpu_hard_pinned     = optional(bool, null)<br/>    num_vnuma_nodes         = optional(number, null)<br/><br/>    categories = optional(list(object({<br/>      name  = string<br/>      value = string<br/>    })), [])<br/><br/>    nic_list = optional(list(object({<br/>      subnet_uuid               = optional(string, null)<br/>      subnet_name               = optional(string, null)<br/>      nic_type                  = optional(string, "NORMAL_NIC")<br/>      model                     = optional(string, null)<br/>      mac_address               = optional(string, null)<br/>      num_queues                = optional(number, null)<br/>      network_function_nic_type = optional(string, null)<br/>      network_function_chain_reference = optional(object({<br/>        kind = optional(string, "network_function_chain")<br/>        uuid = string<br/>      }), null)<br/>      ip_endpoint_list = optional(list(object({<br/>        ip   = string<br/>        type = optional(string, "ASSIGNED")<br/>      })), [])<br/>    })), [])<br/><br/>    disk_list = optional(list(object({<br/>      disk_size_bytes = optional(number, null)<br/>      disk_size_mib   = optional(number, null)<br/>      device_properties = optional(object({<br/>        device_type = optional(string, "DISK")<br/>        disk_address = optional(object({<br/>          device_index = number<br/>          adapter_type = string<br/>        }), null)<br/>      }), null)<br/>      data_source_reference = optional(object({<br/>        kind = string<br/>        uuid = string<br/>      }), null)<br/>      storage_config = optional(object({<br/>        flash_mode = optional(string, null)<br/>        storage_container_reference = optional(object({<br/>          kind = optional(string, "storage_container")<br/>          uuid = string<br/>        }), null)<br/>      }), null)<br/>    })), [])<br/><br/>    serial_port_list = optional(list(object({<br/>      index        = number<br/>      is_connected = optional(bool, true)<br/>    })), [])<br/><br/>    boot_device_order_list  = optional(list(string), [])<br/>    boot_device_mac_address = optional(string, null)<br/>    boot_device_disk_address = optional(object({<br/>      device_index = number<br/>      adapter_type = string<br/>    }), null)<br/><br/>    guest_customization_cloud_init_user_data         = optional(string, null)<br/>    guest_customization_cloud_init_meta_data         = optional(string, null)<br/>    guest_customization_cloud_init_custom_key_values = optional(map(string), null)<br/>    guest_customization_is_overridable               = optional(bool, null)<br/>    guest_customization_sysprep = optional(object({<br/>      install_type = optional(string, "PREPARED")<br/>      unattend_xml = optional(string, null)<br/>    }), null)<br/>    guest_customization_sysprep_custom_key_values = optional(map(string), null)<br/><br/>    project_reference = optional(object({<br/>      kind = optional(string, "project")<br/>      uuid = string<br/>    }), null)<br/><br/>    owner_reference = optional(object({<br/>      kind = optional(string, "user")<br/>      uuid = string<br/>    }), null)<br/><br/>    gpu_list = optional(list(object({<br/>      vendor    = string<br/>      mode      = optional(string, null)<br/>      device_id = optional(number, null)<br/>    })), [])<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_compute_summary"></a> [compute\_summary](#output\_compute\_summary) | Summary of compute resources managed by this module. |
| <a name="output_image_ids"></a> [image\_ids](#output\_image\_ids) | Map of image keys to their external IDs. |
| <a name="output_images"></a> [images](#output\_images) | Map of created images with their details. |
| <a name="output_virtual_machine_ids"></a> [virtual\_machine\_ids](#output\_virtual\_machine\_ids) | Map of VM keys to their UUIDs. |
| <a name="output_virtual_machine_nic_list"></a> [virtual\_machine\_nic\_list](#output\_virtual\_machine\_nic\_list) | Map of VM keys to their NIC list status (includes assigned IPs). |
| <a name="output_virtual_machines"></a> [virtual\_machines](#output\_virtual\_machines) | Map of created VMs with their details. |
<!-- END_TF_DOCS -->
