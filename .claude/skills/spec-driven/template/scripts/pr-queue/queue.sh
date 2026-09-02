#!/bin/bash
# queue.sh — the PR queue: FIFO ordering over one repo shared by several agent sessions.
#
# One PR open on the remote at a time, taken in the order agents asked for it, with `main`
# settled and green before the next goes up. Every claim here is atomic (mkdir) or idempotent.
#
#   queue.sh ticket  SPEC-207   # get in line, when ready to push (idempotent — keeps your place)
#   queue.sh turn    SPEC-207   # exit 0 when it is your turn AND the remote is clear
#   queue.sh acquire SPEC-207   # take the lock; 0 on ACQUIRED, 1 on BUSY. Run it from your worktree
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
HALF_BUILT=60       # grace for a ticket still being created

# --- configuration: single-value files beside this script, all written by install.sh ---------
REPO="${PR_QUEUE_REPO:-$(cat "$Q/repo" 2>/dev/null)}"
MAIN="$(cat "$Q/main-branch" 2>/dev/null)"; [ -n "$MAIN" ] || MAIN=main

die() { echo "queue.sh: $*" >&2; exit 2; }
[ -n "$REPO" ] || die "no checkout configured — write its path to $Q/repo (install.sh does this)"
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || die "$REPO is not a git checkout"

# `stat` differs between BSD and GNU, and handing GNU the BSD spelling does not fail quietly: it
# reads `-f` as --file-system and PRINTS A REPORT on stdout, which a `||` fallback then appends
# to. So probe the spelling once, and refuse any answer that is not a number.
if stat -c %Y "$Q" >/dev/null 2>&1; then STAT_MTIME=(stat -c %Y)   # GNU / busybox
else                                     STAT_MTIME=(stat -f %m)   # BSD / macOS
fi

now()   { date -u +%FT%TZ; }
mtime() { local m; m="$("${STAT_MTIME[@]}" "$1" 2>/dev/null)"
          case "$m" in ''|*[!0-9]*) echo 0 ;; *) echo "$m" ;; esac; }
age()   { echo $(( $(date +%s) - $(mtime "$1") )); }
note()  { printf '%s %s\n' "$(now)" "$*" >> "$LOG"; }

# A ticket mid-creation has no heartbeat file yet, and reaping on a missing file would delete a
# place someone is still taking. Fall back to the directory's own age, so a half-created ticket
# is young now and still reapable later if its session died between the mkdir and the touch.
ticket_age() { if [ -f "$1/alive" ]; then age "$1/alive"; else age "$1"; fi; }

# --- the two remote checks -------------------------------------------------------------------
# All three are overridable: drop an executable named `open-prs`, `all-prs` or `main-green` in the
# queue directory and it is used instead of the gh default below. That is the seam for a project
# whose CI is not GitHub Actions, or whose repo is not on GitHub at all. NOTE that `open-prs` must
# exclude drafts — an override written before drafts were exempted reinstates draft-blocking, and
# nothing here can detect that, because an override is opaque by design.
#
# open_prs   prints the open NON-DRAFT PRs (empty output = none). Non-zero exit means THE
#            CHECK ITSELF failed — an unreadable remote is never "the remote is clear", so
#            callers fail closed.
#
# A DRAFT DOES NOT BLOCK. The remote check stands in for "another agent is mid-turn", and a
# draft is the one open PR explicitly *not* ready to merge — it can sit for hours by design.
# Counting one starves every agent that obeys this queue while agents that never took a
# ticket push straight past it. Measured in s3-upload-portal, whose queue log records it: ticket 0017 took its place at 21:40:09Z and did not acquire until 00:21:55Z
# — two hours forty behind a draft titled "DO NOT MERGE YET", as the only waiter, with the
# lock free throughout. A non-draft PR still blocks, bot-authored ones included: those are
# intended to merge, so waiting for them is the point.
open_prs() {
  local out
  if [ -x "$Q/open-prs" ]; then
    out="$("$Q/open-prs")" || return 1
  else
    out="$( cd "$REPO" && gh pr list --state open --limit 20 \
              --json number,headRefName,title,isDraft \
              --jq '.[] | select(.isDraft | not) | "#\(.number)  \(.headRefName)  \(.title)"' )" || return 1
  fi
  [ -n "$out" ] && printf '%s\n' "$out"
  return 0   # empty output with a clean exit is the "no PRs open" answer
}

