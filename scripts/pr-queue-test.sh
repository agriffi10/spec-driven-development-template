#!/bin/sh
# pr-queue-test.sh — the fixture corpus for scripts/pr-queue/pre-push, and its mutation sweep.
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
# THE MUTATION SWEEP. A corpus proves its checks fire only if breaking a check turns a case red,
# so after the cases pass, each PLANT below breaks one check in a copy of the hook — a single-line
# edit that must land exactly once — and re-runs the cases that check owns, expecting at least one
# to fail. A plant whose cases all still pass is a check nothing here tests. The sweep is what
# makes "seven checks had no test at all and survived mutation silently" impossible to repeat.
#
# Usage: sh scripts/pr-queue-test.sh [case-name-substring]
#   PR_QUEUE_TEST_SRC=<dir>     take the hook and installer from <dir> (the sweep uses this)
#   PR_QUEUE_TEST_NO_SWEEP=1    run the cases only
# POSIX sh. Needs git; needs no network, no gh, and no GitHub.

set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${PR_QUEUE_TEST_SRC:-$ROOT/scripts/pr-queue}"
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

# new_repo <case> [pattern] [trunk] — a bare origin holding one commit on the trunk, a clone of it,
# and the queue installed at $D/queue enforcing the given pattern (default '.', the installed
# default: every branch).
new_repo() {
  D="$WORK/$1"; pattern="${2:-.}"; trunk="${3:-main}"
  rm -rf "$D"; mkdir -p "$D"
  git init -q --bare "$D/origin.git"
  git init -q "$D/repo"
  git -C "$D/repo" symbolic-ref HEAD "refs/heads/$trunk"
  git -C "$D/repo" config user.email t@example.com
  git -C "$D/repo" config user.name  Tester
  git -C "$D/repo" remote add origin "$D/origin.git"
  echo base > "$D/repo/f"; git -C "$D/repo" add f; git -C "$D/repo" commit -qm base
  git -C "$D/repo" push -q origin "$trunk"
  git -C "$D/origin.git" symbolic-ref HEAD "refs/heads/$trunk"
  printf '%s\n' "$trunk" > "$D/trunk"
  # Deliberately `init` + `remote add`, not `clone`: that is the checkout shape where
  # refs/remotes/origin/HEAD never exists, so install.sh has to ask the remote for the trunk name.
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
  git -C "$D/peer" push -q origin "$(cat "$D/trunk")"
}

# hold_lock <case> <branch> [spec] — the lock as cmd_acquire writes it.
hold_lock() {
  D="$WORK/$1"
  mkdir -p "$D/queue/lock"
  printf 'spec %s\nbranch %s\nsince 2026-01-01T00:00:00Z\n' "${3:-SPEC-1}" "$2" > "$D/queue/lock/holder"
}

# work_branch <case> <branch> — branch off the CURRENT local main and add a commit.
work_branch() {
  D="$WORK/$1"
  git -C "$D/repo" checkout -q -b "$2"
  echo work >> "$D/repo/g"; git -C "$D/repo" add g; git -C "$D/repo" commit -qm work
}

# try_push <case> [args...] — push to origin through the hook, capturing output and status.
try_push() { D="$WORK/$1"; shift; try_push_to "$D" origin "$@"; }

