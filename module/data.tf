##################################################
# Compute Inventory Lookups (gated by enable_data_lookups)
##################################################

# Read-only lookups of existing compute inventory in Prism Central. Gated by
# var.enable_data_lookups (default false) because these list-everything reads are
# expensive and plan/validate/test must work without a live Prism Central
# connection (spec §7.4). Consumed by locals.tf to build name -> ext_id maps that
# are surfaced as outputs, so consumers can resolve friendly names to the
# external IDs the v2 schema requires.

# Existing clusters (cluster name -> ext_id).
data "nutanix_clusters_v2" "existing_cluster" {
  count = var.enable_data_lookups ? 1 : 0
}

# Existing images (image name -> ext_id).
data "nutanix_images_v2" "existing_image" {
  count = var.enable_data_lookups ? 1 : 0
}

# Existing virtual machines (VM name -> ext_id).
data "nutanix_virtual_machines_v2" "existing_vm" {
  count = var.enable_data_lookups ? 1 : 0
}

# Existing versioned templates (template name -> ext_id). Lets consumers resolve
# a friendly template name to the ext_id that deploy actions require, and lets
# deployments target templates that were created outside this module.
data "nutanix_templates_v2" "existing_template" {
  count = var.enable_data_lookups ? 1 : 0
}

# Existing OVAs (OVA name -> ext_id). Lets consumers resolve a friendly OVA name
# to the ext_id that download/deploy actions require, and lets deployments and
# exports target OVAs that were created outside this module.
data "nutanix_ovas_v2" "existing_ova" {
  count = var.enable_data_lookups ? 1 : 0
}

##################################################
# Placement Policy Lookups (gated by enable_data_lookups)
##################################################

# Categories are created in tf-ntnx-sec; this read-only lookup resolves existing
# category name/value to ext_id when wiring affinity policies against pre-existing
# categories. Gated so plan/validate needs no live Prism Central connection.
# tflint-ignore: terraform_unused_declarations # Optional lookup surfaced for consumers.
data "nutanix_categories_v2" "category" {
  count = var.enable_data_lookups ? 1 : 0
}

# Existing VM host-affinity policies in Prism Central.
# tflint-ignore: terraform_unused_declarations # Optional lookup surfaced for consumers.
data "nutanix_vm_host_affinity_policies_v2" "host_affinity_policy" {
  count = var.enable_data_lookups ? 1 : 0
}

# Existing VM anti-affinity policies in Prism Central.
# tflint-ignore: terraform_unused_declarations # Optional lookup surfaced for consumers.
data "nutanix_vm_anti_affinity_policies_v2" "anti_affinity_policy" {
  count = var.enable_data_lookups ? 1 : 0
}

##################################################
# NGT Configuration Lookups (gated by enable_data_lookups)
##################################################

# Read-only NGT configuration for each managed installation's VM. Unlike the
# list-everything lookups above, nutanix_ngt_configuration_v2 requires a VM
# ext_id, so this is keyed per ngt_installations entry and only read when
# var.enable_data_lookups = true (for_each collapses to {} otherwise, so
# plan/validate/test need no live Prism Central connection). Surfaced via
# output.ngt_configurations so consumers can see reported NGT state.
data "nutanix_ngt_configuration_v2" "ngt_configuration" {
  for_each = var.enable_data_lookups ? local.ngt_installation_vm_ext_id : {}

  ext_id = each.value
}
