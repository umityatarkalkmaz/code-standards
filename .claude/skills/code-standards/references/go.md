# Go Standards

Verified: 2026-09-24

| Item | Version | Source |
| --- | --- | --- |
| Go | 1.27 | https://go.dev/doc/devel/release |
| gofmt / goimports | bundled / `golang.org/x/tools` | https://pkg.go.dev/cmd/gofmt |
| golangci-lint | v2.14 (config `version: "2"`) | https://golangci-lint.run/docs/configuration/ |
| Module layout | official guide | https://go.dev/doc/modules/layout |
| Error wrapping | `%w`, `errors.Is/As` | https://go.dev/blog/go1.13-errors |

> `github.com/golang-standards/project-layout` is **not** an official Go standard and the Go
> team does not endorse it. Use the official module layout guide below.

## Tooling

- `go.mod` declares the minimum language version; add a `toolchain` line only when a newer
  toolchain is required:

```text
module example.com/project

go 1.27
```

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

- Commands: `golangci-lint fmt`, `golangci-lint run ./...`, `go vet ./...`,
  `go test -race ./...`.

## Project Layout

Follow https://go.dev/doc/modules/layout:

- Small package or command: everything in the module root.
- Command(s) plus shared code:

```text
go.mod
go.sum
cmd/
  <app>/main.go     # thin main: config, wiring, run
internal/           # private packages, not importable from other modules
  <domain>/
<pkg>/              # public packages only if other modules should import them
```

- Put code in `internal/` unless there is a real external consumer.
- No `pkg/`, `src/` or `utils/` catch-all directories; name packages by what they provide.
- One module per repository unless there is a strong reason for more.

## Naming

- `MixedCaps` only, no underscores: exported `FetchUser`, unexported `fetchUser`.
- Functions are Action-Object: `FetchUser`, `ValidateInput`, `parseHeader`.
- Initialisms keep one case: `userID`, `ServeHTTP`, `parseURL`.
- Package names: short, lower-case, singular, no stutter (`user.Service`, not
  `user.UserService`).
- Error variables `ErrNotFound`; error types `NotFoundError`.
- Receivers: short and consistent (`s *Server`), never `this`/`self`.
- Getters without `Get`: `Name()`; setters `SetName()`.

## Security Specifics

- **Errors**: wrap with context, check with `errors.Is/As`, never compare strings:

```go
user, err := repo.FetchUser(ctx, id)
if err != nil {
    return fmt.Errorf("fetch user %d: %w", id, err)
}
```

  Handle every error; never `_ =` an error without a comment. Do not leak internal errors to
  clients; map them to a public message/code at the handler.
- **SQL**: `database/sql` placeholders (`$1`/`?`); never `fmt.Sprintf` SQL. Close `rows`.
- **Shell**: `exec.CommandContext(ctx, name, args...)`; never `sh -c` with input.
- **Paths**: use `os.OpenRoot(root)` / `os.Root` (Go 1.24+) to confine file access, or
  `filepath.Clean` + `filepath.Rel` check; `filepath.IsLocal` for relative names.
- **HTML**: `html/template` (auto-escaping), never `text/template` for HTML.
- **HTTP**: set server timeouts (`ReadHeaderTimeout`, `ReadTimeout`, `WriteTimeout`); limit
  bodies with `http.MaxBytesReader`; always `defer resp.Body.Close()`.
- **Crypto/random**: `crypto/rand` for tokens, never `math/rand`.
- **Context**: pass `ctx context.Context` as the first parameter through I/O paths.
- **Secrets**: `os.Getenv` / config loader at startup; validate and fail fast.

## Testing

- Table-driven tests with `t.Run` subtests; files `*_test.go` next to the code.
- Test names describe behavior: `TestFetchUser_ReturnsNotFound`.
- Run with `-race`; use `t.Parallel()` where safe; `testing/synctest` for concurrency.
- No network in unit tests; use `httptest`.

## Checklist

- [ ] `golangci-lint fmt` (gofmt + goimports) produces no diff.
- [ ] `go vet ./...` and `golangci-lint run ./...` clean.
- [ ] `go test -race ./...` passes.
- [ ] Every error handled and wrapped with `%w` and context; no string comparison of errors.
- [ ] Layout follows go.dev/doc/modules/layout; private code in `internal/`.
- [ ] No `Sprintf` SQL, no `sh -c`, file access confined to a root, `html/template` for HTML.
- [ ] `go.mod`/`go.sum` tidy (`go mod tidy`); new env vars added to `.env.example`.
