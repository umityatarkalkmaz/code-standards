# Project Instructions

## Language

- Chat responses to the user are in Turkish: explanations, questions, confirmations, summaries, plans, error diagnosis.
- Code, identifiers, comments, docstrings, commit messages, branch names and docs (README, CHANGELOG, `docs/`) are in English, unless the user explicitly asks otherwise.
- User-facing string literals use the target user language (see Project-Specific Notes); if none is stated, English. The full string-literal rules live in the `code-standards` skill.

## Standards

- Always apply the `code-standards` skill before writing, editing or reviewing code. Its references are authoritative: do not search the web for language standards they already cover.
- Make file changes with the Edit/Write tools so the standards hook can verify them.

## Security First

- Validate and normalize input at every trust boundary (HTTP, CLI args, env, files, IPC, third-party APIs).
- Prevent injection: parameterized SQL, no shell string building (argument arrays, never `eval`), path traversal checks against a root directory, context-aware output escaping against XSS.
- Never hardcode secrets. Read them from environment variables, document every variable in `.env.example`, keep `.env` gitignored.

## Code Style

- English identifiers with Action-Object naming (`fetchUser`, `validateInput`, `parse_config`), in the language's own casing.
- Minimal, clean code: no unnecessary abstraction, boilerplate or speculative features.
- Always use language-tagged code blocks.

## Dependencies and Tooling

- Install dependencies project-scoped (`node_modules`, `.venv`, `vendor`, per-project Cargo/Go modules), never globally.
- Check tool availability with `command -v <tool>` before relying on it.
- Never hardcode absolute home paths; derive them from `$HOME`.

## Versioning

- Conventional Commits for every commit; Semantic Versioning for releases.
- Record user-visible changes under `## [Unreleased]` in `CHANGELOG.md`.

## Correctness

- If code, requirements or instructions are wrong, incomplete or contradictory, say so clearly with the reason. Do not silently comply or soften the correction. Prefer accuracy over agreement.

## Project-Specific Notes

<!--
Fill in per project. Leave empty if not needed. Useful keys:
Target user language: <e.g. Turkish>
Stack: <languages, frameworks, runtime versions>
Commands: <build / test / lint / run>
-->
