packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.4"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_url" {
  type        = string
  description = "e.g. https://proxmox.lan:8006/api2/json"
}

variable "proxmox_username" {
  type    = string
  default = "automation@pve!packer-terraform"
}

variable "proxmox_token" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name, e.g. pve"
}

variable "iso_storage_pool" {
  type    = string
  default = "local"
}

variable "vm_storage_pool" {
  type    = string
  default = "local-lvm"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "ssh_username" {
  type    = string
  default = "debian"
}

variable "ssh_password" {
  type      = string
  sensitive = true
  default   = "packer-temp-pw" # only used during build; account is unused after cloud-init takes over
}

source "proxmox-iso" "debian13-k3s" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = true

  node                 = var.proxmox_node
  vm_id                = 9000
  vm_name              = "debian13-k3s-template"
  template_description = "Debian 13 (Trixie) + qemu-guest-agent + cloud-init, ready for k3s. Built by Packer on ${timestamp()}"
  
  # Correct block syntax for modern Proxmox plugin local ISO maps
  boot_iso {
    type     = "ide"
    iso_file = "local:iso/debian-13.2.0-amd64-netinst.iso"
    unmount  = true
  }

  qemu_agent      = true
  scsi_controller = "virtio-scsi-single"

  disks {
    type              = "scsi"
    disk_size         = "32G"
    storage_pool      = var.vm_storage_pool
    storage_pool_type = "lvm-thin"
    ssd               = true
    discard           = true
  }

  cores    = 2
  sockets  = 1
  cpu_type = "host"
  memory   = 2048
  ballooning_minimum = 0

  network_adapters {
    model    = "virtio"
    bridge   = var.bridge
    firewall = false
  }

  cloud_init   = false # we install/enable cloud-init ourselves in provision.sh, template stays generic
  boot_wait    = "10s"
  boot_command = [
    "<esc><wait>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "hostname=debian13-template domain=local ",
    "interface=auto ",
    "<enter>"
  ] 

  http_directory = "http"

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "30m"

  # After preseed reboots into the installed system, Packer connects over SSH
  # using the account created in preseed.cfg.
}

build {
  name    = "debian13-k3s"
  sources = ["source.proxmox-iso.debian13-k3s"]

  provisioner "shell" {
    script          = "scripts/provision.sh"
    execute_command = "echo '${var.ssh_password}' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
  }
}

