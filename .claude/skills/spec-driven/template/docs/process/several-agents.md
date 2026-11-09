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

A session told to build an arc **orchestrates** it and builds none of the specs itself: it starts a
new build session per spec, and the instruction to build the arc is the instruction to build each of
its specs (`spec-lifecycle.md`), so it does not ask again between them. An arc run is a multi-agent
run from its first session, so install the PR queue before starting one, and brief every session
from `docs/templates/multi-agent-briefing.md`, queue section included.

- **Start every ready spec, without asking — at the outset and again each time a spec lands.** A spec
  is ready when it is `Draft` on `origin/main` (the status a spec takes once reviewed, `spec-lifecycle.md`),
  `spec-lint` reports no failure for it there, and every earlier spec in `arc_order` that it is not
  independent of has landed. With no independent specs this is one session at a time, in
  `arc_order`. Start every ready spec before stopping to ask about one that is not.
- **Two specs are independent** when neither needs the other's result, whether through `depends_on`
  or through something the earlier one builds, and they touch different source files. The files every
  completion ritual edits (the generated indexes, `CLAUDE.md`'s `## Specs`, the component inventory)
  do not count; name them in each briefing's *Files you and a peer will both touch*. Arcs can carry
  dependencies the frontmatter does not name, so when independence is not clear, chain them.
- **Landed is checked, never taken from a report.** After `git fetch origin`: the spec reads
  `Completed` on `origin/main` (`git show origin/main:<spec path>`), every PR its session named is
  merged, `main` is green at a head that contains them, and the spec holds neither the queue lock nor
  a ticket. A spec already `Completed` when the orchestrator starts counts as landed. A turn-end note
  that reports progress (a plan drafted, a review running) is not a finish, so nothing starts on one.
- **Check for a landing whenever a session it started ends a turn.** Where the harness does not
  report that, poll `origin/main` for the spec's status rather than end the orchestrator's own turn:
  an orchestrator that goes quiet with sessions running is the stall this rule exists to prevent.
- **Archive each finished session in the step that verifies its landing,** before starting the next,
  wherever the harness can archive sessions. That covers every session the orchestrator started, a
  fix or a review session as much as a build. A session idle partway through its work, or one
  waiting on an answer, is not finished.
- **Stop the chain and ask the human** when:
  - a session ends blocked, or ends with its spec not landed by the check above;
  - a session is waiting on the human's answer: relay its question verbatim;
  - `main` is red: start nothing until it is green again, and ask before the chain resumes. The
    session whose merge turned it red fixes it (`CLAUDE.md`); start a fix session only if that one
    has ended;
  - the next spec is `In Progress` from a session this orchestrator did not start (name its branch,
    its PR and any queue lock it holds), is neither `Draft` nor `Completed`, fails `spec-lint`, or
    depends on a spec outside the arc that is not `Completed`.
- **When the arc's last spec lands,** archive its session and report the arc done to the human,
  with the lessons its sessions reported.
