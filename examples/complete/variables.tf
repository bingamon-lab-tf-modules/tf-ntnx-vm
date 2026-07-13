################################################################################
# Provider Variables
################################################################################

variable "nutanix_username" {
  description = "Nutanix Prism Central username"
  type        = string
}

variable "nutanix_password" {
  description = "Nutanix Prism Central password"
  type        = string
  sensitive   = true
}

variable "nutanix_endpoint" {
  description = "Nutanix Prism Central endpoint"
  type        = string
}

variable "nutanix_insecure" {
  description = "Allow insecure TLS connections"
  type        = bool
  default     = false
}

################################################################################
# VM Variables
################################################################################

variable "cluster_ext_id" {
  description = "Nutanix cluster external ID for VM placement and image location"
  type        = string
}

variable "subnet_ext_id" {
  description = "Subnet external ID for VM NIC attachment"
  type        = string
}

variable "source_image_ext_id" {
  description = "Source image external ID for VM disk cloning"
  type        = string
}

variable "storage_container_ext_id" {
  description = "Storage container external ID for additional disks"
  type        = string
}

variable "environment_category_ext_id" {
  description = "Category external ID to associate with the VMs"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}
