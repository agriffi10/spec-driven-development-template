#!/bin/sh
# install-test.sh — the fixture corpus for install.sh: its refusals, its enforcement summary, and
# what it does to a hook that is already there.
#
# Why this exists. The summary is the only thing standing between a mismatched
# `enforce-branches` and an install that looks healthy and refuses nothing, and its first version
# shipped with two escapes of exactly that kind: an EMPTY pattern counted as matching every branch
# (an empty ERE matches every line) and so reported total coverage for the one setting that has
# none, and an INVALID ERE left the count empty and compared it as an integer. Both were found by
# review rather than by running it. A summary nobody tests is a summary that reports what it likes.
# The hook-handling cases exist because the dangerous direction is silent: a wrapper repointed at
# a fresh empty queue, or a zero-byte hook, both install cleanly and say so.
#
# Each case asserts the specific TEXT, not only the exit code: the pattern states differ mostly in
# what they say, and several of them exit 0.
#
# SAFETY: every case builds its own throwaway repo under $TMPDIR and installs into it.
# `PR_QUEUE_DIR` relocates the queue but NOT the hook, so running install.sh anywhere near a real
# checkout rewrites that checkout's .git/hooks/pre-push — which is why nothing here runs in the
# repo this script lives in.
#
# Usage: sh scripts/pr-queue/install-test.sh
# POSIX sh, no dependencies beyond git.

set -eu
SRC="$(cd "$(dirname "$0")" && pwd)"
WORK="${TMPDIR:-/tmp}/pr-queue-install-test.$$"
trap 'rm -rf "$WORK"' EXIT INT TERM
pass=0; fail=0

sh -n "$SRC/install.sh" || { echo "FAIL  install.sh does not parse"; exit 1; }

# A repo with a main branch, one commit, and whatever extra branches the case wants.
scratch() {
  d="$WORK/$1"; shift
  mkdir -p "$d" && git -C "$d" init -q -b main
  git -C "$d" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  mkdir -p "$d/scripts/pr-queue"
  cp "$SRC/install.sh" "$SRC/queue.sh" "$SRC/pre-push" "$SRC/PROTOCOL.md" "$d/scripts/pr-queue/"
  for b in "$@"; do git -C "$d" branch -q "$b" main; done
  printf '%s' "$d"
}

# run <name> <repo> <queue-dir> <expect-exit> <@none|@empty|pattern> -- <substring>...
#
# The argument mode is a TOKEN, not an optional string: `${pat:+"$pat"}` drops an empty argument,
# so "install with no pattern" and "install with an explicit empty pattern" were the same call —
# and the empty case silently tested the default until this corpus said so on its first run.
# stdout and stderr are captured together: the refusals go to stderr, the summary to stdout.
run() {
  name="$1"; d="$2"; qd="$3"; want="$4"; mode="$5"; shift 5
  shift   # the --
  case "$mode" in
    @none)  out=$(cd "$d" && PR_QUEUE_DIR="$qd" sh scripts/pr-queue/install.sh 2>&1) && rc=0 || rc=$? ;;
    @empty) out=$(cd "$d" && PR_QUEUE_DIR="$qd" sh scripts/pr-queue/install.sh '' 2>&1) && rc=0 || rc=$? ;;
    *)      out=$(cd "$d" && PR_QUEUE_DIR="$qd" sh scripts/pr-queue/install.sh "$mode" 2>&1) && rc=0 || rc=$? ;;
  esac
  ok=1; why=""
  [ "$rc" = "$want" ] || { ok=0; why="exit $rc, wanted $want"; }
  for want_text in "$@"; do
    case "$out" in *"$want_text"*) ;; *) ok=0; why="${why:+$why; }output lacked: $want_text" ;; esac
  done
  if [ "$ok" = 1 ]; then pass=$((pass + 1)); echo "ok    $name"
  else fail=$((fail + 1)); echo "FAIL  $name: $why"; printf '%s\n' "$out" | sed 's/^/        /'; fi
}

