#!/bin/sh
# spec-lint-test.sh — the fixture corpus for scripts/spec-lint.sh.
#
# Why this exists. The template shipped `spec-lint.sh` with no corpus at all: two of its five
# checks can fail a build and three only warn, and nothing proved any of the five still fired —
# CI ran it over `docs/specs/`, which proves the specs pass and nothing about whether a check
# works. A consumer built this corpus first (log-forge, alongside its own invariant-citation
# check); its first run found a real defect the live specs could not show. A gate owes a fixture
# corpus asserting the failure REASON, silence cases included, and spec-lint is a gate: it is the
# one check the template runs in CI.
#
# Each case asserts the specific FAIL or WARN TEXT, not just the exit code. A check that fails
# for the wrong reason is a check that will be "fixed" by changing the wrong thing. Cases named
# `*-ok.case` assert the linter stays SILENT — no `FAIL  ` line at all — and that is where the
# exemptions live: the fenced or commented-out FR heading, the case-insensitive section match,
# the duplicate FR id, the filename with a space.
#
# Directives are `@@@ `-prefixed, as in `docs-lint-test.sh`, and for the same reason: a fixture
# whose content began `--- ` was once truncated there silently. `@@@ absent` is the directive a
# WARN check needs — silence there means "no WARN line" rather than "no FAIL line".
#
# Usage: sh scripts/spec-lint-test.sh [case-name-substring]
# POSIX sh — no dependencies.

set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Overridable so the SELF-TEST at the bottom can point this script at a directory of
# deliberately malformed cases. Pointing the harness at different fixtures cannot make a
# real case pass.
CASES="${SPEC_LINT_TEST_CASES:-$ROOT/tests/spec-lint}"
FILTER="${1:-}"
WORK="${TMPDIR:-/tmp}/spec-lint-test.$$"
trap 'rm -rf "$WORK" "$WORK.self"' EXIT
trap 'exit 1' INT TERM

# Parse the linter before exercising it. A syntax error partway through a shell script can
# end a run with status 0 — the linter never reaches its checks and reports success on a
# script that did nothing.
if ! sh -n "$ROOT/scripts/spec-lint.sh"; then
  echo "FAIL  scripts/spec-lint.sh does not parse — a syntax error can exit 0 and look green."
  exit 1
fi

