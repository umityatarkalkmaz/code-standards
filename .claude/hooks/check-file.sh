#!/usr/bin/env bash
# PostToolUse hook for Edit|Write: formats the written file in place and lints it.
#
# Exit codes:
#   0  clean, skipped, or tools missing (warnings are emitted as JSON on stdout)
#   2  lint findings; stderr is shown to Claude (PostToolUse cannot block, the file is written)
#
# Security: never evals input, quotes every expansion, only acts on regular files whose
# resolved path is inside $CLAUDE_PROJECT_DIR. File paths passed to tools are always
# absolute, so they can never be parsed as command-line options.
set -euo pipefail
IFS=$'\n\t'
umask 077

readonly HEAVY_TIMEOUT_SECONDS=90
readonly MAX_OUTPUT_LINES=60

findings=""
warnings=()
state_dir=""
project_root=""
file=""
file_dir=""
rel_path=""

# ---------------------------------------------------------------- JSON helpers

detect_json_tool() {
  if command -v jq >/dev/null 2>&1; then
    printf 'jq\n'
  elif command -v python3 >/dev/null 2>&1; then
    printf 'python3\n'
  else
    printf 'none\n'
  fi
}

JSON_TOOL="$(detect_json_tool)"
readonly JSON_TOOL

# read_json_string <json> <dot.path> -> prints the string value or nothing
read_json_string() {
  local json="$1" key="$2"
  case "$JSON_TOOL" in
    jq)
      jq -r --arg key "$key" \
        'getpath($key | split(".")) | if type == "string" then . else empty end' \
        <<<"$json" 2>/dev/null || true
      ;;
    python3)
      python3 -c '
import json, sys
try:
    value = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
for part in sys.argv[1].split("."):
    value = value.get(part) if isinstance(value, dict) else None
if isinstance(value, str):
    sys.stdout.write(value)
' "$key" <<<"$json" 2>/dev/null || true
      ;;
  esac
}

# emit_warning_json <system_message> <additional_context>
emit_warning_json() {
  local message="$1" context="$2"
  case "$JSON_TOOL" in
    jq)
      jq -n --arg message "$message" --arg context "$context" \
        '{systemMessage: $message,
          hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $context}}'
      ;;
    python3)
      python3 -c '
import json, sys
print(json.dumps({
    "systemMessage": sys.argv[1],
    "hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": sys.argv[2]},
}))
' "$message" "$context"
      ;;
  esac
}

# ---------------------------------------------------------------- state helpers

add_finding() {
  local label="$1" output="$2"
  findings+=$'\n'"[${label}]"$'\n'"${output}"$'\n'
}

add_warning() {
  warnings+=("$1")
}

# should_warn_once <key>: true the first time a key is seen in this session
should_warn_once() {
  local key="$1"
  [[ -n "$state_dir" ]] || return 0
  [[ "$key" =~ ^[A-Za-z0-9._-]+$ ]] || return 0
  local marker="${state_dir}/${key}"
  [[ -e "$marker" ]] && return 1
  : >"$marker" 2>/dev/null || true
  return 0
}

warn_missing_tool() {
  local tool="$1" hint="$2"
  if should_warn_once "missing-${tool}"; then
    add_warning "${tool} not installed; ${hint}"
  fi
}

init_state_dir() {
  local session_id="$1"
  [[ "$session_id" =~ ^[A-Za-z0-9_-]{1,128}$ ]] || return 0
  local base
  base="${TMPDIR:-/tmp}/code-standards-hook-$(id -u)"
  if mkdir -p -- "${base}/${session_id}" 2>/dev/null \
    && [[ -O "$base" && ! -L "$base" && -O "${base}/${session_id}" ]]; then
    state_dir="${base}/${session_id}"
  fi
}

# ---------------------------------------------------------------- path helpers

resolve_path() {
  local path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath -e -- "$path" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os, sys; p = os.path.realpath(sys.argv[1]); print(p) if os.path.exists(p) else sys.exit(1)' "$path"
  else
    return 1
  fi
}

