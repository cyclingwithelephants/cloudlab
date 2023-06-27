packer {
  required_plugins {
    hcloud = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/hcloud"
    }
  }
}

variable "hcloud_token" {
  type      = string
  default   = "${env("HCLOUD_TOKEN")}"
  sensitive = true
}

variable "image-name" {
  type    = string
  default = "talos-image"
}

variable "os" {
  type    = string
  default = "debian-11"
}

variable "talos_version" {
  type    = string
  default = "v1.4.5"
}
# The "legacy_isotime" function has been provided for backwards compatability, but we recommend switching to the timestamp and formatdate functions.

# All locals variables are generated from variables that uses expressions
# that are not allowed in HCL2 variables.
# Read the documentation for locals blocks here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/locals
locals {
  scripts = "${path.root}/scripts"
  version = "${legacy_isotime("2006-01-02-1504")}"
}

# source blocks are generated from your builders; a source can be referenced in
# build blocks. A build block runs provisioner and post-processors on a
# source. Read the documentation for source blocks here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/source
source "hcloud" "autogenerated_1" {
  image       = "${var.os}"
  location    = "fsn1"
  rescue      = "linux64"
  server_type = "cx21"
  snapshot_labels = {
    caph-image-name = "${var.image-name}-${local.version}"
    talos_version   = "${var.talos_version}"
  }
  snapshot_name = "talos-${var.talos_version}-${legacy_isotime("2006-01-02")}"
  ssh_username  = "root"
  token         = "${var.hcloud_token}"
}

# a build block invokes sources and runs provisioning steps on them. The
# documentation for build blocks can be found here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/build
build {
  sources = ["source.hcloud.autogenerated_1"]

  provisioner "shell" {
    environment_vars = ["PACKER_OS_IMAGE=${var.os}", "IMAGE_URL=https://github.com/siderolabs/talos/releases/download/${var.talos_version}/hcloud-amd64.raw.xz"]
    scripts          = ["${local.scripts}/configure_base.sh"]
  }

  post-processor "manifest" {
    custom_data = {
      snapshot_label = "${var.image-name}-${local.version}"
    }
    output     = "manifest.json"
    strip_path = false
  }
}