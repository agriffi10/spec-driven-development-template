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
# THERE IS NO DRY RUN. PR_QUEUE_DIR relocates the queue but not the hook: this still writes
# .git/hooks/pre-push in the checkout it is run from, pointed at whichever queue it just built. A
# scratch run therefore takes the live hook with it — measured by doing exactly that to a live
# repo — so try it in a throwaway clone (`install-test.sh` beside this file does exactly that) and
# read the `hook:` line below to see what was touched. The one guard is below: a wrapper that
# already names a DIFFERENT queue is left alone rather than repointed.
#
# [branch-regex] is the ERE for branches the hook enforces against, and the default is '.' —
# every branch. Narrowing it to a few branch prefixes is the tempting setting and the one that
# breaks: it fails OPEN and says nothing, so the day branch naming moves on the hook stops
# enforcing and still looks installed. The template's previous default, '^spec-', did exactly that
# in both repos that took it: it matched neither `spec/…` nor `docs/…`, installed cleanly, printed
# its pattern, and enforced nothing on any branch anyone pushed. pre-push exempts what cannot open
# a pull request anyway (a non-origin remote, a tag, the trunk from the lock, a deletion from the
# freshness check), which is what makes 'every branch' the honest default rather than a blunt one.
#
# AN EXISTING SETTING IS KEPT when no argument is given, so a widened default does not reach a
# queue that already has one: pass the ERE to re-point it, and the summary says which of the two
# happened. The summary also reports how many of this repo's branches the pattern matches,
# because a narrowed pattern that matches none of them installs cleanly and enforces nothing.
#
# EXIT: 0 installed · 1 could not install (including: a lock is held, or the pattern is blank or
#       not a compilable ERE — refused BEFORE anything is copied, so nothing changed) · 3 queue
#       installed but the hook was NOT — something foreign occupies .git/hooks/pre-push, it points
#       at a different queue and was left alone, the hooks directory could not be written, or
#       core.hooksPath is relative (a wrapper there would not fire in linked worktrees).

set -eu

SRC="$(cd "$(dirname "$0")" && pwd)"

git rev-parse --git-dir >/dev/null 2>&1 || { echo "error: run this from inside the checkout" >&2; exit 1; }

# The MAIN worktree, not whichever linked worktree this was run from: the queue records one
# checkout for its remote checks, and it has to be the one that will still be there tomorrow.
REPO="$(git worktree list --porcelain | sed -n '1s/^worktree //p')"
[ -n "$REPO" ] && [ -d "$REPO" ] || { echo "error: could not locate the main worktree" >&2; exit 1; }

# VALIDATE THE ARGUMENT FIRST, before a directory is made or a file is copied, so that a refusal
# can honestly say nothing changed. A pattern grep cannot compile exempts EVERY branch at runtime
# unless something catches it, and `spec-[` is enough to do it. The hook fails closed on the same
# condition; this refuses to write one at all. It is not a full validation — grep answers "no
# match" rather than "invalid" for a lookaround or a `\d`, and a pattern that matches nothing is
# indistinguishable from a narrow one — which is why `acquire` warns when the branch it is locking
# is outside the pattern, and why the summary below counts. An empty or blank pattern is accepted
# by grep and turns the hook off at its first line, while a later bare install reports it back as
# a deliberate KEPT choice. Refuse it here: "enforce nothing" is a real setting, but it should be
# reached by emptying the file, not by an argument that looks like a pattern.
if [ "$#" -ge 1 ]; then
  if [ -z "$(printf '%s' "$1" | tr -d ' \t')" ]; then
    echo "error: an empty or blank pattern turns the hook off at its first line, and a later" >&2
    echo "       install would report it back as a deliberate choice. Pass '.' for every branch," >&2
    echo "       or empty the queue's enforce-branches by hand if you really mean to enforce nothing." >&2
    echo "       Nothing was changed." >&2
    exit 1
  fi
  probe_rc=0
  printf 'probe\n' | grep -qE "$1" >/dev/null 2>&1 || probe_rc=$?
  if [ "$probe_rc" -gt 1 ]; then
    echo "error: '$1' is not an ERE grep can compile, and a pattern that cannot be evaluated" >&2
    echo "       would exempt every branch. Nothing was changed." >&2
    exit 1
  fi
