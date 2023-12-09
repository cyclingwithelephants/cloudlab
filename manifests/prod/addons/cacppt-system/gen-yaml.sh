#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

clusterctl generate provider --control-plane talos:v0.5.3 > resources/provider.yaml
