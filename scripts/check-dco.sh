#!/usr/bin/env bash
# Copyright the Hyperledger Fabric contributors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# CI supplies the PR base or the previous branch tip, so main pushes are checked too.
base=${DCO_BASE_REF:-origin/main}
if [[ "$base" =~ ^0+$ ]]; then
  base=origin/main
fi
git rev-parse --verify "$base^{commit}" >/dev/null

status=0
while IFS= read -r commit; do
  signoff=$(git log -1 --format='%(trailers:key=Signed-off-by,valueonly)' "$commit")
  if [[ -z "$signoff" ]]; then
    git log -1 --format='Commit %h (%s) is missing Signed-off-by.' "$commit" >&2
    status=1
  fi
done < <(git rev-list --no-merges "$base..HEAD")
exit "$status"
