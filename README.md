# spec-driven-development-template

A **GitHub template repository** that sets up a repo for *spec-driven development with Claude*. The
method in one line: **specify a feature before building it, build it off a validated plan in reviewable
phases, review in a fresh context, land each PR on green CI, and record the result in lean, layered
docs** so the next session starts cheap.

> **This is Claude-specific by design.** It is built for Anthropic's Claude — specifically **Claude
> Code** (the agentic CLI) and **Cowork** (the desktop agent). It leans on Claude conventions that
> other assistants don't share: a `CLAUDE.md` that Claude loads automatically every session, `@docs/…`
> file-references that Claude resolves on demand, and a `.claude/skills/` folder that Claude Code reads
> to discover skills. If you don't use Claude, the Markdown is still readable, but the automation
> (auto-loading, skill discovery, the workflow behaviors) won't fire.

---

## Who this is for

You'll get the most out of this if:

- You drive development through **Claude Code and/or Cowork**, not by hand.
- You're willing to work like an **engineering manager**: you decide *what* to build and judge *whether
  it's good*; Claude does the planning and implementation in between.
- You use **Git + GitHub** with a **PR-based flow** and CI (a GitHub Actions workflow is included).

No prior knowledge of this repo is required — that's the point of this README. By the end you'll know
what every file is, why two copies of the scaffold exist, and exactly what to type in a Claude session
to use it.

## The method (what the workflow actually does)

```
specify  →  plan  →  build in phases  →  review (fresh context)  →  land on green  →  record leanly
```

- **One spec in flight at a time.** You finish and merge before starting the next.
- **Specs are fully resolved before building** — no "open questions" left to discover mid-build.
- **Builds run off a plan you approved**, generated from the spec's phases — not improvised.
- **Review happens in a fresh context** (a new session or subagent), never the session that wrote the
  code, so the reviewer isn't biased by its own work.
- **Context stays lean.** `CLAUDE.md` is small and loaded every session; everything else is pulled
  **on demand** so you're not paying tokens for docs you don't need.

## The two layers

This repo bundles two things that work together but do different jobs:

1. **The scaffold** — the actual files a project needs: `CLAUDE.md`, the `docs/` tree, `scripts/`, and
   `.github/`. These live in *every* repo and are filled in per project.
2. **The skill** (`.claude/skills/spec-driven/`) — the *behavior*. `SKILL.md` tells Claude how to
   scaffold a repo, author a spec, run a plan-gated build, watch PRs/main, and run the completion
   ritual. Committing it in the repo means **Claude Code auto-discovers it** with no install.

Think of the scaffold as the *forms and filing cabinet*, and the skill as the *trained assistant* who
knows how to fill and file them.

---

## Repository layout — what every file does

