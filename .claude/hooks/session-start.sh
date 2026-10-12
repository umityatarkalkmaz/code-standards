#!/usr/bin/env bash
# SessionStart hook (Claude Code on the web only): installs project dependencies
# project-scoped, so the tools check-file.sh looks for (node_modules/.bin, vendor/bin,
# .venv/bin, pub packages) are available in a fresh cloud sandbox.
#
# Only installs from lockfiles that are committed to the project, never globally.
# Prints a short report on stdout, which Claude receives as session context.
set -euo pipefail
IFS=$'\n\t'
umask 022

[[ "${CLAUDE_CODE_REMOTE:-}" == "true" ]] || exit 0
[[ -n "${CLAUDE_PROJECT_DIR:-}" && -d "${CLAUDE_PROJECT_DIR}" ]] || exit 0

readonly STEP_TIMEOUT_SECONDS=240
readonly MAX_DEPTH=3

installed=()
failed=()
missing=()

# run_install <label> <workdir> <command...>
run_install() {
  local label="$1" workdir="$2"
  shift 2
  local status=0 log
  log="$(mktemp)"
  if command -v timeout >/dev/null 2>&1; then
    (cd -- "$workdir" && timeout "$STEP_TIMEOUT_SECONDS" "$@") >"$log" 2>&1 || status=$?
  else
    (cd -- "$workdir" && "$@") >"$log" 2>&1 || status=$?
  fi
  if ((status == 0)); then
    installed+=("$label")
  else
    local reason
    reason="$(grep -m 1 -iE 'error|fatal|failed' "$log" || tail -n 1 "$log" || true)"
    failed+=("${label} (exit ${status}: $(printf '%s' "$reason" | tr -d '\r' | cut -c1-160))")
  fi
  rm -f -- "$log"
}

note_missing() {
  local tool="$1" item
  for item in "${missing[@]}"; do
    [[ "$item" == "$tool" ]] && return 0
  done
  missing+=("$tool")
}

# find_manifests <file name>: manifest paths up to MAX_DEPTH, skipping dependency dirs
find_manifests() {
  find "$CLAUDE_PROJECT_DIR" -maxdepth "$MAX_DEPTH" \
    \( -name node_modules -o -name vendor -o -name .git -o -name target -o -name .venv \
       -o -name .dart_tool -o -name build -o -name dist \) -prune \
    -o -type f -name "$1" -print
}

relative_dir() {
  local dir="$1"
  if [[ "$dir" == "$CLAUDE_PROJECT_DIR" ]]; then
    printf '.\n'
  else
    printf '%s\n' "${dir#"$CLAUDE_PROJECT_DIR"/}"
  fi
}

install_node() {
  local manifest dir rel
  while IFS= read -r manifest; do
    dir="$(dirname -- "$manifest")"
    rel="$(relative_dir "$dir")"
    if [[ -f "${dir}/package-lock.json" ]]; then
      if command -v npm >/dev/null 2>&1; then
        run_install "npm (${rel})" "$dir" npm install --no-audit --no-fund
      else
        note_missing npm
      fi
    elif [[ -f "${dir}/pnpm-lock.yaml" ]]; then
      if command -v pnpm >/dev/null 2>&1; then
        run_install "pnpm (${rel})" "$dir" pnpm install --frozen-lockfile
      else
        note_missing pnpm
      fi
    elif [[ -f "${dir}/yarn.lock" ]]; then
      if command -v yarn >/dev/null 2>&1; then
        run_install "yarn (${rel})" "$dir" yarn install --immutable
      else
        note_missing yarn
      fi
    fi
  done < <(find_manifests package.json)
}

install_php() {
  local manifest dir
  while IFS= read -r manifest; do
    dir="$(dirname -- "$manifest")"
    [[ -f "${dir}/composer.lock" ]] || continue
    if command -v composer >/dev/null 2>&1; then
      run_install "composer ($(relative_dir "$dir"))" "$dir" \
        composer install --no-interaction --no-progress
    else
      note_missing composer
    fi
  done < <(find_manifests composer.json)
}

install_python() {
  local manifest dir
  while IFS= read -r manifest; do
    dir="$(dirname -- "$manifest")"
    [[ -f "${dir}/uv.lock" ]] || continue
    if command -v uv >/dev/null 2>&1; then
      run_install "uv ($(relative_dir "$dir"))" "$dir" uv sync --frozen
    else
      note_missing uv
    fi
  done < <(find_manifests pyproject.toml)
}

install_dart() {
  local manifest dir rel
  while IFS= read -r manifest; do
    dir="$(dirname -- "$manifest")"
    rel="$(relative_dir "$dir")"
    if grep -qE '^[[:space:]]+sdk:[[:space:]]*flutter[[:space:]]*$' "$manifest"; then
      if command -v flutter >/dev/null 2>&1; then
        run_install "flutter pub get (${rel})" "$dir" flutter pub get
      else
        note_missing flutter
      fi
    elif command -v dart >/dev/null 2>&1; then
      run_install "dart pub get (${rel})" "$dir" dart pub get
    else
      note_missing dart
    fi
  done < <(find_manifests pubspec.yaml)
}

install_go() {
  local manifest dir
  while IFS= read -r manifest; do
    dir="$(dirname -- "$manifest")"
    if command -v go >/dev/null 2>&1; then
      run_install "go mod download ($(relative_dir "$dir"))" "$dir" go mod download
    else
      note_missing go
    fi
  done < <(find_manifests go.mod)
}

install_rust() {
  local manifest dir
  while IFS= read -r manifest; do
    dir="$(dirname -- "$manifest")"
    [[ -f "${dir}/Cargo.lock" ]] || continue
    if command -v cargo >/dev/null 2>&1; then
      run_install "cargo fetch ($(relative_dir "$dir"))" "$dir" cargo fetch --locked
    else
      note_missing cargo
    fi
  done < <(find_manifests Cargo.toml)
}

join_items() {
  local joined="" item
  for item in "$@"; do
    joined+="${joined:+, }${item}"
  done
  printf '%s\n' "$joined"
}

print_report() {
  ((${#installed[@]} + ${#failed[@]} + ${#missing[@]} > 0)) || return 0
  printf 'code-standards session setup (project-scoped dependency install):\n'
  ((${#installed[@]} == 0)) || printf -- '- installed: %s\n' "$(join_items "${installed[@]}")"
  ((${#failed[@]} == 0)) || printf -- '- failed: %s\n' "$(join_items "${failed[@]}")"
  if ((${#missing[@]} > 0)); then
    printf -- '- toolchains not available in this sandbox: %s\n' "$(join_items "${missing[@]}")"
    printf -- '  Files in these languages are not verified by the check-file hook; apply the reference Checklist manually.\n'
  fi
}

main() {
  install_node
  install_php
  install_python
  install_dart
  install_go
  install_rust
  print_report
}

main "$@"