pass=0; fail=0
for case_file in "$CASES"/*.case; do
  [ -f "$case_file" ] || continue
  name=$(basename "$case_file" .case)
  case "$name" in *"$FILTER"*) ;; *) continue ;; esac

  rm -rf "$WORK"; mkdir -p "$WORK/scripts" "$WORK/docs/specs"

  # A small FR ceiling, so the over-the-ceiling case can be four short FRs rather than
  # nine. Applied by rewriting the constant in a COPY — not an env override, because a
  # ceiling a caller can lower is a ceiling CI can be told to ignore.
  sed -e 's/^FR_CEILING=.*/FR_CEILING=3/' "$ROOT/scripts/spec-lint.sh" > "$WORK/scripts/spec-lint.sh"
  chmod +x "$WORK/scripts/spec-lint.sh"

  want_exit=$(sed -n 's/^@@@ expect exit=//p' "$case_file")
  awk -v work="$WORK" '
    /^@@@ file / { path = work "/" substr($0, 10); system("mkdir -p \"$(dirname \"" path "\")\""); out = path; next }
    /^@@@ / { out = ""; next }
    out { print >> out }
  ' "$case_file"

  # A fixture that never reaches disk makes its case silent for the WRONG reason, and an
  # `-ok` case cannot tell that apart from a pass. So the directives are checked before the
  # linter is allowed to have an opinion: every case declares at least one file, every
  # declared file was written, and every `@@@` line is a directive the splitter knows —
  # counted on `^@@@`, not `^@@@ `, because `@@@file`, `@@@<tab>file` and `@@@@ file` break
  # the prefix the splitter keys on and would otherwise be discarded with their body.
  decl=$(sed -n 's|^@@@ file ||p' "$case_file")
  if [ -z "$decl" ]; then
    fail=$((fail + 1)); echo "FAIL  $name: declares no '@@@ file' directive, so nothing reached disk."
    continue
  fi
  missing=""
  # Declared paths may carry a space, so they are read line by line rather than word-split.
  printf '%s\n' "$decl" | while IFS= read -r d; do
    [ -n "$d" ] || continue
    [ -f "$WORK/$d" ] || printf '%s\n' "$d"
  done > "$WORK/.missing"
  if [ -s "$WORK/.missing" ]; then
    fail=$((fail + 1)); echo "FAIL  $name: declared file(s) never written: $(tr '\n' ' ' < "$WORK/.missing")"
    continue
  fi
  if [ "$(grep -c '^@@@' "$case_file")" != "$(grep -cE '^@@@ (file |expect exit=|match |absent )' "$case_file")" ]; then
    fail=$((fail + 1)); echo "FAIL  $name: an '@@@' line is not one of file/expect exit=/match/absent."
    continue
  fi

  got=$(cd "$WORK" && sh scripts/spec-lint.sh 2>&1) && rc=0 || rc=$?
  ok=1; why=""
  [ "$rc" = "${want_exit:-0}" ] || { ok=0; why="exit $rc, wanted ${want_exit:-0}"; }
  if [ "$ok" = 1 ]; then
    sed -n 's/^@@@ match //p' "$case_file" | while IFS= read -r m; do
      [ -n "$m" ] || continue
      case "$got" in *"$m"*) ;; *) echo "MISSING|$m" ;; esac
    done > "$WORK/.miss"
    if [ -s "$WORK/.miss" ]; then ok=0; why="output lacked: $(sed 's/^MISSING|//' "$WORK/.miss" | head -1)"; fi
  fi
  if [ "$ok" = 1 ]; then
    sed -n 's/^@@@ absent //p' "$case_file" | while IFS= read -r m; do
      [ -n "$m" ] || continue
      case "$got" in *"$m"*) echo "PRESENT|$m" ;; esac
    done > "$WORK/.present"
    if [ -s "$WORK/.present" ]; then ok=0; why="output carried: $(sed 's/^PRESENT|//' "$WORK/.present" | head -1)"; fi
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

# The live template, as two cases of its own. An unfilled copy of `docs/templates/spec-template.md`
# must pass its structure — every required section present, no banned header — and WARN on its
# placeholders. The second case binds the placeholder regex to EACH string the template actually
# uses: the copy is scrubbed of all but one placeholder at a time, and that one alone must still
# warn. A single run over the whole template could not say that — any one surviving placeholder
# keeps the WARN firing, so renaming `[Feature Name]` in the template stayed green until this was
# split. Run under the same filter as the cases, so `sh scripts/spec-lint-test.sh template`
# reaches both.
if [ -z "${SPEC_LINT_TEST_CASES:-}" ] && case template-unfilled in *"$FILTER"*) true ;; *) false ;; esac; then
  rm -rf "$WORK"; mkdir -p "$WORK/scripts" "$WORK/docs/specs"
  cp "$ROOT/scripts/spec-lint.sh" "$WORK/scripts/spec-lint.sh"
  cp "$ROOT/docs/templates/spec-template.md" "$WORK/docs/specs/SPEC-000-template.md"
  got=$(cd "$WORK" && sh scripts/spec-lint.sh 2>&1) && rc=0 || rc=$?
  case "$rc:$got" in
    0:*"WARN  docs/specs/SPEC-000-template.md: unfilled template placeholder(s)"*"ok    docs/specs/SPEC-000-template.md"*)
      pass=$((pass + 1)); echo "ok    template-unfilled" ;;
    *)
      fail=$((fail + 1)); echo "FAIL  template-unfilled: exit $rc; an unfilled copy of the template must warn on its placeholders and pass its structure"
      printf '%s\n' "$got" | sed 's/^/        /' | head -8 ;;
  esac
