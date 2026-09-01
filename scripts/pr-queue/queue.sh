#!/bin/bash
# queue.sh — the PR queue: FIFO ordering over one repo shared by several agent sessions.
#
# One PR open on the remote at a time, taken in the order agents asked for it, with `main`
# settled and green before the next goes up. Every claim here is atomic (mkdir) or idempotent.
#
#   queue.sh ticket  SPEC-207   # get in line, when ready to push (idempotent — keeps your place)
#   queue.sh turn    SPEC-207   # exit 0 when it is your turn AND the remote is clear
#   queue.sh acquire SPEC-207   # take the lock; 0 on ACQUIRED, 1 on BUSY
#   queue.sh release SPEC-207   # drop the lock and the ticket; always exit 0
#   queue.sh status             # who holds it, who is waiting, what is on the remote
#   queue.sh reap               # drop dead waiters and a dead holder (also runs automatically)
#
# THIS SCRIPT LIVES OUTSIDE THE REPO. Its own directory is the queue, so every session on the
# checkout sees one lock and one line. A copy inside a worktree would be invisible to peers, and
# a copy inside the repo would be a file that itself conflicts. `install.sh` puts it in place;
# `PROTOCOL.md` beside it is what the agents read.

set -uo pipefail

Q="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TICKETS="$Q/tickets"
LOCK="$Q/lock"
LOG="$Q/log"
STALE_TICKET=1800   # 30 min with no heartbeat — a waiter that stopped
STALE_LOCK=5400     # 90 min — a holder that stopped

# --- configuration: single-value files beside this script, all written by install.sh ---------
REPO="${PR_QUEUE_REPO:-$(cat "$Q/repo" 2>/dev/null)}"
MAIN="$(cat "$Q/main-branch" 2>/dev/null)"; [ -n "$MAIN" ] || MAIN=main

die() { echo "queue.sh: $*" >&2; exit 2; }
[ -n "$REPO" ] || die "no checkout configured — write its path to $Q/repo (install.sh does this)"
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || die "$REPO is not a git checkout"

now()   { date -u +%FT%TZ; }
mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }   # BSD, then GNU
age()   { echo $(( $(date +%s) - $(mtime "$1") )); }
note()  { printf '%s %s\n' "$(now)" "$*" >> "$LOG"; }

# A ticket mid-creation has no heartbeat file yet, and reaping on a missing file would delete a
# place someone is still taking. Fall back to the directory's own age, so a half-created ticket
# is young now and still reapable later if its session died between the mkdir and the touch.
ticket_age() { if [ -f "$1/alive" ]; then age "$1/alive"; else age "$1"; fi; }

# --- the two remote checks -------------------------------------------------------------------
# Both are overridable: drop an executable named `open-prs` or `main-green` in the queue
# directory and it is used instead of the gh default below. That is the seam for a project whose
# CI is not GitHub Actions, or whose repo is not on GitHub at all.
#
# open_prs   prints the open PRs (empty output = none). Non-zero exit means THE CHECK ITSELF
#            failed — an unreadable remote is never "the remote is clear", so callers fail closed.
open_prs() {
  local out
  if [ -x "$Q/open-prs" ]; then
    out="$("$Q/open-prs")" || return 1
  else
    out="$( cd "$REPO" && gh pr list --state open --limit 20 \
              --json number,headRefName,title \
              --jq '.[] | "#\(.number)  \(.headRefName)  \(.title)"' )" || return 1
  fi
  [ -n "$out" ] && printf '%s\n' "$out"
  return 0   # empty output with a clean exit is the "no PRs open" answer
}

