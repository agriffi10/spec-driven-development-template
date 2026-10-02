#!/bin/sh
# gen-index.sh — write the generated indexes from the frontmatter they summarise.
#
#   sh scripts/gen-index.sh                    write docs/specs/index.yaml and docs/decisions/index.yaml,
#                                              each only when its tree exists
#   sh scripts/gen-index.sh --print specs      print one index to stdout and write nothing
#   sh scripts/gen-index.sh --print decisions
#
# Exit: 0 written (or printed); 1 a tree was REFUSED — its errors on stderr, its index left exactly
# as it was, any other tree still written; 2 a usage or environment error.
#
# Nobody edits an index by hand. The frontmatter is the one authority (docs/process/knowledge-layout.md)
# and an index is a view of it, so `docs-lint.sh` regenerates each one into a temp file and fails
# the committed copy when the bytes differ. A merge conflict in an index is resolved by running this,
# never by hand.
#
# Deterministic by construction, which is what makes a byte comparison a freshness check: no
# timestamps, every sort under LC_ALL=C, and every string emitted double-quoted with `\` and `"`
# escaped — uniform, valid YAML whatever an author put in a title.
#
# It reads every file through the shared reader (`frontmatter.awk`) with the same two guards the
# linters use, and it REFUSES a tree — writes nothing for it — when any file in it cannot be read,
# or lacks a key the index emits. It does not validate vocabularies, ids or arcs: those belong to
# the linters, and a refusal names the file so the linter can say what is wrong with it.
#
# POSIX sh and awk — no dependencies.

set -eu
LC_ALL=C
export LC_ALL

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
READER="scripts/frontmatter.awk"
SPEC_DIR="docs/specs"
REGISTER_DIR="docs/decisions"
TAB=$(printf '\t')

SCRATCH="${TMPDIR:-/tmp}/gen-index.$$"
TMP_INDEX=""
trap 'rm -f "$SCRATCH".* ${TMP_INDEX:+"$TMP_INDEX"}' EXIT
trap 'exit 2' INT TERM

# Every step below is checked by hand rather than left to `set -e`, which is OFF inside a function
# called as an `if` condition or in an `||` list — exactly how the write and print paths call one.
# A failed awk would otherwise leave an empty key list and the index would be written as `[]`.
die() { echo "error: $1" >&2; exit 2; }

usage() { echo "usage: sh scripts/gen-index.sh [--print specs|decisions]" >&2; exit 2; }

[ -f "$READER" ] || { echo "error: the frontmatter reader $READER is missing" >&2; exit 2; }

# Every file in a list through the reader, records appended to $2. Exit 2 — not a refusal — when
# the reader fails or returns anything but one verdict: an empty read would generate an index that
# lists nothing, and a stale index compared against it would look fresh.
read_all() {
  : > "$2"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    awk -f "$READER" "$f" > "$SCRATCH.one" 2> "$SCRATCH.err" ||
      die "the frontmatter reader failed on $f: $(head -1 "$SCRATCH.err")"
    [ "$(awk -F'\t' '$2 == "F"' "$SCRATCH.one" | wc -l | tr -d '[:space:]')" = 1 ] ||
      die "the frontmatter reader returned no single verdict for $f"
    cat "$SCRATCH.one" >> "$2" || die "cannot append the records for $f"
  done < "$1"
}

# One double-quoted YAML string. Character by character, because the escaping of backslashes in an
# awk gsub replacement differs between awks, and a generator that escapes differently on CI than
# locally writes an index that is stale on one of them.
AWK_Q='
  function q(s,   i, c, o) {
    o = ""
    for (i = 1; i <= length(s); i++) { c = substr(s, i, 1); if (c == "\\" || c == "\"") o = o "\\"; o = o c }
    return "\"" o "\""
  }
'

