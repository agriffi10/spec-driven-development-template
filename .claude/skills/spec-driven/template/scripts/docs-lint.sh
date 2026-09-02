#!/bin/sh
# docs-lint.sh — hold the ALWAYS-LOADED tier to the shape the layering assumes.
#
# Why this exists as a script rather than a rule. Every check below already existed in
# prose — in `docs/process.md` §5 (*Anti-regrowth & doc hygiene*), in `CLAUDE.md`'s own
# doc-size guardrail, and in `docs/decisions.md`'s rules header — and in a sibling
# project running this exact template, every one of them was violated anyway. That
# repo's `CLAUDE.md` went from 7,583 bytes on 2026-07-09 to 87,392 on 2026-09-01 —
# monotonically, not one commit reducing it. Its `process.md` named the violation in the present tense the
# whole time and its `CLAUDE.md` repeated the confession; sessions read both every turn
# and appended regardless, roughly forty times running.
#
# A rule a reader has to remember is a rule that rots. This is the same rules where CI
# can see them.
#
# FAIL (exit 1): the always-loaded file is over budget, a digest bullet has become the
#   reasoning, the register is missing or has inverted with its digest, an entry is
#   unreachable from its Contents, a Completed spec has no delivery doc, a delivery doc
#   has become an essay, or a pointer out of CLAUDE.md goes nowhere.
#
# There is no WARN tier: `spec-lint.sh` owns the soft per-spec judgements, and every
# rule here is a shape the layering depends on — a shape is either held or it isn't.
# Deliberately NOT checked here: anything `spec-lint.sh` already owns (required spec
# sections, banned headers, the FR ceiling). A rule with two enforcement homes gets
# qualified in one of them and read from the other.
#
# Usage: sh scripts/docs-lint.sh          (run from anywhere; resolves its own root)
# POSIX sh — no bashisms, no dependencies; runs anywhere /bin/sh exists.

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ── Budgets ────────────────────────────────────────────────────────────────────
#
# RATCHETS AT THE MEASURED LEVEL, not targets. When a doc grows past one, the fix is
# to move detail down a tier — into `docs/`, behind a pointer — which is the entire
# reason the budget is here. Lowering the bar to fit the edit is the failure mode, and
# it is how the sibling project reached 87 KB one justified exception at a time.
#
# ON ADOPTION: once this repo's real CLAUDE.md exists, re-set CLAUDE_MAX_BYTES to what
# it then measures, rounded up a little. The shipped default suits a scaffold carrying
# a few real decisions; a budget far above the measurement never fires.
CLAUDE_MAX_BYTES=16000

# The longest a single Key Decisions bullet may be, measured on the LOGICAL bullet with
# its continuation lines joined. Measuring the physical line looks equivalent and is
# not: the moment the section is rewritten as wrapped prose the longest physical line
# collapses to the wrap width, and the guard can never fire again while still being
# advertised in process.md. Past this length a digest line has stopped being a reminder
# and become the reasoning, which belongs in the register.
DIGEST_MAX_CHARS=1400

# A delivery doc answers "what shipped and what changed"; the completion template aims
# for well under a page. This cap is generous against that aim on purpose — it catches
# the doc that re-explains the code, not the one that ran a little long.
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

[ -f "$CLAUDE" ] || { echo "docs-lint: no $CLAUDE at $ROOT — nothing to check."; exit 0; }

# ── 1. The always-loaded file's budget ─────────────────────────────────────────
size=$(wc -c < "$CLAUDE" | tr -d '[:space:]')
if [ "$size" -gt "$CLAUDE_MAX_BYTES" ]; then
  note "$CLAUDE is $size bytes against a $CLAUDE_MAX_BYTES budget. It loads every session:
      move the detail into docs/ behind a pointer. Raising this number to fit an edit is the
      failure mode it exists to prevent — cut first, then re-ratchet at the measurement."
fi

# ── 2. Digest bullets, measured joined ─────────────────────────────────────────
# The section runs from "## Key Decisions" to the next level-2 heading. A bullet is a
# "- " line plus every indented continuation beneath it.
awk -v cap="$DIGEST_MAX_CHARS" -v reg="$REGISTER" '
  function flush() {
    if (cur != "" && length(cur) > cap)
      printf "FAIL  A Key Decisions bullet is %d chars (cap %d): %s…\n      Keep the claim and the fence in the digest; the reasoning goes in %s.\n",
             length(cur), cap, substr(cur, 1, 70), reg
    cur = ""
  }
  /^## Key Decisions/ { in_sec = 1; next }
  in_sec && /^## /    { flush(); in_sec = 0 }
  !in_sec             { next }
  /^- /               { flush(); cur = $0; next }
  /^[ \t]+[^ \t]/     { if (cur != "") { s = $0; sub(/^[ \t]+/, "", s); cur = cur " " s } next }
                      { flush() }
  END                 { flush() }
