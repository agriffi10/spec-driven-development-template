# AWS Lambda Best Practices — Agent Reference

> Token-efficient rulebook for LLM coding agents writing/refactoring AWS Lambda functions (Python 3.12 in this repo; principles are language-agnostic). Each section is self-contained; load only the sections relevant to the task. Rules are imperative; ✅ = do, 🔴 = don't. Defaults assume event-driven functions invoked by a Step Function task, an EventBridge Pipe, SQS, or a Cognito trigger.

## How to use this doc
- Find the relevant section ID(s) in the Index below.
- Read only those sections. Sections are deduplicated and cross-linked by ID (e.g. "see §1").
- When a rule conflicts with existing code style, follow the rule unless the user says otherwise; flag the conflict.
- This repo splits Lambda **code** (`lambdas/<name>/`) from **infra** (Terraform owns the function with a placeholder zip + `ignore_changes`; `deploy-lambdas.yml` ships code). See §12 and SPEC-012.
- **Lambdas are also code in a language.** These rules are about the *Lambda* shape; they don't replace language conventions. A Lambda written in **Python must also follow Python best practices** — see §13.

## Index
- **§1 Single responsibility** — one function = one task; size limits; decompose by action; orchestrate in Step Functions, not in code.
- **§2 Handler shape** — thin handler; parse → validate → delegate → return; keep business logic in pure functions.
- **§3 Idempotency** — at-least-once delivery; replay-safe handlers; tolerate already-exists/already-absent; dedupe keys.
- **§4 Errors & retries** — retryable vs terminal; let SFN/SQS retry transient; DLQ; never swallow; structured failures.
- **§5 Clients & cold start** — init SDK clients at module scope; reuse; lazy-load heavy deps; keep the package small.
- **§6 Configuration** — env vars for ARNs/config; validate at init; no hardcoding; no config in code.
- **§7 IAM least privilege** — one scoped role per function; no shared god-role; isolate non-scopable actions.
- **§8 Observability** — structured logs; log request/correlation ids; never log secrets/PII; emit metrics.
- **§9 Security & input trust** — validate every event field; verify JWTs fully; derive identity server-side; least trust on payloads.
- **§10 Step Function orchestration** — workflow lives in the state machine (Choice/Map/Retry/Catch), one Task = one single-task Lambda.
- **§11 Testing** — unit-test pure logic; stub AWS; cover idempotency + error paths; keep the handler thin enough to test logic directly.
- **§12 Code/infra split & packaging** — `lambdas/` code vs Terraform infra; shared code in a common module/layer; pin + minimize deps.
- **§13 Language conventions** — a Lambda is also code; Python Lambdas follow Python best practices on top of §1–§12.

---

## §1 Single responsibility
A Lambda should be **small** and do **one task**. One function that branches on an `action`/`type` discriminator to do five different jobs is five functions wearing a trench coat — split it.

- ✅ **One function, one job.** A function maps to a single logical operation (e.g. *create-space*, *add-members*), with a single reason to change and a single IAM footprint (§7).
- 🔴 No monolithic `action`-switch handler that owns unrelated workflows (validate + create + grant + delete + notify in one file). ✅ Make each verb its own function; let the orchestrator decide which to call (§10).
- ✅ **Size heuristic, not a hard rule:** if a handler exceeds ~150–200 lines, or mixes I/O against >2–3 services for >1 distinct outcome, or its tests need many unrelated setups, it's doing too much — decompose.
- ✅ Extract shared helpers (auth, registry I/O, client factories) into a **common module/layer** (§12) imported by each single-task function — share *code*, not a single fat function.
- ✅ Prefer **composition in the state machine** over composition in code: a workflow is a sequence of small Tasks, not one Lambda calling many helpers in series (§10).
- Benefits: smaller blast radius, tighter least-privilege roles, independent retry/timeout/memory tuning, faster cold starts (§5), and isolated tests (§11).

