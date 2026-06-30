#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$ROOT_DIR/tests"
REPORT_DIR="${TEST_REPORT_DIR:-$ROOT_DIR/test-reports}"
CASE_LOG_DIR="$REPORT_DIR/cases"
RESULTS_TSV="$REPORT_DIR/results.tsv"
SUMMARY_MD="$REPORT_DIR/summary.md"
RESULTS_JSON="$REPORT_DIR/results.json"
JUNIT_XML="$REPORT_DIR/junit.xml"
RED_TODO="$REPORT_DIR/red-first-todo.md"
STARTED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

mkdir -p "$CASE_LOG_DIR"
: > "$RESULTS_TSV"

source "$TEST_DIR/lib/assertions.sh"

xml_escape() {
  sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&apos;/g"
}

json_escape() {
  sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e 's/	/\\t/g'
}

safe_case_id() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9_.-]/_/g'
}

run_case() {
  local id="$1"
  local phase="$2"
  local title="$3"
  local source_doc="$4"
  local fn="$5"
  local safe_id
  local log_path
  local start_epoch
  local end_epoch
  local duration
  local status
  local message

  safe_id="$(safe_case_id "$id")"
  log_path="$CASE_LOG_DIR/$safe_id.log"
  start_epoch="$(date +%s)"

  TOTAL=$((TOTAL + 1))

  if ( set -e; "$fn" ) > "$log_path" 2>&1; then
    status="passed"
    PASSED=$((PASSED + 1))
  else
    status="failed"
    FAILED=$((FAILED + 1))
  fi

  end_epoch="$(date +%s)"
  duration=$((end_epoch - start_epoch))
  message="$(sed -n '1,20p' "$log_path" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$id" "$phase" "$status" "$duration" "$title" "$source_doc" "$log_path" "$message" >> "$RESULTS_TSV"

  if [[ "$status" == "passed" ]]; then
    printf 'ok   %-14s %s\n' "[$phase]" "$title"
  else
    printf 'fail %-14s %s\n' "[$phase]" "$title"
  fi
}

skip_case() {
  local id="$1"
  local phase="$2"
  local title="$3"
  local source_doc="$4"
  local reason="$5"
  local safe_id
  local log_path

  safe_id="$(safe_case_id "$id")"
  log_path="$CASE_LOG_DIR/$safe_id.log"
  printf 'SKIP: %s\n' "$reason" > "$log_path"

  TOTAL=$((TOTAL + 1))
  SKIPPED=$((SKIPPED + 1))

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$id" "$phase" "skipped" "0" "$title" "$source_doc" "$log_path" "$reason" >> "$RESULTS_TSV"
  printf 'skip %-14s %s\n' "[$phase]" "$title"
}

write_markdown_report() {
  {
    printf '# Orb App Test Report\n\n'
    printf -- '- Started at: `%s`\n' "$STARTED_AT"
    printf -- '- Total: `%s`\n' "$TOTAL"
    printf -- '- Passed: `%s`\n' "$PASSED"
    printf -- '- Failed: `%s`\n' "$FAILED"
    printf -- '- Skipped: `%s`\n\n' "$SKIPPED"

    printf '## Failed Cases\n\n'
    if [[ "$FAILED" -eq 0 ]]; then
      printf 'No failed cases.\n\n'
    else
      while IFS=$'\t' read -r id phase status duration title source_doc log_path message; do
        if [[ "$status" == "failed" ]]; then
          printf -- '- `%s` [%s] %s\n' "$id" "$phase" "$title"
          printf '  - Source: `%s`\n' "$source_doc"
          printf '  - Log: `%s`\n' "${log_path#$ROOT_DIR/}"
          printf '  - First output: %s\n' "$message"
        fi
      done < "$RESULTS_TSV"
      printf '\n'
    fi

    printf '## Passed Cases\n\n'
    while IFS=$'\t' read -r id phase status duration title source_doc log_path message; do
      if [[ "$status" == "passed" ]]; then
        printf -- '- `%s` [%s] %s\n' "$id" "$phase" "$title"
      fi
    done < "$RESULTS_TSV"
  } > "$SUMMARY_MD"
}

write_json_report() {
  local first="true"
  {
    printf '{\n'
    printf '  "started_at": "%s",\n' "$STARTED_AT"
    printf '  "summary": {"total": %s, "passed": %s, "failed": %s, "skipped": %s},\n' "$TOTAL" "$PASSED" "$FAILED" "$SKIPPED"
    printf '  "results": [\n'
    while IFS=$'\t' read -r id phase status duration title source_doc log_path message; do
      if [[ "$first" != "true" ]]; then
        printf ',\n'
      fi
      first="false"
      printf '    {"id": "%s", "phase": "%s", "status": "%s", "duration_seconds": %s, "title": "%s", "source": "%s", "log": "%s", "message": "%s"}' \
        "$(printf '%s' "$id" | json_escape)" \
        "$(printf '%s' "$phase" | json_escape)" \
        "$(printf '%s' "$status" | json_escape)" \
        "$duration" \
        "$(printf '%s' "$title" | json_escape)" \
        "$(printf '%s' "$source_doc" | json_escape)" \
        "$(printf '%s' "${log_path#$ROOT_DIR/}" | json_escape)" \
        "$(printf '%s' "$message" | json_escape)"
    done < "$RESULTS_TSV"
    printf '\n  ]\n'
    printf '}\n'
  } > "$RESULTS_JSON"
}

write_junit_report() {
  {
    printf '<?xml version="1.0" encoding="UTF-8"?>\n'
    printf '<testsuite name="orb-red-first" tests="%s" failures="%s" skipped="%s" timestamp="%s">\n' "$TOTAL" "$FAILED" "$SKIPPED" "$STARTED_AT"
    while IFS=$'\t' read -r id phase status duration title source_doc log_path message; do
      printf '  <testcase classname="Orb.%s" name="%s" time="%s">' \
        "$(printf '%s' "$phase" | xml_escape)" \
        "$(printf '%s' "$id $title" | xml_escape)" \
        "$duration"
      if [[ "$status" == "failed" ]]; then
        printf '<failure message="%s"><![CDATA[' "$(printf '%s' "$message" | xml_escape)"
        sed -n '1,120p' "$log_path"
        printf ']]></failure>'
      elif [[ "$status" == "skipped" ]]; then
        printf '<skipped message="%s" />' "$(printf '%s' "$message" | xml_escape)"
      fi
      printf '</testcase>\n'
    done < "$RESULTS_TSV"
    printf '</testsuite>\n'
  } > "$JUNIT_XML"
}

write_red_todo() {
  {
    printf '# Red-First TODO\n\n'
    printf 'Generated from failed tests at `%s`.\n\n' "$STARTED_AT"
    while IFS=$'\t' read -r id phase status duration title source_doc log_path message; do
      if [[ "$status" == "failed" ]]; then
        printf -- '- [ ] `%s` [%s] %s\n' "$id" "$phase" "$title"
        printf '  - Evidence: %s\n' "$message"
      fi
    done < "$RESULTS_TSV"
  } > "$RED_TODO"
}

for spec in "$TEST_DIR"/specs/*.sh; do
  source "$spec"
done

write_markdown_report
write_json_report
write_junit_report
write_red_todo

printf '\nReports written to %s\n' "${REPORT_DIR#$ROOT_DIR/}"
printf 'Total: %s, passed: %s, failed: %s, skipped: %s\n' "$TOTAL" "$PASSED" "$FAILED" "$SKIPPED"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
