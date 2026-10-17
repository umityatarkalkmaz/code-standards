# Go Standards

Verified: 2026-10-12

| Item | Version | Source |
| --- | --- | --- |
| Go | 1.27 (1.27.2) | https://go.dev/doc/devel/release |
| gofmt / goimports | bundled / `golang.org/x/tools` | https://pkg.go.dev/cmd/gofmt |
| golangci-lint | v2.14 (config `version: "2"`) | https://golangci-lint.run/docs/configuration/ |
| Module layout | official guide | https://go.dev/doc/modules/layout |
| Error wrapping | `%w`, `errors.Is/As` | https://go.dev/blog/go1.13-errors |

> `github.com/golang-standards/project-layout` is **not** an official Go standard and the Go
> team does not endorse it. Use the official module layout guide below.

## Tooling

- Go-based dev tools are tracked per module with the `tool` directive (Go 1.24+), not
  installed globally: `go get -tool golang.org/x/tools/cmd/goimports`, run with
  `go tool goimports`.
- golangci-lint is installed as a pinned binary per its docs (it recommends against
  `go install`/`go tool` for itself). Pin the version in CI and in `Makefile`/scripts.
- `.golangci.yml`:

```yaml
version: "2"

linters:
  default: standard
  enable:
    - bodyclose
    - errname
    - errorlint
    - gosec
    - misspell
    - nilerr
    - revive
    - sqlclosecheck
    - unconvert

formatters:
  enable:
    - gofmt
    - goimports
```

## Project Layout

Follow https://go.dev/doc/modules/layout:

- Commands live in `cmd/<app>/main.go` and stay thin: config, wiring, run.
- Put code in `internal/` unless there is a real external consumer.
- No `pkg/`, `src/` or `utils/` catch-all directories; name packages by what they provide.
- One module per repository unless there is a strong reason for more.

## Naming

No rules beyond the core rules.

## Security Specifics

- Wrap errors with `%w` and context; map internal errors to a public code at the handler.
- SQL via `database/sql` placeholders; processes via `exec.CommandContext(ctx, name, args...)`.
- Confine file access with `os.OpenRoot(root)` / `os.Root` (Go 1.24+), or `filepath.Clean` +
  `filepath.Rel`; `filepath.IsLocal` for relative names.
- HTML via `html/template`.
- HTTP servers set `ReadHeaderTimeout`, `ReadTimeout`, `WriteTimeout`; bodies limited with
  `http.MaxBytesReader`.
- Tokens from `crypto/rand`.

## Testing

No rules beyond the core rules.

## Checklist

- [ ] `go test -race ./...` passes.
