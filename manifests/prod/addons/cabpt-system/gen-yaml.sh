#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

clusterctl generate provider --bootstrap talos:v0.6.2 > resources/provider.yaml
