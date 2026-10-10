# Fabric to Fabric-X migration PoC

A standalone Go CLI for the
[Fabric Classic snapshot migration RFC](https://github.com/syndbg/fabric-x-rfcs/blob/feat-fabric-snapshot-migration/0003-fabric-x-snapshot-migration.md).
It streams official peer snapshots directly into each organization's committer
database. It imports public keys and private-data hashes at version `0`, reuses
source MSPs and endorsement policies, and maps source channels and namespaces
into a target network.

The CLI uses upstream Fabric-X database and policy helpers. It does not require
committer changes. Block history, transaction IDs, private values, and source key
versions are not imported. There is no migration bundle or migration state table.

## Run an import

For local setup, see [CONTRIBUTING.md](CONTRIBUTING.md#local-development-setup).
Build the CLI:

```sh
make build
```

1. Stop writes on the source channels and wait for pending transactions to finish.
   Capture the agreed peer snapshots and the channel configuration effective at
   each checkpoint. Confirm the source configuration using trusted channel records.
2. Agree on target membership, ordering settings, administrative policies, and
   namespace mappings. Prepare the target configuration offline.
3. Stop committer services and all other target database writers. Keep the
   databases running. The target must not have accepted application transactions,
   and every mapped application namespace must be empty.
4. Run the same import independently for each organization, changing only the
   database connection.
5. Compare the source identities, mappings, resolved configuration, policies, and
   database record counts in the reports before starting services. Check application
   reads and authorization before enabling application traffic.

`mappings.json`, for one channel:

```json
{
  "target_network": "network1",
  "mappings": [
    {
      "source_channel": "assets",
      "source_namespace": "basic",
      "target_namespace": "assets_basic"
    }
  ]
}
```

```sh
PGPASSFILE=./postgres.pass \
./artifacts/bin/fabric-x-migrate import \
  --snapshot assets=./snapshots/assets \
  --source-config assets=./config/assets.block \
  --mapping mappings.json \
  --target-config ./config/network1.config \
  --database-url 'postgres://migration@db.org1.example:5432/committer?sslmode=verify-full' \
  > org1-import.json
```

pgx supports the standard PostgreSQL password file through `PGPASSFILE`.

`--source-config` accepts a CONFIG block from `peer channel fetch config`. Its
channel must match the snapshot, and its block number must not exceed the
snapshot checkpoint. This check cannot establish that a supplied configuration
was the latest one at that checkpoint; operators must confirm that separately.

`--target-config` accepts a standard initial Fabric-X CONFIG envelope or config
block, with the target channel ID, ordering settings, and administrative and
system namespace policies. The tool adds missing source application MSPs and
rejects conflicting MSP definitions. It validates the resolved configuration and
application namespace policies with the upstream committer code before writing.
Signing keys are not inputs.
Target channel capabilities must support at least the source MSP version;
otherwise migration fails before writing, since older MSP versions can disable
source peer and admin role checks.

The JSON report includes the resolved standard CONFIG envelope as Base64 in
`target_config_envelope`. Save it for the target's offline startup configuration:

```sh
jq -r .target_config_envelope org1-import.json | base64 --decode > resolved.config
```

This envelope contains public configuration. Keep target service configuration
consistent with it. Writing this envelope into the committer database does not
start any service or submit namespace-creation transactions.

## Consolidate channels

Add one `--snapshot CHANNEL=DIR` and `--source-config CHANNEL=BLOCK` pair for each
source channel. Every mapping identifies its source channel, so equally named
source namespaces remain distinct.

```json
{
  "target_network": "network1",
  "mappings": [
    {
      "source_channel": "assets",
      "source_namespace": "basic",
      "target_namespace": "assets_basic",
      "target_hash_namespace": "assets_hashes"
    },
    {
      "source_channel": "securities",
      "source_namespace": "basic",
      "target_namespace": "securities_basic"
    }
  ]
}
```

```sh
PGPASSFILE=./postgres.pass \
./artifacts/bin/fabric-x-migrate import \
  --snapshot assets=./snapshots/assets \
  --source-config assets=./config/assets.block \
  --snapshot securities=./snapshots/securities \
  --source-config securities=./config/securities.block \
  --mapping mappings.json \
  --target-config ./config/network1.config \
  --database-url 'postgres://migration@db.org1.example:5432/committer?sslmode=verify-full' \
  > org1-import.json
```

To share a target namespace, set both `target_namespace` fields to the same ID.
Their effective endorsement policies must match and their keys must not overlap.
A duplicate target key fails the import even when the values are identical.

Without `target_hash_namespace`, public records and collection hash records share
`target_namespace`. With it, all hashes from that source namespace go to the
specified application namespace. Hash bytes are preserved: the source key hash
becomes the target key, and the source value hash becomes the target value.
There is no new key encoding or collection mapping.

A separate hash namespace does not hide records from network members. Channel
consolidation changes who can see public records and hashes. It also cannot
resolve duplicate hash keys between collections mapped to the same destination.

## Validation and database writes

The reader checks snapshot metadata, SHA-256 file hashes, file pairs, record
framing, and source record order. It supports the official SimpleKeyValueDB and
CouchDB snapshot formats. It reads records with bounded memory and discards
source key versions after checking them.

The tool reads selected committed `_lifecycle` or legacy `lscc` definitions,
resolves endorsement policy references in their original source channel, and reuses collection
endorsement policies where present. It rejects unsupported validation plugins,
conflicting namespace policies, and key-level metadata it cannot preserve.
Unmapped application state and lifecycle state are not copied into application
tables.

For modern chaincode, the tool reads the committed `_lifecycle` definition's
`ValidationInfo` and `Collections` fields from the snapshot. For legacy chaincode,
it reads the `lscc` definition. An explicit signature policy retains its rule
order. A channel-policy reference is resolved against that source channel's
configuration, before channels are consolidated.

Fabric builds implicit-meta policies by iterating over a map of organization
subpolicies. Each subpolicy independently evaluates the full endorsement set, so
the same endorsement can satisfy more than one subpolicy. The importer can
therefore merge these overlapping branches without changing which endorsements
are accepted:

| Implicit-meta policy | Equivalent policy |
| --- | --- |
| `ALL(P, P)` | `P` |
| `ANY(P, P)` | `P` |
| `ALL(Org1.peer, Org1.member)` | `Org1.peer` |

Here, `P` is the same complete policy, including its ordered rules and
principals. Evaluating it twice against the same endorsements produces the same
result. A peer also satisfies the member requirement in the same MSP, so that
member branch adds no requirement under implicit `ALL`.

The importer applies these rewrites recursively at implicit-meta boundaries.
It removes duplicate branches under `ALL` and `ANY`, adjusts `ALL` to require
every remaining branch, and removes a single-member branch under `ALL` when a
single-peer branch from the same MSP is present. If one branch remains, it
replaces the implicit-meta rule. The importer then makes the order of remaining
independent branches deterministic. Multiple remaining branches must use role
principals from distinct MSPs, or conversion is rejected before database writes.

These rewrites never simplify explicit signature policies. Fabric consumes
identities in rule order inside those policies. Explicit
`AND(Org1.peer, Org1.member)` still requires two identities and retains its rule
order. Thresholds between `ANY` and `ALL` are not deduplicated: implicit
`2-of(P, P, Q)` counts two successful branches when `P` succeeds, while
`2-of(P, Q)` requires both policies. Overlaps outside the supported rewrites
remain unsupported, even when another equivalent policy might exist.

After preflight validation, the tool creates missing namespace tables and their
normal committer functions, writes MSP configuration and namespace policies, and
inserts bounded batches in one serializable transaction. It uses the normal
configuration row to serialize imports. Database constraints reject duplicate
keys. Errors roll back all changes made by that transaction.

Before committing, it checks database row counts and version `0`, then rechecks
all source files, configuration, and mappings for changes. A successful report
contains source identities, resolved configuration, policies, mappings, and
counts read from the database. Repeated imports into nonempty namespaces fail.
Save source inputs and take a database backup before accepting target writes;
Fabric-X block history cannot reconstruct the imported rows.

## Verification status

The Fabric-X database state digest feature is being implemented separately and
is **not available yet**. This PoC does not compute a custom digest or provide a
fallback. Record counts alone do not establish state equality across committers.
Once the separate feature is available, use it to compare database state across
committers.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for local setup, checks, integration
tests, CI, and releases.
