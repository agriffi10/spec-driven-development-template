#!/bin/sh
# docs-lint.sh — hold the ALWAYS-LOADED tier to the shape the layering assumes.
#
# Why this exists as a script rather than a rule. Every check below already existed in
# prose — in `docs/process/completion-ritual.md` (*Anti-regrowth & doc hygiene*), in `CLAUDE.md`'s own
# doc-size guardrail, and in `docs/decisions.md`'s rules header — and in the sibling
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
# FAIL (exit 1): the always-loaded file is over budget or has been removed outright, a
#   Key Decisions unit has become the reasoning, the register is missing or has inverted
#   with its digest, an entry is unreachable from the Contents, a Completed spec has no
#   delivery doc, a delivery doc has become an essay, a pointer out of an always-loaded file goes
#   nowhere, the routed process tier has lost its shape (router, imports, parts, rules, agents —
#   checks 9–13), or a stub has reappeared at the old single-file path.
#
# There is no WARN tier: `spec-lint.sh` owns the soft per-spec judgements, and every rule
# here is a shape the layering depends on — a shape is either held or it isn't.
# Deliberately NOT checked here: anything `spec-lint.sh` already owns (required spec
# sections, banned headers, the FR ceiling). A rule with two enforcement homes gets
# qualified in one of them and read from the other.
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
# digest would then count 1 instead of 3, so the caps would measure something different
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
# ON ADOPTION, re-ratchet ALL FOUR to what this repo measures once its real docs
# exist, rounded up a little. A budget far above the measurement never fires. The
# defaults below are set AFTER a structural cut (the process moved out of CLAUDE.md into
# docs/process/ behind a router), so they are deliberately NOT at the measurement: what
# remains in these files is fences, and a cap pinned at the post-cut size would make the
# first filled-in Project Overview take its bytes from somewhere else. Each carries room,
# stated in words rather than as a number that goes stale: CLAUDE_MAX_BYTES has room for
# a filled Project Overview, Layout, Tech Stack and Code Conventions plus one
# current-work paragraph; ALWAYS_LOADED_MAX_BYTES has that same room plus two rows in
# the router. Re-derive both after any further structural change — a cap that can no
# longer fail is still advertised as a fence.
CLAUDE_MAX_BYTES=11000

# The whole always-loaded set — CLAUDE.md plus every file the router's "Loaded every
# session" table names (the same files CLAUDE.md imports). Derived from that table at
# run time, never transcribed here: a transcribed copy passed a plant that added a third
# row to the table.
ALWAYS_LOADED_MAX_BYTES=26000

# The whole Key Decisions section, measured as bytes. This is the guard that cannot be
# evaded by reformatting: a per-bullet cap is escaped by splitting one decision into
# five, and every shape that escaped the old parser still costs bytes here.
# (scaffold default; re-ratchet on adoption)
KEY_DECISIONS_MAX_BYTES=12000

# The longest a single Key Decisions unit may be. Measured on the LOGICAL unit — a
# bullet with its continuation lines joined, or a prose paragraph — because measuring
# the physical line looks equivalent and is not: the moment the section is rewritten as
# wrapped prose the longest physical line collapses to the wrap width, and the guard can
# never fire again while still being advertised in the process docs.
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
REGISTER="docs/decisions.md"
SPEC_DIR="docs/specs"
DELIVERY_DIR="docs/spec-delivery"
PROCESS_DIR="docs/process"
ROUTER="$PROCESS_DIR/INDEX.md"
ROUTING="$PROCESS_DIR/model-routing.md"
OLD_PROCESS="docs/process.md"
RULES_DIR=".claude/rules"
AGENTS_DIR=".claude/agents"

# Every failure lands in one file rather than incrementing a counter. A `| while` loop
# runs in a subshell, so a count raised inside one is lost the moment the pipeline ends
# — the bug reads as "the check found nothing" and is invisible in a green run.
total=""
FAILS="${TMPDIR:-/tmp}/docs-lint.$$"
trap 'rm -f "$FAILS"' EXIT INT TERM
: > "$FAILS"

