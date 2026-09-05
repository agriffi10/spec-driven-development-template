# Several agents on one repo

**Several agents on one repo — the PR queue**

The default is one spec in flight (`spec-lifecycle.md`). When you deliberately run N sessions against one repo, each
in its own worktree, their *trees* never collide but the **remote still does**: two PRs open at once
means each is tested against a `main` the other is about to move, and a merge race turns a green PR
red for a reason neither agent caused. Serialising the remote while parallelising the work is the
whole idea, and the invariant is **one PR open at a time, taken in the order agents asked, with
`main` settled and green before the next**.

- **The queue lives outside every worktree and outside the repo.** A lock inside a worktree is
  invisible to peers; a lock inside the repo is a file that itself conflicts. `scripts/pr-queue/`
  holds the implementation; `install.sh` copies it to a shared directory under `$HOME` and points a
  `pre-push` wrapper at it. **Do not hand-roll the shell** — these checks are easy to get subtly
  wrong in a way that fails *open*, which is the one failure mode that matters.
- **Four commands, and the polling one is `turn`:** `ticket` gets in line, `turn` exits 0 when it is
  your turn *and* the remote is clear, `acquire` takes the lock, `release` drops it — on **every**
  exit path, including failure. Poll `turn`, never `acquire`; each `turn` call is also the heartbeat
  that keeps your place. A holder that stops is this design's one real failure.
- **The lock covers the whole PR lifecycle** — rebase, push, open, watch to green, merge, confirm
  `main` — not just the push. One ticket per PR, released between them, so a multi-PR spec does not
  hold the line for its whole duration.
- **The queue is not a review.** It is the last thing between an already-reviewed branch and the
  remote. The local gates and both diff reviews still come first, in that order.
- **Every remote check fails closed; enforcement fails open.** The lock only orders the agents that
  take it, so `turn` asks the remote directly too — and a `gh` that *errors* returns empty output,
  which reads as "no PRs open" unless you check the exit status. Enforcement is the opposite case:
  linked worktrees share `.git/hooks` through the common git dir, so the hook fires for sessions that
  never agreed to the queue, and blocking those would be worse than the problem it solves.
- **Brief each session explicitly** from `docs/templates/multi-agent-briefing.md`: its own worktree
  off fresh `origin/main`, who else is running and on what, the files two agents will both edit, and
  that a rebase conflict is never resolved by discarding a peer's work. An unbriefed session does the
  reasonable thing for a session working alone, which is exactly what breaks a parallel run.

Full protocol, configuration and the stale-entry rules: `scripts/pr-queue/PROTOCOL.md`.
