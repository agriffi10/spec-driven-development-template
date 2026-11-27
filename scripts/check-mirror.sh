#!/bin/sh
# check-mirror.sh — fail if the repo-root scaffold has drifted from the canonical
# copy bundled in the skill.
#
# .claude/skills/spec-driven/template/ is the SOURCE OF TRUTH for the scaffold.
# The repo root mirrors it so that "Use this template" delivers a ready project.
# Editing one and not the other ships a scaffold that is behind its own source:
# PRs #3 and #4 landed in the payload alone, and the repo served a two-revision
# stale scaffold for weeks because nothing checked.
#
# The check runs in BOTH directions, because the two failures are different:
#
#   payload -> root   a payload file that is missing, differs, or differs in
#                     mode at the root. The "edited the payload, forgot to
#                     sync" case.
#
#   root -> payload   a root file with no payload counterpart: an ORPHAN. This
#                     is what a payload *deletion or rename* leaves behind, and
#                     it is invisible to the forward walk. `sync-from-skill.sh`
#                     uses `cp -R`, which never deletes, so the stale root copy
#                     survives every sync.
#
# What is root-only BY DESIGN is exempt from the root -> payload walk, and named
# in two lists below: exact files, and whole directories. An exemption is the one
# thing here that can make a real orphan pass, so each entry is itself checked —
# a listed file must exist, a listed directory must hold a tracked file, and the
# payload must ship nothing under a listed directory.
#
# FAIL (exit 1): a file is missing, differs, is orphaned, or differs in mode, or
#                an exemption below no longer describes the tree.
# PASS (exit 0): the root is exactly the payload plus the root-only files and
#                the contents of the root-only directories below.
# ERROR (exit 2): the repo, payload or file list is not in a shape this can
#                 compare — a vacuous pass is refused rather than reported. Also
#                 a run stopped by a signal (HUP, INT, PIPE or TERM).
#
# File lists come from `git ls-files`, not `find`, for two reasons: it lists
# what the repo actually ships (so .DS_Store, node_modules/ and anything else
# in .gitignore cannot masquerade as drift and turn a git-clean tree red), and
# it needs no path pruning, which is where an earlier version silently walked
# .git and reported green on a repo path containing a space.
#
# Usage: scripts/check-mirror.sh
# POSIX sh — no bashisms; runs anywhere /bin/sh exists (CI runs dash).

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PAYLOAD_PREFIX='.claude/skills/spec-driven/template'
SKILL_TEMPLATE="$ROOT/$PAYLOAD_PREFIX"

# Root files that are deliberately NOT mirrored, because they cannot be: the
# first two describe this repo rather than the scaffold, the third publishes this
# repo's skill as a Claude Code plugin, the next three are
# the mirror machinery itself, which by definition is not part of what it
# mirrors (a scaffolded repo has no payload, so it needs none of them), and the
# last tests this repo's scripts, both copies, from the root alone. Every
# entry is checked to exist below, so this list cannot rot into a set of
# exemptions for files nobody has — which is the way such a list fails.
#
# A legitimately new root-only file goes here, unless it belongs under one of
# the directories listed after it. That is the maintenance cost of the orphan
# direction, and it is the intended trade: a list that must grow is better than
# deletions passing silently.
ROOT_ONLY='README.md
.gitignore
.claude-plugin/marketplace.json
scripts/sync-from-skill.sh
scripts/check-mirror.sh
.github/workflows/check-mirror.yml
scripts/signal-test.sh'

# Root DIRECTORIES that are deliberately not mirrored, one per line, with no
# trailing slash. Everything tracked beneath one is exempt, so a file added
# there needs no entry of its own — which is the point, and also the risk: a
# directory entry exempts files nobody has listed. So this list is for a tree
# that is root-only as a whole and cannot live in the scaffold, not a
# convenience for a file that could go in ROOT_ONLY.
#
#   template-specs   the specs for changes to this template itself. They cannot
#                    live in docs/specs/, because that directory is part of the
#                    scaffold: a spec there would ship into every project
#                    created from the template, and the root's generated
#                    docs/specs/index.yaml would differ from the payload's.
#
# Three things keep an entry honest. The match is a path prefix ending at the
# slash, so `template-specs` exempts neither a sibling directory
# `template-specs-old/` nor a file `template-specs.md`. An entry must hold at
# least one tracked file at the root, for the same reason a ROOT_ONLY entry
# must exist. And the payload must track nothing under the same path: a
# directory cannot be both exempt at the root and shipped in the scaffold,
# because the forward walk would then demand a root copy of a file the reverse
# walk has been told not to look at. The last two are checked below, and each
# failure counts as drift.
ROOT_ONLY_DIRS='template-specs'

