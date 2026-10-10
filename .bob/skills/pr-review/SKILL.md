---
name: pr-review
description: Review Fabric-X Migrate pull requests for migration correctness, compatibility, and missing validation.
---

# Migration review

Read the actual diff and affected callers. Preserve the checkout and keep the
review read-only unless the user also requested fixes. Use
`hyperledger/fabric-x-migrate` for upstream PR metadata.

Follow inputs from `internal/cmd/` through `internal/fabricsnapshot/` and
`internal/migrate/`. Check whether the change preserves source hash and identity
checks, policy meaning, collision detection, transaction rollback, and the final
source-file recheck. Compare committer schema assumptions with the dependency
version in `go.mod`.

Use the `tests` skill to identify which suites exercise the changed behavior.
Distinguish local unit checks, database checks, live snapshot/deployment tests,
and hosted CI evidence. A skipped integration suite is not acceptance proof.

Report concrete failures with file and line locations, their trigger, and their
effect. Keep optional cleanup separate from correctness findings. Return comments
in chat. Post them to GitHub only when the user explicitly requests it.
