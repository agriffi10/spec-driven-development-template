---
name: spec-driven
description: >-
  Spec-driven development workflow with guardrails. Use when (a) setting up / bootstrapping a repo for
  spec-driven work, (b) authoring or refining a spec, (c) starting to build a spec, (d) completing a
  spec, or (e) running several agent sessions against one repo at once. Provides a template repo layout (CLAUDE.md, layered docs/, spec + completion templates), a
  POSIX spec-lint (CI) and docs-lint (a local pre-push gate, deliberately not CI), plus a CI workflow
  + PR template. Enforces: specs are fully specified before build
  (no Open Questions), spec/plan/diff each pass a blocking fresh-context review gate, the diff review
  gates the push rather than the merge, builds run off a reviewed plan straight to completion (no
  per-phase checkpoints), every PR is watched and merged on green, main is always watched, and the
  always-loaded tier stays lean (budget + a decisions register behind every digest line).
  Triggers on phrases like "set up
  spec-driven", "scaffold the docs structure", "write a spec", "start SPEC-XXX", "build this spec",
  "complete the spec / run the completion ritual", "run several agents at once".
---

# Spec-Driven Development

A workflow for shipping features as: **specify → plan → build in reviewable phases → land on green →
record leanly.** This skill carries the scaffold under `template/` and the rules for operating it. The
goal is a small always-loaded context (`CLAUDE.md`) backed by layered, on-demand docs.

`template/docs/process.md` is the **pristine** copy of the method, for scaffolding. In a repo that
has already been scaffolded, read that repo's own **`docs/process.md`** instead, every session — it
is the contract `CLAUDE.md` summarises, and its *Operational traps* and *Project ground rules*
sections are filled in per project and exist nowhere else. The jobs below are the operating modes.

## 0. Scaffold a repo (bootstrap)

When a repo has no spec-driven docs yet:

1. Copy the contents of this skill's `template/` into the repo root: `CLAUDE.md`, `docs/`, `scripts/`,
   `.github/`. **Do not clobber** existing files — if `CLAUDE.md`, a PR template, or a workflow already
   exists, merge rather than overwrite, and tell the user what you merged.
   🔴 **If the repo you are scaffolding is the template repo itself**, stop: its root is a generated
   mirror of `template/`, `scripts/sync-from-skill.sh` regenerates it, and edits belong in `template/`
   followed by a sync. Steps 3 and 6 below would fill in the mirror and delete `ci.yml.example`, which
   must survive there.
2. `chmod +x scripts/spec-lint.sh scripts/docs-lint.sh scripts/docs-lint-test.sh scripts/pr-queue/queue.sh scripts/pr-queue/pre-push scripts/pr-queue/install.sh`.
3. Fill in the placeholders in `CLAUDE.md` (Project Overview, Layout, Tech Stack, Code Conventions,
   Common Commands) from what the repo actually is — detect the language/build/test/lint tooling from
   the manifest (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, …) rather than guessing.
4. Seed `docs/architecture.md` from any existing design notes the repo already has; otherwise leave the
   sectioned stub.
5. Wire `spec-lint` into CI (add a step to the repo's workflow, or keep the standalone `spec-lint.yml`
   — either is fine, but it must run on PRs). **`docs-lint` is deliberately NOT a CI job**: it is a
   local pre-push gate, so its failures land on the person who caused them rather than on a shared
   branch where they red unrelated work. Then **re-ratchet all three budgets in `scripts/docs-lint.sh`** — `CLAUDE_MAX_BYTES`,
   `DIGEST_MAX_BYTES` and `DELIVERY_MAX_LINES` — to what this repo actually measures. The shipped
   defaults are sized for a scaffold whose `CLAUDE.md` is placeholders and whose `docs/spec-delivery/`
   is empty, and a budget far above the measurement never fires.
6. **Set up language CI (GitHub Actions).** Ask the user *once* what the repo's CI needs — which
   languages/runtimes, and the install / format-check / lint / typecheck / test commands (default to
   `CLAUDE.md` → Common Commands). From `.github/workflows/ci.yml.example`, produce a real
   `.github/workflows/ci.yml`: keep only the job(s) for this repo's languages, fill in the actual
   commands, run on PR + push to `main`, then delete the `.example`. 🔴 Never leave placeholder commands
   that would fail — if a check doesn't apply, drop it. This makes "land on green CI" cover the language
   gates, not just spec-lint.
7. Run `sh scripts/spec-lint.sh` and `sh scripts/docs-lint.sh` to confirm both pass (each no-ops or
   passes cleanly on a fresh scaffold).