# try_push_to <case-dir> <remote> [args...] — the same, to a named remote.
try_push_to() {
  D="$1"; remote="$2"; shift 2
  set +e
  out="$(git -C "$D/repo" push "$remote" "$@" 2>&1)"; rc=$?
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

# The refusal names the holder and the recovery for a lock taken from the wrong directory — the
# re-stamp — rather than sending the reader to the bypass.
if run restamp-hint; then
  new_repo restamp-hint; work_branch restamp-hint spec-1/x; hold_lock restamp-hint spec-1/other SPEC-7
  try_push restamp-hint spec-1/x
  refuses restamp-hint "Lock holder:   SPEC-7 on spec-1/other"
  refuses restamp-hint-recovery "acquire SPEC-7"
  refuses restamp-hint-restamp "re-run"
fi

# A lock whose holder file parses to nothing is NOT reported as free — the reader would go
# looking for a race that is not happening, and the wait for the reaper can be indefinite.
if run holder-unreadable; then
  new_repo holder-unreadable; work_branch holder-unreadable spec-1/x
  mkdir -p "$WORK/holder-unreadable/queue/lock"; : > "$WORK/holder-unreadable/queue/lock/holder"
  try_push holder-unreadable spec-1/x
  refuses holder-unreadable "parses to nothing"
  absent  holder-unreadable-not-free "(free)"
fi

# CONSENT: a branch outside the pattern is not ours to police, stale or not.
if run nonparticipating-ok; then
  new_repo nonparticipating-ok '^spec-'; work_branch nonparticipating-ok feature/x
  peer_advances nonparticipating-ok
  try_push nonparticipating-ok feature/x
  silent nonparticipating-ok
fi

# CONSENT: no pattern configured means enforce nothing at all.
if run no-pattern-ok; then
  new_repo no-pattern-ok; work_branch no-pattern-ok spec-1/x; hold_lock no-pattern-ok spec-2/other
  peer_advances no-pattern-ok
  : > "$WORK/no-pattern-ok/queue/enforce-branches"
  try_push no-pattern-ok spec-1/x
  silent no-pattern-ok
fi

# EVIDENCE: a pattern grep cannot compile is a refusal of its own, not "no branch matches".
# install.sh refuses to write one, so this is the hand-edited file it cannot prevent.
if run bad-pattern; then
  new_repo bad-pattern; work_branch bad-pattern spec-1/x; hold_lock bad-pattern spec-1/x
  printf 'spec-[\n' > "$WORK/bad-pattern/queue/enforce-branches"
  try_push bad-pattern spec-1/x
  refuses bad-pattern "not an ERE grep can compile"
  absent  bad-pattern-not-lock "you do not hold the PR queue lock"
fi

# The documented override still works, or the gate has no escape hatch when it is wrong.
if run bypass-ok; then
  new_repo bypass-ok; work_branch bypass-ok spec-1/x; hold_lock bypass-ok spec-2/other
  peer_advances bypass-ok
  set +e
  out="$(cd "$WORK/bypass-ok/repo" && PR_QUEUE_BYPASS=1 git push origin spec-1/x 2>&1)"; rc=$?
  set -e
  silent bypass-ok
fi

# CONSENT: a push to a remote that is not origin can open no pull request here. Stale AND
# lock-less, so both refusals would fire if the exemption did not.
if run nonorigin-ok; then
  new_repo nonorigin-ok; work_branch nonorigin-ok spec-1/x; hold_lock nonorigin-ok spec-2/other
  git init -q --bare "$WORK/nonorigin-ok/backup.git"
  git -C "$WORK/nonorigin-ok/repo" remote add backup "$WORK/nonorigin-ok/backup.git"
  peer_advances nonorigin-ok
  try_push_to "$WORK/nonorigin-ok" backup spec-1/x
  silent nonorigin-ok
fi

# EVIDENCE: a remote we cannot read is never read as "your base is current".
#
# This is the ONE case driven by invoking the hook directly instead of by a real push, and the
# reason is worth stating: git contacts the remote for its refs BEFORE running pre-push, so a
# push to an unreachable remote dies with "Could not read from remote repository" and the hook
# never runs. The path this covers is the narrower one git leaves open — the remote answered the
# push's own connection and `ls-remote` still failed. The stdin format below is git's, and the
# real-push cases above are what keep that format honest. Origin is repointed at the unreadable
# url first, because a url that is not origin's is exempt before it is ever read.
if run unreadable-remote; then
  new_repo unreadable-remote; work_branch unreadable-remote spec-1/x
  hold_lock unreadable-remote spec-1/x
  U="$WORK/unreadable-remote"
  git -C "$U/repo" remote set-url origin "$U/gone.git"
  sha="$(git -C "$U/repo" rev-parse HEAD)"
  zero=0000000000000000000000000000000000000000
  set +e
  out="$(cd "$U/repo" && printf 'refs/heads/spec-1/x %s refs/heads/spec-1/x %s\n' "$sha" "$zero" |
         "$U/queue/pre-push" origin "$U/gone.git" 2>&1)"; rc=$?
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
  ( cd "$D/repo" && PR_QUEUE_DIR="$D/queue" sh "$SRC/install.sh" '.' >/dev/null )
  hold_lock no-main-ok spec-1/x
  try_push no-main-ok spec-1/x
  silent no-main-ok
fi

# The refusal names EVERY ref that lacks the lock, not the last one read.
if run multi-ref; then
  new_repo multi-ref; work_branch multi-ref spec-1/x
  git -C "$WORK/multi-ref/repo" checkout -q main; work_branch multi-ref spec-1/y
  try_push multi-ref spec-1/x spec-1/y
  refuses multi-ref-first  " spec-1/x"
  refuses multi-ref-second " spec-1/y"
