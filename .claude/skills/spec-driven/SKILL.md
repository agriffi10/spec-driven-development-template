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
  always-loaded tier stays lean (budget + a fences-first register file per decision area).
  Triggers on phrases like "set up
  spec-driven", "scaffold the docs structure", "write a spec", "start SPEC-XXX", "build this spec",
  "complete the spec / run the completion ritual", "run several agents at once", "which model
  should review this".
---

# Spec-Driven Development

A workflow for shipping features as: **specify → plan → build in reviewable phases → land on green →
record leanly.** This skill carries the scaffold under `template/` and the rules for operating it. The
goal is a small always-loaded context (`CLAUDE.md`) backed by layered, on-demand docs.

`template/docs/process/` is the **pristine** copy of the method, for scaffolding — one file per part
behind the router `INDEX.md`. In a repo that has already been scaffolded, that repo's own
`CLAUDE.md` **imports** its `docs/process/INDEX.md` and `docs/process/session-rhythm.md`, so both are
in context at launch; pull the other parts when the router's table says, and never a single
`docs/process.md` — that layout predates the router, and `docs-lint.sh` fails a repo that still has
one. `operational-traps.md` and `ground-rules.md` are filled in per project and exist nowhere else. **Every artifact is delegated to a subagent on the model the job calls for** — see §6 below.
The jobs below are the operating modes.

## 0. Scaffold a repo (bootstrap)

When a repo has no spec-driven docs yet:

1. Copy **everything** under this skill's `template/` into the repo root — `CLAUDE.md`, `docs/`,
   `scripts/`, `tests/`, `.github/`, and `.claude/rules/` + `.claude/agents/` (the path-scoped
   pointers and the model-routed subagent roles). Copy the whole tree rather than working from a
   list: `sync-from-skill.sh` does (`cp -R`), and the list that used to stand here omitted `tests/`,
   which ships `docs-lint-test.sh` with no fixtures — it finds nothing, passes, and exits 0, so the
   scaffold arrives with a gate-corpus that proves nothing. **Do not clobber** existing files — if `CLAUDE.md`, a PR template, or a workflow already
   exists, merge rather than overwrite, and tell the user what you merged.
   🔴 **If the repo you are scaffolding is the template repo itself**, stop: its root is a generated
   mirror of `template/`, `scripts/sync-from-skill.sh` regenerates it, and edits belong in `template/`
   followed by a sync. Steps 3 and 6 below would fill in the mirror and delete `ci.yml.example`, which
   must survive there.
2. `chmod +x scripts/spec-lint.sh scripts/docs-lint.sh scripts/docs-lint-test.sh scripts/pr-queue-test.sh scripts/pr-queue/queue.sh scripts/pr-queue/pre-push scripts/pr-queue/install.sh scripts/pr-queue/install-test.sh`.
3. Fill in the placeholders in `CLAUDE.md` (Project Overview, Layout, Tech Stack, Code Conventions,
   Common Commands) from what the repo actually is — detect the language/build/test/lint tooling from
   the manifest (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, …) rather than guessing.
4. Seed `docs/architecture.md` from any existing design notes the repo already has; otherwise leave the
   sectioned stub.
5. Wire `spec-lint` into CI (add a step to the repo's workflow, or keep the standalone `spec-lint.yml`
   — either is fine, but it must run on PRs). **`docs-lint` is deliberately NOT a CI job**: it is a
   local pre-push gate, so its failures land on the person who caused them rather than on a shared
   branch where they red unrelated work. Then **re-ratchet all five budgets in `scripts/docs-lint.sh`** — `CLAUDE_MAX_BYTES`,
   `ALWAYS_LOADED_MAX_BYTES`, `KEY_DECISIONS_MAX_BYTES`, `DIGEST_MAX_BYTES` and `DELIVERY_MAX_LINES` — to
   what this repo actually measures. The shipped
   defaults are sized for a scaffold whose `CLAUDE.md` is placeholders and whose `docs/spec-delivery/`
   is empty, and a budget far above the measurement never fires. `DELIVERY_MAX_LINES` is the
   exception — there is no delivery doc to measure yet, so leave it at its default and ratchet it
   after the first spec completes.