Keep the always-loaded tier (`CLAUDE.md`) lean — it must not regrow into a wall of prose. `docs-lint.sh`
now enforces that rather than asking you to remember it. In a project that ran this template the
always-loaded file grew more than tenfold: first under a rule too weak to bind, then — once the
full rule set arrived and named the violation correctly — for days more regardless.

## 1. Author a spec

Write from `template/docs/templates/spec-template.md`. A spec is *buildable* when:

- **Overview** states user/business intent, no implementation detail.
- **Scope** lists In and **Out** explicitly (especially things a reader would assume are in).
- **Functional Requirements** are granular, each with binary pass/fail **Acceptance Criteria** covering
  happy/error/edge paths, sequential IDs.
- **It is one slice, not a whole feature** — aim for **3–6 FRs**, and past **8** split into a second
  spec rather than growing this one, recording the pair as an arc with a build order in `INDEX.md`.
  Cut on a seam the system already has (a layer, a surface, a switchover), never at the FR where the
  count ran out; the second spec **restarts at FR-001**, since IDs are spec-local.
  `spec-lint.sh` **warns** above 8 rather than failing: a genuinely indivisible spec may sit above
  the line, but say so in one line under *Scope → In Scope* and let the reviewer accept or reject
  it — "it is all one feature" is what every over-scoped spec claims.
- **Data Model / Interface Contract** uses language-native types, not prose.
- **Implementation Phases** are reviewable units — the *input to the build-time plan*. Do **not** write
  per-phase checkpoints.
- **No Open Questions.** Resolve every decision while authoring. If something genuinely can't be
  resolved, that means the spec isn't Draft-ready — get the answer, don't park it. A sentence that
  *promises* a decision ("the spec states which") is an Open Question in declarative clothes, and the
  lint cannot see it.
- **It has been through the reviewer gate.** A freshly-authored spec goes to **one** fresh-context
  reviewer before it is Draft-ready; findings are **fixed or flagged** — a rejection said out loud costs a
  sentence, and only goes in writing when it carries a lesson worth keeping. What this catches is
  rarely a wrong requirement — it is an acceptance criterion that cannot fail, and an Out of Scope
  bullet an FR quietly needs. Give the reviewer the spec, its build-order entry, and its dependencies
  — never your authoring rationale.

Add a row to `docs/specs/INDEX.md`. Before handing off, run `sh scripts/spec-lint.sh` — it fails on
missing sections or an "Open Questions"/"Checkpoint" heading. The lint is the structural half only;
the gate above is the other half.

## 2. Build a spec (plan-gated)

Only when told to build (a Draft spec sitting in the repo is not a signal to start).

1. Read `CLAUDE.md` and the repo's own **`docs/process.md`**, then the **current spec in full**. Skim
   `component-inventory.md`; pull only the `architecture.md` section / dependency delivery-doc you
   need — never the whole file.
2. Confirm CI is green on `main`; investigate failures first.
3. Branch from fresh `main`, and set the spec's `Status: In Progress` + its `INDEX.md` row in that
   first commit — nothing gates that transition, so it is missed by being skipped.
4. **Generate an implementation plan from the spec's phases and validate it against the spec** — every
   FR + acceptance criterion covered, reuse used, nothing out of scope. **Then send the plan to one
   fresh-context reviewer before the first line of code** (one is the floor — a phase that revises
   the plan sends the new plan back through). A wrong plan is more expensive than wrong
   code, because the code will faithfully implement it. This reviewed plan replaces per-phase
   checkpoints.
5. **Send the PR grouping to a reviewer too**, before the first push — as few PRs as the dependencies
   allow. A phase is a unit of work, not a unit of PR. **These two reviews are the only ones that gate
   the START of the build** — the diff review in step 7 gates the push, at the other end, and is
   blocking too. Past the plan and the grouping, the build runs **straight through to completion**.
   Summarize a phase in passing where it is worth saying, but never end the turn on it — a summary
   that ends the turn *is* a request for approval, and on a twelve-phase spec it re-asks a question
   the user already answered twelve times. A phase that *revises* the plan has produced a new
   artifact — that goes back through the gate. Each file-changing task on its own branch → PR.
6. Triage emergent issues by kind: **reversible/technical** → decide in-session (update the spec
   if scope changes); **product-changing/ambiguous** → stop and escalate to the human with options
   + a recommendation, never silently decide. Stop only for a question that genuinely needs an
   answer — reporting is not the same act as asking.
