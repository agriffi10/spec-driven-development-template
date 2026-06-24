#!/bin/sh
# sync-from-skill.sh — regenerate the repo-root scaffold from the canonical copy
# bundled in the skill.
#
# The skill at .claude/skills/spec-driven/template/ is the SOURCE OF TRUTH for the
# scaffold. The repo root mirrors it so that "Use this template" delivers a ready
# project. Edit the skill's template/, then run this to update the root.
#
# (This is a maintenance script for THIS template repo — not something derived
#  projects run. POSIX sh, no dependencies.)

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_TEMPLATE="$ROOT/.claude/skills/spec-driven/template"

[ -d "$SKILL_TEMPLATE" ] || { echo "error: skill template not found at $SKILL_TEMPLATE" >&2; exit 1; }

# Mirror the skill's template into the repo root. cp does not delete, so this
# script (scripts/sync-from-skill.sh) is left untouched.
cp -R "$SKILL_TEMPLATE/." "$ROOT/"
chmod +x "$ROOT/scripts/spec-lint.sh"

echo "Synced root scaffold from .claude/skills/spec-driven/template/."
echo "Review 'git diff' before committing."
