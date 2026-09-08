# Key Decisions — the register

The settled decisions, in full, one file per **area**. Each area file opens with its **Fences** — one
line per decision, the claim and its constraint — and carries the full entries behind them: the
reasoning, what was rejected, the "do NOT build" lines. `CLAUDE.md`'s Key Decisions table names the
areas; `scripts/docs-lint.sh` holds that table, this one and the files to each other. Pull the area
you are working in — you rarely need them all. **Don't re-litigate these.**

Rules that keep the register useful (each earned by a real failure in a project run this way):

- **Entry first, fence second.** Write the `###` entry in the area file *before* adding its line
  under `## Fences`. A fence is never the only home of a fact — a register whose fences outgrow its
  entries has inverted.
- **One `###` heading per entry**, listed in the file's Contents, its label matching the bold label
  of its fence, so the fence greps straight to its entry. `docs-lint.sh` checks that correspondence
  in both directions, and the two further copies of the heading inside the file: a Contents row must
  **name** the entry its link points at, not merely link to a real one, and an entry whose body opens
  with a bold label — below any superseded marker, which is skipped — must restate its own heading
  there. Opening with plain prose instead is fine: the check is on disagreement, not on presence.
- **A new decision never touches `CLAUDE.md`.** It is a fence and an entry in its area file. Only a
  new *area* is a new row — here and in `CLAUDE.md`, in the same order.
- **Fences first.** `- [Fences](#fences)` is the first item of every Contents and `## Fences` the first
  section after it, so a session that opens the file for its fences stops reading after them. An area
  file carries no other `##` section: a fence stated as prose elsewhere in the file is a fence nothing
  checks.
- **When a decision reverses an earlier one,** update the old entry in place — and add a superseded
  marker (a short blockquote: what changed, which spec changed it, where the full entry lives) at
  every *other* doc site that still states the old claim. A reader who lands only on the old site
  must see the reversal.
- **Date-stamp user decisions** (YYYY-MM-DD) so "settled" has a when.
- **Declare what an area governs.** The *Governs* column names the code trees the area's fences apply
  to, as backticked `dir/**` or `dir/prefix-*/**` globs or exact paths separated by commas, or `none`. An area that
  governs a tree has a
  path-scoped rule at `.claude/rules/decisions-<slug>.md` — the area template, with exactly those
  globs — so its fences fire when a matching file is opened with Read; an area that governs none has
  no rule. A deleted rule fails, so does a rule for an area that claims no tree, and so does a file at
  that path that is not this area's rule.
- **A new area is copied from `example-area.md`.** Its title is `# <Area name> — decisions`, with the
  name exactly as the table has it; its row here carries the Governs column, the one in `CLAUDE.md`
  does not.

`scripts/docs-lint.sh` checks the shape: this table's first two columns equal `CLAUDE.md`'s row for
row, every row has a file and every file a row, Fences first, fence ↔ entry one-to-one within each
file, every entry reachable from its Contents and named by the row that reaches it, every opening
bold label equal to its heading, the pointers in each Fences section resolve, and the rules match
*Governs*. Entries labelled `(example)` are exempt from the cross-checks, so a fresh scaffold is
green until the first real decision lands.

## Areas

| Area | Fences | Governs |
|---|---|---|
| (example) Area name | `docs/decisions/example-area.md#fences` | none |