command -v git >/dev/null 2>&1 || {
  echo "error: git is required to enumerate the repo's files" >&2
  exit 2
}
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "error: $ROOT is not a git work tree" >&2
  exit 2
}
[ -d "$SKILL_TEMPLATE" ] || {
  echo "error: skill template not found at $SKILL_TEMPLATE" >&2
  exit 2
}

# A symlink is neither compared nor reported by a file walk, so refuse rather
# than silently skip one.
symlinks=$(find "$SKILL_TEMPLATE" -type l)
if [ -n "$symlinks" ]; then
  echo "error: the skill payload contains symlinks, which this check cannot compare:" >&2
  printf '%s\n' "$symlinks" | sed "s|^$SKILL_TEMPLATE/|  |" >&2
  exit 2
fi

tmp=$(mktemp -d) || exit 2
# A signal EXITS, and the EXIT trap then cleans up. A handler that only removed $tmp let the shell
# resume after it with the file lists gone, ending in "No such file" errors rather than a verdict.
# HUP and PIPE are trapped too, because dash runs no EXIT trap when a signal kills it.
# `scripts/signal-test.sh` holds every script with a trap to this.
trap 'rm -rf "$tmp"' EXIT
trap 'exit 2' HUP INT PIPE TERM

# core.quotePath=false keeps non-ASCII paths literal. Git still quotes a path
# containing a newline or a double quote, which would break line-based reading —
# detect that and refuse rather than mis-compare.
if ! git -C "$ROOT" -c core.quotePath=false ls-files > "$tmp/tracked"; then
  echo "error: 'git ls-files' failed" >&2
  exit 2
fi
if grep -q '^"' "$tmp/tracked"; then
  echo "error: a tracked path needs quoting (newline or quote in the name); refusing to compare:" >&2
  grep '^"' "$tmp/tracked" | sed 's/^/  /' >&2
  exit 2
fi
[ -s "$tmp/tracked" ] || {
  echo "error: 'git ls-files' listed no files — refusing to report a vacuous pass" >&2
  exit 2
}

drift=0
checked=0

# --- the root-only file list must describe reality -------------------------
printf '%s\n' "$ROOT_ONLY" | sort > "$tmp/root_only"
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  if [ ! -e "$ROOT/$rel" ]; then
    echo "STALE EXEMPTION  $rel — listed as root-only but does not exist"
    drift=$((drift + 1))
  fi
done < "$tmp/root_only"

