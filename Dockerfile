# syntax=docker/dockerfile:1
#
# go-review — a Go toolchain image bundling the static-analysis battery used by
# the inverted code-review (tools judge, model reports). Built on the official
# golang image so `go build` / `go vet` / `go test -race` work out of the box,
# plus pinned analysis tools installed into GOBIN (/usr/local/bin).
#
# Used as the run_job image for mr-code-review-v2 layer A: clone the MR branch,
# run the battery, feed the deterministic output back as findings.

FROM golang:1.26-bookworm@sha256:5d2b868674b57c9e48cdd39e891acce4196b6926ca6d11e9c270a8f85106203d

# Tools pinned to exact versions so the battery can't drift on rebuild. Installed
# with the image's Go into a shared bin on PATH. git is already in the base.
# staticcheck module v0.7.0 == release 2026.1.
ENV GOBIN=/usr/local/bin
RUN go install honnef.co/go/tools/cmd/staticcheck@v0.7.0 \
 && go install golang.org/x/vuln/cmd/govulncheck@v1.3.0

# golangci-lint via its official installer (bundles many linters; building from
# source pulls a huge dep tree). Pinned version + checksum-verified by the script.
ARG GOLANGCI_VERSION=v2.12.2
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
    | sh -s -- -b /usr/local/bin ${GOLANGCI_VERSION}

# Sanity: every tool resolves on PATH.
RUN go version && staticcheck -version && govulncheck -version && golangci-lint version

WORKDIR /work
