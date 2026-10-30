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

# Prints the changes of a GHCR release as a Markdown list (see .github/workflows/release-ghcr.yaml):
# CHANGES if set, otherwise the commit subjects since PREV_TAG without CI and Docs commits.
# With --prev-tag, prints the previous release tag instead: the newest v*-nginx-* tag reachable from HEAD
# other than CONTROLLER_TAG (empty for the first release).

set -o errexit
set -o nounset
set -o pipefail

: "${CONTROLLER_TAG:?}"

ROOT=$(dirname "${BASH_SOURCE[0]}")/..
CHANGES="${CHANGES:-}"

prev_tag() {
  git -C "${ROOT}" tag --merged HEAD --sort=-creatordate --list 'v*-nginx-*' | grep -vxF "${CONTROLLER_TAG}" | head -1 || true
}

if [[ "${1:-}" == "--prev-tag" ]]; then
  prev_tag
  exit 0
fi

if [[ -n "${CHANGES}" ]]; then
  echo "${CHANGES}"
  exit 0
fi

PREV_TAG="${PREV_TAG:-$(prev_tag)}"
if [[ -z "${PREV_TAG}" ]]; then
  echo "- Initial release."
  exit 0
fi

# CI and documentation commits do not change the published artifacts.
commits=$(git -C "${ROOT}" log --no-merges --format='- %s (%h)' "${PREV_TAG}..HEAD" | grep -vE '^- (CI|Docs):' || true)
echo "${commits:-- Rebuild without code changes.}"
