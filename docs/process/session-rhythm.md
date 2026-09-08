# The session rhythm

This is the operating loop, start to finish. It loads with `CLAUDE.md` at launch, so it is read every session by mechanism.
**If this file and CLAUDE.md ever disagree, CLAUDE.md wins** — fix the drift here in the same
session you notice it (two hand-synced copies of one procedure is how numbering and staleness bugs
happen).

**Start of session**
1. Read CLAUDE.md, then the **current** spec in full. Don't infer scope from a prior conversation —
   read the spec file as it exists now.
2. Skim `component-inventory.md` for reuse; pull only the `architecture.md` section / dependency
   delivery-doc you actually need.
3. Confirm CI is green on `main`. Investigate failures before building.
4. **Branch from fresh `main`** — `git fetch origin` first, then branch off `origin/main` and not
   off your local `main`. The fetch moves `origin/main` and never touches the local branch, so
   branching off `main` after a fetch still starts you wherever you last pulled, exits 0, and reads
   as compliance. In a multi-agent run, cut your **own worktree** off `origin/main`, never the
   shared checkout and never a peer's branch (`several-agents.md`) — then set the spec header's
   `Status: In Progress` plus its `INDEX.md` row in the same commit — that transition is what makes
   "exactly one spec in flight" (`spec-lifecycle.md`) legible to the next session, and nothing gates
   it, so it is missed by being skipped rather than by failing.
5. **Generate and validate a plan before writing code.** Turn the spec's Implementation Phases into a
   concrete implementation plan, then validate it against the spec — every FR + acceptance criterion is
   covered, reuse from `component-inventory.md` is used, and nothing out of scope crept in. The plan —
   not per-phase checkpoints baked into the spec — is what gates the work.
6. **Put the plan through the reviewer gate before the first line of code** (`reviewer-contract.md`).
   A plan is reviewed for the same reason a PR is: the author cannot see what they assumed.
7. **Put the PR grouping through the same gate**, before the first push. Group consecutive phases
   into as few PRs as the dependencies allow — a phase is a unit of work, not a unit of PR, and the
   useful boundaries are inert-vs-live, either side of a switchover, a deletion following its last
   caller, and infrastructure that must apply before what depends on it.

**These two reviews are the only ones that gate the START of the build**, and once the plan and the
grouping have each been answered, the build runs to completion without checking in. The user
confirmed the work when they set the spec going; a per-phase check-in re-asks a question already
answered, and on a twelve-phase spec it asks it twelve times. This does **not** retire the diff
review — that one gates the push, at the other end of the build, and it is blocking too (`reviewer-contract.md`). Four reviews stand between a spec going In Progress and its PR merging:
one on the plan before the first line of code, one on the PR grouping, and two on the diff — all
four before the first push.

**During the build — one spec, in phases**
- Every file-changing task is done on its **own branch** and opened as a **PR** — automatically, without
  waiting to be asked. Never commit to `main` directly.
- **The diff reviews run BEFORE the push, not before the merge — and there are two of them.** Commit
  locally, run the gates, send the diff to **two** fresh-context reviewers in **different frames**,
  fix or explicitly reject every finding — *then* push and open the PR. Pushing first and reviewing
  after inverts the gate: the branch is already public, the fixes
  arrive as follow-up commits, and the review reads as commentary on something that has already
  happened rather than as the thing that decides whether it should. Rotating the frame (`reviewer-contract.md`) happens
  in the same window. A push is the point of no return for the review, the same way the merge is the
  point of no return for CI. **Green CI is not a review** — it cannot see a test that passes against
  the bug it claims to catch, a lock taken in the wrong order, or an acceptance criterion ticked with
  no evidence.
- Before pushing, run the project's **formatter, linter, typecheck and unit tests** locally and get
  them green. These quality gates are a pre-push step — don't push red and leave CI to discover it.
  **`sh scripts/docs-lint.sh` is in that set and nothing in CI runs it** — plus
  `sh scripts/docs-lint-test.sh` or `sh scripts/spec-lint-test.sh` whenever that linter itself changed, and
  `sh scripts/pr-queue-test.sh` whenever the queue or its hook changed, and
  `sh scripts/pr-queue/install-test.sh` whenever its installer changed.
- **The gates a document names are a floor, not the set — before every push, also run locally
  whatever CI will run on the branch.** A gate no list names is the one that goes unrun, and green
  from the named gates says nothing about it. Read `.github/workflows/` for the jobs that will
  actually run, not just this list — including after a rebase, when a job can newly go red on work
  that was green before `main` moved.
