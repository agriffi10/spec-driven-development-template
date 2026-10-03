# The knowledge layout

Specs, decisions and rulebooks carry YAML frontmatter in the shape of the Open Knowledge Format
(OKF v0.2): a `type`, a `title`, a one-sentence `description`, and the keys each kind needs. The
frontmatter is the **one home** of what it states — a spec's status, a decision's fence, a
rulebook's sources — and the indexes are generated from it, never written by hand. This part says
what may be written there, how the indexes are made, how the decision register is kept, how a
rulebook stays honest about its sources, and how a repo that predates all of it migrates.

The governed files below each conform to OKF on their own; the trees that hold them are not claimed
as OKF bundles (`docs/best-practices/INDEX.md` is a router with no frontmatter, and so would be a
`docs/specs/ARCS.md`). The process parts, the templates and `architecture.md` carry no frontmatter,
and nothing records a `generated` or `verified` claim: a review is recorded by its PR, and a
self-attestation no lint can confirm is not a record.

## Frontmatter

The governed files are `docs/specs/SPEC-*.md`, every `.md` under `docs/decisions/<area>/`, and every
`.md` under `docs/best-practices/` except its `INDEX.md`. (Agent and rule frontmatter is Claude
Code's format, held by `docs-lint.sh`'s own checks, not by this one.)

One reader, `scripts/frontmatter.awk`, reads them for `spec-lint.sh`, `docs-lint.sh` and
`gen-index.sh` alike, so an index is never generated from one reading of a file and linted against
another. It is not a YAML parser. It holds frontmatter to the subset below, and **a line that is not
one of these forms FAILs, naming its line and the rule it broke — it is never skipped**: a reader that
skips what it does not understand reports a file it never read as one that passed.

| Form | Rule |
|---|---|
| line 1 is `---` | nothing comes before it — not a heading, a blank line or a byte-order mark |
| a later line that is exactly `---` | closes the frontmatter; the body starts on the next line |
| `key: value` | a lowercase key (letters, digits, `_`) at column 0 and exactly one space after the colon. A plain value may not start with ``- ? : , [ ] { } # & * ! \| > ' " % @ ` ``, hold `: ` or ` #`, or end in `:` — double-quote such a value |
| `key: "value"` | on one line; `\"` and `\\` are the only escapes, and nothing follows the closing quote |
| `key: [a, b]` or `key: []` | a flow list on one line; each element a plain word holding no bracket, brace, quote, `:` or `?` |
| `sources:` | the one block list. `  - field: value` (two spaces, a dash, a space) opens an item and `    field: value` (four spaces) continues it; each field is a plain or double-quoted value |

Refused by name: a duplicate key (YAML keeps the last copy, so the two disagree silently), a blank
line, a comment, a tab, a control character, any other indentation, a block scalar, a flow map, a
single-quoted value, an anchor, alias or tag, a value continued onto a second line, and a bare `key:`
other than `sources:`. Each is a place where YAML errors or, worse, reads something other than what
was written: ` #` drops the rest of a value as a comment, and an unquoted `[Feature Name]` is a
one-element list. CRLF line endings are read.

**Known limitation**, stated so nobody mistakes it for a check: a plain value YAML would read as a
boolean, a null or a number (`No`, `null`, `1.0`) is read here as text. Double-quote it when text is
meant — a strict YAML reader elsewhere will not agree with this one about `title: No`.

### A spec's keys

| Key | Holds |
|---|---|
| `type` | `Spec` |
| `id` | `SPEC-<number>`, equal to the filename's prefix |
| `title` | the feature's name — the spec carries no `#` title line; this is its one home |
| `description` | one sentence: what it delivers, and for whom |
| `spec_status` | `Draft`, `In Progress` or `Completed` (`spec-lifecycle.md`) |
| `depends_on` | a flow list of spec ids, `[]` for none |
| `arc`, `arc_order` | both or neither: the arc's slug and the spec's place in it, a positive integer (`spec-lifecycle.md`) |

`spec_status`, not OKF's `status`: OKF's `status` is about trust (`draft` means unreviewed), and a
reader who knows OKF would take our Draft — reviewed, not started — for unreviewed work. There is no
*Last Updated*: it was hand-kept and unverifiable, and `git log` is the record. A spec may carry
further keys (OKF allows them); nothing reads them.

