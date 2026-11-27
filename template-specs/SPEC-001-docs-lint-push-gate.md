---
type: Spec
id: SPEC-001
title: "Docs-lint push gate"
description: "A git pre-push hook that refuses a push whose commit fails docs-lint, with an installer that composes with the PR queue's hook, for every person and agent session pushing from a scaffolded repository."
spec_status: Draft
depends_on: []
arc: mechanical-gates
arc_order: 1
---

## Overview

The template's stated principle is that its rules hold by mechanism, not by instruction. The doc
linter is the exception at a session's last step: it is a local gate that nothing in CI runs, on
purpose, so whether it ran before a push depends on a session remembering to run it, and the process
docs themselves concede that this is the category of rule that rots. This spec makes that gate
mechanical without moving it. Once a person has installed it in a clone, a push from that clone is
refused when the commit being pushed fails the doc linter, whether a person or an agent session made
the push, and the refusal says why and how to override it. It is a check on the pushing side, so it
holds for every push that runs git's hooks and for no push that is told to skip them. It is for the
people and agent sessions who push from a repository scaffolded from this template, and for the
template repository itself.

## Scope

### In Scope

- A git `pre-push` gate that lints each commit being pushed with that commit's own
  `scripts/docs-lint.sh`, and refuses the push when the linter does not pass.
- The rules for what the gate leaves alone (a tag, a deletion, a commit that carries no linter), its
  one override, and its refusal when it could not tell.
- An installer for the gate that needs no PR queue, and one wrapper shape at the hooks directory's
  `pre-push` that both this installer and the PR queue's installer write, so the two compose in
  either order.
- One rule for whose hook a `pre-push` file is, applied by both installers, which closes an existing
  defect in the queue installer, and one block a person can paste into a hook of their own.
- A fixture corpus for the gate, the wrapper and both installers, with a mutation sweep, and the
  permission entries that let a session run that corpus.
- Every prose site that states the old arrangement, and the skill's upgrade steps for a repository
  scaffolded before this change.

### Out of Scope

- **The session-start report.** SPEC-002, the second spec in this arc, delivers the Claude Code
  `SessionStart` hook that says whether this wrapper is installed in a clone and which specs are in
  progress. This spec delivers the wrapper it reads and nothing that runs at session start.
- **Moving docs-lint into CI.** That it stays a local gate is settled, for the reason
  `docs/process/completion-ritual.md` gives: a failure lands on the person who caused it rather than on
  a shared branch. This spec makes the local gate mechanical; it does not reopen where the gate runs.
- **A Claude Code `PreToolUse` hook on `git push`.** It cannot reliably tell which tree a push
  targets, and the vendor says not to use one as a hard gate (*Settled Design*, D1).
- **A permission entry for `scripts/hooks/install.sh`.** A person runs the installer, once per clone
  (D6). A session is not pre-allowed to run it and the scaffolding steps do not run it.
- **Running the other local gates from the hook** (spec-lint, the test corpora, a project's own
  formatter and tests). spec-lint already runs in CI, and the rest are the project's own and vary by
  project; this gate runs the one gate that nothing else runs.
- **Running `scripts/hooks-test.sh` in CI.** It is a local corpus, run when the gate, the wrapper or an
  installer changes, exactly as `scripts/pr-queue-test.sh` is.
- **Windows without a POSIX shell.** Every script here is POSIX `sh`, as the existing scripts are.
- **A scaffold that is not at the repository's top level.** The wrapper looks for the gate at
  `scripts/hooks/pre-push-gate` under the pushing worktree's root, as the PR queue and the linters
  already assume.
- **A foreign hook that is not a shell script.** The block a person can paste is POSIX `sh`; a
  `pre-push` written in another language is left alone and gets no gate.
- **A path-scoped rule under `.claude/rules/` for `scripts/hooks/`.** A rule is a backstop that points
  a reader at a process part; the hooks are held by their corpus, and a pointer can be added later
  without touching anything this spec builds.
- **Protecting the wrapper from an installer older than this spec.** A `scripts/pr-queue/install.sh`
  run from a worktree whose branch predates this change rewrites the wrapper in the previous shape,
  without the gate line. Nothing here prevents that; either current installer restores it without
  losing the queue.
- **Changing what the PR queue's own hook refuses.** `scripts/pr-queue/pre-push` changes in comment
  lines only (FR-004); the wrapper that runs it and the installer that writes the wrapper are what
  change.
- **A timeout on the linter.** A commit whose `scripts/docs-lint.sh` never returns holds the push
  until it is interrupted.
- **A push made with `git push --no-verify`.** git skips every `pre-push` hook for it, so the wrapper,
  the gate and the PR queue's hook do not run and nothing is printed. That is inherent to a hook on
  the pushing side (D1) and is the same limit the queue's hook already has. Nothing in this spec
  closes it, and `.claude/settings.json` allows `git push` with any arguments. Only a check on the
  remote could, and docs-lint stays out of CI. The limit is stated in the README's guardrail row
  (FR-006) so nobody takes the gate for more than it is.

---

## Settled Design

These decisions are settled and are recorded here, with their reasons, so a builder does not
re-derive them and a reviewer can check the spec against its authority. The vendor facts were read
from the live Claude Code hooks reference, and the git facts were measured in throwaway repositories
on git 2.54.

**D1. The push gate is git's own `pre-push` hook, not a Claude Code `PreToolUse` hook.**
git runs `pre-push` with its working directory at the root of the worktree the push is made from: a
plain push, `git -C <worktree> push` run from the main worktree, and a push from a subdirectory each
ran the hook at the pushing worktree's root, and linked worktrees share the common git directory's
hooks. A `PreToolUse` hook would have to work out which tree a `git push` command targets, and its
`cwd` input is the session's directory rather than the pushed tree, while sessions here push from
scratch worktrees through `cd <worktree> && git push` or `git -C`. The vendor documents the `if`
filter (`Bash(git push *)`) as best-effort and says to use the permission system rather than a hook
for a hard gate, and documents that a `PreToolUse` command hook that times out does not block the
call. A git hook also covers a person at a terminal and any other agent harness.

**D2. The gate lints the commit being pushed, not the working tree.** The result is then independent
of uncommitted edits, and correct when the pushed commit is not the pushing worktree's `HEAD` (for
example `git push origin other-branch`). `scripts/docs-lint.sh` and the generator it calls walk the
tree with `find` and never call git, so they run correctly in an exported copy of a commit: the
linter exits 0 over an exported copy of this repository at commit `08643d9`. How the commit is
exported is the builder's choice, under one constraint that is observable and is tested: the exported
tree holds every tracked file of the commit, as git checks it out. `git archive` does not meet it. It
drops every path marked `export-ignore`, which would let a commit pass by hiding the file that fails,
and it rewrites files marked `export-subst`. A checkout through a temporary index does meet it and
leaves `git status`, the branch and tag refs and `git worktree list` unchanged, including from a hook
in a linked worktree; that was run in a throwaway repository with a file under each of those two
attributes. "As git checks it out" is
the honest wording: a file under an `ident` or `eol` attribute is checked out with other bytes than
the commit stores, in the exported tree exactly as in anyone's working tree, so the linter sees what a
checkout of that commit holds.

