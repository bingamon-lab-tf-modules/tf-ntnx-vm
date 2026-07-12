##################################################
# VM Templates (v2, provider 2.4.2)
##################################################

# Versioned golden-image template. The initial, active version is captured from
# the source VM referenced by source_vm_ext_id. Steady-state resource: see the
# var.templates description for how day-2 guest-OS updates are handled instead.
resource "nutanix_template_v2" "template" {
  for_each = var.templates

  template_name        = each.value.name
  template_description = each.value.description
  category_ext_ids     = length(each.value.category_ext_ids) > 0 ? each.value.category_ext_ids : null

  template_version_spec {
    version_name           = each.value.version_name
    version_description    = each.value.version_description
    is_active_version      = each.value.is_active_version
    is_gc_override_enabled = each.value.is_gc_override_enabled

    version_source {
      template_vm_reference {
        ext_id = each.value.source_vm_ext_id
      }
    }
  }
}

##################################################
# Template Deployments (v2) -- imperative, one-shot
##################################################

# Deploys number_of_vms VMs from a template version. The template reference is
# resolved in locals.tf against module-created templates first, falling back to
# a literal ext_id. See the var.template_deployments description for the
# imperative/one-shot and destroy caveats; the deployed VMs are NOT modelled as
# nutanix_virtual_machine_v2 resources.
resource "nutanix_deploy_templates_v2" "template_deployment" {
  for_each = var.template_deployments

  ext_id            = local.template_deployment_template_ext_id[each.key]
  cluster_reference = try(local.existing_cluster_ext_ids[each.value.cluster], each.value.cluster)
  number_of_vms     = each.value.number_of_vms
  version_id        = each.value.version_id

  dynamic "override_vm_config_map" {
    for_each = each.value.override_vm_configs
    content {
      name                 = override_vm_config_map.value.name
      num_sockets          = override_vm_config_map.value.num_sockets
      num_cores_per_socket = override_vm_config_map.value.num_cores_per_socket
      num_threads_per_core = override_vm_config_map.value.num_threads_per_core
      memory_size_bytes = override_vm_config_map.value.memory_size_mib != null ? (
        override_vm_config_map.value.memory_size_mib * 1024 * 1024
      ) : null
    }
  }
}

##################################################
# Template Guest-OS Update Actions (v2) -- operator-triggered
##################################################

# Operator-triggered guest-OS update session actions (initiate/complete/cancel)
# over a template version. The template reference is resolved in locals.tf. See
# the var.template_guest_os_actions description for the one-shot state-machine
# semantics.
resource "nutanix_template_guest_os_actions_v2" "template_guest_os_action" {
  for_each = var.template_guest_os_actions

  ext_id              = local.template_guest_os_action_ext_id[each.key]
  action              = each.value.action
  version_id          = each.value.version_id
  version_name        = each.value.version_name
  version_description = each.value.version_description
  is_active_version   = each.value.is_active_version
}