`spec-lint.sh` holds every one of these, in CI: the reader's refusals, the required keys, `type`,
`id` against the filename, the status vocabulary, that every `depends_on` names a spec in the
directory and not itself, the arc keys, that no two specs share an arc place, that no spec depends on
one later in its own arc, that no two files share an id, and that neither a bold header line
(`**Status:** …` and kin) nor a `# ` title line survives in the body as a second copy of the
frontmatter.

## Generated indexes

`docs/specs/index.yaml` and `docs/decisions/index.yaml` are views of the frontmatter, written by
`sh scripts/gen-index.sh` and **never edited by hand** — the first line of each says so. Run it after
any frontmatter change and commit what it writes. `docs-lint.sh` regenerates each index into a temp
file and fails the committed copy when the bytes differ or it is missing; the generator is
deterministic (no timestamps, fixed sorts, every string double-quoted) so that comparison is exact. A
merge conflict in an index is resolved by regenerating on the merged frontmatter, never by hand.

The generator **refuses** a tree — writes nothing for it and leaves the committed index as it was —
when any file in it cannot be read or lacks a key the index lists; docs-lint names the refusal.
Specs are listed by number (SPEC-2 before SPEC-10), then every arc by name with its specs in
`arc_order`; areas by directory name, and each area's decisions by file name.

They are YAML and lowercase because OKF reserves `index.md` for a frontmatter-free markdown listing:
an uppercase `INDEX.md` here would read to an OKF tool as a concept missing its frontmatter. The
pointers to them are written in backticks, never as bare `@` imports.

## The decision register

The settled decisions, in full: **one file per decision, in one directory per area** —
`docs/decisions/<area>/`. `CLAUDE.md`'s Key Decisions table names the areas, and
`docs/decisions/index.yaml` (generated) lists every area's fences. Read your area's block of the index
before working in it, and open a decision's file only when you need its reasoning. **Don't
re-litigate these.**

| File | Frontmatter | Body |
|---|---|---|
| `<area>/<area>.md` — the area concept | `type: Decision Area`; `title`, the area name the `CLAUDE.md` row repeats; `governs`, a flow list of globs (`[]` for none) | the area's intro |
| `<area>/<decision>.md` — one decision | `type: Decision`; `title`, its label; `description`, its **fence** — the claim and its constraint in one line; `status`, optional: `stable` or `deprecated` (absent means stable) | its **entry** — what was decided and why, what was rejected, the do-NOT-build lines — then `## History` |

The words stay the register's own: a decision's **fence** is its `description`, its **entry** is its
body. Rules that keep the register useful (each earned by a real failure in a project run this way):

- **A fence is never the only home of a fact.** The body above History says what was decided and why;
  docs-lint fails a decision whose fence has no entry, and caps a fence's length — one line, not the
  reasoning.
- **A new decision never touches `CLAUDE.md`.** It is a new file in its area. Only a new *area* is a
  new row there: a new directory, its area concept, and the row — in slug order, the order the index
  lists areas.
- **A decision's file name is chosen once and never changes** — conventionally the slug of its first
  title. A reversal rewrites the title in place; renaming would break every link to it and split its
  history across two files.
- **A decision's file is its whole thread.** When a decision is reversed or refined, rewrite its
  current statement — title, fence, entry — in place, and add a dated History entry at the top saying
  what changed and why. `status: deprecated` is only for a decision retired with no replacement, and
  **deprecating one is a reversal too**: set the status and add a dated History entry at the top saying
  it was retired, and why — docs-lint fails a deprecated decision whose newest entry does not say so.
  The file is never deleted. Every *other* doc site still stating the old claim — an arc narrative, an
  `architecture.md` section — gets a superseded marker (a short blockquote: what changed, which spec
  changed it, where the decision lives): a reader who lands only there must see the reversal.
- **History is last, dated and newest first.** `## History` closes the body: one `### YYYY-MM-DD`
  heading per date, newest first, at least one — the first is when the decision was settled — with the
  entries as bullets (OKF's log form; a leading bold word such as `**Settled:**` or `**Reversed:**` is
  convention, not checked).
