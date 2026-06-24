# Python Style & Conventions (PEP 8) — Agent Reference

> Token-efficient rulebook for LLM agents writing/refactoring Python, distilled from PEP 8 (+ PEP 257 docstrings, PEP 484/526 typing). Each section is self-contained; load only what you need. ✅ = do, 🔴 = don't. **Run the project's formatter/linter (`black` / `ruff`) — don't hand-format.** This doc is for the choices a tool can't make (naming, structure, idioms) and for review. PEP 8 is a *guideline*: the repo's configured tools win (line length, quote style), and "a foolish consistency is the hobgoblin of little minds" — when a rule hurts readability in a specific case, deviate and flag it.

## How to use
- Find the section ID(s) in the Index; read only those.
- Defer to the repo's configured tools and conventions (line length, formatter, import order, typing strictness) over the defaults here; flag conflicts.
- Enforce mechanics (§1, §3) by running `ruff`/`black`; reserve judgment for naming (§5), interfaces (§6), and programming recommendations (§7).

## Index
- **§1 Layout** — indentation, continuation, line length, line breaks, blank lines.
- **§2 Imports** — one per line, grouping/order, absolute vs relative, no wildcards.
- **§3 Whitespace** — in expressions and statements; the `=` rule.
- **§4 Comments & docstrings** — block/inline; PEP 257 docstrings.
- **§5 Naming** — modules, classes, functions, constants, privacy.
- **§6 Public vs internal interfaces** — `__all__`, leading underscore.
- **§7 Programming recommendations** — comparisons, exceptions, returns, idioms.
- **§8 Type hints** — annotation spacing and style pointers.
- **§9 Tooling & the "foolish consistency" rule** — formatter/linter/type-checker; when to ignore PEP 8.

---

## §1 Layout
- ✅ 4 spaces per indent level. 🔴 Never tabs; never mix tabs and spaces.
- Line length: PEP 8 default **79** columns (72 for docstrings/comments); many teams raise to **99/100** — use the project's configured limit, don't argue with it.
- ✅ Continuation lines: either align with the opening delimiter, or use a hanging indent (extra indent level, no argument on the opening line).
- ✅ **Break *before* binary operators** (Knuth style) — the operator starts the continued line, so operator and operand line up:
  ```python
  income = (gross_wages
            + taxable_interest
            - ira_deduction)
  ```
- Blank lines: ✅ **2** around top-level functions/classes; **1** between methods in a class; use sparingly inside a function to separate logical steps.
- ✅ One statement per line. 🔴 No `if x: do()` compound lines; 🔴 no multiple statements joined by `;`.
- ✅ End the file with a single newline; 🔴 no trailing whitespace on any line.

## §2 Imports
- ✅ One module per `import` line: `import os` then `import sys` (🔴 not `import os, sys`). `from pkg import a, b` is fine.
- ✅ Group, with a blank line between groups, in order: (1) standard library, (2) third-party, (3) local/first-party.
- ✅ Imports go at the **top of the file**, after the module docstring and `from __future__` imports, before module globals.
- ✅ Prefer **absolute imports**. Explicit relative (`from . import sibling`) is acceptable within a package; 🔴 never implicit relative imports.
- 🔴 Avoid wildcard imports (`from x import *`) — they obscure what's in scope.
- ✅ Module-level dunders (`__all__`, `__version__`) sit after the docstring, before imports (except `__future__`).

## §3 Whitespace
- 🔴 No spaces just inside brackets/parens/braces: `spam(ham[1], {eggs: 2})`, not `spam( ham[ 1 ] )`.
- 🔴 No space before `,` `;` `:`; ✅ one space after them.
- ✅ Slices: treat `:` as a binary operator with equal spacing on both sides; drop spaces when a slot is omitted — `ham[1:9]`, `ham[lower : upper + 1]`, `ham[: n]`.
- ✅ One space around binary operators (assignment, comparisons, booleans, arithmetic). For mixed precedence you may add spacing around only the lowest-precedence operators.
- 🔴 No spaces around `=` for keyword arguments / defaults: `f(x=1)`. ✅ **But** add spaces when the parameter is annotated: `def f(x: int = 1)`.
- ✅ No space before a call's `(` or an index's `[`: `fn()`, `data['key']`.
- 🔴 Don't align `=` (or `:`) across consecutive lines with extra spaces.

