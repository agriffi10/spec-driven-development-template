---
type: Spec
id: SPEC-002
title: "Session-start report"
description: "A Claude Code session-start hook that states whether the docs-lint push gate is installed in this clone and which specs are In Progress across the repository's worktrees, for every session working in a scaffolded repository."
spec_status: Draft
depends_on: [SPEC-001]
arc: mechanical-gates
arc_order: 2
---

## Overview

Two facts about a repository decide how a session should begin, and today a session can see neither.
The first is whether the push gate is installed in the clone it is working in: the gate is installed
per clone, by a person, so a fresh clone has none and nothing says so. The second is what is being
built: which spec is `In Progress` is written on that spec's build branch, nothing forces the
transition, and a session cannot see from its own tree what a peer's worktree has in flight, so two
sessions can each believe they are alone. This spec has every session begin by being told both, as
plain statements of fact: the state of the gate in this clone, and each spec that is in progress with
the branches that carry it. It reports and does not judge or block. It is for the agent sessions that
work in a repository scaffolded from this template, and through them for the people who run several
at once.

## Scope

### In Scope

- A Claude Code `SessionStart` hook, `scripts/hooks/session-start.sh`, that reports the state of the
  push gate in this clone and each spec that is `In Progress` in any worktree, one line per spec.
- Its registration in the project's `.claude/settings.json`, and a docs-lint check that holds the
  registration and the script to each other.
- The report's cases and plants, added to the corpus SPEC-001 creates.
- The prose that says the report exists, and the skill's steps for scaffolding and upgrading.

### Out of Scope

- **The push gate, its wrapper and its installers.** SPEC-001, the first spec in this arc, delivers
  `scripts/hooks/pre-push-gate`, `scripts/hooks/install.sh`, the wrapper both installers write, and
  `scripts/hooks-test.sh`. This spec reads the wrapper and never writes it, and installs nothing.
- **Any hook shipped inside the plugin.** A plugin hook fires in every project where the plugin is
  enabled, including repositories that are not spec-driven (*Settled Design*, D1).
- **Reporting whether `main`'s CI is green at session start.** It needs a network call on every
  session start, resume, clear and compaction.
- **Injecting anything into subagents (`SubagentStart`).** Every subagent would pay the report's
  bytes, on every delegation.
- **Specs that are `In Progress` on a branch not checked out in any worktree.** The report reads
  working trees; a branch with no worktree would have to be read out of the object store for every
  branch on every session start.
- **Telling a current status from a stale one.** A worktree left at an old commit reports the status
  that commit carries, with nothing to mark it stale, and a spec that `main` carries as `In Progress`
  is carried by every worktree cut from `main` since. The report names where a status was read; it
  does not date it. That is a known limit of reading working trees, repeated beside the byte cap.
- **Checking a cleanly `Draft` or `Completed` spec for readability.** A spec whose frontmatter carries
  exactly one `spec_status` line, saying `Draft` or `Completed`, is set aside before the shared reader
  runs (D7), so the report never calls it unread, whatever else its frontmatter holds. spec-lint owns
  frontmatter validity and runs in CI; this report owns only what is in progress.
- **A record of how far a build in flight has got** (the phase reached, the reviews answered). That is
  a separate piece of work with its own design.
- **Naming the command that installs the gate where it cannot succeed.** In a clone with a `pre-push`
  hook this template did not write, or a relative `core.hooksPath`, the installer refuses, so the
  report states the condition and does not name the command (FR-001).
- **Any edit to the always-loaded tier.** `CLAUDE.md`, `docs/process/INDEX.md` and
  `docs/process/session-rhythm.md` are not edited by this spec.
- **Any new permission entry.** A hook is run by the harness, not by a tool call.
- **A scaffold that is not at the repository's top level.** The report looks for `docs/specs` under
  each worktree's root, as the linters already assume.
- **The template repository's own specs.** They live in the root-only `template-specs/` directory,
  which no scaffolded project has. The report reads `docs/specs`, so in the template repository it
  does not list this spec or its neighbours, and reading a second directory would ship a path that
  exists in one repository to every project scaffolded from it.
- **Worktree paths or branch names that contain a newline.** The report reads `git worktree list` one
  line at a time, as `scripts/check-mirror.sh` reads `git ls-files`.
- **A path-scoped rule under `.claude/rules/` for `scripts/hooks/`.** A rule is a backstop that points
  a reader at a process part; one can be added later without touching anything this spec builds.
- **Windows without a POSIX shell.** The script is POSIX `sh`, as the existing scripts are.

---

## Settled Design

These decisions are settled and are recorded here, with their reasons, so a builder does not
re-derive them and a reviewer can check the spec against its authority. The vendor facts were read
from the live Claude Code hooks reference and its worktrees page.

