# Copyright the Hyperledger Fabric contributors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

SHELL := /bin/sh

FABRIC_VERSION ?= 3.1.5
STATE_DATABASE ?= goleveldb
CHANNEL ?= migration
FABRIC_SAMPLES_COMMIT := $(shell cat fabric-samples.commit)
GOLANGCI_LINT_VERSION ?= v2.13.1
ACTIONLINT_VERSION ?= v1.7.12
GOIMPORTS_VERSION ?= v0.43.0
GOFUMPT_VERSION ?= v0.9.2
TOOLS_DIR := $(CURDIR)/artifacts/tools
PYTHON ?= python3
RELEASE_PLATFORMS ?= linux/amd64 linux/arm64 linux/s390x darwin/amd64 darwin/arm64
FABRIC_X_ORDERER_VERSION := v1.0.1

HACK_DIR := $(CURDIR)/hack
FABRIC_SAMPLES := $(HACK_DIR)/fabric-samples
FABRIC_RELEASE := $(HACK_DIR)/fabric/$(FABRIC_VERSION)
FABRIC_BIN := $(FABRIC_RELEASE)/bin
FABRIC_CONFIG := $(FABRIC_RELEASE)/config
FABRIC_ARCHIVE := $(HACK_DIR)/hyperledger-fabric-$(shell go env GOOS)-$(shell go env GOARCH)-$(FABRIC_VERSION).tar.gz
HACK_COMPOSE := docker compose -f $(HACK_DIR)/compose.yaml
HACK_BLOCK := $(HACK_DIR)/$(CHANNEL).block
ORDERER_CA := $(HACK_DIR)/crypto/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
ORDERER_CERT := $(HACK_DIR)/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
ORDERER_KEY := $(HACK_DIR)/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key
PEER_CA := $(HACK_DIR)/crypto/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
PEER_MSP := $(HACK_DIR)/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
ORDERER_ADMIN_ARGS := -o localhost:18053 --ca-file $(ORDERER_CA) --client-cert $(ORDERER_CERT) --client-key $(ORDERER_KEY)
PEER_ENV := FABRIC_CFG_PATH=$(FABRIC_CONFIG) CORE_PEER_TLS_ENABLED=true CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_MSPCONFIGPATH=$(PEER_MSP) CORE_PEER_ADDRESS=localhost:18051 CORE_PEER_TLS_ROOTCERT_FILE=$(PEER_CA)

.PHONY: help build build-release basic-checks check-format check-deps check-license check-dco lint-yaml lint-sql lint-workflows runtime-binaries acceptance-binaries test test-integration lint lint-fix hack-samples hack-fabric run-hack stop-hack hack-status

help:
	@printf '%s\n' \
		'build             build artifacts/bin/fabric-x-migrate' \
		'build-release     build binary archives and checksums in artifacts/release' \
		'basic-checks      check licenses, DCO, formatting, dependencies, lint, and build' \
		'runtime-binaries  build upstream committer and mock orderer for startup tests' \
		'acceptance-binaries build pinned Arma tools for deployment and recovery tests' \
		'test              run unit tests' \
		'test-integration  run Fabric and direct-import integration tests' \
		'lint              run golangci-lint' \
		'lint-fix          run golangci-lint with safe fixes' \
		'hack-samples      checkout the pinned fabric-samples commit' \
		'hack-fabric       download the selected Fabric release' \
		'run-hack          start and join the local Fabric source network' \
		'stop-hack         stop the local network and delete its volumes' \
		'hack-status       show local network containers'

build:
	@mkdir -p artifacts/bin
	go build -o artifacts/bin/fabric-x-migrate ./cmd/fabric-x-migrate

build-release:
	@mkdir -p artifacts/release
	@set -eu; for platform in $(RELEASE_PLATFORMS); do \
		os=$${platform%/*}; arch=$${platform#*/}; \
		dir=artifacts/release/$$os-$$arch; mkdir -p "$$dir"; \
		CGO_ENABLED=0 GOOS=$$os GOARCH=$$arch go build -trimpath -o "$$dir/fabric-x-migrate" ./cmd/fabric-x-migrate; \
		tar -czf "artifacts/release/fabric-x-migrate-$$os-$$arch.tar.gz" -C "$$dir" fabric-x-migrate; \
	done
	cd artifacts/release && shasum -a 256 fabric-x-migrate-*.tar.gz > SHA256SUMS

basic-checks: check-license check-dco check-format check-deps lint-yaml lint-sql lint-workflows lint build

$(TOOLS_DIR)/goimports:
	GOBIN=$(TOOLS_DIR) go install golang.org/x/tools/cmd/goimports@$(GOIMPORTS_VERSION)

$(TOOLS_DIR)/gofumpt:
	GOBIN=$(TOOLS_DIR) go install mvdan.cc/gofumpt@$(GOFUMPT_VERSION)

check-format: $(TOOLS_DIR)/goimports $(TOOLS_DIR)/gofumpt
	GOIMPORTS=$(TOOLS_DIR)/goimports GOFUMPT=$(TOOLS_DIR)/gofumpt bash scripts/check-format.sh

check-license:
	bash scripts/check-license.sh

check-dco:
	bash scripts/check-dco.sh

check-deps:
	@mkdir -p artifacts
	@set -eu; dir=$$(mktemp -d artifacts/check-deps.XXXXXX); \
		trap 'rm -rf "$$dir"' EXIT; \
		cp go.mod go.sum "$$dir/"; \
		go mod tidy -modfile="$$dir/go.mod"; \
		diff -u go.mod "$$dir/go.mod"; diff -u go.sum "$$dir/go.sum"

