# syntax=docker/dockerfile:1
#
# go-review — a Go toolchain image bundling the static-analysis battery used by
# the inverted code-review (tools judge, model reports). Multi-stage: a builder
# compiles the analysis tools, the final image keeps only the Go toolchain +
# the tool binaries (no go-install module/build caches). Small image = fast,
# reliable pulls on any node through the registry proxy.
#
# `go build` / `go vet` / `staticcheck` / `golangci-lint` / `govulncheck` run
# as-is; `go test -race` needs cgo + a C toolchain (gcc + musl-dev below).
#
# run_job image for mr-code-review-v2 layer A: clone the MR branch, run the
# battery, feed the deterministic output back as findings.

# ── builder: compile the pinned analysis tools, discard all build scratch ──────
FROM golang:1.26-alpine AS build
ENV GOBIN=/tools
RUN go install honnef.co/go/tools/cmd/staticcheck@v0.7.0 \
 && go install golang.org/x/vuln/cmd/govulncheck@v1.3.0 \
 && go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.12.2

# ── final: Go toolchain (needed for build/vet/test) + tool binaries only ───────
FROM golang:1.26-alpine
# git: go buildinfo. gcc+musl-dev: required to link `go test -race`. bash: nicer sh.
RUN apk add --no-cache git gcc musl-dev bash
COPY --from=build /tools/ /usr/local/bin/
RUN go version && staticcheck -version && govulncheck -version && golangci-lint version
WORKDIR /work
