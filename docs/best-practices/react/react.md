# React Best Practices — Agent Reference

> Token-efficient rulebook for LLM coding agents writing/refactoring React. Each section is self-contained; load only the sections relevant to the task. Rules are imperative; ✅ = do, 🔴 = don't. Defaults assume function components + Hooks, React 18/19.

## How to use this doc
- Find the relevant section ID(s) in the Index below.
- Read only those sections. Sections are deduplicated and cross-linked by ID (e.g. "see §6").
- When a rule conflicts with existing code style, follow the rule unless the user says otherwise; flag the conflict.

## Index
- **§1 Purity** — components/Hooks must be pure; what runs in render vs not.
- **§2 Immutability** — never mutate props, state, context, Hook args/returns, JSX-passed values.
- **§3 State modeling** — minimal state; derive don't store; where state lives.
- **§4 Rendering model** — one-way data flow; React owns calls; reconciliation & keys.
- **§5 Hooks rules** — call rules; never pass Hooks around.
- **§6 useState** — async/batched updates; updater fn; lazy init; object/array updates.
- **§7 useReducer** — when to use over useState; reducer purity; pattern; +context.
- **§8 Context** — global state; re-render pitfalls; memoize value; split contexts.
- **§9 You Might Not Need an Effect** — anti-patterns and their replacements.
- **§10 Effect fundamentals** — what an Effect is; timing; deps array; cleanup.
- **§11 Effect lifecycle** — think in synchronize/desynchronize, not mount/unmount.
- **§12 Effect dependencies** — deps must match code; remove deps by changing code; object/fn deps.
- **§13 Events vs Effects** — reactive vs non-reactive; useEffectEvent.
- **§14 Custom Hooks** — extract reusable stateful logic; naming; constraints.
- **§15 Performance** — memo/useMemo/useCallback; React Compiler note.
- **§16 Architecture & mental model** — declarative > imperative; react vs react-dom; Elements; FP principles.
- **§17 Build workflow** — Thinking in React 5-step process.
- **§18 Tooling** — StrictMode + eslint-plugin-react-hooks; never suppress the linter.

---

## §1 Purity
Components and Hooks must be pure. Purity = (a) **idempotent**: same inputs (props/state/context for components; args for Hooks) → same output, every render; (b) **no side effects in render**; (c) **no mutation of non-local values** during render.

- 🔴 No non-idempotent calls in render: `new Date()`, `Math.random()`, reading mutable globals. ✅ Move to an event handler, an Effect, or `useState(() => ...)` lazy init.
- 🔴 No side effects in render: DOM writes (`document.title = …`), network calls, mutating external state. ✅ Put them in event handlers (preferred) or Effects (last resort; see §9).
- ✅ **Local mutation is fine**: creating + mutating a value *within the same render* (e.g. build an array then `push` into it) is allowed. Mutating a value created *outside* the component is not.
- ✅ Lazy initialization with a side effect (e.g. `SomeLib.initIfNeeded()`) is acceptable if it doesn't affect other components.
- Purity is what lets React skip, pause, restart, memoize, and re-run renders, and run components on the server.
- StrictMode double-invokes renders in dev to surface impurities (§18).

## §2 Immutability
Treat all React inputs as read-only snapshots for a given render.

- 🔴 Never mutate props. ✅ Copy first: `const url = new Url(item.url, base)`.
- 🔴 Never assign to a state variable directly (`count = count + 1`). ✅ Use the setter (`setCount(count + 1)`) — only the setter queues a re-render.
- 🔴 Never mutate Hook arguments or Hook return values (they may be memoized internally → stale/incorrect results). ✅ Copy: `const next = {...icon, enabled:false}`.
- 🔴 Never mutate a value after it's been passed to JSX (React may evaluate JSX eagerly → stale UI). ✅ Create the final value before using it in JSX.
- Objects/arrays in state: produce a **new reference** to trigger re-render (`setUser({...user, ...})`, `items.map(...)`). Mutating in place keeps the same reference and React skips the update (§6).
- React detects change by reference (`Object.is`), which is *why* immutability matters (§16 FP).

## §3 State modeling
- **Minimal, complete state**: store only data that (a) changes over time AND (b) can't be computed from props/other state. If it can be derived, compute it in render — don't store it (§9).
- Test for "is this state?": unchanging → not state; comes from props → not state; computable from existing state/props → not state.
- Keep state DRY: store an array, derive its `.length`; store a `selectedId`, derive the selected item.
- **Where state lives**: find every component that uses it → their closest common parent → put state there (or lift higher / create a holder component). One-way data flow: state down via props, changes up via callbacks (§17).
- Prefer several focused state variables over one big object when fields update independently; use one object/`useReducer` when fields are interdependent (§7).
- To reset state on a prop change, prefer giving the subtree a different `key` over an Effect (§9).

