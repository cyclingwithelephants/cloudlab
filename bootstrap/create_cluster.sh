#!/usr/bin/env bash


env=${1:-prod}
[[ "${env}" != "prod" ]] && [[ "${env}" != "stage" ]] && echo "env must be either prod or stage" && exit 1

export HCLOUD_TOKEN_CCM="$(cat /Users/adam/.hetzner/cloud/projects/cloudlab-prod/tokens/ccm)"
export HCLOUD_TOKEN_CAPH="$(cat /Users/adam/.hetzner/cloud/projects/cloudlab-prod/tokens/capi)"

clusterctl_init() {
  clusterctl init \
    --core           cluster-api \
    --bootstrap      talos \
    --control-plane  talos \
    --infrastructure hetzner \
    --wait-providers
}

write_capi_secret() {
  kubectl create namespace cluster

  # 4. We also need to configure the auth token, so that the cluster can auth
  #    with Hetzner. I stored mine on my local machine. this is a directory I
  #    have created, hetzner don't officially use this directory

  # 5. Create the k8s secret, allowing the management cluster to auth with Hetzner.
  kubectl apply -f manifests/prod/secrets/hcloud-cloud-controller-manager.yaml
}

apply_manifests_at() {
  kustomize build --enable-helm "$1" | kubectl apply -f -
}

generate_cluster() {
  # 7. Generate the cluster
  apply_manifests_at "manifests/${env}/cluster"
  kubectl apply -f "manifests/prod/secrets/hcloud-capi.yaml"

  # 8. Wait for the cluster to be ready
  kubectl wait taloscontrolplane cloudlab-control-plane \
    -n cluster \
    --for=condition=Available \
    --timeout=5m
}

initialise_workload_cluster() {

  unset KUBECONFIG
  clusterctl get kubeconfig cloudlab -n cluster > /tmp/workload-kubeconfig
  export KUBECONFIG=/tmp/workload-kubeconfig

  # 10. Deploy the Hetzner cloud controller manager
  # allows the hccm to auth with hetzner
  # We also specify the network to attach the cluster to.
  # It happens to be the same as the cluster name.
  apply_manifests_at manifests/prod/addons/hcloud-ccm

  # 11. Deploy ArgoCD, so that the cluster will begin deploying its own workloads
  apply_manifests_at manifests/prod/addons/namespaces

  # create some bootstrap secrets including:
  # - external-secrets secret
  # - hcloud-capi,for allowing CAPI to auth
  # - hcloud-ccm, for allowing Cloud Controller Manager to auth (move to external-secrets)
  kubectl apply -f manifests/prod/secrets/

  # 13. Move the cluster installation from the managing cluster to the
  #     managed cluster, so that the cluster manages itself
  clusterctl_init # in the new cluster
  unset KUBECONFIG
  clusterctl move --to-kubeconfig /tmp/workload-kubeconfig --namespace cluster

  export KUBECONFIG=/tmp/workload-kubeconfig
  apply_manifests_at manifests/prod/addons/argo-cd
  apply_manifests_at manifests/prod/addons/argo-cd
}


# 1. start at root of repo
cd $(dirname $0)/..

kind create cluster
clusterctl_init
write_capi_secret
generate_cluster
initialise_workload_cluster


# ensure all nodes are ready
# kubectl wait --for=condition=Ready nodes --all --timeout=600s
