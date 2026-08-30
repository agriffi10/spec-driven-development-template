# [Project Name] — Architecture

The design reference: *what* we're building and *why*, including decisions made along the way. Read the
**section you need**, not the whole file. It is intentionally allowed to be ahead of the code —
sections describe the target design, not necessarily what's implemented yet.

> **Keep it sectioned and skimmable.** Each numbered section owns one concept so a session can pull just
> that one. Reasoning that justifies a one-line entry in `CLAUDE.md` → Key Decisions lives here.

---

## 1. Purpose & scope

[What this system/library owns, and what it explicitly does not.]

## 2. [Core concept]

[...]

---

## Architecture Decision Record

An **index** of the decisions that changed the *shape* of the system — a piece added or removed, a
boundary moved, a mechanism swapped. Not every decision: a rule, a fence or a per-feature choice is a
`decisions.md` entry and nothing more, and a table that grows a row per spec has stopped being an
orientation aid. Rows are **append-only and never renumbered** — a superseded decision keeps its row
and gains a note naming the row that replaced it.

| # | Decision | Context | Note |
|---|---|---|---|
| 1 | [what changed] | [the one-line situation that forced it] | [pointer to the `decisions.md` entry] |

---

## Known Constraints

Hard constraints and non-obvious gotchas that shape every spec. New constraints get added here the
first time they bite.

- [constraint — one or two lines, with the implication for implementers]

## Deferred / Non-goals

- [things deliberately not built yet, and a pointer to where the seam is reserved if relevant]
