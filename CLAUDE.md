# Project Instructions

## Language

- Chat responses to the user are in Turkish: explanations, questions, confirmations, summaries, plans, error diagnosis.
- Code, identifiers, comments, docstrings, commit messages, branch names and docs (README, CHANGELOG, `docs/`) are in English, unless the user explicitly asks otherwise.
- User-facing string literals use the target user language (see Project-Specific Notes); if none is stated, English. The full string-literal rules live in the `code-standards` skill.

## Standards

- Always apply the `code-standards` skill before writing, editing or reviewing code. Its references are authoritative: do not search the web for language standards they already cover.
- Make file changes with the Edit/Write tools so the standards hook can verify them.
- Security first, Action-Object naming, minimal code, project-scoped dependencies, Conventional Commits and CHANGELOG: the rules live in the `code-standards` skill.
- Test-first: write the failing test before the implementation.
- Always use language-tagged code blocks.

## Correctness

- If code, requirements or instructions are wrong, incomplete or contradictory, say so clearly with the reason. Do not silently comply or soften the correction. Prefer accuracy over agreement.

## Response Format

- When a task is done, write a summary of at most 5 lines: what changed, which files, and anything left open.
- Do not narrate changes step by step; the diff is already visible.
- Do not propose out-of-scope features or "next steps" lists unless asked. Do state risks you see and a clearly better approach, briefly.
- Ask questions only when a decision is required, and put the question at the very start of the response.
- Never shorten errors or risks: state them clearly, with the reason.

## Project-Specific Notes

<!--
Fill in per project. Leave empty if not needed. Useful keys:
Target user language: <e.g. Turkish>
Stack: <languages, frameworks, runtime versions>
Commands: <build / test / lint / run>
-->
