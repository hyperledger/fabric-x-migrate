# Fabric-X Migrate

This CLI imports Classic Fabric snapshots into a Fabric-X committer database.
Read `README.md` for the mapping rules, supported policies, and verification limits.
See `CONTRIBUTING.md` for local setup, checks, and integration test commands.
Use the Go version in `.go-version` and `go.mod`.

## Where to work

- `cmd/fabric-x-migrate/main.go` starts the CLI. `internal/cmd/` parses flags and prints the report.
- `internal/fabricsnapshot/` reads and validates Classic snapshot files.
- `internal/migrate/` resolves policies and mappings and imports state in one transaction.
- `internal/integrationtest/` creates disposable Classic networks and captures snapshots.
- `hack/` contains the manual source-network setup. `docker/compose.test.yaml` provides test databases.
- `.github/workflows/` separates build checks, tests, CodeQL, and releases.

## Checks and skills

Run `make basic-checks` for license headers, DCO sign-offs, goimports/gofumpt,
module tidiness, YAML and SQL lint, workflow validation, Go lint, and the CLI build.
It installs pinned tools under `artifacts/tools/` and needs Python 3 with venv.
Run `make test` for unit tests with race detection. These are the CI targets.

Use `.bob/skills/tests/SKILL.md` when selecting or running migration tests.
Use `.bob/skills/development/SKILL.md` when changing snapshot parsing or imports.
Use the `commit-and-issue`, `pr-review`, and `doc-audit` skills for contribution
messages, migration reviews, and checking documentation after a change.
Claude reads the same skills through `.claude/skills`. `CLAUDE.md` and
`.bob/rules/01-project-guidelines.md` link to this file.

Use disposable databases for integration tests. The tests create and drop databases
and the deployment suite exercises backup and restore. `make stop-hack` deletes
the manual source network's volumes.

## Release checks

`make build-release` creates static Linux and macOS binary archives and SHA-256
checksums under `artifacts/release/`. The root `Dockerfile` builds the CLI from
source and copies it into a UBI minimal runtime image running as user `10001`.
Pull requests build the archives and multi-platform image. Version tags publish
them through `release.yml`. Manual release runs build and upload workflow artifacts
without publishing a GitHub release or pushing images.

Never run `git commit` on the user's behalf. Never add `Co-Authored-By` trailers.