# check <name> <condition-exit> <detail> — a plain assertion outside `run`.
check() {
  if [ "$2" -eq 0 ]; then pass=$((pass + 1)); echo "ok    $1"
  else fail=$((fail + 1)); echo "FAIL  $1: $3"; fi
}

# 1 — the default matches every branch shape, and says so with a count.
d=$(scratch default spec/056-x spec-056-y docs/thing ci/pin test/x fix/y feat/a chore/b perf/c)
run default "$d" "$WORK/q-default" 0 @none -- "enforcing: .  (9 of 9 local branches besides main)" "q-default/pre-push"
# The POSITIVE hook case. Case 6 asserts a foreign hook is not overwritten; nothing asserted that
# ours is written, so deleting the wrapper heredoc left an earlier corpus green while the summary
# went on printing the `hook:` line the script header tells a reader to trust.
#
# Matched on the queue directory's TAIL, not its full path: install.sh absolutises $Q with
# `cd && pwd`, which on macOS resolves $TMPDIR's /var to /private/var, so a full-path comparison
# fails for a reason that has nothing to do with the hook.
if grep -q PR_QUEUE_WRAPPER "$d/.git/hooks/pre-push" 2>/dev/null && [ -x "$d/.git/hooks/pre-push" ] &&
   grep -q "^Q='.*q-default'$" "$d/.git/hooks/pre-push"; then
  check default-hook-written 0 ""
else
  check default-hook-written 1 "no executable wrapper with a Q= line naming the queue"
fi
check default-no-staging "$([ -z "$(ls -d "$WORK"/q-default/.staged.* 2>/dev/null)" ]; echo $?)" "a staging directory was left behind"

# 2 — a pattern that matches nothing, with branches present to match.
d=$(scratch nomatch spec/056-x docs/thing)
run nomatch "$d" "$WORK/q-nomatch" 0 '^nope-' -- "(0 of 2 local branches besides main)" "matches none of them"

# 3 — BLANK argument: refused before anything is copied, so the queue does not exist afterwards.
d=$(scratch blank spec/056-x)
run blank "$d" "$WORK/q-blank" 1 @empty -- "empty or blank pattern" "Nothing was changed"
check blank-nothing-copied "$([ ! -e "$WORK/q-blank/queue.sh" ] && [ ! -e "$d/.git/hooks/pre-push" ]; echo $?)" "queue.sh or the hook was written despite the refusal"
run blank-spaces "$d" "$WORK/q-blank" 1 '  ' -- "empty or blank pattern"

# 4 — INVALID ERE argument: refused before anything is copied.
d=$(scratch invalid spec/056-x)
run invalid "$d" "$WORK/q-invalid" 1 '^spec[' -- "not an ERE grep can compile" "Nothing was changed"
check invalid-nothing-copied "$([ ! -e "$WORK/q-invalid/queue.sh" ]; echo $?)" "queue.sh was written despite the refusal"

# 5 — a fresh clone has no branches of its own; silence, not a warning.
d=$(scratch fresh)
run fresh "$d" "$WORK/q-fresh" 0 @none -- "(0 of 0 local branches besides main)"
# The SPECIFIC text, not the bare word: install.sh also warns when `gh` is absent, and matching
# on WARNING failed this case for that instead — a false accusation about the branch-count logic.
case "$out" in *"matches none of them"*) check fresh-no-warning 1 "warned about a repo with no branches to match" ;;
                                      *) check fresh-no-warning 0 "" ;; esac

# 6 — a foreign pre-push is left alone, and the summary must SAY it was left alone rather than
#     printing the install line: that line is what the header tells a reader to check.
d=$(scratch blocked spec/056-x)
printf '#!/bin/sh\nexit 0\n' > "$d/.git/hooks/pre-push"; chmod +x "$d/.git/hooks/pre-push"
run blocked "$d" "$WORK/q-blocked" 3 @none -- "LEFT ALONE" "nothing is enforced" "THE HOOK WAS NOT INSTALLED"
check blocked-hook-intact "$(! grep -q PR_QUEUE_WRAPPER "$d/.git/hooks/pre-push"; echo $?)" "the foreign hook was overwritten"