fi
if [ -z "${SPEC_LINT_TEST_CASES:-}" ] && case template-placeholders in *"$FILTER"*) true ;; *) false ;; esac; then
  # Each placeholder the linter's regex names, as a sed pattern that removes it. The list is
  # kept here rather than read from the linter so that dropping an alternative from the regex
  # is a red case, not a quieter corpus.
  unbound=""
  for keep in 'Feature Name' 'Requirement Name' 'SPEC-XXX' 'YYYY-MM-DD'; do
    rm -rf "$WORK"; mkdir -p "$WORK/scripts" "$WORK/docs/specs"
    cp "$ROOT/scripts/spec-lint.sh" "$WORK/scripts/spec-lint.sh"
    # Scrub every placeholder except the one under test. Bracketed names are matched with the
    # brackets escaped; the others are plain strings.
    sed -e "$([ "$keep" = 'Feature Name' ] || printf 's/\\[Feature Name\\]/feature/g')" \
        -e "$([ "$keep" = 'Requirement Name' ] || printf 's/\\[Requirement Name\\]/requirement/g')" \
        -e "$([ "$keep" = 'SPEC-XXX' ] || printf 's/SPEC-XXX/SPEC-001/g')" \
        -e "$([ "$keep" = 'YYYY-MM-DD' ] || printf 's/YYYY-MM-DD/2026-01-01/g')" \
        "$ROOT/docs/templates/spec-template.md" > "$WORK/docs/specs/SPEC-000-template.md"
    got=$(cd "$WORK" && sh scripts/spec-lint.sh 2>&1) && rc=0 || rc=$?
    case "$rc:$got" in
      0:*"unfilled template placeholder(s)"*) ;;
      *) unbound="$unbound '$keep'" ;;
    esac
  done
  if [ -z "$unbound" ]; then
    pass=$((pass + 1)); echo "ok    template-placeholders"
  else
    fail=$((fail + 1)); echo "FAIL  template-placeholders: left alone in the template, these placeholder(s) did not warn:$unbound"
  fi
fi

# A spec directory that does not exist must FAIL, not report "nothing to check": the cases above
# always build `docs/specs`, so this one drives the linter at a path that is not there. Under the
# same filter as the cases.
if [ -z "${SPEC_LINT_TEST_CASES:-}" ] && case missing-dir in *"$FILTER"*) true ;; *) false ;; esac; then
  rm -rf "$WORK"; mkdir -p "$WORK/scripts"
  cp "$ROOT/scripts/spec-lint.sh" "$WORK/scripts/spec-lint.sh"
  got=$(cd "$WORK" && sh scripts/spec-lint.sh docs/nowhere 2>&1) && rc=0 || rc=$?
  case "$rc:$got" in
    1:*"docs/nowhere is not a directory"*) pass=$((pass + 1)); echo "ok    missing-dir" ;;
    *) fail=$((fail + 1)); echo "FAIL  missing-dir: exit $rc; a spec directory that does not exist must fail, not pass as empty"
       printf '%s\n' "$got" | sed 's/^/        /' | head -4 ;;
  esac
fi

echo "----"
echo "spec-lint-test: $pass passed, $fail failed."
[ "$fail" -eq 0 ] || exit 1

# A FLOOR, NOT AN EXIT CODE. Every mechanical way to lose the corpus — a renamed directory,
# a glob that stops matching — ends with zero cases run and `0 passed, 0 failed`, which
# exits 0 and prints a success line. Deliberately BELOW the measurement — 26 at the commit
# that introduced it: 23 case files plus the two template cases and the missing-directory case
# — with headroom of about a quarter, so adding cases needs no edit here and pruning a few does
# not either; losing the corpus, or most of it, does, and that is the point. Not applied to the
# self-test invocation, which runs a handful of planted cases.
# A filter typo is the same shape at a smaller scale and gets its own line: a filtered run
# that matched nothing has proved nothing.
if [ -n "$FILTER" ] && [ "$pass" -eq 0 ]; then
  echo "spec-lint-test: the filter '$FILTER' matched no case. Nothing ran, so nothing passed."
  exit 1
