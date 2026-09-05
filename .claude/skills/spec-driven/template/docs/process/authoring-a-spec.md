# Authoring a spec


Specs are written from `docs/templates/spec-template.md`. What makes a spec *buildable*:

- **Overview** — user/business intent, no implementation detail. Understandable cold.
- **Scope: In / Out** — explicitly list what's *excluded*, especially anything a reader would
  reasonably assume is included.
- **Functional Requirements** — one FR per discrete, testable behavior, with binary pass/fail
  **Acceptance Criteria** covering happy path, error path, and edges. Sequential IDs so a prompt can
  say "implement FR-001 through FR-003 only."
- **Size: aim for 3–6 FRs, and split above 8.** A spec is one coherent slice of behavior, not a
  feature's whole surface, and a spec past eight is not a big spec — it is a spec that should have
  been two. (Measured once, on the 216 specs this method was built on: the median carried 6 FRs
  and four in five carried 8 or fewer. A dated observation, not a standing claim about any
  corpus — the rule below forbids a standing rule resting on a number that rots.) The 3–6 aim
  sits at or below that median deliberately: it is where the method is going, not a description
  of where it already is. Growing one spec is the wrong repair;
  the right one is a second spec beside it, with the pair's build order recorded in `INDEX.md` as an
  **arc** (`spec-lifecycle.md`). Splitting keeps paying off past the first cut — a three-spec arc reads better than
  one fourteen-FR spec, and each piece earns its own reviewed plan, its own review gate and its own
  delivery doc. Cut along a seam the system already has — a layer, a surface, a switchover, the
  point where something inert goes live — never at "FR-009, because that is where the count ran
  out." **The second spec restarts at FR-001**: IDs are spec-local, which is why a dependency cites
  them as "SPEC-003 FR-002" and never as a number on its own. On the first specs in a repo, where
  there is no system yet to find a seam in, the seam is the user-visible step: what has to exist
  before the next thing can be tried at all.
- **The ceiling is a warn, not a fail.** A genuinely indivisible spec can sit above 8, and the lint
  warns rather than blocking so that it can. That call is made **out loud** — one line under
  *Scope → In Scope* saying why the FRs cannot be cut apart — and it is the reviewer's to accept
  or reject, not the author's to assert. "It is all one feature" is the claim to be most
  skeptical of, because it is what every over-scoped spec says about itself.
- **Data Model / Interface Contract** — language-native types, not prose. Explicit shapes produce
  better-typed output. Note the target path.
- **Implementation Phases** — each phase is one session's worth of work and maps to a discrete,
  reviewable unit. Phases are the input to the implementation plan generated at build time (`session-rhythm.md`); don't
  bake per-phase checkpoints into the spec.
- **No Open Questions.** Resolve every decision while authoring — a spec doesn't reach Draft-ready with
  unanswered questions. Issues that only surface during the build are handled in-session (`session-rhythm.md`), not
  parked in the spec. A sentence that *promises* a decision is an Open Question in declarative
  clothes (`reviewer-contract.md`).
- **Then the reviewer gate** (`reviewer-contract.md`). A freshly-authored spec goes to a
  fresh-context reviewer before it is Draft-ready, and its findings are fixed or flagged.
  The commonest thing this catches is not a wrong requirement — it is an acceptance criterion that
  cannot fail, and an Out of Scope bullet that an FR quietly needs.

`scripts/spec-lint.sh` enforces the structural side of this in CI: it **fails** a spec that is missing
a required section or that contains an "Open Questions" / "Checkpoint" heading, and **warns** on
unfilled placeholders, a spec with FRs but no acceptance criteria anywhere in it, and a spec
carrying more than 8 FRs. It cannot see a vacuous acceptance criterion, an acceptance criterion
missing from one FR while its neighbours have them, or a decision promised in a declarative
sentence — that is what the reviewer gate is for.
