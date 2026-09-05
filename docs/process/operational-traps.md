# Operational traps that only bite in CI / on deploy


These pass locally and fail later — check them as part of the work, not as an afterthought. Keep this
list project-specific; seed it the first time a trap bites and never again.

- _(example)_ A test runner that needs a specific working directory or config to pick up its
  environment — running it from the repo root vs. the package dir changes behavior.
- _(example)_ Config/env values the app reads at runtime must also be wired into the deploy/build
  environment, or production ships them undefined.
- _(add your own as they bite — one line each, with the fix.)_