fi

# No lock held at all is still a refusal, and says the lock is free rather than naming a holder.
if run lock-free; then
  new_repo lock-free; work_branch lock-free spec-1/x
  try_push lock-free spec-1/x
  refuses lock-free "Lock holder:   (free)"
fi

# The decision keys on the REMOTE ref. A topic branch pushed ONTO the trunk is a trunk push
# (no lock needed, and it fast-forwards); the trunk pushed onto a topic name is a topic push.
if run refspec-onto-trunk-ok; then
  new_repo refspec-onto-trunk-ok; work_branch refspec-onto-trunk-ok spec-1/x
  hold_lock refspec-onto-trunk-ok spec-2/other
  try_push refspec-onto-trunk-ok spec-1/x:main
  silent refspec-onto-trunk-ok
fi
if run refspec-trunk-onto-topic; then
  new_repo refspec-trunk-onto-topic
  hold_lock refspec-trunk-onto-topic spec-2/other
  try_push refspec-trunk-onto-topic main:refs/heads/topic
  refuses refspec-trunk-onto-topic "you do not hold the PR queue lock"
fi

# A tag is not a branch: nothing under refs/tags/ is ever inspected.
if run tag-ok; then
  new_repo tag-ok; hold_lock tag-ok spec-2/other
  git -C "$WORK/tag-ok/repo" tag v1
  try_push tag-ok v1
  silent tag-ok
fi

# CONSENT: origin spelled with a trailing slash is still origin. Treating it as foreign would
# exempt a push going straight to origin — silently.
if run origin-respelled; then
  new_repo origin-respelled; work_branch origin-respelled spec-1/x; hold_lock origin-respelled spec-2/other
  git -C "$WORK/origin-respelled/repo" remote add mirror "$WORK/origin-respelled/origin.git/"
  try_push_to "$WORK/origin-respelled" mirror spec-1/x
  refuses origin-respelled "you do not hold the PR queue lock"
fi

# EVIDENCE: a checkout whose origin cannot be read is ENFORCED — origin is the overwhelmingly
# likely target, and an unreadable configuration must not become an exemption. Driven directly,
# because `git push` needs a remote to exist.
if run origin-unreadable-enforced; then
  new_repo origin-unreadable-enforced; work_branch origin-unreadable-enforced spec-1/x
  hold_lock origin-unreadable-enforced spec-2/other
  U="$WORK/origin-unreadable-enforced"
  sha="$(git -C "$U/repo" rev-parse HEAD)"
  git -C "$U/repo" remote remove origin
  set +e
  out="$(cd "$U/repo" && printf 'refs/heads/spec-1/x %s refs/heads/spec-1/x %s\n' "$sha" \
         0000000000000000000000000000000000000000 | "$U/queue/pre-push" origin "$U/origin.git" 2>&1)"; rc=$?
  set -e
  refuses origin-unreadable-enforced "you do not hold the PR queue lock"
fi

# A deleted queue directory takes the hook with it; the wrapper's exec-if-present is what lets
# the push through. No plant: this is the wrapper, not the hook.
if run absent-queue-ok; then
  new_repo absent-queue-ok; work_branch absent-queue-ok spec-1/x
  rm -rf "$WORK/absent-queue-ok/queue"
  try_push absent-queue-ok spec-1/x
  silent absent-queue-ok
fi

# A deletion of the TRUNK is refused outright: no lock covers it, no commit measures it, and it
# is the limit case of a trunk pushed backwards over a peer's work.
if run delete-trunk; then
  new_repo delete-trunk; work_branch delete-trunk spec-1/x; hold_lock delete-trunk spec-1/x
  try_push delete-trunk --delete main
  refuses delete-trunk "would drop every commit"
  absent  delete-trunk-not-lock "you do not hold the PR queue lock"
fi

# The trunk's refusals run AHEAD of the pattern: a pattern narrowed to exclude the trunk must not
# uncover it. Both of these pass silently if the pattern test comes first.
if run narrowed-trunk-rewritten; then
  new_repo narrowed-trunk-rewritten '^spec-'
  peer_advances narrowed-trunk-rewritten
  git -C "$WORK/narrowed-trunk-rewritten/repo" fetch -q origin
  try_push narrowed-trunk-rewritten --force main
  refuses narrowed-trunk-rewritten "your base is behind"
