# The template's own specs

This directory holds the specs for changes to the spec-driven development template itself: its
scripts, its process documents and its skill. It is separate from `docs/specs/`, which is the empty
scaffold that a new project fills with specs of its own.

## Why it is a separate directory

The repository root mirrors the scaffold that the skill ships, and `docs/specs/` is part of that
scaffold. A spec written there would be copied into every project created from the template. This
directory is root-only instead: it has no counterpart in the skill's payload, and
`scripts/check-mirror.sh` names it in its list of root-only directories so that the mirror check
does not report its files as orphans.

**If you created your project from this template, delete this directory.** These specs describe
work on the template, not on your project. Your project's specs go in `docs/specs/`.

## How the specs here work

Each spec is written from `docs/templates/spec-template.md`, and it is authored, reviewed and built
by the process in `docs/process/`, as a spec in a scaffolded project is. Its frontmatter is the one
home of its status, exactly as it is there, so read `spec_status` in the file to learn whether a spec
is a draft, in progress or completed.

Lint the specs with:

```bash
sh scripts/spec-lint.sh template-specs
```

Name the directory every time. The bare command `sh scripts/spec-lint.sh` reads `docs/specs/`, which
holds no spec in this repository, so it exits 0 without having read a single file here. The
check-mirror workflow (`.github/workflows/check-mirror.yml`) runs the command above in CI on every
pull request and on every push to `main`.

There is no generated index here. `scripts/gen-index.sh` reads `docs/specs/` only, so nothing writes
an `index.yaml` for this directory, and the frontmatter of each file is all there is. Where the
process says to regenerate the index after a change to a spec's frontmatter, there is nothing to
regenerate for a spec in this directory.

## Completing a spec here

`docs/process/completion-ritual.md` numbers the steps that close a spec. It was written for a
scaffolded project, where `docs/` and `CLAUDE.md` belong to the project. In this repository those
files are the scaffold itself: the root copies mirror the skill's payload, and whatever the payload
carries is copied into every project created from the template. So a spec in this directory is
closed by the steps whose target is this directory, and by no others.

These steps are performed, and here:

- **Step 1, the status.** Set `spec_status: Completed` in the spec's frontmatter, in this directory.
- **Step 3, the delivery document.** Write it from `docs/templates/spec-completion-template.md` at
  `template-specs/delivery/SPEC-XXX-<name>.md`, and not in `docs/spec-delivery/`, because that
  directory is mirrored scaffold too. The spec linter reads only the top level of the directory it is
  given, so it does not take a delivery document in the subdirectory for a spec.

These steps are not performed for a spec in this directory:

- **Step 2, regenerating the indexes.** There is no index to regenerate, because `gen-index.sh` does
  not read this directory.
- **Step 4, the row in `docs/component-inventory.md`.**
- **Step 5, the decision file under `docs/decisions/<area>/`.**
- **Step 6, the row in the Architecture Decision Record in `docs/architecture.md`.**
- **Step 7, the prune of the `## Specs` section of `CLAUDE.md`.**

Steps 4 to 7 each write to a scaffold file. At the root those files are the blank placeholders a new
project fills in, and the root is generated from the payload. **Never make one of those edits on
behalf of a spec in this directory, at the root or in the payload.** An edit at the root makes
`scripts/check-mirror.sh` report `DIFFERS`, or `ORPHAN` for a file that is new, as a decision file is.
The documented repairs, moving the change into the payload and syncing, or restoring the file to the
payload, are wrong here: every gate would then be green, and this template's own records would ship
into every project created from it. A `DIFFERS` or an `ORPHAN` that follows such an edit is the signal
to revert the edit, not to carry it into the payload.

This rule is about the record of a spec, not about its work. A spec here usually changes the scaffold,
because the scaffold is what the template delivers, and that change is made in the payload and synced
as always. What stays out of the scaffold is the bookkeeping that says a spec of the template's was
completed.

**A decision reached by a spec here is recorded in that spec's delivery document.** This repository
keeps no decision register of its own, because `docs/decisions/` is scaffold.

## What does not watch this directory

`scripts/docs-lint.sh` reads `docs/specs/` and `docs/spec-delivery/` only. Its check that a completed
spec has a delivery document, and its cap on the length of a delivery document, never see a spec or a
delivery document here, so both are held by whoever completes the spec. The path-scoped rules in
`.claude/rules/` match `docs/specs/**` and `docs/spec-delivery/**` only, so no pointer to the process
fires when a file in this directory is opened. This file is that pointer.
