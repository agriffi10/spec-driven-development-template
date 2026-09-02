# The Spec-Driven Development Process

How work gets done in this repo. `CLAUDE.md` carries the terse, always-loaded rules; this doc is the
fuller **method** they point to, and it is the contract CLAUDE.md only summarises. **Read it at the
start of every session, before any other doc** — CLAUDE.md's Session Workflow says the same. (Both
statements are cheap to write and neither is checked, so keep them agreeing; see §5.)

Goal: each feature is **specified before it's built**, built in **reviewable phases** off a
**reviewed plan**, landed as **as few PRs on green CI as the dependencies allow**, and recorded in
**lean, layered docs** so the next session starts cheap.

---

## 1. Where truth lives (and why it's layered)

The docs are tiered by how often they're loaded. Keep each tier in its lane — the always-loaded tier
is deliberately small and **must not regrow**.

| Tier | File(s) | Loaded | Authoritative for |
|---|---|---|---|
| Always | `CLAUDE.md` | every session | conventions, key decisions, session workflow |
| Status | `docs/specs/INDEX.md` + each spec header | on demand | spec **status** (one row per spec) |
| The work | `docs/specs/SPEC-XXX-*.md` | the one you're building | requirements + phases |
| Why | `docs/architecture.md` | the *section* you need | design rationale + Known Constraints |
| Decisions | `docs/decisions.md` | the *entry* for your area | settled decisions in full + reversal markers |
| Reuse | `docs/component-inventory.md` | skim for reuse | modules/services/components already built |
| Rulebooks | `docs/best-practices/INDEX.md` → domain doc | the section(s) you need | domain coding rules (React, a11y, …) |
| History | `docs/spec-delivery/SPEC-XXX-*.md` | when a dependency points to one | what a past spec shipped |
| Method | `docs/process.md` (this file) | every session | how we work — the method behind CLAUDE.md's summary |

**Context discipline (session-start token cost matters):**
- Read **only the current spec** in full.
- **Never** read `architecture.md` or delivery docs whole — pull the one section you need.
- Delegate *dependency* delivery-doc reading to a subagent brief rather than loading it into the main
  loop.

---

## 2. The spec lifecycle

Specs move **Draft → In Progress → Completed** (the status in each spec's header is authoritative; the
`INDEX.md` row mirrors it).

- **Draft** — written, **reviewed by a fresh-context reviewer (§3, *The reviewer contract*)** and
  refined, but **do not build until told.** Specs are often authored well ahead of implementation. A
  Draft spec sitting in the repo is not a signal to start it. A spec is not Draft-ready while it still
  has unresolved questions (see §4), and a spec that has not been through the gate is not Draft-ready,
  whatever its header says.
- **In Progress** — exactly one spec at a time is in flight. Set when you branch to build it.
  The exception is a deliberate **multi-agent run**, where several sessions build different specs
  at once; what stays serial there is the *remote*, not the work (§3, *Several agents on one
  repo*). Running several by accident — two sessions that each think they are alone — is the
  thing this rule exists to prevent.
- **Completed** — merged on green CI, delivery doc written (see §5).

**Arcs.** Related specs can be grouped into *arcs* with an explicit **build order** documented in
`INDEX.md`. Grouping is a choice; recording the order of a **size split** (§4) is not — a spec cut
for size always leaves an arc entry behind, so keep the section even if you group nothing else.
Build in that order; arcs can have non-obvious dependencies. If arc narrative outgrows an
`INDEX.md` row, move it to a `docs/specs/ARCS.md` with **one `##` heading per arc** and a TOC at the
top, so a session can load only the arc it's in. Structure it that way from the first entry —
retrofitting headings onto grown prose is far more work. The heading names the **arc**, never its
status: status rots the day the next spec lands, and it belongs in the arc's body or its `INDEX.md`
rows (see §5). An arc is also what an over-scoped spec *becomes*: a spec that runs past the size
ceiling in §4 is cured by a second spec beside it and an arc entry holding the order, rather than
by a longer spec.

---

## 3. The session rhythm

This is the operating loop, start to finish. CLAUDE.md's *Session Workflow* is the condensed version.
**If this section and CLAUDE.md ever disagree, CLAUDE.md wins** — fix the drift here in the same
session you notice it (two hand-synced copies of one procedure is how numbering and staleness bugs
happen).

**Start of session**
1. Read CLAUDE.md, then the **current** spec in full. Don't infer scope from a prior conversation —
   read the spec file as it exists now.
2. Skim `component-inventory.md` for reuse; pull only the `architecture.md` section / dependency
   delivery-doc you actually need.
