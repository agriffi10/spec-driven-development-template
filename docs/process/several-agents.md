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
- **The lock covers the whole PR lifecycle** — fetch, rebase, re-run your gates, push, open, watch
  to green, merge, confirm `main` — not just the push. The fetch is inside the lock because the wait
  is when peers merge. One ticket per PR, released between them, so a multi-PR spec does not
  hold the line for its whole duration.
- **The queue is not a review.** It is the last thing between an already-reviewed branch and the
  remote. The local gates and both diff reviews still come first, in that order.
- **Every remote check fails closed; enforcement fails open on CONSENT and closed on EVIDENCE.**
  The lock only orders the agents that take it, so `turn` asks the remote directly too — and a `gh`
  that *errors* returns empty output, which reads as "no PRs open" unless you check the exit status.
  Consent is the opposite case: linked worktrees share `.git/hooks` through the common git dir, so
  the hook fires for sessions that never agreed to the queue, and blocking those would be worse than
  the problem it solves — a branch outside the pattern pushes freely. But for a branch the hook does
  police, a remote it could not read is never read as "your base is current".
- **The hook checks your base, not just your lock.** It refuses a push whose commits do not contain
  the remote's current `main`, because the queue *guarantees* a wait during which peers merge. Prose
  told sessions to rebase for a long time and nothing checked; `scripts/pr-queue-test.sh` is the
  corpus that keeps the check honest.
- **Brief each session explicitly** from `docs/templates/multi-agent-briefing.md`: its own worktree
  off fresh `origin/main`, who else is running and on what, the files two agents will both edit, and
  that a rebase conflict is never resolved by discarding a peer's work. An unbriefed session does the
  reasonable thing for a session working alone, which is exactly what breaks a parallel run.

Full protocol, configuration and the stale-entry rules: `scripts/pr-queue/PROTOCOL.md`.

**Running an arc through — one build session per spec**

When one session orchestrates an arc, starting a build session per spec, the instruction to build
the arc is the instruction to build each of its specs in turn (`spec-lifecycle.md`). The orchestrator
does not ask again between them.

- **Start the next spec's session as soon as the last one has landed, without asking.** The next
  spec is the next in `arc_order`, and its session is a new one, briefed like the first.
- **Landed is checked, never taken from a report.** The PR is merged, `main` is green on the merge
  commit, the queue lock is released, and the spec is `Completed` on `origin/main`. The session's own
  account of its finish is not that proof, and a turn-end note that reports progress (a plan drafted,
  a review running) is not a finish at all, so nothing starts on one.
- **Independent specs may build in parallel, each in its own session; the rest chain one at a time.**
  Two specs are independent when they touch different files and neither needs the other's result,
  whether through `depends_on` or through something the earlier one builds. Arcs can carry
  dependencies the frontmatter does not name, so when independence is not clear, chain them. The
  queue still serialises their PRs.
- **Archive a finished session in the step that verifies its landing,** before starting the next one,
  wherever the harness can archive sessions. A session idle partway through its work, or one waiting
  on an answer, is not finished.
- **Brief each new session** from `docs/templates/multi-agent-briefing.md`, including the lessons the
  previous spec left.
- **Stop the chain and ask the human** if a session ends blocked, `main` is red, or the next spec is
  not `Draft`.