fi
if run narrowed-trunk-delete; then
  new_repo narrowed-trunk-delete '^spec-'; work_branch narrowed-trunk-delete spec-1/x
  try_push narrowed-trunk-delete --delete main
  refuses narrowed-trunk-delete "would drop every commit"
fi

# A deletion carries no commit to measure, so the HOLDER may delete after main moved: refusing
# it would strand the branch cleanup that follows every merge.
if run delete-ok; then
  new_repo delete-ok; work_branch delete-ok spec-1/x; hold_lock delete-ok spec-1/x
  try_push delete-ok spec-1/x
  peer_advances delete-ok
  try_push delete-ok --delete spec-1/x
  silent delete-ok
fi

# But a deletion is NOT exempt from the lock: a non-holder deleting the branch under review
# closes the PR the lock exists to protect.
if run delete-nonholder; then
  new_repo delete-nonholder; work_branch delete-nonholder spec-1/x; hold_lock delete-nonholder spec-1/x
  try_push delete-nonholder spec-1/x
  hold_lock delete-nonholder spec-2/other
  try_push delete-nonholder --delete spec-1/x
  refuses delete-nonholder "you do not hold the PR queue lock"
fi

# An ordinary push of main is not collateral damage: it already contains the remote's main.
if run push-main-ff-ok; then
  new_repo push-main-ff-ok
  hold_lock push-main-ff-ok main
  peer_advances push-main-ff-ok
  git -C "$WORK/push-main-ff-ok/repo" fetch -q origin
  git -C "$WORK/push-main-ff-ok/repo" merge -q --ff-only origin/main
  try_push push-main-ff-ok main
  silent push-main-ff-ok
fi

# The trunk needs no lock: merging is a push of the trunk, and a lock stamped with it would cover
# nothing. A peer holds the lock on its own branch; a fast-forward of main still goes through.
if run push-main-nonholder-ok; then
  new_repo push-main-nonholder-ok
  hold_lock push-main-nonholder-ok spec-9/z
  peer_advances push-main-nonholder-ok
  git -C "$WORK/push-main-nonholder-ok/repo" fetch -q origin
  git -C "$WORK/push-main-nonholder-ok/repo" merge -q --ff-only origin/main
  echo more >> "$WORK/push-main-nonholder-ok/repo/f"
  git -C "$WORK/push-main-nonholder-ok/repo" add f; git -C "$WORK/push-main-nonholder-ok/repo" commit -qm more
  try_push push-main-nonholder-ok main
  silent push-main-nonholder-ok
fi

# A main force-pushed backwards over commits the remote has is a peer's work being dropped. The
# ancestry check refuses it for the same reason it refuses a stale branch, and this case is why
# the trunk's lock exemption is not a freshness exemption.
if run push-main-rewritten; then
  new_repo push-main-rewritten
  hold_lock push-main-rewritten main
  peer_advances push-main-rewritten
  git -C "$WORK/push-main-rewritten/repo" fetch -q origin
  try_push push-main-rewritten --force main
  refuses push-main-rewritten "your base is behind"
fi

# The check must read the ref BEING PUSHED, not HEAD. The hook says so in a comment; without
# these two, substituting HEAD for the pushed sha passes the whole corpus, because every other
# case happens to push the branch it is standing on.
if run push-from-other-branch; then
  new_repo push-from-other-branch; work_branch push-from-other-branch spec-1/x
  hold_lock push-from-other-branch spec-1/x
  peer_advances push-from-other-branch
  git -C "$WORK/push-from-other-branch/repo" fetch -q origin
  git -C "$WORK/push-from-other-branch/repo" checkout -q -B current origin/main
  try_push push-from-other-branch spec-1/x
  refuses push-from-other-branch "your base is behind"
fi

if run push-detached-head; then
  new_repo push-detached-head; work_branch push-detached-head spec-1/x
  hold_lock push-detached-head spec-1/x
  peer_advances push-detached-head
  git -C "$WORK/push-detached-head/repo" fetch -q origin
  git -C "$WORK/push-detached-head/repo" checkout -q --detach origin/main
  try_push push-detached-head spec-1/x:refs/heads/spec-1/x
  refuses push-detached-head "your base is behind"
fi

