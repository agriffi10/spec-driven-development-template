# The PR queue — one PR on the remote at a time, taken in order

Several agent sessions build different specs against one repo. Each works in its own worktree, so
their trees never collide — but the remote is still shared. Two PRs open at once means each is
tested against a `main` the other is about to move, and a merge race turns a green PR red for a
reason neither agent caused. **Serialising the remote while parallelising the work is the whole
idea.**

**The invariant: one PR open at a time, taken in the order agents asked. `main` settled and green
before the next.**

`queue.sh` beside this file implements it. Do not hand-roll the shell — these checks are easy to get
subtly wrong in a way that fails *open*, which is the one failure mode that matters here.

## Before you get in line

Your own gates come first: formatter, linter, type-check, unit tests, `sh scripts/spec-lint.sh`,
`sh scripts/docs-lint.sh`, whatever CI will run on the branch (`.github/workflows/`), and the
fresh-context diff reviews — that list of gates is a floor, not the set. **The queue is the last thing between a reviewed branch and the remote, never a substitute
for the review.** Get in line when you are ready to push, not before — a ticket taken early holds up
everyone behind you while you are still writing code.

## The four commands

```
$Q/queue.sh ticket  SPEC-207     # get in line. Idempotent — asking twice keeps your place
$Q/queue.sh turn    SPEC-207     # exits 0 when it is your turn AND the remote is clear
$Q/queue.sh acquire SPEC-207     # take the lock. Exits 0 on ACQUIRED, 1 on BUSY
$Q/queue.sh release SPEC-207     # drop the lock and your ticket. Always exits 0
```

**Run `acquire` from your worktree, on the branch you are about to push.** The lock records that
branch and the hook compares against it, so a lock taken from anywhere else would refuse its own
holder's push; `acquire` refuses rather than let that happen — and refuses on the trunk outright,
because the hook never asks the trunk for a lock, so a lock stamped with it would cover nothing.

`turn` is what you poll. **Blocking `sleep` is unavailable in the agent's Bash tool** — poll with the
Monitor tool's until-loop on `queue.sh turn SPEC-XXX`, every couple of minutes. Each call is also
your heartbeat: a waiter that stops polling for 30 minutes loses its place, which is what stops a
dead session from blocking the line forever. Do not poll `acquire` — poll `turn`, then `acquire` once
it exits 0. And **`cd` into the worktree you built the spec in and `acquire` from there in the
SAME command** — the agent's Bash tool resets the working directory between calls, so a `cd` in
one call and an `acquire` in the next acquires from the wrong tree.

`turn` says which refusal it is: someone is ahead of you, the lock is held, a **non-draft** PR is
open on the remote, `main` is unsettled, or a check could not run. Two need a different response from waiting.
**If it reports the trunk `IS RED`, stop and escalate to the human** — a red `main` is fixed before
anything else merges. If it says `NO_TICKET` (exit **3**, not 1) you never got in line; run `ticket`.
Every other refusal exits 1 and means keep polling.

**A DRAFT DOES NOT BLOCK.** The remote check stands in for "another agent is mid-turn", and a draft
is the one open PR explicitly *not* ready to merge — it can sit for hours by design. Counting one
starves every agent that obeys this queue, while agents that never took a ticket push straight past
it. Measured in `s3-upload-portal`, and recorded in that queue's own log: ticket
0017 took its place at 2026-09-01T21:40:09Z and did not acquire until 2026-09-02T00:21:55Z — 2h41m,
as the only waiter, with the lock free throughout. What it was behind is recorded in that repo's
protocol rather than its log: a draft titled "DO NOT MERGE YET" **and five PRs opened by sessions
that never took a ticket**. Keep the second half — the log cannot show which of the two held it up,
so the wait is not evidence that drafts alone caused it. A non-draft PR still blocks, bot-authored
ones included: those are intended to merge, so waiting for them is the point.

**Known limit, so a clear `turn` is not read as more than it is:** this queue orders only the agents
that use it. If sessions push without taking tickets, the remote is rarely clear and a waiter can
still starve. The remote check narrows that window; it does not close it.