## §4 Rendering model
- **React calls your components — you don't.** ✅ Use components only in JSX: `<Article />`. 🔴 Never call as functions: `{Article()}` (breaks Hooks, identity, reconciliation, optimizations).
- One-way (top-down) data flow: parents pass props to children; children request changes via callbacks passed down.
- **Reconciliation**: React diffs old vs new element trees. Same type → update props in place. Different type → destroy + rebuild subtree (and its state).
- **Keys**: give list items stable, unique `key`s so React tracks identity across reorders/inserts. 🔴 Don't use array index as key when the list can reorder/insert/delete. Changing a component's `key` remounts it and resets its state (§9).

## §5 Hooks rules
- ✅ Call Hooks only at the **top level** of a component or custom Hook — never in loops, conditions, nested functions, or after an early return.
- ✅ Call Hooks only from **React function components or custom Hooks** — never from plain JS functions.
- 🔴 Never pass a Hook around as a value, inject it as a prop, or build higher-order Hooks (`withLogging(useData)`). ✅ Call Hooks statically/inline; put conditional behavior *inside* the Hook.
- These keep call order stable across renders and preserve local reasoning.

## §6 useState
- `const [v, setV] = useState(initial)`. Setter queues a re-render with the new value.
- **State is a snapshot / async**: after `setV(x)`, the local `v` does NOT change until the next render. Don't read `v` expecting the new value immediately.
- **Updater function** for updates based on previous value: `setCount(c => c + 1)`. Required when batching multiple updates or inside closures/timeouts/Effects to avoid stale values. Three `setCount(c=>c+1)` → +3; three `setCount(count+1)` → +1 (batched, same stale `count`).
- **Lazy init** for expensive initial values: `useState(() => compute())` — fn runs once. 🔴 `useState(compute())` runs `compute()` every render.
- **Objects/arrays**: always set a new copy (`{...obj, k:v}`, `arr.map(...)`, `[...arr, x]`). Mutating + setting the same reference won't re-render (§2).
- The `set` function is stable (safe to omit from deps; §12).
- Move to `useReducer` when state grows complex/interdependent (§7).

## §7 useReducer
- `const [state, dispatch] = useReducer(reducer, initialState[, init])`. Reducer `(state, action) => newState` must be **pure** (no mutation, no side effects).
- **Use over useState when**: state is complex/nested, fields are interdependent, updates follow explicit "business action" patterns, or many actions mutate state. Use `useState` for simple, independent values.
- Benefits: centralized transition logic, self-documenting named actions, consistent derived calculations, easy unit testing (test the pure reducer directly).
- Actions: `{ type, payload? }`. Use a `switch` on `type`; always `return state` in `default`. With TS, model actions as a discriminated union for inference.
- Keep reducers lean by extracting derived calcs into helper functions. Use lazy init (3rd arg) for e.g. reading localStorage.
- **+ Context**: split into a state context and a dispatch context, wrap in a provider, expose via custom hooks — gives app-wide state without prop drilling (§8).

## §8 Context
- For sharing data across distant components without prop drilling (theme, auth, locale, user prefs). `createContext` once; `<Ctx.Provider value>` defines value for its subtree; `useContext(Ctx)` reads nearest provider (else `defaultValue`).
- **Re-render pitfall**: Provider compares `value` by `Object.is`. A fresh object literal `value={{user, setUser}}` is a new reference every render → all consumers re-render. ✅ `useMemo` the value (and `useCallback` functions in it).
- ✅ **Split contexts** by concern / by change frequency (e.g. data vs actions/dispatch) so consumers subscribe only to what they use.
- ✅ Place Providers as low in the tree as possible to limit update scope.
- ✅ Wrap context access in a custom hook (`useUser`) that throws if used outside its Provider.
- For large/complex/high-frequency global state, consider Zustand or Redux; Context is best for simple, infrequently-changing shared values.

## §9 You Might Not Need an Effect
Effects are an escape hatch for syncing with external systems. If no external system is involved, you usually don't need one. Common anti-patterns → fixes:

- **Deriving state from props/state** → 🔴 storing it in state + Effect. ✅ Compute during render: `const fullName = first + ' ' + last`.
- **Expensive derivation** → ✅ `useMemo(() => compute(a,b), [a,b])`, not an Effect (§15).
- **Resetting all state when a prop changes** → ✅ pass a different `key` to the subtree, not an Effect.
- **Adjusting some state on prop change** → ✅ compute during render, or (rarely) set state during render guarded by a `prev !== current` check; best: store an id and derive the object.
- **Logic for a user event** (POST on buy, notification on click) → ✅ put it in the event handler, not an Effect. Ask: does this run *because the component was shown* (Effect) or *because the user did X* (handler)?
- **Chains of Effects** each setting state to trigger the next → ✅ compute what you can in render; set the rest in one event handler.
- **App init once** → ✅ module-level guard or run before render; don't rely on a mount Effect (it runs twice in dev).
- **Notifying parent / lifting state** → ✅ update both in one event handler, or lift state to parent (controlled component).
- **Passing fetched data child→parent** → ✅ fetch in the parent, pass down.
- **Subscribing to an external store** → ✅ `useSyncExternalStore`, not manual Effect subscription.
- **Data fetching IS a valid Effect use**, but add a cleanup `ignore` flag to prevent race conditions; prefer a framework's data layer or a `useData` custom hook (§14). Effects run after render/commit, so Effect-then-setState causes an extra render pass.

## §10 Effect fundamentals
- Use an Effect only to **synchronize with an external system** (DOM, network, browser API, third-party widget, timers, subscriptions). First check §9.
- Shape: `useEffect(() => { /* setup */ return () => { /* cleanup */ }; }, [deps])`.
- **Timing**: runs *after* render + DOM commit, not during render.
- **Deps array**: omitted → runs every render (rarely correct); `[]` → after mount only; `[a,b]` → after mount + whenever a/b change (`Object.is` compare).
- **Cleanup** is essential: clear intervals/timeouts, remove listeners, close connections/sockets, set `ignore` flags for fetches. Runs before each re-run and on unmount. Prevents memory leaks, stale state, race conditions.
- Each Effect = one independent synchronization process. 🔴 Don't bundle unrelated logic (e.g. analytics + connection) into one Effect just because they run together — split them (§11).

## §11 Effect lifecycle
- Think from the **Effect's perspective** (start syncing / stop syncing), not the component's (mount/update/unmount). Write how to start and how to stop; React calls them as needed.
- An Effect with deps re-synchronizes whenever a dep changes: cleanup (stop) with old values → setup (start) with new values.
- In dev, React mounts→unmounts→remounts once to stress-test that cleanup works. Make Effects resilient to being run repeatedly.
- Each Effect should represent one separate sync process; deleting it shouldn't break another Effect's logic. If it would, they belong together; if not, split.