note() { printf 'FAIL  %s\n' "$1" >> "$FAILS"; }

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

# ── 0. The always-loaded file exists ───────────────────────────────────────────
# A repo with no docs/ yet is simply not scaffolded, and there is nothing to hold. But
# once docs/ exists, a MISSING CLAUDE.md is a deletion rather than a pre-scaffold state,
# and going green on the removal of the very file this script constrains is the emptiest
# pass available.
if [ ! -f "$CLAUDE" ]; then
  if [ -d "$SPEC_DIR" ] || [ -f "$REGISTER" ]; then
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
      deleted: every budget passes trivially and the digest/register cross-check disarms."
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

# ── 2. Key Decisions has a FIXED SHAPE, and is measured whole ────────────────
#
# This replaced a markdown parser, after that parser shipped three rounds of fixes and
# each round introduced a fresh escape: prose evaded a bullet-only cap; widening the cap
# to accept indented bullets let a parent-plus-children decision escape; adding boundary
# rules for tables, blockquotes and fences made every one of those a place where content
# was consumed and never measured at all. Eight escapes in the end, five of them
# regressions from the previous fix.
#
# The lesson is that this file's format is OURS. Parsing arbitrary markdown is an
# unbounded problem; validating a fixed shape is a bounded one. So the section may
# contain only four things, and anything else fails LOUDLY rather than silently sliding
# past a cap that cannot see it:
#
#   - a `### ` area heading at column 0
#   - a `- **Label** — …` bullet at column 0
#   - an indented continuation of the bullet above it
#   - a blank line
#
# plus free prose BEFORE the first area heading, which is the section intro. A table, a
# blockquote, a fenced block, an indented bullet, an ordered list, a task list and
# `__bold__` are all refused by name. That is not a limitation to work around: every one
# of them was an escape.
#
# The section is also measured WHOLE, against KEY_DECISIONS_MAX_BYTES. A per-unit cap
# can always be evaded by splitting; a section total cannot be evaded by reformatting,
# because every escape still costs bytes.
kd_report=$(awk -v ucap="$DIGEST_MAX_BYTES" -v scap="$KEY_DECISIONS_MAX_BYTES" -v reg="$REGISTER" '
  function flush(   n) {
    if (unit == "") return
    n = length(unit)
    if (n > ucap)
      printf "FAIL  A Key Decisions bullet is %d bytes (cap %d): %s…\n      Keep the claim and the fence in the digest; the reasoning goes in %s.\n",
             n, ucap, substr(unit, 1, 70), reg
    # A bullet whose ** never closes is a decision the register cross-check cannot see:
    # it parses as a valid bullet and yields no label, so nothing demands an entry.
    if (unit ~ /^- \*\*/ && !has_close(unit))
      printf "FAIL  A Key Decisions bullet never closes its `**` label: %s…\n      An unclosed label yields no label at all, so nothing requires a register entry for it.\n",
             substr(unit, 1, 70)
    unit = ""
  }
  function has_close(u,   s, i, j, k, p) {
    s = u; sub(/^- \*\*/, "", s)
    p = 1
    while ((j = index(substr(s, p), "**")) > 0) {
      k = p + j - 1
      if (substr(s, k + 2, 1) != "*") return (k > 1)
      p = k + 1
    }
    return 0
  }
  function bad(why) {
    printf "FAIL  Key Decisions, line %d: %s\n      The section has a fixed shape — area headings, `- **Label**` bullets at column 0,\n      indented continuations, blank lines, and plain intro prose before the first heading.\n      Anything else is refused because every one of them was a way past this check.\n      Offending line: %s\n", FNR, why, substr($0, 1, 60)
  }
  # The section CLOSES on any level-2 heading, tested before the opener. Leaving the
  # opener first meant a second `## Key Decisions — see also …` line was swallowed at
  # zero cost while still inside the section: 14 KB of decisions measured as 51 bytes.
  in_sec && /^## /    { flush(); in_sec = 0 }
  # Fences are tracked file-wide so a fenced example cannot open a phantom section.
  /^[ \t]*(```|~~~)/ { if (in_sec) { bytes += length($0) + 1; bad("a fenced block") }
                      fence = !fence; next }
  fence               { if (in_sec) bytes += length($0) + 1; next }
  !in_sec && /^## Key Decisions/ { if (!fence) { in_sec = 1; found = 1 } next }
  !in_sec             { next }
  { bytes += length($0) + 1 }
  /^###[ \t]/          { flush(); seen_area = 1; next }
  /^[ \t]*\r?$/       { flush(); next }
  # The intro, before the first area heading, may be PLAIN PROSE and nothing else. It
  # was previously exempt from every rule, which made it a hole the size of the section
  # budget — and the shipped scaffold had no area heading at all, so its whole section
  # sat in that hole with every shape check switched off.
  !seen_area && /^[|>]/            { bad("a table or blockquote row in the intro") ; next }
  !seen_area && /^[0-9]+[.)][ \t]/ { bad("an ordered-list item in the intro") ; next }
  !seen_area && /^[-*+][ \t]/      { bad("a bullet before the first `### ` area heading") ; next }
  !seen_area && /^[ \t]+[^ \t]/    { bad("an indented line in the intro") ; next }
  !seen_area && /^</                { bad("raw HTML in the intro") ; next }
  !seen_area          { next }
  /^- \*\*/            { flush(); unit = $0; next }
  /^- /               { bad("a bullet that does not open with a **bold label**") ; next }
  /^[ \t]+[^ \t]/     { if (unit == "") { bad("indented line with no bullet above it to continue") ; next }
                        s = $0; sub(/^[ \t]+/, "", s); unit = unit " " s; next }
  /^[|>]/             { bad("a table or blockquote row") ; next }
  /^[0-9]+[.)][ \t]/  { bad("an ordered-list item") ; next }
  /^[*+][ \t]/        { bad("a `*` or `+` bullet — use `-`") ; next }
                      { bad("prose after the first area heading") ; next }
  END {
    flush()
    # Nothing else in this file notices a section that is missing, misspelled, or hidden
    # behind an unbalanced fence earlier in the document — and each of those turned every
    # check above into a silent pass.
    if (!found)
      printf "FAIL  No `## Key Decisions` section found. It cannot be renamed, cased differently\n      or hidden behind an unclosed fence earlier in the file: every check on the digest\n      goes quiet when the section cannot be located, which is a silent pass.\n"
    else if (!seen_area)
      printf "FAIL  Key Decisions has no `### ` area heading. It is grouped by AREA, not by spec, and\n      the shape checks on bullets only begin at the first heading — a section with none\n      sits entirely in the intro, unvalidated.\n"
    if (bytes > scap)
      printf "FAIL  The Key Decisions section is %d bytes (cap %d). It is the bulk of the file that\n      loads every session: move decisions into %s and leave one line each.\n", bytes, scap, reg
  }
' "$CLAUDE")
[ -z "$kd_report" ] || printf '%s\n' "$kd_report" >> "$FAILS"

# ── 3, 4 & 5. The register: present, not inverted with its digest, all reachable ─
#
# The inversion is the specific failure this template shipped into a project and did
# not catch. That repo had no register at all, so its digest WAS the register: every
# settled decision landed full-length in the file that loads on every turn. A digest
# line with no entry behind it is the first step there — and so is the reverse, since
# an entry nobody digested is a decision no session will be pointed at.
#
# Both sides skip the scaffold "(example)" placeholder, so a fresh checkout is green
# before the first real decision lands.
if [ ! -f "$REGISTER" ]; then
  note "$REGISTER is missing. Key Decisions in $CLAUDE is a DIGEST — one line per settled
      decision, pointing at its full entry. With no register the digest becomes the only home
      of every fact, which is how an always-loaded file turns into the archive."
else
  # Two files, one pass: NR==FNR is CLAUDE.md, the rest is the register. Comparing the
  # two sets with comm would want process substitution, which is a bashism.
  awk -v claude="$CLAUDE" -v reg="$REGISTER" '
    function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
    function emit(   s, i, j, k, p, pad, orig, label) {
      if (unit == "" || unit !~ /^- \*\*/) { unit = ""; return }
      s = unit; sub(/^- \*\*/, "", s)
      # Blank out inline code spans first: a span containing ** would otherwise close
      # the label early, the same class as the italic-suffix bug below.
      while (match(s, /`[^`]*`/)) {
        pad = sprintf("%*s", RLENGTH, "")
        s = substr(s, 1, RSTART - 1) pad substr(s, RSTART + RLENGTH)
      }
      # The closing ** is the first NOT followed by another *. A label ending in an
      # italic (...skip *work*) is stored as *work***, and taking the first pair
      # truncates it by one character — reported as both halves of the cross-check
      # missing, for a label that is correct.
      i = 0; p = 1
      while ((j = index(substr(s, p), "**")) > 0) {
        k = p + j - 1
        if (substr(s, k + 2, 1) != "*") { i = k; break }
        p = k + 1
      }
      if (i > 1) {
        orig = unit; sub(/^- \*\*/, "", orig)
        label = trim(substr(orig, 1, i - 1))
        if (label !~ /^\(example\)/) digest[label] = 1
      }
      unit = ""
    }
    function anchor(s,   t) {
      t = tolower(trim(s))
      gsub(/`/, "", t); gsub(/\*/, "", t)
      gsub(/[^a-z0-9 _-]/, "", t)
      gsub(/ /, "-", t)
      return t
    }
    # ---- first file: the always-loaded digest ----
    # Check 2 has already refused every shape but `- **Label**` at column 0 with indented
    # continuations, so this only has to join a wrapped label and find its closing `**`.
    NR == FNR {
      if ($0 ~ /^[ \t]*(```|~~~)/) { kfence = !kfence; next }
      if (kfence) next
      if (kd && $0 ~ /^## /)        { emit(); kd = 0 }
      if (!kd && $0 ~ /^## Key Decisions/) { if (!kfence) kd = 1; next }
      if (!kd) next
      sub(/\r$/, "")
      if ($0 ~ /^- /)               { emit(); unit = $0; next }
      if ($0 ~ /^[ \t]+[^ \t]/)     { if (unit != "") { s = $0; sub(/^[ \t]+/, "", s); unit = unit " " s } next }
      emit()
      next
    }
    # ---- second file: the register ----
    # Anchors are collected ONLY from the Contents section. Collecting them from the
    # whole file let one entry cross-reference another and satisfy the check for it,
    # so an entry absent from the Contents passed while the message said it was there.
    /^## Contents/ { in_toc = 1; next }
    in_toc && /^## / { in_toc = 0 }
    in_toc && /^[ \t]*---[ \t]*$/ { in_toc = 0 }
    /^### / {
      s = trim(substr($0, 5))
      if (s !~ /^\(example\)/) { entry[s] = 1; head[anchor(s)] = s }
      next
    }
    in_toc {
      line = $0
      while (match(line, /\(#[a-z0-9_-]+\)/)) {
        seen[substr(line, RSTART + 2, RLENGTH - 3)] = 1
        line = substr(line, RSTART + RLENGTH)
      }
    }
    END {
      emit()
      for (l in digest)
        if (!(l in entry))
          printf "FAIL  Key Decisions carries \"%s\" with no \"### %s\" in %s.\n      Entry first, line second: a digest line is never the only home of a fact.\n", l, l, reg
      for (l in entry)
        if (!(l in digest))
          printf "FAIL  %s has \"### %s\" with no matching bold label in %s Key Decisions.\n      An entry no session is pointed at is a decision that gets re-litigated.\n", reg, l, claude
      for (a in head)
        if (!(a in seen))
          printf "FAIL  %s: \"### %s\" is absent from the Contents — findable only by reading the\n      whole file, which is the cost the layering exists to avoid.\n", reg, head[a]
    }
  ' "$CLAUDE" "$REGISTER" >> "$FAILS"
fi

# ── 6 & 7. The delivery tier ───────────────────────────────────────────────────
# The Status match is deliberately permissive about what sits between "Status" and
# "Completed" — ": ", " | " in a table row, "**" — because a spec whose header form
# this fails to recognise is skipped SILENTLY, and a silent skip of the delivery-doc
# check is indistinguishable from a pass.
if [ -d "$SPEC_DIR" ]; then
  for f in "$SPEC_DIR"/SPEC-*.md; do
    [ -f "$f" ] || continue
    # Fence-aware: a Draft spec that quotes the completion ritual in a fenced block
    # would otherwise be read as Completed and told it owes a delivery doc.
    awk '
      /^[ \t]*(```|~~~)/ { fence = !fence; next }
      fence { next }
      tolower($0) ~ /^[^a-z]*status[^a-z]+completed/ { found = 1 }
      END { exit !found }
    ' "$f" || continue
    num=$(basename "$f" | sed -n 's/^\(SPEC-[0-9][0-9]*\).*/\1/p')
    [ -n "$num" ] || continue
    found=0
    for d in "$DELIVERY_DIR/$num"-*.md; do
      if [ -f "$d" ]; then found=1; break; fi
    done
    [ "$found" -eq 1 ] || note "$f is Completed with no delivery doc at $DELIVERY_DIR/$num-*.md.
      Step 3 of the completion ritual: what shipped belongs one tier down, not in the digest."
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
# layering these files defend: a session sent to a missing register reads the digest and
# stops there. Link-checking every doc in the repo is a different job with a far wider
# false-positive surface, and is not this script business.
#
# This parser is code-span-BLIND on purpose: a pointer written in backticks is still one a
# reader follows, so it must resolve. Check 9 below has a code-span-AWARE parser for the
# opposite question (what does Claude Code actually IMPORT), and the two are different by
# design — do not unify them.
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
      while (match(line, /@[A-Za-z0-9_.*?\/-]+\.md/)) {
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
    [ -e "$p" ] || printf 'FAIL  %s points at "%s", which does not exist.\n' "$1" "$p" >> "$FAILS"
  done
}
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
          while (match(line, /@[A-Za-z0-9_.\/-]+\.md/)) {
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
# 10a / 10b — router rows and part files are the same set.
    for f in "$PROCESS_DIR"/*.md; do
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
      FILES="${TMPDIR:-/tmp}/docs-lint-files.$$"
      find . -path ./.git -prune -o -type f -print | sed 's|^\./||' > "$FILES"
      # Does any file match a glob of one of the four allowed forms? Anchored on a literal
      # prefix and a literal extension, so no glob engine is involved and nothing is
      # translated: a translation is where two implementations disagree.
      glob_hits() {
        case "$1" in
          */'**')      p="${1%/\*\*}/";              awk -v p="$p" 'index($0, p) == 1 { f = 1; exit } END { exit !f }' "$FILES" ;;
          */'**/*.'*)  p="${1%/\*\*/\*.*}/"; e=".${1##*/\*\*/\*.}"
                       awk -v p="$p" -v e="$e" 'index($0, p) == 1 && substr($0, length($0) - length(e) + 1) == e { f = 1; exit } END { exit !f }' "$FILES" ;;
          */'*.'*)     p="${1%/\*.*}/"; e=".${1##*/\*.}"
                       awk -v p="$p" -v e="$e" 'index($0, p) == 1 && index(substr($0, length(p) + 1), "/") == 0 && substr($0, length($0) - length(e) + 1) == e { f = 1; exit } END { exit !f }' "$FILES" ;;
          *)           grep -qxF "$1" "$FILES" ;;
        esac
      }
      find "$RULES_DIR" -name '*.md' | sort | while IFS= read -r r; do
        rel="${r#$RULES_DIR/}"
        case "$rel" in */*) note "$r is in a subdirectory of $RULES_DIR/. Rules are one flat set, one per governed
      tree, so the set can be enumerated by eye and by this script."; continue ;; esac
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
        # 12c / 12d — each glob is one of four literal-prefixed forms, and matches something.
        printf '%s\n' "$fm" | sed -n 's/^  - "\([^"]*\)"$/\1/p' | while IFS= read -r g; do
          case "$g" in
            *'{'*|*'}'*|*'['*|*']'*|'*'*|'/'*|*'/'|'.'|'..'|*'/./'*|*'/../'*)
              note "$r: glob \"$g\" is not allowed. Globs are \`dir/**\`, \`dir/**/*.ext\`, \`dir/*.ext\` or
      an exact path, with a literal first segment — braces and brackets are where two glob engines
      disagree, a leading wildcard scopes a rule to the whole repo, and a trailing slash names a
      directory, which no rule can match."; continue ;;
            */'**'|*/'**/*.'*|*/'*.'*) ;;
            *'*'*|*'?'*) note "$r: glob \"$g\" is not one of the four allowed forms (\`dir/**\`, \`dir/**/*.ext\`,
      \`dir/*.ext\`, exact path)."; continue ;;
          esac
          glob_hits "$g" || note "$r: glob \"$g\" matches no file in the repo. A rule for a tree that does not exist
      never fires and is still advertised as a backstop."
        done
        # 12e / 12f — the body IS the template, rendered for a routed part.
        part=$(printf '%s\n' "$body" | sed -n '1s/^Files matching these paths are governed by `docs\/process\/\([A-Za-z0-9_-]*\)\.md`\.$/\1/p')
        expect=$(printf 'Files matching these paths are governed by `docs/process/%s.md`.\nRead it before changing one — it is not loaded with CLAUDE.md.' "$part")
        if [ -z "$part" ] || [ "$body" != "$expect" ]; then
          note "$r: the body is not the two-line template (\"Files matching these paths are governed by
      \`docs/process/<part>.md\`.\" / \"Read it before changing one — it is not loaded with CLAUDE.md.\").
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
    if [ -f "$ROUTING" ]; then
      awk -F'|' '
        index($0, "## The table") == 1 { t = 1; next }
        t && /^## / { t = 0 }
        t && NF >= 4 {
          c = $4
          while (match(c, /`[a-z][a-z0-9-]*`/)) { print substr(c, RSTART + 1, RLENGTH - 2); c = substr(c, RSTART + RLENGTH) }
        }
      ' "$ROUTING" | sort -u > "$ROUTED"
      while IFS= read -r n; do
        [ -n "$n" ] || continue
        [ -f "$AGENTS_DIR/$n.md" ] || note "$ROUTING routes to agent \`$n\`, but $AGENTS_DIR/$n.md does not exist."
      done < "$ROUTED"
    fi
    if [ -d "$AGENTS_DIR" ] && ls "$AGENTS_DIR"/*.md >/dev/null 2>&1; then
      if [ ! -f "$ROUTING" ]; then
        note "$AGENTS_DIR/ has agent files but $ROUTING does not exist. The routing table is what says
      which job each agent and model is for; agents without it are habit, not routing."
      else
        for a in "$AGENTS_DIR"/*.md; do
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
          grep -qxF "$stem" "$ROUTED" || note "$a is not named in $ROUTING (## The table, Agent column). An agent the table
      does not route to is a role nobody is told to use."
        done
      fi
    fi
    rm -f "$ROUTED"
    rm -f "$LOADED" "$PARTS" "$IMPORTS"
  fi
fi

report
