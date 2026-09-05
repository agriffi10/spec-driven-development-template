# [Project Name] — Project Memory

Loaded every session — keep it lean. The method lives in `docs/process/`, one file per part. Its
router and the session rhythm load **with** this file (the two imports below); everything else is
pulled **on demand**, when the router's table says:

@docs/process/INDEX.md
@docs/process/session-rhythm.md

- `@docs/process/reviewer-contract.md` — the review gate in full (pull before briefing any reviewer)
- `@docs/process/model-routing.md` — which model does which job (pull before delegating anything)
- `@docs/process/completion-ritual.md` — the six steps at spec completion + the doc-hygiene rules
- `@docs/architecture.md` — system design decisions + Known Constraints (read the section you need)
- `@docs/decisions.md` — the Key Decisions register in full (the digest below is one line each)
- `@docs/specs/INDEX.md` — the spec index + status (one row per spec)
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
# spec-lint:  sh scripts/spec-lint.sh
# docs-lint:  sh scripts/docs-lint.sh
# docs-lint tests: sh scripts/docs-lint-test.sh
```

## Specs

Index + status: `@docs/specs/INDEX.md`. Each spec file's header carries its own `Status`.
**Current work:** [the spec in progress, or "none — next work unplanned"].

---

## Key Decisions (settled — don't re-litigate)

One line each — a digest of the full entry in `@docs/decisions.md`; read the entry before working in
that area. A line here is **never the only home of a fact**, and never a paragraph.

**Grouped by AREA, not by spec.** `scripts/docs-lint.sh` holds this section to that shape: an
`### ` area heading, `- **Label** — …` bullets at column 0, indented continuations, blank lines,
and plain prose here in the intro. A table, blockquote, fenced block, ordered list or bare bullet
is refused — each one was a way past the checks. Rename the area below and replace the example.

### (example) Area name

- **(example) Decision label** — the claim and its fence in one line, matching the `###` heading of
  its full entry in `@docs/decisions.md`. Delete this once the first real decision lands.

## Out of Scope (don't build)

[Explicit exclusions — things a reader might assume are in scope but aren't.]

---

## Session Workflow

**Start:** the session rhythm (`@docs/process/session-rhythm.md`) is loaded with this file — follow it literally: read the spec you're building in full, confirm CI is green on `main`, branch from fresh `main` (in a multi-agent run, in your **own worktree** off `origin/main`, never the shared checkout), set the spec `In Progress` in that first commit, plan, and put the plan and the PR grouping through the reviewer gate before the first line of code. If this file and the rhythm disagree, this file wins — fix the drift there in the same session.

**Delegate, and pick the model by the job:** the main session orchestrates. Each artifact — spec, plan, code, every review, every sweep — goes to a subagent from `.claude/agents/` on the model `@docs/process/model-routing.md` names for that job (Sonnet writes specs and docs; Opus reviews; Opus implements, Fable when the complexity rule triggers; Haiku enumerates). When unsure, one tier up, never down.

**Review — three artifacts, one blocking gate:** one fresh-context review on the spec, one on the plan (plus the narrow pass on the PR grouping), **two frames** on the diff, all **before the push** — a branch does not reach the remote until every finding is **fixed or flagged** out loud, because green CI is not a review. Counts, frames, briefing lines and exit rules: `@docs/process/reviewer-contract.md`.

**PRs & main:** before pushing, get the diff through the review gate above, and get the formatter, linter, typecheck and unit tests green locally, plus `sh scripts/spec-lint.sh` and **`sh scripts/docs-lint.sh` — always, before every PR, since nothing in CI runs it** (and `sh scripts/docs-lint-test.sh` whenever you touch the linter). Watch every PR to completion and merge it as soon as CI is green — never open-and-abandon. **Key the watch on the current head sha** — a bare `gh pr checks --watch` can exit clean against the *previous* commit's checks. `main` is always watched: after any merge confirm it went green, and if `main` fails, diagnose immediately and fix it with a new PR before anything else. **When several agent sessions share this repo**, install `scripts/pr-queue/install.sh` once and the remote is serialised by a PR queue — one PR open at a time, taken in the order agents asked, `main` green before the next — and you get in line only once your gates and reviews are green, because the queue is not a review. Until it is installed the queue is inert. Protocol and the four commands: `scripts/pr-queue/PROTOCOL.md`; brief each session from `@docs/templates/multi-agent-briefing.md`.

**On spec completion:** run the six steps in `@docs/process/completion-ritual.md` — status, INDEX row, delivery doc, inventory row, register entry **before** its digest line, and an ADR row only when the system's shape changed.

**Doc-size guardrail:** this file and its two imports are every session's fixed cost. `scripts/docs-lint.sh` holds the set **the router's table names** to a byte budget, holds Key Decisions to its shape with a register entry behind every line (`@docs/decisions.md`), and holds `docs/process/`, `.claude/rules/` and `.claude/agents/` to theirs — run it locally before every push, it is not a CI job. When a budget fires, move detail down a tier behind a pointer and re-ratchet; after a structural cut leave headroom and say why beside the number. Full rule set: `@docs/process/completion-ritual.md` → *Anti-regrowth & doc hygiene*.
