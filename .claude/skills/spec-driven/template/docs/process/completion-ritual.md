# Completion ritual (keep the always-loaded tier lean)

When a spec is done, in the same pass:
1. Set the spec file header `Status: Completed`.
2. Update its one-line row in `docs/specs/INDEX.md` (**status only** — no prose).
3. Write a **short** delivery doc at `docs/spec-delivery/SPEC-XXX-<name>.md` from
   `docs/templates/spec-completion-template.md` — *what shipped + what changed*, typically under a
   page (~40–100 lines), **no code/config pasted** (the code + component-inventory are the source of
   truth for reuse).
4. If reusable modules/services/components were added, add a **one-line** row to
   `docs/component-inventory.md` (if the inventory has split into area files, the row goes in the
   file **matching the component's path**).
5. A *new architectural decision* gets its **full entry in `docs/decisions.md` first, plus a row in
   that file's `## Contents`** — an entry the Contents does not reach is findable only by reading the
   whole file, and `docs-lint.sh` fails the PR for it — then **one
   line** in CLAUDE.md's Key Decisions — the digest line is **never the only home of a fact**, and
   never a paragraph. A reversal that changes the entry's **heading** must move its Contents row with it —
   the row is an anchor link, left pointing at nothing otherwise, which docs-lint fails.
   If the decision **supersedes an earlier one**, update the old register entry in
   place and add a superseded marker (short blockquote: what changed, which spec, where the full
   entry lives) at every doc site that still states the old claim — arc narratives, architecture
   sections. The new entry alone is not enough; a reader who lands only on the old site must see the
   reversal.
6. **If the decision changed the SHAPE of the system** — a new piece, a piece removed, a boundary
   moved, a mechanism swapped — add a row to `docs/architecture.md` → *Architecture Decision Record*
   **and** update the prose section it contradicts. The row is an index entry: number, title,
   one-line context, a short note, linking to the `decisions.md` entry. Rows are **append-only and
   never renumbered**; a superseded decision keeps its row and gains a note naming the row that
   replaced it. Most decisions do **not** qualify — a rule, a fence or a per-feature choice is a
   register entry and nothing more, and a table that grows a row per spec has stopped being an
   orientation aid.

**Anti-regrowth & doc hygiene** (each rule below was earned by a real doc defect in a project run
this way):

- If a doc disagrees with the code, fix or delete it — don't let stale state accumulate. Don't add
  prose to the always-loaded tier.
- **Documentation lives beside the code it describes.** A page named for a source file, a module or
  a directory belongs in that tree, not in `docs/`; `docs/` carries what spans trees or belongs to
  no tree. The test is where a reader is standing when they need it — someone changing a handler is
  in the handler's tree, and a doc they must leave the tree to find is a doc they will not open.
- **One organising axis per subject, and one doc that owns it.** If a subject is documented per-area,
  exactly one place is per-area. A second doc on the same axis is not redundancy, it is a fork with
  no merge — and the two will already have diverged by the time anyone notices.
- **A register is grouped by AREA; ordering it by spec number turns it into a changelog.** The
  question a reader arrives with is "what has been settled about X", never "what did SPEC-143
  decide". A register is the only home of the rejected alternatives and the fences, so a shape that
  reads as disposable gets treated as disposable. The CLAUDE.md digest and the register **group by
  the same areas**, so a reader who finds an area in one finds it in the other.
- **When a doc moves, the pointers that rot unseen are in SOURCE files** — docstrings, infra
  comments, CI steps. A markdown-only sweep reports the tree clean. Grep the path, not the filename,
  and fix the Draft specs too: a Draft is an unbuilt instruction, and pointing one at a deleted file
  sends the next builder nowhere.
- **A doc's own statement of when to read it must agree with CLAUDE.md's.** Both are cheap to write
  and neither is checked, so they drift silently and the reader follows the wrong one.
- **Status never appears in the heading of a doc whose status can change** — an arc, an
  `architecture.md` section, a `decisions.md` entry. It rots the day the next spec lands, and a
  reader who greps the heading gets an answer that was true once. Status lives in `INDEX.md` and the
  spec header — the two places the completion ritual keeps in step **by hand**, since `spec-lint.sh`
  does not compare them. (A delivery doc's `# Completed Spec — …` title is not this: it names a
  finished record whose status cannot change.)
- **A heading in a doc read by SUBJECT names the subject, not the spec that produced it** — that is
  `architecture.md` and the rulebooks, where a reader arrives asking how a thing works, never "what
  did SPEC-168 decide". The scope is deliberate and stops there: a `decisions.md` entry IS a record
  of what one spec settled, and its number is part of its identity when you arrive from a delivery
  doc or a superseded marker, so those headings keep theirs. A rule stated more broadly than that
  would be violated by most of a mature register on the day it was written, and a rule practice
  contradicts at scale trains readers to ignore the ones that hold.
- **Standing rules never cite volatile numbers** (line counts, row counts, section ranges) — state
  the principle. The numbers rot, and a rule resting on false evidence teaches readers to distrust it.
  **Dating the measurement does not save it**, which is the tempting half-fix: a dated number still
  reads as current to anyone not checking the date against the calendar, and one such entry went stale
  within a single commit of being written. Either delete the number and state the principle, or anchor
  the evidence to something immutable — a commit SHA, which a reader can re-measure — rather than to a
  live count.
- **A rule practice consistently violates gets reconciled or deleted.** A dead rule trains agents to
  ignore the live ones.
- **Routers and indexes carry only what self-describes.** Hand-maintained metadata (symbol counts,
  "§1–§N" ranges) rots silently; drop it or let the structure carry the information.
- **Any doc pulled entry-by-entry gets one heading per entry plus a TOC**, and pointer phrases in
  other docs must match a greppable heading — "read the entry for your area" must be a jump, not a
  full-file read.
- **Live findings and obligations never live in historical or cancelled narrative** — rehome them to
  an active register and leave a pointer behind.
- **`scripts/docs-lint.sh` enforces the structural half of these rules, and is a LOCAL PRE-PUSH
  gate — deliberately not a CI job.** Run it, and `docs-lint-test.sh` if you touched it, before every
  PR, alongside the formatter, linter, type-checker and tests. Keeping it local puts the failure in
  front of the person who caused it, at the moment they can still fix it silently, rather than on a
  shared branch where it reds someone else's unrelated work and becomes a thing to be waived.
  **State the trade honestly, because this section argues the opposite elsewhere:** a local gate is
  prose asking a session to run a script, which is the category this section says rots. What carries
  the mechanism instead is the reviewer rule in `reviewer-contract.md` — *every reviewer runs the repo's gates against
  the branch* — so the gate is enforced by the review that must happen before a push rather than by
  a job after it. A project that wants it mechanical as well as local can call it from the pre-push
  hook `scripts/pr-queue/pre-push` already installs. It holds `CLAUDE.md` to a byte budget and each Key Decisions
  **unit** — a bullet with its continuations — to a length, and refuses any construct in that section but an area heading, a bullet, a continuation, a blank line and plain intro prose; requires `docs/decisions.md` to exist, to carry a `###` entry for every digest
  line and a digest line for every entry, and to list every entry in its Contents; requires every
  Completed spec to have a delivery doc, and holds every doc in `docs/spec-delivery/` to a line cap
  (not only those tied to a Completed spec); and checks that the pointers
  out of `CLAUDE.md` resolve. On the routed process tier it also holds the always-loaded set to the
  router's *Loaded every session* table (imports match rows, a byte budget derived from the table, no
  nested imports, pointers resolve in every file of the set), every part to a router row and every
  row to a file, the old single-file path empty, and `.claude/rules/` and `.claude/agents/` to their
  shapes — the rule template, the allowed glob forms, the allowed models, the routing table.
  **`scripts/docs-lint-test.sh` is the corpus that proves those checks still fire** — running the
  linter against the repo's own documents proves the documents pass and nothing about whether any
  check works. A change to the linter runs the corpus. The general rule, and its evidence, is in `reviewer-contract.md`.
  **The budgets are ratchets against ACCRETION** — when one fires because a doc grew a line at a
  time, move detail down a tier and re-ratchet, rather than raising the cap to admit the edit. That
  is the regime a budget is normally in, and pinning it near the measurement is right there.
  **After a structural CUT the regime changes, and the same pinning becomes the trap.** What remains
  after a cut is not accretion but fences, and a budget left at the new measurement leaves the next
  change that legitimately needs a line nothing to spend — so it takes one from somewhere else, and
  the gate causes the damage it exists to prevent. Measured in `log-forge`: a cap set at its post-cut
  size left about two digest lines of room, and was deliberately raised with the reasoning recorded
  beside the number. Leave headroom after a cut, say why where the number lives, and mark that budget
  as the one **not** at the measurement.
  **A threshold can also be invalidated by its own success.** A cap calibrated against a document
  catches things until a cut shrinks everything below it, after which it sits far above anything it
  governs and can never fire — still advertised here as a fence, and now not one. So after any
  structural change to what a threshold measures, **re-derive it rather than re-checking it**: a
  check that passes proves nothing about a cap that can no longer fail. This repo's own shipped
  budgets are deliberately loose for that reason — it ships a scaffold, and `scripts/docs-lint.sh`
  says so where they are set.
  *Why a script and not this paragraph:* every rule in this section already existed here, and the
  sibling project `log-forge` violated several of them anyway — and its history says something
  sharper than "a rule was ignored". Its `CLAUDE.md` grew from 7,350 bytes at `ad898fc8` to 89,340
  at `e60b60d`, more than tenfold. For most of that it had only a **two-sentence** version of this
  section — "don't add prose to the always-loaded tier", naming no shape, no register and no budget:
  a rule too weak to bind. The full set arrived at `690d2a55`, ported from s3-upload-portal, naming
  the violation in the present tense and naming it correctly; the file was already 67,925 bytes by
  then, and grew by nearly a third again before anyone cut it. **Both halves fail without a gate**: the weak
  rule could not bind, and the right rule, diagnosing itself accurately in the file every session
  reads, did not stop the next edit either. Both ends of each measurement are anchored to a commit
  so a reader can re-derive them, per the volatile-number rule above. A rule a reader has to
  remember is a rule that rots.
