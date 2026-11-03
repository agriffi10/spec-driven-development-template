# Agent roles — which agent does which job

The main session is an **orchestrator**. When it is given a task it delegates each artifact — the
spec, the plan, the code, every review, every sweep — to a subagent in the role the **job** calls
for, and keeps for itself only what the process assigns to the orchestrator: triage of emergent
issues, escalation to the human, the push, the watch and the merge.

**Every subagent runs on the model that started the task.** The roles live in `.claude/agents/` and
each declares `model: inherit`, which selects the main conversation's model. A role differs from
another by its brief, its tools and its isolation, never by its model.

## The table

| Job | Agent |
|---|---|
| Write or revise a spec | `spec-author` |
| Review a spec (its one gate) | `reviewer` |
| Write the implementation plan | `implementer` |
| Review the plan; review the PR grouping | `reviewer` |
| Implement, or rewrite under review pressure | `implementer` |
| Diff review, frame 1 — read the change against the criteria and the rulebooks | `reviewer` |
| Diff review, frame 2 — build it and run the suites | `reviewer` |
| Completion ritual, delivery doc, any docs-only change | `spec-author` |
| Enumerate a population, measure, sweep, find every site of a rule | `scout` |

**Precedence.** Rows are read top-down against the artifact. A change whose diff contains code is
*implementation*, whatever documents it also touches; a change with no code in its diff is
*docs-only*. A review is always a `reviewer` row, whatever produced the artifact.

## Fences

- **Write `model: inherit`, never omit it.** An omitted `model` falls back to
  `CLAUDE_CODE_SUBAGENT_MODEL` when that is set; `inherit` selects the main conversation's model
  ahead of it.
- **Pass no `model` on an Agent tool call.** A per-invocation `model` overrides the role's
  `inherit`.
- **Never set `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`** in this repo's settings: it makes every agent
  ignore its `model`, `inherit` included.
- **Sweep with `scout`, not the built-in Explore.** Explore does not always run on the main model —
  under a Fable session on some accounts it runs on Opus — while `scout` inherits.
- `scripts/docs-lint.sh` holds the agent files to their shape: frontmatter at byte 0, `name` equal
  to the file stem, `model: inherit` and nothing else, and every agent this table names exists as a
  file and every file is named here.