## §12 Effect dependencies
- **Deps must match the code**: every reactive value read inside the Effect must be a dep. You don't *choose* deps — the code determines them.
- **Reactive values** = props, state, and anything computed from them in the component body (incl. functions/objects declared there). All must be deps.
- Non-reactive (omit/can't be deps): values outside the component, the `useState` setter and `useRef` object (stable), and `ref.current` / mutable globals (can't be deps — read via `useSyncExternalStore` instead).
- **To remove a dep, change the code so it's no longer reactive** — don't delete it from the array:
  - Read prev state via updater fn (`setX(prev => ...)`) instead of reading `x` → drops `x` dep.
  - Move static objects/functions **outside** the component.
  - Move dynamic objects/functions **inside** the Effect (so they're not reactive).
  - Read primitive fields out of an object before the Effect (`const {roomId, serverUrl} = options`) so deps are primitives, not the object.
  - Extract non-reactive reads into an Effect Event (§13).
- **Object/function deps are dangerous**: a new reference each render makes the Effect re-run every render. Primitives compare by value; objects/functions by identity.
- 🔴 Never suppress `react-hooks/exhaustive-deps`. Suppressing it causes stale-closure bugs. Treat the lint error as a compile error and fix the code (§18).

## §13 Events vs Effects
- **Event handler logic is non-reactive**: runs only on the specific interaction; can read latest reactive values without re-running. Put interaction-caused logic here (e.g. send message on click).
- **Effect logic is reactive**: re-runs whenever a read reactive value changes. Put "stay synchronized" logic here (e.g. connect to room).
- **useEffectEvent** extracts a non-reactive slice out of a reactive Effect — it always sees the latest props/state but does NOT trigger re-sync. Use it when part of an Effect shouldn't react (e.g. read latest `theme`/`isMuted`/`numberOfItems`/a prop callback inside a connection Effect).
  - Declared with `const onX = useEffectEvent(() => {...})`.
  - 🔴 Omit Effect Events from the deps array (they're non-reactive). 🔴 Only call them inside Effects; never pass to other components/Hooks. Declare next to the Effect that uses them.
- Use it to avoid suppressing the linter when you want "react to A but not B" (§12).

## §14 Custom Hooks
- Extract shared **stateful logic** (state + Effects + other Hooks) into a `useX` function. Components express intent (`useOnlineStatus()`) instead of implementation.
- **Naming**: must start with `use` + capital. A function that calls no Hooks should NOT use the `use` prefix (make it a plain function so it can be called conditionally).
- Custom Hooks share **logic, not state** — each call has its own independent state. To share state itself, lift it up (§3).
- Custom Hooks re-run on every render, get latest props/state, and must be **pure** like components.
- ✅ Name after a concrete high-level purpose: `useData(url)`, `useChatRoom(opts)`, `useMediaQuery(q)`. 🔴 Avoid generic lifecycle wrappers: `useMount`, `useEffectOnce`, `useUpdateEffect` (they hide reactivity from the linter and don't fit the model).
- When a custom Hook takes an event-handler arg, wrap it in `useEffectEvent` so it isn't a dep (§13).
- Wrapping Effects in custom Hooks makes data flow explicit and eases later migration (e.g. to `useSyncExternalStore` or `use`).

## §15 Performance
- Default: don't optimize. Add memoization only after identifying a real performance problem.
- **`useMemo(fn, deps)`** — cache an expensive calculation between renders; runs only when deps change; must be a pure calc. Don't help first render; helps updates. Measure with `console.time` before adding (significant ≈ ≥1ms; test on throttled CPU / production build).
- **`useCallback(fn, deps)`** — memoize a function reference, mainly when passing it to memoized children or as an Effect/Hook dep.
- **`React.memo(Component)`** — skip re-render when props are referentially unchanged; pair with stable props (useMemo/useCallback).
- **React Compiler (React 19)** auto-memoizes much of this — manual `useMemo`/`useCallback`/`memo` often become unnecessary. Still useful for very hot paths, function/object props, or libs relying on reference equality.
- Note: splitting one state object into several variables does NOT reduce re-renders by itself; any state change re-renders the component.

## §16 Architecture & mental model
- **Declarative > imperative**: describe *what* the UI should be for the current state; let React do the DOM ops. Use `map`/`filter`, conditional rendering, and state declarations instead of manual DOM mutation.
- **`react` vs `react-dom`**: `react` is the platform-agnostic core (components, elements/Virtual DOM, Hooks, state, context, refs); `react-dom` is the browser renderer (mounting, DOM diffing/commit, events). Split enables React Native, SSR, Server Components.
- **React Elements** are plain objects (`{$$typeof, type, key, ref, props}`) describing UI. JSX `<div/>` → `React.createElement('div', ...)` → element object. `type` is a tag string or a component reference. Reconciliation diffs these objects; keys identify list items.
- **Functional-programming principles** React leans on: first-class functions (handlers, render props, HOCs), pure functions (predictable/testable/skippable renders), immutability (reference-based change detection), composition (build complex UIs from small components; prefer composition + `children` over inheritance), currying (e.g. `action => id => e => …` handlers).

## §17 Build workflow (Thinking in React)
1. **Break UI into a component hierarchy** — one component per concern; JSON shape often maps to component tree.
2. **Build a static version** — render from props only, no state; one-way data flow. (Lots of typing, little thinking.)
3. **Find minimal state** — apply the §3 "is this state?" tests.
4. **Decide where state lives** — closest common parent of all consumers (§3).
5. **Add inverse data flow** — pass setters/callbacks down so child inputs update parent state (`onChange={e => onChange(e.target.value)}`).

## §18 Tooling
- ✅ Enable **StrictMode** (`<React.StrictMode>`) in dev — double-invokes renders and remounts Effects once to surface impurities and missing cleanup. No production effect.
- ✅ Use **`eslint-plugin-react-hooks`** — enforces Hook call rules (§5) and `exhaustive-deps` (§12).
- 🔴 **Never suppress the dependency linter** (`// eslint-disable-next-line react-hooks/exhaustive-deps`). It "lies" to React about what the Effect depends on and causes stale-value bugs. The linter only flags *wrong* deps, not the *best* fix — change the code instead (§12, §13). Treat lint errors as compile errors.
