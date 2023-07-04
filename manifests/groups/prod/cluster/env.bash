#!/usr/bin/env bash


# For machine types available visit https://www.hetzner.com/cloud
# CAX11 is ARM, 2 CPU, 4GB RAM, 40GB Disk

export CLUSTER_NAME=cloudlab
export CONTROL_PLANE_MACHINE_COUNT=3
export HCLOUD_CONTROL_PLANE_MACHINE_TYPE=cx21
# this is the image name, not the image ID or description.
# this is set in packer, by adding the label "caph-image-name" to the image.
# https://github.com/syself/cluster-api-provider-hetzner/blob/main/docs/topics/node-image.md
export HCLOUD_IMAGE_NAME=talos-image-2023-07-23-1210
export HCLOUD_REGION="fsn1"
export HCLOUD_SSH_KEY=cluster-nodes
export HCLOUD_WORKER_MACHINE_TYPE=cx21
export KUBERNETES_VERSION=1.27.3
export TALOS_VERSION=v1.4.5
export WORKER_MACHINE_COUNT=3