# 7 — KEPT: a re-install with no argument keeps the pattern and says so; a re-install WITH one
#     replaces it. The previous generation is kept beside the queue.
d=$(scratch kept spec/056-x)
run kept-first "$d" "$WORK/q-kept" 0 '^nope-' -- "(0 of 1 local branches besides main)"
run kept "$d" "$WORK/q-kept" 0 @none -- "KEPT from the previous install" "enforcing: ^nope-"
check kept-file "$([ "$(cat "$WORK/q-kept/enforce-branches")" = '^nope-' ]; echo $?)" "the pattern was overwritten on a bare re-install"
check kept-previous "$([ -f "$WORK/q-kept/.previous/queue.sh" ] && [ -f "$WORK/q-kept/.previous/enforce-branches" ]; echo $?)" ".previous/ does not hold the replaced generation"
run kept-replaced "$d" "$WORK/q-kept" 0 '.' -- "enforcing: .  (1 of 1 local branches besides main)"
case "$out" in *"KEPT"*) check kept-replaced-not-kept 1 "said KEPT after an explicit pattern" ;; *) check kept-replaced-not-kept 0 "" ;; esac

# 8 — EMPTY file, hand-edited: the installer can no longer write this state, but it can keep it,
#     and the summary must name the state rather than print a count.
d=$(scratch hand-empty spec/056-x)
run hand-empty-first "$d" "$WORK/q-hand-empty" 0 @none -- "enforcing: ."
printf '\n' > "$WORK/q-hand-empty/enforce-branches"
run hand-empty "$d" "$WORK/q-hand-empty" 0 @none -- "enforcing: (empty)" "NOTHING is enforced" "set a pattern"

# 9 — INVALID file, hand-edited: kept and named here; the hook's side of it (fail closed) is the
#     `bad-pattern` case in scripts/pr-queue-test.sh.
d=$(scratch hand-invalid spec/056-x)
run hand-invalid-first "$d" "$WORK/q-hand-invalid" 0 @none -- "enforcing: ."
printf 'spec-[\n' > "$WORK/q-hand-invalid/enforce-branches"
run hand-invalid "$d" "$WORK/q-hand-invalid" 0 @none -- "NOT A VALID ERE" "fix the expression"

# 10 — a held lock refuses the upgrade before anything is copied, and names the holder.
d=$(scratch held spec/056-x)
run held-first "$d" "$WORK/q-held" 0 @none -- "enforcing: ."
mkdir -p "$WORK/q-held/lock"; printf 'spec SPEC-9\nbranch spec/9-x\nsince now\n' > "$WORK/q-held/lock/holder"
printf '# stale\n' > "$d/scripts/pr-queue/queue.sh"
run held "$d" "$WORK/q-held" 1 @none -- "has a lock held" "SPEC-9" "Wait for the holder to release"
check held-nothing-copied "$(! grep -q '^# stale' "$WORK/q-held/queue.sh"; echo $?)" "queue.sh was replaced under a held lock"

# 11 — a wrapper that names a DIFFERENT queue is left alone, and the refusal names that queue.
d=$(scratch other spec/056-x)
run other-first "$d" "$WORK/q-other-A" 0 @none -- "enforcing: ."
run other "$d" "$WORK/q-other-B" 3 @none -- "DIFFERENT queue" "q-other-A" "PR_QUEUE_DIR="
check other-hook-intact "$(grep -q "q-other-A'$" "$d/.git/hooks/pre-push"; echo $?)" "the wrapper was repointed at the second queue"
check other-queue-built "$([ -x "$WORK/q-other-B/pre-push" ]; echo $?)" "the second queue itself was not installed"

