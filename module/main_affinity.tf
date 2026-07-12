##################################################
# VM Placement Policies (v2, new in provider 2.4.2)
##################################################

# These are standalone, Prism Central-scoped policy objects (not the legacy
# per-VM affinity attribute). They select VMs and hosts by category external ID;
# categories themselves are managed in tf-ntnx-sec and referenced here.

# Host-affinity: pin VMs (by category) to specific hosts (by category).
resource "nutanix_vm_host_affinity_policy_v2" "host_affinity_policy" {
  for_each = var.vm_host_affinity_policies

  name            = each.value.name
  description     = each.value.description
  vm_categories   = toset(each.value.vm_categories)
  host_categories = toset(each.value.host_categories)
}

# Anti-affinity: keep VMs (by category) apart on different hosts.
resource "nutanix_vm_anti_affinity_policy_v2" "anti_affinity_policy" {
  for_each = var.vm_anti_affinity_policies

  name        = each.value.name
  description = each.value.description
  categories  = toset(each.value.vm_categories)
}
