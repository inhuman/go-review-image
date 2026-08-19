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
| `gopls` | v0.23.0 | type-aware navigation: references, implementations, diagnostics |
| `go-impact` | in-image | changed declarations + **their callers outside the diff** |

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

## `go-impact` — the question a diff cannot answer

A diff shows changed lines. It cannot show *who else calls the thing you
changed*, because the caller lives in a file the diff does not contain. The
compiler stays silent about it too — the code keeps building right up until the
change is carried to half of the callers, and the other half fails at runtime
or, worse, keeps compiling against a changed meaning.

`go-impact` answers it deterministically, by types rather than by text:

```bash
docker run --rm -v "$PWD:/work" idconstruct/go-review:latest \
  go-impact origin/main
```

```
== IMPACT ==
база: origin/main   изменённых .go (без тестов): 25
  internal/agent/skillengine_path.go: (*Orchestrator).tryRunSkillFlow (Method) — вызывающих ВНЕ дельты: 1, в тестах: 14
    internal/agent/orchestrator_run.go:327:17
  internal/agent/skillengine_assets.go: (*assetResolver).Resolve (Method) — вне дельты не используется (в тестах: 0)
EXIT=0
```

Two signals, both actionable: a changed declaration with callers outside the
delta is a place the reviewer must look at; a changed declaration with **no**
callers outside and none in tests is either dead code or a museum piece.

Cost on a 67-package module: ~8s for 12 declarations, with the gopls workspace
cache warm on the shared `/cache` volume (~1.5s cold for the first lookup).

Caveats, stated so the report is not over-read: only top-level declarations are
tracked, `_test.go` files are not scanned for changes (their references are
counted), and a declaration's span is taken as "up to the next declaration",
since gopls reports the range of the *name*, not of the body. Exit code 2 means
the tool did **not** run — an empty report then means nothing.

## License

MIT.