# 11b — a wrapper from the generation BEFORE the Q= line names its queue only on its exec line.
#       It must be read from there: a different queue is refused, the same queue is upgraded.
d=$(scratch oldwrap spec/056-x)
mkdir -p "$WORK/q-oldwrap-A"; qa="$(cd "$WORK/q-oldwrap-A" && pwd)"
printf '#!/bin/sh\n# PR_QUEUE_WRAPPER — written by scripts/pr-queue/install.sh.\n[ -x "%s/pre-push" ] && exec "%s/pre-push" "$@"\nexit 0\n' "$qa" "$qa" > "$d/.git/hooks/pre-push"
chmod +x "$d/.git/hooks/pre-push"
run oldwrap-other "$d" "$WORK/q-oldwrap-B" 3 @none -- "DIFFERENT queue" "q-oldwrap-A"
check oldwrap-other-intact "$(! grep -q "^Q=" "$d/.git/hooks/pre-push"; echo $?)" "the old-style wrapper was rewritten despite naming another queue"
run oldwrap-same "$d" "$WORK/q-oldwrap-A" 0 @none -- "q-oldwrap-A/pre-push"
check oldwrap-same-upgraded "$(grep -q "^Q='$qa'$" "$d/.git/hooks/pre-push"; echo $?)" "the old-style wrapper for this queue was not upgraded to carry Q="

# 12 — the trunk is asked of the remote when origin/HEAD is absent: `init` + `remote add` never
#      creates it, and a guess of `main` against a `master` remote would make the hook refuse
#      every push in that repo.
d="$WORK/symref"; mkdir -p "$d"
git init -q --bare -b master "$d/origin.git"
git init -q -b master "$d/repo"; git -C "$d/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$d/repo" remote add origin "$d/origin.git"; git -C "$d/repo" push -q origin master
mkdir -p "$d/repo/scripts/pr-queue"; cp "$SRC/install.sh" "$SRC/queue.sh" "$SRC/pre-push" "$SRC/PROTOCOL.md" "$d/repo/scripts/pr-queue/"
run symref "$d/repo" "$WORK/q-symref" 0 @none -- "main:      master"
check symref-file "$([ "$(cat "$WORK/q-symref/main-branch")" = master ]; echo $?)" "main-branch is not master"

# 12b — no origin at all: the trunk is asked of the checkout's only remote.
d="$WORK/solerem"; mkdir -p "$d"
git init -q --bare -b master "$d/fork.git"
git init -q -b master "$d/repo"; git -C "$d/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$d/repo" remote add upstream "$d/fork.git"; git -C "$d/repo" push -q upstream master
mkdir -p "$d/repo/scripts/pr-queue"; cp "$SRC/install.sh" "$SRC/queue.sh" "$SRC/pre-push" "$SRC/PROTOCOL.md" "$d/repo/scripts/pr-queue/"
run solerem "$d/repo" "$WORK/q-solerem" 0 @none -- "main:      master"

# 12c — a RELATIVE core.hooksPath is refused: the wrapper would fire in the main worktree only.
d=$(scratch relhooks spec/056-x)
git -C "$d" config core.hooksPath .githooks
run relhooks "$d" "$WORK/q-relhooks" 3 @none -- "core.hooksPath is relative" "linked" "git config core.hooksPath"
check relhooks-no-wrapper "$([ ! -e "$d/.githooks/pre-push" ] && [ ! -e "$d/.git/hooks/pre-push" ]; echo $?)" "a wrapper was written despite the refusal"
check relhooks-queue-built "$([ -x "$WORK/q-relhooks/pre-push" ]; echo $?)" "the queue itself was not installed"
git -C "$d" config core.hooksPath "$d/.githooks"
run relhooks-absolute "$d" "$WORK/q-relhooks" 0 @none -- ".githooks/pre-push -> "
check relhooks-absolute-written "$([ -x "$d/.githooks/pre-push" ]; echo $?)" "no wrapper at the absolute hooks path"

# 13 — an unwritable hooks directory is exit 3 with the queue installed, not exit 1 before the
#      summary. Skipped as root, who can write anywhere.
if [ "$(id -u)" -eq 0 ]; then
  echo "skip  unwritable (running as root)"
else
  d=$(scratch unwritable spec/056-x)
  chmod 500 "$d/.git/hooks"
  run unwritable "$d" "$WORK/q-unwritable" 3 @none -- "NOT WRITTEN" "Fix the permissions"
  chmod 700 "$d/.git/hooks"
  check unwritable-queue-built "$([ -x "$WORK/q-unwritable/pre-push" ]; echo $?)" "the queue was not installed"
fi

echo "----"
echo "install-test: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