## §2 Handler shape
Keep the entry point thin; push logic into pure, testable functions.

- ✅ Handler does four things only: **parse** the event → **validate** inputs (§9) → **delegate** to a pure function → **return** a small structured result. Everything else lives in functions you can test without a Lambda context (§11).
- 🔴 Don't bury business rules, multi-service orchestration, or large branches inside `handler()`. ✅ `handler` is a few lines; the work is in named functions.
- ✅ Parse the specific event shape you expect (SQS record, Pipe payload, SFN task input) explicitly; don't pass the raw `event` dict deep into logic.
- ✅ Return a **JSON-serializable, minimal** result the next state/caller needs (status + the few fields downstream uses) — not the whole internal object (§10 payload size).
- 🔴 Don't read mutable module globals that change per invocation; module scope is for **reusable, invocation-independent** resources only (clients, §5).

## §3 Idempotency
Every event source here is **at-least-once** (SQS, Pipes, SFN retries). A function **will** be invoked twice for one logical request — design for it.

- ✅ Make each operation **replay-safe**: re-running it produces the same end state, no duplicate side effects. Tolerate "already exists / already granted / already absent" as success, not error (mirrors the SPEC-033 post-confirmation Lambda).
- ✅ Use a **conditional/atomic** primitive where uniqueness matters (e.g. S3 `PutObject If-None-Match:*` for create-once; a `requestId` you can check) instead of "read-then-write" races.
- ✅ Carry a stable **`requestId`/dedupe key** through the workflow; treat a replay of an already-terminal request as a no-op success.
- 🔴 Don't append/emit unconditionally on every invocation if a duplicate would be harmful (e.g. double-charging). For low-harm emits (notifications), at-least-once duplicates may be acceptable — **decide and document** (see SPEC-061).
- ✅ Order writes so a mid-way failure is **recoverable on replay** (e.g. remove the source-of-truth record *last* in a cascade), never leaving a dangling "success" pointer.

## §4 Errors & retries
Distinguish what should retry from what should fail fast, and let the platform do the retrying.

- ✅ **Transient/infra errors** (throttling, 5xx, timeouts) → **raise** and let the Step Function `Retry` (backoff) or SQS redrive handle them; configure a **DLQ** with a sane `maxReceiveCount`.
- ✅ **Terminal/validation errors** (bad input, unauthorized, name taken) → fail **fast and clearly**; record a terminal `failed` status with a reason; **don't** retry into a DLQ for these (use SFN `Catch` to a recorded-failure state).
- 🔴 Never swallow errors (`except: pass`) or return success on failure. ✅ Catch narrowly, add context, re-raise or convert to a typed terminal failure.
- ✅ Use distinct exception types (e.g. `AuthorizationError` vs `ProvisioningError`) so the state machine / caller can branch retryable vs terminal.
- ✅ Set per-function **timeout** and **memory** to the task's real need (a small validator ≠ a recursive bucket delete); don't inherit one big default for everything (a §1 benefit).
- ✅ A partial multi-step result must be reconcilable (§3) — record what succeeded; never leave state claiming `active` after a failed teardown.

## §5 Clients & cold start
Initialize reusable resources once per container, not per invocation.

- ✅ Create SDK clients (`boto3.client(...)`), JWKS clients, and other reusable, **invocation-independent** objects at **module scope** (outside `handler`) so they're reused across warm invocations.
- ✅ **Lazy-init** genuinely heavy/optional resources behind a cached accessor (e.g. a `_client()` that memoizes) so functions that don't need them don't pay the cost.
- 🔴 Don't construct a new client inside the handler on every call, and don't put per-request state at module scope (§2).
- ✅ Keep the deployment package **small** and deps **minimal** (§12) — fewer/lighter imports = faster cold starts. Prefer the standard library and the AWS SDK already present.
- ✅ Favor many small functions over one large one partly *because* each cold-starts faster with a narrower dependency set (§1).

## §6 Configuration
Configuration comes from the environment, validated early — never hardcoded.