6. **Set up language CI (GitHub Actions).** Ask the user *once* what the repo's CI needs — which
   languages/runtimes, and the install / format-check / lint / typecheck / test commands (default to
   `CLAUDE.md` → Common Commands). From `.github/workflows/ci.yml.example`, produce a real
   `.github/workflows/ci.yml`: keep only the job(s) for this repo's languages, fill in the actual
   commands, run on PR + push to `main`, then delete the `.example`. 🔴 Never leave placeholder commands
   that would fail — if a check doesn't apply, drop it. This makes "land on green CI" cover the language
   gates, not just spec-lint.
7. Run `sh scripts/spec-lint.sh` and `sh scripts/docs-lint.sh` to confirm both pass (each no-ops or
   passes cleanly on a fresh scaffold). Then run `sh scripts/docs-lint-test.sh` and
   `sh scripts/pr-queue-test.sh` and `sh scripts/pr-queue/install-test.sh` and **check the case
   COUNTS, not the exit status** — each reports "N passed"; an N of 0 means the fixtures did not
   arrive, and an empty corpus exits 0 exactly like a healthy one.

Keep the always-loaded tier (`CLAUDE.md`) lean — it must not regrow into a wall of prose. `docs-lint.sh`
now enforces that rather than asking you to remember it. In a project that ran this template the
always-loaded file grew more than tenfold: first under a rule too weak to bind, then — once the
full rule set arrived and named the violation correctly — for days more regardless.

## Where the method lives — point, do not restate

**Every rule below this line lives in one file under `docs/process/`, and this file only routes to
it.** That is deliberate. SKILL.md used to restate the method by hand, `check-mirror.sh` skips
`.claude/` by design, and nothing compared the copies — so when the process docs learned that
`git fetch` has to precede a rebase, four passages here went on saying the old thing, and a fifth
site was found only after three review frames. A pointer cannot drift from what it points at.

| Job | Read |
|---|---|
| Author or refine a spec | `docs/process/authoring-a-spec.md` |
| Build a spec, start to finish | `docs/process/session-rhythm.md` |
| Any review gate — spec, plan, grouping, diff | `docs/process/reviewer-contract.md` |
| Watch PRs, watch `main` | `docs/process/session-rhythm.md` → *Landing the spec* |
| Finish a spec | `docs/process/completion-ritual.md` |
| Several sessions on one repo | `docs/process/several-agents.md`, then `scripts/pr-queue/PROTOCOL.md` |
| Which model does which job | `docs/process/model-routing.md` |
| What a spec's status means | `docs/process/spec-lifecycle.md` |

In a scaffolded repo those files are present and its `CLAUDE.md` already imports the router and the
session rhythm, so both are in context at launch. **If they are not there, the repo has not been
scaffolded — do §0 first**, and read the pristine copies under this skill's `template/docs/process/`
until it has been.

What follows is only what those docs do *not* carry: the entry conditions for each job, and the
things that are true of operating this skill rather than of the method.

## 1. Author a spec

Write from `docs/templates/spec-template.md` (before scaffolding, this skill's
`template/docs/templates/spec-template.md`), then follow `docs/process/authoring-a-spec.md` — it carries
what makes a spec buildable, the 3–6 FR aim and the split above 8, and the reviewer gate that stands
between Draft and Draft-ready. Add a row to `docs/specs/INDEX.md`, and run `sh scripts/spec-lint.sh`
before handing off.

## 2. Build a spec (plan-gated)

Only when told to build — a Draft spec sitting in the repo is not a signal to start.

Follow `session-rhythm.md` from the top: it carries the fetch-and-branch step, the plan and the PR
grouping that gate the start, the run-to-completion rule, the two diff frames that gate the push, and
the local gates that run before it. `reviewer-contract.md` carries every review rule those steps
invoke — the counts per artifact, what a floor means, frame rotation, and the sweep-don't-sample rule
for a change that removes things.

🔴 **In the template repo itself, `sh scripts/check-mirror.sh` is a pre-push gate too.** CI runs it,
the scaffold's own `CLAUDE.md` cannot name it (derived projects delete it), and every edit under
`template/` owes a `sh scripts/sync-from-skill.sh` before it passes.

## 3. Watch PRs and watch main

`session-rhythm.md` → *Landing the spec*. Nothing here to add.

## 4. Completion ritual

`completion-ritual.md`, in one pass when a spec is done. Nothing here to add.

## 5. Running several agents on one repo

