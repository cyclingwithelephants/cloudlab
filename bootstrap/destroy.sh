#!/usr/bin/env bash

kind delete cluster

volumes=$(hcloud volume list | awk  '{print $2 }' | awk 'NR > 1')
for volume in $volumes; do
  hcloud volume detach $volume
  hcloud volume delete $volume
done

servers=$(hcloud server list | awk  '{print $2 }' | awk 'NR > 1')
for server in $servers; do
  hcloud server delete $server
done

ips=$(hcloud floating-ip list | awk  '{print $2 }' | awk 'NR > 1')
for ip in $ips; do
  hcloud floating-ip delete $ip
done

# delete load balancer
hcloud load-balancer list | awk  '{print $2 }' | awk 'NR > 1' | xargs -I {} hcloud load-balancer delete {}