# main_green  0 green · 1 RED · 2 building or unsettled · 3 the check could not run.
#             Only 0 lets the queue move; every other code waits, so a check that could not run
#             is never read as evidence that it passed.
main_green() {
  [ -x "$Q/main-green" ] && { "$Q/main-green"; return $?; }
  local sha runs rsha status conclusion any=0 building=0 red=0
  # ls-remote rather than a fetch: it reads the remote's head without touching local refs, which
  # several worktrees hitting FETCH_HEAD at once would race on.
  sha="$( cd "$REPO" && git ls-remote origin "refs/heads/$MAIN" 2>/dev/null | cut -f1 )" || return 3
  [ -n "$sha" ] || return 3
  runs="$( cd "$REPO" && gh run list --branch "$MAIN" --limit 30 \
             --json headSha,status,conclusion \
             --jq '.[] | "\(.headSha) \(.status) \(.conclusion)"' )" || return 3
  while read -r rsha status conclusion; do
    [ "$rsha" = "$sha" ] || continue
    any=1
    [ "$status" = "completed" ] || { building=1; continue; }
    case "$conclusion" in success|skipped|neutral) ;; *) red=1 ;; esac
  done <<< "$runs"
  if [ "$any" -eq 0 ]; then
    # No run yet for main's head. Either CI has not started, or this repo has none — and those
    # need opposite answers, so ask which it is rather than guessing.
    ls "$REPO"/.github/workflows/*.yml "$REPO"/.github/workflows/*.yaml >/dev/null 2>&1 && return 2
    return 0
  fi
  [ "$red" -eq 1 ] && return 1
  [ "$building" -eq 1 ] && return 2
  return 0
}

# --- the holder file --------------------------------------------------------------------------
# `key value` lines, one fact per line, read by field name. The branch is compared as a STRING,
# never grepped: a substring match would let `spec-207/qu` push under `spec-207/queue`'s lock.
holder_field() { awk -v k="$1" '$1==k { $1=""; sub(/^ /,""); print; exit }' "$LOCK/holder" 2>/dev/null; }
my_branch()    { git -C "$PWD" branch --show-current 2>/dev/null; }

my_ticket() {  # prints the ticket dir for a spec, empty if it has none
  local spec="$1" t
  for t in "$TICKETS"/*/; do
    [ -d "$t" ] || continue
    [ "$(cat "$t/spec" 2>/dev/null)" = "$spec" ] && { echo "${t%/}"; return; }
  done
}