**D3. The gate fails open on what is not its business and closed on evidence.** A tag, a branch
deletion and a commit that carries no `scripts/docs-lint.sh` are not its business. The linter exiting
non-zero for any reason, a commit that could not be read, and a commit that could not be exported are
evidence that the check did not pass, and a check that could not run is never read as one that
passed. The same split governs the PR queue's hook.

**D4. One wrapper, two things it can run, either installer may write it.** git allows one `pre-push`
file, and `scripts/pr-queue/install.sh` already writes a wrapper there. The gate's logic lives in the
repository and the wrapper runs the copy in the pushing worktree, so the gate is versioned with the
branch and disappears harmlessly from a tree that does not have it. The wrapper has one shape whoever
wrote it, so installation order cannot matter.

**D5. Each installer carries the wrapper's text itself.** There is no shared file that both read. The
queue corpus's mutation sweep (`scripts/pr-queue-test.sh`, `plant()`) builds each mutant by copying
`install.sh`, `queue.sh` and `PROTOCOL.md` into a fresh directory and running that copy's installer,
and it counts any failing sub-run as a case gone red. An installer that read the wrapper from a
neighbouring file would fail in every such copy, and every plant would report success for the wrong
reason. What holds the two texts equal is the byte-identity criterion in FR-004.

**D6. A person runs the gate installer.** `scripts/hooks/install.sh` is not pre-allowed in
`.claude/settings.json`, and the skill's scaffolding step tells the user to run it rather than
running it, for one reason: both
installers write into `.git/hooks`, and `README.md` already states the policy for the queue installer
("run once, by a person"), so the two are held to one policy.

**D7. The existing foreign-hook defect is fixed in this spec.** At commit `08643d9`, a foreign
`pre-push` to which the user has added the queue installer's own advised line (it ends in
`# PR_QUEUE_WRAPPER`) is taken for a wrapper by the next `scripts/pr-queue/install.sh` run and
replaced, the user's own hook with it. The fix belongs here rather than in a
separate change, because both installers must decide whose hook a file is by one rule (FR-003).

**D8. Every new gate owes a corpus that asserts the reason.** The template's rule
(`docs/process/reviewer-contract.md`) is that a gate is not tested by running it on what it guards: it
owes a fixture corpus asserting the failure text, including cases that assert silence, and the corpus
is proved by defeating each check in turn.

**Technical constraints.**

- Every new script is POSIX `sh` with no dependency beyond git and the standard utilities the
  existing scripts already use. The gate makes no network call.
- **The signal rule.** `scripts/signal-test.sh` runs in CI in this repository and holds every tracked
  file under `scripts/` that contains a `trap` to exactly two lines, `trap '<cleanup>' EXIT` followed
  by one column-0 `trap 'exit N' HUP INT PIPE TERM`, and it runs a copy of each such script from the
  repository root as far as that line. So: `scripts/hooks/pre-push-gate` and `scripts/hooks-test.sh`
  use that two-line shape, each with `exit 1`, set before any early exit, before standard input is
  read and before any scratch is created; and `scripts/hooks/install.sh` sets no trap, because a
  trapped installer would have CI and every maintainer run the installer's opening lines inside the
  real checkout. The installer's only temporary file is the wrapper written beside its destination
  and renamed at once; an installer killed between the two can leave that one file behind, which git
  never runs.
- This spec adds no process part and no router row. Every scaffold file is edited in the payload,
  `.claude/skills/spec-driven/template/`, and the root is regenerated with
  `sh scripts/sync-from-skill.sh`.

---

## Functional Requirements

Two refusal texts are named throughout, so that no criterion says only that a push was refused.
**The docs-lint refusal** is standard error carrying
`PUSH REFUSED — docs-lint failed on the commit being pushed.` **The queue's lock refusal** is standard
error carrying `PUSH REFUSED — you do not hold the PR queue lock.`, which `scripts/pr-queue/pre-push`
prints today. "A failing commit" is a commit whose `scripts/docs-lint.sh`, run over that commit's
tracked files, exits 1; "a passing commit" is one where it exits 0.

### FR-001: The gate lints each commit being pushed and refuses the push when the linter fails

#### Description:

`scripts/hooks/pre-push-gate` reads the pushed refs from standard input, one
`<local ref> <local sha> <remote ref> <remote sha>` line per ref, as git supplies them to a `pre-push`
hook. For each line whose remote ref is under `refs/heads/` and which is not a deletion, it exports
that line's commit into a temporary directory under `TMPDIR`, outside the repository, runs that
commit's own `scripts/docs-lint.sh` there, and refuses the push when the linter exits 1. It keys on the
remote ref because that is the ref that decides what appears on the remote. One distinct commit is
linted once however many refs carry it. The temporary directory is removed on every exit path,
including a signal. A push that passes prints nothing at all.

#### Acceptance Criteria:

- [ ] A push of a branch at a failing commit exits non-zero, nothing reaches the remote, and standard
      error carries the docs-lint refusal, the remote branch name, the commit's abbreviated object
      name as `git rev-parse --short` prints it, every line the linter printed, and
      `Emergency override: DOCS_LINT_BYPASS=1 git push ...`.
- [ ] A push of a branch at a passing commit exits 0, the ref reaches the remote, and the gate writes
      nothing to standard output or standard error.
- [ ] Dirty tree, clean commit: with a tracked file modified and an untracked file added so that
      `sh scripts/docs-lint.sh` run in the working tree exits 1 (the test asserts this first, with the
      linter's own text), a push of the unmodified `HEAD` commit is allowed and the gate prints nothing.
- [ ] Clean tree, failing commit: with `HEAD` a failing commit and the fix present in the working tree
      but not committed, so that `sh scripts/docs-lint.sh` run in the working tree exits 0 (asserted
      first), the push is refused with the docs-lint refusal.
- [ ] A push of a branch that is not checked out (`git push origin other-branch`, made from a worktree
      whose own `HEAD` is a passing commit) is refused with the docs-lint refusal when `other-branch`
      is a failing commit, and the refusal names `other-branch`.
- [ ] The linter that runs is the pushed commit's: when the commit's `scripts/docs-lint.sh` prints a
      marker line and exits 1 while the working tree's copy would exit 0, the refusal carries the
      marker line.
- [ ] The exported tree holds every tracked file, as git checks it out: a failing commit whose failing
      file is marked `export-ignore` in a committed `.gitattributes` is still refused, with the
      linter's text about that file; and a stub linter that prints a checksum of a tracked file marked
      `export-subst` prints the checksum that file has in a fresh checkout of the commit.
- [ ] Two branch refs pushed at the same failing commit produce one refusal block that names both
      branches, and that commit's linter ran exactly once (asserted with a stub linter that records
      each run).
- [ ] A push of two branches at different commits, one failing and one passing, is refused; the
      refusal names the failing branch and does not name the passing one.
- [ ] After an allowed push and after a refused push, the directory `TMPDIR` points at holds nothing
      the gate created.
- [ ] For each of `HUP`, `INT`, `PIPE` and `TERM`: with the gate run directly in the foreground over a
      commit whose stub linter waits a bounded time and then exits 0, and the signal sent to the gate
      by a background sender during that wait, the gate exits 1 and `TMPDIR` holds nothing the gate
      created. The stub exits 0 so that the 1 can only come from the signal line: a gate whose handler
      only cleaned up would go on to exit 0, and a gate with no signal line is either killed, with an
      exit status above 128, or carries on to exit 0. The gate is not started with `&`, because a shell started that way inherits `INT` as
      ignored and cannot trap it; a signal the test's own shell ignores on entry is skipped by name,
      as `scripts/signal-test.sh` does, and a run in which every signal was skipped fails.
