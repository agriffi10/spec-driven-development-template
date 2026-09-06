#!/bin/sh
# pr-queue-test.sh — the fixture corpus for scripts/pr-queue/pre-push.
#
# Why this exists. The hook is a GATE: few checks, each of which goes silent invisibly. Running it
# against a healthy push proves the push is healthy and proves NOTHING about whether any check
# still fires — and half of a gate's regressions are false positives, which a corpus of only
# failures cannot see. So every check here has a case that trips it AND the silence cases that
# say who it must leave alone.
#
# Each case asserts the specific REFUSAL TEXT, not just the exit code. The neighbouring code path
# returns the same code: a stale base and a missing lock both exit 1, and a push refused for the
# wrong reason gets "fixed" by changing the wrong thing.
#
# The cases drive REAL pushes to REAL bare repos through the installed hook wrapper, rather than
# piping ref lines into the script. The hook's contract is git's stdin format and install.sh's
# wrapper, and a test that hand-feeds both would keep passing after either broke.
#
# The lock is written directly rather than through `queue.sh acquire`, because acquire consults
# the remote through `gh` — this corpus is about the hook, and must run with no network and no
# GitHub. `acquire` writes exactly these three fields; see cmd_acquire.
#
# Usage: sh scripts/pr-queue-test.sh [case-name-substring]
# POSIX sh. Needs git; needs no network, no gh, and no GitHub.

set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/scripts/pr-queue"
FILTER="${1:-}"
WORK="${TMPDIR:-/tmp}/pr-queue-test.$$"
trap 'rm -rf "$WORK"' EXIT INT TERM

# Parse the hook before exercising it. A syntax error partway through a shell script can end a
# run with status 0 — the hook never reaches its checks and every push sails through, which from
# the outside is indistinguishable from a clean corpus.
if ! bash -n "$SRC/pre-push"; then
  echo "FAIL  scripts/pr-queue/pre-push does not parse — a syntax error can exit 0 and look green."
  exit 1
fi

pass=0; fail=0; rc=0; out=""

# --- fixture builders -------------------------------------------------------------------------

# new_repo <case> — a bare origin holding one commit on main, a clone of it, and the queue
# installed at $D/queue enforcing the given pattern (default '^spec-').
new_repo() {
  D="$WORK/$1"; pattern="${2:-^spec-}"
  rm -rf "$D"; mkdir -p "$D"
  git init -q --bare "$D/origin.git"
  git init -q "$D/repo"
  git -C "$D/repo" symbolic-ref HEAD refs/heads/main
  git -C "$D/repo" config user.email t@example.com
  git -C "$D/repo" config user.name  Tester
  git -C "$D/repo" remote add origin "$D/origin.git"
  echo base > "$D/repo/f"; git -C "$D/repo" add f; git -C "$D/repo" commit -qm base
  git -C "$D/repo" push -q origin main
  ( cd "$D/repo" && PR_QUEUE_DIR="$D/queue" sh "$SRC/install.sh" "$pattern" >/dev/null )
}

# peer_advances <case> — a second clone merges a commit to origin/main, exactly as a peer would
# while you hold a ticket. Leaves the case repo's own refs untouched and stale.
peer_advances() {
  D="$WORK/$1"
  rm -rf "$D/peer"
  git clone -q "$D/origin.git" "$D/peer"
  git -C "$D/peer" config user.email p@example.com
  git -C "$D/peer" config user.name  Peer
  echo peer >> "$D/peer/f"; git -C "$D/peer" add f; git -C "$D/peer" commit -qm peer
  git -C "$D/peer" push -q origin main
}

# hold_lock <case> <branch> — the lock as cmd_acquire writes it.
hold_lock() {
  D="$WORK/$1"
  mkdir -p "$D/queue/lock"
  printf 'spec SPEC-1\nbranch %s\nsince 2026-01-01T00:00:00Z\n' "$2" > "$D/queue/lock/holder"
}

# work_branch <case> <branch> — branch off the CURRENT local main and add a commit.
work_branch() {
  D="$WORK/$1"
  git -C "$D/repo" checkout -q -b "$2" main
  echo work >> "$D/repo/g"; git -C "$D/repo" add g; git -C "$D/repo" commit -qm work
}

# try_push <case> [args...] — push through the hook, capturing output and status.
try_push() {
  D="$WORK/$1"; shift
  set +e
  out="$(git -C "$D/repo" push origin "$@" 2>&1)"; rc=$?
  set -e
}

