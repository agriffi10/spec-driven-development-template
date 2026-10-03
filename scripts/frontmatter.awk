# frontmatter.awk — the ONE frontmatter reader every script here shares.
#
# Usage: LC_ALL=C awk -f scripts/frontmatter.awk <exactly one file>
#
# Reads the YAML frontmatter of one governed file — a spec, a decision, a rulebook — against
# the subset documented in docs/process/knowledge-layout.md (Frontmatter), and prints what it
# read as records. It is not a YAML parser and does not try to be one: it classifies every line
# between the two `---` delimiters as one of the subset forms, and a line it cannot classify is
# an ERROR record naming the line and the rule it broke. Never a skip. A reader that skips what
# it does not understand reports a file it never read as a file that passed.
#
# One reader, not one per script, because `spec-lint.sh`, `docs-lint.sh` and `gen-index.sh`
# all read the same files, and two readers are two grammars that drift apart: the index would
# be generated from one reading of a file and linted against another.
#
# Records — one per line, tab-separated. A value never holds a tab or a newline: the subset
# refuses both, so the format needs no escaping.
#
#   <path> E <line> <message>          an error (zero or more)
#   <path> K <key> <value>             a scalar, unquoted and unescaped
#   <path> L <key> <n>                 a flow list with n elements (n may be 0)
#   <path> I <key> <element>           one flow-list element, in order, after its L
#   <path> S <n> <field> <value>       one field of `sources` item n (1-based)
#   <path> B <line>                    the first body line: the line after the closing ---
#   <path> F ok|err                    exactly one, always last
#
# CALLERS MUST check two things, and neither alone is enough: this program exit status, and
# that exactly one F record came back for the file. An awk that dies on a syntax error prints
# nothing, and every check downstream of a reader that printed nothing iterates over nothing
# and passes. Exit 2 is a usage error: anything but exactly one file operand.
#
# This is an awk FILE, not a single-quoted program inside a shell script, so an apostrophe in
# a comment here is harmless — the trap the docs-lint.sh header warns about does not apply.

BEGIN {
  if (ARGC != 2) {
    print "frontmatter.awk: exactly one file operand, got " (ARGC - 1) > "/dev/stderr"
    usage = 1
    exit 2
  }
  path = ARGV[1]
  state = "open"      # open: expecting line 1 | top | src0: just read `sources:` | item | done | none
  nerr = 0
  nitem = 0
  INDICATORS = "-?:,[]{}#&*!|>'\"%@`"
}

function err(ln, msg) { printf "%s\tE\t%d\t%s\n", path, ln, msg; nerr++ }

function trim(s) { sub(/^ +/, "", s); sub(/ +$/, "", s); return s }

# Why a value cannot stand as a plain (unquoted) scalar, or "" when it can. Each refusal is a
# place where YAML would error, or — worse — read something other than what was written: ` #`
# silently truncates the value at the comment, and `[x]` is a one-element list.
function plain_why(v,   c) {
  c = substr(v, 1, 1)
  if (c == "{") return "a flow map — the subset has none"
  if (c == "'") return "a single-quoted value — use double quotes"
  if (c == "|" || c == ">") return "a block scalar — a value is written on one line"
  if (c == "&" || c == "*" || c == "!") return "an anchor, alias or tag — the subset has none"
  if (index(INDICATORS, c)) return "a value starting with \"" c "\" — double-quote it"
  if (index(v, ": ")) return "a value holding `: ` — double-quote it"
  if (v ~ /:$/) return "a value ending in `:` — double-quote it"
  if (index(v, " #")) return "a value holding ` #`, which YAML reads as a comment and silently drops the rest — double-quote it"
  return ""
}

# A double-quoted scalar on one line. Sets DQ to the unescaped value and returns "" when it
# reads, or returns why it does not. `\"` and `\\` are the only escapes; v has had its trailing
# spaces trimmed, so anything left after the closing quote is text that does not belong.
function dq(v,   i, n, c, out) {
  n = length(v); out = ""
  for (i = 2; i <= n; i++) {
    c = substr(v, i, 1)
    if (c == "\\") {
      c = substr(v, i + 1, 1)
      if (c == "\"" || c == "\\") { out = out c; i++; continue }
      return "a backslash escape other than \\\" or \\\\ in a double-quoted value"
    }
    if (c == "\"") {
      if (i < n) return "text after the closing quote of a double-quoted value"
      DQ = out
      return ""
    }
    out = out c
  }
  return "an unterminated double-quoted value — it opens and closes on one line"
}

# `key: value` → sets KEY and VAL (unquoted), returns "" or why it does not read. A flow list
# is not taken here: `ctx` says whether one is allowed, and the caller handles it.
function scalar(v,   why) {
  if (substr(v, 1, 1) == "\"") { why = dq(v); if (why == "") VAL = DQ; return why }
  why = plain_why(v)
  if (why == "") VAL = v
  return why
}

function split_kv(s, where,   rest) {
  KEY = s; sub(/:.*/, "", KEY)
  rest = substr(s, length(KEY) + 2)
  if (rest ~ /^ *$/) return "`" KEY ":` " where " has no value — write the value, or delete the key"
  if (rest !~ /^ [^ ]/) return "`" KEY ":` is not followed by exactly one space and its value"
  RAW = trim(substr(rest, 2))
  return ""
}

