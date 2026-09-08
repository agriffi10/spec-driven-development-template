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
# Overridable so the SELF-TEST at the bottom can point this script at a directory of
# deliberately malformed cases. Not a budget and not a threshold — pointing the harness
# at different fixtures cannot make a real case pass.
CASES="${DOCS_LINT_TEST_CASES:-$ROOT/tests/docs-lint}"
FILTER="${1:-}"
WORK="${TMPDIR:-/tmp}/docs-lint-test.$$"
trap 'rm -rf "$WORK" "$WORK.self" "$WORK.floor"' EXIT
trap 'exit 1' INT TERM

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
      -e 's/^ALWAYS_LOADED_MAX_BYTES=.*/ALWAYS_LOADED_MAX_BYTES=1500/' \
      "$ROOT/scripts/docs-lint.sh" > "$WORK/scripts/docs-lint.sh"
  chmod +x "$WORK/scripts/docs-lint.sh"

  # Split the case into its expectations and its files.
  want_exit=$(sed -n 's/^@@@ expect exit=//p' "$case_file")
  awk -v work="$WORK" '
    /^@@@ file / { path = work "/" substr($0, 10); system("mkdir -p \"$(dirname \"" path "\")\""); out = path; next }
    /^@@@ / { out = ""; next }
    out { print >> out }
  ' "$case_file"

  # A fixture that never reaches disk makes its case silent for the WRONG reason, and an
  # `-ok` case cannot tell that apart from a pass: two planted cases — one with a mistyped
  # `@@@  file` directive, one writing outside the linter population — both reported ok.
  # So the directives are checked before the linter is allowed to have an opinion.
  decl=$(sed -n 's|^@@@ file ||p' "$case_file")
  if [ -z "$decl" ]; then
    fail=$((fail + 1)); echo "FAIL  $name: declares no '@@@ file' directive, so nothing reached disk."
    continue
  fi
  missing=""
  for d in $decl; do [ -f "$WORK/$d" ] || missing="$missing $d"; done
  if [ -n "$missing" ]; then
    fail=$((fail + 1)); echo "FAIL  $name: declared file(s) never written:$missing"
    continue
  fi
  # A directive the splitter does not recognise is DISCARDED silently along with the body
  # it introduced, which is how the mistyped one got through. Count them instead — and
  # count on `^@@@`, not `^@@@ `, because `@@@file`, `@@@<tab>file` and `@@@@ file` break
  # the prefix the splitter keys on and would otherwise escape this guard as well as the
  # one above it.
  if [ "$(grep -c '^@@@' "$case_file")" != "$(grep -cE '^@@@ (file |expect exit=|match )' "$case_file")" ]; then
    fail=$((fail + 1)); echo "FAIL  $name: an '@@@' line is not one of file/expect exit=/match."
    continue
  fi

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

# A filter that matched no case is a misspelling, not a pass: a filtered run that ran nothing has
# proved nothing, and it used to print the success line above. Checked before the floor, which a
# filtered run is exempt from by design.
if [ -n "$FILTER" ] && [ "$((pass + fail))" -eq 0 ]; then
  echo "docs-lint-test: the filter '$FILTER' matched no case. Nothing ran, so nothing passed."
  exit 1
fi

# A FLOOR, NOT AN EXIT CODE. Every mechanical way to lose the corpus — a renamed
# directory, a glob that stops matching, a filter typo, an empty CASES path — ends with
# zero cases run and `0 passed, 0 failed`, which exits 0 and prints a success line. That
# is the whole-corpus version of the defect the per-case guards above exist to close, and
# a green run over nothing is indistinguishable from a green run over everything.
#
# Deliberately BELOW the measurement rather than at it, so adding cases needs no edit
# here. Removing them does, and that is the point: a case pruned on purpose is a
# one-line, deliberate lowering in the same change; a case lost by accident reds the run.
# Not applied to the self-test invocation, which runs a handful of planted cases. Derived
# in log-forge, where a floor left slack enough that deleting one whole family of cases
# still printed a success line was measured; re-derived here for the template's own corpus
# — 175 at the commit that took the register cross-checks and check 14 up (121 inherited
# plus 54 taken over) — with headroom of FIVE, below the smallest family (the six tree
# cases), so losing any whole family fires and pruning a case or two does not. A first
# draft set it at 150 and claimed the same thing; measured by deleting families from a
# copy, that floor let two of the three ported families vanish green.
CASES_MIN=170
if { [ -z "${DOCS_LINT_TEST_CASES:-}" ] || [ -n "${DOCS_LINT_TEST_FLOOR:-}" ]; } && [ -z "$FILTER" ] && [ "$pass" -lt "$CASES_MIN" ]; then
  echo "docs-lint-test: only $pass cases ran, against a floor of $CASES_MIN. The corpus has"
  echo "shrunk or gone missing — a run over nothing exits 0 and looks exactly like a healthy"
  echo "one. If cases were removed on purpose, lower CASES_MIN in the same change."
  exit 1
fi

# ── self-test: the three guards above have to fire ─────────────────────────────
#
# The guards exist because a case whose fixture never reached disk reported `ok` — a
# silence case passing for the wrong reason, in the one file whose entire job is to make
# silence mean something. Nothing in tests/docs-lint can cover them: a case that trips a
# guard is by construction a FAILING case, so shipping one would leave the corpus red.
#
# WATCH OUT when adding one: `scripts/**` is inside check 14's own population, and the
# `tests/` exclusion that lets a .case file carry the gated form does not reach this file.
# A self-test case that must contain "measured <ISO date>" therefore has to build the
# string from a variable or sit inside a fenced block, or `docs-lint.sh` fails on this
# very script. None of the cases below needs it, which is why none of them does it.
#
# So the guards get a corpus of their own, run here against a temp directory and asserting
# the FAIL TEXT rather than the exit code — each guard has a distinct message, and a guard
# that fires for the wrong reason is one that gets fixed in the wrong place. Removing any
# one of these three guards turns its case green, which is the whole claim.
if [ -z "${DOCS_LINT_TEST_CASES:-}" ] && [ -z "$FILTER" ]; then
  SELF="$WORK.self"
  rm -rf "$SELF"; mkdir -p "$SELF"
  skeleton='@@@ file CLAUDE.md