fi

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
# origin/HEAD does not exist in a checkout made by `git init` + `git remote add`, and it goes stale
# when the remote renames its default branch. Ask the remote before falling back to a guess: a
# wrong trunk name here is what makes pre-push refuse every push in the repo it was installed for.
# Asked of origin, or of the checkout's only remote when there is no origin — a fork kept as
# `upstream`, say — because a guessed `main` against a `master` remote makes the hook refuse
# every push in that repo with "no branch named main".
if [ -z "$MAIN" ]; then
  if git -C "$REPO" remote get-url origin >/dev/null 2>&1; then ask=origin
  else ask="$(git -C "$REPO" remote | head -1)"; fi
  if [ -n "$ask" ]; then
    MAIN="$(git -C "$REPO" ls-remote --symref "$ask" HEAD 2>/dev/null |
              awk '$1 == "ref:" { sub("^refs/heads/", "", $2); print $2; exit }')"
  fi
fi
[ -n "$MAIN" ] || MAIN=main

# REFUSE TO UPGRADE UNDER A HELD LOCK, before anything is copied. This is the one operation that
# can strand a session with no recovery: the scripts are swapped mid-protocol, and across a change
# to the holder-file format the new ones read every field of the old holder as empty. Measured in
# a consumer, on a generation whose holder format did change under a held lock — the holder's own
# push was refused with `Lock holder: (free)`, its `acquire` said the lock was held by nobody, its
# `release` exited 0 while leaving the lock in place and dropping its ticket, every waiter polled
# forever, and `reap` could not clear it while a PR was open, which a lock holder by definition
# has. The holder format has not changed here, but the swap itself is the hazard (see below):
# waiting is free; that state cost 90 minutes.
if [ -d "$Q/lock" ]; then
  echo "error: the queue at $Q has a lock held:" >&2
  # `>&2` has to come BEFORE `2>/dev/null`, or it duplicates the already-nulled descriptor and the
  # holder — the one fact the operator needs — is printed into nowhere. An `if` rather than
  # `[ -f … ] && …`, because a false test is a non-zero statement and `set -e` would exit on it.
  # `|| true` because sed is the LAST command of this branch: an unreadable holder makes it exit
  # non-zero, `set -e` takes the script out there, and the two lines that say what to do next —
  # the whole point of the refusal — are never printed. BSD sed returns 1 and GNU 2, so the exit
  # code also stops meaning what the header says it means.
  if [ -f "$Q/lock/holder" ]; then sed 's/^/         /' "$Q/lock/holder" >&2 || true; fi
  echo "       Installing now can strand it with no recovery. Wait for the holder to release." >&2
  echo "       If that lock is known dead, remove $Q/lock by hand and say so." >&2
  exit 1
fi

# STAGE, THEN RENAME — never `cp` over a file a peer may be executing. `cp` truncates and rewrites
# the SAME inode, and a shell reads a script incrementally: a peer part-way through `queue.sh` or
# `pre-push` carries on reading at its byte offset into whatever is there now. Measured on this
# script: a peer cut mid-file exits 0 having run only its first half, or dies on a syntax error in
# a line that does not exist in either version. `acquire` between its `mkdir` and its holder write
# leaves a lock directory with no holder — the very "held by nobody" state the check above refuses
# to create. `rename(2)` is atomic and leaves a running process on its old inode, so a peer either
# gets the whole previous file or the whole new one.
#
# The previous copies are kept beside the queue first. A generation that was hand-edited after it
# was deployed exists in no commit, so without this a bad upgrade has nothing to go back to.
STAGE="$Q/.staged.$$"
PREV="$Q/.previous"
rm -rf "$STAGE"; mkdir -p "$STAGE" "$PREV"
for f in queue.sh pre-push PROTOCOL.md; do
  if [ -f "$Q/$f" ]; then cp "$Q/$f" "$PREV/$f"; fi
  cp "$SRC/$f" "$STAGE/$f"