`queue.sh status` shows the holder, the line, and what is actually open on the remote — **including
drafts, labelled `DRAFT (ignored by the queue)`**, so a clear `turn` beside a visibly open draft
never looks like a bug in the queue.

## What the lock covers

The **whole** PR lifecycle, not just the push: `git fetch origin` and rebase onto the ref you just
fetched — `main` moves under you while you wait for the lock and while you hold it, and an
unfetched `origin/main` cannot show you that — re-run your gates, push, open the PR, watch it to green
**keyed on the head sha**, merge, then confirm `main` itself went green. Then release.

If your spec needs more than one PR, take a ticket per PR and release between them, so the others
interleave rather than waiting out your whole spec.

**The hook enforces the fetch, so the rebase is not on your memory.** `pre-push` refuses a push whose
commits do not contain the remote's current `main`, and says so with the remedy. It reads the remote
with `ls-remote` and never fetches for you: fetching from a hook would move refs the other worktrees
share. A branch outside the enforced pattern is not policed at all, but a policed branch whose remote
could not be read is refused rather than waved through — consent fails open, evidence fails closed.
A remote that has branches but not the trunk named in `main-branch` is the same case: that is a
queue pointed at a trunk which does not exist, and reading it as "empty repo, nothing to be behind"
would disable the check for the whole repository without saying so.
`PR_QUEUE_BYPASS=1` overrides both refusals. The corpus for those checks is
`scripts/pr-queue-test.sh` in the repo, which drives real pushes and asserts each refusal's text,
then breaks each check in a copy of the hook and asserts its cases go red.

## Release on every exit path

Including failure, including abandonment, including "I am stuck and asking the human". A lock held by
a session that has stopped is the one failure this design has — and the stale-lock rule below only
clears it after 90 minutes.

**Know what releasing early costs.** `turn` and `acquire` refuse while any non-draft PR is open and
neither exempts the caller's own, and `release` drops the ticket as well as the lock. A session that
releases *after* opening its PR therefore cannot simply resume: it re-enters the queue at the current
high-water mark, behind anyone who ticketed while it held the lock, and the first `turn` after a
release needs a fresh `ticket` before it means anything.

Release anyway when you stop. Not because it frees your peers — while your PR is open they wait
either way — but because the block then ends when the PR lands instead of outliving your session, and
an abandoned lock clears only on the stale-entry timer below. What it costs is the rest of your own
lifecycle:

- **Merging needs no lock.** Green CI, then merge, confirm `main`, drop the ticket. The trunk is the
  one branch the hook never asks for a lock — a merge is a push of the trunk — though it still
  refuses a trunk pushed *backwards* over commits the remote has.
- **Every other push does**, `git push origin --delete <branch>` included: a session that does not
  hold the lock deleting the branch under review closes the very PR the lock protects. So delete
  your branch **before** `release`, or let the merge delete it — a deletion after you have
  released is refused against a free lock. A red CI needing a fix push is the same case;
  `PR_QUEUE_BYPASS=1` is the way through, and the section below asks you to say you used it. What counts as a participating branch is `enforce-branches` and
  nothing else. The default is every branch, and `install.sh` prints how many of the repo's
  branches the live setting matches — the template's earlier default matched neither `spec/…` nor
  `docs/…` and enforced nothing in silence, which is why the count is printed rather than assumed.
- **A draft PR breaks the safety of releasing at all.** Drafts are filtered out of the open-PR check,
  so a peer can acquire behind your draft and open a second PR. They are counted by the stale-lock
  reaper, though — deliberately, as evidence the holder lives — so a lock abandoned behind a draft is
  never broken by the timer, and a peer blocked by one has to escalate rather than wait. Keep the
  lock, or close the draft; having released with only a draft open, re-ticket and acquire at once —
  the queue will hand it back until a peer takes it.

Never close and reopen a PR to reclaim the lock: that discards the checks and the review trail to
work around a lock whose job is already done.

## What is enforced, and what is not