$(TOOLS_DIR)/venv/.installed: scripts/requirements-dev.txt
	$(PYTHON) -m venv $(TOOLS_DIR)/venv
	$(TOOLS_DIR)/venv/bin/pip install -r scripts/requirements-dev.txt
	touch $@

lint-yaml: $(TOOLS_DIR)/venv/.installed
	git ls-files --cached --others --exclude-standard -z '*.yaml' '*.yml' | xargs -0 $(TOOLS_DIR)/venv/bin/yamllint

lint-sql: $(TOOLS_DIR)/venv/.installed
	git ls-files --cached --others --exclude-standard -z '*.sql' | xargs -0 $(TOOLS_DIR)/venv/bin/sqlfluff lint --dialect postgres

lint-workflows:
	go run github.com/rhysd/actionlint/cmd/actionlint@$(ACTIONLINT_VERSION)

runtime-binaries:
	@mkdir -p artifacts/runtime/bin
	go build -o artifacts/runtime/bin/committer github.com/hyperledger/fabric-x-committer/cmd/committer
	go build -o artifacts/runtime/bin/mock github.com/hyperledger/fabric-x-committer/cmd/mock

acceptance-binaries: build runtime-binaries
	GOBIN=$(CURDIR)/artifacts/runtime/bin go install github.com/hyperledger/fabric-x-orderer/cmd/arma@$(FABRIC_X_ORDERER_VERSION)
	GOBIN=$(CURDIR)/artifacts/runtime/bin go install github.com/hyperledger/fabric-x-orderer/cmd/armageddon@$(FABRIC_X_ORDERER_VERSION)
	@mkdir -p artifacts/runtime/orderer-sampleconfig
	cp -R "$$(go list -m -f '{{.Dir}}' github.com/hyperledger/fabric-x-orderer@$(FABRIC_X_ORDERER_VERSION))/testutil/fabric/sampleconfig/." artifacts/runtime/orderer-sampleconfig/

test:
	go test -race ./... -count=1 -timeout=5m -v

test-integration:
	go test -tags=integration ./internal/cmd ./internal/migrate -count=1 -timeout=35m -v

lint:
	go run github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION) run

lint-fix:
	go run github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION) run --fix

hack-samples:
	@test -d $(FABRIC_SAMPLES)/.git || git clone --filter=blob:none --depth=1 https://github.com/hyperledger/fabric-samples.git $(FABRIC_SAMPLES)
	@if test "`git -C $(FABRIC_SAMPLES) rev-parse HEAD`" != "$(FABRIC_SAMPLES_COMMIT)"; then git -C $(FABRIC_SAMPLES) fetch --depth=1 origin $(FABRIC_SAMPLES_COMMIT) && git -C $(FABRIC_SAMPLES) checkout --detach $(FABRIC_SAMPLES_COMMIT); fi
	@test "`git -C $(FABRIC_SAMPLES) rev-parse HEAD`" = "$(FABRIC_SAMPLES_COMMIT)"

hack-fabric: $(FABRIC_BIN)/peer

$(FABRIC_BIN)/peer:
	@mkdir -p $(FABRIC_RELEASE)
	curl -fL https://github.com/hyperledger/fabric/releases/download/v$(FABRIC_VERSION)/$(notdir $(FABRIC_ARCHIVE)) -o $(FABRIC_ARCHIVE)
	tar -xzf $(FABRIC_ARCHIVE) -C $(FABRIC_RELEASE)
	rm $(FABRIC_ARCHIVE)

$(HACK_DIR)/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp: $(FABRIC_BIN)/peer
	cd $(HACK_DIR) && $(abspath $(FABRIC_BIN))/cryptogen generate --config=crypto-config.yaml --output=crypto

$(HACK_BLOCK): $(HACK_DIR)/configtx.yaml $(HACK_DIR)/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
	@test -x $(FABRIC_BIN)/configtxgen || { echo 'set FABRIC_BIN to a Fabric release bin directory'; exit 1; }
	cd $(HACK_DIR) && FABRIC_CFG_PATH=$(HACK_DIR) $(abspath $(FABRIC_BIN))/configtxgen -profile MigrationChannel -channelID $(CHANNEL) -outputBlock $(HACK_BLOCK)

run-hack: hack-samples $(HACK_BLOCK)
	FABRIC_VERSION=$(FABRIC_VERSION) STATE_DATABASE=$(STATE_DATABASE) $(HACK_COMPOSE) up -d
	@until $(FABRIC_BIN)/osnadmin channel list $(ORDERER_ADMIN_ARGS) >/dev/null 2>&1; do sleep 1; done
	@$(FABRIC_BIN)/osnadmin channel list $(ORDERER_ADMIN_ARGS) | grep -q $(CHANNEL) || $(FABRIC_BIN)/osnadmin channel join --channelID $(CHANNEL) --config-block $(HACK_BLOCK) $(ORDERER_ADMIN_ARGS)
	@until $(PEER_ENV) $(FABRIC_BIN)/peer channel list >/dev/null 2>&1; do sleep 1; done
	@$(PEER_ENV) $(FABRIC_BIN)/peer channel list | grep -q $(CHANNEL) || $(PEER_ENV) $(FABRIC_BIN)/peer channel join -b $(HACK_BLOCK)

stop-hack:
	FABRIC_VERSION=$(FABRIC_VERSION) STATE_DATABASE=$(STATE_DATABASE) $(HACK_COMPOSE) down --volumes --remove-orphans

hack-status:
	FABRIC_VERSION=$(FABRIC_VERSION) STATE_DATABASE=$(STATE_DATABASE) $(HACK_COMPOSE) ps
