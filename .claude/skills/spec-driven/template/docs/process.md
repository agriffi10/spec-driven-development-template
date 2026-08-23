# The Spec-Driven Development Process

How work gets done in this repo. `CLAUDE.md` carries the terse, always-loaded rules; this doc is the
fuller **method** they point to — read it once to understand the rhythm, then let CLAUDE.md's Session
Workflow be your in-session checklist. It is read on demand, not every session.

Goal: each feature is **specified before it's built**, built in **reviewable phases** off a
**validated plan**, landed as a **single PR on green CI**, and recorded in **lean, layered docs** so
the next session starts cheap.

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
| Method | `docs/process.md` (this file) | once | how we work |

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
- **Completed** — merged on green CI, delivery doc written (see §5).

**Arcs.** Related specs can be grouped into *arcs* with an explicit **build order** documented in
`INDEX.md`. Build in that order; arcs can have non-obvious dependencies. If arc narrative outgrows an
`INDEX.md` row, move it to a `docs/specs/ARCS.md` with **one `##` heading per arc** (a status word in
the heading — shipped / cancelled / active) and a TOC at the top, so a session can load only the arc
it's in. Structure it that way from the first entry — retrofitting headings onto grown prose is far
more work.

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
4. **Branch from fresh `main`.**
5. **Generate and validate a plan before writing code.** Turn the spec's Implementation Phases into a
   concrete implementation plan, then validate it against the spec — every FR + acceptance criterion is
   covered, reuse from `component-inventory.md` is used, and nothing out of scope crept in. The plan —
   not per-phase checkpoints baked into the spec — is what gates the work.
6. **Put the plan through the reviewer gate before the first line of code** (*The reviewer contract*,
   below). A plan is reviewed for the same reason a PR is: the author cannot see what they assumed.
   Confirm the reviewed plan with the user, then build.

**During the build — one spec, in phases**
- Every file-changing task is done on its **own branch** and opened as a **PR** — automatically, without
  waiting to be asked. Never commit to `main` directly.
- Before opening a PR, run the project's **formatter, linter, and unit tests** locally and get them
  green. These quality gates are a pre-PR step — don't push red and leave CI to discover it.
- Work the **reviewed** plan's phases in order. After each phase, **stop and summarize** what was built
  and how it maps back to the plan before continuing. Re-review the plan only if the phase changed it —
  a phase that revises the plan has produced a new artifact, and it goes through the gate as one.
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
expensive of the two because the code that follows will faithfully implement it.

- **The gate is blocking.** A spec is not Draft-ready, and a plan does not start code, until it has
  been through a review round and every finding is either **fixed** or **explicitly rejected in
  writing** — in the spec/plan itself, or in the session summary, saying which finding and why. A
  finding that is silently dropped is a finding that was not reviewed.
- **The reviewer gets the artifact and its sources, never the author's reasoning.** For a spec: the
  spec file, its build-order entry in `INDEX.md`, the `architecture.md` sections and `decisions.md`
  entries it claims to follow, and the specs it depends on. For a plan: the plan, the spec, and
  `component-inventory.md`. Handing over the authoring rationale tells the reviewer what to conclude.
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
- **A reviewer finding is not an instruction.** The author decides; the record of the decision is what
  the gate requires. A rejected finding that turns out right is a cheap lesson with a written trail; a
  fixed finding that was wrong is a silent regression.

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
  and `scripts/spec-lint.sh` on any spec it touched. Four rounds once reviewed a spec and none ran the
  repo's doc-layout gate; the branch was red on it throughout, for a reason unrelated to the spec, and
  it took an agent that *built* the change to notice. A review of a change touching gated files runs
  the gates.

**Exit on the trajectory of the findings, not on an empty round**

*Refines "exit on a new frame finding nothing".* In practice a fresh frame rarely finds literally
nothing — it finds something smaller. The honest signal is the **class** changing round over round:
blockers → machinery introduced by the fixes → sequencing and contradictions → coin-flips no test
would catch. Stop when a new frame's worst finding is one that would not change the built result, and
say which finding that was.