# --- assertions -------------------------------------------------------------------------------

report() {
  if [ "$1" = 1 ]; then pass=$((pass + 1)); echo "ok    $2"
  else fail=$((fail + 1)); echo "FAIL  $2: $3"; printf '%s\n' "$out" | sed 's/^/        /' | head -8; fi
}

# refuses <case> <substring> — non-zero exit AND the refusal that names this reason.
refuses() {
  ok=1; why=""
  [ "$rc" -ne 0 ] || { ok=0; why="exit 0, wanted a refusal"; }
  case "$out" in *"$2"*) ;; *) ok=0; why="output lacked: $2" ;; esac
  report "$ok" "$1" "$why"
}

# silent <case> — exit 0 AND no refusal of any kind. The false-positive half of the corpus.
silent() {
  ok=1; why=""
  [ "$rc" -eq 0 ] || { ok=0; why="exit $rc, wanted 0"; }
  case "$out" in *"PUSH REFUSED"*) ok=0; why="expected silence, got a refusal" ;; esac
  report "$ok" "$1" "$why"
}

# absent <case> <substring> — the refusal that fired must not ALSO claim this reason.
absent() {
  ok=1; why=""
  case "$out" in *"$2"*) ok=0; why="output should not have mentioned: $2" ;; esac
  report "$ok" "$1" "$why"
}

run() { case "$1" in *"$FILTER"*) return 0 ;; *) return 1 ;; esac; }

# --- the cases --------------------------------------------------------------------------------

# FRESHNESS fires. The base moved and we fetched it, so the object is present and merge-base
# is what refuses — the defect this gate was built for: rebase, wait out the queue, push stale.
if run stale-base; then
  new_repo stale-base; work_branch stale-base spec-1/x; hold_lock stale-base spec-1/x
  peer_advances stale-base
  git -C "$WORK/stale-base/repo" fetch -q origin
  try_push stale-base spec-1/x
  refuses stale-base "your base is behind"
  absent  stale-base-not-unfetched "never fetched that commit"
fi

# FRESHNESS fires with the object ABSENT — never fetched, so merge-base cannot answer and the
# cat-file guard is what refuses. Same verdict, different check.
if run stale-unfetched; then
  new_repo stale-unfetched; work_branch stale-unfetched spec-1/x; hold_lock stale-unfetched spec-1/x
  peer_advances stale-unfetched
  try_push stale-unfetched spec-1/x
  refuses stale-unfetched "never fetched that commit"
fi

# The remedy the message prints actually clears the refusal.
if run rebased-ok; then
  new_repo rebased-ok; work_branch rebased-ok spec-1/x; hold_lock rebased-ok spec-1/x
  peer_advances rebased-ok
  git -C "$WORK/rebased-ok/repo" fetch -q origin
  git -C "$WORK/rebased-ok/repo" rebase -q origin/main >/dev/null 2>&1
  try_push rebased-ok spec-1/x
  silent rebased-ok
fi

# Nothing moved: the common case must not cost the holder a refusal.
if run unmoved-ok; then
  new_repo unmoved-ok; work_branch unmoved-ok spec-1/x; hold_lock unmoved-ok spec-1/x
  try_push unmoved-ok spec-1/x
  silent unmoved-ok
fi

# LOCK fires, and must not be reported as staleness — both exit 1, and the wrong reason sends
# the reader to rebase a branch whose real problem is that a peer holds the lock.
if run not-holder; then
  new_repo not-holder; work_branch not-holder spec-1/x; hold_lock not-holder spec-2/other
  peer_advances not-holder
  try_push not-holder spec-1/x
  refuses not-holder "you do not hold the PR queue lock"
  absent  not-holder-reason "your base is behind"
fi

# CONSENT: a branch outside the pattern is not ours to police, stale or not.
if run nonparticipating-ok; then
  new_repo nonparticipating-ok; work_branch nonparticipating-ok feature/x
  peer_advances nonparticipating-ok
  try_push nonparticipating-ok feature/x
  silent nonparticipating-ok
fi

# CONSENT: no pattern configured means enforce nothing at all.
if run no-pattern-ok; then
  new_repo no-pattern-ok; work_branch no-pattern-ok spec-1/x; hold_lock no-pattern-ok spec-1/x
  peer_advances no-pattern-ok
  : > "$WORK/no-pattern-ok/queue/enforce-branches"
  try_push no-pattern-ok spec-1/x
  silent no-pattern-ok
