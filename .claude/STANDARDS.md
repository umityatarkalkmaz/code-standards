# Code Standards System

This directory makes Claude Code apply one set of coding standards in every project created
from this template, without searching for them, and verifies them with tools where they are
installed. It works the same locally and in Claude Code on the web (cloud sandbox), because
everything is project-level: nothing depends on `~/.claude`.

## Components

| Path | Role |
| --- | --- |
| `CLAUDE.md` (repo root) | Always-loaded project instructions; tells Claude to apply the skill. |
| `.claude/skills/code-standards/SKILL.md` | Core language-agnostic rules and a routing table. |
| `.claude/skills/code-standards/references/<lang>.md` | Per-language standards, loaded on demand. |
| `.claude/hooks/check-file.sh` | PostToolUse hook: formats and lints each written file. |
| `.claude/settings.json` | Registers the hook. Contains no permission changes. |

## How It Works

1. **At write time (skill)**: Claude sees the skill's description at session start and loads
   `SKILL.md` when it writes or reviews code. The routing table points it to one reference
   file per language (progressive disclosure: only the needed reference enters context).
   Each reference has the same sections: Tooling, Project Layout, Naming, Security
   Specifics, Testing, Checklist, plus a `Verified:` date and version table.
2. **After write (hook)**: after every `Edit`/`Write`, `check-file.sh` receives the tool input
   as JSON on stdin and:
   - resolves the file path and ignores anything outside `$CLAUDE_PROJECT_DIR`, non-regular
     files and generated/dependency directories (`node_modules`, `vendor`, `target`, ...);
   - picks tools by file extension, preferring project-local binaries (`node_modules/.bin`,
     `vendor/bin`, `.venv/bin`) over `PATH`;
   - runs formatters in place, then linters; package-level analysers (`cargo clippy`,
     `golangci-lint run`, `go vet`, `phpstan`, `dart`/`flutter analyze`) run under a 90 s timeout.
3. **Feedback**:
   - clean: exit 0, silent;
   - lint findings: exit 2, findings on stderr (first 60 lines) are shown to Claude, which
     fixes them;
   - missing tool: exit 0 with a JSON `systemMessage` (shown to you) and `additionalContext`
     (shown to Claude). Each missing tool is reported once per session.

| Extension | Formatter | Linters |
| --- | --- | --- |
| `.php` | php-cs-fixer (project config or `@PER-CS`) | `php -l`, phpstan (if `phpstan.neon*` exists) |
| `.js .mjs .cjs .jsx .ts .mts .cts .tsx` (incl. React Native / Expo) | prettier | eslint `--max-warnings=0` (if `eslint.config.*` exists, project-local only) |
| `.css` | prettier | none |
| `.rs` | rustfmt (edition from `Cargo.toml`) | `cargo clippy -- -D warnings` |
| `.go` | `golangci-lint fmt` (if configured) or gofmt | `go vet`, golangci-lint (if `.golangci.*` exists) |
| `.py .pyi` | `ruff format` | `ruff check` |
| `.dart` | `dart format` | `flutter analyze` (Flutter packages) or `dart analyze --fatal-infos`, after `pub get` |
| `.sh .bash` | none | shellcheck |

## Limits

- **PostToolUse cannot block**: the file is already written when the hook runs. The hook
  can only report back so Claude fixes the file.
- **Bash edits are not checked**: the hook fires on the `Edit` and `Write` tools only. A
  file changed through `sed`, a heredoc or a code generator is not verified; the skill tells
  Claude to use Edit/Write for file changes.
- **Web sandbox tools**: many tools are missing in a fresh cloud sandbox. The hook then only
  warns; Claude applies the reference Checklist manually. Installing project dev
  dependencies (`npm ci`, `uv sync`, `composer install`) enables the project-local tools.
- **Project-local binaries run as project code**: the hook executes tools from
  `node_modules/.bin`, `vendor/bin` and `.venv/bin`. Only use it in repositories you trust,
  the same as running `npm test`.
- **Requirements**: bash 4.4+ and `jq` or `python3` (to read the hook input). Without
  either, the hook reports that and skips checks.
- **Skill invocation** depends on Claude matching the skill description; `CLAUDE.md`
  instructs Claude to always apply it.

## Add a New Language

Three changes, in this order:

1. **Reference file**: create `.claude/skills/code-standards/references/<lang>.md` with a
   `Verified: YYYY-MM-DD` line, a version/source table, and exactly these sections:
   `## Tooling`, `## Project Layout`, `## Naming`, `## Security Specifics`, `## Testing`,
   `## Checklist`. Verify versions against official sources, not memory.
2. **Routing entry**: add one row to the Routing Table in `SKILL.md` (project marker, file
   extensions, link to the reference). Mention the language in the skill `description` if it
   should trigger the skill on its own.
3. **Hook case**: in `.claude/hooks/check-file.sh`, add a `check_<lang>()` function
   (formatter via `run_step format`, linters via `run_step lint` or `run_step heavy`,
   `warn_missing_tool` when a tool is absent) and one line in the extension `case` in `main`.
   Pass absolute file paths only; never build command strings.

Then update the extension table above.

## Update the Standards

When a tool or standard releases a new major version, update the reference's version table,
`Verified:` date and any changed config snippets, and adjust the hook if command-line flags
changed. Record the change in the template's `CHANGELOG.md`.

## Sync Updates into an Existing Project

Projects created from a GitHub template have unrelated histories, so copy the standards
paths instead of merging:

```bash
git remote add standards https://github.com/umityatarkalkmaz/code-standards.git
git fetch standards main
git checkout standards/main -- \
  .claude/skills/code-standards \
  .claude/hooks/check-file.sh \
  .claude/STANDARDS.md
git remote remove standards
```

- `.claude/settings.json`: merge the `PostToolUse` hook entry by hand if the project has its
  own settings; do not overwrite them.
- `CLAUDE.md`: compare with the template and merge the shared sections by hand; keep the
  project's `Project-Specific Notes`.
- Review the diff (`git diff --staged`), then commit:
  `chore(standards): sync code-standards from template`.
