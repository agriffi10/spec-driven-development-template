# Spec: [Feature Name]

**ID:** SPEC-XXX  
**Status:** Draft | In Progress | Completed  
**Last Updated:** YYYY-MM-DD  
**Depends On:** SPEC-XXX, SPEC-XXX (or "None")

## Overview

One paragraph. What this feature does and why it exists. Focus on user/business intent —
no implementation detail here. Someone unfamiliar with the codebase should understand
the purpose after reading this section alone.

## Scope

### In Scope

- Bullet list of what will be built in this spec

### Out of Scope

- Explicit exclusions — things that are related but intentionally deferred
- Call out anything an implementer might reasonably assume is included but isn't

---

## Functional Requirements

<!--
  One FR per discrete behavior. Keep them granular enough that each one
  maps to a single unit of testable work. Use sequential IDs so you can
  reference them in prompts: "implement FR-001 through FR-003 only."
-->

### FR-001: [Requirement Name]

#### Description:

What the system must do.

#### Acceptance Criteria:

- [ ] Testable condition written from the user/caller's perspective
- [ ] Each criterion is a binary pass/fail — no ambiguous language
- [ ] Cover the happy path, error path, and any edge cases

### FR-002: [Requirement Name]

#### Description:

What the system must do.

#### Acceptance Criteria:

- [ ] Testable condition written from the user/caller's perspective
- [ ] Each criterion is a binary pass/fail — no ambiguous language
- [ ] Cover the happy path, error path, and any edge cases

<!-- Add more FRs as needed -->

---

## Data Model

<!--
  Use language-native types or pseudocode — not prose. Explicit shapes
  produce much better-typed output. Note the target path for the final types.
-->

```
// path/to/types
ExampleItem {
  id: string
  // ...
}
```

---

## API / Interface Contract

<!--
  For functions, classes, hooks, or component props — show the signature and
  a concrete usage example. Skip this section if FR acceptance criteria
  already cover it fully.
-->

```
functionName(param: Type, optionalParam?: Type) -> Result<ReturnType>

// Example call
result = functionName("value")
```

## Configuration / Environment

<!--
  List any new config keys, env vars, or settings this spec introduces.
  Delete this section if none.
-->

## File & Folder Structure

<!--
  Show the exact paths that should exist after this spec is complete, so the
  implementer knows where things go without guessing.
-->

```
src/
└── [feature]/
    ├── ...
    └── ...
```

## Implementation Phases

<!--
  Break work into phases that map to discrete, reviewable units. Each phase
  should be completable in one session. Do NOT write per-phase checkpoints
  here — when this spec is picked up for build, the implementing session
  generates an implementation plan and validates it against this spec before
  writing code (see docs/process.md §3). The phases below are the input to
  that plan.
-->

### Phase 1: [Name — e.g. "Data layer and types"]

- Task 1
- Task 2
- Task 3

### Phase 2: [Name — e.g. "Behavior and state"]

- Task 1
- Task 2