3. Confirm CI is green on `main`. Investigate failures before building.
4. **Branch from fresh `main`** — and in a multi-agent run, in your **own worktree** off
   `origin/main`, never the shared checkout and never a peer's branch (§3, *Several agents on one
   repo*) — then set the spec header's `Status: In Progress` plus its `INDEX.md`
   row in the same commit — that transition is what makes "exactly one spec in flight" (§2) legible
   to the next session, and nothing gates it, so it is missed by being skipped rather than by failing.
5. **Generate and validate a plan before writing code.** Turn the spec's Implementation Phases into a
   concrete implementation plan, then validate it against the spec — every FR + acceptance criterion is
   covered, reuse from `component-inventory.md` is used, and nothing out of scope crept in. The plan —
   not per-phase checkpoints baked into the spec — is what gates the work.
6. **Put the plan through the reviewer gate before the first line of code** (*The reviewer contract*,
   below). A plan is reviewed for the same reason a PR is: the author cannot see what they assumed.
7. **Put the PR grouping through the same gate**, before the first push. Group consecutive phases
   into as few PRs as the dependencies allow — a phase is a unit of work, not a unit of PR, and the
   useful boundaries are inert-vs-live, either side of a switchover, a deletion following its last
   caller, and infrastructure that must apply before what depends on it.

**These two reviews are the only ones that gate the START of the build**, and once the plan and the
grouping have each been answered, the build runs to completion without checking in. The user
confirmed the work when they set the spec going; a per-phase check-in re-asks a question already
answered, and on a twelve-phase spec it asks it twelve times. This does **not** retire the diff
review — that one gates the push, at the other end of the build, and it is blocking too (*The
reviewer contract*, below). Four reviews stand between a spec going In Progress and its PR merging:
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
  happened rather than as the thing that decides whether it should. Rotating the frame (below) happens
  in the same window. A push is the point of no return for the review, the same way the merge is the
  point of no return for CI. **Green CI is not a review** — it cannot see a test that passes against
  the bug it claims to catch, a lock taken in the wrong order, or an acceptance criterion ticked with
  no evidence.
- Before pushing, run the project's **formatter, linter, typecheck and unit tests** locally and get
  them green. These quality gates are a pre-push step — don't push red and leave CI to discover it.
- Work the **reviewed** plan's phases in order, **straight through to completion**. Summarize a phase
  in passing where it is worth saying, but do not end the turn on it — a summary that ends the turn
  *is* a request for approval, whatever its wording says. Re-review the plan only if the phase
  changed it — a phase that revises the plan has produced a new artifact, and it goes through the
  gate as one.
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
- Specs ship with **no Open Questions** — they're resolved during authoring (§4). An issue that emerges
  mid-build is triaged by *kind*, not parked:
  - **Reversible / technical** (naming, file layout, which helper to reuse, an obvious bug fix): just
    decide in-session and keep moving. If it changes scope or contradicts the spec, **update the spec**
    rather than leaving the divergence implicit.
  - **Product-changing / ambiguous** (anything that alters behavior the user would notice, or a call
    with no clearly-right answer): **stop and escalate to the human.** Don't silently pick — surface the
    options with a recommendation. Auto-deciding these is how an autonomous run drifts away from what
    was actually wanted.

**The reviewer contract — three artifacts, one gate**

Nothing reaches the next stage on its author's own judgement. A **spec**, an **implementation plan**
and a **diff** each go to a reviewer in a **fresh context** — a subagent or a new session, never the
context that produced the artifact. An author reviewing their own work assumes its output was
intended and rubber-stamps it; that is as true of a plan as of code, and a wrong plan is the more
expensive one to leave *undetected*, because the code that follows will faithfully implement it.

**How many reviewers, and where.** **One** on the spec when it is written, **one** on the
implementation plan when the build actually starts, and **two** on the diff before it is pushed —
plus the narrow pass on the PR grouping below. The diff gets two because it is the **widest**
artifact and the last one before the branch goes public: a spec or a plan is one document a single
reader can hold whole, while a diff spans code, tests and config *and* the criteria they are
supposed to satisfy, and this method's own measured history (*Rotating the frame*, below) is that the
first differently-framed pass over a change finds a class the previous frame could not see. That
evidence argues for a **different frame**, not for the number two; two is the floor because one frame
is demonstrably not enough and a floor has to be a number.

The two are **two frames, not two rounds** — the same frame run twice buys wording — and they are not
free picks. One starts from the **change** and reads it against what it is supposed to satisfy; the
other starts from **something other than the change** — the system it lands in, or the document it
claims to implement. On a code diff those are: the spec's acceptance criteria plus the
`best-practices/` rules for the domains it touches, and a pass that **builds** the thing and runs the
suites rather than reading it. On a diff with no code in it — a spec, a plan, a docs change — they
are: the artifact against its own sources, and the artifact against every *other* place the same rule
is stated. Both land **before** the push; a review that only happens once the branch is public does
not count toward the two.

