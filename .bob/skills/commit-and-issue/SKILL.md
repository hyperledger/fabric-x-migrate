---
name: commit-and-issue
description: Prepare Fabric-X Migrate commit messages, pull request descriptions, and issues using this repository's contribution workflow.
---

# Contribution messages

Inspect the staged diff and recent commit subjects before drafting a message.
This repository uses Conventional Commit subjects. Keep each commit focused on
one change that can be reviewed independently. See `CONTRIBUTING.md` for checks
and sign-off requirements.

Use `.github/pull_request_template.md` for PR descriptions. Keep its sections and
replace the placeholder text. Link the issue with `resolves #N` only when the
change finishes that issue. Explain incomplete validation when it affects review.

For bug reports, describe the observed behavior, expected behavior, and steps to
reproduce. For feature requests, explain the intended outcome and scope.

The upstream repository is `hyperledger/fabric-x-migrate`. Inspect Git remotes
before preparing a push or PR command. Do not assume `origin` is a fork.
Posting, pushing, and other remote writes require authorization for that action.

DCO checks require a `Signed-off-by` trailer. Give the user a `git commit -s`
command with the drafted message. Do not run `git commit` on their behalf and
do not add `Co-Authored-By` trailers.
