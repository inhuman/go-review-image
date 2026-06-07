# go-review

A Go toolchain image bundling a static-analysis battery for **deterministic code
review** — the "tools judge, model reports" approach.

Built on the official `golang` image, so `go build` / `go vet` / `go test -race`
work as-is, plus pinned analysis tools on `PATH`:

| Tool | Version | Catches |
|---|---|---|
| `go build` | image Go | compile errors, type/interface mismatches |
| `go vet` | image Go | suspicious constructs (shadow, Printf, lost cancel) |
| `go test -race` | image Go | real data races, failing tests |
| `staticcheck` | 2026.1 (v0.7.0) | bugs, dead code, simplifications |
| `golangci-lint` | v2.12.2 | aggregated linters (configurable per-repo) |
| `govulncheck` | v1.3.0 | known vulnerabilities in dependencies |

## Why

LLM code reviewers hallucinate confident-but-false claims ("won't compile",
"deadlock", "does not implement"). The fix isn't a better prompt — it's making
**deterministic tools the source of truth** and the model a translator of their
output. This image is that source of truth for Go: clone the branch, run the
battery, feed the real output back as findings.

## Usage

```bash
docker run --rm -v "$PWD:/work" idconstruct/go-review:latest sh -c '
  go build ./...        2>&1; echo "BUILD=$?"
  go vet ./...          2>&1; echo "VET=$?"
  staticcheck ./...     2>&1; echo "STATICCHECK=$?"
  golangci-lint run     2>&1; echo "LINT=$?"
  go test -race ./...   2>&1; echo "RACE=$?"
  govulncheck ./...     2>&1; echo "VULN=$?"
'
```

Each tool's non-zero exit + output is a deterministic finding. A clean run is a
strong positive signal.

## License

MIT.