- **No `#` title line in the body.** The title has one home, the frontmatter. (A bold label restating
  it is not checked — the copy that drifted when one file held every decision — so don't write one.)
- **`status` is `stable` or `deprecated`, never `draft`.** A register holds settled decisions; an
  unsettled one belongs in its spec until it settles.
- **Declare what an area governs.** `governs` lists the code trees the area's fences apply to, as
  `dir/**`, `dir/prefix-*/**`, `dir/**/*.ext`, `dir/*.ext` or exact paths, or `[]`. An area that
  governs a tree has a path-scoped rule at `.claude/rules/decisions-<area>.md` — the area template
  below, with exactly those globs — so its fences fire when a matching file is opened with Read; an
  area that governs none has no rule.
- **A new area** is a directory `docs/decisions/<slug>/` holding its concept `<slug>.md`, a row in
  `CLAUDE.md`'s Key Decisions table in slug order, its rule when it governs a tree, and then
  `sh scripts/gen-index.sh`. (A scaffold ships one example area, `example-area/`, which its own text
  says to rename for the first real area — so once a repo has one, this is the shape to copy, not that
  directory.) The concept, and the rule:

  ```
  ---
  type: Decision Area
  title: "API"
  governs: [src/api/**]
  ---

  What the area covers, in a sentence or two.
  ```

  ```
  ---
  paths:
    - "src/api/**"
  ---
  Files matching these paths are governed by the **API** decisions in `docs/decisions/api/`.
  Read the area's fences in `docs/decisions/index.yaml` first — they are not loaded with CLAUDE.md.
  ```

  The shipped example is a conformant area, so a fresh scaffold is green by conformance, with nothing
  exempted.

`docs-lint.sh` checks the shape: the table's rows name the area directories by their titles, in slug
order, every row a directory and every directory a row; every area has its concept; every file reads
through the shared reader and carries the keys for its kind; a decision has a fence, an entry above
its History — a line that says something, not a lone heading or comment — a well-formed History with
no date after today, a `status` in the vocabulary, and a deprecation recorded in the newest History
entry; no title line in a body; nothing flat under `docs/decisions/` or a level below an area, no
decision named `index.md` or `log.md`, which OKF reserves, and no file there but `.md` files and the
index; the pointers in each fence resolve; and the rules match `governs` both ways.

## Rulebooks

A rulebook (`docs/best-practices/<domain>/<domain>.md`) states rules an agent follows without
checking them, so where a rule rests on a **version-specific fact** — a WCAG level, a React release,
a PEP — it says where the fact came from. The frontmatter carries `type: Rulebook`, `title`,
`description`, `sources` and `stale_after`; each `sources` item carries `id`, `resource` (the URL)
and `title`, and may carry OKF's other fields. The rule cites its source with a markdown footnote
whose label **is** the source id — `…is AA in WCAG 2.2.[^wcag22]` — and the definition at the foot
of the file gives the title and URL. Footnoting every rule is not the aim; a source that supports no
version-specific rule is cited once, in the rulebook's opening paragraph, on the claim it does support.

**A source is fetched and read before it is cited, and it must support the sentence that cites it.**
A fabricated or unread citation is the defect this layer exists to prevent; when a fetched source
contradicts the rule, the rule is corrected, not the citation dropped. A reviewer re-fetches every
source in the diff — they are few.

`stale_after` is the date by which the sources must be read again: an ISO 8601 instant in UTC,
`YYYY-MM-DDTHH:MM:SSZ` (OKF allows any explicit offset; this subset takes `Z`, so "past" is a plain
comparison with no date arithmetic). A rulebook is stale when now is on or after it, and **a stale
rulebook FAILS `docs-lint.sh`** — there is no WARN tier. That makes this the one check that reads
the clock as well as the tree: the same commit passes before the instant and fails after it, in every
repo that carries the rulebook, and a reviewer re-running the gates later can see a red the change
under review did not cause. That is the intent — a rulebook nobody has re-read is not one to follow
unchecked — and the remedy is the FAIL's own text: re-fetch every source, correct any rule a source no
longer supports, move `stale_after` forward. Set it about a year out. The fixtures use dates far in
the past and the future, so the corpus is deterministic; there is no "now" override, which would be a
bypass.

`docs-lint.sh` holds every `.md` under `docs/best-practices/` but its `INDEX.md` (which is a router,
not a rulebook): the reader's refusals, `type: Rulebook`, the four keys, each source's three fields,
unique ids, the `stale_after` form and date, every footnote reference defined and naming a source,
and every source cited at least once. Code spans and fenced blocks are skipped, so a regex such as
`[^a-z]` written in a rule is not read as a footnote.

## Migrating a repo that predates this layout

A repo scaffolded before specs, decisions and rulebooks carried frontmatter breaks the moment it pulls
these scripts: **spec-lint fails every existing spec in CI** (no frontmatter, a bold header line left
in the body), and docs-lint fails the old `docs/specs/INDEX.md` and `docs/decisions/INDEX.md`, every
flat area file, the `| Area | Fences |` table in `CLAUDE.md`, every area rule, and every rulebook. Every one of those FAILs names this section. Migrate in one branch, by hand — not by a
script: splitting files is the mechanical splice that drops an entry while every check stays green,
which is why the last step is reading what moved, in a diff.

Let `OLD` be the commit before the migration branch.

1. **Take what changed in the template, by the list git gives — not a list written here, which would
   go stale.** In a clone of the template repo, with `FROM` the template commit you scaffolded from and
   `TO` the one you are taking:

   ```sh
   git diff --name-status "$FROM" "$TO" -- .claude/skills/spec-driven/template/
   ```

   Every path it prints under that prefix is the same path in your repo. Take each added or modified
   file whole — the scripts, the process parts, the templates, the agents and rules, `settings.json`,
   the PR template, the workflows — except what your repo owns and you merge by hand (`CLAUDE.md`,
   `docs/process/operational-traps.md`, `docs/process/ground-rules.md`, `docs/architecture.md`,
   `docs/component-inventory.md`, and any `settings.json` entries of your own), and except
   `docs/specs/`, `docs/decisions/` and `docs/best-practices/`, which steps 2–4 rebuild (the template's
   copies are its examples). Delete every path it marks deleted, and **replace** `tests/docs-lint/` and
   `tests/spec-lint/` wholesale: `cp -R` never deletes, and a retired case left behind asserts a FAIL
   the new linter no longer prints.
2. **Specs.** For each `docs/specs/SPEC-*.md`, write the frontmatter (`A spec's keys`, above): `id`
   from the filename's `SPEC-<number>` prefix, `spec_status` from the bold *Status* header line,
   `title` from the `# Spec:` line, `depends_on` from *Depends On* (`None` is `[]`), and
   `arc`/`arc_order` from the arcs section of the old `docs/specs/INDEX.md`. Write the one-sentence
   `description`. Write `title` and `description` **always double-quoted**, escaping `\` as `\\` and
   `"` as `\"` — then no character in them can collide with the subset. **The spec's own header wins**:
   it was the authority in the old layout, so where its *Status* and its row in the old INDEX disagree,
   the row had already drifted, and the header's value is the one carried. Delete the bold header
   lines, the `# Spec:` line and *Last Updated*. In `CLAUDE.md`, point at `` `@docs/specs/index.yaml` `` wherever
   it pointed at `docs/specs/INDEX.md`. `sh scripts/spec-lint.sh` is green.
3. **Register.** For each row of the old `docs/decisions/INDEX.md` — area name, file, Governs:
   - `mkdir docs/decisions/<slug>` and write `<slug>/<slug>.md`: `type: Decision Area`, `title` the area
     name, `governs` the Governs column as a flow list (`none` is `[]`; backticked globs become
     `[src/api/**, src/models/*.py]`), and the old file's intro as its body.
   - For each `### Label` entry, write `<slug>/<file>.md`, the file name the slug of the label (chosen
     once, never renamed): `type: Decision`, `title` the label, `description` its fence — the bullet
     with its `**Label** — ` prefix removed, its continuation lines joined with single spaces and
     trailing spaces dropped, **always double-quoted**, escaping `\` as `\\` and `"` as `\"` (the label in
     `title` the same way) — and as the body **everything under
     the entry's heading, unchanged**, followed by `## History` with one `### YYYY-MM-DD` entry: the
     date the entry records, else the day it entered the register
     (`git log --format=%as -S'### Label' "$OLD" | tail -1`), plus one dated entry per reversal the
     entry records.
   - Rewrite each `.claude/rules/decisions-<slug>.md` body to the area template: `Files matching these
     paths are governed by the **<Area>** decisions in` `` `docs/decisions/<slug>/` ``. then `Read the
     area's fences in` `` `docs/decisions/index.yaml` `` `first — they are not loaded with CLAUDE.md.`
   - In `CLAUDE.md`, take the Key Decisions intro from the shipped `CLAUDE.md`, make the table
     `| Area | Directory |` with one `` | <Area> | `docs/decisions/<slug>/` | `` row per area in slug
     order, and point at `` `@docs/decisions/index.yaml` `` where it pointed at the old index. Bring the
     rest of what `CLAUDE.md` says about these files — its pointer list, *Specs*, the `# indexes:` line
     under *Common Commands*, the completion and guardrail lines — up from the shipped `CLAUDE.md`.
