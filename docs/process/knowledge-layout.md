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
