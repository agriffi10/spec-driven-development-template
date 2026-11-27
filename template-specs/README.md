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

Each spec is written from `docs/templates/spec-template.md` and follows the same rules as a spec in
a scaffolded project. Its frontmatter is the one home of its status, exactly as it is there, so read
`spec_status` in the file to learn whether a spec is a draft, in progress or completed.

Lint the specs with:

```bash
sh scripts/spec-lint.sh template-specs
```

The check-mirror workflow (`.github/workflows/check-mirror.yml`) runs the same command in CI on
every pull request and on every push to `main`.

Two things differ from a scaffolded project:

- **There is no generated index here.** `scripts/gen-index.sh` reads `docs/specs/` only, so nothing
  writes an `index.yaml` for this directory, and the frontmatter of each file is all there is.
- **Delivery documents go in `template-specs/delivery/`.** When one of these specs completes, its
  delivery document is written there and not in `docs/spec-delivery/`, because that directory is
  mirrored scaffold too. The linter reads only the top level of the directory it is given, so it
  does not take a delivery document in the subdirectory for a spec.
