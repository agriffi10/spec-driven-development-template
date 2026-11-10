#!/bin/sh
# signal-test.sh — every script here that traps a signal must EXIT on it, with the code it declares.
#
# Why this exists. In POSIX sh a trap handler that does not call `exit` lets the script RESUME
# after it. A script whose INT/TERM handler only deleted its scratch kept running with that scratch
# gone: docs-lint printed `docs-lint: ok` and exit 0 after a signal, and check-mirror ended in
# "No such file" errors. And a signal with no handler at all kills dash WITHOUT running the EXIT
# trap, so an untrapped PIPE (`gen-index.sh | head`) or HUP leaked the scratch the EXIT trap was
# there to remove. The same defect sat in seven scripts at once, each copied from the last, so
# this checks them all rather than each harness planting its own.
#
# The rule each script must follow, and the only shape this accepts:
#
#   trap '<cleanup>' EXIT
#   trap 'exit N' HUP INT PIPE TERM          N from 1 to 255, set once, at column 0
#
# and nothing after that line, or anywhere off column 0, may trap HUP, INT, PIPE or TERM again. A
# nested trap that names none of them (`trap - EXIT` in a function that execs) is fine.
#
# How it checks. Statically first: the signal line exists once, and no later or nested trap names
# one of the four signals. Then, for each script and each signal, a copy of the script gets a PLANT
# right after its signal line: print a marker, signal itself, and `exit 0` if the shell came back.
# The copy sits beside the original, so the script's own prelude (which resolves paths from `$0`)
# runs as it would, with an EMPTY TMPDIR. It must:
#   - reach the plant (a prelude that exits first, with the same code, would otherwise pass);
#   - exit with the declared N — 0 means it resumed after the handler, and 128+N means the signal
#     killed it, which dash does without running the EXIT trap; and
#   - leave TMPDIR empty. That covers only scratch made BEFORE the signal line (check-mirror's
#     `mktemp`): the plant fires right after it, so most scripts have made nothing yet. Whether a
#     cleanup covers every scratch name a script makes later is that script's own corpus to prove,
#     as `docs-lint-test.sh` does with its empty-TMPDIR guard.
# A signal this shell ignored on entry cannot be trapped at all — INT, when this runs as a
# background job — so it is skipped, by name, rather than failed. A trap set through `eval` or a
# sourced file is not seen. A script with no trap at all is not checked: this holds scripts that
# trap to doing it right, not every script to trapping.
#
# The self-test (`--self-test`) runs this against fixture scripts, one per way of breaking the
# rule, asserting the REASON each is refused, and against correct ones that must pass silently.
#
# Usage: sh scripts/signal-test.sh                 every tracked file under scripts/ with a trap
#        sh scripts/signal-test.sh <file>...       just these
#        sh scripts/signal-test.sh --self-test     the fixtures
# Maintenance for THIS template repo (root-only, like check-mirror.sh). POSIX sh; needs git.
# FAIL (exit 1) a script broke the rule. ERROR (exit 2) nothing to check, or a usage error.

set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SELF="$ROOT/scripts/signal-test.sh"
WORK="${TMPDIR:-/tmp}/signal-test.$$"
copy=""
trap 'rm -rf "$WORK"; [ -z "$copy" ] || rm -f "$copy"' EXIT
trap 'exit 2' HUP INT PIPE TERM
SIGNALS="HUP INT PIPE TERM"
# A `trap` command off column 0: indented, or after `;`, `&`, `|`, `(`, `{`, `then`, `do` or `else`.
NESTED='^[[:space:]]+trap[[:space:]]|[;&|({][[:space:]]*trap[[:space:]]|(then|do|else)[[:space:]]+trap[[:space:]]'
# One of the four signals named as a word, with or without SIG.
NAMES_SIGNAL='(^|[^A-Za-z0-9_])(SIG)?(HUP|INT|PIPE|TERM)([^A-Za-z0-9_]|$)'

# ignored_on_entry <SIG> — 0 when this shell cannot trap SIG.
ignored_on_entry() {
  sh -c "trap 'exit 3' $1; kill -$1 \$\$; exit 0" && probe=0 || probe=$?
  [ "$probe" -ne 3 ]
}

# --- the fixtures ---------------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  FX="$WORK/fixtures"
  mkdir -p "$FX"
  # Each fixture is a prelude, its traps, and a body the plant cuts off. Each body line carries a
  # `  >` prefix here, stripped on the way out, and a nested trap is spelt @TRAP@: as written, the
  # fixtures' traps would otherwise be read as this script's own.
  fixture() { sed -e 's/^  >//' -e 's/@TRAP@/trap/' > "$FX/$1"; }
  fixture good.sh <<'EOF'
  >W="${TMPDIR:-/tmp}/fx.$$"; mkdir "$W"
  >trap 'rm -rf "$W"' EXIT
  >trap 'exit 2' HUP INT PIPE TERM
  >echo body