# A trunk that is not called `main`. install.sh must infer it, and the check must then work
# against it — hardcoding MAIN=main in the hook passes every other case in this file.
if run trunk-not-main; then
  new_repo trunk-not-main '.' master; work_branch trunk-not-main spec-1/x
  hold_lock trunk-not-main spec-1/x
  peer_advances trunk-not-main
  git -C "$WORK/trunk-not-main/repo" fetch -q origin
  try_push trunk-not-main spec-1/x
  refuses trunk-not-main "your base is behind"
fi

# A trunk the remote does not have is a MISCONFIGURED queue, not an empty repo. Reading the one
# as the other silently disables the check for the whole repository.
if run trunk-missing; then
  new_repo trunk-missing; work_branch trunk-missing spec-1/x
  hold_lock trunk-missing spec-1/x
  printf 'nosuch\n' > "$WORK/trunk-missing/queue/main-branch"
  try_push trunk-missing spec-1/x
  refuses trunk-missing "has no branch named"
fi

# `remote.origin.pushurl` makes the fetch url and the push target different repositories. The
# base must be measured against the one being pushed to — and a pushurl IS origin, so the
# non-origin exemption must not swallow it.
if run pushurl-split; then
  new_repo pushurl-split; work_branch pushurl-split spec-1/x
  hold_lock pushurl-split spec-1/x
  git clone -q --bare "$WORK/pushurl-split/origin.git" "$WORK/pushurl-split/frozen.git"
  peer_advances pushurl-split
  git -C "$WORK/pushurl-split/repo" remote set-url origin "$WORK/pushurl-split/frozen.git"
  git -C "$WORK/pushurl-split/repo" remote set-url --push origin "$WORK/pushurl-split/origin.git"
  git -C "$WORK/pushurl-split/repo" fetch -q origin
  try_push pushurl-split spec-1/x
  refuses pushurl-split "your base is behind"
fi

# The holder is compared as a whole string. A substring test would let spec-1/x push under a lock
# held by spec-1/xyz, and the existing not-holder case cannot see the difference.
if run holder-substring; then
  new_repo holder-substring; work_branch holder-substring spec-1/x
  hold_lock holder-substring spec-1/xyz
  try_push holder-substring spec-1/x
  refuses holder-substring "you do not hold the PR queue lock"
fi

# ls-remote matches a ref pattern by TAIL, so a branch named `decoy/refs/heads/main` answers a
# query for `refs/heads/main`. Selecting the wrong line refuses a push whose base is current.
if run decoy-ref-ok; then
  new_repo decoy-ref-ok; work_branch decoy-ref-ok spec-1/x
  hold_lock decoy-ref-ok spec-1/x
  ( cd "$WORK/decoy-ref-ok/repo" &&
      PR_QUEUE_BYPASS=1 git push -q origin main:refs/heads/decoy/refs/heads/main 2>/dev/null )
  try_push decoy-ref-ok spec-1/x
  silent decoy-ref-ok
fi

# A filter that matched no case is a misspelling, not a pass — the sweep depends on this exit.
if [ -n "$FILTER" ] && [ "$((pass + fail))" -eq 0 ]; then
  echo "pr-queue-test: no case matches '$FILTER'"
  exit 2
fi

echo "----"
echo "pr-queue-test: $pass passed, $fail failed."
[ "$fail" -eq 0 ] || exit 1

# --- the mutation sweep -----------------------------------------------------------------------
# Runs only after a clean full run. Each plant is one sed edit to a copy of the hook, and the
# cases that check owns; the plant passes when its edit landed on exactly one line AND at least
# one of its cases went red against the mutated hook. Silence cases are plants too: breaking an
# exemption must turn the silence case red, or the exemption is a comment.
[ -z "$FILTER" ] && [ -z "${PR_QUEUE_TEST_NO_SWEEP:-}" ] || exit 0