Every count here is a **floor**, not a cap, but the two floors work differently and should not be
read across. **On a diff**, two is a minimum before a push: a clean first review does not close the
gate, because "the reviewer found nothing" means nothing within the frame it was given, and the exit
rules below decide when to stop *above* two. **On a spec or a plan**, one review closes the gate — a
clean review there is an answer. What makes that count a floor is **re-entry**: a revised artifact is
a new artifact and goes back through the gate as one, which is why a phase that rewrites the plan
sends the new plan through again.

- **The gate is blocking, and what it asks for is an answer, not a filing.** A spec is not
  Draft-ready, a plan does not start code, and a branch does not reach the remote, until every
  finding has been either **fixed** or **flagged** — said out loud, so the call is visible and can be
  argued with. A finding silently dropped is a finding that was not reviewed; a finding rejected in
  one sentence is a finding that was. **Write a rejection down only when it carries a lesson worth
  keeping** — then it belongs in the register or the spec, as reasoning, not as a paper trail.
- **The reviewer gets the artifact and its sources, never the author's reasoning.** For a spec: the
  spec file, its build-order entry in `INDEX.md`, the `architecture.md` sections and `decisions.md`
  entries it claims to follow, and the specs it depends on. For a plan: the plan, the spec, and
  `component-inventory.md`. For a diff: the diff, the spec's acceptance criteria, and the
  `best-practices/` rules for the domains it touches (route via their INDEX). For a **PR grouping**:
  the reviewed plan and the phase list, and nothing else — the question is only whether the split is
  the fewest the dependencies allow, and whether any boundary leaves `main` in a half-built state.
  Handing over the authoring rationale tells the reviewer what to conclude.
- **What each review is for.** A **spec** review asks: is every FR testable and binary; does any
  acceptance criterion pass vacuously; is anything in Out of Scope actually required by an FR; does it
  contradict a settled decision or silently supersede one without saying so; are there Open Questions
  wearing declarative clothes. A **plan** review asks: does every FR and acceptance criterion have a
  phase that delivers it; is existing reuse used rather than re-built; has out-of-scope work crept in;
  is a phase resting on a premise nobody has checked. A **diff** review checks the spec's acceptance
  criteria **and the relevant `best-practices/` rules** (route via its INDEX), not just "does it look
  fine" — plus the rules below.
- **Cap same-frame rounds at two, then rotate the frame** (next block). Applies to specs and plans as
  much as to code: a second round of the same reviewer on the same artifact converges on wording.
  Rotate instead — for a spec, a reviewer briefed only on the *dependencies* it claims, or one asked to
  build the thing from the spec alone and report what it could not determine; for a plan, one asked to
  find the phase that will be discovered impossible.
- **A reviewer finding is not an instruction.** The author decides. Rejecting one is ordinary and
  costs a sentence; the thing to avoid is deciding silently, because then nobody can tell a
  considered rejection from a finding that was never read. A fixed finding that was wrong is a
  silent regression, which is the same failure in the other direction.

**Rotating the frame — why round count is the wrong exit criterion**

Review rounds converge on the frame they are given, not on correctness. Measured on one spec
(2026-08-07): **eight** rounds of independent review — two on the spec, three on its revisions, three
on the code — after which the merged result still carried two defects, one of which was a regression
of a guarantee an earlier spec had shipped. Rounds 1–3 found design defects; rounds 4–8 increasingly
found wording. The *first* differently-framed pass afterwards found ~25 defects, several years old.

So the loop rotates the frame instead of adding rounds:

- **Cap same-frame review at two rounds.** After the second, switch frame rather than iterate:
  adversarial *execution*, whole-module fresh eyes (not the diff), or the frames your domain makes
  expensive to skip (concurrency, security, accessibility, data loss).
- **Exit on a new frame finding nothing**, not on the current frame converging. "The reviewer found
  nothing" means "nothing within the frame I gave it."
- **The exit rules govern the ceiling, never the floor.** "Never exit on a round count" is about when
  to *stop*; it does not license stopping below the counts in *The reviewer contract*. A diff still
  gets its two frames even when the first one comes back clean.
- **Every frame is entered at most twice, and when they are exhausted, stop.** One requirement ran to
  **eleven** rounds — six same-frame (the cap above, ignored five times over), then rotations that did
  find real holes. So the rule is not "stop sooner regardless": a *third* round in one frame is
  evidence the frame is exhausted, and the choice then is a **different** frame or the decision to
  ship. Rounds 5–8 all found defects in the lint added at round 4, never in the thing it guards: when
  consecutive rounds find defects in the *previous round's fix* rather than in the subject, the review
  has become its own subject.
- **When a change is a guard on a guard, bound it before starting.** A test that polices a rule is
  worth having; a test that polices the test that polices the rule is where those eleven rounds went.
  Decide up front what it may cost; if it exceeds that, record the residual exposure and merge — the
  exposure is usually smaller than the delay. Better still, ask whether the rule could be made
  unrepresentable instead of policed.
