# spec-driven-development-template

A GitHub **template repository** for spec-driven development: specify a feature before building it,
build it off a **validated plan** in reviewable phases, land each PR on green CI, and record it in
**lean, layered docs** so the next session starts cheap.

It bundles two things, versioned together:

- **The scaffold** (repo root: `CLAUDE.md`, `docs/`, `scripts/`, `.github/`) — the files a project
  needs. Creating a repo from this template delivers them ready to fill in.
- **The skill** (`.claude/skills/spec-driven/`) — the *behavior*: how to author a spec, run a
  plan-gated build, watch PRs/main, and run the completion ritual. Committing it here means **Claude
  Code automatically discovers it** in any repo made from this template.

## Use it for a new project

1. **Use this template** on GitHub (or clone) to create your new repo.
2. Fill in the placeholders in `CLAUDE.md` — Project Overview, Layout, Tech Stack, Code Conventions,
   Common Commands — from what your project actually is.
3. Seed `docs/architecture.md` with your design; leave the rest of `docs/` as-is.
4. Confirm spec-lint runs in CI (the included `.github/workflows/spec-lint.yml`), and `chmod +x
   scripts/spec-lint.sh` if needed.
5. Write your first spec from `docs/templates/spec-template.md`, add its row to `docs/specs/INDEX.md`,
   and run `sh scripts/spec-lint.sh`.

A repo created from this template already has the scaffold *and* the committed skill, so you don't run
the skill's "scaffold" mode — that mode is for retrofitting **existing** repos that weren't created
from this template.

## How the skill reaches each tool

- **Claude Code** auto-discovers project skills at `.claude/skills/<name>/SKILL.md`. Because the skill
  is committed here, every template-derived repo gets the workflow in code sessions for free — nothing
  to install.
- **Cowork** uses skills installed into your capabilities (Settings → Capabilities), which are global
  across repos. Install it once from `.claude/skills/spec-driven/` (zip the folder with a `.skill`
  extension and use the install button, or add it via settings). You do **not** copy it per-repo.

## What the guardrails enforce

- **Specs are fully specified before build** — no Open Questions section; `spec-lint` fails on one.
- **Builds run off a validated plan** — phases are the plan's input; no per-phase checkpoints baked in.
- **Every PR is watched and merged on green; `main` is always watched** — a red `main` is fixed
  immediately with a new PR before anything else.
- **The always-loaded tier stays lean** — deep docs are pulled on demand; the completion ritual keeps
  `CLAUDE.md` from regrowing.

## Layout

```
.
├── README.md                         # this file
├── .gitignore
├── CLAUDE.md                         # always-loaded project memory (fill placeholders)
├── scripts/
│   ├── spec-lint.sh                  # POSIX structural linter for specs
│   └── sync-from-skill.sh            # regenerate root scaffold from the skill copy (maintainers)
├── docs/
│   ├── process.md                    # the full method (read once)
│   ├── architecture.md               # sectioned design reference (stub)
│   ├── component-inventory.md        # reuse index
│   ├── best-practices/              # domain coding rulebooks (agent references)
│   │   ├── INDEX.md                 # router: pick one doc + only the sections you need
│   │   ├── react/react.md           # React 18/19 rules
│   │   └── accessibility/accessibility.md  # WCAG 2.2 rules
│   ├── specs/INDEX.md                # spec index + status
│   ├── spec-delivery/                # one short delivery doc per completed spec
│   └── templates/
│       ├── spec-template.md
│       └── spec-completion-template.md
├── .github/
│   ├── workflows/spec-lint.yml
│   └── pull_request_template.md
└── .claude/
    └── skills/
        └── spec-driven/
            ├── SKILL.md              # the workflow (Claude Code reads this)
            └── template/             # CANONICAL copy of the scaffold (source of truth)
```

## Source of truth & keeping copies in sync

The scaffold exists in two places by design: at the repo root (what a derived project uses) and inside
the skill at `.claude/skills/spec-driven/template/` (so the skill is self-contained and can retrofit
other repos). **The skill's copy is canonical.** When you change the scaffold, edit the skill's
`template/`, then run `sh scripts/sync-from-skill.sh` to mirror it to the root, and commit both.