# find_up <name> <start_dir>: nearest directory (up to project root) containing <name>
find_up() {
  local name="$1" dir="$2"
  while :; do
    if [[ -e "${dir}/${name}" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    if [[ "$dir" == "$project_root" || "$dir" == "/" ]]; then
      return 1
    fi
    dir="$(dirname -- "$dir")"
  done
}

# find_up_any <start_dir> <name>...: nearest directory containing any of the names
find_up_any() {
  local dir="$1" name
  shift
  while :; do
    for name in "$@"; do
      if [[ -e "${dir}/${name}" ]]; then
        printf '%s\n' "${dir}/${name}"
        return 0
      fi
    done
    if [[ "$dir" == "$project_root" || "$dir" == "/" ]]; then
      return 1
    fi
    dir="$(dirname -- "$dir")"
  done
}

# resolve_tool <name> <local_subdir> <base_dir>...: project-local binary first, then PATH
resolve_tool() {
  local name="$1" subdir="$2" base
  shift 2
  for base in "$@"; do
    if [[ -n "$base" && -x "${base}/${subdir}/${name}" ]]; then
      printf '%s\n' "${base}/${subdir}/${name}"
      return 0
    fi
  done
  command -v -- "$name" 2>/dev/null
}

# ---------------------------------------------------------------- runners

# run_step <kind> <label> <workdir> <command...>
#   kind: format | lint | heavy (heavy runs under a timeout)
run_step() {
  local kind="$1" label="$2" workdir="$3"
  shift 3
  local output status=0

  if [[ "$kind" == "heavy" ]]; then
    if ! command -v timeout >/dev/null 2>&1; then
      warn_missing_tool "timeout" "skipped ${label} (needs coreutils timeout)"
      return 0
    fi
    output="$(cd -- "$workdir" && timeout --kill-after=5 "$HEAVY_TIMEOUT_SECONDS" "$@" 2>&1)" \
      || status=$?
    if ((status == 124 || status == 137)); then
      add_warning "${label} timed out after ${HEAVY_TIMEOUT_SECONDS}s; run it manually"
      return 0
    fi
  else
    output="$(cd -- "$workdir" && "$@" 2>&1)" || status=$?
  fi

  if ((status != 0)); then
    add_finding "$label" "${output:-exit status ${status}}"
  fi
}

# ---------------------------------------------------------------- language checks

check_php() {
  local composer_dir php_bin fixer phpstan
  composer_dir="$(find_up composer.json "$file_dir" || printf '%s\n' "$project_root")"

  if php_bin="$(command -v php 2>/dev/null)"; then
    run_step lint "php -l" "$file_dir" "$php_bin" -l "$file"
  else
    warn_missing_tool "php" "PHP syntax check skipped"
    return 0
  fi

  if fixer="$(resolve_tool php-cs-fixer vendor/bin "$composer_dir" "$project_root")"; then
    if [[ -e "${composer_dir}/.php-cs-fixer.dist.php" || -e "${composer_dir}/.php-cs-fixer.php" ]]; then
      run_step format "php-cs-fixer" "$composer_dir" "$fixer" fix --quiet "$file"
    else
      run_step format "php-cs-fixer" "$composer_dir" "$fixer" fix --quiet --rules=@PER-CS "$file"
    fi
  else
    warn_missing_tool "php-cs-fixer" "PER-CS formatting skipped (composer require --dev friendsofphp/php-cs-fixer)"
  fi

  if [[ -e "${composer_dir}/phpstan.neon" || -e "${composer_dir}/phpstan.neon.dist" \
    || -e "${composer_dir}/phpstan.dist.neon" ]]; then
    if phpstan="$(resolve_tool phpstan vendor/bin "$composer_dir" "$project_root")"; then
      run_step heavy "phpstan" "$composer_dir" "$phpstan" analyse --no-progress \
        --error-format=raw --memory-limit=1G "$file"
    else
      warn_missing_tool "phpstan" "static analysis skipped (composer require --dev phpstan/phpstan)"
    fi
  fi
}

check_javascript() {
  local package_dir prettier eslint_config eslint
  package_dir="$(find_up package.json "$file_dir" || printf '%s\n' "$project_root")"

  if prettier="$(resolve_tool prettier node_modules/.bin "$package_dir" "$project_root")"; then
    run_step format "prettier" "$package_dir" "$prettier" --write --log-level=warn "$file"
  else
    warn_missing_tool "prettier" "formatting skipped (npm install --save-dev prettier)"
  fi

  [[ "$file" == *.css ]] && return 0

  if eslint_config="$(find_up_any "$file_dir" eslint.config.js eslint.config.mjs \
    eslint.config.cjs eslint.config.ts eslint.config.mts eslint.config.cts)"; then
    local config_dir
    config_dir="$(dirname -- "$eslint_config")"
    # Only a project-local ESLint can load the project's plugins and shared configs.
    if eslint="$(resolve_tool eslint node_modules/.bin "$config_dir" "$package_dir" "$project_root")" \
      && [[ "$eslint" == "$project_root"/* ]]; then
      run_step lint "eslint" "$config_dir" "$eslint" --no-warn-ignored --max-warnings=0 "$file"
    else
      warn_missing_tool "eslint" "lint skipped; install project dependencies (npm ci)"
    fi
  fi
}

check_rust() {
  local crate_dir rustfmt cargo edition=""
  crate_dir="$(find_up Cargo.toml "$file_dir" || true)"

  if [[ -n "$crate_dir" ]]; then
    edition="$(grep -m1 -E '^[[:space:]]*edition[[:space:]]*=' "${crate_dir}/Cargo.toml" \
      | grep -oE '20[0-9]{2}' || true)"
    if [[ -z "$edition" && -e "${project_root}/Cargo.toml" ]]; then
      edition="$(grep -m1 -E '^[[:space:]]*edition[[:space:]]*=' "${project_root}/Cargo.toml" \
        | grep -oE '20[0-9]{2}' || true)"
    fi
  fi
  [[ "$edition" =~ ^20[0-9]{2}$ ]] || edition="2024"

  if rustfmt="$(command -v rustfmt 2>/dev/null)"; then
    run_step format "rustfmt" "$file_dir" "$rustfmt" --edition "$edition" "$file"
  else
    warn_missing_tool "rustfmt" "formatting skipped (rustup component add rustfmt)"
  fi

  [[ -n "$crate_dir" ]] || return 0
  if cargo="$(command -v cargo 2>/dev/null)" && "$cargo" clippy --version >/dev/null 2>&1; then
    run_step heavy "cargo clippy" "$crate_dir" "$cargo" clippy --quiet --all-targets \
      --message-format=short -- -D warnings
  else
    warn_missing_tool "clippy" "lint skipped (rustup component add clippy)"
  fi
}

check_go() {
  local module_dir golangci_config="" golangci gofmt go_bin
  module_dir="$(find_up go.mod "$file_dir" || true)"
  golangci_config="$(find_up_any "$file_dir" .golangci.yml .golangci.yaml .golangci.toml \
    .golangci.json || true)"
  golangci="$(command -v golangci-lint 2>/dev/null || true)"

  if [[ -n "$golangci" && -n "$golangci_config" ]] \
    && grep -qE '^[[:space:]]*"?formatters"?[[:space:]]*[:=]' "$golangci_config"; then
    run_step format "golangci-lint fmt" "$file_dir" "$golangci" fmt "$file"
  elif gofmt="$(command -v gofmt 2>/dev/null)"; then
    run_step format "gofmt" "$file_dir" "$gofmt" -w "$file"
  else
    warn_missing_tool "gofmt" "formatting skipped (install the Go toolchain)"
  fi

  [[ -n "$module_dir" ]] || return 0
  if go_bin="$(command -v go 2>/dev/null)"; then
    run_step heavy "go vet" "$file_dir" "$go_bin" vet .
  else
    warn_missing_tool "go" "go vet skipped"
  fi

  if [[ -n "$golangci_config" ]]; then
    if [[ -n "$golangci" ]]; then
      run_step heavy "golangci-lint" "$file_dir" "$golangci" run --show-stats=false .
    else
      warn_missing_tool "golangci-lint" "lint skipped (see golangci-lint.run install docs)"
    fi
  fi
}

check_python() {
  local py_dir ruff
  py_dir="$(find_up pyproject.toml "$file_dir" || printf '%s\n' "$project_root")"

  if ruff="$(resolve_tool ruff .venv/bin "$py_dir" "$project_root")"; then
    run_step format "ruff format" "$py_dir" "$ruff" format --quiet "$file"
    run_step lint "ruff check" "$py_dir" "$ruff" check --quiet --output-format=concise "$file"
  else
    warn_missing_tool "ruff" "format and lint skipped (uv add --dev ruff)"
  fi
}

check_shell() {
  local shellcheck
  if shellcheck="$(command -v shellcheck 2>/dev/null)"; then
    run_step lint "shellcheck" "$file_dir" "$shellcheck" --format=gcc "$file"
  else
    warn_missing_tool "shellcheck" "shell lint skipped"
  fi
}

# ---------------------------------------------------------------- output

print_findings() {
  local -a lines
  mapfile -t lines <<<"$findings"
  {
    printf 'code-standards: lint findings for %s (available formatters already ran)\n' "$rel_path"
    printf '%s\n' "${lines[@]:0:MAX_OUTPUT_LINES}"
    if ((${#lines[@]} > MAX_OUTPUT_LINES)); then
      printf '... %d more lines truncated\n' "$((${#lines[@]} - MAX_OUTPUT_LINES))"
    fi
    local warning
    for warning in "${warnings[@]}"; do
      printf 'warning: %s\n' "$warning"
    done
    printf 'Fix these findings; do not suppress them without a stated reason.\n'
  } >&2
}

print_warnings() {
  local joined="" warning
  for warning in "${warnings[@]}"; do
    joined+="${joined:+; }${warning}"
  done
  emit_warning_json "code-standards: ${joined}" \
    "code-standards hook could not fully verify ${rel_path:-the written file}: ${joined}. Apply the Checklist of the matching code-standards reference manually. Offer to install missing tools project-scoped; never install them globally."
}

# ---------------------------------------------------------------- main

main() {
  if [[ "$JSON_TOOL" == "none" ]]; then
    # Static JSON only: nothing from the input is echoed.
    printf '%s\n' '{"systemMessage":"code-standards: jq or python3 is required to read hook input; checks skipped."}'
    return 0
  fi

  local input file_path session_id
  input="$(cat)"
  file_path="$(read_json_string "$input" "tool_input.file_path")"
  session_id="$(read_json_string "$input" "session_id")"

  [[ -n "${CLAUDE_PROJECT_DIR:-}" && -n "$file_path" ]] || return 0
  init_state_dir "$session_id"

  if [[ "$file_path" == *[[:cntrl:]]* ]]; then
    add_warning "rejected a file path containing control characters"
    print_warnings
    return 0
  fi

  project_root="$(resolve_path "$CLAUDE_PROJECT_DIR")" || return 0
  [[ "$file_path" == /* ]] || file_path="${project_root}/${file_path}"
  [[ -f "$file_path" ]] || return 0

  file="$(resolve_path "$file_path")" || return 0
  case "$file" in
    "$project_root"/*) ;;
    *)
      if should_warn_once "outside-project"; then
        add_warning "skipped a file outside the project directory"
        print_warnings
      fi
      return 0
      ;;
  esac
  [[ -f "$file" ]] || return 0

  rel_path="${file#"$project_root"/}"
  case "/${rel_path}" in
    */.git/* | */node_modules/* | */vendor/* | */target/* | */.venv/* | */venv/* \
      | */dist/* | */build/* | */.next/* | */__pycache__/*)
      return 0
      ;;
  esac
  file_dir="$(dirname -- "$file")"

  case "$file" in
    *.php) check_php ;;
    *.js | *.mjs | *.cjs | *.jsx | *.ts | *.mts | *.cts | *.tsx | *.css) check_javascript ;;
    *.rs) check_rust ;;
    *.go) check_go ;;
    *.py | *.pyi) check_python ;;
    *.sh | *.bash) check_shell ;;
    *) return 0 ;;
  esac

  if [[ -n "$findings" ]]; then
    print_findings
    return 2
  fi
  if ((${#warnings[@]} > 0)); then
    print_warnings
  fi
  return 0
}

# A non-zero return from main exits the script with that status via errexit.
main "$@"