- ✅ Pass ARNs, URLs, table/bucket names, caps, and toggles as **environment variables** (Terraform sets them; §12). Read them at module scope and **validate presence/shape at init**, failing fast with a clear message.
- 🔴 No hardcoded ARNs, account ids, bucket names, or magic numbers in code. ✅ Name them as env vars / module constants with a documented default.
- ✅ Make a function **degrade gracefully** when an *optional* dependency is unset (e.g. a notifications queue URL absent → log + no-op) so modules stay independently deployable (see SPEC-061).
- ✅ Document each env var where the function's infra is defined and in the spec's "Environment Variables" section.

## §7 IAM least privilege
Each single-task function gets its **own** role scoped to exactly what that task touches.

- ✅ One **execution role per function**, granting only the actions/resources that one task needs (e.g. the validator reads the registry + verifies tokens; the deleter gets recursive-delete + drop-DB). Small functions make tight roles natural (§1).
- 🔴 Don't reuse one broad "orchestrator can do everything" role across unrelated tasks — that's the monolith's IAM smell. ✅ Split the role when you split the function.
- ✅ Scope resource ARNs with principal-tag/path templates where the model allows; **isolate non-scopable actions** (those that only accept `"*"`) into their own statements (architecture.md "adding a new resource type" trap list).
- ✅ Verify with `aws iam simulate-custom-policy`: the intended action on the intended resource is `allowed`; an adjacent resource is `implicitDeny`.
- ✅ Grant `iam:PassRole` narrowly (only the roles the orchestrator actually passes), and add **deploy-role IAM** for every new role/function/resource type as in-scope work (CLAUDE.md infra rule).

## §8 Observability
You can't debug what you can't see; you can't leak what you don't log.

- ✅ Use **structured logging** (key/value or JSON) at a sensible level; include the **`requestId`/correlation id**, the `action`/space, and the outcome so one request is traceable across functions.
- 🔴 Never log secrets, raw tokens, full PII, or whole event bodies that contain them (§9). ✅ Log identifiers and decisions, not credentials.
- ✅ Log the **decision and the reason** on terminal failures (authorized? why rejected?) — enough to diagnose from CloudWatch without a re-run.
- ✅ Set log-group **retention** (this repo: 14 days) — don't rely on never-expiring default groups.
- ✅ Emit a metric/structured event for notable outcomes (created/failed/at-limit) where it aids alerting; keep it cheap.

## §9 Security & input trust
Treat every event field as untrusted until validated; derive identity, never accept it.

- ✅ **Validate the full event shape** before acting: required fields present, types correct, enums in range; reject (terminal, §4) on a schema miss with no partial write.
- ✅ **Derive caller identity server-side** from a verified token — never from a client-asserted `username`/`actor` in the body. For Cognito ID tokens: verify **issuer, audience, expiry, and signature against the pool JWKS** (offline) before trusting any claim (mirrors CLAUDE.md Auth; pre-signup / post-confirmation Lambdas).
- 🔴 Don't trust a body `username` for authorization; don't skip signature/exp checks "because it came from our queue." ✅ The function is the security boundary, not the UI.
- ✅ Authorize the action against the source of truth (e.g. "is `actor` the owner?") **before** any side effect; a failed check is a clean no-op.
- ✅ Keep secrets in env/Secrets Manager, not code; scope the function's role so it can read only what it needs (§7).

## §10 Step Function orchestration
Put the **workflow** in the state machine; keep each **Task** a single-task Lambda. The orchestrator decides *what* runs; each Lambda does *one* thing.

