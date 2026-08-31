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
# FAIL (exit 1): a file is missing, differs, is orphaned, or differs in mode.
# PASS (exit 0): the root is exactly the payload plus the root-only files below.
# ERROR (exit 2): the repo, payload or file list is not in a shape this can
#                 compare — a vacuous pass is refused rather than reported.
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
# first two describe this repo rather than the scaffold, and the last three are
# the mirror machinery itself, which by definition is not part of what it
# mirrors (a scaffolded repo has no payload, so it needs none of them). Every
# entry is checked to exist below, so this list cannot rot into a set of
# exemptions for files nobody has — which is the way such a list fails.
#
# A legitimately new root-only file goes here. That is the maintenance cost of
# the orphan direction, and it is the intended trade: a list that must grow is
# better than deletions passing silently.
ROOT_ONLY='README.md
.gitignore
scripts/sync-from-skill.sh
scripts/check-mirror.sh
.github/workflows/check-mirror.yml'

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
# shellcheck disable=SC2064
trap "rm -rf '$tmp'" EXIT INT TERM

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

# --- the root-only list must describe reality ------------------------------
printf '%s\n' "$ROOT_ONLY" | sort > "$tmp/root_only"
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  if [ ! -e "$ROOT/$rel" ]; then
    echo "STALE EXEMPTION  $rel — listed as root-only but does not exist"
    drift=$((drift + 1))
  fi
done < "$tmp/root_only"

# --- split the tracked list into payload side and root side ----------------
# Payload entries, prefix stripped. Root entries: everything NOT under .claude/,
# since that tree is the skill (payload + SKILL.md + its README), not the mirror.
: > "$tmp/payload"
: > "$tmp/root_all"
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  case "$rel" in
    "$PAYLOAD_PREFIX"/*) printf '%s\n' "${rel#"$PAYLOAD_PREFIX"/}" >> "$tmp/payload" ;;
    .claude/*)           : ;;
    *)                   printf '%s\n' "$rel" >> "$tmp/root_all" ;;
  esac
done < "$tmp/tracked"

sort -o "$tmp/payload" "$tmp/payload"
sort -o "$tmp/root_all" "$tmp/root_all"

[ -s "$tmp/payload" ] || {
  echo "error: no tracked files under $PAYLOAD_PREFIX — refusing to report a vacuous pass" >&2
  exit 2
}

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
comm -23 "$tmp/root_all" "$tmp/root_only" > "$tmp/root_mirrored"
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
  echo "unintended, or add it to ROOT_ONLY in this script if it is legitimately"
  echo "root-only."
  echo
  echo "NOTE: the root docs/, CLAUDE.md and .github/ are generated. Never"
  echo "hand-edit them — the sync discards the change and then reports green."
  exit 1
fi

echo "check-mirror: $checked payload file(s) compared both ways, root matches."