7. **Two fresh-context reviews of the diff, BEFORE the push.** Commit locally, run the gates, send
   the diff to **two** new sessions or subagents in **different frames** — never the one that wrote
   the code — then fix or flag every finding, *then* push and open the PR. The diff gets two because
   it is the widest artifact and the last before the branch is public. One frame starts from the
   **change** and reads it against what it must satisfy; the other starts from **something other
   than the change** — on code, a pass that *builds* the thing and runs the suites; on a docs- or
   spec-only diff, the other places the same rule is stated. Two frames, not two rounds, and two is
   the floor rather than the cap (step 9) — a clean first review does not close a **diff** gate,
   though it does close a spec's or a plan's. A self-reviewing agent rubber-stamps its own work, and
   pushing first inverts the gate: the branch is already public and the fixes arrive as follow-up
   commits. **Green CI is not a review** — it cannot see a test that passes against the bug it claims
   to catch, a lock taken in the wrong order, or an acceptance criterion ticked with no evidence. The
   reviewer checks the diff against the spec's acceptance criteria and the relevant `best-practices/`
   rules. Findings are **fixed or flagged** — a rejection costs a sentence out loud, and goes in
   writing only when it carries a lesson worth keeping.
8. **A gate is not tested by running it on what it guards.** A linter run over the repo's own files
   proves the files pass, not that any check still fires. Every gate owes a fixture corpus asserting
   the specific failure text, including cases that assert silence, proved by defeating each check in
   turn and watching it redden. **Count the ways each check can stop and write
   that many cases** — a check with two terminating conditions is satisfied by a fixture exercising
   either, so the mutant that breaks the other survives with the suite green.
9. **Rotate the frame instead of adding rounds.** Cap same-frame review at two rounds, then switch
   frame: adversarial execution, whole-module fresh eyes (not the diff), concurrency, security. **One
   rotation must actually build the thing** off-repo and run the suites — it finds contradictions,
   unspecified shapes and sequencing that no reader finds. Every reviewer runs the repo's gates against
   the branch. Exit when the *class* of finding stops mattering, never on a round count. Brief each
   reviewer that "this is sound" is a valid verdict, require it to cite where it looked, and tell round
   N+1 what round N fixed. Budget a round for any substantial **rewrite** a finding causes — that
   replacement is the least-reviewed thing in the loop. **When the risk is what the change *removed*,
   enumerate rather than review** — a reviewer samples, and a deletion leaves nothing to read; write
   the sweep that lists the whole population, and have it report before it applies. A sweep has a
   frame the same way a review does — several sweeps asking the same question are one check, however
   exhaustive each is, and they say nothing about the half of a change that was newly written. **Spot-check a
   negative claim** ("no test covers this", "nothing imports this") before acting on it and again
   before writing it down. Full contract and the measurements behind it: `docs/process.md` §3.

## 3. Watch PRs and watch main

- **A branch reaches the remote already reviewed** — the diff gate in §2 step 7 is the precondition
  for the push, so a PR opens carrying findings that are already fixed or answered.
- Watch **every** PR to completion; merge it as soon as CI is green. Never open-and-abandon.
- **Key the watch on the current head sha**, never a bare `gh pr checks --watch` — it can exit clean
  against the *previous* commit's checks, and a hand-rolled shell condition can invert and print
  "settled" while a job is still running.
- After any merge, confirm `main` went green. If `main` fails, **diagnose immediately and fix with a new
  PR before anything else** — a red `main` is top priority and blocks the next spec.
- Re-verify `main` is green before starting the next spec.

## 4. Completion ritual (keep the always-loaded tier lean)

In one pass when a spec is done:
1. Spec header `Status: Completed`.
2. Update its one-line row in `docs/specs/INDEX.md` (status only).
3. Write a short delivery doc at `docs/spec-delivery/SPEC-XXX-<name>.md` from
   `docs/templates/spec-completion-template.md` — typically under a page (~40–100 lines), no code pasted.
4. If reusable components were added, add a one-line row to `docs/component-inventory.md`.
5. A new architectural decision → full entry in `docs/decisions.md` **first**, then one line in
   `CLAUDE.md` Key Decisions (+ pointer). Never a paragraph, and never the only home of a fact. If it
   **supersedes** an earlier decision, add an in-place superseded marker at every doc site still
   stating the old claim.
6. If it changed the **shape** of the system — a piece added or removed, a boundary moved, a mechanism
   swapped — add an append-only row to `docs/architecture.md` → *Architecture Decision Record* and fix
   the prose section it contradicts. Most decisions do not qualify.

## 5. Running several agents on one repo

Only when the user asks for it. The default is one spec in flight; this is the deliberate exception.