EOF
  # Correct, plus a nested trap that names no signal and a late column-0 one that disarms EXIT
  # before the end. Neither touches signal handling, so both must pass — and the late one must not
  # move the plant past the body.
  fixture good-disarms-exit.sh <<'EOF'
  >W="${TMPDIR:-/tmp}/fx.$$"; mkdir "$W"
  >trap 'rm -rf "$W"' EXIT
  >trap 'exit 2' HUP INT PIPE TERM
  >handoff() {
  >  @TRAP@ - EXIT
  >  rm -rf "$W"
  >}
  >echo "BODY RAN" >&2
  >exit 9
  >trap - EXIT
EOF
  # The original defect: the handler cleans up and the shell resumes.
  fixture cleans-only.sh <<'EOF'
  >W="${TMPDIR:-/tmp}/fx.$$"; mkdir "$W"
  >trap 'rm -rf "$W"' EXIT INT TERM
  >echo body
EOF
  # The signal line, then a later one that takes TERM back.
  fixture late.sh <<'EOF'
  >W="${TMPDIR:-/tmp}/fx.$$"; mkdir "$W"
  >trap 'rm -rf "$W"' EXIT
  >trap 'exit 2' HUP INT PIPE TERM
  >trap 'rm -rf "$W"' TERM
  >echo body
EOF
  # The signal line, then a nested trap that takes TERM back.
  fixture nested.sh <<'EOF'
  >W="${TMPDIR:-/tmp}/fx.$$"; mkdir "$W"
  >trap 'rm -rf "$W"' EXIT
  >trap 'exit 2' HUP INT PIPE TERM
  >if true; then @TRAP@ 'rm -rf "$W"' TERM; fi
  >echo body
EOF
  # The right shape, but the EXIT cleanup exits with its own code and overrides the declared one.
  fixture exit-overrides.sh <<'EOF'
  >W="${TMPDIR:-/tmp}/fx.$$"; mkdir "$W"
  >trap 'rm -rf "$W"; exit 5' EXIT
  >trap 'exit 2' HUP INT PIPE TERM
  >echo body
EOF
  # A prelude that exits with the declared code before the traps: the plant is never reached.
  fixture early-exit.sh <<'EOF'
  >[ -d /signal-test-no-such-dir ] || exit 2
  >trap 'exit 0' EXIT
  >trap 'exit 2' HUP INT PIPE TERM
  >echo body
EOF
  # The right traps around a scratch name, made before them, that the cleanup does not cover.
  fixture leaks.sh <<'EOF'
  >W="${TMPDIR:-/tmp}/fx.$$"; mkdir "$W" "$W.side"
  >trap 'rm -rf "$W"' EXIT
  >trap 'exit 2' HUP INT PIPE TERM
  >echo body
EOF
  st_fail=0
  # expect <fixture> <exit> <text> [ignored] — <text> empty means: must print no FAIL line at all.
  # `ignored` runs the check with all four signals ignored on entry, so every one is skipped. An
  # argument, not `IGNORE_ALL=1 expect`: bash as sh keeps an assignment made before a function call.
  expect() {
    if [ "${4:-}" = ignored ]; then
      out=$(sh -c "trap '' $SIGNALS; exec sh \"\$0\" \"\$1\"" "$SELF" "$FX/$1" 2>&1) && rc=0 || rc=$?
    else
      out=$(sh "$SELF" "$FX/$1" 2>&1) && rc=0 || rc=$?
    fi
    ok=1
    [ "$rc" = "$2" ] || ok=0
    if [ -n "$3" ]; then
      case "$out" in *"$3"*) ;; *) ok=0 ;; esac
    else
      case "$out" in *FAIL*|*"BODY RAN"*) ok=0 ;; esac
    fi
    if [ "$ok" = 1 ]; then echo "ok    self-test: $1"
    else
      echo "FAIL  self-test: $1 — exit $rc, wanted $2${3:+ and \"$3\"}"
      printf '%s\n' "$out" | sed 's/^/        /' | head -6
      st_fail=1
    fi
  }
  expect good.sh              0 ""
  expect good-disarms-exit.sh 0 ""
  expect cleans-only.sh       1 "has no \`trap 'exit N' HUP INT PIPE TERM\` line"
  expect late.sh              1 ":4: a trap naming a signal after the signal line"
  expect nested.sh            1 ":4: a nested trap naming a signal"
  expect leaks.sh             1 "left scratch behind in TMPDIR: fx."
  expect early-exit.sh        1 "never reached the plant"
  expect good.sh              1 "every signal was skipped as ignored on entry" ignored
  if ignored_on_entry TERM; then
    echo "signal-test: SKIPPED the exit-overrides fixture — this shell ignores TERM."
  else
    expect exit-overrides.sh  1 "TERM: exit 5, wanted 2"
  fi
  [ "$st_fail" -eq 0 ] || { echo "----"; echo "signal-test: the self-test failed — a check above is not firing, or fires where it must not."; exit 1; }
  echo "signal-test: self-test passed — every fixture refused for its own reason, the good ones silent."
  exit 0
fi