# all_prs    every open PR INCLUDING drafts, for `status` only — never for gating. Without
#            this a clear `turn` next to a visibly open draft reads as a bug in the queue.
all_prs() {
  local out
  if [ -x "$Q/all-prs" ]; then
    out="$("$Q/all-prs")" || return 1
  elif [ -x "$Q/open-prs" ]; then
    # A gh-less install that predates this function wrote only `open-prs`. Fall back to it
    # rather than reaching for a `gh` that is not there: drafts go unlisted in `status`, which
    # is a smaller loss than a permanently broken `status` and a stale-lock check that cannot
    # read the remote at all.
    out="$("$Q/open-prs")" || return 1
  else
    out="$( cd "$REPO" && gh pr list --state open --limit 20 \
              --json number,headRefName,title,isDraft \
              --jq '.[] | "#\(.number)  \(.headRefName)  \(.title)\(if .isDraft then "   DRAFT (ignored by the queue)" else "" end)"' )" || return 1
  fi
  [ -n "$out" ] && printf '%s\n' "$out"
  return 0
}

# main_green  0 green · 1 RED · 2 building or unsettled · 3 the check could not run.
#             Only 0 lets the queue move, so a check that could not run is never read as
#             evidence that it passed.
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
    # need opposite answers, so ask which it is rather than guessing. One `ls` per extension:
    # `ls a b` exits non-zero when EITHER operand is missing, so a single call testing both
    # would answer "no workflows" for the repo that has only one of them.
    ls "$REPO"/.github/workflows/*.yml  >/dev/null 2>&1 && return 2
    ls "$REPO"/.github/workflows/*.yaml >/dev/null 2>&1 && return 2
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
  local t spec held lock_age before after prs
  held="$(holder_field spec)"
  for t in "$TICKETS"/*/; do
    [ -d "$t" ] || continue
    t="${t%/}"
    spec="$(cat "$t/spec" 2>/dev/null)"
    if [ -z "$spec" ]; then
      # Creation died between the mkdir and the write. Nobody can claim this ticket and it sits
      # at the head of the line, so clear it — after a grace period, because a ticket being
      # taken at this instant looks exactly the same.
      [ "$(age "$t")" -gt "$HALF_BUILT" ] &&
        { note "cleared ticket $(basename "$t") — created but never named"; rm -rf "${t:?}"; }
      continue
    fi
    # The holder is not a waiter. Acquiring stops the polling, and the lock covers a PR lifecycle
    # far longer than the waiter timeout, so ageing out the holder's own ticket would be wrong.
    [ -n "$held" ] && [ "$spec" = "$held" ] && continue
    if [ "$(ticket_age "$t")" -gt "$STALE_TICKET" ]; then
      note "reaped stale ticket $(basename "$t") ($spec) — no heartbeat"
      rm -rf "${t:?}"
    fi
  done
  [ -d "$LOCK" ] || return 0
  # The LOCK DIRECTORY's age, not the holder file's. `acquire` does mkdir first and writes the
  # holder second, and a holder file that is not there yet reads as mtime 0 — which makes a lock
  # one second old look infinitely old, and evicts live holders under contention.
  lock_age=$(age "$LOCK")
  [ "$lock_age" -gt "$STALE_LOCK" ] || return 0
  # Age alone is not enough to break a lock: a long PR is not a dead one. Only a holder whose
  # work has demonstrably stopped may be broken, and a check that could not run proves nothing.
  #
  # ALL_PRS, NOT OPEN_PRS — the two questions are different and only one of them ignores
  # drafts. Gating a waiter asks "is someone mid-turn", and a draft is explicitly not that.
  # Breaking a lock asks "has this holder stopped", and an open draft is live evidence they
  # have not: a holder who opens one would otherwise lose the protection they had, get their
  # lock broken under them, and leave two PRs open at once — the invariant this queue exists
  # for. Nothing refreshes the lock's mtime after acquire, so this check is the only thing
  # standing between a slow holder and a broken lock.
  before=$(mtime "$LOCK")
  prs="$(all_prs)" || return 0
  [ -z "$prs" ] || return 0
  main_green || return 0
  # Those checks take seconds, and the lock can turn over inside them. Re-read before deleting:
  # a changed mtime means someone has acquired since, and this is no longer a dead lock.
  after=$(mtime "$LOCK")
  [ "$before" = "$after" ] || return 0
  [ "$(age "$LOCK")" -gt "$STALE_LOCK" ] || return 0
  note "BROKE STALE LOCK held by [$(holder_field spec)] — ${lock_age}s old, no open PR of any kind, main green"
  rm -f "$LOCK/holder" && rmdir "$LOCK"
}

