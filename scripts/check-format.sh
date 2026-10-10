#!/usr/bin/env bash
# Copyright the Hyperledger Fabric contributors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

files=()
while IFS= read -r -d '' file; do
  files+=("$file")
done < <(git ls-files --cached --others --exclude-standard -z '*.go')

status=0
for tool in "${GOIMPORTS:-goimports}" "${GOFUMPT:-gofumpt}"; do
  if [[ "$tool" == *goimports ]]; then
    output=$("$tool" -local "$(go list -m)" -l "${files[@]}")
  else
    output=$("$tool" -l "${files[@]}")
  fi
  if [[ -n "$output" ]]; then
    printf '%s requires formatting:\n%s\n' "$tool" "$output" >&2
    status=1
  fi
done
exit "$status"
