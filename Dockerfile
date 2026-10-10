# Copyright the Hyperledger Fabric contributors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

ARG GO_IMAGE_TAG=1.26.9
FROM --platform=$BUILDPLATFORM golang:${GO_IMAGE_TAG} AS builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG TARGETOS
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOFLAGS=-trimpath make build

FROM registry.access.redhat.com/ubi9/ubi-minimal:9.8

ARG VERSION=dev
ARG CREATED
ARG REVISION

RUN /usr/sbin/useradd -u 10001 -r -g root -s /sbin/nologin migrate && \
    mkdir -p /home/migrate && chown 10001:0 /home/migrate

COPY --from=builder /src/artifacts/bin/fabric-x-migrate /usr/local/bin/fabric-x-migrate

LABEL org.opencontainers.image.created="${CREATED}" \
    org.opencontainers.image.description="Classic Fabric snapshot migration to Fabric-X." \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.revision="${REVISION}" \
    org.opencontainers.image.source="https://github.com/hyperledger/fabric-x-migrate" \
    org.opencontainers.image.title="fabric-x-migrate" \
    org.opencontainers.image.version="${VERSION}"

USER 10001
WORKDIR /home/migrate

ENTRYPOINT ["/usr/local/bin/fabric-x-migrate"]
