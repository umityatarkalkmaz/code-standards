# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Instruction files (`CLAUDE.md`, `SKILL.md`, `references/*.md`) trimmed to project decisions and facts the model cannot know; rules the model already knows or that a tool enforces were removed.
- Shared rules now live once in the `code-standards` skill; `CLAUDE.md` points to it.
- Response Format no longer forbids raising risks or a clearly better approach; it only rules out unrequested out-of-scope features and next-steps lists.

### Added

- Test-first rule in `CLAUDE.md`: write the failing test before the implementation.
