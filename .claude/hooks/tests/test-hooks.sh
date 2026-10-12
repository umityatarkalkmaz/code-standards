#!/usr/bin/env bash
# Regression tests for the standards hooks. Run from anywhere:
#   bash .claude/hooks/tests/test-hooks.sh
# Language checks whose tools are not installed are reported as SKIP, not failures.
set -euo pipefail
IFS=$'\n\t'

HOOKS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly HOOKS_DIR
readonly CHECK_HOOK="${HOOKS_DIR}/check-file.sh"
readonly SESSION_HOOK="${HOOKS_DIR}/session-start.sh"

WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf -- "$WORK_DIR"' EXIT
PROJECT_DIR="${WORK_DIR}/project"
readonly PROJECT_DIR
readonly STATE_TMP="${WORK_DIR}/tmp"
mkdir -p "$PROJECT_DIR" "$STATE_TMP"
PROJECT_DIR_REAL="$(cd -- "$PROJECT_DIR" && pwd -P)"
readonly PROJECT_DIR_REAL

passed=0
failed=0
skipped=0
last_status=0
last_stdout=""
last_stderr=""

# run_check_hook <file_path> [session_id] [env assignments...]
run_check_hook() {
  local file_path="$1" session_id="${2:-test-${RANDOM}}"
  shift 2 || shift $#
  local input
  input="$(printf '{"session_id":"%s","tool_name":"Write","tool_input":{"file_path":"%s"}}' \
    "$session_id" "$file_path")"
  last_status=0
  last_stdout="$(env TMPDIR="$STATE_TMP" "$@" CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$CHECK_HOOK" \
    <<<"$input" 2>"${WORK_DIR}/stderr")" || last_status=$?
  last_stderr="$(cat "${WORK_DIR}/stderr")"
}

pass() {
  passed=$((passed + 1))
  printf 'PASS  %s\n' "$1"
}

fail() {
  failed=$((failed + 1))
  printf 'FAIL  %s\n      status=%s\n      stdout=%s\n      stderr=%s\n' \
    "$1" "$last_status" "$last_stdout" "$last_stderr"
}

skip() {
  skipped=$((skipped + 1))
  printf 'SKIP  %s (%s not installed)\n' "$1" "$2"
}

# expect <name> <status> [stdout substring] [stderr substring]
expect() {
  local name="$1" status="$2" out="${3:-}" err="${4:-}"
  if [[ "$last_status" == "$status" && "$last_stdout" == *"$out"* && "$last_stderr" == *"$err"* ]]; then
    pass "$name"
  else
    fail "$name"
  fi
}

# expect_file_contains <name> <file> <fixed string>
expect_file_contains() {
  if grep -qF -- "$3" "$2"; then
    pass "$1"
  else
    fail "$1"
  fi
}

have() {
  command -v "$1" >/dev/null 2>&1
}

write_file() {
  mkdir -p "$(dirname -- "$1")"
  printf '%b' "$2" >"$1"
}

# ------------------------------------------------------------- security and input

