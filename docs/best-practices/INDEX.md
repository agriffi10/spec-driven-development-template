# Best Practices — Index

Domain coding rulebooks for agents. **Read this index first**, then open only the one doc — and only
the section(s) — your task needs. Each doc is a token-efficient, self-contained agent reference with
its **own internal index**; never load a whole doc you don't need, and don't load a second domain
unless the task genuinely spans both. This index is a **router, not content** — keep it to one screen.

| Domain | Doc | Load when you are… | Internal index |
|---|---|---|---|
| React (18/19, function components + Hooks) | `react/react.md` | writing or refactoring any React component, hook, state, or effect | §1–§18 (Purity → Tooling) |
| Web accessibility (WCAG 2.2) | `accessibility/accessibility.md` | building or auditing any user-facing UI — markup, forms, keyboard/focus, color, ARIA | Task Index → §1–§4 (Perceivable / Operable / Understandable / Robust) |
| Python (PEP 8 + PEP 257/484/526) | `python/python.md` | writing or refactoring any Python — layout, imports, naming, idioms, type hints | §1–§9 (Layout → Tooling) |

## How to use

1. Match your task to a **Domain** row above.
2. Open that doc and use its **own index** (the React Index, the a11y Task Index) to pick the section
   IDs you need — read only those.
3. If a rule conflicts with existing code, follow the rule and **flag the conflict** (unless the user
   says otherwise).

UI work usually touches **both** React and accessibility — pull the relevant sections from each, not
the whole files.

## Adding a new domain

- One file per domain at `best-practices/<domain>/<domain>.md`, written as a token-efficient agent
  reference: a short "how to use" + an internal index + imperative ✅/🔴 rules (match the existing two).
- Add **one row** to the table above and nothing more here — the detail lives in the doc, not the index.
