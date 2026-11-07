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

**Hand a fixing agent the finding's full text, not a summary.** The fixer was not in the
reviewer's context, so a one-line relay leaves it unable to act on the finding and it has to ask for
the text. Pass each finding you have decided to fix verbatim to the agent who fixes it, with its
file:line and, where one exists, its reproducing mutation or concrete failing input. Any answer
from the human that an agent will act on or record is relayed the same way: the question as it was
put to the human and the answer, word for word, to that agent, which records it in the file it
writes (`authoring-a-spec.md`).

## Fences

- **Write `model: inherit`, never omit it.** An omitted `model` falls back to
  `CLAUDE_CODE_SUBAGENT_MODEL` when that is set; `inherit` selects the main conversation's model
  ahead of it. That order holds from Claude Code v2.1.251; before it the variable came first and
  overrode `inherit` too.
- **Pass no `model` on an Agent tool call.** A per-invocation `model` overrides the role's
  `inherit`.
- **Never set `CLAUDE_CODE_SUBAGENT_MODEL`**, with or without `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`,
  in settings or the environment. Forced, it makes every agent ignore its `model`, `inherit`
  included, and run on the model the variable names.
- **Delegate only to the roles above, never to a built-in agent.** The built-ins do not all run
  on the main model: Explore runs on Opus under a Fable session on some accounts, general-purpose
  follows `CLAUDE_CODE_SUBAGENT_MODEL`, and claude-code-guide runs on Haiku. Sweep with `scout`.
- **A reviewer started as a new session, not a subagent, is started on the model of the session that
  asked for it.** `inherit` reaches only subagents.
- `scripts/docs-lint.sh` holds the agent files to their shape: frontmatter at byte 0, `name` equal
  to the file stem, `model: inherit` and nothing else, and every agent this table names exists as a
  file and every file is named here. It also holds every row of this table to the two cells of
  `| Job | Agent |` and the section to one table, fails a row of it or an agent description that
  names a model, fails a leftover `model-routing.md` and any part or agent file that still names
  it, and fails a `.claude/settings.json` that sets `CLAUDE_CODE_SUBAGENT_MODEL` or its `_FORCE`
  twin.
