# Contributing

## Local development setup

Clone the repository and run the commands below from its root.

Install Git, Make, and Python 3 with venv support. Integration tests also need
Docker with Compose. Use the Go version in [.go-version](.go-version), which
matches `go.mod` and the Docker builder image. Update all three together when
changing Go versions. CI reads its Go version from `go.mod`.

Install and activate either [goenv](https://github.com/syndbg/goenv)
or [mise](https://mise.jdx.dev/getting-started.html) in your shell.

With goenv:

```sh
goenv install
go version
```

With mise, enable Go version files once in your user configuration, then install
the version selected by this checkout:

```sh
mise settings add idiomatic_version_file_enable_tools go
mise install go
go version
```

See [mise's Go guide](https://mise.jdx.dev/lang/go.html#version-files) for version
file support. Confirm that `go version` matches `.go-version`, then build:

```sh
make build
```

## Before submitting a change

Run the same checks and unit tests as CI:

```sh
make basic-checks
make test
```

The checks cover license headers, DCO sign-offs, formatting, dependencies, lint,
and the CLI build. They fetch pinned Go tools and install Python tools in
`artifacts/tools/`. Unit tests run with race detection. Use `make help` for other
targets.

For editor integration or a direct lint run, you can also install the
`GOLANGCI_LINT_VERSION` pinned in the Makefile through
[mise](https://mise.jdx.dev/registry.html):

```sh
mise install golangci-lint@2.13.1
mise exec golangci-lint@2.13.1 -- golangci-lint run
```

Sign off each commit with `git commit -s` for the
[Developer Certificate of Origin](https://developercertificate.org/).
`make check-dco` checks commits after `origin/main`. Set `DCO_BASE_REF` when
targeting another branch. Describe the resulting behavior and validation in
the pull request, including any tests you could not run.

## Integration tests

Use disposable databases. These tests create and drop databases, and the
deployment suite performs backup and restore. Check verbose output for skipped
tests. A passing run without the opt-in flags does not exercise the snapshot or
deployment suites.

Start the pinned PostgreSQL and YugabyteDB fixtures when needed:

```sh
docker compose -f docker/compose.test.yaml up -d --wait --wait-timeout 180
```

The commands below show focused suites. To run the full CI suite, build with
`make acceptance-binaries`, use the environment variables and database container
IDs from [.github/workflows/test.yml](.github/workflows/test.yml), then run
`make test-integration`.

### Database imports

The database test uses two independent databases and covers public state, both
hash destinations, consolidation, collision rollback, repeated imports, and
concurrent imports. It compares actual rows within the test; this does not add a
verification algorithm to the CLI.

```sh
FABRIC_X_MIGRATION_TEST_DATABASE_URL='postgres://postgres@localhost:25432/postgres?sslmode=disable' \
go test -tags=integration ./internal/migrate -run '^TestImport$' -count=1 -v
```

Use a disposable PostgreSQL or YugabyteDB server with permission to create and
drop test databases. YugabyteDB requires the tserver setting
`ysql_yb_ddl_transaction_block_enabled=true` for atomic table creation and import;
the CLI checks this before writing. See [YugabyteDB transactional DDL](https://docs.yugabyte.com/stable/explore/transactions/transactional-ddl/).
The Compose fixtures pin PostgreSQL 16.13 and YugabyteDB 2025.2.0.1-b1 and enable
that YugabyteDB setting.

### Snapshot and startup tests

The live Fabric 3.1.5 suite covers these mappings with both LevelDB and CouchDB:

| Source mapping | Hash destination |
| --- | --- |
| One channel | No hashes, with public state, or in a separate namespace |
| Two channels, separate application namespaces | No hashes, with public state, or in separate hash namespaces |
| Two channels, one shared application namespace | No hashes, with public state, or in one separate hash namespace |

Each of the 18 cases runs the CLI against two independent, empty databases with
identical inputs. Tests compare every imported key, value, hash, version, and
record count against the known source writes. They then start the upstream
Fabric-X committer services with the upstream mock orderer against one imported
database, check exact application reads and private-key exclusion, update public
and hash rows using the source peer
identity, and reject writes from a source administrator in every destination
namespace. Collection hash collisions must roll back with either hash destination.

The source-network harness and Fabric configuration are under `hack/` and
`internal/integrationtest/`. See [the manual network guide](hack/README.md) to
capture snapshots by hand. `make stop-hack` deletes that network's volumes.

To run the complete real-snapshot and Fabric-X startup matrix:

```sh
make build runtime-binaries
FABRIC_X_MIGRATION_TEST_FABRIC=1 \
FABRIC_X_MIGRATION_TEST_DATABASE_URL='postgres://postgres@localhost:25432/postgres?sslmode=disable' \
go test -tags=integration ./internal/migrate -run '^TestFabricSnapshots$' -count=1 -timeout=20m -v
```

This starts and removes a disposable Fabric network. It reuses the pinned
`fabric-samples` checkout and includes a small test contract that writes one
public value and one value in a private collection per channel. The startup
checks are part of this suite; there is no separate runtime opt-in flag.

### Deployment and recovery acceptance

`TestDeployment` uses the pinned Fabric-X Arma orderer (`v1.0.1`), with four
parties and one shard. Two organizations run independent committer service sets,
use different MSP identities for block delivery, and import into separate
databases. The test imports public state and separate hash namespaces from two
real Classic channels, then checks reads, authorized writes, and rejected writes
on both organizations.

After target writes, the test stops one organization's services and backs up its
database and sidecar ledger. It uses PostgreSQL's `pg_dump`/`psql` or YugabyteDB's
`ysql_dump`/`ysqlsh` inside the configured database container. While that
organization is stopped, the other commits more writes. The test restores into
a fresh database, starts services from the saved ledger, checks catch-up from
Arma, and submits another write to both organizations. Assertions cover exact
keys, values, versions, private-key exclusion, and transaction status.

Run both database backends with their existing disposable containers. Set the
container variables to the corresponding container names or IDs:

```sh
make acceptance-binaries
FABRIC_X_MIGRATION_TEST_DEPLOYMENT=1 \
FABRIC_X_MIGRATION_TEST_DATABASE_URL='postgres://postgres@localhost:25432/postgres?sslmode=disable' \
FABRIC_X_MIGRATION_TEST_YUGABYTE_DATABASE_URL='postgres://yugabyte@localhost:25433/yugabyte?sslmode=disable' \
FABRIC_X_MIGRATION_TEST_POSTGRES_CONTAINER="$(docker compose -f docker/compose.test.yaml ps -q postgres)" \
FABRIC_X_MIGRATION_TEST_YUGABYTE_CONTAINER="$(docker compose -f docker/compose.test.yaml ps -q yugabyte)" \
go test -tags=integration ./internal/migrate -run '^TestDeployment$' -count=1 -timeout=20m -v
```

The CI integration job in `.github/workflows/test.yml` runs this scenario against
both database services alongside the full snapshot matrix. The Arma deployment
uses real BFT consensus and internal TLS. External orderer and committer connections use
localhost without TLS. This test does not cover production certificate rotation,
consensus fault injection, or recovery without the saved sidecar ledger.

When finished, remove the test databases and their volumes:

```sh
docker compose -f docker/compose.test.yaml down --volumes --remove-orphans
```

## CI and releases

Pull requests and pushes to `main` and `release/**` run separate workflows:

- `verify-build.yml` runs `make basic-checks` and builds release archives and the
  multi-platform container image.
- `test.yml` runs unit tests and the complete snapshot, import, deployment, and
  recovery suite against disposable PostgreSQL and YugabyteDB containers.
- `codeql.yml` scans Go code and GitHub Actions workflows.

`make build-release` creates Linux archives for amd64, arm64, and
s390x, plus macOS archives for amd64 and arm64, with `SHA256SUMS` in
`artifacts/release/`.

The container build compiles the CLI from source in a Go builder stage. It does
not require local release artifacts:

```sh
docker build -t fabric-x-migrate:local .
```

The runtime uses UBI minimal 9.8 and runs as user `10001`, following the Fabric-X
orderer and committer images. The release workflow supplies the version, revision,
and creation time for the image labels. Local builds default to version `dev`
and leave the revision and creation time empty.

Pushing a version tag such as `v1.0.0` publishes those archives as a GitHub release
and pushes Linux images to `docker.io/hyperledger/fabric-x-migrate` and
`ghcr.io/hyperledger/fabric-x-migrate`. Prerelease tags such as `v1.0.0-rc.1` create
prereleases and do not update the `latest` image tag. The Docker Hub publish step
requires the repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`.
For forks, Docker Hub uses `DOCKERHUB_USERNAME` as the namespace, and GHCR uses
the GitHub repository owner.

All workflows support manual runs. A manual `release.yml` run builds the archives
and images and uploads the archives as workflow artifacts. It does not publish a
GitHub release or push images.