test_security() {
  write_file "${PROJECT_DIR}/src/clean.py" 'x = 1\n'

  run_check_hook /etc/passwd
  expect "rejects a file outside the project" 0 "outside the project directory"

  run_check_hook "${PROJECT_DIR}/src/../../../../etc/passwd"
  expect "rejects path traversal" 0 "outside the project directory"

  write_file "${WORK_DIR}/outside/evil.py" 'import os\n'
  ln -s "${WORK_DIR}/outside/evil.py" "${PROJECT_DIR}/src/link.py"
  run_check_hook "${PROJECT_DIR}/src/link.py"
  expect "rejects a symlink escaping the project" 0 "outside the project directory"

  run_check_hook "${PROJECT_DIR}/src/a\\nb.py"
  expect "rejects control characters in the path" 0 "control characters"

  write_file "${PROJECT_DIR}/src/\$(touch PWNED);x.md" 'x\n'
  run_check_hook "${PROJECT_DIR}/src/\$(touch PWNED);x.md"
  if [[ ! -e "${PROJECT_DIR}/src/PWNED" && ! -e "${PROJECT_DIR}/PWNED" ]]; then
    pass "does not execute shell metacharacters in file names"
  else
    fail "does not execute shell metacharacters in file names"
  fi

  last_status=0
  last_stdout="$(env -u CLAUDE_PROJECT_DIR bash "$CHECK_HOOK" \
    <<<'{"tool_input":{"file_path":"/etc/passwd"}}' 2>&1)" || last_status=$?
  last_stderr=""
  expect "exits quietly without CLAUDE_PROJECT_DIR" 0 ""
  [[ -z "$last_stdout" ]] || fail "no output without CLAUDE_PROJECT_DIR"

  last_status=0
  last_stdout="$(CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$CHECK_HOOK" <<<'not json' 2>&1)" \
    || last_status=$?
  expect "tolerates malformed JSON input" 0 ""

  run_check_hook "${PROJECT_DIR}/src/missing.py"
  expect "ignores a file that does not exist" 0 ""

  write_file "${PROJECT_DIR}/node_modules/pkg/index.py" 'import os\n'
  run_check_hook "${PROJECT_DIR}/node_modules/pkg/index.py"
  expect "skips dependency directories" 0 ""

  write_file "${PROJECT_DIR}/notes.md" '# notes\n'
  run_check_hook "${PROJECT_DIR}/notes.md"
  expect "ignores unsupported extensions" 0 ""
}

# ------------------------------------------------------------- missing tool warnings

test_missing_tool_warning() {
  local restricted="${WORK_DIR}/restricted-bin" tool
  mkdir -p "$restricted"
  for tool in bash env cat dirname realpath id mkdir grep jq python3; do
    if have "$tool"; then
      ln -sf "$(command -v "$tool")" "${restricted}/${tool}"
    fi
  done

  run_check_hook "${PROJECT_DIR}/src/clean.py" "warn-once" PATH="$restricted"
  expect "warns with JSON when ruff is missing" 0 '"systemMessage"'
  [[ "$last_stdout" == *"ruff not installed"* ]] || fail "warning names the missing tool"

  run_check_hook "${PROJECT_DIR}/src/clean.py" "warn-once" PATH="$restricted"
  if [[ "$last_status" == 0 && -z "$last_stdout" ]]; then
    pass "warns about a missing tool only once per session"
  else
    fail "warns about a missing tool only once per session"
  fi

  run_check_hook "${PROJECT_DIR}/src/clean.py" "../../evil" PATH="$restricted"
  expect "ignores an unsafe session id for state files" 0 '"systemMessage"'
  if find "$STATE_TMP" -name evil 2>/dev/null | grep -q .; then
    fail "unsafe session id created a state file"
  fi
}

# ------------------------------------------------------------- language branches

test_python() {
  have ruff || {
    skip "python format and lint" ruff
    return 0
  }
  write_file "${PROJECT_DIR}/py/a.py" 'import os\ndef fetch_user( x ):\n    return  x\n'
  run_check_hook "${PROJECT_DIR}/py/a.py"
  expect "python: reports ruff findings with exit 2" 2 "" "F401"
  expect_file_contains "python: formats the file in place" "${PROJECT_DIR}/py/a.py" 'def fetch_user(x):'

  write_file "${PROJECT_DIR}/py/b.py" 'def fetch_user(x: int) -> int:\n    return x\n'
  run_check_hook "${PROJECT_DIR}/py/b.py"
  expect "python: clean file passes silently" 0 ""
}

test_go() {
  have gofmt || {
    skip "go format" gofmt
    return 0
  }
  write_file "${PROJECT_DIR}/golang/main.go" 'package main\nfunc main(){\n}\n'
  run_check_hook "${PROJECT_DIR}/golang/main.go"
  expect "go: gofmt passes without go.mod" 0 ""
  expect_file_contains "go: formats the file in place" "${PROJECT_DIR}/golang/main.go" 'func main() {'
}

test_rust() {
  have rustfmt || {
    skip "rust format" rustfmt
    return 0
  }
  write_file "${PROJECT_DIR}/rust/lib.rs" 'pub fn fetch_id()->u8{1}\n'
  run_check_hook "${PROJECT_DIR}/rust/lib.rs"
  expect "rust: rustfmt passes without Cargo.toml" 0 ""
  expect_file_contains "rust: formats the file in place" "${PROJECT_DIR}/rust/lib.rs" 'pub fn fetch_id() -> u8 {'
}