# Project

## Key Decisions

Intro prose.

| Area | Fences |
|---|---|
| Area one | `docs/decisions/area-one.md#fences` |
@@@ file docs/decisions/INDEX.md
# Register

## Areas

| Area | Fences | Governs |
|---|---|---|
| Area one | `docs/decisions/area-one.md#fences` | none |
@@@ file docs/decisions/area-one.md
# Area one — decisions

intro

## Contents

- [Fences](#fences)
- [Alpha rule](#alpha-rule)

## Fences

- **Alpha rule** — short claim.

---

### Alpha rule

Reasoning.'

  # 1. No `@@@ file` at all: nothing is written, so the linter examines an empty tree.
  printf '@@@ expect exit=0\n' > "$SELF/no-file-ok.case"
  # 2. A recognised directive naming a file the splitter never writes.
  printf '@@@ expect exit=0\n@@@ file docs/never.md\n%s\n' "$skeleton" > "$SELF/unwritten-ok.case"
  # 3. Three typos that each break the `@@@ ` prefix the splitter keys on. The body is
  #    discarded with the directive, so the fixture is absent and the case is vacuous.
  #    Named one at a time rather than derived from the typo: deriving them with
  #    `tr -c 'a-z' '-'` mapped two of the three to the same filename, so one silently
  #    overwrote the other and the count printed below was wrong. A generated name is a
  #    name nobody checks for collisions.
  set -- 'double-space:@@@  file' 'no-space:@@@file' 'four-at:@@@@ file'
  for pair in "$@"; do
    n=${pair%%:*}; typo=${pair#*:}
    printf '@@@ expect exit=0\n%s docs/typo.md\ncontent\n%s\n' "$typo" "$skeleton" > "$SELF/typo-$n-ok.case"
  done

  # Counted from disk, never asserted as a literal: the count that was hand-written here
  # was wrong the moment two planted names collided, in a change whose whole subject is
  # numbers that stop being true.
  planted=$(ls "$SELF" | wc -l | tr -d ' ')
  self_out=$(DOCS_LINT_TEST_CASES="$SELF" sh "$0" 2>&1) && self_rc=0 || self_rc=$?
  rm -rf "$SELF"
  self_fail=0
  for want in \
    "no-file-ok: declares no '@@@ file' directive" \
    "unwritten-ok: declared file(s) never written" \
    "an '@@@' line is not one of file/expect exit=/match"
  do
    case "$self_out" in
      *"$want"*) ;;
      *) echo "FAIL  self-test: a guard did not fire — expected \"$want\"."; self_fail=1 ;;
    esac
  done
  # Every planted case must be reported as a failure; none may report ok.
  case "$self_out" in *"ok    "*) echo "FAIL  self-test: a deliberately vacuous case reported ok."; self_fail=1 ;; esac
  [ "$self_rc" -ne 0 ] || { echo "FAIL  self-test: the harness exited 0 on a directory of vacuous cases."; self_fail=1; }
  if [ "$self_fail" -ne 0 ]; then
    echo "----"
    echo "docs-lint-test: the fixture guards are not firing. A case whose files never reach"
    echo "disk would pass silently, which is how this harness went green over nothing."
    exit 1
  fi
  echo "docs-lint-test: fixture guards verified — 3 guards, $planted vacuous cases refused."

  # The FLOOR has to fire too, and nothing above proves it: the self-test invocation sets
  # DOCS_LINT_TEST_CASES, which disables the floor so a handful of planted cases can run.
  # DOCS_LINT_TEST_FLOOR re-enables it for this one run over a copy of three real cases —
  # far under the floor — which must exit non-zero and name the floor. A floor that cannot
  # be shown to fire is a success line waiting to be printed over nothing.
  FLOOR="$WORK.floor"
  rm -rf "$FLOOR"; mkdir -p "$FLOOR"
  n=0
  for c in "$CASES"/*.case; do
    [ -f "$c" ] || continue
    cp "$c" "$FLOOR/"; n=$((n + 1)); [ "$n" -ge 3 ] && break
  done
  floor_out=$(DOCS_LINT_TEST_CASES="$FLOOR" DOCS_LINT_TEST_FLOOR=1 sh "$0" 2>&1) && floor_rc=0 || floor_rc=$?
  rm -rf "$FLOOR"
  floor_fail=0
  [ "$floor_rc" -ne 0 ] || { echo "FAIL  self-test: the harness exited 0 on $n cases, under a floor of $CASES_MIN."; floor_fail=1; }
  case "$floor_out" in
    *"against a floor of $CASES_MIN"*) ;;
    *) echo "FAIL  self-test: a run under the floor did not name the floor."; floor_fail=1 ;;
  esac
  if [ "$floor_fail" -ne 0 ]; then
    echo "----"
    echo "docs-lint-test: the case floor is not firing. A corpus that shrinks to nothing would"
    echo "print a success line, which is the failure the floor exists to refuse."
    exit 1
  fi
  echo "docs-lint-test: the case floor fires — $n cases refused against $CASES_MIN."
fi