# ── specs ──────────────────────────────────────────────────────────────────────
# One entry per docs/specs/SPEC-*.md, ordered by the NUMBER after SPEC- in the filename (so SPEC-2
# precedes SPEC-10), ties by path; then every arc by name, its specs in arc_order, ties by id.
# Returns 1, printing nothing to stdout, when the tree is refused.
gen_specs() {
  find "$SPEC_DIR" -maxdepth 1 -type f -name 'SPEC-*.md' > "$SCRATCH.find" || die "cannot list $SPEC_DIR"
  sort "$SCRATCH.find" > "$SCRATCH.list" || die "cannot sort the spec list"
  read_all "$SCRATCH.list" "$SCRATCH.rec"
  rm -f "$SCRATCH.errs"
  # Validate, and key each spec for the sorts. Errors go to their own file: a refusal prints all of
  # them, not the first.
  awk -F'\t' -v errs="$SCRATCH.errs" '
    $2 == "F" { n++; file[n] = $1; v[$1] = $3; next }
    $2 == "K" { k[$1, $3] = $4; next }
    $2 == "L" { l[$1, $3] = 1; next }
    END {
      for (i = 1; i <= n; i++) {
        f = file[i]
        if (v[f] != "ok") { print "  " f ": its frontmatter cannot be read (spec-lint.sh names the line)" > errs; continue }
        miss = ""
        split("id title description spec_status", req, " ")
        for (j = 1; j <= 4; j++) if (k[f, req[j]] == "") miss = miss " " req[j]
        if (!l[f, "depends_on"]) miss = miss " depends_on"
        if (miss != "") { print "  " f ": no" miss " (spec-lint.sh names the defect)" > errs; continue }
        b = f; sub(/.*\//, "", b); num = b; sub(/^SPEC-/, "", num); sub(/[^0-9].*$/, "", num)
        printf "S\t%d\t%s\n", num + 0, f
        if (k[f, "arc"] != "") printf "A\t%s\t%d\t%s\n", k[f, "arc"], k[f, "arc_order"] + 0, k[f, "id"]
      }
    }
  ' "$SCRATCH.rec" > "$SCRATCH.keys" || die "the spec key pass failed"
  if [ -s "$SCRATCH.errs" ]; then
    echo "gen-index: refusing to write $SPEC_DIR/index.yaml — every spec must be readable and carry the keys it lists:" >&2
    cat "$SCRATCH.errs" >&2
    rm -f "$SCRATCH.errs"
    return 1
  fi
  awk -F'\t' '$1 == "S"' "$SCRATCH.keys" > "$SCRATCH.s" || die "the spec split failed"
  awk -F'\t' '$1 == "A"' "$SCRATCH.keys" > "$SCRATCH.a" || die "the arc split failed"
  sort -t "$TAB" -k2,2n -k3,3 "$SCRATCH.s" > "$SCRATCH.order" || die "the spec sort failed"
  sort -t "$TAB" -k2,2 -k3,3n -k4,4 "$SCRATCH.a" >> "$SCRATCH.order" || die "the arc sort failed"
  awk -F'\t' "$AWK_Q"'
    NR == FNR {
      if ($2 == "K") k[$1, $3] = $4
      if ($2 == "I") { ni[$1, $3]++; li[$1, $3, ni[$1, $3]] = $4 }
      next
    }
    $1 == "S" { ns++; spec[ns] = $3; next }
    $1 == "A" { if ($2 != last) { na++; arc[na] = $2; last = $2 } nm[na]++; mem[na, nm[na]] = $4; next }
    END {
      print "# Generated by scripts/gen-index.sh from the frontmatter of docs/specs/SPEC-*.md. Do not edit: run `sh scripts/gen-index.sh`."
      if (!ns) print "specs: []"
      else print "specs:"
      for (i = 1; i <= ns; i++) {
        f = spec[i]
        print "  - id: " q(k[f, "id"])
        print "    title: " q(k[f, "title"])
        print "    description: " q(k[f, "description"])
        print "    spec_status: " q(k[f, "spec_status"])
        d = ""
        for (j = 1; j <= ni[f, "depends_on"]; j++) d = d (j > 1 ? ", " : "") q(li[f, "depends_on", j])
        print "    depends_on: [" d "]"
        if (k[f, "arc"] != "") print "    arc: " q(k[f, "arc"])
        print "    path: " q(f)
      }
      if (!na) print "arcs: []"
      else print "arcs:"
      for (i = 1; i <= na; i++) {
        o = ""
        for (j = 1; j <= nm[i]; j++) o = o (j > 1 ? ", " : "") q(mem[i, j])
        print "  - name: " q(arc[i])
        print "    order: [" o "]"
      }
    }
  ' "$SCRATCH.rec" "$SCRATCH.order" || die "the spec index pass failed"
}

# ── decisions ──────────────────────────────────────────────────────────────────
# One entry per area directory under docs/decisions/, by directory name; each carries its area
# concept (<slug>/<slug>.md: title, governs) and every other .md beside it as a decision, by file
# name, with its fence (description) and its EFFECTIVE status — absent means stable (OKF 5.4), so a
# deprecated decision stays listed and is marked. A stray .md directly under docs/decisions/ or one
# level deeper is not indexed; docs-lint fails it by name, which keeps "fresh" from meaning "fresh
# but incomplete".
gen_decisions() {
  find "$REGISTER_DIR" -mindepth 1 -maxdepth 1 -type d > "$SCRATCH.find" || die "cannot list $REGISTER_DIR"
  sort "$SCRATCH.find" > "$SCRATCH.areas" || die "cannot sort the area list"
  : > "$SCRATCH.list"; : > "$SCRATCH.plan"; rm -f "$SCRATCH.errs"
  while IFS= read -r a; do
    slug=${a##*/}
    if [ -f "$a/$slug.md" ]; then
      printf '%s\n' "$a/$slug.md" >> "$SCRATCH.list"
      printf 'A\t%s\t%s\n' "$slug" "$a/$slug.md" >> "$SCRATCH.plan"
    else
      printf '  %s/: no %s.md, the area concept that names it\n' "$a" "$slug" >> "$SCRATCH.errs"
    fi
    find "$a" -mindepth 1 -maxdepth 1 -type f -name '*.md' > "$SCRATCH.find" || die "cannot list $a"
    sort "$SCRATCH.find" | while IFS= read -r d; do
      [ "$d" = "$a/$slug.md" ] && continue
      printf '%s\n' "$d" >> "$SCRATCH.list"
      printf 'D\t%s\t%s\n' "$slug" "$d" >> "$SCRATCH.plan"
    done
  done < "$SCRATCH.areas"
  read_all "$SCRATCH.list" "$SCRATCH.rec"
  awk -F'\t' -v errs="$SCRATCH.errs" '
    NR == FNR {
      if ($2 == "F") v[$1] = $3
      else if ($2 == "K") k[$1, $3] = $4
      else if ($2 == "L") l[$1, $3] = 1
      next
    }
    {
      f = $3
      if (v[f] != "ok") { print "  " f ": its frontmatter cannot be read (docs-lint.sh names the line)" >> errs; next }
      miss = ""
      if (k[f, "title"] == "") miss = miss " title"
      if ($1 == "A" && !l[f, "governs"]) miss = miss " governs (a flow list)"
      if ($1 == "D" && k[f, "description"] == "") miss = miss " description"
      if (miss != "") print "  " f ": no" miss " (docs-lint.sh names the defect)" >> errs
    }
  ' "$SCRATCH.rec" "$SCRATCH.plan" || die "the decision key pass failed"
  if [ -s "$SCRATCH.errs" ]; then
    echo "gen-index: refusing to write $REGISTER_DIR/index.yaml — every area needs its concept, and every file must be readable and carry the keys it lists:" >&2
    cat "$SCRATCH.errs" >&2
    rm -f "$SCRATCH.errs"
    return 1
  fi
  awk -F'\t' "$AWK_Q"'
    NR == FNR {
      if ($2 == "K") k[$1, $3] = $4
      if ($2 == "I") { ni[$1, $3]++; li[$1, $3, ni[$1, $3]] = $4 }
      next
    }
    $1 == "A" { na++; slug[na] = $2; path[na] = $3; next }
    $1 == "D" { nd[na]++; dec[na, nd[na]] = $3; next }
    END {
      print "# Generated by scripts/gen-index.sh from the frontmatter under docs/decisions/. Do not edit: run `sh scripts/gen-index.sh`."
      if (!na) print "areas: []"
      else print "areas:"
      for (i = 1; i <= na; i++) {
        f = path[i]
        print "  - name: " q(k[f, "title"])
        print "    slug: " q(slug[i])
        print "    path: " q(f)
        g = ""
        for (j = 1; j <= ni[f, "governs"]; j++) g = g (j > 1 ? ", " : "") q(li[f, "governs", j])
        print "    governs: [" g "]"
        if (!nd[i]) { print "    decisions: []"; continue }
        print "    decisions:"
        for (j = 1; j <= nd[i]; j++) {
          d = dec[i, j]
          st = k[d, "status"]; if (st == "") st = "stable"
          print "      - title: " q(k[d, "title"])
          print "        fence: " q(k[d, "description"])
          print "        status: " q(st)
          print "        path: " q(d)
        }
      }
    }
  ' "$SCRATCH.rec" "$SCRATCH.plan" || die "the decision index pass failed"
}

# Write one tree's index through a temp file beside it, so an interrupted run never leaves half an
# index; a refused tree leaves the committed index exactly as it was.
write_index() {
  tree=$1; gen=$2
  [ -d "$tree" ] || return 0
  TMP_INDEX="$tree/index.yaml.tmp.$$"
  if "$gen" > "$TMP_INDEX"; then
    mv "$TMP_INDEX" "$tree/index.yaml" || die "cannot move the new $tree/index.yaml into place"
    TMP_INDEX=""
    echo "gen-index: wrote $tree/index.yaml"
    return 0
  fi
  rm -f "$TMP_INDEX"; TMP_INDEX=""
  return 1
}

case "${1:-}" in
  --print)
    [ $# -eq 2 ] || usage
    case "$2" in
      specs) [ -d "$SPEC_DIR" ] || { echo "error: $SPEC_DIR does not exist" >&2; exit 2; }
             gen_specs > "$SCRATCH.out" || exit 1
             cat "$SCRATCH.out" ;;
      decisions) [ -d "$REGISTER_DIR" ] || { echo "error: $REGISTER_DIR does not exist" >&2; exit 2; }
             gen_decisions > "$SCRATCH.out" || exit 1
             cat "$SCRATCH.out" ;;
      *) usage ;;
    esac
    ;;
  '')
    rc=0
    write_index "$SPEC_DIR" gen_specs || rc=1
    write_index "$REGISTER_DIR" gen_decisions || rc=1
    exit "$rc"
    ;;
  *) usage ;;
esac
