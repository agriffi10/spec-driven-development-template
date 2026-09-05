# Model routing — which model does which job

The main session is an **orchestrator**. When it is given a task it delegates each artifact — the
spec, the plan, the code, every review, every sweep — to a subagent on the model the **job** calls
for, and keeps for itself only what the process assigns to the orchestrator: triage of emergent
issues, escalation to the human, the push, the watch and the merge. The model is chosen by the job,
never by habit and never by whatever the parent happens to run on. The fallback direction is **up**:
an unsure call goes one tier stronger, because a weak model's mistake costs a review round and a
strong model's surplus costs tokens.

The roles live in `.claude/agents/` and each carries its default `model` in frontmatter, so a plain
`@agent-reviewer` gets the right model without this table being read. A per-invocation `model` on
the Agent tool overrides the default — that is how the Fable rows below are applied.

## The table

| Job | Model | Agent |
|---|---|---|
| Write or revise a spec | Sonnet | `spec-author` |
| Review a spec (its one gate) | Opus | `reviewer` |
| Write the implementation plan | Opus — Fable when the **spec alone** triggers the complexity rule | `implementer` |
| Review the plan; review the PR grouping | Opus | `reviewer` |
| Implement — default | Opus | `implementer` |
| Implement — the complexity rule triggers | Fable | `implementer`, `model: fable` per invocation |
| Diff review, frame 1 — read the change against the criteria and the rulebooks | Opus | `reviewer` |
| Diff review, frame 2 — build it and run the suites | Opus | `reviewer` |
| A rewrite under review pressure — a *replacement*, not a fix in place | Fable | `implementer`, `model: fable` |
| Completion ritual, delivery doc, any docs-only change | Sonnet | `spec-author` |
| Enumerate a population, measure, sweep, find every site of a rule | Haiku | `scout` |

**Precedence.** Rows are read top-down against the artifact. A change whose diff contains code is
*implementation*, whatever documents it also touches; a change with no code in its diff is
*docs-only*. A review is always a `reviewer` row, whatever produced the artifact.

## The complexity rule — implement on Fable when any one holds

1. The change touches **concurrency or locking**, process **lifecycle or deploy-time wiring**,
   **auth, permissions or secrets**, or a **data migration** or other irreversible change to data.
2. The spec requires an **execution harness** — the reviewer contract's rule for lifecycle,
   concurrency and deploy-time work.
3. The work **crosses a module boundary the spec did not name**.
4. The plan reviewer flagged a **premise nobody has checked**.
5. A previous attempt at the **same phase has failed review twice**.
6. The change is a **replacement** written under review pressure (the row above) — the
   least-reviewed artifact in the loop gets the strongest author.

Triggers 1–3 are properties of the spec and are read when the plan is written, so they decide the
plan's model as well as the implementation's. Triggers 4–6 arise during the build and decide the
implementation's model from that point on. Otherwise: Opus.

## The step-up rule

When two rounds on one artifact return the same **class** of finding, the reviewer contract says the
frame rotates — never a third same-frame round. **The rotated frame's reviewer also runs one tier
up** (Opus → Fable), and the fix that answers it is authored one tier up. The recurrence is evidence
the tier is exhausted, which is the same signal the rotation rule reads, so both respond at once.

## Fences

- **Never down.** Nothing is delegated to a tier below the table's row for that job. If a row's
  model is unavailable, go up, not down.
- **The user's standing rule is that Opus reviews code**, both frames, including code an implementer
  wrote on Fable. The step-up rule is the pressure valve when that reviewer's findings recur.
- **Never set `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`** in this repo's settings: it makes every agent
  ignore its `model` and silently overrides every row above.
- `scripts/docs-lint.sh` holds the agent files to their shape: frontmatter at byte 0, `name` equal
  to the file stem, `model` one of `sonnet`, `opus`, `haiku`, `fable` (`inherit` is refused — it
  defeats routing), and every agent this table names exists as a file and every file is named here.
