################################################################################
# Nutanix VM Module - Complete Example
################################################################################

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    nutanix = {
      source  = "nutanix/nutanix"
      version = ">= 2.4.2"
    }
  }
}

provider "nutanix" {
  username = var.nutanix_username
  password = var.nutanix_password
  endpoint = var.nutanix_endpoint
  insecure = var.nutanix_insecure
}

################################################################################
# VM Module
################################################################################

module "vm" {
  source = "../../module"

  # Images
  images = {
    ubuntu_22 = {
      name        = "ubuntu-22.04-cloudimg"
      description = "Ubuntu 22.04 LTS Cloud Image"
      type        = "DISK_IMAGE"
      source = {
        url_source = {
          url                       = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
          should_allow_insecure_url = false
        }
      }
      cluster_location_ext_ids = [var.cluster_ext_id]
    }

    rocky_9 = {
      name        = "rocky-9-cloudimg"
      description = "Rocky Linux 9 Cloud Image"
      type        = "DISK_IMAGE"
      source = {
        url_source = {
          url = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
        }
      }
      cluster_location_ext_ids = [var.cluster_ext_id]
    }
  }

  # Virtual Machines
  virtual_machines = {
    webserver = {
      name           = "webserver-01"
      description    = "Web server VM"
      cluster_ext_id = var.cluster_ext_id

      # Compute
      num_cores_per_socket = 2
      num_sockets          = 1
      memory_size_mib      = 4096

      # Boot
      boot_type  = "UEFI"
      boot_order = ["DISK", "CDROM", "NETWORK"]

      # Categories (v2: category external IDs)
      category_ext_ids = [var.environment_category_ext_id]

      # Disks - image-backed OS disk
      disks = [
        {
          disk_size_mib = 51200 # 50GB
          bus_type      = "SCSI"
          index         = 0
          image_ext_id  = var.source_image_ext_id
        }
      ]

      # NICs
      nics = [
        {
          subnet_ext_id = var.subnet_ext_id
          nic_type      = "NORMAL_NIC"
        }
      ]

      # Cloud-init
      guest_customization_cloud_init_user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
        hostname       = "webserver-01"
        ssh_public_key = var.ssh_public_key
      }))
    }

    database = {
      name           = "database-01"
      description    = "Database server VM"
      cluster_ext_id = var.cluster_ext_id

      # Compute
      num_cores_per_socket = 4
      num_sockets          = 1
      memory_size_mib      = 8192

      # Categories (v2: category external IDs)
      category_ext_ids = [var.environment_category_ext_id]

      # Disks - image-backed OS disk + blank data disk
      disks = [
        {
          disk_size_mib = 51200 # 50GB OS
          bus_type      = "SCSI"
          index         = 0
          image_ext_id  = var.source_image_ext_id
        },
        {
          disk_size_mib            = 102400 # 100GB data
          bus_type                 = "SCSI"
          index                    = 1
          storage_container_ext_id = var.storage_container_ext_id
        }
      ]

      # NICs
      nics = [
        {
          subnet_ext_id = var.subnet_ext_id
          nic_type      = "NORMAL_NIC"
        }
      ]

      # Cloud-init
      guest_customization_cloud_init_user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
        hostname       = "database-01"
        ssh_public_key = var.ssh_public_key
      }))
    }
  }
}