**D1. The hook is registered in the project's `.claude/settings.json`, not shipped as a plugin hook.**
A plugin's `hooks/hooks.json` would fire in every project where the plugin is enabled; the plugin is
deliberately rooted at the skill folder so that it ships the skill and nothing else; and the script
the hook runs is versioned with the repository. `.claude/settings.json` is part of the mirrored
scaffold, so a scaffolded project receives the hook.

**D2. The hook reports on the repository, not on one working tree.** `${CLAUDE_PROJECT_DIR}` is the
project root where the session started. In a worktree session started from the desktop app, project
hooks are read from the main checkout's root and run there, and the worktree's path is available only
in the `cwd` field of the hook's JSON input. A report of repository-wide facts is the same wherever
it runs, so the hook needs nothing from its input and parses no JSON. It lists and does not judge:
several specs in progress is legitimate in a deliberate multi-agent run
(`docs/process/several-agents.md`).

**D3. The hook is silent where it does not apply, and written as facts.** `SessionStart` fires
with source `startup`, `resume`, `clear`, `compact` or `fork`, and an omitted matcher matches all of
them; firing on `compact` is wanted, because it restates the facts after a compaction. Only `command`
and `mcp_tool` hooks are supported on the event. Plain-text standard output from a hook that exits 0
is added to Claude's context, and output that does not begin with `{` is always read as plain text.
The hook cannot block a session: a non-zero exit only renders an error notice the model does not
see, and a hook cancelled at its timeout has its output discarded. The vendor advises writing injected
context as factual statements, because text framed as out-of-band commands can trigger
prompt-injection defences. Context over 10,000 characters is replaced by a file path and a
2,000-character preview. In an interactive session, hooks in settings files run only after the
workspace trust dialog is accepted; under `claude -p` they run without it.

**D4. One line per spec, with branch names and no paths.** A report with one line for each spec in
each worktree repeats itself: `main` carries a spec as `In Progress` between a multi-PR spec's first
merge and its completion, so every worktree cut from `main` in that time carries it too, and a
handful of worktrees fill the report with one fact. Worktree paths are long (a scratch worktree's
path runs well past a hundred bytes) and tell a session less than the branch does. So the report
groups by spec file: one line names the branches whose worktrees carry it and counts the detached
worktrees that do. It groups by the file's name and not by its number, because two different specs
can share a number on two branches until one is renumbered, and one line for both would read exactly
like one spec carried by two branches.

**D5. Four states of the gate, and the install command named in only one.** The gate is installed by
a person, once per clone (SPEC-001 records that decision), so the report states that as a fact and
does not instruct the session to run anything. In a clone where the installer would refuse, a line
naming the command would hand every session, at every start, a command that fails; those clones get
a line that states the condition instead.

**D6. Exec form for the registration.** The hook is registered with an `args` list, which the vendor
prefers for any hook that references a path placeholder: the path reaches `sh` as one argument
whatever characters the project directory's name holds.

**D7. The cost follows the work in flight, not the size of the repository.** Claude's first response
waits for a `SessionStart` hook, on every start, resume, clear and compaction. In a repository that
has been used for a while nearly every spec file is `Completed`, and every worktree holds all of them,
so a hook that ran the shared reader once for each spec file would cost in proportion to the total
number of specs multiplied by the number of worktrees. So in each worktree one process looks at the
frontmatter block of every spec file and sets aside the files that are cleanly `Draft` or `Completed`
(FR-001 says exactly when), and the shared reader runs only on the rest. The cost then grows with the
number of worktrees and with the number of specs that are not cleanly `Draft` or `Completed`, and not
with the total number of specs.

`scripts/frontmatter.awk` says in its header that it is the one frontmatter reader every script
shares, because two readers are two grammars that drift apart. The pre-filter is allowed beside that
rule because it decides nothing: it never says that a spec is in progress or what any key holds, it
only narrows which files the one reader is asked about, and every file it does not recognise goes to
the reader. For a file it sets aside, the frontmatter block, delimited as the reader delimits it,
holds exactly one line that mentions `spec_status`, and that line says `Draft` or `Completed`; the
reader could return that value or an error for such a file, and never `In Progress`. So the pre-filter
can cost time and cannot give a wrong answer about a spec in progress. What it does cost is stated in
*Out of Scope*: a cleanly `Draft` or `Completed` spec is not checked for readability here. The
pre-filter was run in a throwaway directory beside the real reader over fifteen shapes of file, the
four FR-001 names among them: the reader read every file it set aside as `Draft` or `Completed`, or
refused it, and with a recording `awk` first on `PATH` the same four `awk` processes started (the
pre-filter once, and the reader once for each of three files that were not cleanly `Draft` or
`Completed`) for a worktree holding five `Completed` specs beside them as for one holding three
hundred.

**Technical constraints.**

