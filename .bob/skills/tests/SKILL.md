---
name: tests
description: Select and run Fabric-X Migrate unit, database, snapshot, and deployment tests.
---

# Migration tests

Unit tests live beside the code in `internal/cmd/`, `internal/fabricsnapshot/`, and
`internal/migrate/`. Use `make test` or a focused `go test ./internal/PACKAGE -run '^TestName$'`.

Integration tests require the `integration` build tag. Select the suite that covers
the change before starting infrastructure:

| Suite | Prerequisites | What it checks |
| --- | --- | --- |
| `TestImport` | A disposable database URL | Imported rows, collisions, rollback, and concurrent imports |
| `TestFabricSnapshots` | `make build runtime-binaries`, Docker, database URL, `FABRIC_X_MIGRATION_TEST_FABRIC=1` | LevelDB and CouchDB snapshots, CLI imports, committer startup, and authorization |
| `TestDeployment` | `make acceptance-binaries`, Docker, both database URLs and container IDs, `FABRIC_X_MIGRATION_TEST_DEPLOYMENT=1` | Arma consensus, two organizations, backup, and recovery |

`FABRIC_X_MIGRATION_TEST_DATABASE_URL` accepts a disposable PostgreSQL or
YugabyteDB server. Set `FABRIC_X_MIGRATION_TEST_YUGABYTE_DATABASE_URL` to test
another YugabyteDB server in the same run.
Deployment also needs `FABRIC_X_MIGRATION_TEST_POSTGRES_CONTAINER` and
`FABRIC_X_MIGRATION_TEST_YUGABYTE_CONTAINER` for native backup tools.

See `CONTRIBUTING.md` for focused commands and `.github/workflows/test.yml` for the
complete CI setup. `docker/compose.test.yaml` pins both database images and enables
YugabyteDB transactional DDL. To run the full suite, use the workflow's environment
and `make test-integration` after building the acceptance binaries.

Check the verbose output for skipped tests. A passing run without the opt-in flags
does not prove snapshot or deployment acceptance. The source tests start and remove
disposable Docker networks. Do not point these tests at a database containing user data.
