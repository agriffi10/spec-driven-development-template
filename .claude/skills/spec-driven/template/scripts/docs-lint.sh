#!/bin/sh
# docs-lint.sh — hold the ALWAYS-LOADED tier to the shape the layering assumes.
#
# Why this exists as a script rather than a rule. Every check below already existed in
# prose — in `docs/process/completion-ritual.md` (*Anti-regrowth & doc hygiene*), in `CLAUDE.md`'s own
# doc-size guardrail, and in the register's rules (now `docs/process/knowledge-layout.md`) — and in the sibling
# project `log-forge` (published as `log-foundry`) several were violated anyway. Its
# `CLAUDE.md` grew from 7,350 bytes at `ad898fc8` to 89,340 at `e60b60d`, more than
# tenfold — most of it while that repo carried only a TWO-SENTENCE version of the rule,
# naming no shape, no register and no budget. The full set landed two days before the cut
# and did not stop the next edit either. It was cut back to a digest over its register in
# the change that first ran this script there. Both ends are anchored to commits rather
# than restated: an earlier version of this comment carried three numbers, and two of them
# were wrong by the time it shipped.
#
# A rule a reader has to remember is a rule that rots. This is the same rules where a
# script can see them — run before every push, deliberately not in CI, so the failure
# lands on whoever caused it rather than on a shared branch.
#
# FAIL (exit 1): an always-loaded file is over budget or has been removed outright, a
#   Key Decisions section carries anything but its intro and area table, an area directory is
#   missing, unnamed by the table or named otherwise than its title, a decision file's frontmatter
#   is not a decision's or its History is missing or out of order, a fence has no entry or an entry
#   no fence, a fence has become the reasoning, an area's rule disagrees with what it governs, a
#   Completed spec has no delivery doc — or a spec's `spec_status` cannot be read, so whether it
#   owes one cannot be told — a delivery doc has become an essay, a pointer out of an
#   always-loaded file goes nowhere, the routed process tier has lost its shape (router, imports,
#   parts, rules, agents — checks 9–13), a stub has reappeared at an old path, a dated measurement
#   in a standing doc or script carries no commit to re-measure from (14), a generated index is
#   missing, stale, or cannot be regenerated (15), or a rulebook lacks its frontmatter, cites a
#   footnote that is not one of its sources, carries a source it never cites, or is past its
#   `stale_after` (16 — the one check that reads the DATE as well as the tree, by design).
# ERROR (exit 2): the shared frontmatter reader or the index generator is missing, fails, or
#   returns no verdict — the checks that read through them cannot run, and must not read as passed.
#
# There is no WARN tier: `spec-lint.sh` owns the soft per-spec judgements, and every rule
# here is a shape the layering depends on — a shape is either held or it isn't.
# Deliberately NOT checked here: anything `spec-lint.sh` already owns (required spec
# sections, banned headers, the FR ceiling, and every rule on a spec's frontmatter — this
# script reads a spec's `spec_status` for check 6 and regenerates the spec index for check 15,
# through the same reader, and names spec-lint for the defect). A rule with two enforcement
# homes gets qualified in one of them and read from the other.
#
# Usage: sh scripts/docs-lint.sh          (run from anywhere; resolves its own root)
# POSIX sh — no bashisms, no dependencies; runs anywhere /bin/sh exists.
#
# NOTE for maintainers: the awk programs below are single-quoted. An apostrophe anywhere
# inside one — including in a comment — closes the quote, and the shell then parses awk
# source as shell. That failed *silently with status 0* once during authoring, which is
# why `scripts/docs-lint-test.sh` runs `sh -n` on this file before anything else.

set -eu

# Both byte budgets rely on awk length() counting BYTES. It does in the one-true-awk
# that ships on macOS, but gawk in a UTF-8 locale counts CHARACTERS — every em dash in a
# fence would then count 1 instead of 3, so the caps would measure something different
# in CI than they do locally. C locale makes it bytes everywhere.
LC_ALL=C
export LC_ALL

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ── Budgets ────────────────────────────────────────────────────────────────────
#
# RATCHETS AT THE MEASURED LEVEL, not targets. When a doc grows past one, the fix is
# to move detail down a tier — into `docs/`, behind a pointer — which is the entire
# reason the budget is here. Lowering the bar to fit the edit is the failure mode, and
# it is how the sibling project reached 89 KB one justified exception at a time.
#
# ON ADOPTION, re-ratchet ALL FIVE to what this repo measures once its real docs
# exist, rounded up a little. A budget far above the measurement never fires. The
# defaults below are set AFTER a structural cut (the process moved out of CLAUDE.md into
# docs/process/ behind a router), so they are deliberately NOT at the measurement: what
# remains in these files is fences, and a cap pinned at the post-cut size would make the
# first filled-in Project Overview take its bytes from somewhere else. Each carries room,
# stated in words rather than as a number that goes stale: CLAUDE_MAX_BYTES has room for
# a filled Project Overview, Layout, Tech Stack and Code Conventions plus one
# current-work paragraph. ALWAYS_LOADED_MAX_BYTES does NOT have that room: this comment
# once said it had the same room plus two router rows, which the two numbers never allowed
# (the set's headroom was smaller than CLAUDE.md's alone), and the router row that
# docs/process/knowledge-layout.md added spent part of what there was. So filling CLAUDE.md
# in fires this budget first — the adoption re-ratchet above is where it gets its room.
# Re-derive both after any further structural change — a cap that can no longer fail is
# still advertised as a fence.
CLAUDE_MAX_BYTES=11000

# The whole always-loaded set — CLAUDE.md plus every file the router's "Loaded every
# session" table names (the same files CLAUDE.md imports). Derived from that table at
# run time, never transcribed here: a transcribed copy passed a plant that added a third
# row to the table.
ALWAYS_LOADED_MAX_BYTES=26000

# The whole Key Decisions section, measured as bytes. Since the digest left CLAUDE.md the
# section is an intro paragraph and one row per AREA, so this bounds the number of areas,
# not the number of decisions. Derived: the shipped intro is under a kilobyte and a row is
# under a hundred bytes, so this is room for the intro and a few dozen areas. It sits WELL
# under CLAUDE_MAX_BYTES on purpose — the previous value was above the file cap, so it could
# never fire and was still advertised as a fence.
KEY_DECISIONS_MAX_BYTES=2500

# The longest a single FENCE may be — a decision's frontmatter `description`, unescaped. A fence
# is one YAML scalar on one line, so the logical unit and the physical one are the same thing and
# a wrapped fence cannot hide from the cap (the reader refuses a value continued onto a second
# line). Named DIGEST for history: the fences ARE the digest, listed in the generated index.
#
# BYTES, not characters: awk length() is byte-based in the one-true-awk that ships on
# BSD and macOS, so em dashes and smart quotes count for more than one. Named for what
# it actually measures rather than for what would be tidier.
DIGEST_MAX_BYTES=1400

# A delivery doc answers "what shipped and what changed"; the completion template aims
# for well under a page. Applies to every *.md in docs/spec-delivery/, not only those
# tied to a Completed spec. Generous against that aim on purpose — it catches the doc
# that re-explains the code, not the one that ran a little long.
DELIVERY_MAX_LINES=150

CLAUDE="CLAUDE.md"
REGISTER_DIR="docs/decisions"
OLD_REGISTER="docs/decisions.md"
SPEC_DIR="docs/specs"
DELIVERY_DIR="docs/spec-delivery"
PROCESS_DIR="docs/process"
ROUTER="$PROCESS_DIR/INDEX.md"
ROUTING="$PROCESS_DIR/model-routing.md"
OLD_PROCESS="docs/process.md"
RULES_DIR=".claude/rules"
AGENTS_DIR=".claude/agents"
RULEBOOK_DIR="docs/best-practices"
# The frontmatter reader and the index generator are SHARED with spec-lint.sh, so a file is never
# read two ways (docs/process/knowledge-layout.md). Missing either is an environment error, not a
# pass: every check that reads through them would otherwise iterate over nothing.
READER="scripts/frontmatter.awk"
GENERATOR="scripts/gen-index.sh"

# Every failure lands in one file rather than incrementing a counter. A `| while` loop
# runs in a subshell, so a count raised inside one is lost the moment the pipeline ends
# — the bug reads as "the check found nothing" and is invisible in a green run.
total=""
FAILS="${TMPDIR:-/tmp}/docs-lint.$$"
# Every scratch file this script writes is `${TMPDIR:-/tmp}/docs-lint-<name>.$$`, so one glob
# covers them all — a check interrupted midway must not leave its scratch behind.
trap 'rm -f "$FAILS" "${TMPDIR:-/tmp}"/docs-lint-*.$$' EXIT INT TERM
: > "$FAILS"

note() { printf 'FAIL  %s\n' "$1" >> "$FAILS"; }

# Read one governed file through the shared reader, appending its records to $2. Two guards, and
# neither alone is enough: the reader exit status, and exactly one verdict (F) record. An awk
# that dies on a syntax error prints nothing, and a check iterating over no records passes. Called
# from the main shell, never a pipeline, so the `exit 2` reaches the script.
FM_ONE="${TMPDIR:-/tmp}/docs-lint-fmone.$$"
fm_read() {
  [ -f "$READER" ] || { echo "error: docs-lint: the frontmatter reader $READER is missing; docs-lint.sh, spec-lint.sh and gen-index.sh read every frontmatter through it" >&2; exit 2; }
  if ! awk -f "$READER" "$1" > "$FM_ONE" 2> "$FM_ONE.err"; then
    echo "error: docs-lint: the frontmatter reader failed on $1: $(head -1 "$FM_ONE.err")" >&2
    exit 2
  fi
  if [ "$(awk -F'\t' '$2 == "F"' "$FM_ONE" | wc -l | tr -d '[:space:]')" != 1 ]; then
    echo "error: docs-lint: the frontmatter reader returned no single verdict for $1 — a reader that prints nothing passes every check that reads through it" >&2
    exit 2
  fi
  cat "$FM_ONE" >> "$2"
}

report() {
  count=$(grep -c '^FAIL  ' "$FAILS" || true)
  count=${count:-0}
  [ "$count" -gt 0 ] && cat "$FAILS"
  echo "----"
  if [ "$count" -eq 0 ]; then
    if [ -n "${total:-}" ]; then
      echo "docs-lint: ok — $CLAUDE is $size/$CLAUDE_MAX_BYTES bytes; the always-loaded set is $total/$ALWAYS_LOADED_MAX_BYTES."
    else
      echo "docs-lint: ok — $CLAUDE is $size/$CLAUDE_MAX_BYTES bytes."
    fi
    exit 0
  fi
  echo "docs-lint: $count check(s) failed."
  exit 1
}

# Shared by checks 4 and 8: every relative link and `@path.md` / `@path.yaml` pointer in a file
# resolves — `.yaml` because the generated indexes are pointed at the same way.
# Defined here because the register check (4) runs before the always-loaded check (8).
# Code-span-BLIND on purpose — see the note at check 8.
check_pointers() {
  awk '
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      line = $0
      while (match(line, /\]\([^)]+\)/)) {
        p = substr(line, RSTART + 2, RLENGTH - 3)
        line = substr(line, RSTART + RLENGTH)
        sub(/#.*$/, "", p)
        if (p != "" && p !~ /^(https?:|mailto:)/ && p !~ /[*?]/) print p
      }
      line = $0
      while (match(line, /@[A-Za-z0-9_.*?\/-]+\.(md|yaml)/)) {
        p = substr(line, RSTART + 1, RLENGTH - 1)
        line = substr(line, RSTART + RLENGTH)
        # A pointer written as a glob (@docs/specs/SPEC-XXX-*.md) names a shape, not a
        # file. Skipped ON PURPOSE and matched first, so that a real broken pointer is
        # not silently excused by a character class that happened to exclude the star.
        if (p !~ /[*?]/) print p
      }
    }
  ' "$1" | sort -u | while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -e "$p" ] || printf 'FAIL  %s points at "%s", which does not exist.\n' "${2:-$1}" "$p" >> "$FAILS"
  done
}

