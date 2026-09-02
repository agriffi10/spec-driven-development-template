## Summary
<!-- What does this PR do? One or two sentences. -->

## Spec & plan
- Spec: SPEC-XXX
- [ ] Maps to the validated implementation plan for this spec (no scope creep)
- [ ] No new Open Questions introduced — emergent issues were resolved in-session (and the spec updated if scope changed)

## Changes
<!-- Bullet list of what changed and why. -->
-

## Review (before this branch was pushed)
- [ ] **Two** fresh-context reviews of this diff, in **different frames**, before the push — every
      diff gets two, including a spec-only or docs-only one (`docs/process.md` §3 names the two
      frames for a diff with no code in it). The single review a spec or plan gets is the earlier
      gate on the artifact, not this one.
- [ ] Every finding **fixed or flagged** out loud; nothing dropped silently
- [ ] Any acceptance criterion that could not settle pre-push is listed under **Owed** below

### Owed (criteria that can only settle on the green run)
<!-- One line each, or "none". These block the merge, not the push. Edit this line —
     "none" is a claim you are making, not a placeholder left unfilled. -->
- none

## Verification
- [ ] Lint / typecheck pass
- [ ] Tests pass (added/updated where behavior changed)
- [ ] `sh scripts/spec-lint.sh` passes
- [ ] `sh scripts/docs-lint.sh` passes
- [ ] `sh scripts/docs-lint-test.sh` passes (only if you changed the linter)
- [ ] `sh scripts/docs-lint-test.sh` passes (only if you changed the linter)

## Landing
- [ ] Watching this PR to green — will merge once CI passes **and** every Owed item above is settled
- [ ] Will confirm `main` is green after merge (and fix immediately with a new PR if it isn't)
