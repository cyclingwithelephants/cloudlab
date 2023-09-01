#!/usr/bin/env bash


env=${1:-prod}
[[ "${env}" != "prod" ]] && [[ "${env}" != "stage" ]] && echo "env must be either prod or stage" && exit 1

# 1. start at root of repo
cd $(dirname $0)/..

# 2. We need to create and initiate a temporary management cluster, this can
#    be created locally using e.g. kind
# kind delete cluster
kind create cluster
clusterctl init \
  --core cluster-api \
  --bootstrap talos \
  --control-plane talos \
  --infrastructure 'hetzner:v1.0.0-beta.20'

# 3. We must export some environment variables to configure the bootstrap process
source manifests/groups/${env}/cluster/env.bash

kubectl create namespace cluster

# 4. We also need to configure the auth token, so that the cluster can auth
#    with Hetzner. I stored mine on my local machine. this is a directory I
#    have created, hetzner don't officially use this directory
export HCLOUD_TOKEN=$(cat /Users/adam/.hetzner/cloud/projects/cloudlab-${env}/tokens/capi)

# 5. Create the k8s secret, allowing the management cluster to auth with Hetzner.
kubectl create secret generic hcloud \
  -n cluster \
  --from-literal=token=${HCLOUD_TOKEN}

# 6. We also patch the created secret so it is automatically moved to the target
#    cluster later. This will enable the cluster to manage itself.
kubectl patch secret hcloud \
  -n cluster \
  -p '{"metadata":{"labels":{"clusterctl.cluster.x-k8s.io/move":""}}}'

# 7. Generate the cluster
kustomize build manifests/groups/${env}/cluster \
  | envsubst \
  | kubectl apply -f -

# sleep 30

# 8. Wait for the cluster to be ready
kubectl wait taloscontrolplanes.controlplane.cluster.x-k8s.io cloudlab-control-plane \
  --for=condition=Available

# 9. Once the first master node is up, we can fetch the kube-config
export CAPH_WORKER_CLUSTER_KUBECONFIG=/tmp/workload-kubeconfig
unset KUBECONFIG
clusterctl get kubeconfig ${CLUSTER_NAME} > ${CAPH_WORKER_CLUSTER_KUBECONFIG}
export KUBECONFIG=/tmp/workload-kubeconfig

# 10. Deploy the Hetzner cloud controller manager
kustomize build --enable-helm manifests/groups/prod/addons/hcloud-ccm \
  | kubectl apply -f -

# allows the hccm to auth with hetzner
# We also specify the network to attach the cluster to.
# It happens to be the same as the cluster name.
kubectl create secret generic hcloud \
 -n kube-system \
 --from-literal=token=${HCLOUD_TOKEN} \
 --from-literal=network=${CLUSTER_NAME}

# 11. Deploy ArgoCD, so that the cluster will begin deploying its own workloads
kustomize build manifests/groups/prod/addons/argocd | kubectl apply -f -

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

# 12. Move the cluster installation from the managing cluster to the
#     managed cluster, so that the cluster manages itselfinstall the cluster
#     controllers onto the host cluster
clusterctl init \
  --core cluster-api \
  --bootstrap talos \
  --control-plane talos \
  --infrastructure 'hetzner:v1.0.0-beta.20'
  
unset KUBECONFIG
clusterctl move \
  --to-kubeconfig ${CAPH_WORKER_CLUSTER_KUBECONFIG}