# The four governed trees — docs/process/, docs/decisions/, .claude/rules/ and
# .claude/agents/ — are each ONE FLAT SET, and each is enumerated through this pair so the
# set cannot differ by tree. It differed three times: a glob skipped the dotfiles in two
# trees, `ls` skipped them in a third, and a subdirectory was invisible in two. Each miss
# has the same shape — a file Claude Code loads and no check here sees — and each was found
# one tree later than the last, which is why this is a helper and not a third fix.
#
# `find -maxdepth 1` takes dotfiles; the glob and `ls` do not. Callers read it through a
# `while IFS= read -r`, which runs in a subshell: safe here because every caller reports
# through `note`, which appends to a FILE, and none of them accumulates a variable.
list_flat_md() { find "$1" -maxdepth 1 -name '*.md' | sort; }
refuse_deep_md() {
  find "$1" -mindepth 2 -name '*.md' | sort | while IFS= read -r deep; do
    note "$deep is in a subdirectory of $1/. $2"
  done
}

# ── 0. The always-loaded file exists ───────────────────────────────────────────
# A repo with no docs/ yet is simply not scaffolded, and there is nothing to hold. But
# once docs/ exists, a MISSING CLAUDE.md is a deletion rather than a pre-scaffold state,
# and going green on the removal of the very file this script constrains is the emptiest
# pass available.
if [ ! -f "$CLAUDE" ]; then
  if [ -d "$SPEC_DIR" ] || [ -d "$REGISTER_DIR" ] || [ -f "$OLD_REGISTER" ]; then
    size=0
    note "$CLAUDE does not exist, but docs/ is scaffolded. The always-loaded file has been
      removed, not merely not-yet-written."
    report
  fi
  echo "docs-lint: no $CLAUDE at $ROOT and no docs/ scaffold — nothing to check."
  exit 0
fi

# ── 1. The always-loaded file is within budget ─────────────────────────────────
# Not `wc | tr` in one pipeline: that takes tr's status, so a wc failure leaves size
# empty and the `if` below — exempt from set -e as a condition — skips the check.
size=$(wc -c < "$CLAUDE") || { echo "error: cannot measure $CLAUDE" >&2; exit 2; }
# An emptied file passes every byte budget trivially, and feeding an empty first file to
# the two-file awk below makes NR==FNR true for the whole REGISTER — which silently
# disarms all three cross-check arms. Truncating instead of deleting was the emptiest
# pass available.
if ! grep -q '[^[:space:]]' "$CLAUDE"; then
  note "$CLAUDE is empty. The always-loaded file cannot be emptied any more than it can be
      deleted: every budget passes trivially and the table/register cross-check disarms."
  size=0
  report
fi
size=$(printf '%s' "$size" | tr -d '[:space:]')
case "$size" in
  ''|*[!0-9]*) echo "error: unreadable size for $CLAUDE" >&2; exit 2 ;;
esac
if [ "$size" -gt "$CLAUDE_MAX_BYTES" ]; then
  note "$CLAUDE is $size bytes against a $CLAUDE_MAX_BYTES budget. It loads every session:
      move the detail into docs/ behind a pointer. Raising this number to fit an edit is the
      failure mode it exists to prevent — cut first, then re-ratchet. After a structural cut, leave
      headroom rather than pinning at the new measurement, and record why beside the number."
fi

# ── 2. Key Decisions is an INTRO and ONE AREA TABLE, measured whole ───────────
#
# Decisions live one file per decision, one directory per area (docs/decisions/<slug>/), and this
# section names the areas. The fixed-shape rule stays — it replaced a markdown parser that shipped
# three rounds of fixes, each opening a fresh escape — and the shape is small: plain prose, then
# exactly one table with the header `| Area | Directory |` and rows
# `| <name> | \`docs/decisions/<slug>/\` |`. Bullets, a second table, prose after the table,
# blockquotes, headings and fenced blocks are refused by name. Every one of them was a way past a
# check once.
#
# An empty table is a parse anchor missing, not an empty set: with no row, every check on the
# register would iterate nothing and pass — so no row FAILS. With at least one row, and every row
# required to name a directory that exists (4a), the register cannot be vacuous.
#
# Terminating conditions (each with a fixture): 2a no section  2b no table row  2c header
# not | Area | Directory |  2d malformed row  2e duplicate area name  2f duplicate directory  2g a
# second table  2h content after the table  2i bullet/list in the intro  2j blockquote in
# the intro  2k indented line in the intro  2l raw HTML in the intro  2m heading inside the
# section  2n fenced block  2o section over KEY_DECISIONS_MAX_BYTES  2p separator row missing
# 2q an | Area | Directory | table outside the section
KD_ROWS="${TMPDIR:-/tmp}/docs-lint-kdrows.$$"
awk -v scap="$KEY_DECISIONS_MAX_BYTES" '
  function bad(why) {
    printf "FAIL  Key Decisions, line %d: %s\n      The section is plain intro prose and ONE table (| Area | Directory |) whose rows name an area\n      and its directory — nothing else. A bullet, a second table, prose after the table, a\n      blockquote, a heading or a fenced block is refused: each was a way past this check once.\n      Offending line: %s\n", FNR, why, substr($0, 1, 60)
  }
  in_sec && /^## /    { in_sec = 0 }
  /^[ \t]*(```|~~~)/ { if (in_sec) { bytes += length($0) + 1; bad("a fenced block") }
                      fence = !fence; next }
  fence               { if (in_sec) bytes += length($0) + 1; next }
  !in_sec && /^## Key Decisions/ { if (!fence) { in_sec = 1; found = 1 } next }
  !in_sec && /^\|[ \t]*Area[ \t]*\|[ \t]*Directory[ \t]*\|/ {
    printf "FAIL  %s, line %d: an | Area | Directory | table outside the Key Decisions section. The section holds the\n      one area table; a second one elsewhere names areas nothing checks.\n", FILENAME, FNR; next }
  !in_sec             { next }
  { bytes += length($0) + 1; sub(/\r$/, "") }
  /^[ \t]*$/          { if (in_table) { in_table = 0; after_table = 1 } next }
  /^\|/ {
    if (after_table) { bad("a second table after the area table"); next }
    if (!in_table) {
      in_table = 1; want_sep = 1
      if ($0 !~ /^\|[ \t]*Area[ \t]*\|[ \t]*Directory[ \t]*\|[ \t]*$/) bad("a table whose header is not | Area | Directory | (a register written before one file per decision: docs/process/knowledge-layout.md, Migrating)")
      next
    }
    if (want_sep) { want_sep = 0; if ($0 !~ /^\|[ \t]*:?-+:?[ \t]*\|[ \t]*:?-+:?[ \t]*\|[ \t]*$/) bad("a table without a |---|---| separator row under its header"); next }
    if ($0 ~ /^\|[ \t]*[^|`][^|`]*\|[ \t]*`docs\/decisions\/[A-Za-z0-9_-]+\/`[ \t]*\|[ \t]*$/) {
      name = $0; sub(/^\|[ \t]*/, "", name); sub(/[ \t]*\|.*$/, "", name)
      slug = $0; sub(/^.*`docs\/decisions\//, "", slug); sub(/\/`.*$/, "", slug)
      if (name in names) bad("a duplicate area name: " name)
      if (slug in slugs) bad("a duplicate area directory: docs/decisions/" slug "/")
      names[name] = 1; slugs[slug] = 1; rows++
      printf "ROW\t%s\t%s\n", name, slug
    } else bad("a row that is not | <area> | `docs/decisions/<slug>/` | — one area, its directory, nothing else in the row")
    next
  }
  in_table            { in_table = 0; after_table = 1 }
  after_table         { bad("content after the area table"); next }
  /^[-*+][ \t]/       { bad("a bullet in the intro — a decision is a file in its area directory"); next }
  /^[0-9]+[.)][ \t]/  { bad("an ordered-list item in the intro"); next }
  /^>/                { bad("a blockquote in the intro"); next }
  /^[ \t]+[^ \t]/     { bad("an indented line in the intro"); next }
  /^</                { bad("raw HTML in the intro"); next }
  /^#/                { bad("a heading inside the section — areas are table rows, not headings"); next }
  { next }
  END {
    if (!found)
      printf "FAIL  No `## Key Decisions` section found. It cannot be renamed, cased differently\n      or hidden behind an unclosed fence earlier in the file: every check on the register\n      goes quiet when the section cannot be located, which is a silent pass.\n"
    else if (!rows)
      printf "FAIL  Key Decisions has no | Area | Directory | table row. With no row every check on the register\n      iterates nothing — an empty table is a missing parse anchor, not an empty set.\n"
    if (bytes > scap)
      printf "FAIL  The Key Decisions section is %d bytes (cap %d). It is an intro and one row per AREA —\n      a decision is a file in its area directory, never a line here.\n", bytes, scap
  }
' "$CLAUDE" > "${TMPDIR:-/tmp}/docs-lint-kd.$$"
grep -v '^ROW	' "${TMPDIR:-/tmp}/docs-lint-kd.$$" >> "$FAILS" || true
grep '^ROW	' "${TMPDIR:-/tmp}/docs-lint-kd.$$" | cut -f2- > "$KD_ROWS" || true
rm -f "${TMPDIR:-/tmp}/docs-lint-kd.$$"

# ── 3, 4 & 5. The register: one directory per area, one file per decision ─────
#
# docs/decisions/<slug>/<slug>.md is the AREA CONCEPT (type: Decision Area — its `title` is the
# area name, its `governs` the code trees its fences apply to), and every other .md beside it is
# one DECISION (type: Decision — `title` the label, `description` the FENCE, optional `status`,
# and a body that is the entry, ending in a dated History). docs/decisions/index.yaml is generated
# from them (check 15) and lists every area's fences; the frontmatter is the one authority. Every
# file is read through the shared reader (docs/process/knowledge-layout.md, The decision register).
#
# The area set and its order belong to the frontmatter, not to this table: the table lists the
# area directories in slug order — the order the index lists them — and each row's name is its
# area's title. Held instead of what the single-file register needed (Contents, anchors, the
# fences-first section, the opening-label checks), which died with the file they guarded.
#
#   3a docs/decisions.md still exists (a stub)   3e docs/decisions/INDEX.md still exists (a stub)
#   3d a row named otherwise than its area's title, or rows out of slug order
#   4a a row whose directory does not exist      4b an area directory with no row
#   4o a .md deeper than docs/decisions/<area>/  4s a .md directly under docs/decisions/
#   4t an area directory with no <slug>.md       4u frontmatter refused, or the wrong type or keys
#   4y a decision named index.md or log.md (OKF reserves both)
#   4v a status other than stable or deprecated  4i a fence over DIGEST_MAX_BYTES
#   4l a decision with no fence (description)    4k a fence with no entry (no body before History)
#   4w History missing (4w1), a date not YYYY-MM-DD (4w2), not strictly newest first (4w3), no
#      dated entry (4w4), or a `##` after it (4w5)   4x a `# ` title line in a decision or area body
#   4n a pointer in a fence that resolves to nothing
#   5a an area declaring globs with no rule      5b a rule whose globs differ from `governs`
#   5c a rule for an area declaring none         5d `governs` missing or not a flow list
#   5e the file at decisions-<slug>.md is not this area's rule (body not template B for it)
[ ! -e "$OLD_REGISTER" ] || note "$OLD_REGISTER exists. The register is one directory per area under $REGISTER_DIR/; there is no
      stub at the old path — a stale pointer must fail, not land on an empty file. Migrating: docs/process/knowledge-layout.md."
