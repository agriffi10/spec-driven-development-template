# [Project Name] — Project Memory

Loaded every session — keep it lean. The method lives in `docs/process/`, one file per part. Its
router and the session rhythm load **with** this file (the two imports below); everything else is
pulled **on demand**, when the router's table says:

@docs/process/INDEX.md
@docs/process/session-rhythm.md

- `@docs/process/reviewer-contract.md` — the review gate in full (pull before briefing any reviewer)
- `@docs/process/model-routing.md` — which model does which job (pull before delegating anything)
- `@docs/process/completion-ritual.md` — the seven steps at spec completion + the doc-hygiene rules
- `@docs/architecture.md` — system design decisions + Known Constraints (read the section you need)
- `@docs/decisions/index.yaml` — the Key Decisions register, generated: every area's fences (one file per decision under `docs/decisions/<area>/`)
- `@docs/specs/index.yaml` — the spec index, generated from each spec's frontmatter (`sh scripts/gen-index.sh`)
- `@docs/specs/SPEC-XXX-*.md` — the spec you're implementing
- `@docs/component-inventory.md` — reusable modules/services/components already built
- `@docs/spec-delivery/SPEC-XXX-*.md` — what a past spec delivered (pull only when a dependency points to one)
- `@docs/best-practices/INDEX.md` — domain coding rulebooks (React, accessibility, …); route here, then load only the section(s) you need
- `.claude/rules/` — one path-scoped pointer per governed tree; fires when a matching file is opened with Read (a backstop, not the mechanism)
- `.claude/agents/` — the subagent roles the routing table names, each carrying its default model

---

## Project Overview

[One paragraph: what this project is and why it exists. User/business intent, not implementation
detail. Understandable by someone who has never seen the code.]

## Layout

[Where things live — app/library code, infra, tests, docs. One line each.]

## Tech Stack

[Short table or list of the stack: language + version, framework, key libraries, test/lint tooling.]
**Don't add dependencies without noting them here first.**

## Code Conventions

[The non-negotiable rules: typing/strictness, error handling, naming, file/module structure, testing
expectations. Keep to what an implementer must not violate.]

- When writing/refactoring code in a domain that has a rulebook (see `@docs/best-practices/INDEX.md`), consult it first and load only the relevant section(s) — don't reinvent or guess the rules.

## Common Commands

```bash
# build / run
# test
# lint / typecheck
# spec-lint:  sh scripts/spec-lint.sh   (its tests: sh scripts/spec-lint-test.sh)
# docs-lint:  sh scripts/docs-lint.sh
# indexes:    sh scripts/gen-index.sh   (after any frontmatter change; never edit an index by hand)
# docs-lint tests: sh scripts/docs-lint-test.sh
# pr-queue tests: sh scripts/pr-queue-test.sh; sh scripts/pr-queue/install-test.sh
```

## Specs

Each spec's frontmatter is the one authority for its status; `docs/specs/index.yaml` is generated from it.
**Current work:** [the spec in progress, or "none — next work unplanned"].

---

## Key Decisions (settled — don't re-litigate)

Settled decisions live in `docs/decisions/`, **one file per decision** in one directory per area: its
`description` is the **fence** — the claim and its constraint in one line — and its body the reasoning.
`docs/decisions/index.yaml` (generated) lists every area's fences: **read your area's before working
in it.** A new decision is a new file in its area, never a line here; a new *area* is a new directory
and a row here, in slug order. `scripts/docs-lint.sh` holds this table to the areas' titles and
refuses anything in this section but this prose and the table.

| Area | Directory |
|---|---|
| (example) Area name | `docs/decisions/example-area/` |

## Out of Scope (don't build)

[Explicit exclusions — things a reader might assume are in scope but aren't.]

---

## Session Workflow

**Start:** the session rhythm (`@docs/process/session-rhythm.md`) is loaded with this file — follow it literally: read the spec you're building in full, confirm CI is green on `main`, branch off freshly fetched `origin/main` (in a multi-agent run, in your **own worktree**, never the shared checkout), set the spec `In Progress` in that first commit, plan, and put the plan and the PR grouping through the reviewer gate before the first line of code. A decision only the human can make is asked with the **question tool** — options as selections, the recommended one first — and the build continues on the answer; a summary or a list of options that ends the turn is a stop, whatever it says. If this file and the rhythm disagree, this file wins — fix the drift there in the same session.

**Delegate, and pick the model by the job:** the main session orchestrates. Each artifact — spec, plan, code, every review, every sweep — goes to a subagent from `.claude/agents/` on the model `@docs/process/model-routing.md` names for that job (Sonnet writes specs and docs; Opus reviews, and Fable builds-and-reviews what Fable wrote; Opus implements, Fable when the complexity rule triggers; Haiku enumerates). When unsure, one tier up, never down.

**Review — three artifacts, one blocking gate:** one fresh-context review on the spec, one on the plan (plus the narrow pass on the PR grouping), **two frames** on the diff, all **before the push** — a branch does not reach the remote until every finding is **fixed or flagged** out loud, because green CI is not a review. Counts, frames, briefing lines and exit rules: `@docs/process/reviewer-contract.md`.

**PRs & main:** building a spec **authorizes the whole landing** — the push of the reviewed branch, the PR, the watch and the merge on green are the build's last steps, not decisions to confirm, so do not stop to ask for them and do not stop at announcing them. Before pushing, get the diff through the review gate above, and get the formatter, linter, typecheck and unit tests green locally, plus `sh scripts/spec-lint.sh` and **`sh scripts/docs-lint.sh` — always, before every PR, since nothing in CI runs it** (and `sh scripts/docs-lint-test.sh` or `sh scripts/spec-lint-test.sh` whenever you touch that linter). **That list is a floor, not the set** — also run locally whatever CI will run on the branch. Watch every PR to completion and merge it as soon as CI is green — never open-and-abandon. **Key the watch on the current head sha** — a bare `gh pr checks --watch` can exit clean against the *previous* commit's checks. `main` is always watched: after any merge confirm it went green, and if `main` fails, diagnose immediately and fix it with a new PR before anything else. **When several agent sessions share this repo**, install `scripts/pr-queue/install.sh` once and the remote is serialised by a PR queue — one PR open at a time, taken in the order agents asked, `main` green before the next — and you get in line only once your gates and reviews are green, because the queue is not a review. Until it is installed the queue is inert; once it is, its `pre-push` hook refuses a push whose commits do not contain the remote's current `main`. Protocol and the four commands: `scripts/pr-queue/PROTOCOL.md`; brief each session from `@docs/templates/multi-agent-briefing.md`.

**On spec completion:** run the seven steps in `@docs/process/completion-ritual.md` — `spec_status`, regenerated indexes, delivery doc, inventory row, a decision as one file — fence and entry together, an ADR row only when the system's shape changed, and a prune of `## Specs` above (never an append).

**Doc-size guardrail:** this file and its two imports are every session's fixed cost. `scripts/docs-lint.sh` holds the set **the router's table names** to a byte budget, holds Key Decisions to an intro and one area table, every decision to its frontmatter and an entry behind its fence, every generated index to its frontmatter, and `docs/process/`, `.claude/rules/` and `.claude/agents/` to their shapes. Run it locally before every push; it is not a CI job. When a budget fires, move detail down a tier behind a pointer and re-ratchet; after a structural cut leave headroom and say why beside the number. Full rule set: `@docs/process/completion-ritual.md` → *Anti-regrowth & doc hygiene*.
