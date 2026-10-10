---
name: doc-audit
description: Check existing Fabric-X Migrate documentation and agent guidance for drift after changes to commands, tests, workflows, or migration behavior.
---

# Documentation audit

Start from the diff, including untracked files when they belong to the task.
Extract changed flags, paths, Make targets, environment variables, supported
inputs, and policy behavior. Check references to those names in `README.md`,
`CONTRIBUTING.md`, `hack/README.md`, `AGENTS.md`, `.bob/skills/`, and workflow files.

Compare commands with `internal/cmd/main.go` and `make help`. Compare test setup
with `.github/workflows/test.yml` and the integration tests' opt-in conditions.
Compare release claims with `.github/workflows/release.yml` and `Dockerfile`.

This repository has no generated CLI-documentation or metrics-documentation
targets. Do not invoke the committer's generators here.

Preserve the README's verification limits. Record counts do not prove state
equality. Build checks do not prove release publication. Report mismatches with
file and line locations. Apply text corrections only within an authorized edit.