# --- the scripts ----------------------------------------------------------------------------------
case "${1:-}" in -*) echo "usage: sh scripts/signal-test.sh [--self-test | <file>...]" >&2; exit 2 ;; esac
mkdir -p "$WORK"
LIST="$WORK/list"
if [ $# -gt 0 ]; then
  printf '%s\n' "$@" > "$LIST"
else
  git -C "$ROOT" -c core.quotePath=false ls-files -- scripts/ | while IFS= read -r f; do
    grep -Eq "^trap[[:space:]]|$NESTED" "$ROOT/$f" && printf '%s\n' "$ROOT/$f"
  done > "$LIST" || true
fi
[ -s "$LIST" ] || { echo "error: signal-test: no script with a trap to check — refusing a vacuous pass" >&2; exit 2; }

fail=0; n=0; skipped_any=""
while IFS= read -r f; do
  [ -f "$f" ] || { echo "FAIL  $f — no such file"; fail=1; continue; }
  n=$((n + 1))
  # The signal line: exactly one, of the one accepted shape. A handler that cleans up instead of
  # exiting, or a signal left out of the list, is the defect this exists for.
  decl=$(grep -n "^trap 'exit [1-9][0-9]*' HUP INT PIPE TERM\$" "$f" || true)
  case "$decl" in
    *"
"*|"") echo "FAIL  $f has no \`trap 'exit N' HUP INT PIPE TERM\` line, or more than one — a handler that does not exit lets the script resume, and an untrapped signal kills dash without its EXIT trap."
       fail=1; continue ;;
  esac
  line=${decl%%:*}
  want=$(printf '%s\n' "$decl" | sed "s/^[0-9]*:trap 'exit \\([0-9]*\\)'.*/\\1/")
  [ "$want" -le 255 ] || { echo "FAIL  $f:$line: exit $want is out of range"; fail=1; continue; }
  # Nothing may take a signal back after that line, or from anywhere the plant cannot follow.
  # Comment lines are skipped; a match in prose on a code line is reported with its line, to reword.
  bad=$(awk -v decl="$line" -v nested="$NESTED" -v names="$NAMES_SIGNAL" '
    /^[[:space:]]*#/ { next }
    $0 ~ names {
      if ($0 ~ nested) { print NR ": a nested trap naming a signal"; exit }
      if ($0 ~ /^trap[[:space:]]/ && NR > decl) { print NR ": a trap naming a signal after the signal line"; exit }
    }' "$f")
  if [ -n "$bad" ]; then
    echo "FAIL  $f:$bad — set signal traps once, at column 0, with \`trap 'exit N' HUP INT PIPE TERM\` last (a match in prose: reword it)."
    fail=1; continue
  fi
  file_ok=1; skipped=""
  for sig in $SIGNALS; do
    if ignored_on_entry "$sig"; then
      skipped="$skipped $sig"
      case " $skipped_any " in *" $sig "*) ;; *) skipped_any="$skipped_any $sig" ;; esac
      continue
    fi
    copy="$(dirname "$f")/.signal-test.$$.$(basename "$f")"
    awk -v line="$line" -v sig="$sig" '
      { print }
      NR == line {
        print "echo \"signal-test: planted " sig "\" >&2"
        print "kill -" sig " $$"
        print "exit 0"
      }' "$f" > "$copy"
    rm -rf "$WORK/tmp"; mkdir -p "$WORK/tmp"
    out=$(cd "$ROOT" && TMPDIR="$WORK/tmp" sh "$copy" < /dev/null 2>&1) && rc=0 || rc=$?
    rm -f "$copy"; copy=""
    why=""
    case "$out" in
      *"signal-test: planted $sig"*)
        if [ "$rc" != "$want" ]; then
          why="exit $rc, wanted $want"
          [ "$rc" -ne 0 ] || why="$why — it resumed after the handler"
          [ "$rc" -le 128 ] || why="$why — the signal killed it, and dash runs no EXIT trap then"
        fi ;;
      *) why="never reached the plant — exit $rc: $(printf '%s\n' "$out" | head -1)" ;;
    esac
    if [ -z "$why" ] && [ -n "$(ls -A "$WORK/tmp")" ]; then
      why="left scratch behind in TMPDIR: $(ls -A "$WORK/tmp" | head -3 | tr '\n' ' ')"
    fi
    if [ -n "$why" ]; then
      echo "FAIL  $f $sig: $why"
      file_ok=0
    fi
  done
  # Every signal skipped is nothing checked, which must not read as a pass.
  if [ "$skipped" = " $SIGNALS" ]; then
    echo "FAIL  $f: every signal was skipped as ignored on entry — nothing was checked"
    file_ok=0
  fi
  if [ "$file_ok" = 1 ]; then
    echo "ok    ${f#"$ROOT"/} exits $want on every trapped signal${skipped:+ (SKIPPED, ignored on entry:$skipped)}"
  else
    fail=1
  fi
done < "$LIST"

if [ "$fail" -ne 0 ]; then
  echo "----"
  echo "signal-test: a script does not exit cleanly on a signal. Use exactly:"
  echo "    trap '<cleanup>' EXIT"
  echo "    trap 'exit N' HUP INT PIPE TERM"
  exit 1
fi
echo "signal-test: $n script(s), each exits with its declared code on every signal checked${skipped_any:+ — SKIPPED, ignored on entry:$skipped_any}."