done
if [ -f "$Q/enforce-branches" ]; then cp "$Q/enforce-branches" "$PREV/enforce-branches"; fi
chmod +x "$STAGE/queue.sh" "$STAGE/pre-push"
for f in queue.sh pre-push PROTOCOL.md; do mv -f "$STAGE/$f" "$Q/$f"; done
# `rm -rf`, not `rmdir`: anything left in the staging directory means a move did not happen, and
# failing here under `set -e` would abort AFTER the files were already in place — a half-install
# reported as an error. Clean up unconditionally and let the install stand or fall on its own.
rm -rf "$STAGE"
printf '%s\n' "$REPO" > "$Q/repo"
printf '%s\n' "$MAIN" > "$Q/main-branch"

# An existing pattern is KEPT, never overwritten — a project may have narrowed it deliberately.
# That makes an upgrade the one case where the default does not apply, so the summary below has
# to say which of the two happened: an install that reports "enforcing: <stale pattern>" under the
# word "installed" reads exactly like an install that chose it. (The argument was validated at the
# top, before anything was copied.)
pattern_source=written
if [ "$#" -ge 1 ]; then
  printf '%s\n' "$1" > "$Q/enforce-branches"
elif [ ! -s "$Q/enforce-branches" ]; then
  printf '%s\n' '.' > "$Q/enforce-branches"
else
  pattern_source=kept
fi

# --- the hook wrapper -------------------------------------------------------------------------
# Linked worktrees share the common git dir's hooks, so installing here covers every session on
# the checkout — which is the point, and also why the hook it execs fails open.
#
# The wrapper is also the ONLY place the missing-queue fail-open can live. pre-push sits inside
# the queue directory, so a deleted queue deletes it too and no guard of its own can run; this
# `[ -x ... ] && exec` is what actually lets the push through afterwards.
# A RELATIVE core.hooksPath is refused. git resolves it against the root of the worktree the
# hook runs from, so a wrapper written under the main worktree fires there and nowhere else: every
# linked worktree — the agent sessions this queue exists for — pushes unenforced, while the summary
# reports a hook installed. That is the configuration husky and lefthook write, and it was measured
# on a linked worktree: push accepted, no output from the hook at all. The remedy is an absolute
# path, which every worktree resolves to the same file.
HOOKS_CFG="$(git -C "$REPO" config --get core.hooksPath || true)"
hooks_relative=0
if [ -n "$HOOKS_CFG" ]; then
  HOOKS="$HOOKS_CFG"
  case "$HOOKS" in /*) ;; *) hooks_relative=1; HOOKS="$REPO/$HOOKS" ;; esac
else
  HOOKS="$(git -C "$REPO" rev-parse --git-common-dir)/hooks"
  case "$HOOKS" in /*) ;; *) HOOKS="$REPO/$HOOKS" ;; esac
fi
HOOK="$HOOKS/pre-push"

# WHOSE HOOK IS THIS? Three answers, and they are not interchangeable.
#
# Every wrapper this script writes declares its queue on a `Q=` line, so the question is answered
# by reading that line rather than by searching for a path. Searching was the first attempt and it
# is wrong in the dangerous direction twice: a foreign hook that merely mentions the directory
# matches, and so does any queue whose path merely starts with this one.
#
# The third answer is the one that matters after an upgrade. Once a wrapper carries the marker, a
# BARE run of this script — which picks its own path from the origin slug — would happily repoint
# the hook at a brand-new empty queue while every session went on using the old one: every push
# refused, against a lock nobody holds, with the real queue's line and log orphaned. So a wrapper
# naming a different queue is REFUSED, not replaced.
existing_q=""
hook_status=installed
[ "$hooks_relative" -eq 0 ] || hook_status=relhooks
if [ "$hook_status" = installed ]; then mkdir -p "$HOOKS"; fi
if [ "$hook_status" = installed ] && [ -e "$HOOK" ]; then
  existing_q="$(sed -n 's/^Q=//p' "$HOOK" 2>/dev/null | head -1)"
  # The value is single-quoted by the wrapper below and was bare in the generation before it, so
  # strip either. Reading the quotes as part of the path would make this queue's own wrapper look
  # like a stranger's and refuse to upgrade it.
  existing_q="${existing_q#\'}"; existing_q="${existing_q%\'}"
  existing_q="${existing_q#\"}"; existing_q="${existing_q%\"}"
  # The generation before the Q= line named its queue only on the exec line. Read it from there,
  # or a bare re-install over one of those wrappers — a consumer installed under PR_QUEUE_DIR, say
  # — would pass as "ours" and be repointed at the slug path, orphaning the live queue.
  if [ -z "$existing_q" ] && grep -q PR_QUEUE_WRAPPER "$HOOK" 2>/dev/null; then
    existing_q="$(sed -n 's/^\[ -x "\(.*\)\/pre-push" \] && exec .*/\1/p' "$HOOK" 2>/dev/null | head -1)"
  fi
  if [ -n "$existing_q" ] && [ "$existing_q" != "$Q" ]; then
    hook_status=other
  elif [ -z "$existing_q" ] && ! grep -q PR_QUEUE_WRAPPER "$HOOK" 2>/dev/null; then
    hook_status=blocked
  fi
