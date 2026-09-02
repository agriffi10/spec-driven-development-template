#!/bin/sh
# install.sh — put the PR queue where several agent sessions can share it, and make it
# enforceable. Run once per checkout, before launching the agents.
#
#   sh scripts/pr-queue/install.sh [branch-regex]
#
# The queue must live OUTSIDE the repo and outside every worktree: a lock inside a worktree is
# invisible to peers, and a lock inside the repo is a file that itself conflicts. So this copies
# queue.sh, pre-push and PROTOCOL.md to a directory under $HOME and points a
# .git/hooks/pre-push wrapper at the copy there.
#
# The default location is keyed on the ORIGIN URL, not the directory name, because the invariant
# is about the remote: two checkouts of the same repo must share one queue, and two different
# repos that happen to share a directory name must not. Override with PR_QUEUE_DIR.
#
# [branch-regex] is the ERE for branches the hook enforces against (default '^spec-'). Branches
# outside it push freely — see the fail-open note in pre-push. An existing setting is kept when
# no argument is given.
#
# EXIT: 0 installed · 1 could not install · 3 queue installed but the hook was NOT (something
#       else already occupies .git/hooks/pre-push — the message says what to add by hand).

set -eu

SRC="$(cd "$(dirname "$0")" && pwd)"

git rev-parse --git-dir >/dev/null 2>&1 || { echo "error: run this from inside the checkout" >&2; exit 1; }

# The MAIN worktree, not whichever linked worktree this was run from: the queue records one
# checkout for its remote checks, and it has to be the one that will still be there tomorrow.
REPO="$(git worktree list --porcelain | sed -n '1s/^worktree //p')"
[ -n "$REPO" ] && [ -d "$REPO" ] || { echo "error: could not locate the main worktree" >&2; exit 1; }

if [ -n "${PR_QUEUE_DIR:-}" ]; then
  Q="$PR_QUEUE_DIR"
else
  url="$(git -C "$REPO" remote get-url origin 2>/dev/null || echo '')"
  if [ -n "$url" ]; then
    slug="$(printf '%s' "$url" | sed -e 's#^[a-zA-Z+]*://##' -e 's#^[^@/]*@##' -e 's#\.git$##' \
                                     -e 's#[^A-Za-z0-9._-]#-#g')"
  else
    slug="$(basename "$REPO")"
  fi
  Q="$HOME/.claude/pr-queue/$slug"
fi

# Absolutise before anything is compared or written: the guard below is a prefix test, which a
# relative path silently passes, and the same string goes into the hook wrapper — where a
# relative path resolves against whatever directory git happens to run the hook from, leaving a
# healthy-looking queue with no enforcement at all.
mkdir -p "$Q" || { echo "error: could not create $Q" >&2; exit 1; }
Q="$(cd "$Q" && pwd)"

# Outside the repo AND outside every worktree, not just the main one: a queue inside a linked
# worktree is invisible to that worktree's peers, which is the whole failure this avoids.
worktrees="$(git -C "$REPO" worktree list --porcelain | sed -n 's/^worktree //p')"
oldifs="$IFS"; IFS='
'
for wt in $worktrees; do
  case "$Q/" in
    "$wt"/*) echo "error: the queue may not live inside a worktree ($wt)" >&2
             rmdir "$Q" 2>/dev/null || true
             exit 1 ;;
  esac
done
IFS="$oldifs"

MAIN="$(git -C "$REPO" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
[ -n "$MAIN" ] || MAIN=main

cp "$SRC/queue.sh" "$SRC/pre-push" "$SRC/PROTOCOL.md" "$Q/"
chmod +x "$Q/queue.sh" "$Q/pre-push"
printf '%s\n' "$REPO" > "$Q/repo"
printf '%s\n' "$MAIN" > "$Q/main-branch"

if [ "$#" -ge 1 ]; then
  printf '%s\n' "$1" > "$Q/enforce-branches"
elif [ ! -s "$Q/enforce-branches" ]; then
  printf '%s\n' '^spec-' > "$Q/enforce-branches"
fi

# --- the hook wrapper -------------------------------------------------------------------------
# Linked worktrees share the common git dir's hooks, so installing here covers every session on
# the checkout — which is the point, and also why the hook it execs fails open.
HOOKS="$(git -C "$REPO" config --get core.hooksPath || true)"
[ -n "$HOOKS" ] || HOOKS="$(git -C "$REPO" rev-parse --git-common-dir)/hooks"
case "$HOOKS" in /*) ;; *) HOOKS="$REPO/$HOOKS" ;; esac
mkdir -p "$HOOKS"
HOOK="$HOOKS/pre-push"

hook_status=installed
if [ -e "$HOOK" ] && ! grep -q PR_QUEUE_WRAPPER "$HOOK" 2>/dev/null; then
  hook_status=blocked
else
  cat > "$HOOK" <<WRAPPER
#!/bin/sh
# PR_QUEUE_WRAPPER — written by scripts/pr-queue/install.sh. Execs the real hook from the queue
# directory, so enforcement disappears with the queue rather than outliving it.
[ -x "$Q/pre-push" ] && exec "$Q/pre-push" "\$@"
exit 0
WRAPPER
  chmod +x "$HOOK"
fi

echo "PR queue installed."
echo "  queue:     $Q"
echo "  checkout:  $REPO"
echo "  main:      $MAIN"
echo "  enforcing: $(cat "$Q/enforce-branches")"
command -v gh >/dev/null 2>&1 || echo "  WARNING: 'gh' not found — the built-in remote checks need it, or install
           your own 'open-prs', 'all-prs' and 'main-green' executables in $Q (see PROTOCOL.md)."
[ -x "$Q/open-prs" ] && echo "  NOTE: an existing 'open-prs' override is in place. It must now exclude DRAFT
        PRs; one written before drafts were exempted will reinstate draft-blocking silently."
echo
echo "Brief each agent with these four commands:"
echo "  $Q/queue.sh ticket  SPEC-XXX"
echo "  $Q/queue.sh turn    SPEC-XXX"
echo "  $Q/queue.sh acquire SPEC-XXX"
echo "  $Q/queue.sh release SPEC-XXX"
echo "Protocol: $Q/PROTOCOL.md"

if [ "$hook_status" = blocked ]; then
  echo
  echo "⚠️  THE HOOK WAS NOT INSTALLED — $HOOK already exists and is not ours." >&2
  echo "   The queue works, but nothing enforces it. Add this to that hook by hand:" >&2
  echo >&2
  echo "     [ -x \"$Q/pre-push\" ] && exec \"$Q/pre-push\" \"\$@\"   # PR_QUEUE_WRAPPER" >&2
  echo >&2
  exit 3
fi
