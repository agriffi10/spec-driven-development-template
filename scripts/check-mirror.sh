#!/bin/sh
# check-mirror.sh — fail if the repo-root scaffold has drifted from the canonical
# copy bundled in the skill.
#
# .claude/skills/spec-driven/template/ is the SOURCE OF TRUTH for the scaffold.
# The repo root mirrors it so that "Use this template" delivers a ready project.
# Editing one and not the other ships a scaffold that is behind its own source:
# PRs #3 and #4 landed in the payload and never reached the root, and the repo
# served a two-revision-stale scaffold for weeks because nothing checked.
#
# FAIL (exit 1): a payload file is missing at the root, or the two differ.
# PASS (exit 0): every payload file has an identical counterpart at the root.
# ERROR (exit 2): the payload is missing or empty — a vacuous pass is refused.
#
# The walk is payload -> root, deliberately. Files that exist only at the root
# (.gitignore, README.md, the scripts here, .claude/, .git/) are not in the
# payload, so they are never compared and need no exclusion list — a
# hand-maintained list of exceptions is the thing that rots.
#
# Usage: scripts/check-mirror.sh
# POSIX sh — no bashisms; runs anywhere /bin/sh exists.

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_TEMPLATE="$ROOT/.claude/skills/spec-driven/template"

[ -d "$SKILL_TEMPLATE" ] || {
  echo "error: skill template not found at $SKILL_TEMPLATE" >&2
  exit 2
}

list=$(mktemp) || exit 2
# shellcheck disable=SC2064
trap "rm -f '$list'" EXIT INT TERM
find "$SKILL_TEMPLATE" -type f > "$list"

drift=0
checked=0

# Reading from a file (not a pipe) keeps the loop in this shell, so the counters
# below survive it.
while IFS= read -r src; do
  [ -n "$src" ] || continue
  rel=${src#"$SKILL_TEMPLATE"/}
  dst="$ROOT/$rel"
  checked=$((checked + 1))
  if [ ! -f "$dst" ]; then
    echo "MISSING  $rel — in the skill payload, absent from the repo root"
    drift=$((drift + 1))
  elif ! cmp -s "$src" "$dst"; then
    echo "DIFFERS  $rel"
    drift=$((drift + 1))
  fi
done < "$list"

if [ "$checked" -eq 0 ]; then
  echo "error: compared 0 files — refusing to report a vacuous pass" >&2
  exit 2
fi

if [ "$drift" -gt 0 ]; then
  echo "----"
  echo "check-mirror: $drift of $checked file(s) drifted."
  echo "The skill payload is canonical. To fix:  sh scripts/sync-from-skill.sh"
  echo "then review 'git diff' and commit BOTH the payload and the root."
  exit 1
fi

echo "check-mirror: $checked file(s) compared, root matches the skill payload."