fi
if [ "$hook_status" = installed ]; then
  # Written beside and RENAMED, for the reason the queue's own files are: `cat >` truncates the
  # existing inode, and this hook runs on every push. Measured at 300 installs, it is a zero-byte
  # executable for about 1.25% of each one — and a zero-byte hook exits 0, which is a fail-open.
  #
  # The write is also TESTED rather than left to `set -e`. An unwritable hooks directory made the
  # script exit before its summary, reporting "could not install" (1 on BSD, 2 on GNU) about a
  # queue that was fully installed — where the header promises 3, "installed but the hook was NOT".
  hook_tmp="$HOOK.pr-queue.$$"
  if cat > "$hook_tmp" <<WRAPPER
#!/bin/sh
# PR_QUEUE_WRAPPER — written by scripts/pr-queue/install.sh. Execs the real hook from the queue
# directory, so enforcement disappears with the queue rather than outliving it: delete the queue
# and this becomes a no-op, which is where the missing-queue fail-open actually lives.
#
# The Q= line below is this file's identity. A later install reads it to tell its own wrapper from
# a foreign hook and from a wrapper belonging to a DIFFERENT queue. Keep it one line, first field.
# SINGLE quotes: a path with a space would otherwise parse as an assignment plus a command, and the
# wrapper would exit 0 — installing cleanly, saying so, and enforcing nothing. Double quotes would
# still interpolate a \$ in the path.
Q='$Q'
[ -x "\$Q/pre-push" ] && exec "\$Q/pre-push" "\$@"
exit 0
WRAPPER
  then
    chmod +x "$hook_tmp"
    mv -f "$hook_tmp" "$HOOK"
  else
    rm -f "$hook_tmp"
    hook_status=unwritable
  fi
fi

echo "PR queue installed."
echo "  queue:     $Q"
echo "  checkout:  $REPO"
echo "  main:      $MAIN"
# A pattern is only enforcement if it matches the branches this repo actually uses, so say so
# here rather than leaving it to be discovered by a push that should have been refused and was
# not. Counted over local branches other than the trunk; a fresh clone has none of its own, which
# is why the warning is gated on there being some to match.
pat="$(cat "$Q/enforce-branches")"
branches="$(git -C "$REPO" for-each-ref --format='%(refname:short)' refs/heads | grep -vxF "$MAIN" || true)"
total=$(printf '%s' "$branches" | grep -c . || true)
# Three states, and only one of them is a count. An EMPTY pattern is what pre-push tests for
# first and exits on, so it enforces nothing — but an empty ERE matches every line, so counting
# it would report total coverage for the one setting that has none. An INVALID ERE makes grep
# exit 2 with empty output, which would print "( of 12)" and then compare an empty string as an
# integer. Both were live escapes in the first version of this summary. Neither can be WRITTEN by
# this script any more; both can still be KEPT from a file edited by hand, which is why the states
# stay.
# grep exits 2 on an invalid ERE and 1 on a valid one that simply did not match; `|| pat_rc=$?`
# is what keeps `set -e` from aborting on the ordinary no-match case.
pat_rc=0
printf 'x\n' | grep -qE "$pat" >/dev/null 2>&1 || pat_rc=$?
kept_note=""
[ "$pattern_source" = kept ] && kept_note="   <-- KEPT from the previous install, NOT written"
if [ -z "$pat" ]; then
  echo "  enforcing: (empty) — the hook exits before testing any ref, so NOTHING is enforced.$kept_note"
  echo "  WARNING: set a pattern: sh scripts/pr-queue/install.sh '.'   (every branch)"