- ✅ Model multi-step work as explicit states: a **validate** step, then a **`Choice`** that routes by `action` to the right verb Task (e.g. `event → validate JWT → create-space`, or `event → validate JWT → add-members`). Each branch is its own workflow.
- 🔴 Don't implement the router as an `if action == …` ladder **inside one Lambda** — that's the monolith. ✅ The `Choice` state is the router; verb Lambdas don't know about each other.
- ✅ Use the state machine for **retry/backoff (`Retry`)**, **error routing (`Catch` → recorded-failure state)**, **fan-out (`Map`)**, and **parallelism (`Parallel`)** instead of coding those in a Lambda (§4).
- ✅ Keep state-passed **payloads small** — pass ids/keys and let each Task fetch what it needs (§2); large blobs between states are an anti-pattern and hit size limits.
- ✅ Make each Task **idempotent** (§3) so SFN retries are safe.
- ✅ Shared concerns that must run on **every** branch (e.g. emit a notification, record terminal status) are either a **common helper** each verb calls or a dedicated terminal state — decide per project (this repo: verb Lambdas emit inline via a shared helper, SPEC-061).

## §11 Testing
Thin handlers + pure functions make logic testable without a Lambda runtime.

- ✅ Unit-test the **pure logic** functions directly (no Lambda context); the handler is thin enough (§2) that most coverage is on the functions it calls.
- ✅ **Stub/mock AWS** (e.g. `moto`, botocore stubbers, or injected client fakes) — never hit real AWS in unit tests.
- ✅ Cover the **happy path, each terminal failure, and idempotency** (run the op twice → same end state; §3) and **authorization** rejections (§9).
- ✅ Co-locate tests with the function (`test_<name>.py`) and keep them green before opening a PR (CLAUDE.md PR rule).
- ✅ When you split a monolith (§1), split its tests too — each new function gets a focused test file, not one giant suite.

## §12 Code/infra split & packaging
Code and infrastructure live apart; share code deliberately; ship small.

- ✅ This repo: function **source** under `lambdas/<name>/` (snake_case filename); **Terraform** owns the function resource with a **placeholder zip + `ignore_changes`**, and `deploy-lambdas.yml` deploys real code (a **matrix row per function**) — see SPEC-012. Adding a function adds a code dir **and** a deploy matrix row **and** its infra.
- ✅ Put **shared code** (auth/JWT verify, registry I/O, client factories, the notification emit helper) in a **common module or Lambda layer** imported by each single-task function — don't copy-paste across verb functions (§1).
- ✅ **Pin and minimize** dependencies (`requirements.txt`); prefer stdlib + the bundled AWS SDK; every extra dep grows the package and cold start (§5).
- 🔴 Don't fetch network resources, write outside `/tmp`, or assume local state persists across invocations (only `/tmp` is writable and only within a warm container).
- ✅ Keep each function independently deployable; a missing optional dependency degrades to a no-op (§6), not a deploy-order deadlock.

## §13 Language conventions
A Lambda is also ordinary code in a language — §1–§12 govern its *Lambda* shape, not its *language* style. Apply the language's own best practices **on top of** these rules.

- ✅ **Python Lambdas follow Python best practices.** If a Python rulebook exists in `best-practices/` (e.g. `python/python.md`), route to it via `best-practices/INDEX.md` and load the relevant sections; otherwise apply standard Python conventions below.
- ✅ **PEP 8** style + a formatter/linter (e.g. `black` + `ruff`/`flake8`); snake_case functions/modules, CONSTANT_CASE module constants (matches the repo's existing `lambdas/`).
- ✅ **Type hints** on function signatures + `mypy`-clean where practical; makes the thin handler → pure-function boundary (§2) explicit and testable (§11).
- ✅ **Specific exceptions**, not bare `except:`; define domain exception types (§4) and never `except: pass` (§4 swallowing rule).
- ✅ Pythonic structure: small pure functions, docstrings on the public ones, `pathlib`/context managers for I/O, f-strings, comprehensions over manual loops where clearer — and **stdlib first** before adding a dependency (§5/§12).
- ✅ Pin the runtime (this repo: **Python 3.12**) and keep `requirements.txt` pinned + minimal (§12).
- The same applies to any other language a Lambda is written in: layer its ecosystem's conventions over §1–§12.
