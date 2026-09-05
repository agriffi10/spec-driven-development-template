# The spec lifecycle


Specs move **Draft → In Progress → Completed** (the status in each spec's header is authoritative; the
`INDEX.md` row mirrors it).

- **Draft** — written, **reviewed by a fresh-context reviewer (`reviewer-contract.md`)** and
  refined, but **do not build until told.** Specs are often authored well ahead of implementation. A
  Draft spec sitting in the repo is not a signal to start it. A spec is not Draft-ready while it still
  has unresolved questions (`authoring-a-spec.md`), and a spec that has not been through the gate is not Draft-ready,
  whatever its header says.
- **In Progress** — exactly one spec at a time is in flight. Set when you branch to build it.
  The exception is a deliberate **multi-agent run**, where several sessions build different specs
  at once; what stays serial there is the *remote*, not the work (`several-agents.md`). Running
  several by accident — two sessions that each think they are alone — is the
  thing this rule exists to prevent.
- **Completed** — merged on green CI, delivery doc written (`completion-ritual.md`).

**Arcs.** Related specs can be grouped into *arcs* with an explicit **build order** documented in
`INDEX.md`. Grouping is a choice; recording the order of a **size split** (`authoring-a-spec.md`) is not — a spec cut
for size always leaves an arc entry behind, so keep the section even if you group nothing else.
Build in that order; arcs can have non-obvious dependencies. If arc narrative outgrows an
`INDEX.md` row, move it to a `docs/specs/ARCS.md` with **one `##` heading per arc** and a TOC at the
top, so a session can load only the arc it's in. Structure it that way from the first entry —
retrofitting headings onto grown prose is far more work. The heading names the **arc**, never its
status: status rots the day the next spec lands, and it belongs in the arc's body or its `INDEX.md`
rows (`completion-ritual.md`). An arc is also what an over-scoped spec *becomes*: a spec that runs past the size
ceiling in `authoring-a-spec.md` is cured by a second spec beside it and an arc entry holding the order, rather than
by a longer spec.
