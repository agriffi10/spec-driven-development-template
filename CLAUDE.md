# [Project Name] — Project Memory

Loaded every session — keep it lean. Deep docs live in `docs/` and are pulled **on demand**, except
`process.md`, which is the contract this file summarises:
- `@docs/process.md` — how we work: spec lifecycle, session rhythm, completion ritual (**read every session**)
- `@docs/architecture.md` — system design decisions + Known Constraints (read the section you need)
- `@docs/decisions.md` — the Key Decisions register in full (the digest below is one line each)
- `@docs/specs/INDEX.md` — the spec index + status (one row per spec)
- `@docs/specs/SPEC-XXX-*.md` — the spec you're implementing
- `@docs/component-inventory.md` — reusable modules/services/components already built
- `@docs/spec-delivery/SPEC-XXX-*.md` — what a past spec delivered (pull only when a dependency points to one)
- `@docs/best-practices/INDEX.md` — domain coding rulebooks (React, accessibility, …); route here, then load only the section(s) you need

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
```

## Specs

Index + status: `@docs/specs/INDEX.md`. Each spec file's header carries its own `Status`.
**Current work:** [the spec in progress, or "none — next work unplanned"].

---

## Key Decisions (settled — don't re-litigate)

One line each — a digest of the full entry in `@docs/decisions.md`; read the entry before working in
that area. A line here is **never the only home of a fact**, and never a paragraph.

- [One line per settled decision, bold label matching its `decisions.md` heading.]

## Out of Scope (don't build)

[Explicit exclusions — things a reader might assume are in scope but aren't.]

---

## Session Workflow

**Start:** (1) this file, then **`@docs/process.md` — read it every session, not once**: it is the contract this file only summarises; (2) the spec you're implementing (`@docs/specs/SPEC-XXX`); (3) skim `@docs/component-inventory.md` for reuse and pull only the architecture.md section / dependency delivery-doc you need — don't read architecture.md or delivery docs in full. (4) Confirm CI is green on `main`; investigate failures before building. (5) Branch from fresh `main`, and set the spec's `Status: In Progress` + its INDEX row in that first commit. (6) Generate an implementation plan from the spec's phases, validate it against the spec (FRs + acceptance criteria covered, reuse used, nothing out of scope), **send it to one fresh-context reviewer**, then build. (7) Send the **PR grouping** to a reviewer too, before the first push — as few PRs as the dependencies allow.

**During:** those two reviews are the only gates on *starting*, so **build straight through to completion**, summarizing a phase in passing but never ending the turn on it (a summary that ends the turn *is* a request for approval). Every file-changing task goes on its own branch and opens a PR — never commit to `main` directly. Specs carry no Open Questions — triage emergent issues by kind: **reversible/technical** ones you decide in-session (update the spec if scope changes); **product-changing or ambiguous** ones you stop and escalate to the human with options + a recommendation, never silently decide.

**Review — three artifacts, one blocking gate:** a **spec**, an implementation **plan** and a **diff** each go to a reviewer in a **fresh context** (new session or subagent), never the context that produced them. **Counts: one on the spec, one on the plan, two on the diff** — two *frames*, not two rounds, both before the push; the diff gets two because it is the only one of the three whose defects reach `main`, and two is the floor, not the cap. A spec is not Draft-ready, a plan does not start code, and **a branch does not reach the remote**, until every finding is either **fixed** or **flagged** — a rejection costs a sentence out loud, and only goes in writing when it carries a lesson worth keeping. **The diff review gates the PUSH, not the merge**, because **green CI is not a review**: it cannot see a test that passes against the bug it claims to catch, a lock taken in the wrong order, or an acceptance criterion ticked with no evidence. Cap same-frame rounds at two, then rotate the frame; exit on the *class* of finding shrinking, never on a round count. Brief the reviewer that "this is sound" is a valid verdict, make it cite where it looked, and tell round N+1 what round N fixed. One rotation must **build** the thing, not read it — and every reviewer runs the repo's gates against the branch. When the risk is what a change *removed*, enumerate the population with a sweep instead of reviewing a sample. Full contract: `@docs/process.md` §3 → *The reviewer contract*.

**PRs & main:** before pushing, get the diff through the review gate above, and get the formatter, linter, typecheck and unit tests green locally. Watch every PR to completion and merge it as soon as CI is green — never open-and-abandon. **Key the watch on the current head sha** — a bare `gh pr checks --watch` can exit clean against the *previous* commit's checks. `main` is always watched: after any merge confirm it went green, and if `main` fails, diagnose immediately and fix it with a new PR before anything else.

**On spec completion — keep the always-loaded files lean:**
1. Set the spec file's `Status: Completed`.
2. Update the one-line row in `@docs/specs/INDEX.md` (status only — don't add prose).
3. Write a short delivery doc at `docs/spec-delivery/SPEC-XXX-<name>.md` from the template.
4. If it added reusable modules/services/components, add a one-line row to `@docs/component-inventory.md`.
5. A *new architectural decision* gets its full entry in `docs/decisions.md` **first**, then one line in Key Decisions above — the line is never the only home of a fact, and never a paragraph. If it supersedes an earlier decision, add an in-place superseded marker at every doc site still stating the old claim.
6. If it changed the **shape** of the system — a piece added or removed, a boundary moved, a mechanism swapped — add an append-only row to `@docs/architecture.md` → *Architecture Decision Record* and fix the prose section it contradicts. Most decisions do not qualify.

**Doc-size guardrail:** this is the always-loaded file — if an edit pushes a section past a few lines,
the detail belongs in a `docs/` file behind a pointer. Same for `INDEX.md` (status rows only) and the
component inventory. **Key Decisions is grouped by AREA and carries fences, not history** — it is not
a per-spec changelog, and `## Specs` is not one either; both regrow by being appended to, one
completion at a time. Full rule set: `@docs/process.md` §5 → *Anti-regrowth & doc hygiene*.
