# Key Decisions — full register

The settled architectural decisions, in full. **Don't re-litigate these.** `CLAUDE.md` carries a
one-line digest of each; this file carries the reasoning, the constraints, what was rejected, and any
explicit "do NOT build" fences. Pull the entry you need — you rarely need them all.

Rules that keep this file useful (each earned by a real failure in a project run this way):

- **Entry first, line second.** Write the full entry here *before* adding the one-line digest to
  `CLAUDE.md`. The digest line must never be the only home of a fact — a digest that outgrows its
  register inverts the whole model.
- **One `###` heading per entry**, listed in the Contents below. The heading label matches the bold
  label of its `CLAUDE.md` digest line, so the line greps straight to its entry.
- **When a decision reverses an earlier one,** update the old entry in place — and add a superseded
  marker (a short blockquote: what changed, which spec changed it, where the full entry lives) at
  every *other* doc site that still states the old claim (arc narratives, architecture sections).
  The new entry alone is not enough; a reader who lands only on the old site must see the reversal.
- **Date-stamp user decisions** (YYYY-MM-DD) so "settled" has a when.

`scripts/docs-lint.sh` checks the first two mechanically on every PR: this file must exist, every
`CLAUDE.md` digest label must have a `###` entry here and every entry a digest label, and every entry
must appear in the Contents. The `(example)` entry below is exempt, so a fresh scaffold is green
until the first real decision lands.

## Contents

- [(example) Decision label](#example-decision-label)

---

### (example) Decision label

*(Delete this example once the first real entry lands.)* What was decided; the constraint, incident,
or trade-off that forced it; what was explicitly considered and rejected, and why; any "do NOT build"
fence a future reader might otherwise cross. Point to the spec or delivery doc that holds the longer
story rather than retelling it.