- The script is POSIX `sh` with no dependency beyond git and the standard utilities the existing
  scripts already use, and no JSON parser. It makes no network call.
- **It creates no file and sets no trap.** `scripts/signal-test.sh` holds every script under
  `scripts/` that traps a signal to exit non-zero on it, and this hook must exit 0 whenever it
  finishes; a script with no scratch needs no trap, and so falls outside that rule. Everything it
  reads is held in shell variables and pipes.
- This spec adds no process part and no router row. Every scaffold file is edited in the payload,
  `.claude/skills/spec-driven/template/`, and the root is regenerated with
  `sh scripts/sync-from-skill.sh`.

---

## Functional Requirements

### FR-001: The report states the gate's state in this clone and each spec in progress

#### Description:

`scripts/hooks/session-start.sh` finds its repository from its own location, reads nothing from
standard input, and prints a report built only from the line templates under *Data Model*, each a
declarative statement of fact.

**The gate line.** SPEC-001 FR-003 defines the wrapper this line is about, and the one thing this spec
needs from it is restated here. The hooks directory is the absolute `core.hooksPath` when one is
configured, otherwise the `hooks` directory of the common git directory. A `pre-push` file there is
this template's wrapper when its second line begins with `# PR_QUEUE_WRAPPER`, and a wrapper runs the
gate when it has a line beginning `GATE=`. The report puts the clone in exactly one of four states,
tested in this order:

1. **Relative hooks path.** `core.hooksPath` is configured and is not absolute. A hook there does not
   run in linked worktrees, and the installer refuses it.
2. **Foreign hook.** The hooks directory's `pre-push` exists and is not this template's wrapper. The
   installer leaves it alone. This is the state of a hook carrying the block SPEC-001 FR-004 gives
   for pasting: the gate runs there, and the wrapper is still not installed.
3. **Installed.** The file is this template's wrapper, is a regular executable file, and has a line
   beginning `GATE=`.
4. **Not installed.** Everything else: no `pre-push` at all, or a wrapper of ours that has lost its
   executable bit or belongs to a generation with no `GATE=` line. In each of these the installer
   succeeds (SPEC-001 FR-003 and FR-004), so this is the one state whose line names it.

The gate line is printed when the hook's own tree has `scripts/hooks/pre-push-gate`.

**The spec lines.** The worktrees are those `git worktree list --porcelain` names (the form that
survives a path with a space) whose directory exists and which have a `docs/specs` directory. In each,
the population is every `SPEC-*.md` directly in that directory, and each file is classified in two
steps.

*The pre-filter.* One process for the worktree, not one for each file, considers only the frontmatter
block of each file and sets the file aside when all four of these hold: its first line is `---`; a
later line that is exactly `---` closes the block; exactly one line of the block contains the text
`spec_status`; and that line is exactly `spec_status: Draft` or `spec_status: Completed`. One trailing
carriage return on a line is ignored, as the shared reader ignores it. A file set aside is cleanly
`Draft` or `Completed`: it is not in progress, it is on no line, and nothing else reads it.

*The reader.* Every file not set aside is read once with the shared reader, `scripts/frontmatter.awk`
(one directory above the hook), under its caller contract: the reader's exit status and exactly one
`F` record. Such a spec is **in progress** in that worktree when the reader returns `F ok` and a
`spec_status` that is exactly `In Progress`. It is **unread** there when the reader exits non-zero,
returns anything but exactly one `F` record, returns `F err`, or returns no scalar `spec_status`. A
spec the reader reads with any other status is on no line. An unread spec is reported and never
dropped: a reader that skips what it cannot read reports a spec it never read as one that is not in
progress. The one narrowing is the pre-filter's, and it is deliberate: a file set aside is never
reported unread, whatever else its frontmatter holds, because spec-lint owns frontmatter validity and
runs in CI (D7).

A spec is named by its file's **stem**, the file name without `.md`. The report has one line for each
stem that is in progress anywhere, naming the branches whose worktrees carry it so and counting the
detached worktrees that do, and one line for each stem that is unread anywhere, in the same shape. Two
files that share a number are two stems and two lines. Where no branch carries a stem, only detached
worktrees, the line says `no branch`, which no branch can be called, because a branch name cannot
contain a space. Worktree paths are not printed. The spec lines are printed when at least one listed
worktree has `docs/specs`.

**Behaviour.** When neither the gate line nor the spec lines apply, and when the script is not inside
a git repository, the hook prints nothing at all. It exits 0 whenever it finishes and writes nothing
to standard error, because a non-zero exit shows the user an error and tells the model nothing. Its
output is held to a byte cap, because it is a fixed cost on every session exactly as the
always-loaded tier is; when there is more to say than the cap allows it prints the lines that fit and
ends with one line giving the number left out.

#### Acceptance Criteria:

- [ ] Not installed, one spec in progress: in a clone with no `pre-push` hook, where a linked worktree
      on a branch holds one `In Progress` spec and the main worktree holds only `Draft` specs, the
      output is exactly the header, the not-installed line, and one in-progress line carrying that
      spec's stem, that branch's name and a detached count of 0 (worked example 1, with the fixture's
      names).
- [ ] Installed, none in progress: after SPEC-001's `sh scripts/hooks/install.sh` exits 0, with only
      `Draft` and `Completed` specs in every worktree, the output is exactly the header, the installed
      line naming the wrapper's absolute path, and `No spec is In Progress in any worktree.` (worked
      example 2).
- [ ] An unread spec: a `SPEC-*.md` with no frontmatter, one whose frontmatter has no `spec_status`,
      and one whose frontmatter says `spec_status: In Progress` beside a line the reader refuses are
      each reported on an unread line carrying their stem and their worktree's branch, and with no
      spec in progress the summary line is
      `No spec that could be read is In Progress in any worktree.` (worked example 3).
- [ ] When the reader is replaced by a file that does not parse, the hook exits 0, every spec that is
      not cleanly `Draft` or `Completed` is reported on an unread line, and no cleanly `Draft` or
      `Completed` spec is on any line.
- [ ] Only the frontmatter block counts: a spec whose frontmatter says `spec_status: In Progress` and
      whose body carries a line reading `spec_status: Completed` is reported on an in-progress line;
      and a spec whose frontmatter has no `spec_status` and whose body carries that line is reported
      on an unread line.
- [ ] The block starts on the first line: a file whose first line is a heading, followed by a complete
      `---` block that carries `spec_status: Completed`, is reported on an unread line.
- [ ] Exactly one status line: a spec whose frontmatter carries `spec_status: Completed` and, on a
      later line, `spec_status: In Progress` is reported on an unread line (the reader refuses the
      duplicate key), and is not set aside.
- [ ] A file with CRLF line endings whose frontmatter says `In Progress` is reported on an in-progress
      line, and one that is cleanly `Completed` is on no line.
- [ ] A file whose first line is `---`, which carries `spec_status: Completed`, and which has no
      closing `---` line is reported on an unread line.
- [ ] The narrowing holds as stated: a spec whose frontmatter carries exactly one `spec_status` line,
      `spec_status: Completed`, beside a line the reader refuses is on no line.
- [ ] The cost does not grow with the number of specs: with `PATH` holding only a directory of
      recording shims for the commands the hook runs (so a command with no shim fails and the output
      differs), the number of processes recorded is the same for a fixture whose worktrees each hold
      five cleanly `Completed` specs and for the same fixture with three hundred in each; the shared
      reader is recorded exactly once for each spec file that is not cleanly `Draft` or `Completed`
      and not at all for any that is; and the output is byte-identical to the output without the
      shims.
- [ ] One line per spec file: with the same file `In Progress` in three worktrees, two on branches and
      one on a detached `HEAD`, the output has exactly one line for that stem, naming both branches in
      C-locale order and a detached count of 1.
- [ ] Two files that share a number, each `In Progress` on its own branch, are two lines, each carrying
      its own stem and its one branch.
- [ ] A spec `In Progress` only in a detached worktree is reported with `no branch` for its branches
      and a detached count of 1; a spec `In Progress` on a branch that is named `none` is reported
      with `none`.
- [ ] A worktree that `git worktree list` still names but whose directory has been removed is skipped:
      its branch is named on no line, and the other worktrees are reported.
- [ ] A spec `In Progress` in a worktree whose path contains a space is reported with that worktree's
      branch.
- [ ] No in-progress line and no unread line of any output above contains the path of any listed
      worktree.
- [ ] A spec whose `spec_status` is `in progress`, `Draft` or `Completed` is on no line.
- [ ] The installed line is printed after SPEC-001's gate installer exits 0, and after
      `sh scripts/pr-queue/install.sh` alone exits 0.
- [ ] The not-installed line, which carries `sh scripts/hooks/install.sh`, is printed with no
      `pre-push` in the hooks directory, with a wrapper of ours whose executable bit was removed, and
      with a wrapper of the previous generation (the marker on its second line, a `Q=` line and no
      `GATE=` line).
- [ ] The foreign-hook line is printed, naming the hook's absolute path, for a `pre-push` this
      template did not write and for one that carries the pasted block; the relative-path line is
      printed, naming the configured value, with `core.hooksPath` set to a relative path. Neither line
      contains `scripts/hooks/install.sh`.
- [ ] Run from a linked worktree's copy of the script, the output is byte-identical to the output
      from the main worktree's copy.