- [ ] `sh scripts/signal-test.sh` exits 0 and prints
      `ok    scripts/hooks/pre-push-gate exits 1 on every trapped signal`. This is what holds the
      two-line shape itself: it refuses any other spelling of the traps and plants each signal
      directly after the signal line, and CI runs it under dash.
- [ ] A gate run changes nothing in the repository: `git status --porcelain`,
      `git for-each-ref refs/heads refs/tags` and `git worktree list` in the pushing worktree are
      identical before and after an allowed push and before and after a refused one.
- [ ] The gate makes no network call: with the gate run directly (not through a push, because git puts
      its own directory first on a hook's `PATH` and a shim would see nothing the gate does) and a
      `git` placed first on `PATH` that records its arguments and then runs the real one, a run over a
      failing commit and one over a passing commit each record at least one git call and record no
      `fetch`, `pull`, `push`, `ls-remote`, `remote` or `clone` subcommand.
- [ ] The shipped linter runs correctly in the exported tree: in a throwaway repository holding the
      shipped `scripts/docs-lint.sh`, `scripts/frontmatter.awk` and `scripts/gen-index.sh` and a
      minimal conformant tree that carries a `CLAUDE.md` and a `docs/process/` with its router (the
      linter checks nothing in a tree without them), a push is allowed silently; after a commit that
      adds a stub at
      `docs/process.md`, the push is refused and the refusal carries the shipped linter's own line
      beginning `FAIL  docs/process.md exists beside docs/process/`.

### FR-002: What the gate leaves alone, its override, and its refusal when it could not tell

#### Description:

The gate leaves alone what is not its business. A line whose remote ref is not under `refs/heads/` (a
tag, a note) is not inspected. A deletion, which git marks with the literal local ref `(delete)`, has
no commit to lint. A commit that carries no `scripts/docs-lint.sh` belongs to a branch that predates
the gate. Each of these lets the push through in silence, and so does a push that carries no ref at
all (an up-to-date push, for which the wrapper hands the gate one blank line).

"Carries no linter" has one meaning: the object named on the line is readable as a commit, and its
tree has no path `scripts/docs-lint.sh`. The two halves are decided separately, because one git
command that asks for the file answers the same way for a commit without it, for a deletion's
all-zero object and for an object that cannot be read. An object that cannot be read as a commit is
evidence, not an exemption, and is refused.

Evidence is refused in three ways, each with its own text (*API / Interface Contract*, *Refusal
text*): the linter exiting 1; the linter exiting with any other non-zero status (its "could not run"
exit, or death by a signal); and a commit that could not be read or could not be exported. The
gate's one override is the environment variable `DOCS_LINT_BYPASS=1`, which skips the check and says
so in one line on standard error. (git's own `--no-verify` is not an override of the gate: it stops
git from running any `pre-push` hook at all, in silence, and is named in *Out of Scope*.) The gate
applies to a push to any remote, not only `origin`, because the
linter judges the commit and not where it is going. A consequence worth knowing: docs-lint has one
check that reads the date (a rulebook past its `stale_after`), so a commit that passed last month can
be refused today; that is the linter's stated intent, and the override exists for the push that must
go out first.

#### Acceptance Criteria:

- [ ] A push of a tag that points at a failing commit is allowed and the gate prints nothing; the same
      commit pushed to a branch in the same repository is refused with the docs-lint refusal (this
      second half is what shows the first is the tag exemption and not a gate that did not run).
- [ ] A push that deletes a remote branch (`git push origin --delete <branch>`) is allowed and the gate
      prints nothing.
- [ ] A push of a branch whose commit has no `scripts/docs-lint.sh` is allowed and the gate prints
      nothing, and it is still allowed with `TMPDIR` pointing at the path of a regular file (so nothing
      was exported for it; the same `TMPDIR` refuses a commit that does carry the linter, below).
- [ ] Run directly with no line on standard input, and with one blank line, the gate exits 0 and
      prints nothing.
- [ ] Run directly with a line whose remote ref is under `refs/heads/`, whose local ref is not
      `(delete)` and whose local object name is one the repository does not have, the gate exits 1 and
      standard error carries `PUSH REFUSED — the commit being pushed could not be exported for linting.`
      and the branch.
- [ ] A push of a tag and a failing branch together is refused, and the refusal names the branch and
      not the tag.
- [ ] With `DOCS_LINT_BYPASS=1`, a push of a failing commit is allowed, standard error carries exactly
      one line from the gate, `pre-push: DOCS_LINT_BYPASS=1 — docs-lint check skipped`, and no linter
      is run (asserted with the recording stub).
- [ ] With `DOCS_LINT_BYPASS` set to `0`, to `true`, or to the empty string, a push of a failing
      commit is refused with the docs-lint refusal.
- [ ] A commit whose `scripts/docs-lint.sh` exits 2 is refused, and standard error carries
      `PUSH REFUSED — docs-lint could not run on the commit being pushed (it exited 2).`, the branch,
      the abbreviated object name, the linter's output and the override line.
- [ ] When the commit cannot be exported (the test points `TMPDIR` at the path of a regular file,
      under which no directory can be made), the push is refused and standard error carries
      `PUSH REFUSED — the commit being pushed could not be exported for linting.`, the branch, the
      abbreviated object name and the override line. (A gate that lets `mktemp` pick its own directory
      fails this: on macOS, `mktemp -d` with `TMPDIR` at a regular file made a directory elsewhere and
      exited 0. The exported tree goes under `TMPDIR` by name, as FR-001 says.)
- [ ] A push of a failing commit to a second remote that is not `origin` is refused with the docs-lint
      refusal.
- [ ] Every refusal exits 1 and writes only to standard error.

### FR-003: The gate installer writes the wrapper, and guards what is already there

#### Description:

`sh scripts/hooks/install.sh`, run by a person with no argument from anywhere inside a checkout,
installs the gate in a repository that does not use the PR queue. It writes the wrapper described
under *Data Model* to the hooks directory's `pre-push`: the absolute `core.hooksPath` when one is
configured, otherwise the `hooks` directory of the common git directory, which every linked worktree
shares. The wrapper runs the gate from the worktree a push is made from, when that worktree has one.
The guards the queue's installer already has carry over, for the reasons that installer records: a
`pre-push` that is not this template's wrapper is left alone and reported with its own exit status; a
relative `core.hooksPath` is refused, because git resolves it against whichever worktree the hook runs
from, so a wrapper there fires in the main worktree only; and the wrapper is written beside its
destination and renamed into place, because a truncating write leaves a zero-byte hook for a moment,
and a zero-byte hook exits 0.

**Whose hook a file is.** A `pre-push` file is this template's wrapper when its second line begins
with `# PR_QUEUE_WRAPPER`. The marker anywhere else does not make a file ours (D7). The claim that
earlier wrappers carry the marker there is verified for the two generations in this repository's
history: the one commit `4a5237b` introduced, which names its queue only on its `exec` line, and the
one commit `9e5017a` introduced, with a single-quoted `Q=` line. The installer's own comments record a
third generation, with a bare `Q=` value, that exists only in consumer checkouts and could not be
examined here. A wrapper of any generation that does not carry the marker on its second line is
treated as foreign and left alone, which is the safe direction: nothing is overwritten, and the
installer says what to do by hand.

For a foreign hook, the installer prints the block under *API / Interface Contract*, *The block for a
hook of your own*, with advice that says where it goes (FR-004).

#### Acceptance Criteria:

- [ ] In a fresh clone with no `pre-push` hook, `sh scripts/hooks/install.sh` exits 0, prints
      `Pre-push gate installed.` and a `hook:` line naming the file it wrote, and that file is
      executable and its second, third and fourth lines are the marker line, `Q=''` and
      `GATE='scripts/hooks/pre-push-gate'`.
- [ ] After that install, a push of a failing commit is refused with the docs-lint refusal and a push
      of a passing commit is allowed in silence.
- [ ] The installer is idempotent: a second run exits 0 and leaves the wrapper byte-identical.
- [ ] A wrapper of ours whose executable bit has been removed is executable again after a run, which
      exits 0.
- [ ] Run from a linked worktree, the installer writes the common hooks directory's `pre-push`, and a
      push of a failing commit from the main worktree is then refused with the docs-lint refusal;
      installed from the main worktree, the same push from a linked worktree is refused with it.
- [ ] The gate that runs is the pushing worktree's: with the wrapper installed, a push of a failing
      commit made with `git -C <linked worktree> push` from a subdirectory of the main worktree is
      refused with the docs-lint refusal when the linked worktree's tree has
      `scripts/hooks/pre-push-gate`, and the same push is allowed in silence, with the wrapper exiting
      0, when that tree has no such file.
- [ ] A checkout whose path contains a space: the install exits 0 and a push of a failing commit from
      it is refused with the docs-lint refusal.
- [ ] A foreign `pre-push` (one without the marker on its second line) is left byte-identical, the
      installer exits 3, and its output carries `LEFT ALONE`, `it is not ours` and the block for a
      hook of your own.
- [ ] A foreign `pre-push` to which a line ending in `# PR_QUEUE_WRAPPER` has been added by hand is
      still foreign: the installer leaves it byte-identical and exits 3.
- [ ] With `core.hooksPath` set to a relative path, the installer exits 1, writes no file, and its
      output carries `core.hooksPath is relative` and the `git config core.hooksPath` remedy with the
      absolute path.
- [ ] With `core.hooksPath` set to an absolute directory, the wrapper is written there and a push of a
      failing commit is refused with the docs-lint refusal.
- [ ] When the hooks directory cannot be written, the installer exits 1 and its output carries
      `could not be written`; outside a git checkout it exits 1 with `run this from inside the checkout`;
      given any argument it exits 2 and prints a line beginning
      `usage: sh scripts/hooks/install.sh`. In each of the three cases no file is created or changed.
- [ ] The write is a rename: when the installer replaces an existing wrapper whose content must
      change, the file's inode number differs afterwards, and the file names in the hooks directory
      are the same as before the run.
- [ ] `scripts/hooks/install.sh` contains no `trap` command, and `sh scripts/signal-test.sh` does not
      list it.

### FR-004: The wrapper composes with the PR queue, whichever installer ran first

#### Description:

The wrapper has one shape whichever installer wrote it: it runs the gate if the pushing worktree has
one, then the queue's hook if a queue is configured and still present. `scripts/pr-queue/install.sh`
writes that same shape from its own copy of the text (D5), so installing the gate over an existing
queue wrapper keeps the queue, installing the queue over a gate-only wrapper keeps the gate, the order
of installation does not matter, and each installer is idempotent. Both the gate and the queue's hook
read the pushed refs from standard input, so the wrapper reads the ref list once and gives each the
whole of it. Both always run, so a session sees every reason for a refusal in one attempt, and a push
refused by either is refused. The two overrides are independent: each skips its own check and nothing
else.

Both installers decide whose hook a file is by the rule in FR-003, and neither changes a queue it did
not set: the gate installer never alters the queue a wrapper names, and the queue installer still
refuses a wrapper that names a different queue. The gate installer reads the queue from each
generation of wrapper: the single-quoted `Q=` line, a bare `Q=` line, and the generation that named
its queue only on its `exec` line. The gate installer does not consult the queue's lock, because it
replaces only the wrapper, by rename, and a push already running keeps the file it started with.

**A hook of the user's own.** Both installers leave a foreign hook alone and print one fixed block
for a person to paste into it. The line the queue installer advises today cannot be extended: it ends
in `exec`, so nothing placed after it runs, and anything placed before it that reads standard input
leaves the queue's hook with no refs, at which point it enforces neither its lock nor its base check
and says nothing. The block therefore reads standard input once, gives the gate and the queue's hook
the whole ref list each, and fails the push when either refuses. It carries no marker, so the
identity rule never takes a hook carrying it for a wrapper. The advice printed with it says that it
goes before anything in that hook that reads standard input, that it consumes standard input and
leaves the pushed refs in `$sdd_refs`, that it replaces any line ending in `# PR_QUEUE_WRAPPER` that
an earlier installer advised, and when a block already in the hook is current.

**A block that names the wrong queue is said out loud.** The block's `sdd_q=` line is the only thing
that makes it run a queue's hook, so a block pasted with an empty queue, in a clone where a queue is
later installed, runs the gate and enforces no queue, and no push says so. Each installer therefore
looks at a foreign hook before it prints anything: the hook **carries the block** when one of its
lines is exactly the block's first line. For a hook that carries it, the installer reads the hook's
lines beginning `sdd_q=` and says one of two things, each with fixed text:

- The queue installer says the block **is current** when the hook has exactly one such line and it is
  `sdd_q='<its queue directory>'`, and otherwise that it **must be replaced whole** with the block
  printed below, naming the queue the hook's block names and its own.
- The gate installer has no queue of its own and never sets or clears one (it is the same rule as for
  a wrapper), so it says the block is current when the hook has exactly one such line, whatever queue
  it names, and that it must be replaced whole when the hook has none or several.

The block an installer prints carries the queue that installer stands for: the queue installer's own
directory; for the gate installer, the queue the hook's block already names, or an empty queue when
the hook carries no block or does not name exactly one. The exit status is 3 in every one of these cases, because the hook is still
not this template's and was left alone. This makes a stale block loud; it does not make it
impossible. Between a block being pasted with an empty or a different queue and a person replacing it,
this queue's lock and base check are not enforced through that hook, and the only thing that says so
is the next run of the queue installer.

`scripts/pr-queue/pre-push` is not changed in behaviour. Its header comment says the wrapper `exec`s
it, which stops being true, so comment lines in that file may be corrected and nothing else may.

#### Acceptance Criteria:

- [ ] Gate installer over the wrapper `scripts/pr-queue/install.sh` writes at commit `08643d9` (the
      one every existing clone holds: the marker on its second line, its single-quoted `Q=` line on
      its eleventh, an `exec` line and no `GATE=` line), reproduced in the test line for line as that
      installer's heredoc writes it: the result carries the same `Q=` value on its third line and the `GATE=` line on its fourth, the
      installer's output names that queue on a `queue:` line, and a push by a session that does not
      hold the lock is still refused with the queue's lock refusal.
- [ ] Gate installer over each of the two older queue wrapper generations (a bare `Q=` line, and a
      queue named only on the `exec` line), each with the marker on its second line: the result
      carries that queue on a single-quoted `Q=` line and the `GATE=` line.
- [ ] Queue installer over a gate-only wrapper: the result carries the queue on its `Q=` line and the
      `GATE=` line, and `scripts/pr-queue/install.sh` exits 0.
- [ ] Order does not matter: the wrapper after gate-then-queue, after queue-then-gate, and after the
      queue installer alone are byte-identical for the same queue directory, and running either
      installer again leaves it byte-identical.
- [ ] A wrapper naming a different queue is still refused by the queue installer (exit 3, its output
      carrying `DIFFERENT queue`, the file byte-identical), and the gate installer run over that same
      wrapper keeps the queue it names.
- [ ] The defect in D7 is closed: a foreign `pre-push` to which the previously advised line ending in
      `# PR_QUEUE_WRAPPER` was added by hand is left byte-identical by `scripts/pr-queue/install.sh`,
      which exits 3 with `LEFT ALONE` in its output.
- [ ] On a foreign hook, each installer's output carries the block for a hook of your own, verbatim
      but for the queue value, and the phrases `before anything in that hook that reads standard input`
      and `consumes standard input`.
- [ ] A foreign hook into which that block has been pasted, taken from the queue installer's own
      output and placed before the hook's own lines, refuses a push of a failing commit by the lock
      holder with the docs-lint refusal, and refuses a push of a passing commit by a session that does
      not hold the lock with the queue's lock refusal; a push of a passing commit by the lock holder
      is allowed, and the hook's own lines after the block then run.
- [ ] A foreign hook carrying the block is still foreign: each installer leaves it byte-identical and
      exits 3.
- [ ] A stale block is said out loud: over a foreign hook carrying the block with `sdd_q=''`, the
      queue installer exits 3, leaves the hook byte-identical, and its output carries
      `The block in that hook must be replaced whole with the block printed below.` and the block with
      the installer's queue on its `sdd_q=` line. The same text is printed for a block that names a
      different queue directory, and for a hook with two `sdd_q=` lines.
- [ ] Its mirror: over a foreign hook carrying the block with the queue installer's own queue on its
      one `sdd_q=` line, the queue installer exits 3 and its output carries
      `The block in that hook is current.` and does not carry `must be replaced`.
- [ ] The gate installer keeps the queue a block names: over a foreign hook carrying the block with a
      queue directory on its `sdd_q=` line, it exits 3, its output carries
      `The block in that hook is current.`, and the block it prints carries that same queue; over a
      foreign hook with no block it prints the block with `sdd_q=''`.
- [ ] With both installed, a push by the lock holder of a failing commit on a fresh base is refused;
      standard error carries the docs-lint refusal and does not carry `PR queue lock`.
- [ ] With both installed, a push of a passing commit by a session that does not hold the lock is
      refused with the queue's lock refusal, naming the refused branch (which shows the queue's hook
      received the ref list after the gate had read it), and standard error does not carry
      `docs-lint`.