[ ! -e "$REGISTER_DIR/INDEX.md" ] || note "$REGISTER_DIR/INDEX.md exists. The register index is $REGISTER_DIR/index.yaml, generated from the
      frontmatter; there is no stub at the old path, and its rules live in docs/process/knowledge-layout.md.
      Migrating a register written before one file per decision: the same part, Migrating."

# 4a — every row names a directory that exists, whether or not docs/decisions/ does: a table
# routing to areas that are not there must fail, not go quiet with the directory.
while IFS='	' read -r name slug; do
  [ -n "$slug" ] || continue
  [ -d "$REGISTER_DIR/$slug" ] || note "$CLAUDE routes area \"$name\" to $REGISTER_DIR/$slug/, which does not exist. A row with no
      directory sends the next session nowhere."
done < "$KD_ROWS"

REG_REC="${TMPDIR:-/tmp}/docs-lint-regrec.$$"
REG_PLAN="${TMPDIR:-/tmp}/docs-lint-regplan.$$"
REG_AREAS="${TMPDIR:-/tmp}/docs-lint-regareas.$$"
: > "$REG_REC"; : > "$REG_PLAN"; : > "$REG_AREAS"
if [ -d "$REGISTER_DIR" ]; then
  # 4s / 4o — the register is directories of files, one level deep, and nothing else. A .md
  # directly under docs/decisions/ is the pre-directory layout (or a stray), and one a level below
  # an area is a decision no index lists and no check reads.
  find "$REGISTER_DIR" -mindepth 1 -maxdepth 1 -type f -name '*.md' | sort | while IFS= read -r f; do
    [ "$f" = "$REGISTER_DIR/INDEX.md" ] && continue   # 3e names it
    note "$f is directly under $REGISTER_DIR/. A decision is a file in its area's directory,
      $REGISTER_DIR/<area>/<decision>.md; a flat area file is the layout before one file per decision
      (docs/process/knowledge-layout.md, Migrating)."
  done
  find "$REGISTER_DIR" -mindepth 3 -name '*.md' | sort | while IFS= read -r f; do
    note "$f is in a subdirectory of an area. Decisions are one flat set per area directory; a file a
      level down is listed by no index and read by no check."
  done
  find "$REGISTER_DIR" -mindepth 1 -maxdepth 1 -type d | sort > "$REG_AREAS"
  # Every governed file through the reader, by redirect so fm_read's exit 2 reaches this shell.
  # The plan records each file's kind: A an area concept, D a decision.
  while IFS= read -r a; do
    slug=${a##*/}
    # 4b — every area directory is a row (dot-directories included: find sees them).
    cut -f2 "$KD_ROWS" | grep -qxF "$slug" || note "$a/ is not a row in the Key Decisions table in $CLAUDE. An area the table does not
      name is a register nobody is pointed at — add the row (in slug order), or move its decisions into
      an area that has one."
    # 4t — the area concept names the area and says what it governs.
    if [ -f "$a/$slug.md" ]; then
      printf 'A\t%s\t%s\n' "$slug" "$a/$slug.md" >> "$REG_PLAN"
      fm_read "$a/$slug.md" "$REG_REC"
    else
      note "$a/ has no $slug.md. Every area directory carries its area concept — type: Decision Area, its
      title the area name and its \`governs\` the trees its fences apply to."
    fi
    find "$a" -mindepth 1 -maxdepth 1 -type f -name '*.md' | sort > "${TMPDIR:-/tmp}/docs-lint-regdec.$$"
    while IFS= read -r d; do
      [ "$d" = "$a/$slug.md" ] && continue
      printf 'D\t%s\t%s\n' "$slug" "$d" >> "$REG_PLAN"
      fm_read "$d" "$REG_REC"
    done < "${TMPDIR:-/tmp}/docs-lint-regdec.$$"
    rm -f "${TMPDIR:-/tmp}/docs-lint-regdec.$$"
  done < "$REG_AREAS"
fi

# 4u, 4v, 4i, 4l, 4y — the frontmatter of each file, for its kind. Writes FAIL lines to $FAILS
# and, for each area whose concept reads, one `AREA <slug> <title>` line plus its governs globs,
# for 3d and 5 below; and each readable decision's fence to a scratch file per decision, for 4n.
REG_AREA_INFO="${TMPDIR:-/tmp}/docs-lint-reginfo.$$"
REG_FENCES="${TMPDIR:-/tmp}/docs-lint-fencelist.$$"
awk -F'\t' -v cap="$DIGEST_MAX_BYTES" -v info="$REG_AREA_INFO" -v fences="$REG_FENCES" \
    -v pfx="${TMPDIR:-/tmp}/docs-lint-fence" -v pid="$$" '
  function out(f, msg) { printf "FAIL  %s: %s\n", f, msg }
  FILENAME == ARGV[1] {
    if ($2 == "F") v[$1] = $3
    else if ($2 == "E") { ne[$1]++; e[$1, ne[$1]] = $3 "\t" $4 }
    else if ($2 == "K") { kind[$1, $3] = "K"; k[$1, $3] = $4 }
    else if ($2 == "L") { kind[$1, $3] = "L"; nl[$1, $3] = $4 }
    else if ($2 == "I") { ni[$1, $3]++; li[$1, $3, ni[$1, $3]] = $4 }
    next
  }
  {
    t = $1; slug = $2; f = $3
    base = f; sub(/^.*\//, "", base)
    if (t == "D" && (base == "index.md" || base == "log.md"))
      out(f, "is named " base ", which OKF reserves at every level of a bundle (index.md a listing, log.md a history). A decision takes a name of its own.")
    if (v[f] != "ok") {
      for (j = 1; j <= ne[f]; j++) { split(e[f, j], p, "\t"); printf "FAIL  %s:%s: frontmatter: %s\n", f, p[1], p[2] }
      printf "      Every .md under docs/decisions/<area>/ opens with frontmatter (docs/process/knowledge-layout.md,\n      The decision register); a register written before one file per decision: the same part, Migrating.\n"
      next
    }
    if (t == "A") {
      if (k[f, "type"] != "Decision Area")
        out(f, "type is \"" k[f, "type"] "\", not \"Decision Area\". " slug ".md is the area concept: its title names the area, its governs says what the area governs.")
      if (kind[f, "title"] != "K" || k[f, "title"] == "") out(f, "frontmatter has no `title` — the area name the Key Decisions row repeats.")
      if (kind[f, "governs"] != "L")
        out(f, "`governs` is " (kind[f, "governs"] == "" ? "missing" : "not a flow list") ". Write the globs the area governs, `governs: [src/api/**, src/models/*.py]`, or `governs: []` for none.")
      if (kind[f, "status"] != "") out(f, "an area concept carries no `status`; a decision does.")
      if (k[f, "type"] == "Decision Area" && k[f, "title"] != "" && kind[f, "governs"] == "L") {
        printf "AREA\t%s\t%s\n", slug, k[f, "title"] > info
        for (j = 1; j <= ni[f, "governs"]; j++) printf "GLOB\t%s\t%s\n", slug, li[f, "governs", j] > info
      }
      next
    }
    if (k[f, "type"] != "Decision")
      out(f, "type is \"" k[f, "type"] "\", not \"Decision\". Every .md in an area directory but the area concept is one decision.")
    if (kind[f, "title"] != "K" || k[f, "title"] == "") out(f, "frontmatter has no `title` — the decision label.")
    d = k[f, "description"]
    if (kind[f, "description"] != "K" || d == "")
      out(f, "has no fence: its frontmatter has no `description`. The fence is the claim and its constraint in one line,\n      and it is what the index lists — an entry no fence points at is a decision that gets re-litigated.")
    else {
      if (length(d) > cap)
        out(f, "its fence (description) is " length(d) " bytes (cap " cap "): " substr(d, 1, 70) "…\n      A fence is the claim and its constraint in one line; the reasoning goes in the entry below.")
      # One scratch file per fence, closed as it is written — awk holds only a few files open.
      n++; ff = pfx n "." pid; printf "%s\n", d > ff; close(ff); printf "%s\t%s\n", f, ff > fences
    }
    s = k[f, "status"]
    if (kind[f, "status"] == "L") out(f, "frontmatter `status` is a list; it takes one value.")
    else if (s == "draft") out(f, "status is \"draft\". A register holds settled decisions; an unsettled one belongs in its spec until it settles.")
    else if (kind[f, "status"] == "K" && s != "stable" && s != "deprecated")
      out(f, "status \"" s "\" is not stable or deprecated (absent means stable). deprecated is for a decision retired with no replacement.")
  }
' "$REG_REC" "$REG_PLAN" >> "$FAILS"

# 4k, 4w, 4x — the BODY of each readable file: the entry, its History, and no second title.
awk -F'\t' '$2 == "F" && $3 == "ok" { print $1 }' "$REG_REC" > "${TMPDIR:-/tmp}/docs-lint-regok.$$"
while IFS='	' read -r t slug f; do
  grep -qxF "$f" "${TMPDIR:-/tmp}/docs-lint-regok.$$" || continue
  start=$(F="$f" awk -F'\t' '$1 == ENVIRON["F"] && $2 == "B" { print $3 }' "$REG_REC")
  awk -v start="$start" -v file="$f" -v kind="$t" '
    function out(msg) { printf "FAIL  %s: %s\n", file, msg }
    function valid(dt,   y, m, d, dim) {
      if (dt !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
      y = substr(dt, 1, 4) + 0; m = substr(dt, 6, 2) + 0; d = substr(dt, 9, 2) + 0
      if (m < 1 || m > 12) return 0
      dim = (m == 2) ? (((y % 4 == 0 && y % 100 != 0) || y % 400 == 0) ? 29 : 28) : ((m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31)
      return d >= 1 && d <= dim
    }
    FNR < start { next }
    { sub(/\r$/, "") }
    /^[ \t]*(```|~~~)/ { fence = !fence; if (!hist) content = 1; next }
    fence { if (!hist) content = 1; next }
    /^# / { out("line " FNR " is a `# ` title line. The title has one home, the frontmatter `title`; the body starts with the entry."); next }
    /^## / {
      h = $0; sub(/^## +/, "", h); sub(/[ \t]+$/, "", h)
      if (kind == "D" && h == "History" && !hist) { hist = 1; next }
      if (hist) out("line " FNR " is a `## " h "` after `## History`. History is the last section: an entry below it is read as history.")
      next
    }
    hist && /^### / {
      dt = $0; sub(/^### +/, "", dt); sub(/[ \t]+$/, "", dt)
      if (!valid(dt)) { out("History heading \"### " dt "\" (line " FNR ") is not a YYYY-MM-DD date. Each entry is dated, OKF log form."); next }
      dates++
      if (last != "" && dt >= last) out("History entry " dt " (line " FNR ") is not older than the one above it (" last "). Entries run newest first, one heading per date.")
      last = dt; next
    }
    !hist && /[^ \t]/ { content = 1 }
    END {
      if (kind != "D") exit
      if (!hist) out("has no `## History`. A decision ends with its dated History, newest first — the first entry is when it was settled.")
      else if (!dates) out("its `## History` has no dated entry (`### YYYY-MM-DD`). The first is when the decision was settled.")
      if (!content) out("is a fence with no entry: nothing above `## History` says what was decided and why. A fence is never the only home of a fact.")
    }
  ' "$f" >> "$FAILS"
done < "$REG_PLAN"
rm -f "${TMPDIR:-/tmp}/docs-lint-regok.$$"

# 3d — the table repeats the areas: each row named by its area's title, the rows in slug order (the
# order the index lists them). Compared only over rows whose area reads; a row with no directory is
# 4a's, and an area that does not read is 4t's or 4u's — one message per defect.
if [ -s "$KD_ROWS" ]; then
  : >> "$REG_AREA_INFO"
  awk -F'\t' -v claude="$CLAUDE" '
    NR == FNR { if ($1 == "AREA") title[$2] = $3; next }
    ($2 in title) {
      if ($1 != title[$2])
        printf "FAIL  %s names area docs/decisions/%s/ \"%s\", but its %s.md title is \"%s\". The row and the title name\n      the area identically; the title is the authority.\n", claude, $2, $1, $2, title[$2]
      n++; got[n] = $2
    }
    END {
      for (i = 2; i <= n; i++) if (got[i] < got[i - 1]) bad = 1
      if (bad) {
        s = got[1]; for (i = 2; i <= n; i++) s = s ", " got[i]
        printf "FAIL  The Key Decisions table lists its areas in the order %s. Rows go in slug order — the order\n      docs/decisions/index.yaml lists them — so the table and the index read alike.\n", s
      }
    }
  ' "$REG_AREA_INFO" "$KD_ROWS" >> "$FAILS"
fi

# 5 — governs ↔ rules. An area that governs a tree has a rule with exactly those globs; an area that
# governs none has no rule. Either direction missing fails by name. Over the areas whose concept
# reads with a `governs` list (5d is 4u's `governs` message above).
if [ -s "$REG_AREA_INFO" ]; then
  awk -F'\t' '$1 == "AREA" { print $2 "\t" $3 }' "$REG_AREA_INFO" > "${TMPDIR:-/tmp}/docs-lint-regareaonly.$$"
  while IFS='	' read -r slug title; do
    rule="$RULES_DIR/decisions-$slug.md"
    want=$(awk -F'\t' -v s="$slug" '$1 == "GLOB" && $2 == s { print $3 }' "$REG_AREA_INFO" | sort -u)
    if [ -z "$want" ]; then
      [ ! -e "$rule" ] || note "$rule exists, but area \"$title\" governs none (\`governs: []\` in $REGISTER_DIR/$slug/$slug.md).
      Declare the globs it governs, or delete the rule."
      continue
    fi
    if [ ! -f "$rule" ]; then
      note "Area \"$title\" governs $(printf '%s' "$want" | tr '\n' ' '| sed 's/ $//'), but $rule does not exist. A governed tree has a
      path-scoped rule with exactly those globs, so the fences fire when a matching file is opened."
      continue
    fi
    # The file must BE this area's rule — template B naming this area — not merely a rule with
    # matching globs. Area rules carry the decisions- prefix so they can never collide with the
    # process rules that share the directory.
    rbody=$(tr -d '\r' < "$rule" | awk 'NR == 1 { next } b { print; next } /^---$/ { b = 1 }')
    rexpect=$(printf 'Files matching these paths are governed by the **%s** decisions in `docs/decisions/%s/`.\nRead the area'"'"'s fences in `docs/decisions/index.yaml` first — they are not loaded with CLAUDE.md.' "$title" "$slug")
    if [ "$rbody" != "$rexpect" ]; then
      note "$rule is not the rule for area \"$title\": its body is not the area template naming
      docs/decisions/$slug/. A rule is bound to its area by its body, not by its globs."
      continue
    fi
    have=$(tr -d '\r' < "$rule" | awk 'NR == 1 { next } /^---$/ { exit } { print }' | sed -n 's/^  - "\([^"]*\)"$/\1/p' | sort -u)
    [ "$want" = "$have" ] || note "$rule lists globs that differ from what area \"$title\" governs.
      governs: $(printf '%s' "$want" | tr '\n' ' ')
      rule:    $(printf '%s' "$have" | tr '\n' ' ')"
  done < "${TMPDIR:-/tmp}/docs-lint-regareaonly.$$"
  rm -f "${TMPDIR:-/tmp}/docs-lint-regareaonly.$$"
fi

# 4n — a pointer written in a fence resolves. Each fence is checked through the same helper as the
# always-loaded files, from a scratch file of its own, and named by its decision.
if [ -f "$REG_FENCES" ]; then
  while IFS='	' read -r f ff; do
    check_pointers "$ff" "$f (its fence)"
    rm -f "$ff"
  done < "$REG_FENCES"
fi
rm -f "$REG_REC" "$REG_PLAN" "$REG_AREAS" "$REG_AREA_INFO" "$REG_FENCES"

# ── 6 & 7. The delivery tier ───────────────────────────────────────────────────
# A spec's status is its frontmatter `spec_status`, read through the shared reader — the body is
# not consulted at all, so a spec quoting "Status: Completed" in an example cannot be mistaken for
# a completed one. A spec whose `spec_status` cannot be read (frontmatter refused, key missing,
# a value outside the vocabulary) FAILS here: a spec this check cannot read would otherwise be
# skipped SILENTLY, and a silent skip of the delivery-doc check is indistinguishable from a pass.
# spec-lint.sh names the defect itself; this only refuses to guess.
#   6a a Completed spec with no delivery doc   6b a spec whose spec_status cannot be read
if [ -d "$SPEC_DIR" ]; then
  FM_REC="${TMPDIR:-/tmp}/docs-lint-fmrec.$$"
  for f in "$SPEC_DIR"/SPEC-*.md; do
    [ -f "$f" ] || continue
    : > "$FM_REC"
    fm_read "$f" "$FM_REC"
    st=$(awk -F'\t' '$2 == "F" { v = $3 } $2 == "K" && $3 == "spec_status" { s = $4 } END { if (v == "ok") print s }' "$FM_REC")
    case "$st" in
      Draft|"In Progress") continue ;;
      Completed) ;;
      *) note "$f: its spec_status cannot be read, so whether it owes a delivery doc cannot be checked — a
      silent skip here is indistinguishable from a pass. spec-lint.sh names the defect; a spec written
      before specs carried frontmatter: docs/process/knowledge-layout.md (Migrating)."
         continue ;;
    esac
    num=$(basename "$f" | sed -n 's/^\(SPEC-[0-9][0-9]*\).*/\1/p')
    [ -n "$num" ] || continue
    found=0
    for d in "$DELIVERY_DIR/$num"-*.md; do
      if [ -f "$d" ]; then found=1; break; fi
    done
    [ "$found" -eq 1 ] || note "$f is Completed with no delivery doc at $DELIVERY_DIR/$num-*.md.
      Step 3 of the completion ritual: what shipped belongs one tier down, not in a fence."
  done
fi

if [ -d "$DELIVERY_DIR" ]; then
  for d in "$DELIVERY_DIR"/*.md; do
    [ -f "$d" ] || continue
    n=$(wc -l < "$d" | tr -d '[:space:]')
    [ "$n" -le "$DELIVERY_MAX_LINES" ] || note "$d is $n lines (cap $DELIVERY_MAX_LINES). A
      delivery doc says what shipped and what changed; past this it is re-explaining the code."
  done
fi

# ── 8. Pointers out of the always-loaded files ─────────────────────────────────
# The always-loaded set only, deliberately. A pointer that goes nowhere defeats the
# layering these files defend: a session sent to a missing file reads the fence in the
# router and stops there. Link-checking every doc in the repo is a different job with a far wider
# false-positive surface, and is not this script business.
#
# This parser is code-span-BLIND on purpose: a pointer written in backticks is still one a
# reader follows, so it must resolve. Check 9 below has a code-span-AWARE parser for the
# opposite question (what does Claude Code actually IMPORT), and the two are different by
# design — do not unify them.
check_pointers "$CLAUDE"

# ── 9–13. The routed process tier: router, imports, parts, rules, agents ───────
#
# `docs/process/` is one file per part behind a router (INDEX.md). Two of them load WITH
# CLAUDE.md as bare `@` imports — the router "Loaded every session" table is the authority
# for which — and the rest are pulled when the router "One file per part" table says.
# Every check here holds a shape the routing depends on. All are gated on the DIRECTORY
# existing, never on the router file: gating on the file would let one change delete the
# router and the two import lines together and take every check below quiet with it. A
# directory with no router fails by name.
#
# Terminating conditions, each with a fixture in tests/docs-lint/ — count them, do not
# guess (a check with two exits is satisfied by a fixture exercising either):
#   9a  the table does not name CLAUDE.md          9b  a table row CLAUDE.md does not import
#   9c  an import the table does not name           9d  the set is over ALWAYS_LOADED_MAX_BYTES
#   9e  a bare @ import in a non-CLAUDE set file    9f  a pointer in a set file goes nowhere
#   10a a part with no router row                   10b a router row with no file
#   11  a stub at the old single-file path           11b docs/process/ exists with no router
#   9h  no Loaded-every-session table (heading is a parse anchor)   10c no One-file-per-part table
#   12a frontmatter not at byte 0                   12b paths missing or written inline
#   12c an illegal glob                             12d a glob matching no file
#   12e a body that is not the template             12f the template names an unrouted part
#   12g a rule in a subdirectory                    12h an unexpected frontmatter key
#   12i an area body that is not template B           12j area rule naming a non-row area
#   12k area rule not named <slug>.md
#   13a an agent with no frontmatter                13b name not equal to the file stem
#   13c a model outside the allowed set             13d a routed agent with no file
#   13e an agent file the routing table omits       13f agents present with no routing table
#   12c also covers a trailing-slash glob; CRLF rule files are normalised before comparing (crlf -ok case)
if [ -d "$PROCESS_DIR" ]; then
  # 11 — no stub. A file at the old path is where a stale pointer lands softly and a new
  # paragraph accretes; a stale pointer should FAIL check 8, not find an empty file.
  [ ! -e "$OLD_PROCESS" ] || note "$OLD_PROCESS exists beside $PROCESS_DIR/. There is no stub at the old
      path: a stale pointer must fail, not land on an empty file, and a new paragraph must land
      in a routed part."
  if [ ! -f "$ROUTER" ]; then
    note "$PROCESS_DIR/ exists with no $ROUTER. The router is the authority for what loads every
      session and for which parts exist; without it every check on the routed tier is blind."
  else
    # Table rows: the first backticked token of each `| ... |` row under a heading, until
    # the next `## `. Header and separator rows carry no backtick and fall out on their own.
    table_paths() {
      awk -v h="$2" '
        index($0, h) == 1 { t = 1; next }
        t && /^## / { t = 0 }
        t && /^\|[ \t]*`[^`]+`/ { match($0, /`[^`]+`/); print substr($0, RSTART + 1, RLENGTH - 2) }
      ' "$1"
    }
    LOADED="${TMPDIR:-/tmp}/docs-lint-loaded.$$"; PARTS="${TMPDIR:-/tmp}/docs-lint-parts.$$"
    IMPORTS="${TMPDIR:-/tmp}/docs-lint-imports.$$"
    table_paths "$ROUTER" "## Loaded every session" | sort -u > "$LOADED"
    table_paths "$ROUTER" "## One file per part"    | sort -u > "$PARTS"
    # 9h / 10c — the two headings are PARSE ANCHORS. A renamed or re-cased heading yields an
    # empty table, and an empty table would make every check below report a confident falsehood
    # (rows "missing" that are present, rules "unrouted" that are fine). Assert the anchor and
    # skip what depends on it; the Key Decisions check guards its own heading the same way.
    have_loaded=1; have_parts=1
    if [ ! -s "$LOADED" ]; then
      have_loaded=0
      note "$ROUTER has no \`## Loaded every session\` table with backticked-path rows. The heading is a
      parse anchor (exact text, exact case) and the rows must backtick the path — without it the
      always-loaded set cannot be derived and checks 9a–9f do not run."
    fi
    if [ ! -s "$PARTS" ]; then
      have_parts=0
      note "$ROUTER has no \`## One file per part\` table with backticked-path rows. The heading is a
      parse anchor (exact text, exact case) and the rows must backtick the path — without it no part
      is routed and checks 10a and 12f do not run."
    fi

    # 9a — the set must name the file whose imports define it.
    [ "$have_loaded" -eq 0 ] || grep -qx "$CLAUDE" "$LOADED" || note "$ROUTER: the Loaded-every-session table does not name $CLAUDE (rows must
      backtick the path). The table is the authority for the always-loaded set, and the set starts
      with the file that imports the rest."

    # Imports: bare `@path.md` outside code spans and fences — what Claude Code actually loads.
    # Code-span-AWARE, unlike check 8, and on purpose (see the note there).
    bare_imports() {
      awk '
        /^[ \t]*(```|~~~)/ { fence = !fence; next }
        fence { next }
        {
          line = $0
          while (match(line, /`[^`]*`/)) {
            pad = sprintf("%*s", RLENGTH, "")
            line = substr(line, 1, RSTART - 1) pad substr(line, RSTART + RLENGTH)
          }
          while (match(line, /@[A-Za-z0-9_.\/-]+\.(md|yaml)/)) {
            pre = (RSTART > 1) ? substr(line, RSTART - 1, 1) : " "
            p = substr(line, RSTART + 1, RLENGTH - 1)
            line = substr(line, RSTART + RLENGTH)
            if (pre !~ /[A-Za-z0-9]/) print p
          }
        }
      ' "$1" | sort -u
    }
    bare_imports "$CLAUDE" > "$IMPORTS"
    if [ "$have_loaded" -eq 1 ]; then
    # 9b / 9c — the two sets agree row for row.
    while IFS= read -r p; do
      [ -n "$p" ] && [ "$p" != "$CLAUDE" ] || continue
      grep -qxF "$p" "$IMPORTS" || note "$ROUTER names \"$p\" as loaded every session, but $CLAUDE does not import
      it (a bare @$p outside backticks). The table and the imports must agree row for row."
    done < "$LOADED"
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      grep -qxF "$p" "$LOADED" || note "$CLAUDE imports \"$p\" (a bare @ outside backticks), which the router
      Loaded-every-session table does not name (rows must backtick the path). An import IS an
      always-loaded file — add the row and make the case, or put the pointer in backticks."
    done < "$IMPORTS"
    # 9d / 9e / 9f — over the set: budget, no nested imports, pointers resolve.
    total=0
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      [ -f "$p" ] || continue   # a missing set file is reported by 9b/check 8, not here
      n=$(wc -c < "$p" | tr -d '[:space:]'); total=$((total + n))
      if [ "$p" != "$CLAUDE" ]; then
        if [ -s "$(bare_imports "$p" > "${TMPDIR:-/tmp}/docs-lint-nested.$$"; echo "${TMPDIR:-/tmp}/docs-lint-nested.$$")" ]; then
          note "$p carries a bare @ import ($(head -1 "${TMPDIR:-/tmp}/docs-lint-nested.$$")). Only $CLAUDE imports; an import in
      an always-loaded file pulls its target in at launch too, through recursion, which is the cost
      this layout exists to avoid. Put the pointer in backticks."
        fi
        rm -f "${TMPDIR:-/tmp}/docs-lint-nested.$$"
        check_pointers "$p"
      fi
    done < "$LOADED"
    [ "$total" -le "$ALWAYS_LOADED_MAX_BYTES" ] || note "The always-loaded set ($(tr '\n' ' ' < "$LOADED")) is $total bytes against a
      $ALWAYS_LOADED_MAX_BYTES budget. Every byte here is paid on every session: move a part behind
      the router, or shorten what the table names — and re-ratchet with headroom, never to fit the
      edit in hand."
    fi
# 10a / 10b — router rows and part files are the same set. Flat, and enumerated with find
    # rather than a glob: a part one directory down is where the next paragraph of process
    # accretes unread, which is the reason 10a exists, and a dotfile is invisible to `*.md`.
    refuse_deep_md "$PROCESS_DIR" "The method is one flat set, one file per router row;
      a part a level down is routed by nothing and read by no one."
    list_flat_md "$PROCESS_DIR" | while IFS= read -r f; do
      [ -f "$f" ] || continue
      [ "$f" = "$ROUTER" ] && continue
      grep -qxF "$f" "$LOADED" && continue   # always-loaded parts are routed by the OTHER table
      [ "$have_parts" -eq 1 ] && [ "$have_loaded" -eq 1 ] || continue   # a missing table is reported once above, not once per part
      grep -qxF "$f" "$PARTS" || note "$f is not a row in the router One-file-per-part table. An unrouted part is where
      the next paragraph of process accretes unread — add the row (what it holds, when to pull it)."
    done
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      [ -f "$p" ] || note "$ROUTER routes to \"$p\", which does not exist. A row with no file sends the next
      session nowhere."
    done < "$PARTS"

    # 12 — rules: one path-scoped pointer per governed tree, body equal to the template.
    if [ -d "$RULES_DIR" ]; then
      # The WORKING TREE, not the tracked set: `git ls-files` would be deterministic, and would
      # also be empty in the corpus harness, which runs this script over a plain directory. The
      # cost is stated rather than hidden — a glob matching only untracked or ignored files
      # (a venv, a build dir) passes here and fails on a clean checkout, so 12d means "matches
      # a file you have", not "matches a file the repo has".
      FILES="${TMPDIR:-/tmp}/docs-lint-files.$$"
      find . -path ./.git -prune -o -type f -print | sed 's|^\./||' > "$FILES"
      # Does any file match a glob of one of the five allowed forms? Anchored on a literal
      # prefix and a literal extension, so no glob engine is involved and nothing is
      # translated: a translation is where two implementations disagree.
      glob_hits() {
        case "$1" in
          # `dir/prefix-*/**`: ONE wildcard, ending the last directory segment. Taken from a
          # consumer whose Lambda directories are named by prefix (`lambdas/archive-*`), which
          # the four literal forms could only spell as a list that goes stale with the next
          # function. Still no glob engine: the prefix is literal, and a hit is a file whose
          # path starts with it and has a `/` somewhere after — the wildcard completes a
          # segment rather than matching across one.
          *'*'/'**')   p="${1%\*/\*\*}";              awk -v p="$p" 'index($0, p) == 1 && index(substr($0, length(p) + 1), "/") > 0 { f = 1; exit } END { exit !f }' "$FILES" ;;
          */'**')      p="${1%/\*\*}/";              awk -v p="$p" 'index($0, p) == 1 { f = 1; exit } END { exit !f }' "$FILES" ;;
          */'**/*.'*)  p="${1%/\*\*/\*.*}/"; e=".${1##*/\*\*/\*.}"
                       awk -v p="$p" -v e="$e" 'index($0, p) == 1 && substr($0, length($0) - length(e) + 1) == e { f = 1; exit } END { exit !f }' "$FILES" ;;
          */'*.'*)     p="${1%/\*.*}/"; e=".${1##*/\*.}"
                       awk -v p="$p" -v e="$e" 'index($0, p) == 1 && index(substr($0, length(p) + 1), "/") == 0 && substr($0, length($0) - length(e) + 1) == e { f = 1; exit } END { exit !f }' "$FILES" ;;
          *)           grep -qxF "$1" "$FILES" ;;
        esac
      }
      refuse_deep_md "$RULES_DIR" "Rules are one flat set, one per governed tree, so the set can be
      enumerated by eye and by this script."
      list_flat_md "$RULES_DIR" | while IFS= read -r r; do
        # 12a — frontmatter opens the file. Anything before it makes the rule ALWAYS-loaded.
        if [ "$(sed -n '1p' "$r" | tr -d '\r')" != "---" ]; then
          note "$r does not open with frontmatter at byte 0. Without it Claude Code loads the rule
      into EVERY session, which turns a scoped pointer into always-loaded prose."
          continue
        fi
        fm=$(tr -d '\r' < "$r" | awk 'NR == 1 { next } /^---$/ { exit } { print }')
        body=$(tr -d '\r' < "$r" | awk 'NR == 1 { next } b { print; next } /^---$/ { b = 1 }')
        # 12b / 12h — the frontmatter is `paths:` and its globs, nothing else.
        printf '%s\n' "$fm" | grep -qx 'paths:' || { note "$r has no \`paths:\` block list in its frontmatter (an inline \`paths: [...]\`
      is refused too). A rule without a block-list paths is always-loaded, or unparseable — both
      silently."; continue; }
        printf '%s\n' "$fm" | grep -v -E '^paths:$|^  - "[^"]+"$' | grep -q . && note "$r carries a frontmatter line that is not \`paths:\` or a \`  - \"glob\"\` entry:
      $(printf '%s\n' "$fm" | grep -v -E '^paths:$|^  - "[^"]+"$' | head -1). A rule is a pointer and nothing else."
        # 12c / 12d — each glob is one of five literal-prefixed forms, and matches something.
        # Judged in two steps, and the order is the design: the ALLOWED TAIL (`/**`, `/**/*.ext`,
        # `/*.ext`, or none) is stripped first, and the HEAD that remains is judged once. Judging
        # the whole glob by pattern was tried and kept leaking — each pattern closed one wildcard
        # shape and the next review found another, because a wildcard can sit in the head several
        # ways and every one of them fell through to 12d, where the literal prefix reported
        # "matches no file" about a tree that exists. The head may carry ONE wildcard: a `*` ending
        # its last segment behind a literal prefix, and only when the tail is `/**` — that is the
        # `dir/prefix-*/**` form. Everything else with a wildcard in it is refused here, by name.
        printf '%s\n' "$fm" | sed -n 's/^  - "\([^"]*\)"$/\1/p' | while IFS= read -r g; do
          case "$g" in
            *'{'*|*'}'*|*'['*|*']'*|*'\'*|'*'*|'/'*|*'/'|'.'|'..'|*'/./'*|*'/../'*)
              note "$r: glob \"$g\" is not allowed. Globs are \`dir/**\`, \`dir/prefix-*/**\`, \`dir/**/*.ext\`,
      \`dir/*.ext\` or an exact path, with a literal first segment — braces and brackets are where two
      glob engines disagree, a backslash is decoded by the awk that measures the glob, a leading
      wildcard scopes a rule to the whole repo, and a trailing slash names a directory, which no rule
      can match."; continue ;;
          esac
          h=$g; t=exact
          case "$g" in
            */'**/*.'*) h=${g%/\*\*/\*.*}; t=ext ;;
            */'**')     h=${g%/\*\*};      t=tree ;;
            */'*.'*)    h=${g%/\*.*};      t=flat ;;
          esac
          if [ "$t" = ext ] || [ "$t" = flat ]; then
            # The TAIL is judged as well as the head, or `docs/**/*.*` reaches 12d and is told the
            # tree does not exist — the head's defect one layer over. The extension after `*.` is
            # one literal: not empty, no wildcard, no `?`, no `/`.
            e=${g##*/\*.}
            case "$e" in
              ''|*'*'*|*'?'*|*'/'*) note "$r: glob \"$g\" ends in an extension that is not literal (\`.$e\`). The tail of
      \`dir/**/*.ext\` and \`dir/*.ext\` is one literal extension — not empty, no wildcard, no \`?\`, no \`/\`."; continue ;;
            esac
          fi
          if [ "$t" = exact ]; then
            case "$g" in *'*'*|*'?'*) note "$r: glob \"$g\" is not one of the five allowed forms (\`dir/**\`, \`dir/prefix-*/**\`,
      \`dir/**/*.ext\`, \`dir/*.ext\`, exact path)."; continue ;; esac
          else
            why=""
            case "$h" in
              *'?'*)        why="\`?\` is allowed in no form" ;;
              *'*'*'*'*)    why="it carries two wildcards" ;;
              *'*'*'/'*)    why="the wildcard sits before a \`/\`, so it would match across a segment" ;;
              *'/*')        why="the wildcard segment has no literal prefix — \`dir/**\` is the form for every child" ;;
              *'*')         [ "$t" = tree ] || why="a wildcard segment is allowed only before \`/**\`, not before \`${g#"$h"}\`" ;;
              *'*'*)        why="the wildcard does not end its segment" ;;
            esac
            if [ -n "$why" ]; then
              note "$r: glob \"$g\" carries a wildcard that is not the single \`prefix-*\` ending its last directory
      segment — $why. The one wildcard form is \`dir/prefix-*/**\`."; continue
            fi
          fi
          glob_hits "$g" || note "$r: glob \"$g\" matches no file in the repo. A rule for a tree that does not exist
      never fires and is still advertised as a backstop."
        done
        # 12e / 12f — the body IS one of two templates: A, rendered for a routed process part;
        # B, rendered for a Key Decisions area (its title and directory, filename = slug).
        part=$(printf '%s\n' "$body" | sed -n '1s/^Files matching these paths are governed by `docs\/process\/\([A-Za-z0-9_-]*\)\.md`\.$/\1/p')
        expect=$(printf 'Files matching these paths are governed by `docs/process/%s.md`.\nRead it before changing one — it is not loaded with CLAUDE.md.' "$part")
        aslug=$(printf '%s\n' "$body" | sed -n '1s/^Files matching these paths are governed by the \*\*.*\*\* decisions in `docs\/decisions\/\([A-Za-z0-9_-]*\)\/`\.$/\1/p')
        if [ -n "$aslug" ]; then
          aname=$(printf '%s\n' "$body" | sed -n '1s/^Files matching these paths are governed by the \*\*\(.*\)\*\* decisions in `docs\/decisions\/.*$/\1/p')
          bexpect=$(printf 'Files matching these paths are governed by the **%s** decisions in `docs/decisions/%s/`.\nRead the area'"'"'s fences in `docs/decisions/index.yaml` first — they are not loaded with CLAUDE.md.' "$aname" "$aslug")
          if [ "$body" != "$bexpect" ]; then
            note "$r: the body is not the two-line area template (\"Files matching these paths are governed by the
      **<Area>** decisions in \`docs/decisions/<slug>/\`.\" / \"Read the area's fences in
      \`docs/decisions/index.yaml\` first — they are not loaded with CLAUDE.md.\")."
          elif ! grep -qxF "$(printf '%s\t%s' "$aname" "$aslug")" "$KD_ROWS" 2>/dev/null; then
            note "$r names area \"$aname\" in docs/decisions/$aslug/, which is not a row of the Key Decisions
      table in $CLAUDE (name and directory must both match a row)."
          elif [ "$(basename "$r" .md)" != "decisions-$aslug" ]; then
            note "$r points at docs/decisions/$aslug/ but is not named decisions-$aslug.md. An area rule is named
      decisions-<slug>.md — for its area directory, and with a prefix no process rule can collide with."
          fi
          continue
        fi
        if [ -z "$part" ] || [ "$body" != "$expect" ]; then
          note "$r: the body is not the two-line process template (\"Files matching these paths are governed by
      \`docs/process/<part>.md\`.\" / \"Read it before changing one — it is not loaded with CLAUDE.md.\") nor
      the area template (\"…governed by the **<Area>** decisions in \`docs/decisions/<slug>/\`.\").
      A committed rule reaches every teammate on every matching Read; a template leaves no room for a
      line that is not a pointer."
        elif [ "$have_parts" -eq 1 ] && ! grep -qxF "$PROCESS_DIR/$part.md" "$PARTS"; then
          note "$r points at docs/process/$part.md, which is not a row in the One-file-per-part table. A rule
      may only route to an on-demand part — an always-loaded file needs no rule, and a pointer to it
      would say something false about when it is read."
        fi
      done
      rm -f "$FILES"
    fi

    # 13 — agents: the roles the routing table names, each carrying an allowed model.
    # 13d runs whenever the TABLE exists, whether or not any agent file does: with the
    # roles directory gone entirely, a table routing to four ghosts must still fail.
    ROUTED="${TMPDIR:-/tmp}/docs-lint-routed.$$"
    : > "$ROUTED"
    have_routing_table=1
    if [ -f "$ROUTING" ]; then
      awk -F'|' '
        index($0, "## The table") == 1 { t = 1; next }
        t && /^## / { t = 0 }
        t && NF >= 4 {
          c = $4
          while (match(c, /`[a-z][a-z0-9-]*`/)) { print substr(c, RSTART + 1, RLENGTH - 2); c = substr(c, RSTART + RLENGTH) }
        }
      ' "$ROUTING" | sort -u > "$ROUTED"
      # 13f — the heading is a PARSE ANCHOR (exact text, exact case), like the two in the
      # router. Renaming it yields an empty roster, and an empty roster makes 13e report one
      # confident falsehood per agent file — "not named in the routing table" for a table that
      # names them all. Assert the anchor and skip what depends on it.
      if [ ! -s "$ROUTED" ]; then
        have_routing_table=0
        note "$ROUTING has no \`## The table\` section with backticked agent names in its Agent column.
      The heading is a parse anchor: with no roster, every check that depends on it reports a
      falsehood — one \"not named in the routing table\" per role — instead of naming this."
      fi
      while IFS= read -r n; do
        [ -n "$n" ] || continue
        [ -f "$AGENTS_DIR/$n.md" ] || note "$ROUTING routes to agent \`$n\`, but $AGENTS_DIR/$n.md does not exist."
      done < "$ROUTED"
    fi
    # 13g — one flat set, the same guard the other three trees carry. Claude Code scans this
    # directory RECURSIVELY, so a file one level down is loaded into a session while every
    # check below — allowed model, name equals stem, named by the routing table — would
    # never see it; a dotfile role escaped the same way until this used list_flat_md.
    if [ -d "$AGENTS_DIR" ]; then
      refuse_deep_md "$AGENTS_DIR" "Roles are one flat set, one per row of the routing table:
      Claude Code loads a role a level down, and the checks here would not see it, so the file would
      be live and unchecked at the same time."
    fi
    if [ -d "$AGENTS_DIR" ] && [ -n "$(list_flat_md "$AGENTS_DIR")" ]; then
      if [ ! -f "$ROUTING" ]; then
        note "$AGENTS_DIR/ has agent files but $ROUTING does not exist. The routing table is what says
      which job each agent and model is for; agents without it are habit, not routing."
      else
        list_flat_md "$AGENTS_DIR" | while IFS= read -r a; do
          stem=$(basename "$a" .md)
          if [ "$(sed -n '1p' "$a" | tr -d '\r')" != "---" ]; then
            note "$a has no frontmatter at byte 0, so it declares no name and no model — the
      routing table cannot bind to it."; continue
          fi
          name=$(tr -d '\r' < "$a" | awk 'NR == 1 { next } /^---$/ { exit } /^name:/ { sub(/^name:[ \t]*/, ""); print }')
          model=$(tr -d '\r' < "$a" | awk 'NR == 1 { next } /^---$/ { exit } /^model:/ { sub(/^model:[ \t]*/, ""); print }')
          [ "$name" = "$stem" ] || note "$a declares name \"$name\" but is named $stem.md. The routing table names
      agents by file stem; a mismatch routes to nothing."
          case "$model" in
            sonnet|opus|haiku|fable) ;;
            *) note "$a declares model \"$model\". Allowed: sonnet, opus, haiku, fable. \`inherit\` and an empty
      model both take whatever the parent runs on, which is exactly what routing by job exists to stop." ;;
          esac
          [ "$have_routing_table" -eq 1 ] || continue   # a missing anchor is reported once above, not once per agent
          grep -qxF "$stem" "$ROUTED" || note "$a is not named in $ROUTING (## The table, Agent column). An agent the table
      does not route to is a role nobody is told to use."
        done
      fi
    fi
    rm -f "$ROUTED"
    rm -f "$LOADED" "$PARTS" "$IMPORTS"
  fi
fi


# ── 14. A dated measurement in the standing tier carries an anchor ────────────
#
# WRITTEN IN LOG-FORGE, and the history below is that repo's: every site, commit and
# percentage named in this block was measured there, on its tree, and is kept because the
# reasoning is the check's specification. Where it says "this repo" it means log-forge.
#
# completion-ritual.md: "Standing rules never cite volatile numbers ... Dating the measurement
# does not save it." That rule was stated, and violated in the tier it governs, at eight
# sites at once — including that section itself, which carried the dated-measurement
# example AND argued that the date was what made it safe. The architecture.md §12 entry
# added by dcb07c3 was one line stale in dcb07c3 itself and outright wrong in a58dfff,
# the very next commit.
#
# So this is the half of that rule a script can hold: a dated measurement must carry a
# commit a reader can re-measure from. A date says WHEN someone looked. It does not say
# AT WHAT, and a reader who does not check it against a calendar reads it as current.
#
# WHAT IT CATCHES, exactly: a bullet, paragraph or comment block in which "measured" or
# "as of" is followed by an ISO date — immediately, or across one adverb of time from a
# closed set (today, now, recently, here, again, … — the list is beside the check, and
# `once` is deliberately not in it) — with no short SHA or version tag in that same unit.
#
# THAT IS ONE SHAPE, NOT THE POPULATION, and the difference is worth stating plainly
# because the next person to widen this will read it. Of the eight sites the commit that
# added this check had to fix, exactly ONE matched — architecture.md §12. Both
# pyproject.toml sites carried a bare count with no date at all; the spec-authoring rules wrote the
# date six words from the word; the completion ritual carried a byte pair with no date. So this
# check does not close the defect class. It closes the sub-shape that DATING creates: a
# number sitting beside a recent date, which is the form that reads as current and
# therefore never gets re-checked. An undated number at least still looks like something
# to verify.
#
# Narrow on purpose, and the narrowness is a false-negative choice, not a coverage claim.
# A SIBLING TRIGGER WAS BUILT AND REJECTED ON MEASUREMENT, not on taste: a transition
# ("146 -> 222") whose unit carries fewer than two distinct SHAs. It failed both ways at
# once. It fired on CODE — an awk program inside this script and two in spec-lint.sh, where
# a digit, a `->` and another digit share a block — and it stayed SILENT on the exact site
# it was written for, because the unit is the whole comment block and a neighbouring
# sentence three lines up carried two SHAs of its own. Catching that site needs
# sentence-granularity, which awk does not have and this script does not buy. What replaced it
# is a rule rather than a check: a standing comment states the current measurement with one
# anchor, or states the principle — it does not write a transition with one end anchored
# and the other on the word "here", which is the shape that went stale one commit later.
#
# A trigger wide enough to catch the other seven would have to fire on any number near
# any date, which is ordinary prose in every one of these files — and a doc gate that
# fires on ordinary prose is a doc gate that gets commented out. The rest stays with
# completion-ritual.md, to be caught by reading. If a future sweep finds a second idiom actually
# in use, add it here and add a fixture for it; do not widen this into a number detector.
#
# THE ANCHOR IS SOUGHT OVER THE WHOLE UNIT, not the line, because the anchor and the
# number routinely wrap apart. That is a deliberate false-NEGATIVE — an unrelated SHA
# elsewhere in the same unit silences the check for it — and it is only tolerable while a
# UNIT STAYS SHORT ENOUGH TO READ. So what ends a unit is load-bearing, not incidental:
# a blank line, a fence, a list marker, a markdown heading, and, outside markdown, ANY
# LINE THAT IS NOT A COMMENT. That last one was missing when this check first covered
# .toml/.sh/.yml, and the cost was measured before it was added: sweeping an unanchored
# measurement through every insertion position of this repo left 27-41% of positions in
# those files silent, against 8-16% in its markdown, because a comment block ran on
# across intervening CODE until the next blank line. One SHA in a comment silenced a
# 15-line array 13 lines below it.
#
# What remains unbounded: a run of ordinary non-comment lines is one unit. In markdown
# that is a paragraph, which is the reading-distance case this rule was designed around.
# In a source file it is code — and the tempting sentence, that a dated measurement is
# not written in code, is FALSE and was written here before it was checked. An INLINE
# comment is not a comment LINE: `fetch-depth: 0  # Measured 2026-09-05: 42 s` joins the
# surrounding code run, and any SHA in that run silences it. Under .github that is not a
# corner case but the norm, since every `uses:` pins its action by SHA — measured on
# release.yml, an inline measurement two lines below a pin is silent while the same text
# on its own comment line fires.
#
# Not closed here, because closing it means telling a comment from a `#` inside a string
# in four languages. The remedy is one sentence to an author instead: WRITE A MEASUREMENT
# ON ITS OWN COMMENT LINE, where the bound applies. An unbalanced fence is the other
# knowing escape — a lone ``` at column 0, in any file type, silences everything below
# it to EOF, and nothing here notices.
#
# ── the population ──
#
# NOT MARKDOWN ONLY. log-forge's architecture §5 says exactly why: "the pointers that rot
# unseen are in SOURCE files — .py docstrings, .toml comments, .yml steps. A markdown-only
# sweep reports the tree clean." Two of the eight sites this check was written for were
# pyproject.toml comments, and a third was a docstring in scripts/. A gate blind to the
# files where a quarter of the known instances lived is half a gate.
#
#   IN:  every *.md at the root (CLAUDE.md, README.md, SECURITY.md and any that join
#        them); docs/**.md except the frozen-record trees below; pyproject.toml when the
#        repo has one; scripts/**; every *.yml and *.yaml under .github, which is workflows AND the
#        composite actions and dependabot.yml beside them — those pin third-party code
#        by SHA and carry the same kind of comment. Both spellings of the extension,
#        because a glob that knows only one silently drops the other.
#   OUT: docs/specs, docs/spec-delivery, docs/templates — and, in a consumer that keeps
#        them, docs/audits and docs/release-notes — FROZEN RECORDS, not standing rules. An
#        audit dated 2026-08-07 is a report of what was true then, and demanding an anchor
#        from it demands an anchor from history.
#   OUT: src/ — deliberately, and not because it is clean. Its docstrings anchor to SPEC
#        numbers by convention rather than to commits, which is a different anchoring
#        scheme; whether a spec number is an acceptable anchor is a decision nobody has
#        taken, and this check must not take it by accident. Recorded, not chased.
#   OUT: tests/ — tests/docs-lint/*.case carry the WRONG form on purpose. A gate that
#        fails on its own fixture corpus is a gate that gets switched off within a week.
#
# The docs half is derived BY EXCLUSION so a standing doc written tomorrow, in a
# directory that does not exist yet, is covered without anyone remembering to list it.
{
  for f in *.md; do [ -f "$f" ] && printf '%s\n' "$f"; done
  [ -f pyproject.toml ] && printf 'pyproject.toml\n'
  if [ -d docs ];    then find docs -type f -name '*.md' -print | sort; fi
  if [ -d scripts ]; then find scripts -type f -print | sort; fi
  if [ -d .github ]; then find .github -type f \( -name '*.yml' -o -name '*.yaml' \) -print | sort; fi
} | while IFS= read -r f; do
    # FROZEN RECORDS, excluded by tree. A consumer that keeps another kind — audits, release
    # notes, an archive — adds its directory here; the scaffold ships the three it creates.
    case "$f" in
      docs/specs/*|docs/spec-delivery/*|docs/templates/*|docs/audits/*|docs/release-notes/*) continue ;;
    esac
    [ -f "$f" ] || continue
    # `#` opens a heading in markdown and a COMMENT in everything else, and the two want
    # opposite unit rules: a heading is its own unit, while consecutive comment lines are
    # one block that an anchor may wrap into. Getting this wrong makes every comment line
    # its own unit, so an anchor on the next line stops counting — which is precisely how
    # the pyproject.toml sites are written.
    md=0
    case "$f" in *.md) md=1 ;; esac
    awk -v file="$f" -v md="$md" '
      # An anchor is a short SHA, and ONLY a short SHA. Two other forms were tried and
      # rejected on evidence rather than taste. A version TAG names a tree as exactly as
      # a SHA does, so it looked like an obvious second form — but version numbers appear
      # in these files for a dozen unrelated reasons, and accepting `vN.N.N` silenced a
      # 37-line region of pyproject.toml on the strength of two release numbers in a
      # classifiers block that anchor nothing. A 7-hex token in prose is almost always an
      # anchor; a version number almost never is. A PR number was never a candidate: it
      # names a change, not a tree, and cannot be re-measured without the network.
      #
      # A short SHA is a hex run of 7+ starting and ending at a non-alphanumeric
      # boundary, containing at least one DIGIT. The digit is what keeps English out:
      # "defaced" is seven hex characters and a word, and silencing this check on it
      # would be a false negative dressed as a feature. A real short SHA without a
      # digit is possible and vanishingly rare (about one in 700). The converse is
      # accepted knowingly: a bare seven-digit decimal is all hex characters and would
      # silence the check too — and the likeliest such number is THE MEASURED VALUE
      # ITSELF, not some unrelated token elsewhere in the unit, so
      # "Measured 2026-09-05: 1234567 events" silences its own violation while the same
      # figure written 1,234,567 does not. Requiring a LETTER as well would close it and
      # would reject the roughly one short SHA in 25 that is all digits, which is the
      # worse trade: that failure is loud and fixed by pasting one more character, and
      # this one is silent.
      function has_anchor(s,   i, n, c, run, digits, dirty) {
        n = length(s); run = 0; digits = 0; dirty = 0
        for (i = 1; i <= n + 1; i++) {
          c = (i <= n) ? substr(s, i, 1) : " "
          if (c ~ /^[0-9a-f]$/)        { run++; if (c ~ /^[0-9]$/) digits++ }
          else if (c ~ /^[0-9A-Za-z]$/) { dirty = 1; run = 0; digits = 0 }
          else {
            if (!dirty && run >= 7 && digits > 0) return 1
            run = 0; digits = 0; dirty = 0
          }
        }
        return 0
      }
      # The separators are the ones this repo actually writes: "Measured 2026-09-01",
      # "Measured, on `f17edd4`", "measured at e565e22". Leaving `at` and the comma out
      # made the two likeliest honest spellings escape while the rule was being followed.
      # ONE ADVERB OF TIME may sit between the verb and the date, from a closed set. The gap
      # was found while the queue paragraphs in docs/process/ were being drafted: both were
      # first written as "Measured here on <date>" with no SHA, this check stayed silent on
      # them, and a read of the draft caught what the gate had not. Those sentences were
      # anchored before they committed, so the evidence a reader can re-run is the FIXTURE
      # SET, not the history.
      #
      # A CLOSED SET, not a bounded run of letters, and the difference is the whole design.
      # The bounded version was built first and rejected on a real false positive: "as of the
      # 2026-08-04 correction below" — a date that NAMES A THING rather than recording when
      # someone looked — fired under it and is silent here. (An earlier draft of this comment
      # claimed "measured against the 2026-08-01 baseline" fired under the bound too; measured,
      # it does not — "the" sits between the adverb slot and the date. The unhedged form,
      # "measured against 2026-08-01 baseline", is the one that fires. Corrected here rather
      # than left standing, since the comment says the next person to widen this will read it.)
      # The FAIL text has no remedy to offer such a sentence — no number to drop, no tree to
      # anchor — so the moves left are a decorative SHA or learning to skip a local gate, which
      # is the damage this check exists to avoid.
      #
      # THE SET IS THE ORDINARY ADVERBS OF TIME, and it has to be: a first cut carried only
      # five and lost everything the bound had caught, so "Measured today on <date>" shipped
      # green — likelier prose than the "here" that prompted the widening. What is deliberately
      # OUT is `once`, which doubles as a conjunction ("Measured once 2026-08-01 landed" names
      # an event, not a measurement), and every determiner and preposition, which is what keeps
      # `as of the <date> <noun>` and `measured against the <date> baseline` silent. A trailing
      # comma is taken after the adverb as well as before it, because "Measured here, on <date>"
      # is the same claim with a pause in it.
      function dated(s) {
        return tolower(s) ~ /(measured|as of)[ \t]*[,:]?[ \t]*((here|again|twice|already|today|now|yesterday|recently|just|lately|then|still|finally|first|initially|currently|originally)[ \t]*[,:]?[ \t]*)?((on|at|in)[ \t]+)?20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]/
      }
      function flush(   where, what) {
        if (unit != "" && dated(unit) && !has_anchor(unit)) {
          where = hitline ? hitline : ustart
          what  = hitline ? hittext : unit
          printf "FAIL  %s:%d carries a dated measurement with no commit to re-measure from.\n      %s\n      A date says WHEN someone looked, not at what: a dated number still reads as\n      current to anyone not checking it against a calendar. Either drop the number and\n      state the principle, or anchor the evidence to a short commit SHA in the same\n      bullet, paragraph or comment block. A version tag is not accepted; the comment\n      beside this check says why. Quoting the wrong form on purpose? Put it in a fenced\n      block, which this check skips. See completion-ritual.md, never cite volatile numbers.\n",
                 file, where, substr(what, 1, 90)
        }
        unit = ""; hitline = 0; ukind = ""
      }
      # In a non-markdown file, is this line a comment or is it not? A unit may not span
      # the two. `kind` reads $0 directly, so it is only meaningful inside a line rule.
      function kind() { return ($0 ~ /^[ \t]*#/) ? "c" : "p" }
      function take(   s) {
        if (unit == "") { unit = $0; ustart = FNR; ukind = kind() }
        else { s = $0; sub(/^[ \t]+/, "", s); unit = unit " " s }
        if (!hitline && dated($0)) { hitline = FNR; hittext = $0 }
      }
      FNR == 1 { flush(); fence = 0 }
      { sub(/\r$/, "") }
      /^[ \t]*(```|~~~)/                { flush(); fence = !fence; next }
      fence                             { next }
      /^[ \t]*$/                        { flush(); next }
      md && /^[ \t]*#/                  { flush(); take(); next }
      /^[ \t]*([-*+]|[0-9]+[.)])[ \t]/  { flush(); take(); next }
      !md && unit != "" && kind() != ukind { flush() }
                                        { take() }
      END { flush() }
    ' "$f" >> "$FAILS"
  done


# ── 15. The generated indexes exist, are fresh, and can be regenerated ────────
#
# An index is a VIEW of the frontmatter, written by scripts/gen-index.sh and never by hand
# (docs/process/knowledge-layout.md). Freshness is regenerate-and-compare: the generator prints
# the index into a temp file and the committed copy must match it byte for byte — the index is
# only ever written, never parsed, so there is no second reading of it to disagree with.
# The generator runs whether or not the index exists, so a tree it refuses is named even when
# the index is missing too: "run the generator" is no remedy when the generator refuses.
#   15a the spec index is missing      15b the spec index is stale
#   15c the decisions index is missing 15d the decisions index is stale
#   15e the generator refuses a tree (its errors are printed)   15f a stub at docs/specs/INDEX.md
#   (the stub at docs/decisions/INDEX.md is 3e, with the register)
GEN_OUT="${TMPDIR:-/tmp}/docs-lint-genout.$$"
GEN_ERR="${TMPDIR:-/tmp}/docs-lint-generr.$$"
check_index() {   # check_index <tree> <specs|decisions>
  idx="$1/index.yaml"
  [ -f "$GENERATOR" ] || { echo "error: docs-lint: the index generator $GENERATOR is missing; docs-lint regenerates every index through it" >&2; exit 2; }
  sh "$GENERATOR" --print "$2" > "$GEN_OUT" 2> "$GEN_ERR" && grc=0 || grc=$?
  case "$grc" in
    0|1) ;;
    *) echo "error: docs-lint: $GENERATOR --print $2 failed (exit $grc): $(head -1 "$GEN_ERR")" >&2; exit 2 ;;
  esac
  [ "$grc" -eq 0 ] || note "$GENERATOR cannot regenerate $idx — it refuses the tree:
$(sed 's/^/      /' "$GEN_ERR")"
  if [ ! -f "$idx" ]; then
    note "$idx is missing. It is generated from the frontmatter: run \`sh $GENERATOR\` and commit it."
  elif [ "$grc" -eq 0 ] && ! cmp -s "$GEN_OUT" "$idx"; then
    note "$idx is stale — it differs from what the frontmatter generates. Run \`sh $GENERATOR\` and commit
      the result; never edit it by hand (a merge conflict in it is resolved the same way)."
  fi
}
if [ -d "$SPEC_DIR" ]; then
  [ ! -e "$SPEC_DIR/INDEX.md" ] || note "$SPEC_DIR/INDEX.md exists. The spec index is $SPEC_DIR/index.yaml, generated from each
      spec's frontmatter; there is no stub at the old path — a stale pointer must fail, not land on an
      empty file. Migrating: docs/process/knowledge-layout.md."
  check_index "$SPEC_DIR" specs
fi
[ ! -d "$REGISTER_DIR" ] || check_index "$REGISTER_DIR" decisions


# ── 16. Rulebooks carry their sources, cite them, and are not stale ────────────
#
# A rulebook states rules an agent follows without checking them, so where a rule rests on a
# version-specific fact it says where the fact came from: OKF `sources` in the frontmatter, and a
# footnote whose label is a source id on the rule (docs/process/knowledge-layout.md, Rulebooks).
# A fabricated or unread citation is the defect this exists to prevent — so every source must be
# cited somewhere, every footnote must resolve to a source, and `stale_after` puts a date on the
# claim that the sources were read. Past that date the rulebook FAILS, and this is the one check
# here that reads the CLOCK as well as the tree: the same commit passes before that instant and
# fails after it, in every repo that carries the rulebook. That is the intent — docs-lint has no
# WARN tier — and the FAIL says what to do. The fixtures use dates far in the past and the future,
# so the corpus is deterministic; there is no "now" override, which would be a bypass.
#
# `stale_after` is narrowed from OKF (any explicit offset) to UTC with `Z`, so "past" is a plain
# byte comparison against `date -u` with no date arithmetic in awk.
#
# The population is every .md under docs/best-practices/ but its INDEX.md, found with `find` so a
# second file in a domain directory, a dotfile or a deeper file is governed too — a rulebook nobody
# held to this is exactly the one that would drift.
#   16a frontmatter refused, or type not Rulebook   16b title, description, sources or stale_after
#   missing   16c a source without id, resource or title   16d a duplicate source id   16e
#   stale_after not YYYY-MM-DDTHH:MM:SSZ (a real date)   16f stale   16g a footnote reference with no
#   definition   16h a footnote label that is no source id   16i a source never cited
if [ -d "$RULEBOOK_DIR" ]; then
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  case "$NOW" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) echo "error: docs-lint: date -u did not give an ISO 8601 UTC instant ($NOW); staleness cannot be judged" >&2; exit 2 ;;
  esac
  RB_LIST="${TMPDIR:-/tmp}/docs-lint-rblist.$$"
  RB_REC="${TMPDIR:-/tmp}/docs-lint-rbrec.$$"
  find "$RULEBOOK_DIR" -type f -name '*.md' | sort > "$RB_LIST"
  # Read by redirect, not a pipe: fm_read exits 2 on a reader failure, and inside a pipeline that
  # exit would end a subshell rather than this script.
  while IFS= read -r f; do
    [ "$f" = "$RULEBOOK_DIR/INDEX.md" ] && continue
    : > "$RB_REC"
    fm_read "$f" "$RB_REC"
    awk -F'\t' -v now="$NOW" -v file="$f" '
      function out(msg) { printf "FAIL  %s: %s\n", file, msg }
      function leap(y) { return (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }
      function instant(v,   y, m, d, dim) {
        if (v !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/) return 0
        y = substr(v, 1, 4) + 0; m = substr(v, 6, 2) + 0; d = substr(v, 9, 2) + 0
        if (m < 1 || m > 12) return 0
        dim = (m == 2) ? (leap(y) ? 29 : 28) : ((m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31)
        if (d < 1 || d > dim) return 0
        if (substr(v, 12, 2) + 0 > 23 || substr(v, 15, 2) + 0 > 59 || substr(v, 18, 2) + 0 > 59) return 0
        return 1
      }
      # Blank every inline code span, so a regex written in a rule (`[^a-z]`) is not read as a
      # footnote. A fenced block is skipped whole, below.
      function nocode(s,   pad) {
        while (match(s, /`[^`]*`/)) { pad = sprintf("%*s", RLENGTH, ""); s = substr(s, 1, RSTART - 1) pad substr(s, RSTART + RLENGTH) }
        return s
      }
      NR == FNR {
        if ($2 == "F") verdict = $3
        else if ($2 == "E") { ne++; eline[ne] = $3; emsg[ne] = $4 }
        else if ($2 == "K") k[$3] = $4
        else if ($2 == "L") lst[$3] = 1
        else if ($2 == "B") body = $3
        else if ($2 == "S") { n = $3 + 0; if (n > nsrc) nsrc = n; sf[n, $4] = $5 }
        next
      }
      verdict != "ok" || FNR < body { next }
      { line = $0 }
      line ~ /^[ \t]*(```|~~~)/ { fence = !fence; next }
      fence { next }
      {
        line = nocode(line)
        # Labels are kept in order of first appearance and reported in that order: awk walks an
        # array in an unspecified order, and the corpus must read the same on every awk.
        if (match(line, /^\[\^[A-Za-z0-9_.-]+\]:/)) {
          lab = substr(line, 3, RLENGTH - 4)
          if (!(lab in def)) { ndef++; defs[ndef] = lab; def[lab] = FNR }
          line = substr(line, RLENGTH + 1)
        }
        while (match(line, /\[\^[A-Za-z0-9_.-]+\]/)) {
          lab = substr(line, RSTART + 2, RLENGTH - 3)
          if (!(lab in ref)) { nref++; refs[nref] = lab; ref[lab] = FNR }
          line = substr(line, RSTART + RLENGTH)
        }
      }
      END {
        if (verdict != "ok") {
          for (i = 1; i <= ne; i++) printf "FAIL  %s:%s: frontmatter: %s\n", file, eline[i], emsg[i]
          printf "      A rulebook opens with frontmatter (docs/process/knowledge-layout.md, Rulebooks); one written\n      before rulebooks carried it: the same part, Migrating. No other rulebook check ran on this file.\n"
          exit
        }
        if (k["type"] != "Rulebook")
          out("type is \"" k["type"] "\", not \"Rulebook\". Every .md under docs/best-practices/ but its INDEX.md is a rulebook.")
        split("title description stale_after", req, " ")
        for (j = 1; j <= 3; j++) if (k[req[j]] == "") out("frontmatter has no `" req[j] "`, or it is empty.")
        if (lst["sources"]) out("`sources` is a flow list. It is the block list of `  - id:` items, each with id, resource and title.")
        else if (!nsrc) out("frontmatter has no `sources`. Every rulebook names what its rules rest on, each source with id, resource and title.")
        for (n = 1; n <= nsrc; n++) {
          for (j = split("id resource title", fld, " "); j >= 1; j--)
            if (sf[n, fld[j]] == "") out("sources item " n " has no `" fld[j] "`.")
          id = sf[n, "id"]
          if (id == "") continue
          if (id in sid) out("source id \"" id "\" is used twice. A footnote resolves to exactly one source.")
          sid[id] = 1
        }
        v = k["stale_after"]
        if (v != "" && !instant(v))
          out("stale_after \"" v "\" is not YYYY-MM-DDTHH:MM:SSZ — a real UTC instant, `Z` for the offset (OKF allows any offset; this subset takes Z, so staleness is a byte comparison).")
        else if (v != "" && now >= v)
          out("is stale since " v ": re-fetch every source it cites, correct any rule a source no longer supports, and move\n      stale_after forward. This check reads the date as well as the tree, by design (docs/process/knowledge-layout.md, Rulebooks).")
        for (i = 1; i <= nref; i++) { lab = refs[i]
          if (!(lab in def)) out("line " ref[lab] " cites [^" lab "] with no `[^" lab "]:` definition.")
          if (!(lab in sid)) out("footnote [^" lab "] (line " ref[lab] ") names no `sources` id. A footnote label IS the source id it attributes to.") }
        for (i = 1; i <= ndef; i++) { lab = defs[i]
          if (!(lab in ref) && !(lab in sid)) out("footnote definition [^" lab "] (line " def[lab] ") names no `sources` id, and nothing cites it.") }
        for (n = 1; n <= nsrc; n++) { id = sf[n, "id"]
          if (id != "" && !(id in ref)) out("source \"" id "\" is never cited. Cite it with [^" id "] on the rule it supports, or drop it: a source nothing cites is a citation nobody checked.") }
      }
    ' "$RB_REC" "$f" >> "$FAILS"
  done < "$RB_LIST"
  rm -f "$RB_LIST" "$RB_REC"
fi


report