Only when the user asks for it. The default is one spec in flight; this is the deliberate exception.
`several-agents.md` carries why the remote is serialised, what the lock covers and what the hook
refuses; `scripts/pr-queue/PROTOCOL.md` carries the four commands, the branch-pattern setting and the
configuration seams for a project that is not on GitHub.

Install it once, before launching anyone — `sh scripts/pr-queue/install.sh` (the optional
`'<branch-regex>'` defaults to `.`, every branch; a narrowed one fails open the day branch naming
moves on) — and brief every session from `docs/templates/multi-agent-briefing.md`.

One fact about installing is worth knowing before the first run: `install.sh` exits **3**, having
installed everything else, when it could not wire the hook — a foreign `pre-push` already occupies
the path (its message says what to add by hand, and the queue is inert until someone does), the
existing wrapper names a **different** queue (left alone; the old queue stays enforced, and the
message says how to upgrade it instead), the hooks directory could not be written, or
`core.hooksPath` is relative (a wrapper there fires in the main worktree only, so linked worktrees
would push unenforced; the message gives the absolute-path remedy). Exit **1** is
a refusal before anything was copied: a blank or uncompilable pattern, or a lock held on the queue.

## 6. Delegate by model

`model-routing.md` is the authority: each artifact goes to a subagent from `.claude/agents/` on the
model that table names, the agent files carry those defaults so a plain `@agent-reviewer` gets the
right one, and when unsure it is one tier up, never down.

## spec-lint reference

`scripts/spec-lint.sh [dir]` (default `docs/specs`). **FAIL** (exit 1): a spec missing a required
section (`## Overview`, `## Scope`, `## Functional Requirements`, `## Implementation Phases`), or
containing an `Open Questions` / `Checkpoint` heading. **WARN** (exit 0): unfilled placeholders, a
spec with FRs but no acceptance criteria anywhere in it, and a spec carrying more than
`FR_CEILING` (8) distinct FRs. POSIX `sh` — no runtime dependency.

## docs-lint reference

`scripts/docs-lint.sh` (no arguments; resolves its own repo root). **FAIL** (exit 1), no WARN tier:
`CLAUDE.md` over `CLAUDE_MAX_BYTES`; anything in its Key Decisions section but intro prose and one
`| Area | Fences |` table, or that table empty; `docs/decisions/INDEX.md` missing, empty, or naming
areas that differ from the table in name, file or order; a stub at `docs/decisions.md`; an area file
with no row or a row with no file; in an area file: a title not matching the row, a `##` other than
Contents and Fences, Fences not first in Contents or not first after it, a fence over
`DIGEST_MAX_BYTES` (a bullet with its continuations joined) or of the wrong shape, a fence with no
`###` entry or an entry with no fence, an entry absent from the Contents, a pointer in Fences that
resolves to nothing; an area whose *Governs* globs have no matching rule, or a rule for an area that
governs none; a `Status: Completed` spec with no
`docs/spec-delivery/SPEC-NNN-*.md`; a delivery doc over `DELIVERY_MAX_LINES`; a relative link or `@`
pointer in an always-loaded file that resolves to nothing. On the **routed process tier** it also
fails: a `docs/process/` with no router; a stub at `docs/process.md`; a router row `CLAUDE.md` does
not import or an import the router does not name; the always-loaded set (derived from the router's
table) over `ALWAYS_LOADED_MAX_BYTES`; a bare `@` import in any always-loaded file but `CLAUDE.md`;
a part with no router row or a row with no file; a `.claude/rules/` file without frontmatter at
byte 0, with an inline or missing `paths:`, an extra key, a glob outside the four allowed forms or
matching nothing, a body that is not the two-line template, or a pointer to an unrouted part; a
`.claude/agents/` file without frontmatter, a `name` not equal to its stem, a `model` outside
`sonnet|opus|haiku|fable`, or one the routing table does not name (and the reverse). Entries labelled `(example)` are exempt, so a fresh
scaffold is green. **`scripts/docs-lint-test.sh` is its fixture corpus — run it after any change to
`docs-lint.sh`.** The linter passing against your own docs says nothing about whether its checks
work; the corpus is what says that. The budgets are **ratchets against accretion**: when one fires because a doc grew a line at a time, cut and re-ratchet at the new
measurement — never raise it to fit the edit. **After a structural CUT the regime inverts**: what remains is fences rather than accretion, so leave headroom deliberately and record why beside the number, or the next change that legitimately needs a line takes one from another area. POSIX `sh` — no runtime dependency.
