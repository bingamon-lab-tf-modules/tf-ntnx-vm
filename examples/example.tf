################################################################################
# Nutanix VM Module - Example
################################################################################
#
# Uploads one disk image and provisions two virtual machines against the v2
# (nutanix_virtual_machine_v2) schema: a Linux VM customised with cloud-init and
# a Windows VM customised with sysprep.
#
# The cluster, subnet and source-image external IDs below are placeholders.
# Replace them with real ext_ids from your Prism Central, or set
# enable_data_lookups = true and use the module's existing_*_ext_ids outputs to
# resolve friendly names to external IDs.

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    nutanix = {
      source  = "nutanix/nutanix"
      version = ">= 2.4.2"
    }
  }
}

# Credentials are read from the NUTANIX_USERNAME / NUTANIX_PASSWORD /
# NUTANIX_ENDPOINT environment variables.
provider "nutanix" {}

locals {
  cluster_ext_id      = "00000000-0000-0000-0000-000000000001"
  subnet_ext_id       = "00000000-0000-0000-0000-000000000002"
  source_image_ext_id = "00000000-0000-0000-0000-000000000003"

  linux_cloud_init = <<-EOT
    #cloud-config
    hostname: app-linux-01
    package_update: true
    packages:
      - nginx
  EOT

  windows_unattend = "<?xml version=\"1.0\" encoding=\"utf-8\"?><unattend />"
}

module "vm" {
  source = "git::https://github.com/bingamon-lab-tf-modules/tf-ntnx-vm.git//module?ref=v0.1.0"

  # One uploaded DISK image.
  images = {
    ubuntu_2204 = {
      name        = "ubuntu-22.04-cloudimg"
      description = "Ubuntu 22.04 LTS cloud image"
      type        = "DISK_IMAGE"
      source = {
        url_source = {
          url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
        }
      }
      cluster_location_ext_ids = [local.cluster_ext_id]
    }
  }

  virtual_machines = {
    # Linux VM: cloud-init guest customization, 2 disks, 1 NIC.
    linux = {
      name           = "app-linux-01"
      description    = "Linux application server"
      cluster_ext_id = local.cluster_ext_id

      num_sockets          = 1
      num_cores_per_socket = 2
      memory_size_mib      = 4096
      boot_type            = "UEFI"

      disks = [
        {
          # OS disk cloned from the source image.
          bus_type     = "SCSI"
          index        = 0
          image_ext_id = local.source_image_ext_id
        },
        {
          # Blank data disk.
          bus_type      = "SCSI"
          index         = 1
          disk_size_mib = 51200
        },
      ]

      nics = [
        {
          subnet_ext_id = local.subnet_ext_id
        },
      ]

      guest_customization_cloud_init_user_data = base64encode(local.linux_cloud_init)
    }

    # Windows VM: sysprep guest customization, 1 disk, 1 NIC.
    windows = {
      name           = "app-win-01"
      description    = "Windows application server"
      cluster_ext_id = local.cluster_ext_id

      num_sockets          = 2
      num_cores_per_socket = 2
      memory_size_mib      = 8192
      boot_type            = "SECURE_BOOT"
      machine_type         = "Q35"

      disks = [
        {
          bus_type     = "SCSI"
          index        = 0
          image_ext_id = local.source_image_ext_id
        },
      ]

      nics = [
        {
          subnet_ext_id = local.subnet_ext_id
        },
      ]

      guest_customization_sysprep = {
        install_type = "PREPARED"
        unattend_xml = local.windows_unattend
      }
    }
  }
}

output "image_ids" {
  description = "External IDs of the uploaded images."
  value       = module.vm.image_ids
}

output "virtual_machine_ids" {
  description = "External IDs of the created virtual machines."
  value       = module.vm.virtual_machine_ids
}

output "compute_summary" {
  description = "Summary of the compute resources managed by the module."
  value       = module.vm.compute_summary
}
