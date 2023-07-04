This process assumes you have build a VM image and saved that to hetzner.

1. We need to create and initiate a temporary management cluster, this can be created locally using e.g. kind
    ```bash
    kind create cluster
    clusterctl init \
      --core cluster-api \
      --bootstrap talos \
      --control-plane talos \
      --infrastructure hetzner
    ```
2. We must export some environment variables to configure the bootstrap process
    ```bash
    # we assume here that we are initialising the production cluster, since it (will) manage the other clusters
    source manifests/groups/prod/cluster/env.bash
   ```
3. We also need to configure the auth token, so that the cluster can auth with Hetzner. I stored mine on my local machine.
   ```bash
   # this is a directory I have created, hetzner don't officially use this directory
   export HCLOUD_TOKEN=$(cat /Users/adam/.hetzner/cloud/projects/cloudlab-prod/tokens/capi)
   ```
4. Create the k8s secret, allowing the management cluster to auth with Hetzner. We also patch the created secret so it is automatically moved to the target cluster later. This will enable the cluster to manage itself.
   ```bash
   kubectl create secret generic hcloud --from-literal=token=$HCLOUD_TOKEN -n cluster
   kubectl patch secret hcloud -n cluster -p '{"metadata":{"labels":{"clusterctl.cluster.x-k8s.io/move":""}}}'
   ```
5. Generate the cluster
   ```bash
   kustomize build manifests/groups/prod/cluster | envsubst | kubectl apply -f -
   ```
6. Wait for the cluster to be created
   ```bash
   # view the cluster and its resources
   kubectl get cluster ${CLUSTER_NAME} --watch
   
   # verify that the cluster is ready
   kubectl get taloscontrolplane 
   ```

7. Once the first master node is up, we can fetch the kube-config
   ```bash
   export CAPH_WORKER_CLUSTER_KUBECONFIG=/tmp/workload-kubeconfig
   unset KUBECONFIG
   clusterctl get kubeconfig ${CLUSTER_NAME} > ${CAPH_WORKER_CLUSTER_KUBECONFIG}
   export KUBECONFIG=/tmp/workload-kubeconfig
   kubectl get pods -A
   ```
8. Deploy the Hetzner cloud controller manager (CCM)
   ```bash
   kustomize build --enable-helm manifests/groups/prod/addons/hcloud-ccm | kubectl apply -f -
   # allows the hccm to auth with hetzner
   # we also specify the network to attach the cluster to.
   kubectl create secret generic hcloud \
     -n kube-system \
     --from-literal=token=$HCLOUD_TOKEN \
     --from-literal=network=$HCLOUD_NETWORK
   
   ```
9. Move the cluster installation from the managing cluster to the managed cluster, so that the cluster manages itself
   ```bash
   # install the cluster controllers onto the host cluster
   clusterctl init \
    --core cluster-api \
    --bootstrap talos \
    --control-plane talos \
    --infrastructure hetzner
    
   # move the cluster to the target cluster
   unset KUBECONFIG
   clusterctl move --to-kubeconfig $CAPH_WORKER_CLUSTER_KUBECONFIG
   ```