- [ ] With both installed, a push of a failing commit by a session that does not hold the lock is
      refused, and standard error carries both the docs-lint refusal and the queue's lock refusal.
- [ ] With both installed, a push by the lock holder of a passing commit on a fresh base is allowed,
      and nothing is printed.
- [ ] `PR_QUEUE_BYPASS=1` does not skip the gate (a failing commit is still refused with the docs-lint
      refusal), and `DOCS_LINT_BYPASS=1` does not skip the queue (a push without the lock is still
      refused with the queue's lock refusal).
- [ ] With the queue directory deleted after both were installed, a failing commit is refused with the
      docs-lint refusal and a passing commit is allowed in silence.
- [ ] In a worktree whose tree has no `scripts/hooks/pre-push-gate`, with a queue installed, a push by
      a session that does not hold the lock is refused with the queue's lock refusal, a push by the
      holder is allowed, and the wrapper prints nothing of its own in either.
- [ ] With the queue's lock held, `sh scripts/hooks/install.sh` exits 0 and the wrapper keeps its
      queue.
- [ ] The diff of `scripts/pr-queue/pre-push` against commit `08643d9`, in the payload and at the
      root, changes only lines that begin with `#`, and no comment line in it still says the wrapper
      `execs` it.
- [ ] `sh scripts/pr-queue-test.sh` and `sh scripts/pr-queue/install-test.sh` exit 0, the sweep
      included, and no case name either runner reported at commit `08643d9` is missing from what it
      reports now.

### FR-005: A corpus for the gate, the wrapper and both installers, and the permission to run it

#### Description:

`scripts/hooks-test.sh` is the fixture corpus for the gate, the wrapper and both installers' handling
of it. It is run locally, like `scripts/pr-queue-test.sh`. It builds throwaway repositories under
`TMPDIR`, drives real pushes to real bare repositories through the installed wrapper, and asserts the
refusal text of every case rather than only the exit status; the silence cases assert that nothing
was printed. Every acceptance criterion of FR-001 to FR-004 that names a behaviour of a script is a
case in it. After the cases pass, a mutation sweep breaks one check at a time in a copy of the script
under test and re-runs the cases that check owns, expecting at least one to fail; a plant whose cases
all still pass is a check nothing tests, and it fails the run.

A sub-run that fails for a reason other than its case going red is the way a sweep goes vacuous, so
the sweep guards it by name: an edit that does not land, a mutant that does not parse, and a sub-run
that ends without reporting on the case it was asked for each fail the run.

`.claude/settings.json` gains two `permissions.allow` entries, for the corpus only, in the forms the
file already uses. The installer gets none (D6).

#### Acceptance Criteria:

- [ ] `sh scripts/hooks-test.sh` exits 0, printing one `ok` line per case and one per plant; with a
      failing case or plant it prints a `FAIL` line naming it and exits non-zero.
- [ ] Before any case runs, `scripts/hooks/pre-push-gate` and `scripts/hooks/install.sh` are each
      parsed with `sh -n`, and a script that does not parse stops the run with a `FAIL` line naming it.
- [ ] `sh scripts/hooks-test.sh <substring>` runs only the matching cases, and a substring that
      matches no case exits non-zero with text containing `matched no case`.
- [ ] An unfiltered run in which fewer cases ran than the `CASES_MIN` constant in the script exits
      non-zero with text containing `against a floor of` and the constant's value; `CASES_MIN` is two
      below the number of cases the script ships.
- [ ] The corpus never touches the checkout it is run from: the invoking repository's hooks directory
      and `git status --porcelain` are identical before and after a full run.
- [ ] The corpus writes nothing under the user's home: run with `HOME` pointing at an empty directory,
      a full run exits 0 and leaves that directory empty. (`scripts/pr-queue/install.sh` puts its
      queue under `$HOME/.claude/pr-queue/` whenever `PR_QUEUE_DIR` is unset, so a case that forgot to
      set it would write there.)
- [ ] The sweep plants at least these mutations, each naming the cases it must break: the bypass test;
      the `refs/heads/` filter (the tag exemption); the deletion exemption; the no-linter exemption;
      the refusal on linter exit 1; the refusal on any other non-zero exit; the refusal on a commit
      that cannot be read or exported; exporting the commit rather than the working tree; linting one
      commit once; the gate's final exit status; the wrapper giving the queue's hook the ref list; the
      wrapper's test for the gate's presence; the pasted block giving the queue's hook the ref list;
      the gate installer's foreign-hook rule; the queue installer's foreign-hook rule; the gate
      installer's relative `core.hooksPath` refusal; the gate installer keeping the queue a wrapper
      names (a mutant that writes `Q=''` over it); and the queue installer's comparison of a pasted
      block's `sdd_q=` line (a mutant that calls every block current).
- [ ] A plant whose edit does not change exactly one line, or whose mutant does not parse, fails the
      run rather than counting as a broken case.
- [ ] A plant counts as broken only when the case it names reports `FAIL` in the sub-run; a sub-run
      that exits non-zero without reporting on that case fails the run with a line beginning
      `FAIL  plant` and naming the plant.
- [ ] `sh scripts/signal-test.sh` exits 0 and prints
      `ok    scripts/hooks-test.sh exits 1 on every trapped signal`, and
      `sh scripts/signal-test.sh --self-test` exits 0.
- [ ] `.claude/settings.json` `permissions.allow` contains `Bash(sh scripts/hooks-test.sh *)` and
      `Bash(sh scripts/hooks-test.sh)`, contains no entry naming `scripts/hooks/install.sh`, and every
      entry it held at commit `08643d9` is still present.

### FR-006: Every statement of the old arrangement is brought into line, and a consumer can take the change

#### Description:

A reviewer checks an artifact against every other place the same rule is stated, so each site that
describes the old arrangement changes in the same change. docs-lint stays local and stays out of CI,
for the reason `completion-ritual.md` already gives; what changes is that it is mechanical through the
git hook in a clone where a person has installed the gate, and that the reviewer rule (every reviewer
runs the repository's gates against the branch) is what carries it in a clone where nobody has.

**The always-loaded edits, exactly.** `CLAUDE.md` and `docs/process/session-rhythm.md` are loaded by
every session and are held, with `docs/process/INDEX.md`, to `ALWAYS_LOADED_MAX_BYTES`. At commit
`08643d9` the set is 25,703 of 26,000 bytes, so 297 bytes are free. This spec makes two edits there
and no others, does not edit `INDEX.md`, and raises neither budget. Byte counts below are measured
against that commit, on the root copies, which the payload copies equal.

Edit 1, `CLAUDE.md`, *Common Commands*: one line is added after the `# pr-queue tests:` line. Net
change, 101 bytes.

```text
# push gate: sh scripts/hooks/install.sh (a person, once per clone); tests: sh scripts/hooks-test.sh
```

Edit 2, `docs/process/session-rhythm.md`, the bullet beginning "Before pushing, run the project's".
These five lines:

```text
  **`sh scripts/docs-lint.sh` is in that set and nothing in CI runs it** — plus
  `sh scripts/docs-lint-test.sh` or `sh scripts/spec-lint-test.sh` whenever that linter, the shared
  frontmatter reader or the index generator changed, and
  `sh scripts/pr-queue-test.sh` whenever the queue or its hook changed, and
  `sh scripts/pr-queue/install-test.sh` whenever its installer changed.
```

become these seven. Net change, 128 bytes (387 bytes become 515).

```text
  **`sh scripts/docs-lint.sh` is in that set and nothing in CI runs it** (the pre-push gate
  does, where `scripts/hooks/install.sh` was run) — plus
  `sh scripts/docs-lint-test.sh` or `sh scripts/spec-lint-test.sh` whenever that linter, the shared
  frontmatter reader or the index generator changed,
  `sh scripts/pr-queue-test.sh` whenever the queue or its hook changed, and
  `sh scripts/pr-queue/install-test.sh` and `sh scripts/hooks-test.sh` whenever an installer or
  anything under `scripts/hooks/` did.
```

The last line names the directory and not the gate, so that it stays true when SPEC-002 adds the
session-start report under `scripts/hooks/` and its cases to that corpus: SPEC-002 edits no
always-loaded file, and this sentence is what sends a session that changed the report to the corpus
that tests it.

The two edits come to 229 bytes, which takes the set to 25,932 of 26,000 and leaves 68 free;
`CLAUDE.md` alone goes from 8,567 to 8,668 of its 11,000. Both were applied to an export of commit
`08643d9`, and that commit's `scripts/docs-lint.sh` exits 0 over the result and prints those two
figures. Nothing moves down a tier, because the edits fit. The
`CLAUDE.md` *PRs & main* paragraph is deliberately not edited: its sentence that docs-lint is run
before every PR because nothing in CI runs it stays true, and the gate is named once in that file, in
*Common Commands*.

Sentences that still hold are left as they are, and are named here so a reviewer does not read them as
missed. Every site that tells a session or a reviewer to run `sh scripts/docs-lint.sh` before a push
keeps saying so (`.claude/agents/implementer.md`, `.claude/agents/reviewer.md`,
`docs/process/reviewer-contract.md`, `docs/templates/multi-agent-briefing.md`,
`.github/workflows/ci.yml.example`): the gate is installed per clone, and running the linter before
committing is still how a failure is found while it is cheap.

The upgrade path is for a repository scaffolded before this change. Its hooks are not versioned, so a
person installs the gate once in each clone.

#### Acceptance Criteria:

- [ ] The payload's `CLAUDE.md` carries the Edit 1 line, byte for byte, directly after its
      `# pr-queue tests:` line, and is otherwise identical to its content at the commit the build
      branches from: it is 101 bytes larger.
- [ ] The payload's `docs/process/session-rhythm.md` carries the seven Edit 2 lines, byte for byte, in
      place of the five, and is otherwise identical to its content at the commit the build branches
      from: it is 128 bytes larger.
- [ ] The payload's `docs/process/INDEX.md` is unchanged, `CLAUDE_MAX_BYTES` and `ALWAYS_LOADED_MAX_BYTES` in
      `scripts/docs-lint.sh` are the values they were at commit `08643d9`, and `sh scripts/docs-lint.sh`
      exits 0.
- [ ] `docs/process/completion-ritual.md`: the paragraph beginning "`scripts/docs-lint.sh` enforces the
      structural half" no longer contains `wants it mechanical as well as local`; still contains
      `deliberately not a CI job`; names `scripts/hooks/install.sh` as what a person runs to make the
      gate mechanical in a clone; and says the reviewer rule carries it where the gate is not
      installed.
- [ ] `scripts/pr-queue/PROTOCOL.md`: no longer contains `overrides everything` or
      `` `exec`-if-present ``; says the wrapper runs the docs-lint gate and then the queue's hook, each
      given the pushed refs; and names `DOCS_LINT_BYPASS=1` as the gate's own override, separate from
      `PR_QUEUE_BYPASS=1`.
- [ ] `docs/process/several-agents.md`: where it says the installer points a `pre-push` wrapper at the
      queue, it says the same wrapper runs the docs-lint gate.
- [ ] `.github/pull_request_template.md`: the verification checklist carries a line for
      `sh scripts/hooks-test.sh`, conditional on an installer or anything under `scripts/hooks/`
      having changed.
- [ ] `README.md`: the file table has a row for each of `scripts/hooks/pre-push-gate`,
      `scripts/hooks/install.sh` and `scripts/hooks-test.sh`; the `.claude/settings.json` row says the
      file omits `scripts/hooks/install.sh` as well as `scripts/pr-queue/install.sh`, for the reason it
      already gives (`run once, by a person`); the guardrail table has a row for the push gate that
      says it holds only in a clone where it was installed and that `git push --no-verify` skips it
      (the row contains `--no-verify`); and the setup text names
      `sh scripts/hooks/install.sh` as the one command a person runs to install the gate, and says
      what the installer does when a `pre-push` hook of the user's own is already there.
- [ ] `.claude/skills/spec-driven/SKILL.md`, scaffolding: the `chmod +x` list names
      `scripts/hooks/pre-push-gate`, `scripts/hooks/install.sh` and `scripts/hooks-test.sh`; the list
      of corpora to run names `sh scripts/hooks-test.sh`; and a step tells the user to run
      `sh scripts/hooks/install.sh` once per clone, and does not have Claude run it.
- [ ] `.claude/skills/spec-driven/SKILL.md`, upgrading: a paragraph beginning
      `**Updating a repo scaffolded before the pre-push gate**` gives a command that resolves the
      template commit or commits to apply (a `git log -S` lookup on a phrase this change introduces,
      as the paragraph for #27 does, since a commit cannot name its own SHA); says to merge the two
      permission entries into `.claude/settings.json` by hand; says to make the three new scripts
      executable; says a person runs `sh scripts/hooks/install.sh` once in every clone and that a
      clone with the PR queue installed keeps its queue; and gives the one `CLAUDE.md` line to bring
      up by hand.
- [ ] `scripts/sync-from-skill.sh` makes the three new scripts executable; in the payload and at the
      root each of the three has its executable bit set.
- [ ] After `sh scripts/sync-from-skill.sh`, `sh scripts/check-mirror.sh` exits 0, and `git ls-files`
      lists each of the three new scripts at both paths, in the payload and at the root.
      (`check-mirror.sh` reads tracked files, so it exits 0 over a new payload script whose root copy
      is on disk and was never added.)
- [ ] `git grep -n -e 'wants it mechanical as well as local' -e 'overrides everything'` returns no
      line outside the files under `docs/specs/` and `template-specs/`, where a spec may quote the
      phrase it retires. (Each phrase is on one line of its file at commit
      `08643d9`, in the payload and at the root, so the sweep can fail.)

---

## Data Model

The wrapper, written to the hooks directory's `pre-push` by either installer, each from its own copy
of this text (D5). The second, third and fourth lines are contract: the marker is the file's
identity, `Q=` names the queue (empty when none is installed), and `GATE=` is what tells a reader,
SPEC-002's report among them, that this generation runs the gate. The remaining lines are the
reference behaviour, and the acceptance criteria of FR-003 and FR-004 are what bind them. The value of
`Q` is single-quoted, as it is today, because a path with a space would otherwise parse as an
assignment and a command.

```sh
#!/bin/sh
# PR_QUEUE_WRAPPER — written by scripts/hooks/install.sh or scripts/pr-queue/install.sh.
Q='<absolute queue directory, or empty>'
GATE='scripts/hooks/pre-push-gate'
refs="$(cat)"
rc=0
top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$top" ] && [ -f "$top/$GATE" ]; then
  printf '%s\n' "$refs" | sh "$top/$GATE" "$@" || rc=1
fi
if [ -n "$Q" ] && [ -x "$Q/pre-push" ]; then
  printf '%s\n' "$refs" | "$Q/pre-push" "$@" || rc=1
fi
exit "$rc"
```

The gate is tested with `-f` and run with `sh`, not tested with `-x` and executed, so a tree that lost
the file's mode bit still runs it. A repository with no working tree has no gate copy to run. The
queue's hook keeps its `-x` test, which is what lets a push through once the queue directory is gone.
On an up-to-date push git gives the hook no line, and the wrapper then hands each reader one blank
line; both readers treat it as nothing to check.

The permission entries added to `.claude/settings.json` (the existing entries are kept and are elided
here):

```json
{
  "permissions": {
    "allow": [
      "Bash(sh scripts/hooks-test.sh *)",
      "Bash(sh scripts/hooks-test.sh)"
    ]
  }
}
```

---

## API / Interface Contract

```text
scripts/hooks/pre-push-gate <remote name> <remote url>
  stdin   "<local ref> <local sha> <remote ref> <remote sha>" lines, as git gives a pre-push hook
  env     DOCS_LINT_BYPASS=1 skips the check; TMPDIR is honoured for the exported tree
  stdout  nothing, ever
  stderr  nothing when the push may proceed without the override
  exit    0 the push may proceed · 1 the push is refused, or the gate was stopped by a signal

sh scripts/hooks/install.sh                      (no arguments; run by a person)
  exit    0 the wrapper is in place: written, upgraded, or already current
          1 could not install, nothing changed: not inside a checkout, core.hooksPath is
            relative, or the hooks directory could not be written
          2 usage: an argument was given; prints "usage: sh scripts/hooks/install.sh"
          3 a pre-push that is not this template's wrapper occupies the path; left alone
  stdout  on 0:  Pre-push gate installed.
                   hook:   <absolute path of the wrapper>
                   gate:   scripts/hooks/pre-push-gate, run from the worktree a push is made from
                   queue:  <the queue directory the wrapper names> | none

sh scripts/pr-queue/install.sh [branch-regex]    (usage and exit statuses unchanged: 0, 1, 3)
  now writes the wrapper above from its own copy of the text, and decides whose hook a file is
  by the second-line marker

sh scripts/hooks-test.sh [case-name-substring]
  exit    0 every case and every plant passed · non-zero otherwise, including a filter that
          matched no case ("matched no case"), a run under the floor ("against a floor of
          <CASES_MIN>"), a plant that did not bite ("FAIL  plant <name>"), and a signal
```

**Refusal text.** Each block is written to standard error, one block for each distinct commit
refused, and the gate then exits 1. `<branch>` is the remote ref without its `refs/heads/` prefix and
`<short sha>` is the commit's object name as `git rev-parse --short` abbreviates it (for an object the
repository does not have, the first seven characters of the name on the line). The linter's output is
its standard output and standard error together, each line indented.

```text

  PUSH REFUSED — docs-lint failed on the commit being pushed.

  Refused ref(s): <branch>[, <branch> ...] at <short sha>

    <every line scripts/docs-lint.sh printed>

  docs-lint ran on the tracked files of that commit, not on your working tree, so a fix that
  is not committed does not count: commit it, then push again.
  Emergency override: DOCS_LINT_BYPASS=1 git push ...

```

```text

  PUSH REFUSED — docs-lint could not run on the commit being pushed (it exited <status>).

  Unchecked ref(s): <branch>[, <branch> ...] at <short sha>

    <every line scripts/docs-lint.sh printed>

  A check that could not run is not evidence that it passed.
  Emergency override: DOCS_LINT_BYPASS=1 git push ...

```

```text

  PUSH REFUSED — the commit being pushed could not be exported for linting.

  Unchecked ref(s): <branch>[, <branch> ...] at <short sha>

    <what git or the export printed>

  A check that could not run is not evidence that it passed.
  Emergency override: DOCS_LINT_BYPASS=1 git push ...

```

The override's one line, on standard error: `pre-push: DOCS_LINT_BYPASS=1 — docs-lint check skipped`.

**The block for a hook of your own.** Both installers print it, verbatim but for the queue value,
when a foreign `pre-push` occupies the path. A hook carries the block when one of its lines is exactly
the block's first line. It was run as written in a throwaway repository, in a
foreign hook, against the queue's real hook, with a queue path containing a space: it refused a
failing commit, refused a session without the lock, printed both refusals when both applied, and let
the hook's own lines run after an allowed push.

```sh
# --- docs-lint gate and PR queue: pasted by hand from the installer's advice ---
sdd_refs="$(cat)"
sdd_rc=0
sdd_top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$sdd_top" ] && [ -f "$sdd_top/scripts/hooks/pre-push-gate" ]; then
  printf '%s\n' "$sdd_refs" | sh "$sdd_top/scripts/hooks/pre-push-gate" "$@" || sdd_rc=1
fi
sdd_q='<absolute queue directory, or empty>'
if [ -n "$sdd_q" ] && [ -x "$sdd_q/pre-push" ]; then
  printf '%s\n' "$sdd_refs" | "$sdd_q/pre-push" "$@" || sdd_rc=1
fi
[ "$sdd_rc" -eq 0 ] || exit 1
# --- end of the pasted block; the pushed refs are in $sdd_refs ---
```

The advice printed with it, each sentence identified by the quoted text:

```text
  Paste the block below into that hook, before anything in that hook that reads standard input.
  It consumes standard input: the pushed refs are in $sdd_refs afterwards, for anything in the
  hook that needs them.
  It replaces any line ending in "# PR_QUEUE_WRAPPER" that an earlier installer advised.
  A hook that already carries this block is current only if its sdd_q= line is the one printed
  below; otherwise replace the whole block.
```

What an installer says about a block already in the hook, before the advice, each line identified by
the quoted text. The comparison was run as written in a throwaway directory against hooks carrying no
block, a block with an empty queue, the installer's own queue (a path with a space), another queue,
and two `sdd_q=` lines, and gave the answers FR-004 states for each installer.

```text
  The block in that hook is current.
  The block in that hook must be replaced whole with the block printed below.
      It names: <the queue on the hook's sdd_q= line, or "no queue", or "more than one queue">
      This installer's queue: <the queue directory>
```

The two indented lines follow the second text. The gate installer has no queue of its own and prints
only the first of them.

**The installer's refusals**, each identified by the quoted text: a foreign hook, `LEFT ALONE` and
`it is not ours`, followed by what it says about a block already there, the advice and the block; a relative hooks path,
`core.hooksPath is relative`, with the `git config core.hooksPath "<absolute path>"` remedy; an
unwritable hooks directory, `could not be written`; outside a checkout,
`run this from inside the checkout`.

## Configuration / Environment

- `DOCS_LINT_BYPASS=1`: read by `scripts/hooks/pre-push-gate`. Skips the docs-lint check for one push
  and prints one line saying so. Only the value `1` does this.
- `PR_QUEUE_BYPASS=1`: unchanged. It skips the queue's hook and does not skip the gate.
- `TMPDIR`: honoured by the gate for the exported tree and by `scripts/hooks-test.sh` for its
  throwaway repositories, as the existing scripts honour it.
- `CASES_MIN` in `scripts/hooks-test.sh`: a constant, with its reasoning in a comment beside it.

## File & Folder Structure

Paths are in the payload, `.claude/skills/spec-driven/template/`; the repository root mirrors every
one of them, regenerated by `sh scripts/sync-from-skill.sh` and held by `sh scripts/check-mirror.sh`.

```text
.claude/skills/spec-driven/template/
├── .claude/
│   └── settings.json                    edited: two permission entries for the corpus
├── .github/
│   └── pull_request_template.md         edited
├── CLAUDE.md                            edited: one line (FR-006, Edit 1)
├── docs/
│   └── process/
│       ├── completion-ritual.md         edited
│       ├── session-rhythm.md            edited: one bullet (FR-006, Edit 2)
│       └── several-agents.md            edited
└── scripts/
    ├── hooks-test.sh                    new
    ├── hooks/
    │   ├── install.sh                   new
    │   └── pre-push-gate                new
    └── pr-queue/
        ├── install.sh                   edited: its own copy of the wrapper, second-line identity, the block
        ├── install-test.sh              edited: cases for the new wrapper shape and the foreign hook
        ├── pre-push                     edited: comment lines only
        └── PROTOCOL.md                  edited
```

Outside the payload, and so not mirrored:

```text
.claude/skills/spec-driven/SKILL.md      edited: scaffolding steps, the upgrade paragraph
README.md                                edited
scripts/sync-from-skill.sh               edited: makes the three new scripts executable
```

## Implementation Phases

The order puts each inert piece before the thing that makes it live: the gate and its corpus exist
before anything can install them, and the installers before the prose that tells people to run one.
Every phase edits the payload, runs `sh scripts/sync-from-skill.sh`, and leaves these green:
`sh scripts/check-mirror.sh`, `sh scripts/docs-lint.sh`, `sh scripts/signal-test.sh --self-test`,
`sh scripts/signal-test.sh`, and the corpora it touched.

### Phase 1: The gate and the start of its corpus

- Write `scripts/hooks/pre-push-gate` to FR-001 and FR-002, with the two trap lines first, and the
  three refusal blocks and the override line as the Interface Contract gives them.
- Start `scripts/hooks-test.sh`: the two trap lines, the parse guard, the throwaway-repository
  builders, the filter guard, and every FR-001 and FR-002 case, driven through a hand-placed one-line
  hook until the installer exists.
- Add the sweep with the plants that belong to the gate, and its three guards.
- Add each new script to the `chmod` list in `scripts/sync-from-skill.sh` in the commit that creates
  it, never before: that script runs under `set -eu` and stops at a file that does not exist.
- Add the two permission entries to `.claude/settings.json`.

### Phase 2: The installers, the one wrapper and the block

- Write `scripts/hooks/install.sh` to FR-003, with no trap, and add it to the `chmod` list.
- Change `scripts/pr-queue/install.sh` to write the same wrapper from its own heredoc, to decide whose
  hook a file is by the second-line marker, and to print the block, its advice and its verdict on a
  block already there for a foreign hook, keeping its exit statuses and every other behaviour.
- Correct the comment in `scripts/pr-queue/pre-push`, and the two sentences in
  `scripts/pr-queue/PROTOCOL.md` that this phase makes false (`overrides everything` and the
  `exec`-if-present description): the installer copies that file into the queue directory, so it
  changes with the installer and not later.
- Move the Phase 1 cases onto the installed wrapper, add the FR-003 and FR-004 cases and their plants,
  and set `CASES_MIN`.
- Update `scripts/pr-queue/install-test.sh` for the new wrapper shape, the hand-patched foreign hook
  and the block; run it and `sh scripts/pr-queue-test.sh`, sweep included, and compare both runners'
  case names against commit `08643d9`.

### Phase 3: The prose and the upgrade path

- Make the two always-loaded edits exactly as FR-006 gives them, and confirm the byte counts.
- Bring the remaining sites FR-006 names into line: `completion-ritual.md`, `several-agents.md`, the
  rest of `PROTOCOL.md`, the PR template, `README.md`.
- Write the scaffolding changes and the upgrade paragraph in `SKILL.md`.
- Run the closing sweep (the `git grep` in FR-006), then every gate: `spec-lint.sh`, `docs-lint.sh`,
  `docs-lint-test.sh`, `spec-lint-test.sh`, `pr-queue-test.sh`, `pr-queue/install-test.sh`,
  `hooks-test.sh`, `check-mirror.sh`, `signal-test.sh --self-test` and `signal-test.sh`.