## §4 Comments & docstrings
- ✅ Comments are complete sentences, in English, kept in sync with the code. 🔴 Never leave a comment that contradicts what the code does.
- ✅ Block comments: each line begins with `# ` at the code's indent level. ✅ Inline comments are separated from code by **two** spaces and used sparingly.
- ✅ Write docstrings (PEP 257) for every public module, function, class, and method. ✅ Multi-line: one-line summary, blank line, then details; closing `"""` on its own line. 🔴 No docstring belongs on a `lambda`.

## §5 Naming
- ✅ Names should describe **intent**, not type or abbreviation — `calculate_rectangle_area(width, height)` over `ca(w, h)`. The casing rules below are necessary, not sufficient.
- Modules: short, `lowercase` (underscores only if they aid readability). Packages: `lowercase`, no underscores.
- Classes, exceptions, type variables: `CapWords`. Exception classes that are errors end in `Error`.
- Functions, methods, variables, attributes: `lower_case_with_underscores`.
- Constants: `UPPER_CASE_WITH_UNDERSCORES`, defined at module level.
- ✅ First arg of instance methods is `self`; of class methods, `cls`.
- ✅ `_single_leading_underscore` = "internal use"; `__double_leading` invokes name-mangling (use rarely); `trailing_` avoids a keyword clash (`class_`, `id_`).
- 🔴 Never name a single character `l`, `O`, or `I` (indistinguishable from `1`/`0`).

## §6 Public vs internal interfaces
- ✅ Declare the public API in `__all__`. Anything not in `__all__`, or prefixed with `_`, is internal and carries no backward-compatibility promise.
- ✅ Mark internal modules/functions with a leading underscore rather than relying on documentation alone.

## §7 Programming recommendations
- ✅ Compare to `None` with `is` / `is not`, never `==`. ✅ Write `x is not None`, not `not x is None`.
- 🔴 Don't compare booleans with `==`: `if active:` not `if active == True:`.
- ✅ Use truthiness for emptiness: `if not items:` / `if items:` (not `len(items) == 0`).
- ✅ `isinstance(obj, T)` over `type(obj) == T`.
- ✅ Use `str.startswith()` / `.endswith()` for prefix/suffix checks, not slicing.
- ✅ Bind names with `def`, not `name = lambda ...` (better tracebacks and `repr`).
- ✅ Derive custom exceptions from `Exception` (not `BaseException`). ✅ Catch the **specific** exception; keep the `try` body minimal. ✅ Chain with `raise New(...) from err`.
- ✅ Use context managers (`with`) for acquire/release; otherwise explicit `try/finally`.
- ✅ Be consistent about `return`: either every return in a function returns a value (write `return None` explicitly) or none do.
- 🔴 Never use a **mutable default argument** (`def f(items=[])`, `={}`) — the default is created once and shared across every call. ✅ Default to `None` and build inside: `def f(items=None): items = [] if items is None else items`.
- ✅ **One responsibility per function** — if it does two unrelated things, split it (easier to name, test, and reuse). Don't repeat logic; factor shared code out (DRY).
- ✅ Prefer **`return` over `print()`** for results — side-effect-free functions are testable; print only at the program's edges.
- ✅ For large or streaming data, prefer a **generator expression** (`sum(x * x for x in xs)`) over materializing a list comprehension first — holds one item in memory, not the whole sequence.

## §8 Type hints
- ✅ Annotate functions (PEP 484) and module/class-level variables (PEP 526) where it adds clarity. Spacing: `def f(x: int = 0) -> str:` — space after `:`, and spaces around `=` *because* the parameter is annotated (§3).
- ✅ Follow the project's typing strictness (e.g. `mypy --strict`, no untyped defs). ✅ On modern Python prefer `X | None` over `Optional[X]` and built-in generics (`list[int]`) over `typing.List`.

## §9 Tooling & the "foolish consistency" rule
- ✅ Run the project's formatter (`black` / `ruff format`) and linter (`ruff` / `flake8`) — let them own the §1/§3 mechanics. ✅ Run `mypy` when configured.
- ✅ PEP 8 is guidance, not law: when a rule would **reduce** readability, or clash with surrounding code or an existing (PEP-8-violating) API, **deviate and flag it** rather than churn the codebase.
- 🔴 Don't reformat unrelated code to satisfy style inside a feature PR — it buries the real change in diff noise.
