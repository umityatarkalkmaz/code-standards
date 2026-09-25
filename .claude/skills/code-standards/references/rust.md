# Rust Standards

Verified: 2026-09-24

| Item | Version | Source |
| --- | --- | --- |
| Rust (stable) | 1.98.1, edition 2024 | https://doc.rust-lang.org/edition-guide/rust-2024/ |
| rustfmt | bundled with the toolchain | https://rust-lang.github.io/rustfmt/ |
| clippy | bundled with the toolchain | https://rust-lang.github.io/rust-clippy/stable/ |
| Cargo `[lints]` table | stable since 1.74 | https://doc.rust-lang.org/cargo/reference/manifest.html#the-lints-section |
| thiserror | 2.0 | https://docs.rs/thiserror |
| anyhow | 1.0 | https://docs.rs/anyhow |

## Tooling

- Toolchain pinned per project with `rust-toolchain.toml` (keeps Cargo per project, no
  global component changes):

```toml
[toolchain]
channel = "1.98"
components = ["rustfmt", "clippy"]
```

- **rustfmt**: default style. Add `rustfmt.toml` only for deliberate deviations; the
  edition comes from `Cargo.toml`.
- **clippy + lints** in `Cargo.toml` (use `[workspace.lints]` + `lints.workspace = true`
  in workspaces):

```toml
[package]
edition = "2024"
rust-version = "1.98"

[lints.rust]
unsafe_code = "forbid"

[lints.clippy]
pedantic = { level = "warn", priority = -1 }
# Pedantic lints allowed on purpose (keep this list short and justified):
must_use_candidate = "allow"   # noisy on simple getters
missing_errors_doc = "allow"   # enable for published libraries
missing_panics_doc = "allow"   # enable for published libraries
# Restriction lints enabled on purpose:
undocumented_unsafe_blocks = "deny"
unwrap_used = "warn"
dbg_macro = "warn"
```

- Commands: `cargo fmt`, `cargo clippy --all-targets --all-features -- -D warnings`,
  `cargo test`. Tools like `cargo-audit` go in the project's CI or are run via
  `cargo install --root ./.tools` — not into the global `~/.cargo/bin` unless justified.

## Project Layout

```text
Cargo.toml
Cargo.lock          # commit for binaries and workspaces; libraries may commit too
rust-toolchain.toml
src/
  main.rs           # binary entry: thin, parses args, calls into lib
  lib.rs            # library root
  <module>.rs       # prefer module.rs over module/mod.rs
tests/              # integration tests
benches/
examples/
```

- Workspaces for multiple crates: root `Cargo.toml` with `[workspace]`, crates under `crates/`.
- Keep `main.rs` thin; put logic in `lib.rs` so it is testable.

## Naming

- `snake_case` for functions, variables, modules, files; `PascalCase` for types and traits;
  `SCREAMING_SNAKE_CASE` for constants and statics (Rust API Guidelines).
- Functions are Action-Object: `fetch_user`, `validate_input`, `parse_header`.
- Conversions follow `as_` (cheap borrow), `to_` (expensive), `into_` (consuming).
- Constructors: `new`, `with_<thing>`; fallible constructors return `Result`.
- Getters have no `get_` prefix: `fn name(&self) -> &str`.

## Security Specifics

- **`unsafe` is forbidden by default** (`unsafe_code = "forbid"`). It is allowed only when
  necessity is explicitly proven for one of:
  1. FFI to a C/system library,
  2. direct hardware or memory-mapped I/O access,
  3. a demonstrated performance requirement (benchmark shows safe code cannot meet it).

  Procedure when an exception is approved by the user:
  - Change the crate lint to `unsafe_code = "deny"` (a `forbid` cannot be overridden).
  - Put the unsafe code in one small module with `#[allow(unsafe_code)]` on that item only,
    wrapped in a safe API.
  - Every `unsafe` block gets a `// SAFETY:` comment stating the invariants and why they hold;
    every `unsafe fn` gets a `# Safety` doc section. `undocumented_unsafe_blocks` enforces it.
  - Edition 2024 rules apply: `unsafe extern "C" { ... }`, `#[unsafe(no_mangle)]`, and
    explicit `unsafe {}` blocks inside `unsafe fn` (`unsafe_op_in_unsafe_fn`).
  - Record the justification (benchmark, FFI target) in the module doc comment.
- **Errors**: libraries define typed errors with `thiserror`; binaries/application code use
  `anyhow::Result` with `.context("fetch user")`. No `unwrap`/`expect` in non-test code
  unless the invariant is documented next to it. Never `panic!` on bad input.
- **Input**: parse into validated types (newtypes with `TryFrom`) at the boundary.
- **SQL**: `sqlx`/`diesel` with bound parameters; never `format!` SQL.
- **Shell**: `std::process::Command` with `.arg()`; never `sh -c` with input.
- **Paths**: `canonicalize()` then `starts_with(root)`.
- **Integers**: use `checked_*`/`saturating_*` for arithmetic on untrusted values.
- **Secrets**: from env (`std::env::var`), wrap in a type that does not `Debug`-print them
  (e.g. `secrecy`).

```rust
#[derive(Debug, thiserror::Error)]
pub enum FetchUserError {
    #[error("user {0} not found")]
    NotFound(u64),
    #[error("database error")]
    Database(#[from] sqlx::Error),
}
```

## Testing

- Unit tests in a `#[cfg(test)] mod tests` at the bottom of the file; integration tests in
  `tests/`. `unwrap`/`expect` are fine in tests.
- Test names describe behavior: `fn rejects_expired_token()`.
- Doc examples compile and run (`cargo test` runs doctests).

## Checklist

- [ ] `cargo fmt --check` clean.
- [ ] `cargo clippy --all-targets --all-features -- -D warnings` clean.
- [ ] `cargo test` passes.
- [ ] No `unsafe`, or an approved exception with `deny` + scoped `allow` + `// SAFETY:` comments.
- [ ] Library errors via `thiserror`, application errors via `anyhow` with context.
- [ ] No `unwrap`/`expect`/`panic!` on input paths; no `format!`-built SQL or shell.
- [ ] `Cargo.lock` committed for binaries; new env vars added to `.env.example`.
