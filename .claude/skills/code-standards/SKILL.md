---
name: code-standards
description: Project coding standards for every language in this repository (PHP, JavaScript/TypeScript, React Native/Expo, Rust, Go, Python, Dart/Flutter). Apply before writing, editing, refactoring or reviewing any source file, config file or test. Covers security rules, naming, string-literal language, tooling, project layout and per-language checklists.
when_to_use: Use whenever code is written or changed, a new project or module is scaffolded, dependencies or linters are configured, or code is reviewed. Use instead of searching the web for PSR-4, PER Coding Style, ESM, TypeScript strict, Next.js, Tailwind, Expo, React Native, Flutter, Effective Dart, rustfmt, clippy, gofmt, golangci-lint, ruff or pyproject conventions.
---

# Code Standards

These rules are authoritative for this project. Do not search the web for the
standards covered here. If a reference is silent on a point, follow the language's
official formatter/linter defaults and tell the user about the gap.

## Workflow

1. **Detect the language** of the file you are about to touch using the routing table.
2. **Read the matching reference once per session**, before the first write in that language.
3. **Apply the rules while writing.** Do not write first and fix later.
4. **Make file changes with Edit/Write**, never with Bash (`sed`, heredocs, `echo >`), so the
   PostToolUse hook can format and lint the file.
5. **Act on hook feedback.** Lint findings come back to you; fix them before moving on.
6. **Run the reference Checklist** before declaring the task done.

## Routing Table

| Project marker | File extensions | Reference |
| --- | --- | --- |
| `composer.json` | `.php` | [references/php.md](references/php.md) |
| `package.json`, `tsconfig.json` | `.js` `.mjs` `.cjs` `.jsx` `.ts` `.mts` `.cts` `.tsx` `.css` | [references/javascript.md](references/javascript.md) |
| `package.json` depending on `expo` or `react-native`, `app.json`, `app.config.ts` | same as above | [references/react-native.md](references/react-native.md) **plus** javascript.md |
| `Cargo.toml` | `.rs` | [references/rust.md](references/rust.md) |
| `go.mod` | `.go` | [references/go.md](references/go.md) |
| `pyproject.toml` | `.py` `.pyi` | [references/python.md](references/python.md) |
| `pubspec.yaml` | `.dart` | [references/dart.md](references/dart.md) |

- In a monorepo, the nearest marker above the file decides.
- A new project with no marker yet: create the marker first, as the reference describes.
- A language without a reference: apply the Core Rules and the language's official formatter.

## Core Rules (all languages)

### Security

- Treat every external input as untrusted: HTTP requests, CLI args, env vars, files,
  uploads, IPC, database rows written by users, third-party API responses.
- Validate at the boundary: type, length, range, format, allow-list. Reject; do not "clean up".
- **SQL**: parameterized queries or a query builder only. Never concatenate or interpolate input.
- **Shell**: pass argument arrays to the process API with no shell. Never `eval`, never build
  command strings from input.
- **Paths**: resolve to a canonical absolute path and verify it stays inside the allowed root.
  Reject symlinks that escape it.
- **Output**: context-aware escaping (HTML, attribute, URL, JS). Never render raw user HTML.
- **Deserialization**: never deserialize untrusted data with formats that can execute code.
- **Secrets**: never in code, tests, fixtures, logs or error messages. Read from env vars,
  list every variable in `.env.example`, keep `.env` gitignored.
- Fail closed: on validation or auth errors deny by default and log without sensitive data.

### Naming

- English identifiers only.
- Functions and methods are **Action-Object**: `fetchUser`, `validateInput`, `parse_config`,
  `ParseHeader`. Use the language's casing convention.
- Booleans read as predicates: `isValid`, `has_access`, `canRetry`.
- No abbreviations except widely known ones (`id`, `url`, `http`, `db`).

### Code Shape

- Minimal and clean: no speculative abstraction, no unused parameters, no dead code.
- Small functions with one responsibility; early returns over deep nesting.
- Comments explain *why*, not *what*.
- Every code block in chat or docs is language-tagged.

### Language of Code and Strings

- Everything outside string literals is English: identifiers, comments, docstrings,
  commit messages, branch names.
- **User-facing strings** (UI text, exported/downloadable output, validation feedback, any
  message the end user sees) use the target user language, only when it is stated in the
  prompt or in a `Target user language:` line in `CLAUDE.md`. Otherwise English.
- **Strings the end user never sees** are English: thrown errors, logs, test names, assertion
  messages, developer-facing CLI/debug output.
- **Code-level string data** is English: object keys, enum values, config keys, CSS classes,
  env var names.
- If a thrown error can reach the end user, keep the internal message English and map it via
  an error code to a separate user-facing string. Never surface the internal message.
- English code containing target-language user-facing strings is not "mixed language".

### Dependencies and Tooling

- Install dependencies project-scoped (`node_modules`, `.venv`, `vendor`, Cargo/Go module
  cache per project). Never install globally unless it is a genuine system-wide requirement,
  and then say so explicitly.
- Commit lockfiles (`package-lock.json`, `composer.lock`, `Cargo.lock` for binaries,
  `go.sum`, `uv.lock`).
- Run tools from the project (`npx`, `vendor/bin/`, `.venv/bin/`, `uv run`, `cargo`, `go`).
- Check tools with `command -v <tool>` before relying on them.
- Never hardcode absolute home paths; derive from `$HOME`.

### Versioning

- Conventional Commits: `type(scope): summary` with types `feat`, `fix`, `docs`, `style`,
  `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`. `!` or `BREAKING CHANGE:`
  for breaking changes.
- Semantic Versioning. User-visible changes go under `## [Unreleased]` in `CHANGELOG.md`.

## Hook Contract

`.claude/hooks/check-file.sh` runs after every Edit/Write:

- Formatters rewrite the file in place. Re-read the file before the next edit if needed.
- Lint findings are sent back to you: fix them, do not suppress them without a stated reason.
- If a tool is missing, you get a one-time warning. Then apply the reference Checklist
  manually, and offer to install the tool project-scoped. Never install it globally.