**An Open Question can wear a declarative sentence**

`CLAUDE.md` forbids a spec carrying Open Questions, and `spec-lint.sh` fails an "Open Questions"
heading — and the check is easy to pass while failing. One spec shipped the sentence *"either the
exception moves to a shared location or the call returns a refusal the caller raises. The spec states
which"* — and then did not. A sentence that **promises a decision** is an Open Question with a
declarative shape; so is an acceptance criterion demanding a **computed** bound while supplying none
of its inputs. Both were caught by an implementer who had to pick, and neither by a reader.

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
- **At least one pass must start from the system, not the diff.** Every diff-scoped review is
  structurally blind to a defect that predates the diff — and to the states the diff is never
  exercised in (a change verified only in the signed-in path says nothing about sign-in).
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

**Landing the spec — watch PRs and watch `main`**
- **Every PR is watched to completion and merged as soon as CI is green** — never open a PR and walk
  away. A spec's PR merges only on green.
- **`main` is always watched.** After any merge, confirm `main`'s build went green. If `main` fails,
  **diagnose immediately and fix it with a new PR** — a red `main` is the top priority and blocks
  starting the next spec.
- **Re-verify `main` is green** before starting the next spec (land before starting the next).
- Then run the completion ritual (§5).

---

## 4. Authoring a spec

Specs are written from `docs/templates/spec-template.md`. What makes a spec *buildable*:

- **Overview** — user/business intent, no implementation detail. Understandable cold.
- **Scope: In / Out** — explicitly list what's *excluded*, especially anything a reader would
  reasonably assume is included.
- **Functional Requirements** — one FR per discrete, testable behavior, with binary pass/fail
  **Acceptance Criteria** covering happy path, error path, and edges. Sequential IDs so a prompt can
  say "implement FR-001 through FR-003 only."
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
  fresh-context reviewer before it is Draft-ready, and its findings are fixed or rejected in writing.
  The commonest thing this catches is not a wrong requirement — it is an acceptance criterion that
  cannot fail, and an Out of Scope bullet that an FR quietly needs.

`scripts/spec-lint.sh` enforces the structural side of this in CI: it **fails** a spec that is missing
a required section or that contains an "Open Questions" / "Checkpoint" heading, and **warns** on
unfilled placeholders or FRs without acceptance criteria. It cannot see a vacuous acceptance criterion
or a decision promised in a declarative sentence — that is what the reviewer gate is for.

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
5. A *new architectural decision* gets its **full entry in `docs/decisions.md` first**, then **one
   line** in CLAUDE.md's Key Decisions — the digest line is **never the only home of a fact**, and
   never a paragraph. If the decision **supersedes an earlier one**, update the old register entry in
   place and add a superseded marker (short blockquote: what changed, which spec, where the full
   entry lives) at every doc site that still states the old claim — arc narratives, architecture
   sections. The new entry alone is not enough; a reader who lands only on the old site must see the
   reversal.

**Anti-regrowth & doc hygiene** (each rule below was earned by a real doc defect in a project run
this way):

- If a doc disagrees with the code, fix or delete it — don't let stale state accumulate. Don't add
  prose to the always-loaded tier.
- **Standing rules never cite volatile numbers** (line counts, row counts, section ranges) — state
  the principle. The numbers rot, and a rule resting on false evidence teaches readers to distrust it.
- **A rule practice consistently violates gets reconciled or deleted.** A dead rule trains agents to
  ignore the live ones.
- **Routers and indexes carry only what self-describes.** Hand-maintained metadata (symbol counts,
  "§1–§N" ranges) rots silently; drop it or let the structure carry the information.
- **Any doc pulled entry-by-entry gets one heading per entry plus a TOC**, and pointer phrases in
  other docs must match a greppable heading — "read the entry for your area" must be a jump, not a
  full-file read.
- **Live findings and obligations never live in historical or cancelled narrative** — rehome them to
  an active register and leave a pointer behind.

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
