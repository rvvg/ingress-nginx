#!/bin/bash

# Copyright 2026 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Prints GitHub release notes for a GHCR release (see .github/workflows/release-ghcr.yaml).

set -o errexit
set -o nounset
set -o pipefail

: "${REGISTRY:?}" "${CHART_REGISTRY:?}" "${BASE_TAG:?}" "${CONTROLLER_TAG:?}" "${CHART_VERSION:?}" "${DIGEST:?}" "${DIGEST_CHROOT:?}"

ROOT=$(dirname "${BASH_SOURCE[0]}")/..
NGINX_VERSION=$(sed -n 's/^export NGINX_VERSION=//p' "${ROOT}/images/nginx/rootfs/build.sh")
REPO_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-rvvg/ingress-nginx}"

cat <<EOF
ingress-nginx controller \`${CONTROLLER_TAG}\` built on NGINX ${NGINX_VERSION} (mainline) with the OpenResty patch set.
Drop-in replacement for the retired \`kubernetes/ingress-nginx\` \`controller-${CONTROLLER_TAG%%-nginx-*}\` images. See the
[README](${REPO_URL}#readme) for the patch list and behavior changes.

## Artifacts

All images are multi-arch (\`linux/amd64\`, \`linux/arm64\`), signed with keyless cosign and carry SPDX SBOM attestations.

| Artifact | Reference |
| --- | --- |
| Controller | \`${REGISTRY}/controller:${CONTROLLER_TAG}@${DIGEST}\` |
| Controller (chroot) | \`${REGISTRY}/controller-chroot:${CONTROLLER_TAG}@${DIGEST_CHROOT}\` |
| NGINX base | \`${REGISTRY}/nginx:${BASE_TAG}\` |
| Helm chart | \`oci://${CHART_REGISTRY}/ingress-nginx\` version \`${CHART_VERSION}\` |

## Install

\`\`\`bash
helm upgrade --install ingress-nginx oci://${CHART_REGISTRY}/ingress-nginx \\
  --version ${CHART_VERSION} -n ingress-nginx --create-namespace
\`\`\`

## Use with the upstream chart

\`\`\`yaml
controller:
  image:
    registry: ${REGISTRY%/ingress-nginx}
    image: ingress-nginx/controller
    tag: ${CONTROLLER_TAG}
    digest: ${DIGEST}
    digestChroot: ${DIGEST_CHROOT}
\`\`\`

## Verify

\`\`\`bash
cosign verify ${REGISTRY}/controller:${CONTROLLER_TAG} \\
  --certificate-identity-regexp '^${REPO_URL}/' \\
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
\`\`\`
EOF
