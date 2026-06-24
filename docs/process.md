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
| Reuse | `docs/component-inventory.md` | skim for reuse | modules/services/components already built |
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

- **Draft** — written and refined, but **do not build until told.** Specs are often authored well
  ahead of implementation. A Draft spec sitting in the repo is not a signal to start it. A spec is not
  Draft-ready while it still has unresolved questions (see §4).
- **In Progress** — exactly one spec at a time is in flight. Set when you branch to build it.
- **Completed** — merged on green CI, delivery doc written (see §5).

**Arcs.** Related specs can be grouped into *arcs* with an explicit **build order** documented in
`INDEX.md`. Build in that order; arcs can have non-obvious dependencies.

---

## 3. The session rhythm

This is the operating loop, start to finish. CLAUDE.md's *Session Workflow* is the condensed version.

**Start of session**
1. Read CLAUDE.md, then the **current** spec in full. Don't infer scope from a prior conversation —
   read the spec file as it exists now.
2. Skim `component-inventory.md` for reuse; pull only the `architecture.md` section / dependency
   delivery-doc you actually need.
3. Confirm CI is green on `main`. Investigate failures before building.
4. **Branch from fresh `main`.**
5. **Generate and validate a plan before writing code.** Turn the spec's Implementation Phases into a
   concrete implementation plan, then validate it against the spec — every FR + acceptance criterion is
   covered, reuse from `component-inventory.md` is used, and nothing out of scope crept in. Confirm the
   plan before building. The validated plan — not per-phase checkpoints baked into the spec — is what
   gates the work.

**During the build — one spec, in phases**
- Every file-changing task is done on its **own branch** and opened as a **PR** — automatically, without
  waiting to be asked. Never commit to `main` directly.
- Work the validated plan's phases in order. After each phase, **stop and summarize** what was built and
  how it maps back to the plan before continuing.
- Specs ship with **no Open Questions** — they're resolved during authoring (§4). An issue that emerges
  mid-build is handled in the session: resolve it, note the decision, and if it changes scope or
  contradicts the spec, **update the spec** rather than leaving the divergence implicit.

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
  parked in the spec.

`scripts/spec-lint.sh` enforces the structural side of this in CI: it **fails** a spec that is missing
a required section or that contains an "Open Questions" / "Checkpoint" heading, and **warns** on
unfilled placeholders or FRs without acceptance criteria.

---

## 5. Completion ritual (keep the always-loaded tier lean)

When a spec is done, in the same pass:
1. Set the spec file header `Status: Completed`.
2. Update its one-line row in `docs/specs/INDEX.md` (**status only** — no prose).
3. Write a **short** delivery doc at `docs/spec-delivery/SPEC-XXX-<name>.md` from
   `docs/templates/spec-completion-template.md` — *what shipped + what changed*, under ~40 lines, **no
   code/config pasted** (the code + component-inventory are the source of truth for reuse).
4. If reusable modules/services/components were added, add a **one-line** row to
   `docs/component-inventory.md`.
5. A *new architectural decision* gets **one line** in CLAUDE.md's Key Decisions (+ a pointer) — never a
   paragraph. Reasoning lives in the spec/delivery doc.

**Anti-regrowth.** If a doc disagrees with the code, fix or delete it — don't let stale state
accumulate. Don't add prose to the always-loaded tier.

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