- **At least one pass must start from the system, not the diff.** Every diff-scoped review is
  structurally blind to a defect that predates the diff — and to the states the diff is never
  exercised in (a change verified only in the signed-in path says nothing about sign-in).
- **A review SAMPLES; when the risk is ABSENCE, enumerate instead.** Review is the right instrument
  for "is this new code correct" and a weak one for "what did we stop checking" — a reviewer reads
  what is there, and a deletion leaves nothing to read. Measured on a test-suite reduction in a
  project run this way: three fresh frames returned **4, then 7, then 17** findings, diverging
  rather than converging, because each sampled a population of hundreds. The mechanical sweep that
  answered the absence question completely — error codes raised vs error codes asserted — ran in
  seconds. **Before
  reviewing a change whose risk is what it removed, write the sweep that lists the whole
  population.**
- **Spot-check a negative claim before acting on it, and again before writing it down.** "Only
  documented on page X", "no test covers this", "nothing imports this file", "there is no scrubber"
  — each is a claim about an absence, and an absence is what a search proves badly. Verify it
  yourself whether a reviewer said it or you did. The asymmetry that makes this worth a rule: a
  wrong claim entering **code** has tests to catch it later, while one entering a spec, a register
  entry, a docstring or a commit message has nothing, and the next session reads it as settled. Two
  such claims shipped as source comments in one project and were believed for weeks — a "registry
  guard" a router advertised and did not have, and a credential "scrub" a config module named as the
  thing keeping tokens out of logs. Both were found by writing the test that assumed them.
- **A mechanical sweep REPORTS before it applies.** Print what it would change, read the list, then
  re-run with `--apply`, and check the result by diffing **test names** rather than a pass count. A
  classifier that looks right is routinely wrong at its edges: a sweep for unused module-level
  helpers classified a test framework's discovered classes as dead and would have deleted every test
  inside them — caught only because it printed first. A regex over source is the same hazard one
  level down; parse instead where a parser exists.
- **A verification method has a frame, exactly as a review does.** Three sweeps that all ask "is the
  old content still present" are one check run three times, however exhaustive each is — they cover the
  mechanical half of a change and say nothing about the half that was authored. Before trusting a
  verification, ask what question it asks, and whether anything asks a different one. Measured: a
  migration was proved lossless three ways while the freshly-written summaries of the moved material
  went unexamined, and contained a fabricated citation.
  Its stopping rule is the sweep's: stop when a fresh question would not change what you conclude.
- **A finding should carry a reproducing mutation, and the fix is verified by re-planting it.**
  Then fix-verification is mechanical and needs no second reviewer — which is what stops a review
  round spawning a review of its fixes. A frame only finds what its mutations probe, so a fix that
  satisfies a weak mutation can still be wrong.
- **A gate is not tested by running it on the thing it guards.** Running a linter over the repo's own
  files proves the files pass; it proves nothing about whether any check still fires, and a gate whose
  checks have gone quiet is indistinguishable from a healthy repo. Every gate owes a **fixture corpus**:
  one case per construct, asserting the specific **failure text** rather than the exit code, because a
  check that fails for the wrong reason gets "fixed" by changing the wrong thing. Include cases that
  assert **silence** — a corpus of only-failures cannot see a false positive, and false positives are
  a large share of what a gate gets wrong. Prove the corpus bites by defeating each check in turn and watching it redden.
  Measured: a doc linter took four rounds of fixes, three of which each opened a fresh escape while
  closing the previous one, and **not one was caught by CI** — the only thing CI ran was the linter
  against documents that happened to pass. Reviewers found most; the author found two mid-build; and
  the fixture corpus found two the moment it existed, which is the argument for it. Nothing reached
  `main`, because the branch happened not to merge in between.
- **One fixture per guard is not enough when the guard has more than one exit.** A check with two
  terminating conditions is satisfied by a fixture exercising either, so the mutant that breaks the
  other survives with the suite green. Count the ways a check can stop, and write that many cases.
- **Reasoning finds wording; execution finds defects.** Require a reproduction, not an argument.
  Passing review, passing unit tests and deploying successfully are three things that can all be true
  of code that fails on its first real invocation.
- **A spec touching lifecycle, concurrency or deploy-time wiring gets an execution harness, not a
  review.** A race, a cold-start import failure, or a missing runtime binding is not findable by
  reading; build the harness as in-scope work for the spec.

**When a review changes a rule, re-audit the rule — not the line**

A review finding is usually reported as an instance ("this call site uses the wrong predicate").
Fixing the cited line and moving on is how the same defect survives repeated review: on one spec,
three separate reviewers reported the same rule against three *different* call sites, each was fixed,
and a fourth site shipped broken.

