#!/bin/sh
# docs-lint-test.sh — the fixture corpus for scripts/docs-lint.sh.
#
# Why this exists. `docs-lint.sh` shipped four rounds of fixes, and three of those rounds
# introduced a fresh escape while closing the previous one. Every regression was found by
# hand, after shipping, because CI ran the linter only against the repo's own live
# documents — which proves those documents pass and proves NOTHING about whether any
# check works. A green run on a linter whose checks have stopped firing looks exactly
# like a green run on a healthy repo.
#
# Each case asserts the specific FAIL TEXT, not just the exit code. A check that fails
# for the wrong reason is a check that will be "fixed" by changing the wrong thing, and
# several of the historical regressions produced a real failure with a misleading
# message. Cases named `*-ok.case` assert the linter stays SILENT: half of the
# regressions were false positives, and a corpus of only-failures would have missed them.
#
# Directives are `@@@ `-prefixed, not `--- `: a fixture whose CONTENT began "--- " was
# silently truncated at that line, so the construct it existed to test was not on disk and
# the case passed for the wrong reason. A thematic break (bare `---`) is legitimate markdown
# and every register fixture uses one.
#
# Usage: sh scripts/docs-lint-test.sh [case-name-substring]
# POSIX sh — no dependencies.

set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="$ROOT/tests/docs-lint"
FILTER="${1:-}"
WORK="${TMPDIR:-/tmp}/docs-lint-test.$$"
trap 'rm -rf "$WORK"' EXIT INT TERM

# Parse the linter before exercising it. A syntax error partway through a shell script can
# end a run with status 0 — the linter never reaches its checks and reports success on a
# script that did nothing. That happened once while it was being written, and this used to
# be a separate CI step; the corpus is where it lives now that the gate is local.
if ! sh -n "$ROOT/scripts/docs-lint.sh"; then
  echo "FAIL  scripts/docs-lint.sh does not parse — a syntax error can exit 0 and look green."
  exit 1
fi

pass=0; fail=0
for case_file in "$CASES"/*.case; do
  [ -f "$case_file" ] || continue
  name=$(basename "$case_file" .case)
  case "$name" in *"$FILTER"*) ;; *) continue ;; esac

  rm -rf "$WORK"; mkdir -p "$WORK/scripts" "$WORK/docs/specs" "$WORK/docs/spec-delivery"

  # Small caps, so a fixture can be a few lines rather than a few kilobytes. Applied by
  # rewriting the constants in a COPY — deliberately not env overrides, because a budget
  # a caller can lower is a budget CI can be told to ignore.
  sed -e 's/^CLAUDE_MAX_BYTES=.*/CLAUDE_MAX_BYTES=2000/' \
      -e 's/^KEY_DECISIONS_MAX_BYTES=.*/KEY_DECISIONS_MAX_BYTES=1200/' \
      -e 's/^DIGEST_MAX_BYTES=.*/DIGEST_MAX_BYTES=300/' \
      -e 's/^DELIVERY_MAX_LINES=.*/DELIVERY_MAX_LINES=10/' \
      "$ROOT/scripts/docs-lint.sh" > "$WORK/scripts/docs-lint.sh"
  chmod +x "$WORK/scripts/docs-lint.sh"

  # Split the case into its expectations and its files.
  want_exit=$(sed -n 's/^@@@ expect exit=//p' "$case_file")
  awk -v work="$WORK" '
    /^@@@ file / { path = work "/" substr($0, 10); system("mkdir -p $(dirname \"" path "\")"); out = path; next }
    /^@@@ / { out = ""; next }
    out { print >> out }
  ' "$case_file"

  got=$(cd "$WORK" && sh scripts/docs-lint.sh 2>&1) && rc=0 || rc=$?
  ok=1
  [ "$rc" = "${want_exit:-0}" ] || { ok=0; why="exit $rc, wanted ${want_exit:-0}"; }
  if [ "$ok" = 1 ]; then
    sed -n 's/^@@@ match //p' "$case_file" | while IFS= read -r m; do
      [ -n "$m" ] || continue
      case "$got" in *"$m"*) ;; *) echo "MISSING|$m" ;; esac
    done > "$WORK/.miss"
    if [ -s "$WORK/.miss" ]; then ok=0; why="output lacked: $(sed 's/^MISSING|//' "$WORK/.miss" | head -1)"; fi
  fi
  # A `-ok` case must be silent: no FAIL line may appear at all.
  case "$name" in
    *-ok) case "$got" in *"FAIL  "*) ok=0; why="expected silence, got a FAIL" ;; esac ;;
  esac

  if [ "$ok" = 1 ]; then
    pass=$((pass + 1)); echo "ok    $name"
  else
    fail=$((fail + 1)); echo "FAIL  $name: $why"
    printf '%s\n' "$got" | sed 's/^/        /' | head -8
  fi
done

echo "----"
echo "docs-lint-test: $pass passed, $fail failed."
[ "$fail" -eq 0 ] || exit 1
