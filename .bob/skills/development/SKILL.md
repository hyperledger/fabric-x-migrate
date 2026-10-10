---
name: development
description: Navigate Fabric-X Migrate snapshot parsing and import code and choose checks for changes to migration behavior.
---

# Migration implementation

Start with the affected boundary:

- CLI inputs and report output: `internal/cmd/main.go` and `main_test.go`.
- Snapshot metadata, file hashes, and streamed records: `internal/fabricsnapshot/`.
- Mapping and policy conversion: `internal/migrate/config.go` and `config_test.go`.
- Input identity checks: `internal/migrate/inputs.go`.
- Transactional writes and reports: `internal/migrate/import.go` and `system.sql`.

Read the relevant README section before changing accepted inputs or policies.
The importer validates inputs before writing, imports in one serializable
transaction, then rechecks source files before commit. Preserve those boundaries
when moving validation or database operations.

The committer schema and services come from the version pinned in `go.mod`.
Inspect that dependency when changing SQL or runtime setup. The sibling committer
checkout may be on a different version.

Use `make basic-checks` and the affected unit tests. For changes to writes, rollback,
or policies, consult the `tests` skill for the database or live snapshot suite.
Record whether validation used real databases and services or only local unit tests.