# --- split the tracked list into payload side and root side ----------------
# Payload entries, prefix stripped. Root entries: everything NOT under .claude/skills/,
# since that tree is the skill (payload + SKILL.md + its README), not the mirror.
# The rest of .claude/ (rules/, agents/, settings.json) IS mirrored: the payload ships them.
: > "$tmp/payload"
: > "$tmp/root_all"
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  case "$rel" in
    "$PAYLOAD_PREFIX"/*) printf '%s\n' "${rel#"$PAYLOAD_PREFIX"/}" >> "$tmp/payload" ;;
    .claude/skills/*)    : ;;
    *)                   printf '%s\n' "$rel" >> "$tmp/root_all" ;;
  esac
done < "$tmp/tracked"

sort -o "$tmp/payload" "$tmp/payload"
sort -o "$tmp/root_all" "$tmp/root_all"

[ -s "$tmp/payload" ] || {
  echo "error: no tracked files under $PAYLOAD_PREFIX — refusing to report a vacuous pass" >&2
  exit 2
}

# --- the root-only directory list must describe reality --------------------
# Run after the split, because both checks read the tracked lists rather than
# the worktree: an exempt directory is one git ships, and an untracked or
# ignored file sitting in it says nothing about what the repo carries. The
# cost of that choice: a directory deleted from the worktree but not yet staged
# still passes here, and is reported once the deletion is staged or committed.
# "$dir"/* is quoted so the entry is matched literally, and it ends at the
# slash so a longer name that merely starts the same way is not exempted.
printf '%s\n' "$ROOT_ONLY_DIRS" > "$tmp/root_only_dirs"
: > "$tmp/root_exempt"
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  held=0
  while IFS= read -r rel; do
    case "$rel" in
      "$dir"/*)
        held=$((held + 1))
        printf '%s\n' "$rel" >> "$tmp/root_exempt"
        ;;
    esac
  done < "$tmp/root_all"
  if [ "$held" -eq 0 ]; then
    echo "STALE EXEMPTION  $dir/ — listed as a root-only directory but holds no tracked file"
    drift=$((drift + 1))
  fi
  while IFS= read -r rel; do
    case "$rel" in
      "$dir"/*)
        echo "SHIPPED EXEMPTION  $rel — in the skill payload, under a directory listed as root-only"
        drift=$((drift + 1))
        ;;
    esac
  done < "$tmp/payload"
done < "$tmp/root_only_dirs"
sort -o "$tmp/root_exempt" "$tmp/root_exempt"

# --- payload -> root: missing, differing content, differing mode -----------
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  src="$SKILL_TEMPLATE/$rel"
  dst="$ROOT/$rel"
  checked=$((checked + 1))
  if [ ! -f "$src" ]; then
    # Tracked in git but gone from the worktree — a deletion that has not been
    # staged yet. Reported plainly rather than surfacing as a confusing DIFFERS.
    echo "DELETED  $rel — tracked in the payload but missing from the worktree"
    drift=$((drift + 1))
  elif [ ! -f "$dst" ]; then
    echo "MISSING  $rel — in the skill payload, absent from the repo root"
    drift=$((drift + 1))
  elif ! cmp -s "$src" "$dst"; then
    echo "DIFFERS  $rel"
    drift=$((drift + 1))
  elif { [ -x "$src" ] && [ ! -x "$dst" ]; } || { [ ! -x "$src" ] && [ -x "$dst" ]; }; then
    # sync-from-skill.sh chmod +x's spec-lint.sh, so the exec bit is part of the
    # sync contract; cmp compares content only and would miss a mode-only drift.
    echo "MODE     $rel — executable bit differs between payload and root"
    drift=$((drift + 1))
  fi
done < "$tmp/payload"

# --- root -> payload: orphans left behind by a deletion or rename ----------
# Two subtractions leave the root files that owe a payload counterpart: the
# listed root-only files, then everything under a listed root-only directory.
comm -23 "$tmp/root_all" "$tmp/root_only" > "$tmp/root_listed"
comm -23 "$tmp/root_listed" "$tmp/root_exempt" > "$tmp/root_mirrored"
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  if [ ! -f "$SKILL_TEMPLATE/$rel" ]; then
    echo "ORPHAN   $rel — tracked at the repo root with no counterpart in the skill payload"
    drift=$((drift + 1))
  fi
done < "$tmp/root_mirrored"

# --- verdict ---------------------------------------------------------------
if [ "$checked" -eq 0 ]; then
  echo "error: compared 0 files — refusing to report a vacuous pass" >&2
  exit 2
fi

if [ "$drift" -gt 0 ]; then
  echo "----"
  echo "check-mirror: $drift problem(s) across $checked payload file(s)."
  echo
  echo "The skill payload is canonical. For a MISSING/DIFFERS/MODE finding:"
  echo "    sh scripts/sync-from-skill.sh"
  echo "then review 'git diff' and commit BOTH the payload and the root."
  echo
  echo "For an ORPHAN, sync will NOT help — 'cp -R' never deletes. Either remove"
  echo "the root file by hand, restore it to the payload if the deletion was"
  echo "unintended, or, if it is legitimately root-only, add it to ROOT_ONLY in"
  echo "this script or keep it under a directory listed in ROOT_ONLY_DIRS."
  echo
  echo "For a STALE EXEMPTION, drop the entry from ROOT_ONLY or ROOT_ONLY_DIRS: it"
  echo "names a file that is gone or a directory that tracks nothing. For a SHIPPED"
  echo "EXEMPTION, choose one: a directory is root-only or part of the scaffold,"
  echo "so remove it from the payload or remove its entry from ROOT_ONLY_DIRS."
  echo
  echo "NOTE: the root docs/, CLAUDE.md and .github/ are generated. Never"
  echo "hand-edit them — the sync discards the change and then reports green."
  exit 1
fi

echo "check-mirror: $checked payload file(s) compared both ways, root matches."
