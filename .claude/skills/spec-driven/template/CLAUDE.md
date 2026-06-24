# [Project Name] — Project Memory

Loaded every session — keep it lean. Deep docs live in `docs/` and are pulled **on demand**:
- `@docs/process.md` — how we work: spec lifecycle, session rhythm, completion ritual (read once)
- `@docs/architecture.md` — system design decisions + Known Constraints (read the section you need)
- `@docs/specs/INDEX.md` — the spec index + status (one row per spec)
- `@docs/specs/SPEC-XXX-*.md` — the spec you're implementing
- `@docs/component-inventory.md` — reusable modules/services/components already built
- `@docs/spec-delivery/SPEC-XXX-*.md` — what a past spec delivered (pull only when a dependency points to one)

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

## Key Decisions (settled — don't re-litigate; detail in the linked spec/architecture)

- [One line per settled decision, each with a pointer to the spec/architecture section that holds the
  reasoning. Never a paragraph here.]

## Out of Scope (don't build)

[Explicit exclusions — things a reader might assume are in scope but aren't.]

---

## Session Workflow

**Start:** (1) this file; (2) the spec you're implementing (`@docs/specs/SPEC-XXX`); (3) skim `@docs/component-inventory.md` for reuse and pull only the architecture.md section / dependency delivery-doc you need — don't read architecture.md or delivery docs in full. (4) Confirm CI is green on `main`; investigate failures before building. (5) Branch from fresh `main`. (6) Generate an implementation plan from the spec's phases, validate it against the spec (FRs + acceptance criteria covered, reuse used, nothing out of scope), and confirm it before writing code.

**During:** every file-changing task goes on its own branch and opens a PR — never commit to `main` directly. After a phase, stop and summarize what was built and how it maps to the plan. Specs carry no Open Questions — triage emergent issues by kind: **reversible/technical** ones you decide in-session (update the spec if scope changes); **product-changing or ambiguous** ones you stop and escalate to the human with options + a recommendation, never silently decide.

**Review:** code review and verification run in a **fresh context** (new session or subagent), never the session that wrote the code — check the diff against the spec's acceptance criteria, not just "looks fine."

**PRs & main:** watch every PR to completion and merge it as soon as CI is green — never open-and-abandon. `main` is always watched: after any merge confirm it went green, and if `main` fails, diagnose immediately and fix it with a new PR before anything else.

**On spec completion — keep the always-loaded files lean:**
1. Set the spec file's `Status: Completed`.
2. Update the one-line row in `@docs/specs/INDEX.md` (status only — don't add prose).
3. Write a short delivery doc at `docs/spec-delivery/SPEC-XXX-<name>.md` from the template.
4. If it added reusable modules/services/components, add a one-line row to `@docs/component-inventory.md`.
5. A *new architectural decision* gets one line in Key Decisions above (+ a pointer) — never a paragraph.