| Path | What it is | Who reads it |
|---|---|---|
| `CLAUDE.md` | **Always-loaded project memory.** Conventions, key decisions, the session workflow, and `@docs/…` pointers to everything else. Kept deliberately short. | Claude, every session (auto) |
| `docs/process.md` | The full **method** — spec lifecycle, session rhythm, review, completion ritual. Read once to understand the rhythm. | You + Claude (on demand) |
| `docs/architecture.md` | Sectioned **design reference** + "Known Constraints". Pull the *one section* you need, never the whole file. | Claude (on demand) |
| `docs/component-inventory.md` | One-line index of **reusable** modules/services/components, so a new spec reuses instead of rebuilding. | Claude (on demand) |
| `docs/best-practices/INDEX.md` | **Router** for domain coding rulebooks — match your task to a domain, then load only the sections you need. | Claude (on demand) |
| `docs/best-practices/react/react.md` | React 18/19 rulebook (✅/🔴, internal index §1–§18). | Claude (on demand) |
| `docs/best-practices/accessibility/accessibility.md` | WCAG 2.2 rulebook (Task Index → §1–§4). | Claude (on demand) |
| `docs/best-practices/python/python.md` | Python / PEP 8 rulebook (§1–§9). | Claude (on demand) |
| `docs/specs/INDEX.md` | The **spec index + status** (one row per spec; optional build-order "arcs"). | You + Claude |
| `docs/specs/SPEC-XXX-*.md` | An individual **spec** — the unit of work. You author these. | You + Claude |
| `docs/spec-delivery/SPEC-XXX-*.md` | Short **"what shipped"** note written when a spec completes. Pulled only when a later spec depends on it. | Claude (on demand) |
| `docs/templates/spec-template.md` | The blank a new spec is written from. | You |
| `docs/templates/spec-completion-template.md` | The blank a delivery doc is written from. | You + Claude |
| `scripts/spec-lint.sh` | **POSIX** linter that fails a spec missing a required section or containing a banned "Open Questions"/"Checkpoint" heading; warns on unfilled placeholders. | CI + you |
| `scripts/sync-from-skill.sh` | Maintenance script: regenerates the root scaffold from the skill's canonical copy (see below). | You (maintainer) |
| `.github/workflows/spec-lint.yml` | Runs `spec-lint.sh` on every PR and push to `main`. | CI |
| `.github/workflows/ci.yml.example` | **Inert** GitHub Actions template (Node + Python jobs). At scaffold time it becomes a real `ci.yml` that runs your formatter/linter/types/tests; the `.example` extension means GitHub never runs it as-is. | CI (once filled in) |
| `.github/pull_request_template.md` | PR checklist that restates the rules: maps-to-plan, no new open questions, tests/lint green, watch-to-green. | You + Claude |
| `.claude/skills/spec-driven/SKILL.md` | The **skill** — the workflow Claude follows. Claude Code discovers it here automatically. | Claude Code (auto) |
| `.claude/skills/spec-driven/template/` | The **canonical copy** of the entire scaffold (see "Why two copies"). | the skill |
| `.gitignore` | Ignores OS/editor cruft and common Python/Node build artifacts. | Git |

## Why the scaffold exists in two places

The scaffold lives both at the **repo root** and inside the skill at
`.claude/skills/spec-driven/template/`. This is intentional, and each copy has a distinct job:

