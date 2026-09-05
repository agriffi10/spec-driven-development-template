# The reviewer contract

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
- **Never carry an evidence sentence from another repo's commit message or script header — re-measure
  it where you are putting it.** This is the mechanism behind every false claim a review has caught in
  these docs, and it does not feel like guessing: the sentence was written by someone who had the repo
  open, it reads as measured, and it is repeated verbatim. Six such claims shipped into this section
  and its script — "monotonically, not one commit reducing it", "named the violation in the present
  tense throughout", "eight weeks", a byte count already stale on the branch that wrote it. The one
  figure that survived checking came from the same place, which is exactly why the habit persists.
  **Anchor both ends of any measurement to a commit** a reader can re-derive it from: anchoring only
  the end is what let "eight weeks" through, because "from" was then whichever commit the writer had
  in mind. If you cannot cite both ends, state the principle and drop the number.
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
*above* the counts in *The reviewer contract* above, not that a count can be skipped, so a diff still
gets its two frames when the first comes back with nothing that would change the built result.

**An Open Question can wear a declarative sentence**

`CLAUDE.md` forbids a spec carrying Open Questions, and `spec-lint.sh` fails an "Open Questions"
heading — and the check is easy to pass while failing. One spec shipped the sentence *"either the
exception moves to a shared location or the call returns a refusal the caller raises. The spec states
which"* — and then did not. A sentence that **promises a decision** is an Open Question with a
declarative shape; so is an acceptance criterion demanding a **computed** bound while supplying none
of its inputs. Both were caught by an implementer who had to pick, and neither by a reader.
