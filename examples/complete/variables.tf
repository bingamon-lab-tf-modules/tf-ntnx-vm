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

variable "cluster_uuid" {
  description = "Nutanix cluster UUID for VM placement"
  type        = string
}

variable "cluster_ext_id" {
  description = "Nutanix cluster external ID for image placement"
  type        = string
}

variable "subnet_uuid" {
  description = "Subnet UUID for VM NIC attachment"
  type        = string
}

variable "source_image_uuid" {
  description = "Source image UUID for VM disk cloning"
  type        = string
}

variable "storage_container_uuid" {
  description = "Storage container UUID for additional disks"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}