reap() {
  local t holder_age prs
  for t in "$TICKETS"/*/; do
    [ -d "$t" ] || continue
    if [ "$(ticket_age "${t%/}")" -gt "$STALE_TICKET" ]; then
      note "reaped stale ticket $(basename "$t") ($(cat "$t/spec" 2>/dev/null)) — no heartbeat"
      rm -rf "${t:?}"
    fi
  done
  [ -d "$LOCK" ] || return 0
  holder_age=$(age "$LOCK/holder")
  [ "$holder_age" -gt "$STALE_LOCK" ] || return 0
  # Age alone is not enough to break a lock: a long PR is not a dead one. Only a holder whose
  # work has demonstrably stopped may be broken, and a check that could not run proves nothing.
  prs="$(open_prs)" || return 0
  [ -z "$prs" ] || return 0
  main_green || return 0
  note "BROKE STALE LOCK held by [$(holder_field spec)] — ${holder_age}s old, no open PR, main green"
  rm -f "$LOCK/holder" && rmdir "$LOCK"
}

cmd_ticket() {
  local spec="$1" t n
  mkdir -p "$TICKETS"; reap
  t="$(my_ticket "$spec")"
  if [ -z "$t" ]; then
    # Allocate from the high-water mark, never from zero. Reaping frees a low number, and a new
    # arrival taking it would land ahead of someone who has been waiting longer — which is the
    # starvation the tickets exist to prevent.
    n=$(cat "$Q/seq" 2>/dev/null || echo 0)
    while ! mkdir "$TICKETS/$(printf %04d "$n")" 2>/dev/null; do n=$((n+1)); done
    t="$TICKETS/$(printf %04d "$n")"
    touch "$t/alive"          # heartbeat first: an unheartbeaten ticket is a reap candidate
    echo $((n+1)) > "$Q/seq"
    echo "$spec" > "$t/spec"
    my_branch > "$t/branch"
    note "$spec took ticket $(basename "$t")"
  fi
  touch "$t/alive"
  echo "ticket $(basename "$t") for $spec"
}

cmd_turn() {
  local spec="$1" t lowest rc pr
  mkdir -p "$TICKETS"; reap
  t="$(my_ticket "$spec")"
  [ -n "$t" ] || { echo "NO_TICKET — run: $0 ticket $spec"; return 3; }
  touch "$t/alive"   # the heartbeat: a live waiter keeps its place, a dead one loses it
  if [ -d "$LOCK" ]; then
    [ "$(holder_field spec)" = "$spec" ] && { echo "READY (you already hold the lock)"; return 0; }
    echo "WAIT — lock held by [$(holder_field spec) on $(holder_field branch), since $(holder_field since)]"
    return 1
  fi
  lowest="$(ls "$TICKETS" 2>/dev/null | sort | head -1)"
  [ "$lowest" = "$(basename "$t")" ] || {
    echo "WAIT — ahead of you: $(cat "$TICKETS/$lowest/spec" 2>/dev/null) (ticket $lowest)"; return 1; }
  # The lock only orders the agents that take it. Sessions outside the set push without one, so
  # ask the remote itself as well.
  pr="$(open_prs)" || { echo "WAIT — could not read the remote (the check failed). Not assuming it is clear."; return 1; }
  [ -z "$pr" ] || { echo "WAIT — a PR is open on the remote:"; echo "$pr" | head -3; return 1; }
  main_green; rc=$?
  case $rc in
    0) echo "READY — your turn, no PR open, $MAIN green"; return 0 ;;
    1) echo "WAIT — $MAIN IS RED. Stop and escalate; a red $MAIN is fixed before anything merges."; return 1 ;;
    3) echo "WAIT — could not read $MAIN's status (the check failed). Not assuming it is green."; return 1 ;;
    *) echo "WAIT — $MAIN is building or unsettled"; return 1 ;;
  esac
}

cmd_acquire() {
  local spec="$1" out
  out="$(cmd_turn "$spec")" || { echo "BUSY — $out"; return 1; }
  # mkdir IS the atomicity: it either creates or fails, with no window between the two. A
  # test-then-create has a gap, and agents polling on similar cadences land in it.
  mkdir "$LOCK" 2>/dev/null || { echo "BUSY — lost the race to [$(holder_field spec)]"; return 1; }
  { printf 'spec %s\n'   "$spec"
    printf 'branch %s\n' "$(my_branch)"
    printf 'since %s\n'  "$(now)"; } > "$LOCK/holder"
  note "$spec ACQUIRED the lock"
  echo "ACQUIRED — release it when the PR is merged and $MAIN is green, on every exit path"
}

cmd_release() {
  local spec="$1" t
  if [ -d "$LOCK" ] && [ "$(holder_field spec)" = "$spec" ]; then
    rm -f "$LOCK/holder" && rmdir "$LOCK" && note "$spec released the lock" && echo "RELEASED"
  else
    echo "NOT_HELD by $spec — lock left alone"
  fi
  t="$(my_ticket "$spec")"; [ -n "$t" ] && rm -rf "${t:?}" && note "$spec dropped its ticket"
  return 0
}

cmd_status() {
  local n prs
  mkdir -p "$TICKETS"
  if [ -d "$LOCK" ]; then
    echo "LOCK: [$(holder_field spec) on $(holder_field branch)] — held $(age "$LOCK/holder")s"
  else
    echo "LOCK: free"
  fi
  echo "WAITING:"
  ls "$TICKETS" 2>/dev/null | sort | while read -r n; do
    printf '  %s  %s  (%ss since heartbeat)\n' \
      "$n" "$(cat "$TICKETS/$n/spec" 2>/dev/null)" "$(ticket_age "$TICKETS/$n")"
  done
  echo "OPEN PRs:"
  # Assigned first, then printed: in a pipeline `||` would test sed's exit status, not the
  # check's, and the "could not read" branch would never fire.
  if prs="$(open_prs)"; then
    if [ -n "$prs" ]; then printf '%s\n' "$prs" | sed 's/^/  /'; else echo "  (none)"; fi
  else
    echo "  (COULD NOT READ THE REMOTE — this is not evidence that it is clear)"
  fi
  return 0
}

case "${1:-}" in
  ticket)  cmd_ticket  "${2:?spec id required, e.g. SPEC-207}" ;;
  turn)    cmd_turn    "${2:?spec id required}" ;;
  acquire) cmd_acquire "${2:?spec id required}" ;;
  release) cmd_release "${2:?spec id required}" ;;
  status)  cmd_status ;;
  reap)    mkdir -p "$TICKETS"; reap; echo "reaped" ;;
  *) sed -n '2,15p' "${BASH_SOURCE[0]}"; exit 64 ;;
esac
