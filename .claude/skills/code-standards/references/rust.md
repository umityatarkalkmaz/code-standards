# Rust Standards

Verified: 2026-10-12

| Item | Version | Source |
| --- | --- | --- |
| Rust (stable) | 1.99.0, edition 2024 | https://doc.rust-lang.org/edition-guide/rust-2024/ |
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
channel = "1.99"
components = ["rustfmt", "clippy"]
```

- **clippy + lints** in `Cargo.toml` (use `[workspace.lints]` + `lints.workspace = true`
  in workspaces):

```toml
[package]
edition = "2024"
rust-version = "1.99"

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

- Tools like `cargo-audit` go in the project's CI or are run via
  `cargo install --root ./.tools` — not into the global `~/.cargo/bin` unless justified.

## Project Layout

- Commit `Cargo.lock` for binaries and workspaces; libraries may commit it too.
- Prefer `module.rs` over `module/mod.rs`.
- Keep `main.rs` thin (parse args, call into the library); put logic in `lib.rs` so it is
  testable.
- Workspaces for multiple crates: root `Cargo.toml` with `[workspace]`, crates under `crates/`.

## Naming

No rules beyond the core rules.

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
  `anyhow::Result` with `.context("fetch user")`.
- Input parsed into validated newtypes (`TryFrom`) at the boundary.
- SQL via `sqlx`/`diesel` bound parameters; processes via `std::process::Command` with `.arg()`.
- Paths: `canonicalize()`, then `starts_with(root)`.
- `checked_*`/`saturating_*` arithmetic on untrusted values.
- Secrets from `std::env::var`, wrapped in a type that does not `Debug`-print them (`secrecy`).

## Testing

No rules beyond the core rules.

## Checklist

- [ ] No `unsafe`, or an approved exception with `deny` + scoped `allow` + `// SAFETY:` comments.
