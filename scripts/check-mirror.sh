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
#   payload -> root   a payload file that is missing or differs at the root.
#                     This is the "edited the payload, forgot to sync" case.
#
#   root -> payload   a root file with no payload counterpart: an ORPHAN.
#                     This is the "deleted or renamed a payload file" case, and
#                     it is invisible to the forward walk. `sync-from-skill.sh`
#                     uses `cp -R`, which never deletes, so a payload deletion
#                     reaches the root through no path at all and the stale root
#                     copy survives every sync.
#
# FAIL (exit 1): a file is missing, differs, is orphaned, or differs in mode.
# PASS (exit 0): the root is exactly the payload plus the root-only files below.
# ERROR (exit 2): the payload is absent, empty, or contains a shape this cannot
#                 compare — a vacuous pass is refused.
#
# Usage: scripts/check-mirror.sh
# POSIX sh — no bashisms; runs anywhere /bin/sh exists (CI runs dash).

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_TEMPLATE="$ROOT/.claude/skills/spec-driven/template"

# Root files that are deliberately NOT mirrored, because they cannot be: the
# first two describe this repo rather than the scaffold, and the last three are
# the mirror machinery itself, which by definition is not part of what it
# mirrors (a scaffolded repo has no payload, so it needs none of them). Every
# entry is checked to exist below, so this list cannot rot into a set of
# exemptions for files nobody has — which is the way such a list fails.
ROOT_ONLY='README.md
.gitignore
scripts/sync-from-skill.sh
scripts/check-mirror.sh
.github/workflows/check-mirror.yml'

# Top-level directories the mirror has no opinion about.
SKIP_DIRS='.git
.claude'

[ -d "$SKILL_TEMPLATE" ] || {
  echo "error: skill template not found at $SKILL_TEMPLATE" >&2
  exit 2
}

# A symlink is neither compared nor reported by a -type f walk, so refuse rather
# than silently skip one.
if [ -n "$(find "$SKILL_TEMPLATE" -type l)" ]; then
  echo "error: the skill payload contains symlinks, which this check cannot compare:" >&2
  find "$SKILL_TEMPLATE" -type l | sed "s|^$SKILL_TEMPLATE/|  |" >&2
  exit 2
fi

tmp=$(mktemp -d) || exit 2
# shellcheck disable=SC2064
trap "rm -rf '$tmp'" EXIT INT TERM

drift=0
checked=0

# --- the root-only list must describe reality ------------------------------
printf '%s\n' "$ROOT_ONLY" > "$tmp/root_only"
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  if [ ! -e "$ROOT/$rel" ]; then
    echo "STALE EXEMPTION  $rel — listed as root-only but does not exist"
    drift=$((drift + 1))
  fi
done < "$tmp/root_only"

# --- payload -> root: missing, differing content, differing mode -----------
find "$SKILL_TEMPLATE" -type f | sed "s|^$SKILL_TEMPLATE/||" | sort > "$tmp/payload"
[ -s "$tmp/payload" ] || {
  echo "error: the skill payload contains no files — refusing to report a vacuous pass" >&2
  exit 2
}

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  src="$SKILL_TEMPLATE/$rel"
  dst="$ROOT/$rel"
  checked=$((checked + 1))
  if [ ! -f "$dst" ]; then
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
# Every root file, minus the skipped directories and the root-only list, must
# have a payload counterpart. Anything else is a file the payload no longer has.
skip_expr=""
for d in $SKIP_DIRS; do
  skip_expr="$skip_expr -path $ROOT/$d -prune -o"
done
# shellcheck disable=SC2086
find "$ROOT" $skip_expr -type f -print | sed "s|^$ROOT/||" | sort > "$tmp/root_all"
sort "$tmp/root_only" > "$tmp/root_only_sorted"
comm -23 "$tmp/root_all" "$tmp/root_only_sorted" > "$tmp/root_mirrored"

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  if [ ! -f "$SKILL_TEMPLATE/$rel" ]; then
    echo "ORPHAN   $rel — at the repo root with no counterpart in the skill payload"
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
  echo "For an ORPHAN, sync will NOT help — 'cp -R' never deletes. Remove the"
  echo "root file by hand (or restore it to the payload if the deletion was"
  echo "unintended), then re-run."
  echo
  echo "NOTE: the root docs/ are generated. Never hand-edit them — running the"
  echo "sync discards the change and reports green. Edit the payload instead."
  exit 1
fi

echo "check-mirror: $checked payload file(s) compared both ways, root matches."
