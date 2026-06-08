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

# Cache layout — the image owns this knowledge so callers (skills) don't have
# to set env per-call. Convention: the cluster mounts a shared cache PVC at
# /cache, and each review-image keeps its own subdir there. For go-review:
#   /cache/go-review/gomod        — Go modules (GOMODCACHE)
#   /cache/go-review/gobuild      — Go build artifacts (GOCACHE)
#   /cache/go-review/staticcheck  — staticcheck's own cache
# staticcheck uses os.UserCacheDir() → $XDG_CACHE_HOME/staticcheck on Linux,
# so pointing XDG_CACHE_HOME at /cache/go-review gives it the right path
# automatically. Different review-images (python-review, ts-review) get their
# own /cache/<image>/ subtree — no cross-talk.
ENV GOMODCACHE=/cache/go-review/gomod \
    GOCACHE=/cache/go-review/gobuild \
    XDG_CACHE_HOME=/cache/go-review

# Pre-create cache directories. PVC mount root is mode 0755 by default;
# `mkdir -p` is idempotent, safe on repeated container starts.
RUN mkdir -p "$GOMODCACHE" "$GOCACHE" "$XDG_CACHE_HOME/staticcheck"

RUN go version && staticcheck -version && govulncheck -version && golangci-lint version
WORKDIR /work