splant=0; sfail=0
plant() {  # <name> <sed-expression> <case>...
  pname="$1"; pexpr="$2"; shift 2
  M="$WORK/mut-$pname"; rm -rf "$M"; mkdir -p "$M"
  cp "$SRC/install.sh" "$SRC/queue.sh" "$SRC/PROTOCOL.md" "$M/"
  sed "$pexpr" "$SRC/pre-push" > "$M/pre-push"; chmod +x "$M/pre-push"
  changed=$(diff "$SRC/pre-push" "$M/pre-push" | grep -c '^>' || true)
  if [ "$changed" -ne 1 ]; then
    sfail=$((sfail + 1)); echo "FAIL  plant $pname: the edit changed $changed line(s), wanted exactly 1"; return 0
  fi
  # A mutant that does not parse fails the sub-run's `bash -n` guard, which would count as "the
  # case went red" without the check ever being exercised — a vacuous plant that looks strong.
  if ! bash -n "$M/pre-push" 2>/dev/null; then
    sfail=$((sfail + 1)); echo "FAIL  plant $pname: the mutant does not parse, so its cases fail for the wrong reason"; return 0
  fi
  broke=0
  for c in "$@"; do
    set +e
    PR_QUEUE_TEST_SRC="$M" PR_QUEUE_TEST_NO_SWEEP=1 sh "$0" "$c" >/dev/null 2>&1; prc=$?
    set -e
    case "$prc" in
      0) ;;
      2) sfail=$((sfail + 1)); echo "FAIL  plant $pname names a case that does not exist: $c"; return 0 ;;
      *) broke=1 ;;
    esac
  done
  if [ "$broke" = 1 ]; then splant=$((splant + 1)); echo "ok    plant $pname"
  else sfail=$((sfail + 1)); echo "FAIL  plant $pname: every case it names still passes — nothing tests that check"; fi
}

plant lock-check      's#refused="\$refused \$branch"; continue; fi#:; fi#'                                   not-holder holder-substring delete-nonholder
plant ancestry        's#|| stale="\$stale \$branch"$#|| true#'                                              stale-base push-main-rewritten push-from-other-branch
plant unfetched       's#stale="\$stale \$branch"; unfetched=#unfetched=#'                                   stale-unfetched
plant unreadable      's#if \[ "\$main_readable" -eq 0 \]#if false#'                                         unreadable-remote
plant trunk-missing   's#if \[ "\$trunk_missing" -eq 1 \]#if false#'                                         trunk-missing
plant origin-scope    's#\[ "\$matched" = 1 \] || exit 0#:#'                                                  nonorigin-ok
plant trunk-lock      's#^  if \[ "\$branch" = "\$MAIN" \]; then#  if false; then#'                          push-main-nonholder-ok narrowed-trunk-rewritten
plant bad-pattern     's#\*) badpat=1; continue ;;#*) continue ;;#'                                          bad-pattern
plant bypass          's#PR_QUEUE_BYPASS:-}" = "1"#PR_QUEUE_BYPASS:-}" = "never"#'                           bypass-ok
plant delete-exempt   's#\[ "\$lref" = "(delete)" \] && continue#:#'                                          delete-ok
plant participation   's#^ *1) continue ;;#      1) ;;#'                                                      nonparticipating-ok
plant empty-pattern   's#^\[ -n "\$PATTERN" \] || exit 0#:#'                                                  no-pattern-ok
plant final-exit      's#^exit 1$#exit 0#'                                                                    stale-base not-holder
plant pushed-sha      's#"\$main_sha" "\$lsha"#"$main_sha" HEAD#'                                             push-from-other-branch push-detached-head
plant holder-parse    's#if \[ -d "\$Q/lock" \] && \[ -z "\$holder_spec" \]#if false#'                    holder-unreadable
plant restamp-hint    's#If that lock is yours, re-run#If that lock is yours, run#'                            restamp-hint
plant delete-trunk    's#then deltrunk="\$deltrunk \$branch"; continue; fi#then :; fi#'                       delete-trunk narrowed-trunk-delete
plant multi-ref       's#refused="\$refused \$branch"; continue; fi#refused="$branch"; continue; fi#'          multi-ref
plant lock-free-text  's#held="(free)"#held="(none)"#'                                                         lock-free
plant ref-keying      's#^while read -r lref lsha rref _rsha; do#while read -r rref lsha lref _rsha; do#'      refspec-onto-trunk-ok refspec-trunk-onto-topic
plant tag-exempt      's|\*) continue ;; esac$|*) branch="${rref#refs/tags/}" ;; esac|'                        tag-ok
plant norm-url        's#^norm_url() { printf .*#norm_url() { printf "%s" "$1"; }#'                            origin-respelled
plant origins-read    's#if \[ -n "\${2:-}" \] && \[ -n "\$ORIGINS" \]; then#if [ -n "${2:-}" ]; then#'      origin-unreadable-enforced

echo "----"
echo "pr-queue-test sweep: $splant plant(s) broke their cases, $sfail failed."
[ "$sfail" -eq 0 ] || exit 1