- Work the **reviewed** plan's phases in order, **straight through to completion**. Summarize a phase
  in passing where it is worth saying, but do not end the turn on it — a summary that ends the turn
  *is* a request for approval, whatever its wording says, and so is a list of options written out in
  prose — when a decision genuinely needs the human, ask it (the triage below says how). Re-review the plan only if the phase
  changed it — a phase that revises the plan has produced a new artifact, and it goes through the
  gate as one. A spec revised mid-build does this from the other side: if a phase now delivers a
  requirement the spec no longer carries, that plan is a new artifact too.
- **An acceptance criterion that cannot settle before the push does not pass the pre-push review —
  it is recorded as owed.** A criterion closing "against a green CI run" is undecidable while the
  branch is still local, and the failure mode is a reviewer ticking it vacuously, which is the exact
  defect the spec review exists to catch. Name it in the PR body as owed, settle it on the green run,
  and do not merge until it is settled. If a spec has several of these, that is the dependency the PR
  grouping is for: the job lands in the PR before the one whose criteria depend on it.
- **Stop only for a question that genuinely needs an answer:** a product-changing or ambiguous call,
  a finding that changes scope, a phase discovering the plan was wrong. Reporting is not the same act
  as asking, and doing the first while intending the second is how the build stalls.
- Before writing code in a domain that has a rulebook (React, accessibility, …), route through
  `docs/best-practices/INDEX.md` and load only the relevant section(s). Apply the rules as you write;
  flag (don't silently break) any that conflict with existing code.
- Specs ship with **no Open Questions** — they're resolved during authoring (`authoring-a-spec.md`). An issue that emerges
  mid-build is triaged by *kind*, not parked — and the test for the kind is **what the wrong choice
  would cost**: a revert or a follow-up commit, decide; a product outcome the user would have to live
  with, ask:
  - **Reversible / technical** (naming, file layout, which helper to reuse, an obvious bug fix): just
    decide in-session and keep moving. If it changes scope or contradicts the spec, **update the spec**
    rather than leaving the divergence implicit.
  - **Product-changing / ambiguous** (anything that alters behavior the user would notice, or a call
    with no clearly-right answer): **stop and escalate to the human.** Don't silently pick — ask with
    the **question tool** (`AskUserQuestion`), the options as selections and the recommended one
    first, and go on with the answer; options written out in prose that end the turn are the same
    stop by another name.
    Auto-deciding these is how an autonomous run drifts away from what was actually wanted.
  - **The spec contradicting itself** (two FRs that cannot both hold): a spec defect, not a preference
    call, and the tie-break is evidence — implement **each** reading, run the suite, and record the
    verdict in the spec. One reading run to red settles nothing. `reviewer-contract.md` (*Adjudicating two FRs that cannot both hold*) carries the
    method, and the three outcomes that escalate instead of settling.

**Landing the spec — watch PRs and watch `main`**
- **The instruction to build the spec is the authorization for everything in this section.** Pushing
  the reviewed branch, opening the PR, watching it and merging it on green are the last steps of the
  build, not new decisions: do not stop to ask for them, and do not stop after announcing them — a
  session whose turn ends at "I'll open the PR" has not built the spec. What still stops the session
  is a product-changing call or a permission the harness refuses; say which, and ask with the
  question tool.
- **A branch reaches the remote already reviewed.** The gate above is the precondition for the push,
  so a PR opens carrying work whose findings are already fixed or answered. If a review round happens
  after a push anyway — a late finding, a rotated frame, a reviewer that ran long — its fixes are
  committed and reviewed locally before the next push, rather than each one going up as it lands.
- **Every PR is watched to completion and merged as soon as CI is green** — never open a PR and walk
  away. A spec's PR merges only on green.
- **Key the watch on the current head sha, never a bare `gh pr checks --watch`** — it can exit clean
  against the **previous** commit's checks, and a hand-written shell condition can invert and print
  "settled" while a job is still running. Both report a green that is not there.
  `gh pr view <n> --json headRefOid,statusCheckRollup` returns the sha and the checks against it in
  one call, and the shipped allow-list covers it where `gh api` is not.
- **`main` is always watched.** After any merge, confirm `main`'s build went green. If `main` fails,
  **diagnose immediately and fix it with a new PR** — a red `main` is the top priority and blocks
  starting the next spec.
- **Re-verify `main` is green** before starting the next spec (land before starting the next).
- Then run the completion ritual (`completion-ritual.md`).