elif [ "$pat_rc" -gt 1 ]; then
  echo "  enforcing: $pat — NOT A VALID ERE, so the hook refuses every push it judges.$kept_note"
  echo "  WARNING: fix the expression: sh scripts/pr-queue/install.sh '.'   (every branch)"
else
  matched=$(printf '%s' "$branches" | grep -cE "$pat" || true)
  echo "  enforcing: $pat  ($matched of $total local branches besides $MAIN)$kept_note"
  [ "$matched" -eq "$total" ] || echo "             (agent worktree and scratch branches are expected not to match)"
  if [ "$total" -gt 0 ] && [ "$matched" -eq 0 ]; then
    echo "  WARNING: that pattern matches none of them, so the hook will refuse nothing. Re-run with
           the ERE your branches use, or sh scripts/pr-queue/install.sh '.' for every branch."
  fi
fi
[ "$pattern_source" = kept ] && echo "             Pass a regex to change it, e.g.  install.sh '.'  for every branch."
case "$hook_status" in
  installed)  echo "  hook:      $HOOK -> $Q/pre-push" ;;
  blocked)    echo "  hook:      $HOOK — LEFT ALONE, it is not ours; nothing is enforced until the
             line below is added to it by hand" ;;
  other)      echo "  hook:      $HOOK — LEFT ALONE, it points at a different queue (see below)" ;;
  unwritable) echo "  hook:      $HOOK — NOT WRITTEN (see below)" ;;
  relhooks)   echo "  hook:      NOT WRITTEN — core.hooksPath is relative (see below)" ;;
esac
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

if [ "$hook_status" = relhooks ]; then
  echo
  echo "⚠️  THE HOOK WAS NOT WRITTEN — core.hooksPath is relative ($HOOKS_CFG)." >&2
  echo "   git resolves a relative hooks path against the root of whichever worktree the hook" >&2
  echo "   runs from, so a wrapper here would fire in the main worktree only and every linked" >&2
  echo "   worktree would push unenforced. The queue at $Q is installed but NOT wired. Make the" >&2
  echo "   path absolute and re-run:" >&2
  echo >&2
  echo "     git config core.hooksPath \"$REPO/$HOOKS_CFG\"" >&2
  echo >&2
  exit 3
fi

if [ "$hook_status" = unwritable ]; then
  echo
  echo "⚠️  THE HOOK WAS NOT WRITTEN — $HOOK could not be created." >&2
  echo "   The queue at $Q is installed and usable, but nothing enforces it." >&2
  echo "   Fix the permissions on that directory and re-run." >&2
  echo >&2
  exit 3
fi

if [ "$hook_status" = other ]; then
  echo
  echo "⚠️  THE HOOK WAS LEFT ALONE — it already points at a DIFFERENT queue:" >&2
  echo "       $existing_q" >&2
  echo "   Repointing it would hand every session on this checkout a queue with none of the" >&2
  echo "   line, lock or log they are using. This queue at $Q is now installed but NOT wired." >&2
  echo "   If you meant to upgrade the queue in use, re-run with PR_QUEUE_DIR=$existing_q." >&2
  echo >&2
  exit 3
fi

if [ "$hook_status" = blocked ]; then
  echo
  echo "⚠️  THE HOOK WAS NOT INSTALLED — $HOOK already exists and is not ours." >&2
  echo "   The queue works, but nothing enforces it. Add this to that hook by hand:" >&2
  echo >&2
  echo "     [ -x \"$Q/pre-push\" ] && exec \"$Q/pre-push\" \"\$@\"   # PR_QUEUE_WRAPPER" >&2
  echo >&2
  exit 3
fi
