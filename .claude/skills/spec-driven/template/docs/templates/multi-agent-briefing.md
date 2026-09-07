# Launch briefing — one agent in a multi-agent run

Fill one of these per session before launching several agents against this repo at once, and paste it
as that session's first message. The queue it names is set up by `scripts/pr-queue/install.sh`; the
rules it enforces are in `scripts/pr-queue/PROTOCOL.md`.

A session that is not told these things will do the reasonable thing for a session working alone —
branch in the shared checkout, push when its own gates are green — and that is exactly what breaks a
parallel run.

---

You are building **SPEC-XXX** in a run with [N] other agent sessions against one repo.

**Your worktree.** Work in your own worktree, created off fresh `origin/main`. Fetch first: `origin/main`
is a local ref, only as fresh as your last fetch, so branching off it without fetching starts you on
whatever `main` was the last time anyone looked — and the command below will not complain.

```
git fetch origin
git worktree add [path]/wt-spec-XXX -b spec-XXX/[short-name] origin/main
```

Never work in the shared checkout, never switch, reset or checkout a branch you did not create there,
and never delete or force-push a peer's branch. Fetch again and rebase onto `origin/main` before you
push — `main` will have moved while you worked, and only a fetch tells you how far. Under the queue
below, that rebase belongs *after* you take the lock, not before.

**Who else is running.** [One line per peer: session, spec, branch. "You are the only one" is also an
answer, and a useful one.]

**Files you and a peer will both touch.** [List them — the always-loaded `CLAUDE.md`, an index, a
shared module. Name them even when you think the overlap is small.] These will conflict at rebase.
Resolve by **keeping both changes**; never resolve a conflict by discarding a peer's work, and if the
right resolution is not obvious, stop and escalate rather than guess.

**Your gates come first, and the queue is last.** In order: the formatter, linter, type-check and
tests green locally, plus `sh scripts/spec-lint.sh`, `sh scripts/docs-lint.sh` and whatever CI will run
on the branch — that list is a floor, not the set; then the fresh-context diff reviews (`docs/process/reviewer-contract.md`); *then* get in line.
The queue serialises the remote — it is not a review, and it does not replace one.

**The queue.** One PR open on the remote at a time, taken in the order agents asked:

```
[queue-dir]/queue.sh ticket  SPEC-XXX     # get in line — when ready to push, not before
[queue-dir]/queue.sh turn    SPEC-XXX     # poll until it exits 0 (Monitor's until-loop, not sleep)
[queue-dir]/queue.sh acquire SPEC-XXX     # take the lock — from your worktree, on your branch
[queue-dir]/queue.sh release SPEC-XXX     # on EVERY exit path, including failure and abandonment
```

The lock covers the whole PR lifecycle — fetch, rebase, re-run your gates, push, open, watch to green
keyed on the head sha, merge, confirm `main` went green — not just the push. The fetch is *inside* the
lock because the wait is exactly when peers merge: rebase before you get in line and you push a base
that went stale while you queued, with every remote check still green. The gates run again for the
same reason — the rebase pulls in the peer work you were told above to expect conflicts from, and your
reviews closed against the base you had before it. The `pre-push` hook refuses a push that does not
contain the remote's current `main`, so a forgotten fetch costs you a refusal and not a stale PR.
Full protocol: `[queue-dir]/PROTOCOL.md`. One
ticket per PR: if your spec needs several, release between them so the others interleave. If `turn` reports the trunk `IS RED`, stop and
escalate; a red `main` is fixed before anything else merges.

**Escalate, don't improvise.** [Name who to escalate to and how.] A product-changing or ambiguous
call, a conflict you cannot resolve without discarding someone's work, and a red `main` all stop the
session — the reversible technical calls are still yours to make.