- [ ] A copy of the script and the reader placed, in the same relative layout, in a directory that is
      not inside a git repository prints nothing and exits 0, whatever directory it is run from; and
      in a repository with no `docs/specs` in any worktree and no `scripts/hooks/pre-push-gate`, the
      hook prints nothing and exits 0.
- [ ] The hook exits 0 and writes nothing to standard error in every case above.
- [ ] The first line of any non-empty output is the header, and every line matches one of the line
      templates.
- [ ] Standard input is not read: with standard input connected to a pipe that is never written to
      and never closed, the hook finishes, and its output is byte-identical to its output with
      standard input closed.
- [ ] No network call is made: with a `git` placed first on `PATH` that records its arguments and
      then runs the real one, a run records no `fetch`, `pull`, `push`, `ls-remote`, `remote` or
      `clone` subcommand.
- [ ] The cap: with enough distinct specs in progress that the full report would exceed
      `REPORT_MAX_BYTES`, the output is at most that many bytes, begins with the header and the gate
      line, ends with the left-out line whose number equals the lines the full report would have had
      minus the lines printed before it, and printing one more line would have exceeded the cap. With
      a report that fits, no left-out line is printed.
- [ ] The script creates no file and sets no trap: after a run with `TMPDIR` pointing at an empty
      directory that directory is still empty, the script contains no `trap` command, and
      `sh scripts/signal-test.sh` does not list it.

### FR-002: The hook is registered, and docs-lint holds the registration and the script to each other

#### Description:

The hook is registered in `.claude/settings.json` as a `SessionStart` command hook, with no matcher
and a timeout, exactly as under *Data Model*.

`scripts/docs-lint.sh` gains one check, numbered after the existing ones, that holds the registration
in both directions: a tree that has `scripts/hooks/session-start.sh` must register it, and a tree
that registers it must have it. The check does not parse JSON. It looks for the key `"SessionStart"`
and for a JSON string exactly equal to `"${CLAUDE_PROJECT_DIR}/scripts/hooks/session-start.sh"`,
quotes included, so a mention of the path in a permission entry does not satisfy it. Its known limits,
stated so nobody takes it for more: it cannot tell that the string sits inside the `SessionStart`
entry, nor an `args` element from a `command` that is exactly that string. A tree with neither the
script nor the registration is silent, which is every repository that has not taken this change and
every existing fixture.

#### Acceptance Criteria:

- [ ] `.claude/settings.json` registers the hook exactly as under *Data Model*: under
      `hooks.SessionStart`, with no `matcher`, `"type": "command"`, `"command": "sh"`, one `args`
      element `${CLAUDE_PROJECT_DIR}/scripts/hooks/session-start.sh`, and `"timeout": 30`; and every
      `permissions.allow` entry the file held at the commit the build branches from is still present,
      with none added.
- [ ] The check fails a tree that has `scripts/hooks/session-start.sh` and a `.claude/settings.json`
      without the registration, with text containing
      `does not register scripts/hooks/session-start.sh`, and names the exec form it expects.
- [ ] The same failure is printed when `.claude/settings.json` is missing, when the path appears only
      inside a `permissions.allow` entry, and when the hook is registered in shell form with the path
      inside a longer `command` string (`sh \"${CLAUDE_PROJECT_DIR}\"/scripts/hooks/session-start.sh`).
- [ ] The check fails a tree whose `.claude/settings.json` carries the registration but which has no
      `scripts/hooks/session-start.sh`, with text containing `but that script does not exist`.
- [ ] The check is silent for a tree with the script and the registration, and for a tree with
      neither.
- [ ] Each of the seven conditions in the four criteria above is a case under `tests/docs-lint/`
      asserting that text or that silence, the new check's terminating conditions are listed in the
      linter's header beside the existing ones, and `CASES_MIN` in `scripts/docs-lint-test.sh` equals
      the number of `tests/docs-lint/*.case` files minus two.
- [ ] `sh scripts/docs-lint-test.sh` and `sh scripts/docs-lint.sh` exit 0, and no case name the
      docs-lint runner reported at commit `08643d9` is missing from what it reports now.

### FR-003: The report's cases and plants join the hooks corpus

#### Description:

`scripts/hooks-test.sh`, which SPEC-001 FR-005 creates with its guards, its floor and its mutation
sweep, gains the report's cases: every acceptance criterion of FR-001 is a case that asserts the
report's text, line for line, and the silence cases assert that nothing was printed. The sweep gains
the plants that belong to the report. The existing guards apply to the new plants unchanged: an edit
that does not land, a mutant that does not parse, and a sub-run that ends without reporting on its
case each fail the run.

#### Acceptance Criteria:

- [ ] `sh scripts/hooks-test.sh` exits 0, with one `ok` line for each FR-001 criterion's case and one
      for each plant below.
- [ ] `scripts/hooks/session-start.sh` joins the scripts parsed with `sh -n` before any case runs, and
      a copy that does not parse stops the run with a `FAIL` line naming it.
