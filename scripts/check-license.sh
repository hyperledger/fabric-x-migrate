#!/usr/bin/env bash
set -euo pipefail

status=0
while IFS= read -r -d '' file; do
  [[ -f "$file" && ! -L "$file" ]] || continue
  case "$file" in
    *.go|*.sh|*.sql|*.yaml|*.yml|Makefile|Dockerfile|.dockerignore|.yamllint|.sqlfluff)
      if ! grep -q 'SPDX-License-Identifier: Apache-2.0' "$file"; then
        printf 'Missing Apache-2.0 header: %s\n' "$file" >&2
        status=1
      fi
      ;;
  esac
done < <(git ls-files --cached --others --exclude-standard -z)
exit "$status"
