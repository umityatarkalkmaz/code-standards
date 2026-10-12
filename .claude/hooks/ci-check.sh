#!/usr/bin/env bash
# CI entry point: runs check-file.sh on every changed file, exactly as Claude Code does
# after Edit/Write, then fails if any formatter changed a file (code was committed
# unformatted) or any linter reported findings.
#
# Usage: ci-check.sh [base-commit]
#   With a base commit, checks files changed between it and HEAD; without one, checks
#   every tracked file.
set -euo pipefail
IFS=$'\n\t'

HOOKS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly HOOKS_DIR
REPO_ROOT="$(git -C "$HOOKS_DIR" rev-parse --show-toplevel)"
readonly REPO_ROOT

base="${1:-}"
if [[ -n "$base" && ! "$base" =~ ^[0-9a-f]{7,64}$ ]]; then
  printf 'ci-check: base must be a commit SHA, got: %s\n' "$base" >&2
  exit 1
fi
# An all-zero SHA is what GitHub sends for a newly created branch.
[[ "$base" =~ ^0+$ ]] && base=""

session_id="ci-${GITHUB_RUN_ID:-local}"
[[ "$session_id" =~ ^[A-Za-z0-9_-]{1,128}$ ]] || session_id="ci-local"

list_files() {
  if [[ -n "$base" ]]; then
    git -C "$REPO_ROOT" diff -z --name-only --diff-filter=ACMR "$base" HEAD --
  else
    git -C "$REPO_ROOT" ls-files -z
  fi
}

checked=0
findings=0
checked_paths=()

while IFS= read -r -d '' rel_path; do
  file="${REPO_ROOT}/${rel_path}"
  [[ -f "$file" && ! -L "$file" ]] || continue
  checked=$((checked + 1))
  checked_paths+=("$rel_path")

  input="$(jq -n --arg session_id "$session_id" --arg file_path "$file" \
    '{session_id: $session_id, tool_name: "Write", tool_input: {file_path: $file_path}}')"
  status=0
  stdout="$(CLAUDE_PROJECT_DIR="$REPO_ROOT" bash "${HOOKS_DIR}/check-file.sh" \
    <<<"$input" 2>"${RUNNER_TEMP:-/tmp}/ci-check-stderr")" || status=$?

  if ((status == 2)); then
    findings=$((findings + 1))
    printf '::group::Findings in %s\n' "$rel_path"
    cat "${RUNNER_TEMP:-/tmp}/ci-check-stderr"
    printf '::endgroup::\n'
    printf '::error file=%s::code-standards lint findings\n' "$rel_path"
  elif ((status != 0)); then
    findings=$((findings + 1))
    printf '::error file=%s::check-file.sh failed with exit %d\n' "$rel_path" "$status"
    cat "${RUNNER_TEMP:-/tmp}/ci-check-stderr"
  elif [[ -n "$stdout" ]]; then
    message="$(jq -r '.systemMessage // empty' <<<"$stdout" 2>/dev/null || true)"
    [[ -z "$message" ]] || printf '::warning::%s\n' "$message"
  fi
done < <(list_files)

rm -f -- "${RUNNER_TEMP:-/tmp}/ci-check-stderr"

# Only checked files count: dependency installs may legitimately touch lockfiles.
unformatted=0
if ((checked > 0)) && ! git -C "$REPO_ROOT" diff --quiet -- "${checked_paths[@]}"; then
  unformatted=1
  printf '::group::Formatter changes (files committed unformatted)\n'
  git -C "$REPO_ROOT" --no-pager diff --stat -- "${checked_paths[@]}"
  git -C "$REPO_ROOT" --no-pager diff -- "${checked_paths[@]}"
  printf '::endgroup::\n'
  printf '::error::Some files are not formatted. Run the formatters locally and commit the result.\n'
fi

printf 'ci-check: %d files checked, %d with findings, formatting %s\n' \
  "$checked" "$findings" "$([[ $unformatted -eq 0 ]] && echo clean || echo changed)"
((findings == 0 && unformatted == 0))
