#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

clusterctl generate provider --infrastructure hetzner:v1.0.0-beta.26 > resources/provider.yaml