fi
CASES_MIN=19
if [ -z "${SPEC_LINT_TEST_CASES:-}" ] && [ -z "$FILTER" ] && [ "$pass" -lt "$CASES_MIN" ]; then
  echo "spec-lint-test: only $pass cases ran, against a floor of $CASES_MIN. The corpus has"
  echo "shrunk or gone missing — a run over nothing exits 0 and looks exactly like a healthy"
  echo "one. If cases were removed on purpose, lower CASES_MIN in the same change."
  exit 1
fi

# ── self-test: the three fixture guards above have to fire ─────────────────────
#
# A case that trips a guard is by construction a FAILING case, so none can live in
# tests/spec-lint without leaving the corpus red. They get a corpus of their own, run
# here against a temp directory and asserting the FAIL TEXT rather than the exit code.
# Removing any one of the three guards turns its planted case green, which is the claim.
if [ -z "${SPEC_LINT_TEST_CASES:-}" ] && [ -z "$FILTER" ]; then
  SELF="$WORK.self"
  rm -rf "$SELF"; mkdir -p "$SELF"
  skeleton='@@@ file docs/specs/SPEC-001-x.md
# Spec

**Status:** Draft

## Overview
## Scope
## Functional Requirements
## Implementation Phases'

  # 1. No `@@@ file` at all: nothing is written, so the linter examines an empty tree.
  printf '@@@ expect exit=0\n' > "$SELF/no-file-ok.case"
  # 2. A recognised directive naming a file the splitter never writes.
  printf '@@@ expect exit=0\n@@@ file docs/never.md\n%s\n' "$skeleton" > "$SELF/unwritten-ok.case"
  # 3. Three typos that each break the `@@@ ` prefix the splitter keys on, named one at a
  #    time rather than derived from the typo, so two cannot collide on one filename.
  set -- 'double-space:@@@  file' 'no-space:@@@file' 'four-at:@@@@ file'
  for pair in "$@"; do
    n=${pair%%:*}; typo=${pair#*:}
    printf '@@@ expect exit=0\n%s docs/typo.md\ncontent\n%s\n' "$typo" "$skeleton" > "$SELF/typo-$n-ok.case"
  done

  planted=$(ls "$SELF" | wc -l | tr -d ' ')
  self_out=$(SPEC_LINT_TEST_CASES="$SELF" sh "$0" 2>&1) && self_rc=0 || self_rc=$?
  rm -rf "$SELF"
  self_fail=0
  for want in \
    "no-file-ok: declares no '@@@ file' directive" \
    "unwritten-ok: declared file(s) never written" \
    "an '@@@' line is not one of file/expect exit=/match/absent"
  do
    case "$self_out" in
      *"$want"*) ;;
      *) echo "FAIL  self-test: a guard did not fire — expected \"$want\"."; self_fail=1 ;;
    esac
  done
  case "$self_out" in *"ok    "*) echo "FAIL  self-test: a deliberately vacuous case reported ok."; self_fail=1 ;; esac
  [ "$self_rc" -ne 0 ] || { echo "FAIL  self-test: the harness exited 0 on a directory of vacuous cases."; self_fail=1; }
  if [ "$self_fail" -ne 0 ]; then
    echo "----"
    echo "spec-lint-test: the fixture guards are not firing. A case whose files never reach"
    echo "disk would pass silently, which is how a harness goes green over nothing."
    exit 1
  fi
  echo "spec-lint-test: fixture guards verified — 3 guards, $planted vacuous cases refused."
fi
