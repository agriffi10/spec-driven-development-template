# The Spec-Driven Development Process

How work gets done in this repo. `CLAUDE.md` carries the terse, always-loaded rules; the files in
this directory carry the fuller **method** they point to, one file per part. This router and
`session-rhythm.md` load **with** `CLAUDE.md` at launch — it imports them — so they are read every
session by mechanism, not by instruction. Every other part is pulled at the moment the table below
says; nothing else in `docs/` is read whole.

Goal: each feature is **specified before it's built**, built in **reviewable phases** off a
**reviewed plan**, landed as **as few PRs on green CI as the dependencies allow**, and recorded in
**lean, layered docs** so the next session starts cheap.

## Loaded every session

| File | Carries |
|---|---|
| `CLAUDE.md` | conventions, the Key Decisions digest, the gates in one line each, the pointers |
| `docs/process/INDEX.md` | this router — what loads when, and where each kind of truth lives |
| `docs/process/session-rhythm.md` | the operating loop from session start to landing the PR |

This table is the **authority** for the always-loaded set. `scripts/docs-lint.sh` derives the always-loaded set from it — the set it holds to a byte budget — and requires `CLAUDE.md`'s imports to match it row for row, so adding a row is a
visible act that costs every session — make the case in the PR. Nothing in this table, other than
`CLAUDE.md`, may carry a bare `@path` import: an import here would pull the whole tree in through
recursion, which is the cost this layout exists to avoid.

## One file per part

| File | What it holds | When to pull it |
|---|---|---|
| `docs/process/spec-lifecycle.md` | Draft → In Progress → Completed, one spec in flight, arcs and build order | when changing a spec's status, or grouping specs into an arc |
| `docs/process/authoring-a-spec.md` | what makes a spec buildable: scope, FRs with binary criteria, size, no Open Questions, the spec's one review | when writing or revising a spec |
| `docs/process/reviewer-contract.md` | the review gate in full: counts and frames, rotating the frame, briefing the reviewer, the build frame, the exit rule, the evidence | before briefing any reviewer, and when a round's findings decide the next frame |
| `docs/process/model-routing.md` | which model does which job, the complexity rule for Fable, the step-up rule, the agent roles | before delegating any artifact to a subagent |
| `docs/process/several-agents.md` | running N sessions on one repo: the PR queue, what the lock covers, briefing each session | when more than one session shares this repo |
| `docs/process/completion-ritual.md` | the six steps at spec completion, and the anti-regrowth & doc-hygiene rules | at spec completion, and before any edit to a file in the table above |
| `docs/process/operational-traps.md` | traps that pass locally and bite in CI or on deploy — project-specific, seeded as they bite | before the first CI- or deploy-dependent step of a build |
| `docs/process/ground-rules.md` | the project's load-bearing constraints | when adding a dependency or a constraint |

Every `*.md` in this directory other than the router is a row here, and every row is a file — an
unrouted part is where the next paragraph of process accretes unread, so `scripts/docs-lint.sh`
holds the two sets equal.

## Where truth lives (and why it's layered)

The docs are tiered by how often they're loaded. Keep each tier in its lane — the always-loaded tier
is deliberately small and **must not regrow**.

| Tier | File(s) | Loaded | Authoritative for |
|---|---|---|---|
| Always | `CLAUDE.md` + its two imports (the table above) | every session | conventions, key decisions, the session rhythm, what loads when |
| Status | `docs/specs/INDEX.md` + each spec header | on demand | spec **status** (one row per spec) |
| The work | `docs/specs/SPEC-XXX-*.md` | the one you're building | requirements + phases |
| Why | `docs/architecture.md` | the *section* you need | design rationale + Known Constraints |
| Decisions | `docs/decisions.md` | the *entry* for your area | settled decisions in full + reversal markers |
| Reuse | `docs/component-inventory.md` | skim for reuse | modules/services/components already built |
| Rulebooks | `docs/best-practices/INDEX.md` → domain doc | the section(s) you need | domain coding rules (React, a11y, …) |
| History | `docs/spec-delivery/SPEC-XXX-*.md` | when a dependency points to one | what a past spec shipped |
| Method | `docs/process/` — this router + `session-rhythm.md` | every session; the other parts when the table above says | how we work — the method behind CLAUDE.md's summary |

**Context discipline (session-start token cost matters):**
- Read **only the current spec** in full.
- **Never** read `architecture.md` or delivery docs whole — pull the one section you need.
- Delegate *dependency* delivery-doc reading to a subagent brief rather than loading it into the main
  loop.

**Path-scoped rules are a backstop, not the mechanism.** `.claude/rules/*.md` carries one pointer
per governed tree (specs, delivery docs, the register, this directory, the PR queue, the agents),
each firing when a matching file is opened **with the Read tool** — not when it is read through the
shell, so a session working in `cat` and `grep` never sees one, and only for a path under the
session's own working directory, so a file opened in another worktree fires nothing. The instruction to pull a part
before working in its area lives here and in `CLAUDE.md`; the rule only catches the session that
forgot.
