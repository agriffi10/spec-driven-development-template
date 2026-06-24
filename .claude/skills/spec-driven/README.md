# spec-driven (skill)

The **behavior** layer of the [spec-driven-development-template](../../../README.md): the workflow
Claude follows to author specs, run plan-gated builds, review in a fresh context, watch PRs/main, and
run the completion ritual. The full method and rationale live in the top-level `README.md` and in
`docs/process.md`.

## Files here

- **`SKILL.md`** — the workflow Claude executes. **Claude Code auto-discovers it** at this path
  (`.claude/skills/spec-driven/SKILL.md`) — no install needed in a repo that contains it.
- **`template/`** — the **canonical copy** of the repo scaffold (`CLAUDE.md`, `docs/`, `scripts/`,
  `.github/`). It lives here so the skill is self-contained and can scaffold a *different, pre-existing*
  repo. This is the **source of truth**; the repo root mirrors it (run `scripts/sync-from-skill.sh`
  after editing here, and commit both).

## Using it

- **Claude Code:** available automatically. Invoke explicitly with `/spec-driven`, or just describe the
  task ("draft a spec for X", "build SPEC-007", "run the completion ritual") and it triggers.
- **Cowork:** install once into Settings → Capabilities (global across repos). Zip this `spec-driven/`
  folder with a `.skill` extension and use the install button, or add it via settings. A Cowork install
  is separate from Claude Code's auto-discovery.
