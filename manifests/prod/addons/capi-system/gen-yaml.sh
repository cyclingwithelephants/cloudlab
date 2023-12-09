#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

clusterctl generate provider --core cluster-api:v1.6.0 > resources/provider.yaml