- When a finding is an instance of a **rule**, the fix is a test or lint rule that enumerates
  **every** site of that rule and asserts each one — for the same reason inventories are derived
  rather than hand-written: a hand-maintained list rots and a derived one does not.
- **Scope added mid-review restarts the clock.** Widening a spec in response to a finding is often
  right, but the widening arrives late, gets the least scrutiny, and inherits confidence it has not
  earned.

**Briefing the reviewer — four lines that change what comes back**

The frame decides the *class* of finding; the briefing decides whether the answer is honest.

- **Say that "this is sound" is a valid verdict.** A reviewer that infers it is expected to produce
  findings will produce them. The round that returned the most useful report was the one told
  explicitly that a short "implementable as written, here is what I built" was a valuable outcome —
  and it still returned real defects, so the line costs nothing.
- **Require it to cite where it looked** before declaring something missing — the spec line it read
  before concluding the spec is silent. That separates a genuine gap from a miss, and it is the
  cheapest way to keep a long report's false-positive rate down.
- **Tell round N+1 what round N fixed, and forbid re-auditing it.** Otherwise the second pass
  re-derives the first pass's findings and never reaches the new work.
- **Withhold the history from a frame that is testing self-sufficiency.** The opposite of the line
  above, and both are right: a pass asking *"is this spec buildable by someone who wasn't here"* must
  be given it cold.

**A rewrite under review pressure is the highest-risk artifact in the loop**

Adjacent to *scope added mid-review restarts the clock*, and stronger. When a finding causes a
substantial **replacement** rather than a widening, the replacement is written quickly, confidently,
and with nobody having reviewed it. On one spec the second round found **four blockers, all of them
inside machinery the first round's fixes introduced** — two of which independently broke a path the
spec had a requirement to preserve. Budget a round for the fix, aimed at the fix.

And **when the same area is wrong twice, the signal is about the area, not the draft.** Two drafts of
one spec were wrong about the same thing. A repeat in one place is where to spend the next frame,
ahead of anything the reviewer ranked higher.

**The implementer frame must actually build, and every frame must run the gates**

*The build-it-from-the-spec rotation named above, made concrete — it earns its own block because it
yields a different class of finding than any reading-based frame.*

