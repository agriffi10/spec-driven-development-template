# Python Best Practices — Agent Reference

> Token-efficient rulebook for LLM coding agents writing/refactoring Python in this repo (runtime **Python 3.12**; the only Python here is AWS Lambda source under `lambdas/` + shared layers). Distilled from **PEP 8** (+ PEP 257 docstrings, PEP 484/526 typing) and the **[Google Python Style Guide](https://google.github.io/styleguide/pyguide.html)**, adapted to this repo. Each section is self-contained; load only what the task needs. Rules are imperative; ✅ = do, 🔴 = don't.
>
> **Run the formatter/linter — don't hand-format.** Mechanics (§2, §3) are owned by `ruff`/`black`; this doc is for the choices a tool can't make (naming, interfaces, idioms) and for review. Style is *guidance*: the repo's configured tools win (line length, quote style), and "a foolish consistency is the hobgoblin of little minds" — when a rule hurts readability in a specific case, deviate and flag it (§1).
>
> **Lambda shape vs Python style:** this doc governs *language* style. The *Lambda* shape (single responsibility, handler shape, idempotency, IAM, orchestration) lives in `lambdas/lambdas.md` — that doc's §13 routes here. When both apply, follow both.

## How to use this doc
- Find the relevant section ID(s) in the Index below; read only those. Sections are cross-linked by ID (e.g. "see §7").
- Defer to the repo's configured tools (line length, formatter, import order, typing strictness) over the defaults here; when a rule conflicts with existing code, follow the rule and **flag the conflict** unless the user says otherwise.
- Repo defaults: format/lint with **`ruff` (format + lint)**, type-check with **`mypy`**, test with **`pytest`** + AWS stubs (`moto`/botocore stubbers). Runtime = 3.12; pin + minimize `requirements.txt`.

## Index
- **§1 Tooling & the "foolish consistency" rule** — formatter/linter/type-checker own the mechanics; when to deviate; don't churn diffs.
- **§2 Layout & formatting** — indentation, line length, continuation, operator breaks, blank lines, one statement per line.
- **§3 Whitespace** — in expressions and statements; slices; the `=` rule.
- **§4 Imports** — module-level, absolute, one per line, grouped stdlib→third-party→local; no wildcards; `typing`/`collections.abc` exempt.
- **§5 Naming** — `lower_with_under` funcs/vars, `CapWords` classes, `CAPS_WITH_UNDER` constants; `_` internal; descriptive intent, no cryptic abbreviations.
- **§6 Public vs internal interfaces** — `__all__`, leading underscore, backward-compat promise.
- **§7 Exceptions** — built-ins for precondition violations; subclass for domain errors; no bare `except`; no `assert` for logic; small `try`; chain with `from`.
- **§8 Types & annotations** — annotate public APIs; `X | None` explicit; abstract container types in signatures; no mutable default args; annotated-`=` spacing.
- **§9 Functions, classes & properties** — one responsibility; small focused functions; properties only for cheap derived access; avoid `staticmethod`; `return` over `print`.
- **§10 Comprehensions, iterators & generators** — simple comprehensions only; default iterators; generators for streaming; `Yields:`.
- **§11 Strings, logging & errors** — f-strings/`%`/`.format`, never `+` in loops; lazy `%`-logging; precise, greppable error messages.
- **§12 Truthiness & conditionals** — implicit falsiness with caveats; `is None`; `isinstance`; `startswith`/`endswith`; simple ternaries.
- **§13 Resources & global state** — `with` for files/clients/closeables; avoid mutable global state; module-level constants OK.
- **§14 Docstrings & comments** — docstrings are the primary source of context; triple-quoted summary line; `Args`/`Returns`/`Raises`; no verbose comments, comment *why* not *what*; `TODO:` + tracked ref.
- **§15 Modules, main & power features** — module docstring; `main()` behind `if __name__ == '__main__'`; avoid metaclasses/reflection/`__del__` cleanup.

---

## §1 Tooling & the "foolish consistency" rule
Every file is auto-formatted, linted, and type-checked — style is not hand-argued.

- ✅ Run the **formatter** (`ruff format`, Black-compatible) and **linter** (`ruff`) on every file; let them own the §2/§3 mechanics. Keep both green before a PR (mirrors the repo's format:check-gates-CI rule). ✅ Run **`mypy`** where configured (§8).
- ✅ Suppress a warning **narrowly and with a reason** — a line-level `# noqa: <rule>` / `# type: ignore[<code>]` with a short explanation when the rule name isn't self-explanatory. Searchable suppressions can be revisited.
- 🔴 Don't blanket-disable rules for a whole file to dodge one line, and don't leave an unexplained `# noqa`. ✅ Fix the issue or justify the exception.
- ✅ For an unused-but-required argument (callback/interface signature), delete it at the top (`del unused_arg  # Unused.`) or prefix `unused_`.
- ✅ **Style is guidance, not law:** when a rule would *reduce* readability, or clash with surrounding code or an existing (style-violating) API, **deviate and flag it** rather than churn the codebase.
- 🔴 Don't reformat unrelated code to satisfy style inside a feature PR — it buries the real change in diff noise. **Be consistent** with the surrounding file; prefer converging on the newer style over perpetuating an old one.

## §2 Layout & formatting
Formatter-driven; the rules below are what the formatter enforces — know them for hand-edits.

- ✅ **4-space indent**, never tabs; never mix tabs and spaces. One statement per line (a single `if foo: bar()` with no `else` is the only same-line allowance; never for `try`/`except`). 🔴 No `;`-joined statements.
- ✅ **Line length:** use the project's configured limit; PEP 8 default is 79 (72 for docstrings/comments), Google caps at 80, many teams raise to 99/100. Don't argue with the configured value. Long imports, URLs/paths in comments, and `# noqa`-style directives may exceed.
- 🔴 **No backslash line continuation.** ✅ Use implicit joining inside `()`/`[]`/`{}`; add parens around an expression if needed. Continuation lines either align with the opening delimiter or use a 4-space hanging indent (no argument on the opening line). Break at the highest syntactic level.
- ✅ **Break *before* binary operators** (Knuth style) so operator and operand line up:
  ```python
  income = (gross_wages
            + taxable_interest
            - ira_deduction)
  ```
- ✅ Blank lines: **2** around top-level functions/classes, **1** between methods; use single blank lines sparingly inside a function to separate logical steps. No blank line right after a `def`.
- ✅ Trailing comma in a multi-line sequence only when the closing bracket is on its own line (and for 1-tuples: `(foo,)`); it also cues the formatter to one-item-per-line. Don't vertically align tokens (`=`, `:`, `#`) across lines. End the file with a single newline; no trailing whitespace.

## §3 Whitespace
Standard typographic spacing; a few Python-specific traps.

- 🔴 No spaces just inside brackets/parens/braces: `spam(ham[1], {'eggs': 2})`, not `spam( ham[ 1 ] )`.
- 🔴 No space before `,` `;` `:`; ✅ one space after them (except at line end). No space before a call's `(` or an index's `[`: `fn()`, `data['key']`.
- ✅ **Slices:** treat `:` as a binary operator with equal spacing on both sides; drop spaces when a slot is omitted — `ham[1:9]`, `ham[lower : upper + 1]`, `ham[: n]`.
- ✅ One space around binary operators (assignment, comparisons `== < > != <= >= in not in is is not`, booleans `and or not`). Use judgment around arithmetic; for mixed precedence you may space only the lowest-precedence operators.
- 🔴 **No spaces around `=` for keyword args / unannotated defaults:** `f(x=1)`, `def complex(real, imag=0.0)`. ✅ **But** add spaces when the parameter is **annotated**: `def f(x: int = 0)` (§8).

## §4 Imports
Import modules, not individual names (typing is the exception); keep them absolute and ordered.

- ✅ `import x` for packages/modules; `from x import y` where `y` is a **module** (`from doctor.who import jodie`), then reference `jodie.Thing`. 🔴 No `import os, sys` on one line (`from pkg import a, b` is fine).
- ✅ **Exception — typing:** import symbols directly from `typing` / `collections.abc` (`from collections.abc import Mapping, Sequence`; `from typing import Any, cast, TYPE_CHECKING`) — multiple per line allowed.
- ✅ `import y as z` only for standard abbreviations (`import numpy as np`) or to resolve a genuine collision / inconveniently long name.
- ✅ Prefer **absolute imports** (full package path). Explicit relative (`from . import sibling`) is tolerable within a package; 🔴 never implicit relative imports, and a bare `import jodie` is assumed third-party/top-level, not a sibling file.
- 🔴 Avoid wildcard imports (`from x import *`) — they obscure what's in scope.
- ✅ **One import per line**; group and order with a blank line between groups: (1) `from __future__`, (2) stdlib, (3) third-party (e.g. `boto3`), (4) local sub-packages — sorted lexicographically within each group. Imports go at the top, after the module docstring and any module dunders (`__all__`, `__version__`), before constants.

## §5 Naming
Names describe **intent**; casing follows the standard table; visibility governs the leading underscore.

- ✅ Descriptive names, proportional to scope — `calculate_rectangle_area(width, height)` over `ca(w, h)`. Casing rules are necessary, not sufficient.
- ✅ `module_name`/`package_name` (`lower_with_under`; packages prefer no underscores), `function_name`, `method_name`, `local_var_name`, `parameter_name`, `instance_var_name`, `global_var_name`.
- ✅ `ClassName`, `ExceptionName`, type variables in `CapWords`; exception classes end in `Error`. `GLOBAL_CONSTANT_NAME` in `CAPS_WITH_UNDER` at module level.
- ✅ First arg of instance methods is `self`; of class methods, `cls`.
- ✅ Prepend **one** `_` for module-internal / class-protected names; `trailing_` avoids a keyword clash (`class_`, `id_`). 🔴 Avoid `__dunder` name-mangling — hurts readability/testability and isn't really private.
- ✅ Single-char names only for counters/iterators (`i`, `k`, `v`), `e` in `except`, `f` in `with open`, or unconstrained private typevars (`_T`). 🔴 Never name anything `l`, `O`, or `I` (indistinguishable from `1`/`0`); no letter-deleting abbreviations; no type-in-name (`names_dict`); no dashes in filenames — always `.py`, `lower_with_under.py`.
- ✅ Repo convention already in `lambdas/`: snake_case modules/functions, `CONSTANT_CASE` module constants — match it.

## §6 Public vs internal interfaces
Make the public surface explicit; everything else carries no compatibility promise.

- ✅ Declare the public API in **`__all__`**. Anything not in `__all__`, or prefixed with `_`, is internal and may change without notice.
- ✅ Mark internal modules/functions with a **leading underscore** rather than relying on documentation alone. (In this repo, shared Lambda-layer code exposes its intended surface this way; see `lambdas.md` §12.)

## §7 Exceptions
Exceptions are allowed but disciplined; never swallow, never use `assert` for real logic.

- ✅ Raise a **built-in** for a violated precondition / bad argument (`raise ValueError(f'Not a probability: {p=}')`). Prefer specific built-ins over generic ones.
- ✅ Define **domain exceptions** by subclassing an existing exception (from `Exception`, not `BaseException`); name them `…Error` without stutter (`ProvisioningError`, not `provisioning.ProvisioningError`). Distinct types let callers/Step Functions branch retryable vs terminal (see `lambdas.md` §4).
- 🔴 Never `except:` bare, and don't catch `Exception` broadly — **unless** re-raising or forming a deliberate isolation boundary that records/suppresses (e.g. protecting a thread's outermost block). Bare `except:` also swallows `SystemExit`, `KeyboardInterrupt`, typos. ✅ Catch the **specific** exception.
- 🔴 Never `except: pass` or return success on failure. ✅ Catch narrowly, add context, re-raise or convert to a typed terminal failure; **chain** with `raise NewError(...) from err`.
- ✅ Keep the **`try` body minimal** — only the line(s) that can raise — so a real error isn't hidden by an unrelated one. Use `finally` (or `with`, §13) for cleanup.
- 🔴 Don't use `assert` to validate inputs or enforce control flow — asserts can be stripped (`-O`) and aren't guaranteed to run. (In `pytest` tests, `assert` is the expected way to check expectations.)

## §8 Types & annotations
Annotate public surfaces; make `None` explicit; prefer abstract types in signatures.

- ✅ Annotate **public function/method signatures** (PEP 484) and module/class-level variables (PEP 526) where it adds clarity; you needn't annotate everything. Don't annotate `self`/`cls` or `__init__`'s `None` return. Follow the project's strictness (e.g. `mypy --strict`).
- ✅ **Explicit `X | None`** for nullable args (3.10+ union syntax preferred over `Optional[X]`); a nullable arg *must* be declared nullable — no implicit `a: str = None`.
- ✅ In signatures prefer **abstract containers** (`collections.abc.Sequence`, `Mapping`) over concrete `list`/`dict`; use built-in generics (`list[int]`, `tuple[str, ...]`) over `typing.List`/`Tuple`. Always parameterize generics (`Mapping[int, str]`, not bare `Mapping` → implicit `Any`).
- 🔴 **Never use a mutable default argument** (`def f(a, b=[])`, `={}`) — created once and shared across every call. ✅ Default to `None` and build inside: `def f(a, b: Sequence | None = None): b = [] if b is None else b`. (Empty tuple `()` is fine — immutable.)
- ✅ **Spacing:** `def f(x: int = 0) -> str:` — space after `:`, and spaces around `=` *because* the parameter is annotated (§3).
- ✅ `CapWords` type aliases (`_Private` if module-local); forward refs via `from __future__ import annotations` or string names; `str` for text, `bytes` for binary; typing-only imports under `if TYPE_CHECKING:`.

## §9 Functions, classes & properties
One job per function; small and testable; classes and properties only where they earn their keep.

- ✅ **One responsibility per function** — if it does two unrelated things, split it (easier to name, test, reuse); factor shared logic out (DRY). Prefer **small focused functions**; no hard limit, but past ~40 lines consider splitting. (Lambda handlers stay thin — logic in pure functions, `lambdas.md` §2.)
- ✅ Prefer **`return` over `print()`** for results — side-effect-free functions are testable; print only at the program's edges.
- ✅ Be consistent about `return`: either every return in a function returns a value (write `return None` explicitly) or none do.
- ✅ Put related classes/functions together in one module — no one-class-per-file rule. Nested functions/classes are fine **only** to close over a local (not just to hide a helper — prefix `_` at module level instead so tests can reach it).
- ✅ A **`@property`** is only for cheap, straightforward, unsurprising derived access. 🔴 Don't wrap a plain get/set in a property — make the attribute public. Use getter/setter methods (`get_foo()`/`set_foo()`) only when get/set does real work (invalidates/rebuilds state, significant cost).
- 🔴 Never `staticmethod` (write a module-level function) unless an external API forces it; use `classmethod` only for named constructors or class-wide state. ✅ Bind names with `def`, not `name = lambda ...` (better tracebacks and `repr`). Use decorators judiciously with a clear payoff.

## §10 Comprehensions, iterators & generators
Concise container/iterator idioms — but readability wins over cleverness.

- ✅ Comprehensions/generator expressions are fine for **simple** cases: `[f(x) for x in xs if pred(x)]`. 🔴 No multiple `for` clauses or multiple filters — expand to a loop. Optimize for readability, not brevity.
- ✅ Use **default iterators/operators**: `for k in adict`, `if x in alist`, `for k, v in adict.items()`, `for line in afile`. 🔴 Not `adict.keys()` / `afile.readlines()` for plain iteration. Don't mutate a container while iterating it.
- ✅ For large or streaming data, prefer a **generator expression** (`sum(x * x for x in xs)`) over materializing a list first — holds one item in memory. Document generators with `Yields:` not `Returns:` (§14); wrap one holding an expensive resource in a context manager so cleanup is forced.
- ✅ Lambdas are fine for one-liners; if it spans lines or exceeds ~60–80 chars, use a named `def`. Prefer `operator.mul` etc. over `lambda x, y: x * y`.

## §11 Strings, logging & errors
Format explicitly; log lazily; write precise, greppable messages.

- ✅ Format with **f-strings**, `%`, or `.format()` — pick per readability. A single `a + b` join is fine; 🔴 don't build strings with chained `+` (`'a: ' + name + '; ' + str(n)`).
- 🔴 Don't accumulate a string with `+=` **in a loop** (risks quadratic time). ✅ Append substrings to a list and `''.join(items)` after the loop, or write to `io.StringIO`.
- ✅ **Lazy logging:** pass a **literal `%`-pattern** + args to the logger — `logger.info('version is: %s', v)` — never a pre-rendered f-string. Preserves the queryable pattern and skips rendering when the level is off.
- ✅ **Error messages** (exceptions and user-facing): match the actual condition precisely, mark interpolated pieces clearly (`f'{p=}'`, `%r`), and stay greppable. 🔴 Don't assert a cause you didn't verify (e.g. "directory already deleted" on any `OSError`).
- ✅ Be consistent with one quote character per file; use `"""` for multi-line strings and all docstrings.

## §12 Truthiness & conditionals
Use implicit falsiness and identity comparisons — with the standard traps in mind.

- ✅ `if seq:` / `if not seq:` for empty sequences (not `if len(seq) == 0:`); `if foo:` over `if foo != []:`.
- ✅ Compare to `None` with **`is` / `is not`**, never `==`; write `x is not None`, not `not x is None`. Always `if x is None:` for None checks — a falsy-but-not-None value (`0`, `''`, `[]`) would otherwise be misread. 🔴 Don't `x = x or []` when `x` could be legitimately falsy.
- 🔴 Never compare booleans with `==`: `if active:` not `if active == True:` (chain `if not x and x is not None:` if you must separate `False` from `None`).
- ✅ `isinstance(obj, T)` over `type(obj) == T`. ✅ `str.startswith()` / `.endswith()` for prefix/suffix checks, not slicing.
- ✅ For integers, compare explicitly (`if i % 10 == 0:`) rather than relying on implicit false — avoids treating `None` as `0`. Note `'0'` (string) is truthy; NumPy arrays raise on implicit bool — use `.size`.
- ✅ Ternaries only when each of the three parts fits on one line; otherwise a full `if`.

## §13 Resources & global state
Close what you open; avoid mutable module/class state.

- ✅ Manage files/sockets/DB connections and other closeables with a **`with` statement** (or `contextlib.closing()` for non-context-manager closeables); otherwise explicit `try/finally`. Don't rely on `__del__`/GC for cleanup — timing is unguaranteed.
- 🔴 **Avoid mutable global state.** If unavoidable, declare it at module level, make it internal (`_name`), expose via functions, and comment *why*. (In Lambdas, module scope is for reusable, invocation-independent objects only — clients, not per-request state; `lambdas.md` §2/§5.)
- ✅ **Module-level constants are encouraged** — `_MAX_RETRIES = 3` (internal) / `DEFAULT_REGION = 'us-east-1'` (public), `CAPS_WITH_UNDER`.
- ✅ Init reusable SDK clients (`boto3.client(...)`) once at module scope and reuse — not per call (cold-start/perf; `lambdas.md` §5).
- 🔴 Don't rely on atomicity of built-in types across threads; use `queue.Queue` or `threading` primitives to communicate between threads.

## §14 Docstrings & comments
Docstrings describe the interface and are the **primary source of context**; comments explain the non-obvious and should be rare.

- ✅ Triple-double-quoted `"""` docstrings (PEP 257) for every public module, function, class, and method — plus any nontrivial or non-obvious function. First line a summary ending in a period, ≤ the docstring line limit; multi-line = summary, blank line, details, closing `"""` on its own line. 🔴 No docstring on a `lambda`. Enough info to call it without reading the body.
- ✅ Use the section format when it adds info: **`Args:`** (each param + description; note types if not annotated), **`Returns:`** (or **`Yields:`** for generators; omit if it only returns `None` or the summary already says it), **`Raises:`** (exceptions relevant to the interface).
- ✅ Class docstring below the `class` line summarizing what an **instance represents** (an `Exception` subclass says what it *represents*, not when it's raised); document public attributes in an `Attributes:` section.
- ✅ **When code needs explaining, prefer expanding the docstring over adding comments.** Docstrings are discoverable (`help()`, hover, generated docs); scattered comments are not.
- ✅ **Comments explain *why*, not *what*** — tricky logic, non-obvious decisions; assume the reader knows Python. Complete sentences, proper capitalization/punctuation, kept in sync with the code. 🔴 No verbose or paragraph-length comments, and never a comment that just narrates *what* the next line does. 🔴 Never leave a comment that contradicts the code. Block comments at the code's indent (`# ` prefix); inline comments ≥2 spaces from code, used sparingly.
- ✅ `TODO:` in caps + colon + a **tracked reference** (issue link preferred) + `-` explanation: `# TODO: <issue-url> - Investigate X`. Don't attribute TODOs to a person/team as the context.

## §15 Modules, main & power features
Modules stay importable; avoid Python's fancy machinery.

- ✅ Start each module with a **docstring** describing contents and usage (+ license boilerplate where the project requires). Test modules need a docstring only if there's something extra to say.
- ✅ If a file is executable, put the work in a **`main()`** and guard `if __name__ == '__main__': main()` so importing (for tests/`pydoc`) doesn't run it. 🔴 Don't do real work at module top level. (Lambda source is imported by the runtime — no `__main__` guard needed; the entry point is `handler`.)
- 🔴 **Avoid power features** — custom metaclasses, bytecode access, dynamic inheritance, reflection tricks (`getattr` hacks), `__del__` cleanup, import hacks. Stdlib/framework internals that use them (`dataclasses`, `enum`, `abc.ABCMeta`) are fine to *use*.
- ✅ `from __future__ import` is encouraged to adopt modern semantics per-file (e.g. `annotations`).