N sessions, one repo, one `main`. Each works in its own worktree so their trees never collide, but
the remote is still shared: two PRs open at once means each is tested against a `main` the other is
about to move, and a merge race turns a green PR red for a reason neither agent caused. **Serialise
the remote, parallelise the work.**

1. **Install the queue once, before launching anyone:** `sh scripts/pr-queue/install.sh '<branch-regex>'`
   (default `^spec-`). **That regex is the setting that silently disables everything** — the hook
   enforces only against branches matching it and allows every other push, so it must match the
   branch names you hand out in step 2, and nothing reports the mismatch if it does not.
   It copies `queue.sh`, `pre-push` and `PROTOCOL.md` to a shared directory under `$HOME` — outside
   every worktree and outside the repo, because a lock inside a worktree is invisible to peers and a
   lock inside the repo is a file that itself conflicts — and points a `.git/hooks/pre-push` wrapper
   at the copy there. It exits **3**, having installed everything else, if another `pre-push` hook is
   already in the way; the message says what to add by hand.
2. **Brief every session from `docs/templates/multi-agent-briefing.md`** — its own worktree off fresh
   `origin/main`, who else is running and on what, the local gates and diff reviews that come *before*
   the queue, the four commands, and the files two agents will both edit. Tell them plainly that a
   rebase conflict is never resolved by discarding a peer's work. An unbriefed session does the
   reasonable thing for a session working alone, which is exactly what breaks a parallel run.
3. **Each session, when its gates and reviews are green:** `queue.sh ticket SPEC-XXX` to get in line,
   poll `queue.sh turn SPEC-XXX` with the Monitor tool's until-loop (blocking `sleep` is unavailable
   in the Bash tool, and each `turn` call is the heartbeat that keeps its place), `queue.sh acquire`
   once that exits 0, then `queue.sh release` on **every** exit path including failure. The lock
   covers the whole PR lifecycle — rebase, push, open, watch to green, merge, confirm `main` — not
   just the push, and it is one ticket per PR so a multi-PR spec does not hold the line throughout.
4. **If `turn` reports the trunk `IS RED`, stop and escalate.** A red `main` is fixed before anything
   else merges.
5. **Do not hand-roll the shell.** Every remote check fails closed on purpose (a `gh` that *errors*
   returns empty output, which reads as "no PRs open"), and enforcement fails open on purpose (linked
   worktrees share `.git/hooks`, so the hook fires for sessions that never agreed to the queue).
   Reimplementing this by hand gets one of those backwards. Full protocol and the configuration
   seams for non-GitHub projects: `scripts/pr-queue/PROTOCOL.md`.

## spec-lint reference

`scripts/spec-lint.sh [dir]` (default `docs/specs`). **FAIL** (exit 1): a spec missing a required
section (`## Overview`, `## Scope`, `## Functional Requirements`, `## Implementation Phases`), or
containing an `Open Questions` / `Checkpoint` heading. **WARN** (exit 0): unfilled placeholders, a
spec with FRs but no acceptance criteria anywhere in it, and a spec carrying more than
`FR_CEILING` (8) distinct FRs. POSIX `sh` — no runtime dependency.

## docs-lint reference

`scripts/docs-lint.sh` (no arguments; resolves its own repo root). **FAIL** (exit 1), no WARN tier:
`CLAUDE.md` over `CLAUDE_MAX_BYTES`; a Key Decisions unit over `DIGEST_MAX_BYTES` — a bullet with its
continuation lines joined, or a prose paragraph, since keying only on bullets let the section be
rewritten as prose to escape both this cap and the register cross-check; `docs/decisions.md` missing; a digest label with no `###` entry or an entry
with no digest label; an entry absent from that file's Contents; a `Status: Completed` spec with no
`docs/spec-delivery/SPEC-NNN-*.md`; a delivery doc over `DELIVERY_MAX_LINES`; a relative link or `@`
pointer in `CLAUDE.md` that resolves to nothing. Entries labelled `(example)` are exempt, so a fresh
scaffold is green. **`scripts/docs-lint-test.sh` is its fixture corpus — run it after any change to
`docs-lint.sh`.** The linter passing against your own docs says nothing about whether its checks
work; the corpus is what says that. The budgets are **ratchets against accretion**: when one fires because a doc grew a line at a time, cut and re-ratchet at the new
measurement — never raise it to fit the edit. **After a structural CUT the regime inverts**: what remains is fences rather than accretion, so leave headroom deliberately and record why beside the number, or the next change that legitimately needs a line takes one from another area. POSIX `sh` — no runtime dependency.
