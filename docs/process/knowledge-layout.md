# The knowledge layout

Specs, decisions and rulebooks carry YAML frontmatter in the shape of the Open Knowledge Format
(OKF v0.2): a `type`, a `title`, a one-sentence `description`, and the keys each kind needs. The
frontmatter is the **one home** of what it states — a spec's status, a decision's fence, a
rulebook's sources — and the indexes are generated from it, never written by hand. This part says
what may be written there, how the indexes are made, how the decision register is kept, how a
rulebook stays honest about its sources, and how a repo that predates all of it migrates.

Only these trees are held to OKF. The process parts, the templates and `architecture.md` carry no
frontmatter, and nothing records a `generated` or `verified` claim: a review is recorded by its PR,
and a self-attestation no lint can confirm is not a record.

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
one later in its own arc, that no two files share an id, and that no bold header line
(`**Status:** …` and kin) survives in the body as a second copy of the frontmatter.

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
in the body), and docs-lint fails the old `docs/specs/INDEX.md`, every rulebook, and every old
register file. Every one of those FAILs names this section. Migrate in one branch, by hand — not by a
script: splitting files is the mechanical splice that drops an entry while every check stays green,
which is why the last step counts and compares.

Let `OLD` be the commit before the migration branch.

1. **Take the scripts and the corpora whole.** Copy `scripts/frontmatter.awk`, `gen-index.sh`,
   `spec-lint.sh`, `spec-lint-test.sh`, `docs-lint.sh` and `docs-lint-test.sh`, and **replace**
   `tests/docs-lint/` and `tests/spec-lint/` — delete them first: `cp -R` never deletes, and a retired
   case left behind asserts a FAIL the new linter no longer prints.
2. **Specs.** For each `docs/specs/SPEC-*.md`, write the frontmatter (`A spec's keys`, above): `id` and
   `spec_status` from the bold header lines, `title` from the `# Spec:` line, `depends_on` from
   *Depends On* (`None` is `[]`), and `arc`/`arc_order` from the arcs section of the old
   `docs/specs/INDEX.md`. Write the one-sentence `description`. Delete the bold header lines, the
   `# Spec:` line and *Last Updated*. `sh scripts/spec-lint.sh` is green.
3. **Rulebooks.** For each `docs/best-practices/<domain>/<domain>.md`, add the frontmatter, fetch every
   source and read it, footnote each rule that states a version-specific fact, correct any rule a
   source contradicts, and set `stale_after` about a year out (*Rulebooks*, above).
4. **Generate and delete.** `sh scripts/gen-index.sh`, then `git rm docs/specs/INDEX.md`. Run every gate:
   `spec-lint.sh`, `spec-lint-test.sh`, `docs-lint.sh`, `docs-lint-test.sh`.
5. **Verify against `OLD`, and do not skip it** — green gates prove the new files are well-formed, not
   that nothing was lost. Specs before equal specs after, each with its status:

   ```sh
   git show "$OLD:docs/specs/INDEX.md" \
     | awk -F'|' '$2 ~ /SPEC-[0-9]/ { id = $2; sub(/^.*SPEC-/, "SPEC-", id); sub(/[^A-Z0-9-].*$/, "", id)
                                      st = $4; gsub(/^ +| +$/, "", st); print id "\t" st }' | sort > before.tsv
   for f in docs/specs/SPEC-*.md; do LC_ALL=C awk -f scripts/frontmatter.awk "$f"; done \
     | awk -F'\t' '$2 == "K" && $3 == "id" { id[$1] = $4 } $2 == "K" && $3 == "spec_status" { st[$1] = $4 }
                   END { for (f in id) print id[f] "\t" st[f] }' | sort > after.tsv
   diff before.tsv after.tsv && echo "every spec carried, every status equal"
   ```

   and each spec's body is unchanged below its old header — `git diff "$OLD" -- docs/specs/` touches
   only the lines above `## Overview`.