test_javascript() {
  have prettier || {
    skip "javascript format" prettier
    return 0
  }
  write_file "${PROJECT_DIR}/js/package.json" '{"type":"module"}\n'
  write_file "${PROJECT_DIR}/js/a.js" 'export const fetchUser=(id)=>{return id}\n'
  run_check_hook "${PROJECT_DIR}/js/a.js"
  expect "javascript: prettier passes without an ESLint config" 0 ""
  expect_file_contains "javascript: formats the file in place" "${PROJECT_DIR}/js/a.js" 'export const fetchUser = (id) => {'

  write_file "${PROJECT_DIR}/js/eslint.config.js" 'export default [];\n'
  run_check_hook "${PROJECT_DIR}/js/a.js" "eslint-local"
  expect "javascript: warns when ESLint is not project-local" 0 "eslint not installed"
}

test_shell() {
  have shellcheck || {
    skip "shell lint" shellcheck
    return 0
  }
  # shellcheck disable=SC2016 # the unquoted \$1 is the finding under test
  write_file "${PROJECT_DIR}/sh/a.sh" '#!/usr/bin/env bash\necho $1\n'
  run_check_hook "${PROJECT_DIR}/sh/a.sh"
  expect "shell: reports shellcheck findings with exit 2" 2 "" "SC2086"
}

test_dart() {
  have dart || {
    skip "dart format and analysis" dart
    return 0
  }
  write_file "${PROJECT_DIR}/dartpkg/pubspec.yaml" 'name: dartpkg\nenvironment:\n  sdk: ^3.0.0\n'
  write_file "${PROJECT_DIR}/dartpkg/lib/a.dart" 'int fetchId( ){return 1;}\n'
  run_check_hook "${PROJECT_DIR}/dartpkg/lib/a.dart" "dart-pub"
  expect "dart: asks for pub get before analysis" 0 "pub get"
  expect_file_contains "dart: formats the file in place" "${PROJECT_DIR}/dartpkg/lib/a.dart" 'int fetchId() {'
}

# ------------------------------------------------------------- session start hook

test_session_start() {
  last_status=0
  last_stdout="$(env -u CLAUDE_CODE_REMOTE CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$SESSION_HOOK" </dev/null 2>&1)" || last_status=$?
  last_stderr=""
  if [[ "$last_status" == 0 && -z "$last_stdout" ]]; then
    pass "session-start: does nothing outside the web sandbox"
  else
    fail "session-start: does nothing outside the web sandbox"
  fi

  local empty="${WORK_DIR}/empty-project"
  mkdir -p "$empty"
  last_status=0
  last_stdout="$(CLAUDE_CODE_REMOTE=true CLAUDE_PROJECT_DIR="$empty" \
    bash "$SESSION_HOOK" </dev/null 2>&1)" || last_status=$?
  if [[ "$last_status" == 0 && -z "$last_stdout" ]]; then
    pass "session-start: silent when there is nothing to install"
  else
    fail "session-start: silent when there is nothing to install"
  fi

  write_file "${empty}/package.json" '{"name":"x","private":true}\n'
  last_status=0
  last_stdout="$(CLAUDE_CODE_REMOTE=true CLAUDE_PROJECT_DIR="$empty" \
    bash "$SESSION_HOOK" </dev/null 2>&1)" || last_status=$?
  if [[ "$last_status" == 0 && -z "$last_stdout" ]]; then
    pass "session-start: skips manifests without a lockfile"
  else
    fail "session-start: skips manifests without a lockfile"
  fi
}

main() {
  printf 'project: %s\n' "$PROJECT_DIR_REAL"
  test_security
  test_missing_tool_warning
  test_python
  test_go
  test_rust
  test_javascript
  test_shell
  test_dart
  test_session_start
  printf '\n%d passed, %d failed, %d skipped\n' "$passed" "$failed" "$skipped"
  ((failed == 0))
}

main "$@"