- [ ] The sweep plants at least these mutations, each naming the cases it must break: the unread
      classification (an unread spec treated as not in progress); the cap; the exit status (a
      non-zero exit after a reader failure); the `GATE=` condition of the installed state; the
      foreign-hook state (a foreign hook treated as not installed); the grouping (one line per
      worktree rather than per spec file); and each of the pre-filter's four conditions (a mutant that
      does not require the first line, the closing line, exactly one status line, or that the line is
      inside the block: each must turn one of the FR-001 cases red by dropping a spec that is unread
      or in progress).
- [ ] `CASES_MIN` in `scripts/hooks-test.sh` is two below the number of cases the script now ships,
      and no case name the runner reported at the commit the build branches from is missing from what
      it reports now.
- [ ] The corpus still never touches the checkout it is run from: the invoking repository's hooks
      directory, its `.claude/settings.json` and `git status --porcelain` are identical before and
      after a full run.

### FR-004: The prose says the report exists, and a consumer can take it

#### Description:

A reviewer checks an artifact against every other place the same rule is stated, so the sites that
describe how a session learns what is in flight, and the sites that list what the scaffold ships,
change with it. No always-loaded file is among them, and none needs to be: SPEC-001 FR-006 words the
sentence in `docs/process/session-rhythm.md` and the line in the pull request template so that a
change to anything under `scripts/hooks/` calls for `sh scripts/hooks-test.sh`, which covers this
script. `docs/process/session-rhythm.md` step 4 says of
the `In Progress` transition that nothing gates it; that sentence still holds and is deliberately
left alone, because the report shows a skipped transition and does not prevent one.

The upgrade path is for a repository scaffolded before this change. Its `.claude/settings.json` holds
entries of its own, so the `hooks` block is merged into it rather than copied over it.

#### Acceptance Criteria:

- [ ] `docs/process/spec-lifecycle.md`: the *In Progress* bullet says the session-start report lists
      every spec in progress in any worktree, with the branches that carry it, and names its limit (a
      worktree left at an old commit reports that commit's status).
- [ ] `README.md`: the file table has a row for `scripts/hooks/session-start.sh`; the
      `.claude/settings.json` row says the file registers a hook that runs that script at every
      session start; and the guardrail table has a row for the session-start report.
- [ ] `.claude/skills/spec-driven/SKILL.md`, scaffolding: the `chmod +x` list names
      `scripts/hooks/session-start.sh`, and the step that merges `.claude/settings.json` says the file
      registers a hook that runs a repository script at every session start, and that the user is
      shown it.
- [ ] `.claude/skills/spec-driven/SKILL.md`, upgrading: the paragraph beginning
      `**Updating a repo scaffolded before the pre-push gate**` says to merge the `hooks` block into
      `.claude/settings.json` by hand, to make `scripts/hooks/session-start.sh` executable, and that
      `CASES_MIN` in `scripts/docs-lint-test.sh` is re-derived; and its command resolves this spec's
      commit or commits as well.
- [ ] `scripts/sync-from-skill.sh` makes `scripts/hooks/session-start.sh` executable, and the file has
      its executable bit set in the payload and at the root.
- [ ] The payload's `CLAUDE.md`, `docs/process/INDEX.md` and `docs/process/session-rhythm.md` are
      identical to their content at the commit the build branches from.
- [ ] After `sh scripts/sync-from-skill.sh`, `sh scripts/check-mirror.sh` exits 0, and `git ls-files`
      lists `scripts/hooks/session-start.sh` and each new `tests/docs-lint/` case at both paths, in
      the payload and at the root. (`check-mirror.sh` reads tracked files, so it exits 0 over a new
      payload file whose root copy is on disk and was never added.)

---

## Data Model

The registration, in `.claude/settings.json` (the existing `permissions` block is kept and is not
shown):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh",
            "args": ["${CLAUDE_PROJECT_DIR}/scripts/hooks/session-start.sh"],
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

The timeout is in seconds. Two things set it at 30. Claude's first response waits for the hook, so
the default of 600 would let a hung git hold a session for ten minutes, and the value has to be far
below that. And the work it bounds does not grow with the size of the repository: a fixed number of
processes for each worktree and one reader for each spec that is not cleanly `Draft` or `Completed`
(D7), so the value does not have to be raised as specs accumulate. A hook cancelled at its timeout
has its report discarded whole, which is the stated limit of any value chosen here.

The line templates. The report is built from these and nothing else. `<…>` is a substitution; every
other character is literal. The labels in the left column are for this spec and are not printed.

```text
H   Repository state at session start, reported by scripts/hooks/session-start.sh:
G1  The pre-push wrapper that runs the docs-lint gate is installed in this clone at <absolute path of the wrapper>.
G0  The pre-push wrapper that runs the docs-lint gate is not installed in this clone. A person installs it once per clone with: sh scripts/hooks/install.sh
GF  A pre-push hook that this template did not write is present in this clone at <absolute path of the hook>, so the wrapper that runs the docs-lint gate is not installed.
GR  core.hooksPath is a relative path in this clone (<the configured value>), which linked worktrees do not resolve, so the wrapper that runs the docs-lint gate is not installed.
P   <spec file stem> is In Progress. Branches whose worktree carries it: <branches>. Detached worktrees that carry it: <count>.
N1  No spec is In Progress in any worktree.
N2  No spec that could be read is In Progress in any worktree.
U   <spec file stem> could not be read, so its status is unknown. Branches whose worktree holds the unread copy: <branches>. Detached worktrees that hold it: <count>.
T   Lines left out to keep this report within <REPORT_MAX_BYTES> bytes: <number>.
```

`<spec file stem>` is the file's name without `.md`. `<branches>` is the branch names without their
`refs/heads/` prefix, in C-locale order, separated by a comma and a space, or the two words
`no branch`. `<count>` is a decimal number, `0` included. The order of a report:

1. `H`, always first, so the output never begins with `{` and is always read as plain text.
2. Exactly one of `GR`, `GF`, `G1` and `G0`, by the four states in FR-001, when the hook's own tree
   has `scripts/hooks/pre-push-gate`.
3. One `P` line for each stem in progress, in C-locale order of the stems.
4. `N1` when no spec is in progress and none is unread; `N2` when none is in progress and at least one
   is unread.
5. One `U` line for each unread stem, in the same order as step 3.
6. `T`, only when lines were left out.

Steps 3 to 5 are printed when at least one listed worktree has a `docs/specs` directory. A stem can
have a `P` line and a `U` line, when it is in progress in one worktree and unread in another.

**The cap** is the constant `REPORT_MAX_BYTES=1800` in `scripts/hooks/session-start.sh`, a constant and
not an environment variable, because a budget a caller can raise is not a budget. When every line
together (each with its newline) is within the cap, all are printed. Otherwise the hook prints the
longest run of whole lines from the start such that those lines and the `T` line together are within
the cap, then the `T` line carrying the number of lines not printed. The unread lines come last so
that they are the first to go. Why 1,800, stated here and in a comment beside the constant:

- It is derived from the line shapes above, for a deliberately large run. The inputs, each a byte
  count with the line's newline, written out so the sum can be re-derived:
  - the header: 79;
  - the longest gate line, `GF`, with a hook path of 120 bytes: 261;
  - an in-progress line before its stem and its branches are filled in: 92;
  - a stem of 32 bytes and a branch name of 32 bytes, with 2 bytes between branch names;
  - one spec in progress that `main` carries, and that seven branches and two detached worktrees
    therefore carry: 92, the stem, seven branches and six separators, 360;
  - five more specs in progress on one branch each: 156 each, 780;
  - the left-out line with a two-digit number: 58.
  That load comes to 1,538 bytes.
- The cap is that load with about a seventh added, rounded up to a hundred. It is deliberately not
  pinned at the load: pinned there, the first long branch name or stem would truncate a healthy
  report.
- It is paid on every session start, resume, clear and compaction, so it is sized against the
  always-loaded tier: about a fourteenth of `ALWAYS_LOADED_MAX_BYTES` as that budget stands.
- It is under a fifth of the 10,000 characters at which the vendor replaces a hook's output with a
  file path and a preview, so the report always arrives whole.
- It must be re-derived, not re-checked, if a line template changes length or a template is added.
- What the cap cannot do is tell a current line from a stale one: a worktree left at an old commit
  still contributes its branch to a line (*Out of Scope*).

Worked example 1, not installed and one spec in progress:

```text
Repository state at session start, reported by scripts/hooks/session-start.sh:
The pre-push wrapper that runs the docs-lint gate is not installed in this clone. A person installs it once per clone with: sh scripts/hooks/install.sh
SPEC-014-export-audit-log is In Progress. Branches whose worktree carries it: spec/014-export-audit-log. Detached worktrees that carry it: 0.
```

Worked example 2, installed and none in progress:

```text
Repository state at session start, reported by scripts/hooks/session-start.sh:
The pre-push wrapper that runs the docs-lint gate is installed in this clone at /Users/dev/acme/.git/hooks/pre-push.
No spec is In Progress in any worktree.
```

Worked example 3, an unreadable spec:

```text
Repository state at session start, reported by scripts/hooks/session-start.sh:
The pre-push wrapper that runs the docs-lint gate is installed in this clone at /Users/dev/acme/.git/hooks/pre-push.
No spec that could be read is In Progress in any worktree.
SPEC-009-rate-limits could not be read, so its status is unknown. Branches whose worktree holds the unread copy: main. Detached worktrees that hold it: 0.
```

The three examples are 373, 236 and 410 bytes.

---

## API / Interface Contract

```text
sh scripts/hooks/session-start.sh                (no arguments; standard input is not read)
  stdout  the report, or nothing
  stderr  nothing
  exit    0 whenever it finishes; it sets no trap, so a signal ends it with no report
  files   none created
  cost    a fixed number of processes for each worktree, and the shared reader once for each
          spec file that is not cleanly Draft or Completed
```

The docs-lint check's two failures, each identified by the quoted text:
`.claude/settings.json does not register scripts/hooks/session-start.sh as a SessionStart hook`,
followed by the exec form it expects, and
`.claude/settings.json registers scripts/hooks/session-start.sh as a SessionStart hook, but that script does not exist`.

What this spec reads from SPEC-001, and where that spec fixes it:

```text
the hooks directory, the marker on a wrapper's second line     SPEC-001 FR-003
the GATE= line of a wrapper that runs the gate                 SPEC-001 FR-003, Data Model
the generations a current installer upgrades                   SPEC-001 FR-004
the block a person pastes into a hook of their own             SPEC-001 FR-004, Interface Contract
scripts/hooks-test.sh, its guards, floor and sweep             SPEC-001 FR-005
```

## Configuration / Environment

- `hooks.SessionStart` in `.claude/settings.json`: the registration under *Data Model*.
- `REPORT_MAX_BYTES` in `scripts/hooks/session-start.sh`: a constant, with its derivation in a comment
  beside it.
- The hook reads no environment variable of its own. `${CLAUDE_PROJECT_DIR}` appears only in the
  registration, where Claude Code substitutes it.

## File & Folder Structure

Paths are in the payload, `.claude/skills/spec-driven/template/`; the repository root mirrors every
one of them, regenerated by `sh scripts/sync-from-skill.sh` and held by `sh scripts/check-mirror.sh`.

```text
.claude/skills/spec-driven/template/
├── .claude/
│   └── settings.json                    edited: the hooks.SessionStart block
├── docs/
│   └── process/
│       └── spec-lifecycle.md            edited
├── scripts/
│   ├── docs-lint.sh                     edited: the registration check
│   ├── docs-lint-test.sh                edited: CASES_MIN re-derived
│   ├── hooks-test.sh                    edited: the report's cases and plants, CASES_MIN re-derived
│   └── hooks/
│       └── session-start.sh             new
└── tests/
    └── docs-lint/
        └── session-hook-*.case          new: one case per condition of the registration check
```

Outside the payload, and so not mirrored:

```text
.claude/skills/spec-driven/SKILL.md      edited: scaffolding steps, the upgrade paragraph
README.md                                edited
scripts/sync-from-skill.sh               edited: makes the new script executable
```

## Implementation Phases

The script and its cases land before the registration that makes the report fire, and the
registration before the prose that tells people about it. Every phase edits the payload, runs
`sh scripts/sync-from-skill.sh`, and leaves these green: `sh scripts/check-mirror.sh`,
`sh scripts/docs-lint.sh`, `sh scripts/signal-test.sh --self-test`, `sh scripts/signal-test.sh`, and
the corpora it touched.

### Phase 1: The report, not yet registered

- Write `scripts/hooks/session-start.sh` to FR-001: the four gate states, the pre-filter and the
  reader behind it, the unread rule, the grouping by spec file, the line templates and their order,
  and the cap, with the cap's derivation and the pre-filter's reason (D7) in comments beside them, no
  file created and no trap.
- Add it to the `chmod` list in `scripts/sync-from-skill.sh` in the commit that creates it.
- Add the FR-001 cases and the FR-003 plants to `scripts/hooks-test.sh`, add the script to its parse
  guard, and re-derive its `CASES_MIN`.

### Phase 2: Registration and the lint check

- Add the `hooks.SessionStart` block to `.claude/settings.json`.
- Add the registration check to `scripts/docs-lint.sh`, its conditions to the header, and its seven
  cases under `tests/docs-lint/`; re-derive `CASES_MIN` in `scripts/docs-lint-test.sh`; run the corpus
  and compare its case names against commit `08643d9`.

### Phase 3: The prose and the upgrade path

- Bring the sites FR-004 names into line: `spec-lifecycle.md` and `README.md`.
- Add the scaffolding lines and the upgrade paragraph's additions in `SKILL.md`.
- Run every gate: `spec-lint.sh`, `docs-lint.sh`, `docs-lint-test.sh`, `spec-lint-test.sh`,
  `pr-queue-test.sh`, `pr-queue/install-test.sh`, `hooks-test.sh`, `check-mirror.sh`,
  `signal-test.sh --self-test` and `signal-test.sh`.