' "$CLAUDE" >> "$FAILS"

# ── 3, 4 & 5. The register: present, not inverted with its digest, all reachable ─
#
# The inversion is the specific failure this template shipped into a project and did
# not catch. That repo has no register at all, so its digest IS the register: every
# settled decision lands full-length in the file that loads on every turn. A digest
# line with no entry behind it is the first step there — and so is the reverse, since
# an entry nobody digested is a decision no session will be pointed at.
#
# Both sides skip the scaffold's own "(example)" placeholder, so a fresh checkout is
# green before the first real decision lands.
if [ ! -f "$REGISTER" ]; then
  note "$REGISTER is missing. Key Decisions in $CLAUDE is a DIGEST — one line per settled
      decision, pointing at its full entry. With no register the digest becomes the only home
      of every fact, which is how an always-loaded file turns into the archive."
else
  # Two files, one pass: NR==FNR is CLAUDE.md, the rest is the register. Comparing the
  # two sets with comm would want process substitution, which is a bashism, and two
  # temp files, which is a rm nobody maintains.
  awk -v claude="$CLAUDE" -v reg="$REGISTER" '
    function anchor(s,   t) {
      t = tolower(s)
      gsub(/`/, "", t); gsub(/\*/, "", t)
      gsub(/^[ \t]+|[ \t]+$/, "", t)
      gsub(/[^a-z0-9 _-]/, "", t)
      gsub(/ /, "-", t)
      return t
    }
    # ---- first file: the always-loaded digest ----
    NR == FNR {
      if ($0 ~ /^## Key Decisions/) { in_sec = 1; next }
      if (in_sec && $0 ~ /^## /)    { in_sec = 0 }
      if (in_sec && $0 ~ /^- \*\*/) {
        s = $0
        sub(/^- \*\*/, "", s)
        i = index(s, "**")
        if (i > 1) {
          label = substr(s, 1, i - 1)
          if (label !~ /^\(example\)/) digest[label] = 1
        }
      }
      next
    }
    # ---- second file: the register ----
    /^### / {
      s = $0; sub(/^### /, "", s)
      if (s !~ /^\(example\)/) { entry[s] = 1; head[anchor(s)] = s }
      next
    }
    {
      line = $0
      while (match(line, /\(#[a-z0-9_-]+\)/)) {
        seen[substr(line, RSTART + 2, RLENGTH - 3)] = 1
        line = substr(line, RSTART + RLENGTH)
      }
    }
    END {
      for (l in digest)
        if (!(l in entry))
          printf "FAIL  Key Decisions carries \"%s\" with no \"### %s\" in %s.\n      Entry first, line second: a digest line is never the only home of a fact.\n", l, l, reg
      for (l in entry)
        if (!(l in digest))
          printf "FAIL  %s has \"### %s\" with no matching bold label in %s Key Decisions.\n      An entry no session is pointed at is a decision that gets re-litigated.\n", reg, l, claude
      for (a in head)
        if (!(a in seen))
          printf "FAIL  %s: \"### %s\" is in no Contents entry — findable only by reading the whole\n      file, which is the cost the layering exists to avoid.\n", reg, head[a]
    }
  ' "$CLAUDE" "$REGISTER" >> "$FAILS"
fi

# ── 6 & 7. The delivery tier ───────────────────────────────────────────────────
if [ -d "$SPEC_DIR" ]; then
  for f in "$SPEC_DIR"/SPEC-*.md; do
    [ -f "$f" ] || continue
    grep -qiE '^[*_ ]*Status[*_ ]*:.*Completed' "$f" || continue
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
# surface, and is not this script's business.
awk '
  {
    line = $0
    while (match(line, /\]\([^)]+\)/)) {
      p = substr(line, RSTART + 2, RLENGTH - 3)
      line = substr(line, RSTART + RLENGTH)
      sub(/#.*$/, "", p)
      if (p != "" && p !~ /^(https?:|mailto:)/) print p
    }
    line = $0
    while (match(line, /@[A-Za-z0-9_.\/-]+\.md/)) {
      print substr(line, RSTART + 1, RLENGTH - 1)
      line = substr(line, RSTART + RLENGTH)
    }
  }
' "$CLAUDE" | sort -u | while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ -e "$p" ] || printf 'FAIL  %s points at "%s", which does not exist.\n' "$CLAUDE" "$p" >> "$FAILS"
done

# ── Report ─────────────────────────────────────────────────────────────────────
count=$(grep -c '^FAIL  ' "$FAILS" || true)
count=${count:-0}
if [ "$count" -gt 0 ]; then cat "$FAILS"; fi
echo "----"
if [ "$count" -eq 0 ]; then
  echo "docs-lint: ok — $CLAUDE is $size/$CLAUDE_MAX_BYTES bytes."
  exit 0
fi
echo "docs-lint: $count check(s) failed."
exit 1
