#!/usr/bin/env bash


env=${1:-prod}
[[ "${env}" != "prod" ]] && [[ "${env}" != "stage" ]] && echo "env must be either prod or stage" && exit 1

clusterctl_init() {
  clusterctl init \
    --core           'cluster-api:v1.5.1' \
    --bootstrap      'talos:v0.6.0' \
    --control-plane  'talos:v0.5.1' \
    --infrastructure 'hetzner:v1.0.0-beta.21' \
    --wait-providers
}

write_capi_secret() {
  kubectl create namespace cluster

  # 4. We also need to configure the auth token, so that the cluster can auth
  #    with Hetzner. I stored mine on my local machine. this is a directory I
  #    have created, hetzner don't officially use this directory

  # 5. Create the k8s secret, allowing the management cluster to auth with Hetzner.
  kubectl create secret generic hcloud \
    -n cluster \
    --from-literal=token=$(cat /Users/adam/.hetzner/cloud/projects/cloudlab-prod/tokens/capi)

  # 6. We also patch the created secret so it is automatically moved to the target
  #    cluster later. This will enable the cluster to manage itself.
  kubectl patch secret hcloud \
    -n cluster \
    -p '{"metadata":{"labels":{"clusterctl.cluster.x-k8s.io/move":""}}}'
}

apply_manifests_at() {
  kustomize build --enable-helm $1 | kubectl apply -f -
}

generate_cluster() {
  # 7. Generate the cluster
  apply_manifests_at manifests/${env}/cluster
  sleep 10

  # 8. Wait for the cluster to be ready
  kubectl wait taloscontrolplane cloudlab-control-plane \
    -n cluster \
    --for=condition=Available \
    --timeout=5m
}

# 9. Once the first master node is up, we can fetch the kube-config
get_workload_kubeconfig() {
  export CAPH_WORKER_CLUSTER_KUBECONFIG=/tmp/workload-kubeconfig
  unset KUBECONFIG
  clusterctl get kubeconfig cloudlab -n cluster > ${CAPH_WORKER_CLUSTER_KUBECONFIG}
  export KUBECONFIG=/tmp/workload-kubeconfig
}

initialise_workload_cluster() {

  apply_manifests_at manifests/prod/addons/cilium

  # 10. Deploy the Hetzner cloud controller manager
  # allows the hccm to auth with hetzner
  # We also specify the network to attach the cluster to.
  # It happens to be the same as the cluster name.
  kubectl create secret generic hcloud \
    -n kube-system \
    --from-literal=token=$(cat /Users/adam/.hetzner/cloud/projects/cloudlab-${env}/tokens/ccm) \
    --from-literal=network=cloudlab
  apply_manifests_at manifests/prod/addons/hcloud-ccm

  # 11. Deploy ArgoCD, so that the cluster will begin deploying its own workloads
  apply_manifests_at manifests/prod/addons/namespaces
  sleep 5
  apply_manifests_at manifests/prod/addons/argocd
  sleep 1
  apply_manifests_at manifests/prod/addons/argocd

  # 12. Deploy the secret allowing external-secrets to populate secrets
  #     from AWS parameter store. It looks like:
  # ---
  #apiVersion: v1
  #data:
  #  aws_access_key_id: <redacted>
  #  aws_secret_access_key: <redacted>
  #kind: Secret
  #metadata:
  #  name: aws-parameter-store
  #  namespace: external-secrets
  # ---
  kubectl apply -f manifests/groups/prod/secrets/external-secrets.yaml

  # 13. Move the cluster installation from the managing cluster to the
  #     managed cluster, so that the cluster manages itself
  clusterctl_init # in the new cluster
  unset KUBECONFIG
  clusterctl move --to-kubeconfig ${CAPH_WORKER_CLUSTER_KUBECONFIG}
}


# 1. start at root of repo
cd $(dirname $0)/..

clusterctl_init
write_capi_secret
generate_cluster
get_workload_kubeconfig
initialise_workload_cluster