- The **root copy** is what a project created from this template actually uses day to day.
- The **skill's copy** keeps the skill **self-contained**, so it can scaffold a *different,
  pre-existing* repo (one that wasn't created from this template) without needing this repo present.

**The skill's copy is the source of truth.** When you change the scaffold, edit the files under
`.claude/skills/spec-driven/template/`, then run:

```bash
sh scripts/sync-from-skill.sh   # mirrors the skill's template/ → repo root
```

and commit both. (Because `.claude/` can be treated as protected by some editors/agents, in practice
you may edit the root copy and copy it back into the skill — either way, keep the two identical and
commit both.)

---

## Getting started

### A) New project — "Use this template"

1. On GitHub, click **Use this template** (or clone this repo) to create your new project repo, and in
   Settings tick **Template repository** if you want others to do the same.
2. Fill in the placeholders in **`CLAUDE.md`** — Project Overview, Layout, Tech Stack, Code
   Conventions, Common Commands — to describe *your* project. Keep it lean.
3. Seed **`docs/architecture.md`** with your design; leave the rest of `docs/` as-is.
4. Make sure spec-lint runs in CI (the included `.github/workflows/spec-lint.yml`) and is executable:
   `chmod +x scripts/spec-lint.sh`.
5. **Set up language CI.** Turn `.github/workflows/ci.yml.example` into a real `.github/workflows/ci.yml`
   that runs your formatter, linter, type-checker, and tests on every PR and push to `main` — keep the
   job(s) for your languages, fill in your actual commands, delete the `.example`. The skill does this
   for you during scaffolding (it asks once what you need); you can also do it by hand.
6. Trim `docs/best-practices/` to the domains you actually use (e.g. a Python-only library doesn't need
   `react/`), and update `docs/best-practices/INDEX.md` to match.
7. Write your first spec (see "Using it in a Claude session" below).

A template-derived repo already ships the scaffold *and* the committed skill, so you **don't** run the
skill's "scaffold" mode — that mode is only for retrofitting existing repos.

### B) Existing project — retrofit with the skill

If you have a repo that wasn't made from this template, install the skill (below) and ask Claude to set
it up: *"Set this repo up for spec-driven development."* The skill copies its bundled `template/` into
your repo (without clobbering existing files), fills in `CLAUDE.md` from your actual stack, and wires
spec-lint into CI.

---

## How Claude loads and runs this

**Claude Code (CLI / agentic).**
- Reads **`CLAUDE.md`** automatically at the start of every session — that's your always-on rulebook.
- Discovers the skill at **`.claude/skills/spec-driven/SKILL.md`** automatically. Nothing to install;
  it travels with the repo.
- Resolves the **`@docs/…`** references in `CLAUDE.md` on demand — Claude only opens those files when
  the task calls for them, which is what keeps context cheap.

**Cowork (desktop agent).**
- Uses skills installed into your **capabilities** (Settings → Capabilities), which are **global across
  repos** — you install once, not per repo.
- To install: zip the `.claude/skills/spec-driven/` folder with a **`.skill`** extension and use the
  install button, or add it via Settings.
- Cowork also respects a repo's `CLAUDE.md` as project instructions.

> Heads-up: a skill installed in Cowork is **not** automatically available in Claude Code, and vice
> versa. The committed `.claude/skills/` copy covers Claude Code; the Cowork install covers Cowork.

## Using it in a Claude session — what to say

You drive the workflow by **talking to Claude**. With the skill available, these requests trigger the
matching mode (in Claude Code you can also invoke it explicitly with `/spec-driven`):

| You want to… | Say something like… | What Claude does |
|---|---|---|
| Set up an existing repo | "Set this repo up for spec-driven development." | Copies the scaffold in, fills `CLAUDE.md`, wires CI. |
| Write a spec | "Draft SPEC-007 for <feature> from the spec template." | Writes a spec with no open questions; runs spec-lint; adds the INDEX row. |
| Build a spec | "Build SPEC-007." | Reads `CLAUDE.md` + the spec, generates a plan, **asks you to confirm it**, then builds in phases on a branch/PR. |
| Review work | "Review this branch against SPEC-007 in a fresh context." | Runs review/verification in a new session or subagent against the spec's acceptance criteria + best-practices rules. |
| Finish a spec | "Run the completion ritual for SPEC-007." | Flips status, updates INDEX, writes the delivery doc, updates the component inventory. |

**Shell commands** (Claude can run these for you in-session, or you can run them yourself):

```bash
sh scripts/spec-lint.sh            # lint all specs (also runs in CI on every PR)
sh scripts/spec-lint.sh docs/specs # same, explicit path
sh scripts/sync-from-skill.sh      # maintainers: mirror the skill's scaffold copy to the repo root
```

Before Claude opens a PR it runs your project's **formatter, linter, and unit tests** locally and gets
them green — quality gates are a pre-PR step here, not something CI discovers.

## The guardrails (and where they're enforced)

| Guardrail | Enforced by |
|---|---|
| Specs are fully specified before build (no Open Questions) | `spec-lint.sh` (CI) + `process.md` |
| Builds run off a plan you approved (no per-phase checkpoints) | `process.md` + `SKILL.md` build mode |
| Emergent issues triaged by kind: reversible → decide; product-changing → escalate to you | `process.md` + `CLAUDE.md` |
| Review runs in a fresh context, not the authoring session | `process.md` + `CLAUDE.md` |
| Formatter / linter / tests green **before** a PR | `process.md` + `CLAUDE.md` + PR template |
| Every PR watched and merged on green; `main` always watched; red `main` fixed first | `process.md` + `CLAUDE.md` |
| Domain code follows the right rulebook, loading only what's needed | `best-practices/INDEX.md` + `process.md` |
| The always-loaded tier stays lean | the completion ritual in `process.md` |

## Maintaining & extending

- **Change the scaffold:** edit the canonical copy under `.claude/skills/spec-driven/template/`, run
  `sh scripts/sync-from-skill.sh`, commit both copies. Keep the root and skill copies identical.
- **Add a best-practices domain:** create `docs/best-practices/<domain>/<domain>.md` as a
  token-efficient agent reference (a short "how to use" + an internal index + ✅/🔴 rules — match the
  existing docs), then add **one row** to `docs/best-practices/INDEX.md`. The index is a router; the
  detail lives in the doc.
- **Keep `CLAUDE.md` lean:** new architectural decisions get **one line** (+ a pointer), never a
  paragraph. Reasoning belongs in the spec/delivery doc or `architecture.md`.
