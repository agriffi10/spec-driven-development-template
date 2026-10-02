# The spec lifecycle


Specs move **Draft → In Progress → Completed**. A spec's `spec_status` in its own frontmatter is the
one authority; `docs/specs/index.yaml` is generated from it (`knowledge-layout.md`), so a status change
is one edit and a regeneration, never two edits kept in step by hand.

- **Draft** — written, **reviewed by a fresh-context reviewer (`reviewer-contract.md`)** and
  refined, but **do not build until told.** Specs are often authored well ahead of implementation. A
  Draft spec sitting in the repo is not a signal to start it. A spec is not Draft-ready while it still
  has unresolved questions (`authoring-a-spec.md`), and a spec that has not been through the gate is not Draft-ready,
  whatever its `spec_status` says.
- **In Progress** — exactly one spec at a time is in flight. Set when you branch to build it.
  The exception is a deliberate **multi-agent run**, where several sessions build different specs
  at once; what stays serial there is the *remote*, not the work (`several-agents.md`). Running
  several by accident — two sessions that each think they are alone — is the
  thing this rule exists to prevent.
- **Completed** — merged on green CI, delivery doc written (`completion-ritual.md`).

**Arcs.** Related specs can be grouped into *arcs* with an explicit **build order**, written in each
spec's frontmatter: `arc: <slug>` names the arc and `arc_order: <n>` the spec's place in it, and the
generated `docs/specs/index.yaml` lists every arc in that order. Grouping is a choice; recording the
order of a **size split** (`authoring-a-spec.md`) is not — a spec cut for size always joins an arc.
Build in that order; arcs can have non-obvious dependencies. `spec-lint.sh` fails an ambiguous order
(two specs in one place) and a spec that depends on one later in its own arc, since the order would
then contradict the dependency. Inserting a spec mid-arc renumbers the ones after it — rare, since a
size split appends. If an arc needs *narrative*, it goes in a `docs/specs/ARCS.md` with **one `##`
heading per arc** and a TOC at the top, so a session can load only the arc it's in — narrative only,
never the order and never a status, which have their one home in the frontmatter. The heading names
the **arc**, never its status: status rots the day the next spec lands (`completion-ritual.md`). An arc
is also what an over-scoped spec *becomes*: a spec that runs past the size ceiling in
`authoring-a-spec.md` is cured by a second spec beside it in one arc, rather than by a longer spec.
