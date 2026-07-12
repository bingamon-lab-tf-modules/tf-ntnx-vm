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
      name         = "webserver-01"
      description  = "Web server VM"
      cluster_uuid = var.cluster_uuid

      # Compute
      num_vcpus_per_socket = 2
      num_sockets          = 1
      memory_size_mib      = 4096

      # Boot
      boot_type              = "UEFI"
      boot_device_order_list = ["DISK", "CDROM", "NETWORK"]

      # Categories
      categories = [
        {
          name  = "Environment"
          value = "Production"
        },
        {
          name  = "AppType"
          value = "WebServer"
        }
      ]

      # Disks
      disk_list = [
        {
          disk_size_mib = 51200 # 50GB
          device_properties = {
            device_type = "DISK"
            disk_address = {
              device_index = 0
              adapter_type = "SCSI"
            }
          }
          data_source_reference = {
            kind = "image"
            uuid = var.source_image_uuid
          }
        }
      ]

      # NICs
      nic_list = [
        {
          subnet_uuid = var.subnet_uuid
          nic_type    = "NORMAL_NIC"
        }
      ]

      # Cloud-init
      guest_customization_cloud_init_user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
        hostname       = "webserver-01"
        ssh_public_key = var.ssh_public_key
      }))
    }

    database = {
      name         = "database-01"
      description  = "Database server VM"
      cluster_uuid = var.cluster_uuid

      # Compute
      num_vcpus_per_socket = 4
      num_sockets          = 1
      memory_size_mib      = 8192

      # Categories
      categories = [
        {
          name  = "Environment"
          value = "Production"
        },
        {
          name  = "AppType"
          value = "Database"
        }
      ]

      # Disks - OS disk + data disk
      disk_list = [
        {
          disk_size_mib = 51200 # 50GB OS
          device_properties = {
            device_type = "DISK"
            disk_address = {
              device_index = 0
              adapter_type = "SCSI"
            }
          }
          data_source_reference = {
            kind = "image"
            uuid = var.source_image_uuid
          }
        },
        {
          disk_size_mib = 102400 # 100GB data
          device_properties = {
            device_type = "DISK"
            disk_address = {
              device_index = 1
              adapter_type = "SCSI"
            }
          }
          storage_config = {
            storage_container_reference = {
              kind = "storage_container"
              uuid = var.storage_container_uuid
            }
          }
        }
      ]

      # NICs
      nic_list = [
        {
          subnet_uuid = var.subnet_uuid
          nic_type    = "NORMAL_NIC"
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
