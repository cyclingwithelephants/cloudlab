packer {
  required_plugins {
    hcloud = {
      version = ">= 1.0.5"
      source  = "github.com/hashicorp/hcloud"
    }
    git = {
      version = ">= 0.4.2"
      source  = "github.com/ethanmdavidson/git"
    }
  }
}

data "git-commit" "cwd-head" {}

variable "hcloud_token" {
  type      = string
  default   = "${env("HCLOUD_TOKEN")}"
  sensitive = true
}

variable "talos_version" {
  type    = string
  default = "v1.4.5"
}

locals {
  truncated_sha = substr(data.git-commit.cwd-head.hash, 0, 8)
  scripts       = "${path.root}/scripts"
  image_name    = "talos-${local.truncated_sha}"
  location      = "fsn1"
  rescue        = "linux64"
  os            = "debian-11"
  ssh_username  = "root"
}

source "hcloud" "amd64" {
  image       = local.os
  location    = local.location
  rescue      = local.rescue
  server_type = "cx21" # 2 core 4GB ram

  snapshot_labels = {
    caph-image-name = local.image_name
    talos-version   = var.talos_version
    arch            = "amd64"
    git-sha         = local.truncated_sha
  }

  snapshot_name = "${local.image_name}-amd64"
  ssh_username  = local.ssh_username
  token         = var.hcloud_token
}

source "hcloud" "arm64" {
  image       = local.os
  location    = local.location
  rescue      = local.rescue
  server_type = "cax21" # 4 core 8 GB ram

  snapshot_labels = {
    caph-image-name = local.image_name
    talos-version   = var.talos_version
    arch            = "arm64"
    git-sha         = local.truncated_sha
  }

  snapshot_name = "${local.image_name}-arm64"
  ssh_username  = local.ssh_username
  token         = var.hcloud_token
}

# We build two identical images, one for amd64 and one for arm64.
# We give them the same tag `caph-image-name` so that we can always reference
# the same image name regardless of the architecture for the particular node.
build {
  sources = [
    "source.hcloud.amd64",
    "source.hcloud.arm64",
  ]

  provisioner "shell" {
    only             = ["hcloud.amd64"]
    environment_vars = ["IMAGE_URL=https://github.com/siderolabs/talos/releases/download/${var.talos_version}/hcloud-amd64.raw.xz"]
    scripts          = ["${local.scripts}/configure_base.sh"]
  }

  provisioner "shell" {
    only             = ["hcloud.arm64"]
    environment_vars = ["IMAGE_URL=https://github.com/siderolabs/talos/releases/download/${var.talos_version}/hcloud-arm64.raw.xz"]
    scripts          = ["${local.scripts}/configure_base.sh"]
  }

  post-processor "manifest" {
    custom_data = {
      caph-image-name = local.image_name
      talos-version   = var.talos_version
      git-sha         = local.truncated_sha
    }
    output     = "manifest.json"
    strip_path = true
  }
}
