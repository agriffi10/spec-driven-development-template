---
name: spec-driven
description: >-
  Spec-driven development workflow with guardrails. Use when (a) setting up / bootstrapping a repo for
  spec-driven work, (b) authoring or refining a spec, (c) starting to build a spec, or (d) completing a
  spec. Provides a template repo layout (CLAUDE.md, layered docs/, spec + completion templates), a
  POSIX spec-lint, and a CI workflow + PR template. Enforces: specs are fully specified before build
  (no Open Questions), builds run off a validated plan (no per-phase checkpoints baked into the spec),
  every PR is watched and merged on green, and main is always watched. Triggers on phrases like "set up
  spec-driven", "scaffold the docs structure", "write a spec", "start SPEC-XXX", "build this spec",
  "complete the spec / run the completion ritual".
---

# Spec-Driven Development

A workflow for shipping features as: **specify → plan → build in reviewable phases → land on green →
record leanly.** This skill carries the scaffold under `template/` and the rules for operating it. The
goal is a small always-loaded context (`CLAUDE.md`) backed by layered, on-demand docs.

Read `template/docs/process.md` for the full method. The four jobs below are the operating modes.

## 0. Scaffold a repo (bootstrap)

When a repo has no spec-driven docs yet:

1. Copy the contents of this skill's `template/` into the repo root: `CLAUDE.md`, `docs/`, `scripts/`,
   `.github/`. **Do not clobber** existing files — if `CLAUDE.md`, a PR template, or a workflow already
   exists, merge rather than overwrite, and tell the user what you merged.
2. `chmod +x scripts/spec-lint.sh`.
3. Fill in the placeholders in `CLAUDE.md` (Project Overview, Layout, Tech Stack, Code Conventions,
   Common Commands) from what the repo actually is — detect the language/build/test/lint tooling from
   the manifest (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, …) rather than guessing.
4. Seed `docs/architecture.md` from any existing design notes the repo already has; otherwise leave the
   sectioned stub.
5. Wire `spec-lint` into CI. If the repo already has a CI workflow, add the spec-lint step there too (or
   keep the standalone `spec-lint.yml` — either is fine, but it must run on PRs).
6. Run `sh scripts/spec-lint.sh` to confirm it passes (it no-ops cleanly when there are no specs yet).

Keep the always-loaded tier (`CLAUDE.md`) lean — it must not regrow into a wall of prose.

## 1. Author a spec

Write from `template/docs/templates/spec-template.md`. A spec is *buildable* when:

- **Overview** states user/business intent, no implementation detail.
- **Scope** lists In and **Out** explicitly (especially things a reader would assume are in).
- **Functional Requirements** are granular, each with binary pass/fail **Acceptance Criteria** covering
  happy/error/edge paths, sequential IDs.
- **Data Model / Interface Contract** uses language-native types, not prose.
- **Implementation Phases** are reviewable units — the *input to the build-time plan*. Do **not** write
  per-phase checkpoints.
- **No Open Questions.** Resolve every decision while authoring. If something genuinely can't be
  resolved, that means the spec isn't Draft-ready — get the answer, don't park it.

Add a row to `docs/specs/INDEX.md`. Before handing off, run `sh scripts/spec-lint.sh` — it fails on
missing sections or an "Open Questions"/"Checkpoint" heading.

## 2. Build a spec (plan-gated)

Only when told to build (a Draft spec sitting in the repo is not a signal to start).

1. Read `CLAUDE.md`, then the **current spec in full**. Skim `component-inventory.md`; pull only the
   `architecture.md` section / dependency delivery-doc you need — never the whole file.
2. Confirm CI is green on `main`; investigate failures first.
3. Branch from fresh `main`.
4. **Generate an implementation plan from the spec's phases and validate it against the spec** — every
   FR + acceptance criterion covered, reuse used, nothing out of scope. **Confirm the plan before
   writing code.** This validated plan replaces per-phase checkpoints.
5. Work phases in order; each file-changing task on its own branch → PR. After each phase, stop and
   summarize what was built and how it maps to the plan.
6. Triage emergent issues by kind: **reversible/technical** → decide in-session (update the spec
   if scope changes); **product-changing/ambiguous** → stop and escalate to the human with options
   + a recommendation, never silently decide.
7. **Review in a fresh context.** Code review and verification run in a new session or subagent —
   never the one that wrote the code — checking the diff against the spec's acceptance criteria. A
   self-reviewing agent rubber-stamps its own work.

## 3. Watch PRs and watch main

- Watch **every** PR to completion; merge it as soon as CI is green. Never open-and-abandon.
- After any merge, confirm `main` went green. If `main` fails, **diagnose immediately and fix with a new
  PR before anything else** — a red `main` is top priority and blocks the next spec.
- Re-verify `main` is green before starting the next spec.

## 4. Completion ritual (keep the always-loaded tier lean)

In one pass when a spec is done:
1. Spec header `Status: Completed`.
2. Update its one-line row in `docs/specs/INDEX.md` (status only).
3. Write a short delivery doc at `docs/spec-delivery/SPEC-XXX-<name>.md` (< ~40 lines, no code pasted).
4. If reusable components were added, add a one-line row to `docs/component-inventory.md`.
5. A new architectural decision → one line in `CLAUDE.md` Key Decisions (+ pointer). Never a paragraph.

## spec-lint reference

`scripts/spec-lint.sh [dir]` (default `docs/specs`). **FAIL** (exit 1): a spec missing a required
section (`## Overview`, `## Scope`, `## Functional Requirements`, `## Implementation Phases`), or
containing an `Open Questions` / `Checkpoint` heading. **WARN** (exit 0): unfilled placeholders, FRs
without acceptance criteria. POSIX `sh` — no runtime dependency.
