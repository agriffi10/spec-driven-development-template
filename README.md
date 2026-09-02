# spec-driven-development-template

A **GitHub template repository** for building software with Claude as the implementer and you as the
person deciding what gets built and whether it's good.

It gives you two things: a set of documents that hold your project's rules and decisions in a shape
Claude can read cheaply, and a **skill** — a written procedure Claude follows — that turns "add a
feature" into a repeatable sequence: *write the spec, plan it, review the plan, build it, review the
diff, land it on green CI, record what shipped.*

You do not need prior experience with coding agents to use this. The sections below explain each
concept before it's used.

> **Built for Claude specifically.** It relies on conventions that are Claude's, not generic AI
> features: a `CLAUDE.md` file that Claude loads automatically at the start of every session,
> `@docs/…` references that Claude opens only when a task needs them, and a `.claude/skills/` folder
> that Claude Code discovers on its own. Read with a different assistant, the Markdown still makes
> sense, but none of the automatic behavior fires.

---

## Contents

- [What problem this solves](#what-problem-this-solves)
- [Concepts, in plain terms](#concepts-in-plain-terms)
- [The workflow](#the-workflow)
- [Quick start](#quick-start)
- [Your first feature, end to end](#your-first-feature-end-to-end)
- [Running several agents at once](#running-several-agents-at-once)
- [What to say to Claude](#what-to-say-to-claude)
- [What every file does](#what-every-file-does)
- [Why the scaffold exists in two places](#why-the-scaffold-exists-in-two-places)
- [Where each guardrail is enforced](#where-each-guardrail-is-enforced)
- [Maintaining and extending](#maintaining-and-extending)
- [Troubleshooting](#troubleshooting)

---

## What problem this solves

Asking an agent to "build a login page" produces something. Whether it produces the *right* thing
depends on decisions nobody wrote down: what happens on a failed attempt, whether sessions persist,
what's explicitly not included. The agent will make those decisions silently, and you'll find out
what it chose by reading the code afterwards.

This template moves those decisions earlier, into a **spec** you approve before any code exists, and
adds checks at the points where things usually go wrong:

- **Decisions are made before building, not during.** A spec with unresolved questions isn't ready to
  build, and a script enforces that mechanically.
- **The plan is reviewed before the code is written.** A wrong plan is more expensive than wrong
  code, because the code will faithfully implement it.
- **Nothing reviews its own work.** Every review runs in a *fresh context* — a Claude session that
  hasn't seen the work being reviewed. The finished diff gets **two** such reviews, from deliberately
  different angles, because one angle only finds what that angle can see.
- **Review happens before the branch is pushed, not before it's merged.** By the time work reaches
  GitHub it has already been through review, rather than collecting fixes in public.
- **The documents stay small.** Claude reads a short always-loaded file and pulls deeper documents
  only when a task needs them, so sessions start cheap and stay focused.

The cost is real: you write a spec before you get code. The return is that you review a document
while it's cheap to change, instead of reviewing a pull request after the work is done.

## Concepts, in plain terms

If you already work with agents daily, skim this. If you don't, it's the vocabulary the rest of the
README uses.

**Agent.** Claude with the ability to read and write files in your repository and run commands, not
just answer questions in a chat window. Two products run this template:

- **Claude Code** — the command-line tool you run inside a project directory.
- **Cowork** — the desktop application.

Both are installed separately from this repository; see Anthropic's Claude Code documentation at
<https://docs.claude.com/en/docs/claude-code> to get set up. Everything below assumes you have one of
them running in your project directory.

**Session.** One continuous conversation with an agent. It starts fresh with no memory of previous
sessions, which is why the important rules live in files rather than in your chat history.

**Worktree.** A second working directory for the same repository, checked out on its own branch
(`git worktree add`). Two sessions in one directory fight over the files; two sessions in two
worktrees of the same repository do not. It is how several agents work at once without colliding.

**Context.** Everything the agent currently has in front of it — your instructions, the files it has
opened, the output of commands it ran. It is finite, and a session that has read fifteen documents
reasons less well about the one that mattered. Hence the layered documents: one short file is always
loaded, everything else is fetched on demand.

**`CLAUDE.md`.** The always-loaded file. Claude reads it automatically at the start of every session
in that repository. It holds your project overview, tech stack, code conventions, settled decisions
(one line each), and the session workflow. It is deliberately short — when it grows, the detail moves
into `docs/` behind a pointer.

**`@docs/…` reference.** A line in `CLAUDE.md` like `@docs/architecture.md` is a pointer, not an
inclusion. Claude opens that file when a task calls for it and otherwise leaves it closed. This is the
mechanism that keeps context cheap.

**Skill.** A folder containing a `SKILL.md` file: a written procedure Claude follows when a matching
request comes in. Claude Code discovers skills committed at `.claude/skills/<name>/SKILL.md`
automatically, with nothing to install. This repository's skill is `spec-driven`.

If the scaffold is the set of forms and the filing cabinet, the skill is the assistant who knows how
to fill them in and where they go.

**Spec.** A document describing one feature completely enough to build from without further
questions: what it's for, what's in scope and explicitly out of scope, numbered functional
requirements each with pass/fail acceptance criteria, data shapes, and the phases of work. Specs live
at `docs/specs/SPEC-XXX-<name>.md` and are the unit of work here.

A spec is one coherent slice of behavior, not a feature's entire surface. Aim for three to six
functional requirements; past eight, the repair is a second spec beside it, recorded as an *arc*
(defined below), not a longer first one. Requirement IDs are spec-local, so the second spec restarts at FR-001 and
dependencies are cited as "SPEC-003 FR-002" rather than by a bare number.

**Fresh-context review.** Handing an artifact to a Claude session that has not seen it being made,
and asking it to find problems. This matters because an agent reviewing its own work treats its own
output as intended and rubber-stamps it. In practice the reviewer is either a new session or a
**subagent** — a helper session the main one spawns, with its own blank context.

**Frame.** The angle a reviewer is asked to look from. A reviewer finds what its frame can see, so
"the reviewer found nothing" only ever means "nothing within the frame I gave it." That is why the
finished diff gets two reviewers with *different* frames rather than the same reviewer twice: running
one frame again buys wording changes, while changing the frame finds a new class of problem.

**Arc.** Two or more related specs with an explicit build order recorded in `docs/specs/INDEX.md`.
Arcs are how a feature too big for one spec gets built: a second spec beside the first, not a longer
first one.

**PR grouping.** The decision about how one spec's phases get split across pull requests. A phase is
a unit of work, not automatically a unit of PR, so the aim is as few pull requests as the
dependencies allow — the useful boundaries are things like either side of a switchover, or
infrastructure that has to land before what depends on it. It gets its own narrow review, which asks
only whether the split is the fewest possible and whether any boundary would leave `main` half-built.

**spec-lint.** A small shell script (`scripts/spec-lint.sh`) that checks specs mechanically. It
**fails** a spec missing a required section or carrying an "Open Questions"/"Checkpoint" heading, and
**warns** on unfilled template placeholders, on a spec with requirements but no acceptance criteria
anywhere in it, and on a spec carrying more than eight requirements. The size ceiling warns rather
than fails because a genuinely indivisible spec can legitimately sit above it — that judgment belongs
to a reviewer, not a script. spec-lint catches structure, not meaning; the fresh-context review is
the half that reads for meaning.

**Owed criterion.** An acceptance criterion that cannot be settled until CI has run — anything
phrased as "passes on a green run." It can't be ticked honestly while the branch is still local, so
it's named under **Owed** in the pull request instead. Owed items block the merge, not the push.

**CI (continuous integration).** GitHub Actions runs checks automatically on every pull request. This
template ships spec-lint, docs-lint and a mirror check, and includes a template for your language's
formatter, linter, type-checker, and tests.

## The workflow

```
specify → plan → review the plan → build → review the diff → push → land on green → record
```

Read as who does what:

| Stage | You | Claude |
|---|---|---|
| **Specify** | Say what you want. Answer the questions the spec surfaces. Approve the result. | Drafts the spec, sends it to **one** fresh-context reviewer, runs spec-lint, adds it to the index. |
| **Plan** | Nothing, usually. | Turns the spec's phases into an implementation plan, checks it covers every requirement, sends it to **one** fresh-context reviewer. Sends the pull-request grouping through a narrower pass of its own. |
| **Build** | Answer escalations. Otherwise let it run. | Branches from `main`, works the plan's phases straight through, deciding reversible details itself and stopping only for choices that would change the product. |
| **Review** | Nothing. | Commits locally, runs your formatter, linter, type-checker and tests, then sends the diff to **two** fresh-context reviewers in **different frames**, fixing or explicitly rejecting every finding. |
| **Land** | Nothing. | Pushes, opens the PR, watches it to green, merges, then confirms `main` is still green. |
| **Record** | Nothing. | Marks the spec complete, updates the index, writes a short delivery note, adds any reusable component to the inventory. |

Four points are worth stating outright, because they're what make this different from asking an agent
to just build something:

**One spec in flight at a time.** You finish and merge before starting the next. Parallel specs
produce conflicting assumptions about the same code.

**Two gates on starting, two reviews before pushing — and in between, it runs.** The plan is reviewed
before the first line of code, and the PR grouping and the diff are both reviewed before the first
push. Between those bookends the build runs straight through rather than stopping after every phase
to re-ask a question you already answered. On a twelve-phase spec, per-phase check-ins ask it twelve
times.

**How many reviews, and why those numbers.** The spec gets **one**, when it is written. Then **four**
more stand between that spec starting and its pull request merging: one on the implementation plan,
one on the PR grouping, and **two** on the diff — all four before the first push. The diff gets two
because it is the widest artifact and the last one before the branch becomes public: a spec is a
single document one reader can hold whole, while a diff spans code, tests and config *and* the
criteria they are meant to satisfy. These counts are floors rather than caps, and the two floors
behave differently. On a **diff**, a clean first review does not close the gate — the second frame
still runs. On a **spec or plan**, one clean review does close it; what makes that a floor is that a
*revised* artifact is a new artifact and goes back through the gate.

**Emergent issues are triaged by kind, not parked.** Something reversible and technical — a name, a
file layout, which helper to reuse — Claude decides in-session and updates the spec if scope moved.
Something that changes behavior you'd notice, or has no clearly-right answer, stops the build and
comes to you with options and a recommendation.

The full method, with the reasoning behind each rule, is in [`docs/process.md`](docs/process.md).
Claude reads it every session.

## Quick start

### A) Starting a new project

1. On GitHub, click **Use this template** to create your repository. (This copies the files, not the
   repository settings or history — you'll set protections up in step 7.)
2. Fill in the placeholders in **`CLAUDE.md`**: Project Overview, Layout, Tech Stack, Code
   Conventions, Common Commands. Describe your actual project and keep it short — this file is loaded
   in full on every session.
3. Seed **`docs/architecture.md`** with your design, if you have one. Leave the rest of `docs/` as it
   is; the templates fill themselves in as you work.
4. **Set up language CI.** Copy `.github/workflows/ci.yml.example` to `.github/workflows/ci.yml`,
   keep only the job for your language, replace the placeholder commands with your real ones, then
   delete the `.example` file. GitHub Actions only runs workflow files ending in `.yml` or `.yaml`,
   which is why the shipped copy is inert. Until you do this, "green CI" in your project means only
   that spec-lint and docs-lint passed — and neither knows anything about your code.
5. **Delete the mirror machinery.** Remove `scripts/check-mirror.sh`, `scripts/sync-from-skill.sh`
   and `.github/workflows/check-mirror.yml`. They keep *this* template's two copies of the scaffold
   in step, and in your project they will fail: the check compares the root files against the copy
   inside the skill, so it goes red the moment you customize `CLAUDE.md` in step 2. Keep
   `.claude/skills/spec-driven/` itself — that's the skill Claude uses.
6. Trim `docs/best-practices/` to the domains you actually use — a Python library doesn't need the
   React rulebook — and update `docs/best-practices/INDEX.md` to match.
7. **Protect `main`.** In Settings → Rules, require pull requests (no direct pushes) and add
   `spec-lint`, `docs-lint` and your `ci` jobs as required status checks. Nothing in the files can enforce this;
   it's a repository setting.
8. Fill in the two per-project sections at the bottom of `docs/process.md`: *Operational traps* (§6)
   and *Project ground rules* (§7). They start as examples and exist nowhere else — the first time a
   trap bites you, one line there stops it biting the next session.
9. Write your first spec (see below).

You do **not** need to run the skill's scaffolding mode: a repository made from this template already
has both the documents and the skill. Scaffolding is for retrofitting a repository that doesn't.

### B) Retrofitting an existing project

Install the skill (see the next section), then in a session in that repository say:

> Set this repo up for spec-driven development.

Claude copies the scaffold in without overwriting files you already have, fills in `CLAUDE.md` from
your actual manifest (`package.json`, `pyproject.toml`, and so on) rather than guessing, asks once
what your CI needs, and wires spec-lint in.

### Making the skill available

**In Claude Code**, nothing to do. The skill is committed at `.claude/skills/spec-driven/SKILL.md`
and Claude Code discovers it there automatically. You can also invoke it explicitly with
`/spec-driven`.

**In Cowork**, skills are installed once into Settings → Capabilities and are then available across
all your repositories. Zip the `.claude/skills/spec-driven/` folder with a **`.skill`** extension and
use the install button, or add it through settings. Cowork also reads a repository's `CLAUDE.md` as
project instructions.

A skill installed in Cowork is not automatically available in Claude Code, and the reverse is also
true. The committed copy covers Claude Code; the Cowork install covers Cowork.

## Your first feature, end to end

A realistic sequence, so you know what to expect. Everything in quotes is what you type.

**1. Ask for a spec.**

> Draft SPEC-001 for a CSV export button on the reports page, from the spec template.

Claude writes `docs/specs/SPEC-001-csv-export.md` and comes back with questions it could not decide
for you — which columns, what happens when the report is empty, whether the file downloads or emails.
Answer them. These are the decisions that would otherwise have been made silently inside the
implementation.

Claude then sends the spec to a fresh-context reviewer, applies or rejects the findings, runs
spec-lint, and adds a row to `docs/specs/INDEX.md`. The spec's status is `Draft`.

If the feature needs more than eight requirements, expect Claude to propose splitting it into two
specs with a recorded build order rather than handing you one long one.

**2. Read it.** This is the moment your review is cheapest. Look at the Out of Scope list and the
acceptance criteria in particular: a criterion you can't imagine failing is one that isn't really
testing anything.

**3. Say go.**

> Build SPEC-001.

A Draft spec sitting in the repository is not a signal to start — Claude waits to be told. Now it
reads the spec in full, checks `main` is green, branches, marks the spec `In Progress`, generates an
implementation plan from the spec's phases, and sends that plan to a fresh-context reviewer before
writing any code. It does the same for how the work will be split into pull requests.

**4. Let it run.** The build works through the phases without stopping for approval. It will surface
progress; it will stop only if it hits something product-changing or genuinely ambiguous, and when it
does it will bring you options and a recommendation rather than a bare question.

**5. The work is reviewed before it goes public.** Claude commits locally and runs your formatter,
linter, type-checker and tests. Then the diff goes to **two** fresh-context reviewers with different
frames: one reads the change against the spec's acceptance criteria and the relevant rulebooks, and
the other starts somewhere other than the change — for code, by actually building it and running the
suites; for a documentation change, by checking every *other* place the same rule is stated. Findings
are fixed or rejected out loud. Only then does it push and open the PR.

Any acceptance criterion that can only settle once CI is green is listed under **Owed** in the pull
request rather than ticked early.

**6. It lands the PR.** Claude watches CI on the pull request, merges when green, and confirms `main`
went green afterwards. A red `main` becomes the next thing it fixes, ahead of any new work.

**7. It records what shipped.**

> Run the completion ritual for SPEC-001.

The spec's status becomes `Completed`, the index row updates, a short delivery note appears in
`docs/spec-delivery/`, and anything reusable gets a one-line row in `docs/component-inventory.md` so
the next spec reuses it instead of rebuilding it.

## Running several agents at once

The default is one spec at a time. You can also run several sessions in parallel, each building a
different spec — but not by simply opening more windows.

**What goes wrong without help.** Give each session its own worktree and their *files* stop
colliding. The **remote** still doesn't. Two pull requests open at once means each is tested against a
`main` the other is about to move, and whichever merges second turns red for a reason neither agent
caused. You then spend the time you saved diagnosing failures that are artifacts of the parallelism.

**What this template does about it.** It serializes the *remote* while leaving the *work* parallel.
The rule is: **one pull request open at a time, taken in the order the agents asked for it, with
`main` settled and green before the next one goes up.** The tool that enforces it ships in
`scripts/pr-queue/`: a lock plus a first-come-first-served line. Installing it copies it *out* of the
repository, because a lock inside one working directory is invisible to sessions in the others.

**Setting it up**, once, before you launch anyone:

```bash
sh scripts/pr-queue/install.sh '^spec-'
```

The argument is the branch-name pattern the queue applies to, and it defaults to `^spec-`. Branches
outside it push freely, so the pattern has to match the branch names you give the agents — nothing
warns you if it doesn't. The script copies the queue somewhere shared under your home directory and
installs a `pre-push` hook, so a session that tries to push out of turn is stopped rather than
reminded. If you already have a `pre-push` hook of your own, it says so and prints the line to add.

**Briefing each session.** Fill in `docs/templates/multi-agent-briefing.md` per session and paste it
as that session's first message. It covers what a session cannot work out for itself: to work in its
own worktree off a fresh `main`, who else is running and on what, which files two of them will both
edit, that its own tests and reviews come before the queue rather than instead of it — and that a
conflict is never resolved by deleting a peer's work. A session that isn't told does the sensible
thing for a session working alone, which is precisely what breaks a parallel run.

**What you'll see.** Each agent builds normally, and at the end — after its own tests and its two
reviews, which the queue does *not* replace — it gets in line and waits its turn to push. `queue.sh
status` shows who holds the lock, who's waiting, and what's actually open on GitHub. A *waiting*
session that stops responding loses its place after half an hour, so a crashed agent doesn't hold up
the line; a session that crashes while it *holds* the lock is the expensive case, and takes 90
minutes to clear — see the troubleshooting entry below.

Full detail, including how to point the queue at something other than GitHub Actions, is in
`scripts/pr-queue/PROTOCOL.md`.

## What to say to Claude

You drive this by describing what you want. These phrases trigger the matching mode of the skill; in
Claude Code you can also invoke it directly with `/spec-driven`.

| You want to… | Say something like… | What Claude does |
|---|---|---|
| Set up an existing repo | "Set this repo up for spec-driven development." | Copies the scaffold in without clobbering, fills `CLAUDE.md` from your real stack, wires CI. |
| Write a spec | "Draft SPEC-007 for &lt;feature&gt; from the spec template." | Writes a spec with no open questions, sends it to one fresh-context reviewer, runs spec-lint, adds the index row. Proposes a split if it runs past eight requirements. |
| Build a spec | "Build SPEC-007." | Plans from the spec's phases, gets the plan and the PR grouping reviewed, then builds on a branch straight through. |
| Review work | "Review this branch against SPEC-007 in a fresh context." | Runs **two** reviews in **different frames**, each in its own session or subagent, against the acceptance criteria and the relevant rulebooks — before the push, so the branch reaches GitHub already reviewed. |
| Finish a spec | "Run the completion ritual for SPEC-007." | Sets the status, updates the index, writes the delivery note, updates the component inventory. |
| Run several at once | "Set up the PR queue and brief three agents for SPEC-007, SPEC-008 and SPEC-009." | Installs the queue, writes a briefing per session from the template, and tells each one to take its turn on the remote rather than push when ready. |

The scripts, which Claude runs for you or you can run yourself:

```bash
sh scripts/spec-lint.sh
```

```bash
sh scripts/docs-lint.sh
```

```bash
sh scripts/sync-from-skill.sh
```

```bash
sh scripts/check-mirror.sh
```

`spec-lint.sh` checks every spec in `docs/specs` (pass a different directory as an argument).
`docs-lint.sh` checks the always-loaded tier: `CLAUDE.md`'s size, the length of each Key Decisions
line, and the rule that the digest and `docs/decisions.md` are two halves of one thing rather than
one file doing both jobs. The last two are maintenance scripts for *this* template repository, explained under
[Why the scaffold exists in two places](#why-the-scaffold-exists-in-two-places); projects created
from the template don't need them.

## What every file does

| Path | What it is | Who reads it |
|---|---|---|
| `CLAUDE.md` | **Always-loaded project memory.** Conventions, key decisions, session workflow, and `@docs/…` pointers to everything else. Deliberately short. | Claude, every session (automatically) |
| `docs/process.md` | The **full method** — spec lifecycle, session rhythm, the reviewer contract, completion ritual, plus per-project sections for operational traps and ground rules. It's the contract `CLAUDE.md` summarizes, so Claude reads it every session. | You + Claude (every session) |
| `docs/architecture.md` | Sectioned **design reference**, an append-only decision record, and Known Constraints. Pull the one section you need, never the whole file. | Claude (on demand) |
| `docs/decisions.md` | **Key Decisions register** — full entries with reasoning and supersession markers. `CLAUDE.md` carries a one-line digest of each. | Claude (on demand) |
| `docs/component-inventory.md` | One-line index of **reusable** modules and components, so a new spec reuses instead of rebuilding. | Claude (on demand) |
| `docs/best-practices/INDEX.md` | **Router** for the domain rulebooks: match your task to a domain, then load only the sections you need. | Claude (on demand) |
| `docs/best-practices/react/react.md` | React 18/19 rulebook (✅/🔴 rules, own internal index). | Claude (on demand) |
| `docs/best-practices/accessibility/accessibility.md` | WCAG 2.2 rulebook, organized as a task index over Perceivable / Operable / Understandable / Robust. | Claude (on demand) |
| `docs/best-practices/python/python.md` | Python 3.12 / PEP 8 rulebook. | Claude (on demand) |
| `docs/best-practices/lambdas/lambdas.md` | AWS Lambda rulebook (Python; event-driven, Step Functions, IAM). Layer `python.md` over it for language style. | Claude (on demand) |
| `docs/specs/INDEX.md` | The **spec index**: one status row per spec, plus the build-order "arcs" that record related specs. Keep the arcs section — a spec split for size always leaves an entry there. | You + Claude |
| `docs/specs/SPEC-XXX-*.md` | An individual **spec** — the unit of work. | You + Claude |
| `docs/spec-delivery/SPEC-XXX-*.md` | A short **"what shipped"** note written at completion. Read only when a later spec depends on that one. | Claude (on demand) |
| `docs/templates/spec-template.md` | The blank a new spec is written from. | You + Claude |
| `docs/templates/spec-completion-template.md` | The blank a delivery note is written from. | You + Claude |
| `docs/templates/multi-agent-briefing.md` | The blank a launch briefing is written from, when several agents run at once. One per session. | You + Claude |
| `scripts/spec-lint.sh` | **POSIX** shell linter. Fails a spec that's missing a required section or contains an "Open Questions"/"Checkpoint" heading; warns on unfilled placeholders, on requirements with no acceptance criteria anywhere in the file, and on a spec carrying more than eight requirements. No dependencies. | CI + you + Claude |
| `scripts/docs-lint.sh` | **POSIX** shell linter for the always-loaded tier. Fails when `CLAUDE.md` is over its byte budget, a Key Decisions line has grown into an essay, `docs/decisions.md` is missing or has stopped matching the digest one-for-one, an entry is missing from that file's Contents, a Completed spec has no delivery doc, a delivery doc has become an essay, or a pointer out of `CLAUDE.md` goes nowhere. No dependencies. | CI + you + Claude |
| `scripts/pr-queue/queue.sh` | The **PR queue**: a lock and a first-come-first-served line that keeps one pull request open at a time when several agents share the repo. Runs from outside the repo — `install.sh` puts it there. | Claude (multi-agent runs) |
| `scripts/pr-queue/pre-push` | The git hook that makes the queue binding rather than advisory. Refuses a push from a participating branch that doesn't hold the lock, and allows everything else. | Git |
| `scripts/pr-queue/install.sh` | One-time setup for a multi-agent run: places the queue outside the repo and installs the hook wrapper. | You + Claude |
| `scripts/pr-queue/PROTOCOL.md` | The protocol the agents read: the four commands, what the lock covers, the configuration seams, and the stale-entry rules. | Claude (multi-agent runs) |
| `scripts/sync-from-skill.sh` | Maintenance for **this template repo only** — regenerates the root scaffold from the skill's canonical copy. Delete it in a derived project. | Maintainers of this template |
| `scripts/check-mirror.sh` | Maintenance for **this template repo only** — fails if the root scaffold has drifted from the canonical copy, in either direction. Delete it in a derived project, where customizing `CLAUDE.md` makes it fail by design. | CI + maintainers |
| `.github/workflows/spec-lint.yml` | Runs spec-lint on pushes to `main`, and on pull requests that touch `docs/specs/`, the lint script, or the workflow itself. | CI |
| `.github/workflows/docs-lint.yml` | Runs docs-lint on every pull request and push to `main`. Deliberately not path-filtered, for the same reason as the mirror check: the growth it exists to catch arrives in whichever doc nobody thought to list. | CI |
| `.github/workflows/check-mirror.yml` | Runs the mirror check on every pull request and push to `main`, in **this template repo only**. Deliberately not path-filtered — the failure it exists to catch is a change in a path nobody thought to list. Delete it in a derived project. | CI |
| `.github/workflows/ci.yml.example` | **Inert** template for your language's formatter, linter, type-checker and tests (Node and Python jobs included). The `.example` extension means GitHub never runs it; you turn it into a real `ci.yml` at setup. | CI (once you fill it in) |
| `.github/pull_request_template.md` | PR checklist restating the rules: maps to the plan, no new open questions, **both framed pre-push reviews done**, gates green, owed criteria named, watch to green. | You + Claude |
| `.claude/skills/spec-driven/SKILL.md` | The **skill** — the procedure Claude follows. Claude Code discovers it at this path. | Claude Code (automatically) |
| `.claude/skills/spec-driven/README.md` | Human-facing note on what the skill folder contains and how to install it. | You |
| `.claude/skills/spec-driven/template/` | The **canonical copy** of the whole scaffold (see below). | The skill |
| `.gitignore` | OS and editor cruft, plus common Node and Python build artifacts. | Git |

## Why the scaffold exists in two places

The scaffold exists both at the repository root and inside the skill at
`.claude/skills/spec-driven/template/`. This is intentional, and the two copies have different jobs:

- The **root copy** is what a project created from this template actually uses day to day.
- The **skill's copy** makes the skill self-contained, so it can scaffold a *different, pre-existing*
  repository without this one being present.

**The skill's copy is the source of truth.** To change the scaffold, edit the files under
`.claude/skills/spec-driven/template/`, then run:

```bash
sh scripts/sync-from-skill.sh
```

and commit both copies. (Some editors and agents treat `.claude/` as protected; if that's your
situation, editing the root copy and copying it back into the skill is fine. What matters is that the
two end up identical and both are committed.)

**Never hand-edit the root `docs/`, `CLAUDE.md`, or `.github/` in this repository** — they are
generated. The next sync silently discards your change and then reports success. Five files at the
root are *not* mirrored, because they can't be: `README.md`, `.gitignore`, the two maintenance
scripts, and `.github/workflows/check-mirror.yml`. Those you edit directly.

**CI checks the mirror**, in both directions, because the two failures are different:

- A payload file that is missing at the root, differs in content, or differs in its executable bit —
  the "edited the payload, forgot to sync" case.
- A root file with no payload counterpart — an **orphan**, which is what a payload *deletion or
  rename* leaves behind. `sync-from-skill.sh` uses `cp -R`, which never deletes, so a stale root file
  survives every sync. Fix an orphan by hand.

The check exists because it was needed: two revisions' worth of changes landed in the payload alone
and the repository served a stale scaffold for weeks, because nothing was checking.

> ⚠️ **The CI jobs are not yet *required* status checks on `main`**, so a red run doesn't currently
> block a merge — the `main` ruleset has no `required_status_checks` rule. To make them binding, add
> `check-mirror`, `spec-lint` and `docs-lint` under Settings → Rules → the `main` ruleset → *Require
> status checks to pass*.

## Where each guardrail is enforced

Some rules are enforced by a script, some by CI, and some only by the documents Claude reads. Knowing
which is which tells you what breaks silently if you skip a step.

| Guardrail | Enforced by |
|---|---|
| Specs are fully specified before build — no Open Questions | `spec-lint.sh` (CI) + `process.md` |
| Specs are structurally complete (required sections present) | `spec-lint.sh` (CI) |
| A spec stays one buildable slice — split past eight requirements | `spec-lint.sh` warns (CI); the reviewer decides |
| Every spec, plan and diff passes a fresh-context review before it moves on | `process.md` + `CLAUDE.md` + `SKILL.md` |
| The counts: one review on the spec, one on the plan, one on the PR grouping, **two** on the diff | `process.md` + `CLAUDE.md` + `SKILL.md` |
| Both diff reviews happened before the push, and owed criteria are named | PR template |
| The diff reviews gate the **push**, not the merge | `process.md` + `CLAUDE.md` + `SKILL.md` |
| Builds run off a reviewed plan, straight through — no per-phase checkpoints | `process.md` + `SKILL.md` |
| Emergent issues triaged by kind: reversible → decide, product-changing → escalate | `process.md` + `CLAUDE.md` |
| Formatter, linter, type-checker and tests green **before** a push | `process.md` + `CLAUDE.md` + PR template |
| Every PR watched and merged on green; `main` watched; red `main` fixed first | `process.md` + `CLAUDE.md` + PR template |
| Domain code follows the right rulebook, loading only what's needed | `best-practices/INDEX.md` + `process.md` |
| The always-loaded tier stays lean — budget, digest line length, a register behind every digest line | `docs-lint.sh` (CI) + the completion ritual in `process.md` |
| One pull request open at a time when several agents share the repo | `scripts/pr-queue/` (the `pre-push` hook) |
| The root scaffold matches the skill's canonical copy | `check-mirror.sh` (CI) |
| Your language's own quality gates | the `ci.yml` you create from `ci.yml.example` |

The rows enforced only by documents are the ones worth reading `docs/process.md` for. They hold
because Claude reads them every session, not because anything fails when they're skipped.

## Maintaining and extending

**Changing the scaffold.** Edit the canonical copy under `.claude/skills/spec-driven/template/`, run
`sh scripts/sync-from-skill.sh`, and commit both copies. `check-mirror.sh` runs in CI and goes red on
a one-sided change in either direction. A **deletion or rename** in the payload needs the stale root
file removed by hand — the sync will not do it.

**Adding a best-practices domain.** Create `docs/best-practices/<domain>/<domain>.md` written the way
the existing ones are: a short "how to use", an internal index so a session can load one section, and
imperative ✅/🔴 rules. Then add **one row** to `docs/best-practices/INDEX.md`. The index is a router;
the detail belongs in the doc.

**Keeping `CLAUDE.md` lean.** This is the file loaded on every session, so its size is a running cost.
A new architectural decision gets its **full entry in `docs/decisions.md` first**, then **one line** in
`CLAUDE.md` — never a paragraph, and never the only home of a fact. If an edit pushes a section past a
few lines, the detail belongs in `docs/` behind a pointer.

**Recording what a spec delivered.** The completion ritual exists to stop the always-loaded tier
regrowing one spec at a time. `docs/specs/INDEX.md` holds status rows only, and Key Decisions is
grouped by area rather than kept as a per-spec changelog.

## Troubleshooting

**Claude isn't following the workflow.** Check that `CLAUDE.md` exists at the repository root and that
you started the session in the repository directory. In Claude Code you can invoke the skill directly
with `/spec-driven`. In Cowork, confirm the skill is installed under Settings → Capabilities — a
Claude Code install doesn't carry over.

**spec-lint fails on a spec.** It reports the file and the reason. A missing section means a required
heading (`## Overview`, `## Scope`, `## Functional Requirements`, `## Implementation Phases`) isn't
there. A banned header means the spec still contains "Open Questions" or "Checkpoint" — resolve the
question and write the answer into the spec rather than parking it. Warnings never fail the run:
unfilled template placeholders like `SPEC-XXX`, requirements with no acceptance criteria, and a spec
over the eight-requirement ceiling.

**spec-lint warns that a spec has too many requirements.** The usual fix is to split it in two and
record the pair as an arc in `docs/specs/INDEX.md`, cutting along a seam the system already has — a
layer, a surface, the point where something inert goes live — rather than at whichever requirement
happens to be ninth. If the spec genuinely can't be divided, say why in one line under *Scope → In
Scope* and let the reviewer accept or reject it. "It's all one feature" is the claim to be most
skeptical of, since it's what every over-scoped spec says about itself.

**`check-mirror` is red.** Read the finding type. `MISSING`, `DIFFERS` or `MODE` means you edited the
payload and didn't sync: run `sh scripts/sync-from-skill.sh`, review the diff, commit both copies.
`ORPHAN` means a root file has no counterpart in the payload, usually left behind by a deletion —
remove it by hand, restore it to the payload if the deletion was a mistake, or add it to `ROOT_ONLY`
in the script if it's genuinely root-only. Two rarer types: `DELETED` means a payload file is still
tracked by git but gone from your working copy, so stage the deletion; `STALE EXEMPTION` means the
script's `ROOT_ONLY` list names a file that no longer exists, so drop that entry.

**`check-mirror` fails in a project I created from this template.** It's meant to, and the fix is to
delete it. That check exists to keep the template's own two copies of the scaffold identical; your
project has one scaffold, and customizing `CLAUDE.md` or `docs/` makes the root differ from the copy
bundled in the skill. Remove `scripts/check-mirror.sh`, `scripts/sync-from-skill.sh` and
`.github/workflows/check-mirror.yml`, and keep the rest of `.claude/skills/spec-driven/`.

**My edits to `docs/` keep disappearing.** In *this* template repository, the root `docs/`,
`CLAUDE.md` and `.github/` are generated from the skill's payload, and the sync overwrites them. Edit
the payload instead.

In a project created from the template the root files are yours, and nothing should overwrite them —
provided you deleted `scripts/sync-from-skill.sh` at setup. If you kept it, don't run it: your
project still carries the bundled payload copy, and the script's `cp -R` would overwrite your
customized `CLAUDE.md`, `docs/` and `.github/` with the blank template versions, then report success.

**CI is green but nothing was really checked.** Until you turn `ci.yml.example` into a real `ci.yml`,
the only checks running in your project are spec-lint and docs-lint, which know about your documents
and nothing about your code. (In this template repository itself, the mirror check runs too — it also
knows nothing about your code.)

**docs-lint fails on `CLAUDE.md` being over budget.** The fix is a cut, not a bigger number: move the
detail into `docs/` behind a pointer, then re-set `CLAUDE_MAX_BYTES` in `scripts/docs-lint.sh` to what
the file measures afterwards. Raising the cap to admit the edit in hand is exactly the failure the
budget exists to catch, and it is how a sibling project's always-loaded file reached 87 KB.

**docs-lint says a Key Decisions line has no entry in `docs/decisions.md`.** Write the full entry
first, then leave the one-line digest pointing at it. A digest line that is the only home of a fact
has quietly turned the always-loaded file into the archive.

**A push was refused with "PUSH REFUSED — you do not hold the PR queue lock".** The PR queue is
installed and that branch is in a multi-agent run, so it has to take its turn: `queue.sh ticket`,
poll `queue.sh turn`, then `queue.sh acquire`. If the branch isn't part of such a run at all, the
enforced pattern is too broad — it's the argument you gave `install.sh`, kept in `enforce-branches`
in the queue directory. `PR_QUEUE_BYPASS=1 git push …` overrides it for one push.

**An agent has been waiting in the queue for a long time.** Run `queue.sh status`. If a session holds
the lock and has stopped, the queue breaks that lock on its own after 90 minutes — but only once
there's also no pull request open and `main` is green, since age alone doesn't prove a session is
dead. If it says it could not read the remote, that's `gh` failing rather than the queue stalling:
every remote check deliberately waits instead of guessing, so a check that can't run holds the line.

**A review keeps finding more things.** Two rounds in the same frame is the cap. After that, change
the angle rather than iterating — have a reviewer try to *build* the thing, or read the whole module
instead of the diff. Exit when a fresh angle finds nothing, not when you reach a round number.

**The first review came back clean — is the second one still needed?** On a diff, yes. "Never exit on
a round count" governs when to stop *above* the required two, not permission to stop below it. A
clean review means nothing was found within the frame that reviewer was given. On a spec or a plan,
one clean review does close the gate. The reasoning, and the measurements behind it, are in
`docs/process.md` §3.