- **Have it write real code, off-repo, and run the suites.** What it found by running that no reader
  found: nine existing tests that invert (a list the spec claimed was four, including one in a
  *different* suite from the one the spec's list implied), fixtures across two suites that silently
  become the new failure case, a hard-coded count in an unrelated coverage test, and a fake whose
  signature diverges from the real client.
- **Its output class is contradictions, unspecified shapes and sequencing** — two requirements that
  cannot both hold; a return type nobody named; a phase boundary that leaves `main` exposed. An
  adversarial reader finds defects and does not find these; the implementer finds these and is worse at
  defects. Run both, not one twice.
- **Every reviewer runs the repo's gates against the branch** — formatter, linter, typecheck, tests,
  `scripts/spec-lint.sh` on any spec it touched, and `scripts/docs-lint.sh` on any change that touches
  `CLAUDE.md`, `docs/decisions.md` or a delivery doc. Four rounds once reviewed a spec and none ran the
  repo's doc-layout gate; the branch was red on it throughout, for a reason unrelated to the spec, and
  it took an agent that *built* the change to notice. A review of a change touching gated files runs
  the gates.

**Exit on the trajectory of the findings, not on an empty round**

*Refines "exit on a new frame finding nothing".* In practice a fresh frame rarely finds literally
nothing — it finds something smaller. The honest signal is the **class** changing round over round:
blockers → machinery introduced by the fixes → sequencing and contradictions → coin-flips no test
would catch. Stop when a new frame's worst finding is one that would not change the built result, and
say which finding that was. **This governs the ceiling, never the floor** — it says when to stop
*above* the counts in §3's reviewer contract, not that a count can be skipped, so a diff still
gets its two frames when the first comes back with nothing that would change the built result.

**An Open Question can wear a declarative sentence**

`CLAUDE.md` forbids a spec carrying Open Questions, and `spec-lint.sh` fails an "Open Questions"
heading — and the check is easy to pass while failing. One spec shipped the sentence *"either the
exception moves to a shared location or the call returns a refusal the caller raises. The spec states
which"* — and then did not. A sentence that **promises a decision** is an Open Question with a
declarative shape; so is an acceptance criterion demanding a **computed** bound while supplying none
of its inputs. Both were caught by an implementer who had to pick, and neither by a reader.

**Landing the spec — watch PRs and watch `main`**
- **A branch reaches the remote already reviewed.** The gate above is the precondition for the push,
  so a PR opens carrying work whose findings are already fixed or answered. If a review round happens
  after a push anyway — a late finding, a rotated frame, a reviewer that ran long — its fixes are
  committed and reviewed locally before the next push, rather than each one going up as it lands.
- **Every PR is watched to completion and merged as soon as CI is green** — never open a PR and walk
  away. A spec's PR merges only on green.
- **Key the watch on the current head sha, never a bare `gh pr checks --watch`** — it can exit clean
  against the **previous** commit's checks, and a hand-written shell condition can invert and print
  "settled" while a job is still running. Both report a green that is not there.
- **`main` is always watched.** After any merge, confirm `main`'s build went green. If `main` fails,
  **diagnose immediately and fix it with a new PR** — a red `main` is the top priority and blocks
  starting the next spec.
- **Re-verify `main` is green** before starting the next spec (land before starting the next).
- Then run the completion ritual (§5).

**Several agents on one repo — the PR queue**

The default is one spec in flight (§2). When you deliberately run N sessions against one repo, each
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

---

## 4. Authoring a spec

Specs are written from `docs/templates/spec-template.md`. What makes a spec *buildable*:

- **Overview** — user/business intent, no implementation detail. Understandable cold.
- **Scope: In / Out** — explicitly list what's *excluded*, especially anything a reader would
  reasonably assume is included.
- **Functional Requirements** — one FR per discrete, testable behavior, with binary pass/fail
  **Acceptance Criteria** covering happy path, error path, and edges. Sequential IDs so a prompt can
  say "implement FR-001 through FR-003 only."
- **Size: aim for 3–6 FRs, and split above 8.** A spec is one coherent slice of behavior, not a
  feature's whole surface, and a spec past eight is not a big spec — it is a spec that should have
  been two. (Measured once, on the 216 specs this method was built on: the median carried 6 FRs
  and four in five carried 8 or fewer. A dated observation, not a standing claim about any
  corpus — the rule below forbids a standing rule resting on a number that rots.) The 3–6 aim
  sits at or below that median deliberately: it is where the method is going, not a description
  of where it already is. Growing one spec is the wrong repair;
  the right one is a second spec beside it, with the pair's build order recorded in `INDEX.md` as an
  **arc** (§2). Splitting keeps paying off past the first cut — a three-spec arc reads better than
  one fourteen-FR spec, and each piece earns its own reviewed plan, its own review gate and its own
  delivery doc. Cut along a seam the system already has — a layer, a surface, a switchover, the
  point where something inert goes live — never at "FR-009, because that is where the count ran
  out." **The second spec restarts at FR-001**: IDs are spec-local, which is why a dependency cites
  them as "SPEC-003 FR-002" and never as a number on its own. On the first specs in a repo, where
  there is no system yet to find a seam in, the seam is the user-visible step: what has to exist
  before the next thing can be tried at all.
- **The ceiling is a warn, not a fail.** A genuinely indivisible spec can sit above 8, and the lint
  warns rather than blocking so that it can. That call is made **out loud** — one line under
  *Scope → In Scope* saying why the FRs cannot be cut apart — and it is the reviewer's to accept
  or reject, not the author's to assert. "It is all one feature" is the claim to be most
  skeptical of, because it is what every over-scoped spec says about itself.
- **Data Model / Interface Contract** — language-native types, not prose. Explicit shapes produce
  better-typed output. Note the target path.
- **Implementation Phases** — each phase is one session's worth of work and maps to a discrete,
  reviewable unit. Phases are the input to the implementation plan generated at build time (§3); don't
  bake per-phase checkpoints into the spec.
- **No Open Questions.** Resolve every decision while authoring — a spec doesn't reach Draft-ready with
  unanswered questions. Issues that only surface during the build are handled in-session (§3), not
  parked in the spec. A sentence that *promises* a decision is an Open Question in declarative
  clothes (§3).
- **Then the reviewer gate** (§3, *The reviewer contract*). A freshly-authored spec goes to a
  fresh-context reviewer before it is Draft-ready, and its findings are fixed or flagged.
  The commonest thing this catches is not a wrong requirement — it is an acceptance criterion that
  cannot fail, and an Out of Scope bullet that an FR quietly needs.

`scripts/spec-lint.sh` enforces the structural side of this in CI: it **fails** a spec that is missing
a required section or that contains an "Open Questions" / "Checkpoint" heading, and **warns** on
unfilled placeholders, a spec with FRs but no acceptance criteria anywhere in it, and a spec
carrying more than 8 FRs. It cannot see a vacuous acceptance criterion, an acceptance criterion
missing from one FR while its neighbours have them, or a decision promised in a declarative
sentence — that is what the reviewer gate is for.

---

## 5. Completion ritual (keep the always-loaded tier lean)

When a spec is done, in the same pass:
1. Set the spec file header `Status: Completed`.
2. Update its one-line row in `docs/specs/INDEX.md` (**status only** — no prose).
3. Write a **short** delivery doc at `docs/spec-delivery/SPEC-XXX-<name>.md` from
   `docs/templates/spec-completion-template.md` — *what shipped + what changed*, typically under a
   page (~40–100 lines), **no code/config pasted** (the code + component-inventory are the source of
   truth for reuse).
4. If reusable modules/services/components were added, add a **one-line** row to
   `docs/component-inventory.md` (if the inventory has split into area files, the row goes in the
   file **matching the component's path**).
5. A *new architectural decision* gets its **full entry in `docs/decisions.md` first, plus a row in
   that file's `## Contents`** — an entry the Contents does not reach is findable only by reading the
   whole file, and `docs-lint.sh` fails the PR for it — then **one
   line** in CLAUDE.md's Key Decisions — the digest line is **never the only home of a fact**, and
   never a paragraph. A reversal that changes the entry's **heading** must move its Contents row with it —
   the row is an anchor link, left pointing at nothing otherwise, which docs-lint fails.
   If the decision **supersedes an earlier one**, update the old register entry in
   place and add a superseded marker (short blockquote: what changed, which spec, where the full
   entry lives) at every doc site that still states the old claim — arc narratives, architecture
   sections. The new entry alone is not enough; a reader who lands only on the old site must see the
   reversal.
6. **If the decision changed the SHAPE of the system** — a new piece, a piece removed, a boundary
   moved, a mechanism swapped — add a row to `docs/architecture.md` → *Architecture Decision Record*
   **and** update the prose section it contradicts. The row is an index entry: number, title,
   one-line context, a short note, linking to the `decisions.md` entry. Rows are **append-only and
   never renumbered**; a superseded decision keeps its row and gains a note naming the row that
   replaced it. Most decisions do **not** qualify — a rule, a fence or a per-feature choice is a
   register entry and nothing more, and a table that grows a row per spec has stopped being an
   orientation aid.

**Anti-regrowth & doc hygiene** (each rule below was earned by a real doc defect in a project run
this way):

- If a doc disagrees with the code, fix or delete it — don't let stale state accumulate. Don't add
  prose to the always-loaded tier.
- **Documentation lives beside the code it describes.** A page named for a source file, a module or
  a directory belongs in that tree, not in `docs/`; `docs/` carries what spans trees or belongs to
  no tree. The test is where a reader is standing when they need it — someone changing a handler is
  in the handler's tree, and a doc they must leave the tree to find is a doc they will not open.
- **One organising axis per subject, and one doc that owns it.** If a subject is documented per-area,
  exactly one place is per-area. A second doc on the same axis is not redundancy, it is a fork with
  no merge — and the two will already have diverged by the time anyone notices.
- **A register is grouped by AREA; ordering it by spec number turns it into a changelog.** The
  question a reader arrives with is "what has been settled about X", never "what did SPEC-143
  decide". A register is the only home of the rejected alternatives and the fences, so a shape that
  reads as disposable gets treated as disposable. The CLAUDE.md digest and the register **group by
  the same areas**, so a reader who finds an area in one finds it in the other.
- **When a doc moves, the pointers that rot unseen are in SOURCE files** — docstrings, infra
  comments, CI steps. A markdown-only sweep reports the tree clean. Grep the path, not the filename,
  and fix the Draft specs too: a Draft is an unbuilt instruction, and pointing one at a deleted file
  sends the next builder nowhere.
- **A doc's own statement of when to read it must agree with CLAUDE.md's.** Both are cheap to write
  and neither is checked, so they drift silently and the reader follows the wrong one.
- **Status never appears in the heading of a doc whose status can change** — an arc, an
  `architecture.md` section, a `decisions.md` entry. It rots the day the next spec lands, and a
  reader who greps the heading gets an answer that was true once. Status lives in `INDEX.md` and the
  spec header — the two places the completion ritual keeps in step **by hand**, since `spec-lint.sh`
  does not compare them. (A delivery doc's `# Completed Spec — …` title is not this: it names a
  finished record whose status cannot change.)
- **A heading in a doc read by SUBJECT names the subject, not the spec that produced it** — that is
  `architecture.md` and the rulebooks, where a reader arrives asking how a thing works, never "what
  did SPEC-168 decide". The scope is deliberate and stops there: a `decisions.md` entry IS a record
  of what one spec settled, and its number is part of its identity when you arrive from a delivery
  doc or a superseded marker, so those headings keep theirs. A rule stated more broadly than that
  would be violated by most of a mature register on the day it was written, and a rule practice
  contradicts at scale trains readers to ignore the ones that hold.
- **Standing rules never cite volatile numbers** (line counts, row counts, section ranges) — state
  the principle. The numbers rot, and a rule resting on false evidence teaches readers to distrust it.
  **Dating the measurement does not save it**, which is the tempting half-fix: a dated number still
  reads as current to anyone not checking the date against the calendar, and one such entry went stale
  within a single commit of being written. Either delete the number and state the principle, or anchor
  the evidence to something immutable — a commit SHA, which a reader can re-measure — rather than to a
  live count.
- **A rule practice consistently violates gets reconciled or deleted.** A dead rule trains agents to
  ignore the live ones.
- **Routers and indexes carry only what self-describes.** Hand-maintained metadata (symbol counts,
  "§1–§N" ranges) rots silently; drop it or let the structure carry the information.
- **Any doc pulled entry-by-entry gets one heading per entry plus a TOC**, and pointer phrases in
  other docs must match a greppable heading — "read the entry for your area" must be a jump, not a
  full-file read.
- **Live findings and obligations never live in historical or cancelled narrative** — rehome them to
  an active register and leave a pointer behind.
- **`scripts/docs-lint.sh` enforces the structural half of these rules, and runs on every PR**
  (`.github/workflows/docs-lint.yml`). It holds `CLAUDE.md` to a byte budget and each Key Decisions
  **unit** — a bullet with its continuations — to a length, and refuses any construct in that section but an area heading, a bullet, a continuation, a blank line and plain intro prose; requires `docs/decisions.md` to exist, to carry a `###` entry for every digest
  line and a digest line for every entry, and to list every entry in its Contents; requires every
  Completed spec to have a delivery doc, and holds every doc in `docs/spec-delivery/` to a line cap
  (not only those tied to a Completed spec); and checks that the pointers
  out of `CLAUDE.md` resolve.
  **`scripts/docs-lint-test.sh` is the corpus that proves those checks still fire** — running the
  linter against the repo's own documents proves the documents pass and nothing about whether any
  check works. A change to the linter runs the corpus. The general rule, and its evidence, is in §3.
  **The budgets are ratchets against ACCRETION** — when one fires because a doc grew a line at a
  time, move detail down a tier and re-ratchet, rather than raising the cap to admit the edit. That
  is the regime a budget is normally in, and pinning it near the measurement is right there.
  **After a structural CUT the regime changes, and the same pinning becomes the trap.** What remains
  after a cut is not accretion but fences, and a budget left at the new measurement leaves the next
  change that legitimately needs a line nothing to spend — so it takes one from somewhere else, and
  the gate causes the damage it exists to prevent. Measured in `log-forge`: a cap set at its post-cut
  size left about two digest lines of room, and was deliberately raised with the reasoning recorded
  beside the number. Leave headroom after a cut, say why where the number lives, and mark that budget
  as the one **not** at the measurement.
  **A threshold can also be invalidated by its own success.** A cap calibrated against a document
  catches things until a cut shrinks everything below it, after which it sits far above anything it
  governs and can never fire — still advertised here as a fence, and now not one. So after any
  structural change to what a threshold measures, **re-derive it rather than re-checking it**: a
  check that passes proves nothing about a cap that can no longer fail. This repo's own shipped
  budgets are deliberately loose for that reason — it ships a scaffold, and `scripts/docs-lint.sh`
  says so where they are set.
  *Why a script and not this paragraph:* every rule in this section already existed here, and the
  sibling project `log-forge` violated several of them anyway — and its history says something
  sharper than "a rule was ignored". Its `CLAUDE.md` grew from 7,350 bytes at `ad898fc8` to 89,340
  at `e60b60d`, more than tenfold. For most of that it had only a **two-sentence** version of this
  section — "don't add prose to the always-loaded tier", naming no shape, no register and no budget:
  a rule too weak to bind. The full set arrived at `690d2a55`, ported from s3-upload-portal, naming
  the violation in the present tense and naming it correctly; the file was already 67,925 bytes by
  then, and grew a further fifth before anyone cut it. **Both halves fail without a gate**: the weak
  rule could not bind, and the right rule, diagnosing itself accurately in the file every session
  reads, did not stop the next edit either. Both ends of each measurement are anchored to a commit
  so a reader can re-derive them, per the volatile-number rule above. A rule a reader has to
  remember is a rule that rots.

---

## 6. Operational traps that only bite in CI / on deploy

These pass locally and fail later — check them as part of the work, not as an afterthought. Keep this
list project-specific; seed it the first time a trap bites and never again.

- _(example)_ A test runner that needs a specific working directory or config to pick up its
  environment — running it from the repo root vs. the package dir changes behavior.
- _(example)_ Config/env values the app reads at runtime must also be wired into the deploy/build
  environment, or production ships them undefined.
- _(add your own as they bite — one line each, with the fix.)_

---

## 7. Project ground rules that shape the process

- **Don't add dependencies** without first noting them in CLAUDE.md's Tech Stack.
- _(add the load-bearing constraints that shape how work is done here — e.g. "no backend," "library
  must stay dependency-free," "single supported runtime version.")_