A `pre-push` hook refuses a push of any ref matching `enforce-branches` unless that branch holds the
lock, and refuses a push whose commits do not contain the remote's current trunk; `install.sh` sets
the pattern to **every branch**. It reads the refs git actually hands it on stdin rather than the
checked-out branch, so `git push origin spec-x/y` from somewhere else, and a `HEAD:refs/heads/spec-x/y`
refspec from a detached HEAD, are covered too. The branch it compares is always the **remote** one,
so `mine:main` is a push to the trunk however it is spelled locally.

**Do not narrow the pattern to a list of branch prefixes.** That was the first design and it fails
**open**, silently: one consumer enforced the prefixes of five specs, those specs closed, and the hook
then exited 0 for every branch anyone pushed while still looking installed; the template's own
default matched neither branch convention its consumers use. Nothing about a queue enforcing nothing
looks different from a queue enforcing everything.

Three things are exempt, each by what a pull request can come of it. A push to a remote that is
**not this checkout's origin** — a fork, a backup, a scratch repo — is exempt from both refusals:
this queue serialises one remote. The **trunk** is exempt from the lock, because merging is a push
of the trunk and a lock stamped with it would authorise nothing — but not from the freshness check,
so a trunk force-pushed backwards is still refused. A branch **deletion** is exempt from the
freshness check, because there is no commit to measure — but not from the lock, because a non-holder
deleting the branch under review closes the PR the lock exists to protect. A deletion of the
**trunk itself** is refused outright: it is the limit case of a trunk pushed backwards. The trunk's
two refusals run *ahead* of the pattern, because they guard the remote's integrity rather than the
queue's consent — narrowing the pattern never uncovers the trunk; only an empty pattern does. A
**tag** falls out for free: the hook only ever inspects `refs/heads/*`.

It still **fails open** wherever the *queue* is what is missing: an empty `enforce-branches`, a
deleted queue directory, an explicit `PR_QUEUE_BYPASS=1`. Linked worktrees share `.git/hooks` through
the common git dir, so this hook fires for **every** session on the checkout — including ones that
never agreed to the queue and have never heard of it — and blocking those would be a worse failure
than the one it prevents. The deleted-queue case is carried by the wrapper in `.git/hooks`, not by
the hook: the hook lives *inside* the queue directory, so a deleted queue deletes it too, and the
wrapper's `exec`-if-present is what lets the push through. It **fails closed** on evidence: a remote
it could not read, a trunk the remote does not have, and a pattern grep cannot compile are each a
refusal of their own, never "nothing to refuse". `PR_QUEUE_BYPASS=1 git push …` overrides everything;
if you need that, say so in your report.

**If the refusal names a lock you believe is yours**, read the branch on the holder line. A lock
acquired from the wrong directory records the wrong branch and then authorises nothing; re-running
`acquire` from the right worktree re-stamps it, and keeps your place. Reach for the bypass after
that, not before.

**A detached HEAD cannot hold a lock, and is refused a push.** `acquire` needs a branch to record,
so a detached worktree can take a ticket and never acquire, while every branch it pushes is
enforced. Create a branch and acquire from it; `PR_QUEUE_BYPASS=1` is the other way out and is worth
mentioning in your report if you take it.

That re-stamp is the one place `acquire` is not a no-op when you already hold the lock: it re-points
a live lock at whatever branch you are standing on. Two sessions sharing a ticket id can therefore
take the lock away from each other's push without either noticing, so **one id per session** is a
rule rather than a convention. Every re-stamp is logged to `$Q/log`.

The queue only orders the agents that use it, so `turn` also asks the remote itself — that is what
covers sessions outside the set. **Both remote checks fail closed.** The trap they are written
against: a `gh` invocation that *errors* returns empty output, and empty reads as "no PRs open". A
check that could not run is never evidence that it passed.

## Stale entries

A waiter that has not polled `turn` for 30 minutes is dropped from the line automatically; the
holder is exempt, because acquiring stops the polling and the lock deliberately covers far longer
than that. A lock whose holder is over 90 minutes old is broken **only** when there is also no open
PR and `main` is green — age alone is never enough. Both timeouts are `STALE_TICKET` and
`STALE_LOCK` at the top of `queue.sh`; change them there, and fix this paragraph in the same edit.