4. **Rulebooks.** The shipped rulebooks carry corrections their sources forced (WCAG levels, React
   Compiler and `useEffectEvent` versions, PEP 484 on `__init__`) as well as their frontmatter: **if
   yours are the stock ones, take them whole.** For one you have edited, or one of your own, add the
   frontmatter, fetch every source and read it, footnote each rule that states a version-specific fact,
   correct any rule a source contradicts, and set `stale_after` about a year out (*Rulebooks*, above).
5. **Generate and delete.** `sh scripts/gen-index.sh`, then `git rm docs/specs/INDEX.md
   docs/decisions/INDEX.md` and every old `docs/decisions/<slug>.md`. Run every gate: `spec-lint.sh`,
   `spec-lint-test.sh`, `docs-lint.sh`, `docs-lint-test.sh`.
6. **Read the migration diff, and do not skip it.** Green gates prove the new files are well-formed,
   not that nothing was lost — and **nothing here proves that mechanically**. This is a diff for a
   person to read, in the migration PR. That is a deliberate trade: three mechanical verifiers written
   for this step each misread a valid old form (a fence with a plain hyphen, a `#` line in a code block,
   a bulleted *Depends On*), and a checker that misreads passes what it misread. The new linters, with
   their tested corpus, hold the new layout; your reading holds the move. Set `OLD` first — the commit
   before the migration branch — in the shell you run these in, from anywhere inside the repo.

   **Specs.** One diff, nothing parsed:

   ```sh
   : "${OLD:?set OLD to the commit before the migration}"
   git -c core.quotePath=false diff "$OLD" -- ':/docs/specs/'
   ```

   Expected in each spec: the old header lines removed — `# Spec: …`, `**ID:** …`, `**Status:** …`,
   `**Last Updated:** …`, `**Depends On:** …` — and a frontmatter block added in their place, carrying
   the same title, status and dependencies; `INDEX.md` deleted and `index.yaml` added. **Any other
   removed line in a spec body is a loss or an edit** — find it, and put it back or account for it.

   **Decisions.** For each old area file, a word diff of that file against the new area directory's
   files concatenated — the area concept first, then the decisions in file-name order — the temporary
   files in a directory that is removed however the loop ends. It uses no glob, so it reads the same in
   `sh`, `dash`, `bash` and `zsh` (whose no-match error would otherwise end the loop at a missing
   directory):

   ```sh
   : "${OLD:?set OLD to the commit before the migration}"
   ( cd "$(git rev-parse --show-toplevel)" && tmp=$(mktemp -d) &&
     trap 'rm -rf "$tmp"' EXIT && trap 'exit 1' INT TERM HUP &&
     git -c core.quotePath=false ls-tree -r --name-only "$OLD" -- docs/decisions/ |
     while IFS= read -r f; do
       case $f in */INDEX.md) continue ;; *.md) ;; *) continue ;; esac
       a=${f#docs/decisions/}; a=${a%.md}
       git show "$OLD:$f" > "$tmp/old"
       c="docs/decisions/$a/${a##*/}.md"
       { if [ -f "$c" ]; then cat "$c"; fi
         find "docs/decisions/$a" -type f -name '*.md' 2>/dev/null | LC_ALL=C sort |
         while IFS= read -r d; do [ "$d" = "$c" ] || cat "$d"; done; } > "$tmp/new"
       printf '\n===== %s  ->  docs/decisions/%s/\n' "$f" "$a"
       git --no-pager diff --no-index --word-diff --diff-algorithm=patience "$tmp/old" "$tmp/new" || :
     done )
   ```

   Read `[-…-]` as removed and `{+…+}` as added. **Expected removals:** the `# <Area> — decisions`
   title, the `## Contents` list, the `## Fences` heading, each fence bullet's `- **Label** —` (its
   text comes back as an added `description: "…"`), the `---` separator, and each `### Label` heading
   (it comes back as `title: "Label"`). **Expected additions:** each file's frontmatter, and each
   decision's `## History`. Where a decision's file name sorts away from its old position, its whole
   entry shows as removed in one place and added in another. **A loss is a removed passage that comes
   back nowhere** in that area's additions — a line of an entry, a line of a code block, a
   `Rejected:` or `Do NOT build:` line, a fence whose text no `description:` repeats. An area file
   whose directory does not exist shows as wholly removed.
