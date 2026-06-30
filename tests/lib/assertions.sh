#!/usr/bin/env bash

fail() {
  printf 'FAIL: %s\n' "$*"
  exit 1
}

find_source_files() {
  local dir="$1"

  find "$dir" \
    \( \
      -path '*/.git' -o \
      -path '*/node_modules' -o \
      -path '*/dist' -o \
      -path '*/build' -o \
      -path '*/coverage' -o \
      -path '*/test-results' -o \
      -path '*/playwright-report' -o \
      -path '*/.next' -o \
      -path '*/.turbo' \
    \) -prune -o \
    -type f -print 2>/dev/null
}

assert_path_exists() {
  local path="$1"
  local message="${2:-path is required}"
  [[ -e "$path" ]] || fail "$message (missing: $path)"
}

assert_dir_exists() {
  local path="$1"
  local message="${2:-directory is required}"
  [[ -d "$path" ]] || fail "$message (missing directory: $path)"
}

assert_file_exists() {
  local path="$1"
  local message="${2:-file is required}"
  [[ -f "$path" ]] || fail "$message (missing file: $path)"
}

assert_file_contains() {
  local path="$1"
  local pattern="$2"
  local message="${3:-file must contain expected pattern}"

  [[ -f "$path" ]] || fail "$message (missing file: $path)"
  grep -Eq "$pattern" "$path" || fail "$message (pattern not found: $pattern in $path)"
}

assert_file_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="${3:-file must not contain forbidden pattern}"

  [[ -f "$path" ]] || fail "$message (missing file: $path)"
  if grep -Eq "$pattern" "$path"; then
    fail "$message (forbidden pattern found: $pattern in $path)"
  fi
}

assert_any_file_contains() {
  local dir="$1"
  local pattern="$2"
  local message="${3:-at least one file must contain expected pattern}"
  local file

  [[ -d "$dir" ]] || fail "$message (missing directory: $dir)"

  while IFS= read -r file; do
    if grep -Eq "$pattern" "$file"; then
      return 0
    fi
  done < <(find_source_files "$dir")

  fail "$message (pattern not found under $dir: $pattern)"
}

assert_no_file_contains() {
  local dir="$1"
  local pattern="$2"
  local message="${3:-no file may contain forbidden pattern}"
  local file

  [[ -d "$dir" ]] || fail "$message (missing directory: $dir)"

  while IFS= read -r file; do
    if grep -Eq "$pattern" "$file"; then
      fail "$message (forbidden pattern found in $file: $pattern)"
      return 1
    fi
  done < <(find_source_files "$dir")
}

assert_package_json_script() {
  local path="$1"
  local script_name="$2"
  local message="${3:-package script is required}"

  assert_file_contains "$path" "\"$script_name\"[[:space:]]*:" "$message"
}

assert_openapi_path() {
  local path="$1"
  local endpoint="$2"
  local message="${3:-OpenAPI path is required}"

  assert_file_contains "$path" "$endpoint" "$message"
}

assert_contract_fixture() {
  local root="$1"
  local pattern="$2"
  local message="${3:-contract fixture is required}"
  local found

  [[ -d "$root" ]] || fail "$message (missing fixture directory: $root)"
  found="$(find "$root" -type f -name "$pattern" -print -quit 2>/dev/null)"
  [[ -n "$found" ]] || fail "$message (missing fixture matching: $pattern under $root)"
}

assert_phase_source() {
  local doc="$1"
  local pattern="$2"
  local message="${3:-documentation source must contain scope}"

  assert_file_contains "$doc" "$pattern" "$message"
}
