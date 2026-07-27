##################################################
# OVAs (v2, provider 2.4.2)
##################################################

# OVA appliance image. Imported once from exactly one source variant (URL,
# object-lite key, or an existing VM). Steady-state resource that ova_downloads
# and ova_deployments reference. See the var.ovas description for the family
# distinction from images_v2.
resource "nutanix_ova_v2" "ova" {
  for_each = var.ovas

  name        = each.value.name
  disk_format = each.value.disk_format

  cluster_location_ext_ids = length(each.value.cluster_location_ext_ids) > 0 ? each.value.cluster_location_ext_ids : null

  dynamic "checksum" {
    for_each = each.value.checksum != null ? [each.value.checksum] : []
    content {
      dynamic "ova_sha1_checksum" {
        for_each = checksum.value.sha1 != null ? [checksum.value.sha1] : []
        content {
          hex_digest = ova_sha1_checksum.value
        }
      }
      dynamic "ova_sha256_checksum" {
        for_each = checksum.value.sha256 != null ? [checksum.value.sha256] : []
        content {
          hex_digest = ova_sha256_checksum.value
        }
      }
    }
  }

  # The provider requires exactly one source block; var.ovas validation ensures
  # exactly one variant is populated within it.
  source {
    dynamic "ova_url_source" {
      for_each = each.value.source.url_source != null ? [each.value.source.url_source] : []
      content {
        url                       = ova_url_source.value.url
        should_allow_insecure_url = ova_url_source.value.should_allow_insecure_url

        dynamic "basic_auth" {
          for_each = ova_url_source.value.basic_auth != null ? [ova_url_source.value.basic_auth] : []
          content {
            username = basic_auth.value.username
            password = basic_auth.value.password
          }
        }
      }
    }

    dynamic "object_lite_source" {
      for_each = each.value.source.object_lite_source != null ? [each.value.source.object_lite_source] : []
      content {
        key = object_lite_source.value.key
      }
    }

    dynamic "ova_vm_source" {
      for_each = each.value.source.vm_source != null ? [each.value.source.vm_source] : []
      content {
        vm_ext_id        = ova_vm_source.value.vm_ext_id
        disk_file_format = ova_vm_source.value.disk_file_format
      }
    }
  }
}

##################################################
# OVA Downloads (v2) -- imperative, one-shot export
##################################################

# Exports/downloads an OVA once. The OVA reference is resolved in locals.tf
# against module-created OVAs first, falling back to a literal ext_id. See the
# var.ova_downloads description for the imperative/one-shot caveats.
resource "nutanix_ova_download_v2" "ova_download" {
  for_each = var.ova_downloads

  ova_ext_id = local.ova_download_ova_ext_id[each.key]
}

##################################################
# OVA VM Deployments (v2) -- deploy a VM from an OVA
##################################################

# Deploys a VM from an OVA. The OVA reference is resolved in locals.tf against
# module-created OVAs first, falling back to a literal ext_id; the cluster is
# resolved from a name to an ext_id when enable_data_lookups = true. The deployed
# VM is a provider-side artifact and is NOT modelled as a
# nutanix_virtual_machine_v2 resource. Provider 2.4.2 supports in-place update of
# override_vm_config -- see the var.ova_deployments description.
resource "nutanix_ova_vm_deploy_v2" "ova_deployment" {
  for_each = var.ova_deployments

  ext_id                  = local.ova_deployment_ova_ext_id[each.key]
  cluster_location_ext_id = try(local.existing_cluster_ext_ids[each.value.cluster], each.value.cluster)

  override_vm_config {
    name                 = each.value.name
    num_sockets          = each.value.num_sockets
    num_cores_per_socket = each.value.num_cores_per_socket
    num_threads_per_core = each.value.num_threads_per_core
    power_state          = each.value.power_state
    memory_size_bytes = each.value.memory_size_mib != null ? (
      each.value.memory_size_mib * 1024 * 1024
    ) : null

    dynamic "categories" {
      # Same backup-tier mechanism as a VM. Prism Central matches protection
      # policies on CATEGORIES, so this tag protects the deployed VM even
      # though OpenTofu never tracks it.
      for_each = toset(local.ova_deployment_category_ext_ids[each.key])
      content {
        ext_id = categories.value
      }
    }

    dynamic "nics" {
      for_each = each.value.nics
      content {
        backing_info {
          is_connected = nics.value.is_connected
          model        = nics.value.model
          mac_address  = nics.value.mac_address
        }

        network_info {
          nic_type  = nics.value.nic_type
          vlan_mode = nics.value.vlan_mode

          subnet {
            ext_id = (
              nics.value.subnet_name != null
              ? local.resolved_subnet_names[nics.value.subnet_name]
              : nics.value.subnet_ext_id
            )
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
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      override_vm_config[0].memory_size_bytes,
      override_vm_config[0].num_sockets,
      override_vm_config[0].num_cores_per_socket,
      override_vm_config[0].num_threads_per_core,
    ]
  }
}
