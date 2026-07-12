##################################################
# Data Sources for Compute
##################################################

# Existing images can be looked up via the v2 data source when needed:
# data "nutanix_images_v2" "existing_images" {}

# Existing clusters can be looked up via the v2 data source when needed:
# data "nutanix_clusters_v2" "clusters" {}

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
