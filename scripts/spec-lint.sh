#!/bin/sh
# spec-lint.sh — structural linter for spec files.
#
# FAIL (exit 1):
#   - a spec is missing a required top-level section, OR
#   - a spec contains a banned "Open Questions" / "Checkpoint" header
#     (these are resolved during authoring or in-session, never parked in the spec).
# WARN (exit 0): soft issues — unfilled template placeholders, FRs with no acceptance
#   criteria, and a spec carrying more FRs than one buildable slice should (see
#   FR_CEILING below). The ceiling is a warn, not a fail: an indivisible spec can
#   legitimately sit above it, and that call belongs to the reviewer, not the lint.
#
# Usage: scripts/spec-lint.sh [spec-dir]     (default: docs/specs)
# POSIX sh — no bashisms; runs anywhere /bin/sh exists.

set -eu

SPEC_DIR="${1:-docs/specs}"

# Above this many FRs, a spec has usually stopped being one buildable slice and
# wants splitting into two specs recorded as an arc (docs/process.md §4).
FR_CEILING=8
fail=0
warn=0

# Required top-level sections every spec must have (exact "## " headings).
required_sections="## Overview
## Scope
## Functional Requirements
## Implementation Phases"

# Headings (any level) that must NOT appear.
banned_headers="Open Questions|Checkpoint"

specs=$(find "$SPEC_DIR" -maxdepth 1 -type f -name 'SPEC-*.md' 2>/dev/null | sort || true)

# Split the list on newlines only — an unquoted expansion on default IFS turns a
# spec filename containing a space into two nonexistent paths and four bogus FAILs.
IFS='
'

if [ -z "$specs" ]; then
  echo "spec-lint: no SPEC-*.md files in $SPEC_DIR (nothing to check)."
  exit 0
fi

for f in $specs; do
  file_fail=0

  # --- required sections ---
  echo "$required_sections" | while IFS= read -r sec; do
    [ -n "$sec" ] || continue
    grep -qiE "^${sec}([[:space:]]|\$)" "$f" || echo "MISSING|$sec"
  done > /tmp/spec-lint-missing.$$
  if [ -s /tmp/spec-lint-missing.$$ ]; then
    while IFS='|' read -r _ sec; do
      echo "FAIL  $f: missing required section '$sec'"
    done < /tmp/spec-lint-missing.$$
    file_fail=1
  fi
  rm -f /tmp/spec-lint-missing.$$

  # --- banned headers (any heading level) ---
  if grep -qiE "^#{1,6}[[:space:]].*(${banned_headers})" "$f"; then
    echo "FAIL  $f: contains banned header(s) — resolve in spec/session, don't park them:"
    grep -inE "^#{1,6}[[:space:]].*(${banned_headers})" "$f" | head -3 | sed 's/^/        line /'
    file_fail=1
  fi

  # --- WARN: unfilled template placeholders ---
  if grep -qE '\[Feature Name\]|\[Requirement Name\]|SPEC-XXX|YYYY-MM-DD' "$f"; then
    echo "WARN  $f: unfilled template placeholder(s) (e.g. [Feature Name], SPEC-XXX, YYYY-MM-DD)"
    warn=$((warn + 1))
  fi

  # --- WARN: FRs present but no acceptance criteria ---
  if grep -qE '^### FR-' "$f" && ! grep -qiE 'Acceptance Criteria' "$f"; then
    echo "WARN  $f: has FR-* requirements but no 'Acceptance Criteria'"
    warn=$((warn + 1))
  fi

  # --- WARN: more FRs than one spec should carry ---
  # Level-3 headings only (what the spec template emits, and what the check
  # above already uses), outside fenced blocks and HTML comments, counted as
  # distinct IDs. Without the skips, a spec that quotes FR headings in an
  # example — or comments some out while splitting — is told to split on
  # requirements it does not have. A comment is closed before a fence is
  # opened, so a ``` inside a comment cannot swallow the rest of the file;
  # ~~~ counts as a fence; and a one-line <!-- … --> is stripped rather than
  # skipped, so a heading with a trailing note still counts.
  fr_count=$(awk '
    { line = $0 }
    in_comment { if (line ~ /-->/) in_comment = 0; next }
    in_fence   { if (line ~ /^[[:space:]]*(```|~~~)/) in_fence = 0; next }
    line ~ /^[[:space:]]*(```|~~~)/ { in_fence = 1; next }
    { gsub(/<!--[^>]*-->/, "", line) }
    line ~ /<!--/ { in_comment = 1; next }
    match(line, /^### FR-[0-9]+/) { print substr(line, RSTART + 4, RLENGTH - 4) }
  ' "$f" | sort -u | wc -l | tr -d '[:space:]')
  if [ "${fr_count:-0}" -gt "$FR_CEILING" ]; then
    echo "WARN  $f: $fr_count FRs (over the $FR_CEILING ceiling) — split into two specs and record them as an arc"
    warn=$((warn + 1))
  fi

  [ "$file_fail" -eq 0 ] && echo "ok    $f" || fail=$((fail + 1))
done

echo "----"
echo "spec-lint: $fail file(s) failed, $warn warning(s)."
[ "$fail" -eq 0 ] || exit 1
