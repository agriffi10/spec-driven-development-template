#!/bin/sh
# docs-lint.sh — hold the ALWAYS-LOADED tier to the shape the layering assumes.
#
# Why this exists as a script rather than a rule. Every check below already existed in
# prose — in `docs/process.md` §5 (*Anti-regrowth & doc hygiene*), in `CLAUDE.md`'s own
# doc-size guardrail, and in `docs/decisions.md`'s rules header — and in the sibling
# project this template was extracted from (`log-forge`, published as `log-foundry`),
# every one of them was violated anyway. That repo's `CLAUDE.md` went from 7,583 bytes
# on 2026-07-09 to 89,340 on 2026-09-02 — monotonically, not one commit reducing it —
# while its own `process.md` named the violation in the present tense throughout and its
# `CLAUDE.md` repeated the confession. It was cut back to 29,515 on 2026-09-02, in the
# same change that first ran this script against it.
#
# A rule a reader has to remember is a rule that rots. This is the same rules where CI
# can see them.
#
# FAIL (exit 1): the always-loaded file is over budget or has been removed outright, a
#   Key Decisions unit has become the reasoning, the register is missing or has inverted
#   with its digest, an entry is unreachable from the Contents, a Completed spec has no
#   delivery doc, a delivery doc has become an essay, or a pointer out of CLAUDE.md goes
#   nowhere.
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
# why `.github/workflows/docs-lint.yml` runs `sh -n` on this file as its own step.

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
# ON ADOPTION, re-ratchet ALL THREE to what this repo measures once its real docs
# exist, rounded up a little. A budget far above the measurement never fires. The
# defaults below are deliberately loose because THIS repo ships a scaffold: its
# CLAUDE.md is placeholders, its Key Decisions holds one example line, and
# docs/spec-delivery/ is empty, so ratcheting them here would fire on the next edit to
# the template itself rather than on anything a project did wrong.
CLAUDE_MAX_BYTES=16000

# The whole Key Decisions section, measured as bytes. This is the guard that cannot be
# evaded by reformatting: a per-bullet cap is escaped by splitting one decision into
# five, and every shape that escaped the old parser still costs bytes here.
# (scaffold default; re-ratchet on adoption)
KEY_DECISIONS_MAX_BYTES=12000

# The longest a single Key Decisions unit may be. Measured on the LOGICAL unit — a
# bullet with its continuation lines joined, or a prose paragraph — because measuring
# the physical line looks equivalent and is not: the moment the section is rewritten as
# wrapped prose the longest physical line collapses to the wrap width, and the guard can
# never fire again while still being advertised in process.md.
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

# Every failure lands in one file rather than incrementing a counter. A `| while` loop
# runs in a subshell, so a count raised inside one is lost the moment the pipeline ends
# — the bug reads as "the check found nothing" and is invisible in a green run.
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
    echo "docs-lint: ok — $CLAUDE is $size/$CLAUDE_MAX_BYTES bytes."
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
      failure mode it exists to prevent — cut first, then re-ratchet at the measurement."
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

# ── 8. Pointers out of the always-loaded file ──────────────────────────────────
# CLAUDE.md only, deliberately. A pointer that goes nowhere defeats the layering this
# file defends: a session sent to a missing register reads the digest and stops there.
# Link-checking every doc in the repo is a different job with a far wider false-positive
# surface, and is not this script business.
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
' "$CLAUDE" | sort -u | while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ -e "$p" ] || printf 'FAIL  %s points at "%s", which does not exist.\n' "$CLAUDE" "$p" >> "$FAILS"
done

report