function flow(key, v,   inner, n, parts, i, e, why) {
  if (v !~ /\]$/) return "a flow list that does not close on its line — `[a, b]` opens and closes on one line"
  inner = substr(v, 2, length(v) - 2)
  if (inner ~ /^ *$/) { printf "%s\tL\t%s\t0\n", path, key; return "" }
  n = split(inner, parts, ",")
  for (i = 1; i <= n; i++) {
    e = trim(parts[i])
    if (e == "") return "an empty element in a flow list (a trailing or doubled comma)"
    if (index(e, "[") || index(e, "]") || index(e, "{") || index(e, "}") || index(e, "\"") || index(e, "'") || index(e, ":") || index(e, "?"))
      return "a flow-list element holding a bracket, a brace, a quote, `:` or `?` — inside `[…]` YAML reads each as structure, so list elements are plain words"
    why = plain_why(e)
    if (why != "") return "a flow-list element that cannot stand unquoted (" why ")"
    parts[i] = e
  }
  printf "%s\tL\t%s\t%d\n", path, key, n
  for (i = 1; i <= n; i++) printf "%s\tI\t%s\t%s\n", path, key, parts[i]
  return ""
}

function no_items() {
  err(src_line, "`sources:` opens a list with no items under it — write at least one `  - id: …` item")
}

function top(line,   why) {
  if (state == "src0") no_items()
  state = "top"
  KEY = line; sub(/:.*/, "", KEY)
  if (KEY in seen) { err(NR, "a duplicate key `" KEY "` — YAML keeps the last copy, so the two disagree silently"); return }
  seen[KEY] = 1
  if (line ~ /^[a-z_][a-z0-9_]*: *$/) {
    if (KEY == "sources") { state = "src0"; src_line = NR; return }
    err(NR, "`" KEY ":` has no value — write the value, or delete the key (only `sources:` opens a block list)")
    return
  }
  why = split_kv(line, "")
  if (why != "") { err(NR, why); return }
  if (substr(RAW, 1, 1) == "[") { why = flow(KEY, RAW); if (why != "") err(NR, why); return }
  why = scalar(RAW)
  if (why != "") { err(NR, why); return }
  printf "%s\tK\t%s\t%s\n", path, KEY, VAL
}

function field(s,   why) {
  if (s !~ /^[a-z_][a-z0-9_]*:/) { err(NR, "a `sources` field is `key: value` with a lowercase key"); return }
  why = split_kv(s, "in a `sources` item")
  if (why != "") { err(NR, why); return }
  if (KEY in item_seen) { err(NR, "a duplicate field `" KEY "` in sources item " nitem); return }
  item_seen[KEY] = 1
  if (substr(RAW, 1, 1) == "[") { err(NR, "a list inside a `sources` item — a field takes one value"); return }
  why = scalar(RAW)
  if (why != "") { err(NR, why); return }
  printf "%s\tS\t%d\t%s\t%s\n", path, nitem, KEY, VAL
}

{ sub(/\r$/, "") }

NR == 1 {
  if ($0 != "---") {
    err(1, "no frontmatter — line 1 is not `---` (nothing comes before it: not a heading, a blank line or a byte-order mark)")
    state = "none"
    exit
  }
  state = "top"
  next
}

$0 == "---" {
  if (state == "src0") no_items()
  printf "%s\tB\t%d\n", path, NR + 1
  state = "done"
  exit
}

index($0, "\t")          { err(NR, "a tab — the frontmatter is indented with spaces, and a value may not hold a tab"); next }
/[[:cntrl:]]/            { err(NR, "a control character"); next }
# U+0085, U+2028 and U+2029, as UTF-8 bytes: YAML reads each as a line break, so a value holding one
# is two lines to PyYAML and one line here. Refused rather than read two ways.
index($0, "\302\205") || index($0, "\342\200\250") || index($0, "\342\200\251") {
  err(NR, "a Unicode line or paragraph separator (U+0085, U+2028 or U+2029), which YAML reads as a line break"); next }
/^ *$/                   { err(NR, "a blank line — the frontmatter carries none"); next }
/^ *#/                   { err(NR, "a comment — the frontmatter carries none, and this reader does not skip them"); next }
/^[a-z_][a-z0-9_]*:/     { top($0); next }
/^  - / {
  if (state != "src0" && state != "item") { err(NR, "a list item outside `sources:` — `sources` is the only key that takes an indented list"); next }
  state = "item"; nitem++; split("", item_seen)
  field(substr($0, 5))
  next
}
/^    [^ ]/ {
  if (state != "item") { err(NR, "an indented field outside a `sources` item"); next }
  field(substr($0, 5))
  next
}
{ err(NR, "a line that is not one of the frontmatter forms — `key: value` with a lowercase key at column 0, a `sources` item, or the closing `---`") }

END {
  if (usage) exit 2
  if (NR == 0) err(1, "an empty file — no frontmatter")
  else if (state == "top" || state == "src0" || state == "item")
    err(1, "the frontmatter opened on line 1 never closes — no `---` line ends it")
  printf "%s\tF\t%s\n", path, (nerr ? "err" : "ok")
}