fi

# The documented override still works, or the gate has no escape hatch when it is wrong.
if run bypass-ok; then
  new_repo bypass-ok; work_branch bypass-ok spec-1/x; hold_lock bypass-ok spec-1/x
  peer_advances bypass-ok
  set +e
  out="$(cd "$WORK/bypass-ok/repo" && PR_QUEUE_BYPASS=1 git push origin spec-1/x 2>&1)"; rc=$?
  set -e
  silent bypass-ok
fi

# EVIDENCE: a remote we cannot read is never read as "your base is current".
#
# This is the ONE case driven by invoking the hook directly instead of by a real push, and the
# reason is worth stating: git contacts the remote for its refs BEFORE running pre-push, so a
# push to an unreachable remote dies with "Could not read from remote repository" and the hook
# never runs. The path this covers is the narrower one git leaves open — the remote answered the
# push's own connection and `ls-remote` still failed. The stdin format below is git's, and the
# real-push cases above are what keep that format honest.
if run unreadable-remote; then
  new_repo unreadable-remote; work_branch unreadable-remote spec-1/x
  hold_lock unreadable-remote spec-1/x
  U="$WORK/unreadable-remote"
  sha="$(git -C "$U/repo" rev-parse HEAD)"
  zero=0000000000000000000000000000000000000000
  set +e
  out="$(cd "$U/repo" && printf 'refs/heads/spec-1/x %s refs/heads/spec-1/x %s\n' "$sha" "$zero" |
         "$U/queue/pre-push" "$U/gone.git" "$U/gone.git" 2>&1)"; rc=$?
  set -e
  refuses unreadable-remote "could not read"
fi

# A repo whose main does not exist yet has nothing to be behind. Distinguishes "no such ref"
# (empty output, exit 0) from "the check failed" (non-zero) — conflating them refuses the first
# push into an empty repo forever.
if run no-main-ok; then
  D="$WORK/no-main-ok"; rm -rf "$D"; mkdir -p "$D"
  git init -q --bare "$D/origin.git"
  git init -q "$D/repo"
  git -C "$D/repo" symbolic-ref HEAD refs/heads/spec-1/x
  git -C "$D/repo" config user.email t@example.com
  git -C "$D/repo" config user.name Tester
  git -C "$D/repo" remote add origin "$D/origin.git"
  echo a > "$D/repo/f"; git -C "$D/repo" add f; git -C "$D/repo" commit -qm a
  ( cd "$D/repo" && PR_QUEUE_DIR="$D/queue" sh "$SRC/install.sh" '^spec-' >/dev/null )
  hold_lock no-main-ok spec-1/x
  try_push no-main-ok spec-1/x
  silent no-main-ok
fi

# A deletion carries an all-zero sha and no commit to measure. Refusing one would strand the
# branch cleanup that follows every merge.
if run delete-ok; then
  new_repo delete-ok; work_branch delete-ok spec-1/x; hold_lock delete-ok spec-1/x
  try_push delete-ok spec-1/x
  peer_advances delete-ok
  try_push delete-ok --delete spec-1/x
  silent delete-ok
fi

# An ordinary push of main is not collateral damage: it already contains the remote's main.
# Needs a pattern that matches main, which the default '^spec-' does not.
if run push-main-ff-ok; then
  new_repo push-main-ff-ok '.'
  hold_lock push-main-ff-ok main
  peer_advances push-main-ff-ok
  git -C "$WORK/push-main-ff-ok/repo" fetch -q origin
  git -C "$WORK/push-main-ff-ok/repo" merge -q --ff-only origin/main
  try_push push-main-ff-ok main
  silent push-main-ff-ok
fi

# A main force-pushed backwards over commits the remote has is a peer's work being dropped. The
# ancestry check refuses it for the same reason it refuses a stale branch, and this case is why
# the hook carries no exemption for main.
if run push-main-rewritten; then
  new_repo push-main-rewritten '.'
  hold_lock push-main-rewritten main
  peer_advances push-main-rewritten
  git -C "$WORK/push-main-rewritten/repo" fetch -q origin
  try_push push-main-rewritten --force main
  refuses push-main-rewritten "your base is behind"
fi

echo "----"
echo "pr-queue-test: $pass passed, $fail failed."
[ "$fail" -eq 0 ] || exit 1