cmd_ticket() {
  local spec="$1" t n d b
  mkdir -p "$TICKETS"; reap
  t="$(my_ticket "$spec")"
  if [ -z "$t" ]; then
    # Allocate from the high-water mark, never from zero. Reaping frees a low number, and a new
    # arrival taking it would land ahead of someone who has been waiting longer — which is the
    # starvation the tickets exist to prevent. An unreadable or corrupt mark restarts at zero
    # rather than killing the script mid-ticket, which would leave an unclaimable one behind.
    n=$(cat "$Q/seq" 2>/dev/null)
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    # The mark is the primary source, but it is one file and files are lost. Floor the number at
    # one past the highest ticket in the line as well, so a lost mark cannot restart at zero and
    # put this arrival ahead of everyone already waiting.
    for d in "$TICKETS"/*/; do
      [ -d "$d" ] || continue
      b="$(basename "$d")"
      case "$b" in ''|*[!0-9]*) continue ;; esac
      [ "$((10#$b + 1))" -gt "$n" ] && n=$((10#$b + 1))
    done
    while ! mkdir "$TICKETS/$(printf %04d "$n")" 2>/dev/null; do n=$((n+1)); done
    t="$TICKETS/$(printf %04d "$n")"
    touch "$t/alive"          # heartbeat first: an unheartbeaten ticket is a reap candidate
    echo "$spec" > "$t/spec"
    my_branch > "$t/branch"
    # Written through a temp file: `> "$Q/seq"` truncates before it writes, and a peer reading
    # in that window gets an empty mark and starts again from zero.
    printf '%s\n' "$((n+1))" > "$Q/seq.$$" && mv -f "$Q/seq.$$" "$Q/seq"
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
  local spec="$1" out branch
  # The lock records the branch it covers and pre-push compares against it, so a lock taken from
  # outside a worktree would name no branch and would refuse its own holder's push.
  branch="$(my_branch)"
  [ -n "$branch" ] || {
    echo "REFUSED — run this from your worktree, on the branch you are about to push."; return 1; }
  out="$(cmd_turn "$spec")" || { echo "BUSY — $out"; return 1; }
  # mkdir IS the atomicity: it either creates or fails, with no window between the two. A
  # test-then-create has a gap, and agents polling on similar cadences land in it.
  if ! mkdir "$LOCK" 2>/dev/null; then
    # Already ours means this is a retry, not a race — `turn` reports READY to the holder, so a
    # turn-then-acquire loop would otherwise spin forever against its own lock.
    [ "$(holder_field spec)" = "$spec" ] && { echo "ACQUIRED (already yours)"; return 0; }
    echo "BUSY — lost the race to [$(holder_field spec)]"; return 1
  fi
  { printf 'spec %s\n'   "$spec"
    printf 'branch %s\n' "$branch"
    printf 'since %s\n'  "$(now)"; } > "$LOCK/holder"
  note "$spec ACQUIRED the lock on $branch"
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
    echo "LOCK: [$(holder_field spec) on $(holder_field branch)] — held $(age "$LOCK")s"
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
  if prs="$(all_prs)"; then
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