Ticket numbers come from a high-water mark and are floored at one past the highest ticket in the
line, so a freed slot is never handed to a newcomer while anyone is still waiting: reaping frees a
low number, and a new arrival taking it would land ahead of someone who has waited longer, which is
precisely the starvation the tickets prevent. (With the line empty and the mark lost, numbering does
restart from zero — there is nobody left to jump.) Both reaps are logged to `$Q/log`.

## Configuration

Single-value files in the queue directory, written by `install.sh` — `repo` and `main-branch` on
every run, `enforce-branches` only as the row below describes:

| File | What it holds |
|---|---|
| `repo` | The checkout the remote checks run from. |
| `main-branch` | The trunk branch name. `install.sh` reads it from `origin/HEAD`, then asks origin — or the checkout's only remote when there is no origin — then guesses `main`. |
| `enforce-branches` | ERE for the branches `pre-push` enforces against. `install.sh` writes `.` — every branch — only when the file is **absent or empty**; an existing pattern is KEPT, so **an upgrade must pass the regex explicitly** or it silently keeps whatever was there. The summary says which of the two happened, and how many local branches the live setting matches. A blank or uncompilable argument is refused before anything is copied. Empty or missing enforces nothing, silently, which is why narrowing it is the change to think twice about. |

`install-test.sh` beside `install.sh` is the corpus for the installer — the pattern states (default,
non-matching, blank, invalid, hand-emptied, kept), the fresh-clone silence case, the held-lock and
foreign-hook and other-queue refusals, and the remote-asked trunk — each asserting the text rather
than only the exit code. **A change to `install.sh` runs it**; it builds throwaway repos under
`$TMPDIR` and never touches the checkout it is run from, which `install.sh` itself cannot claim:
`PR_QUEUE_DIR` relocates the queue but not the hook.

Two environment variables override the files, for a one-off: `PR_QUEUE_DIR` tells `install.sh` where
to put the queue, and `PR_QUEUE_REPO` overrides `repo` for a single `queue.sh` invocation.

Three optional **executables** replace the built-in GitHub checks — the seam for a project whose CI
is not GitHub Actions, or whose repo is not on GitHub:

| Executable | Contract |
|---|---|
| `open-prs` | Prints the open **non-draft** PRs, empty for none. **Non-zero exit means the check itself failed**, and the queue waits rather than assuming the remote is clear. |
| `all-prs` | Prints **every** open PR including drafts, for `status` only — never for gating. Optional: if absent, `all-prs` falls back to `open-prs`, and drafts simply go unlisted. |
| `main-green` | Exit `0` green · `1` RED · `2` building/unsettled · `3` the check could not run. Only `0` lets the queue move. |

> **If you wrote an `open-prs` override before drafts were exempted, update it.** One that still
> lists drafts silently reinstates draft-blocking — and `status`, which reads `all-prs`, will label
> the same PR `DRAFT (ignored by the queue)` while `turn` refuses because of it. The queue does not
> and cannot detect this: an override is opaque by design.

The built-in `main-green` reads the GitHub Actions runs recorded for `main`'s head sha. It waits
while any is incomplete, and while the repo has workflows but no run for that sha yet; a run that
concluded anything other than success/skipped/neutral is **RED**, which stops the agent rather than
making it wait. Its known limit: it can only judge the runs that **exist**, so
in the seconds between one workflow being created and another it can see a green subset. A project
with its own CI watcher should install it here rather than rely on that.

## Changing the protocol mid-flight

If you strengthen this while agents are running, they are split across two versions. Keep the lock
primitive (`mkdir`) and the holder-file format identical so both versions still exclude each other,
put a dated "this changed" note at the top of this file, and **message the running sessions
directly** rather than waiting for them to re-read it. `install.sh` refuses to upgrade a queue whose
lock is held, stages the new files and renames them into place, and keeps the previous generation
in `.previous/` beside the queue — so an upgrade is an atomic swap with something to go back to,
never a `cp` over a script a peer is executing.
