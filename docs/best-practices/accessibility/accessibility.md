# Web Accessibility (WCAG 2.2) — Agent Reference

> Token-efficient, code-oriented digest of WCAG 2.2 success criteria (SC), from the W3C "How to Meet WCAG" Quickref. For LLMs writing/auditing web UI. Each SC: **number Name (Level) — rule. ✅ technique. 🔴 failure.** Levels: **A** = must, **AA** = standard legal target (meet A+AA), **AAA** = enhanced (rarely required wholesale). Load only the sections you need.

## How to use
- Use the **Task Index** to jump from what you're building to the relevant SC IDs.
- Then read those SC entries in §1–§4. Default to satisfying all **A + AA**.
- Prefer native HTML semantics over ARIA ("No ARIA is better than bad ARIA"). Add ARIA only to fill gaps.

## Task Index (build → check these SCs)
- **Image / icon / non-text**: 1.1.1, 1.4.5, 1.4.11, 1.3.3, 1.4.1.
- **Color & contrast**: 1.4.1, 1.4.3, 1.4.6(AAA), 1.4.11, 1.3.3.
- **Text & zoom/reflow**: 1.4.4, 1.4.10, 1.4.12, 1.4.8(AAA), 1.4.5.
- **Headings / structure / landmarks**: 1.3.1, 1.3.2, 2.4.1, 2.4.10(AAA).
- **Links**: 2.4.4, 2.4.9(AAA), 1.4.1.
- **Forms & inputs**: 1.3.1, 1.3.5, 3.3.2, 3.3.7, 2.5.3, 4.1.2, 1.4.1, 4.1.3.
- **Keyboard & focus**: 2.1.1, 2.1.2, 2.1.4, 2.4.3, 2.4.7, 2.4.11, 2.4.13(AAA), 3.2.1.
- **Custom widgets (div/span as control)**: 4.1.2, 2.1.1, 2.4.7, 1.4.11, 4.1.3, 2.5.3.
- **Pointer / touch / mobile**: 2.5.1, 2.5.2, 2.5.4, 2.5.7, 2.5.8, 1.3.4.
- **Motion / animation / flashing**: 2.2.2, 2.3.1, 1.4.2.
- **Tooltips / hover / popovers**: 1.4.13, 4.1.3.
- **Dynamic updates / toasts / errors / live**: 4.1.3, 3.3.7.
- **Timeouts / sessions / auto-refresh**: 2.2.1, 3.2.5(AAA), 2.2.6(AAA).
- **Media (audio/video)**: 1.2.1–1.2.5 (+AAA 1.2.6–1.2.9).
- **Navigation across pages**: 2.4.5, 3.2.3, 3.2.4, 3.2.6, 2.4.8(AAA).
- **Language**: 3.1.1, 3.1.2.
- **Authentication**: 3.3.8, 3.3.9(AAA).

---

## §1 Perceivable

### 1.1 Text Alternatives
- **1.1.1 Non-text Content (A)** — every img/icon/control/non-text element has an equivalent text alternative. ✅ `alt` on `<img>` (concise, purpose-equivalent); `aria-label`/`aria-labelledby` for SVG/icon controls; for controls, the alt/label states the control's *purpose*; complex images (charts) get a short alt + long description (`aria-describedby`/adjacent text). Decorative → `alt=""` (or CSS background) so AT ignores it. 🔴 Missing `alt`; `alt="image"`/filename/"spacer"; not updating alt when the image changes; decorative image left without null alt.

### 1.2 Time-based Media
- **1.2.1 Audio-/Video-only (Prerecorded) (A)** — provide a transcript (audio) or text/audio description (video). ✅ linked transcript adjacent to media. 🔴 alt that isn't a real alternative.
- **1.2.2 Captions (Prerecorded) (A)** — synchronized captions for all prerecorded audio. ✅ `<track kind="captions">`. 🔴 captions omit dialogue/important sounds.
- **1.2.3 Audio Description or Media Alternative (Prerecorded) (A)** — audio description **or** full text alternative for video.
- **1.2.4 Captions (Live) (AA)** — captions for live audio in synchronized media.
- **1.2.5 Audio Description (Prerecorded) (AA)** — audio description track for prerecorded video. ✅ `<track kind="descriptions">`.
- **AAA**: 1.2.6 Sign Language, 1.2.7 Extended Audio Description, 1.2.8 Media Alternative, 1.2.9 Audio-only (Live).

### 1.3 Adaptable
- **1.3.1 Info and Relationships (A)** — structure/relationships conveyed visually must be in the markup/programmatically determinable. ✅ semantic HTML: `<h1>`–`<h6>` for headings, `<ul>/<ol>/<dl>` for lists, `<table>` with `<th scope>`/`<caption>` for data tables, `<label>`/`<fieldset>`/`<legend>` for forms, landmarks (`<nav>/<main>/<header>` or ARIA landmark roles). 🔴 styling text to fake a heading; layout tables with `<th>`; `role="presentation"` on meaningful content; visible label with no programmatic association (F111).
- **1.3.2 Meaningful Sequence (A)** — reading/DOM order matches meaning. ✅ make DOM order = visual order; don't reorder meaning with CSS only. 🔴 whitespace-formatted columns/tables; CSS positioning that changes meaning.
- **1.3.3 Sensory Characteristics (A)** — don't rely solely on shape/size/location/color/sound ("click the round button on the right"). ✅ add a text label. 🔴 instructions by shape/location/symbol alone.
- **1.3.4 Orientation (AA)** — don't lock to portrait/landscape unless essential.
- **1.3.5 Identify Input Purpose (AA)** — set `autocomplete` on inputs collecting user info (name, email, tel…). 🔴 wrong autocomplete values.
- **1.3.6 Identify Purpose (AAA)** — programmatically expose purpose of components/icons/regions (landmarks, ARIA).

### 1.4 Distinguishable
- **1.4.1 Use of Color (A)** — color is never the *only* way to convey info/state/distinguish (errors, required, links). ✅ add text/icon/underline; links distinguishable without color or ≥3:1 + non-color cue on hover/focus. 🔴 required/error fields shown by color only; links not visually evident without color.
- **1.4.2 Audio Control (A)** — auto-playing audio >3s must have a pause/stop or volume control. 🔴 autoplay with no stop.
- **1.4.3 Contrast (Minimum) (AA)** — text contrast ≥ **4.5:1** (≥ **3:1** for large text: ≥18pt, or ≥14pt bold). 🔴 fg without bg color; low-contrast text over background images.
- **1.4.4 Resize Text (AA)** — text resizable to 200% without loss of content/function. ✅ relative units (em/rem/%), reflowing containers. 🔴 fixed px containers clipping zoomed text; viewport-unit-only text sizing.
- **1.4.5 Images of Text (AA)** — use real text, not images of text (except logos/essential). ✅ CSS-styled text.
- **1.4.10 Reflow (AA)** — no 2-D scrolling at 320 CSS px width (400% zoom). ✅ responsive CSS (flex/grid, media queries), `max-width`. 🔴 content lost/cut on reflow.
- **1.4.11 Non-text Contrast (AA)** — UI components (borders/states) and meaningful graphics ≥ **3:1** vs adjacent colors. Includes focus indicators. 🔴 invisible focus outline; low-contrast input borders/toggles.
- **1.4.12 Text Spacing (AA)** — no loss when user overrides line-height 1.5, paragraph 2x, letter 0.12em, word 0.16em. ✅ avoid fixed-height text containers. 🔴 clipped/overlapping text on spacing override.
- **1.4.13 Content on Hover or Focus (AA)** — hover/focus popups (tooltips, menus) are **dismissible** (Esc), **hoverable** (can move pointer onto them), **persistent** (stay until dismissed). 🔴 tooltip vanishes when moving toward it.
- **AAA**: 1.4.6 Contrast (Enhanced) 7:1, 1.4.7 Low/No Background Audio, 1.4.8 Visual Presentation, 1.4.9 Images of Text (No Exception).

## §2 Operable

### 2.1 Keyboard Accessible
- **2.1.1 Keyboard (A)** — all functionality operable by keyboard. ✅ use native `<button>/<a>/<input>`; for custom controls add `tabindex="0"`, role, and key handlers (Enter/Space/arrows). 🔴 pointer-only handlers (onclick on div without keyboard); `onmouseover`-only; script removing focus on receipt (F55).
- **2.1.2 No Keyboard Trap (A)** — focus can always leave a component via keyboard (standard keys, or documented exit). 🔴 modal/embed that traps Tab.
- **2.1.4 Character Key Shortcuts (A)** — single-character shortcuts can be turned off, remapped, or are active only on focus. 🔴 unremappable single-key shortcuts.
- **2.1.3 Keyboard (No Exception) (AAA)**.

### 2.2 Enough Time
- **2.2.1 Timing Adjustable (A)** — user can turn off/adjust/extend time limits (≥10x, or 20s warning to extend). 🔴 meta-refresh/redirect with time limit; server timeout with no extension.
- **2.2.2 Pause, Stop, Hide (A)** — moving/blinking/scrolling/auto-updating content >5s has a pause/stop/hide control. 🔴 carousels/marquees/auto-updates with no pause.
- **AAA**: 2.2.3 No Timing, 2.2.4 Interruptions, 2.2.5 Re-authenticating, 2.2.6 Timeouts (warn of inactivity data loss unless data kept >20h).

### 2.3 Seizures
- **2.3.1 Three Flashes or Below Threshold (A)** — nothing flashes >3 times/sec (or below flash thresholds; keep flashing area small). 🔴 content flashing >3x/sec.
- **2.3.2 Three Flashes (AAA)** — nothing flashes >3x/sec at all.

### 2.4 Navigable
- **2.4.1 Bypass Blocks (A)** — skip repeated blocks. ✅ "skip to main content" link; landmarks; headings. 
- **2.4.3 Focus Order (A)** — focus order preserves meaning/operability. ✅ DOM order = visual order; insert dynamic content adjacent to trigger; `<dialog>`. 🔴 positive `tabindex` breaking order; menus/dialogs detached from trigger in tab order.
- **2.4.4 Link Purpose (In Context) (A)** — link purpose clear from text (+ programmatic context). ✅ descriptive link text; `aria-label`/`aria-labelledby`; ensure an image-only link has an accessible name. 🔴 "click here"/"more" with no context; image link with no alt.
- **2.4.5 Multiple Ways (AA)** — ≥2 ways to find a page (nav, search, sitemap, ToC) — except steps in a process.
- **2.4.7 Focus Visible (AA)** — keyboard focus indicator is visible. ✅ keep/strengthen `:focus-visible` outline. 🔴 `outline:none` with no replacement (F78); removing focus on receipt (F55).
- **2.4.11 Focus Not Obscured (Minimum) (AA)** — focused component not *entirely* hidden by author content. 🔴 sticky header/footer fully covering focused element. ✅ `scroll-padding`.
- **AAA**: 2.4.8 Location, 2.4.9 Link Purpose (Link Only), 2.4.10 Section Headings, 2.4.12 Focus Not Obscured (Enhanced), **2.4.13 Focus Appearance** (focus indicator min area/contrast).

### 2.5 Input Modalities
- **2.5.1 Pointer Gestures (A)** — multipoint/path gestures have a single-pointer alternative unless essential. ✅ buttons replacing swipe/pinch. 🔴 path gesture with no simple-pointer alternative.
- **2.5.2 Pointer Cancellation (A)** — single-pointer actions complete on **up-event**; allow abort/undo (move off before release). 🔴 activating on down-event (F101).
- **2.5.3 Label in Name (A)** — a control's accessible name **contains** its visible label text (ideally at the start). ✅ match `aria-label` to visible text. 🔴 visible "Search" button whose accessible name is "submit" (F96) — breaks voice control.
- **2.5.4 Motion Actuation (A)** — motion-triggered functions also work via UI controls and motion can be disabled. 🔴 shake-only actions with no alternative.
- **2.5.7 Dragging Movements (AA)** — dragging operations have a single-pointer non-drag alternative (e.g. click targets) unless essential.
- **2.5.8 Target Size (Minimum) (AA)** — pointer targets ≥ **24×24 CSS px** (or sufficient spacing). ✅ `min-height`/`min-width`. 
- **AAA**: 2.5.5 Target Size (Enhanced) 44×44, 2.5.6 Concurrent Input Mechanisms.

## §3 Understandable

### 3.1 Readable
- **3.1.1 Language of Page (A)** — set `<html lang="…">`.
- **3.1.2 Language of Parts (AA)** — mark inline language changes with `lang` (except proper names/technical terms/vernacular).
- **AAA**: 3.1.3 Unusual Words, 3.1.4 Abbreviations, 3.1.5 Reading Level, 3.1.6 Pronunciation.

### 3.2 Predictable
- **3.2.1 On Focus (A)** — focus alone never triggers a change of context (no navigation/popup on focus). ✅ trigger on activate, not focus.
- **3.2.2 On Input (A)** — changing a control's setting doesn't auto-change context unless the user was warned. ✅ explicit submit button. 🔴 auto-submit on select change / new window on radio change (F36/F37).
- **3.2.3 Consistent Navigation (AA)** — repeated nav appears in the same relative order across pages.
- **3.2.4 Consistent Identification (AA)** — same-function components labeled/named consistently across pages.
- **3.2.6 Consistent Help (A)** — repeated help mechanisms (contact, chat) appear in consistent order across pages.
- **3.2.5 Change on Request (AAA)** — context changes only on user request.

### 3.3 Input Assistance
- **3.3.2 Labels or Instructions (A)** — provide labels/instructions for inputs. ✅ `<label for>`/wrapping label; `fieldset`+`legend` for groups; format hints/examples; mark required (`required`, text, or `aria-required`). 🔴 placeholder-as-label; visually grouped fields (phone) with no label (F82).
- **3.3.7 Redundant Entry (A)** — info already entered in a process is auto-populated or selectable, not re-typed (except passwords/security).
- **3.3.8 Accessible Authentication (Minimum) (AA)** — no cognitive-function test (memorize/transcribe/puzzle) required to authenticate, unless an alternative exists. ✅ allow paste/password managers, `autocomplete="current-password"`, WebAuthn/OAuth, email-link. 🔴 blocking paste on password (F109).
- **AAA**: 3.3.1 Error Identification, 3.3.3 Error Suggestion, 3.3.5 Help, 3.3.6 Error Prevention (All), 3.3.9 Accessible Authentication (Enhanced). *(Note: 3.3.3/3.3.4 error suggestion & prevention are AA in full WCAG 2.2 — confirm in spec.)*

## §4 Robust

### 4.1 Compatible
- **4.1.2 Name, Role, Value (A)** — every UI component exposes a programmatic **name**, **role**, and settable **states/values**, with change notifications. ✅ native HTML controls satisfy this automatically; for custom widgets use ARIA `role`, `aria-label`/`aria-labelledby` (name), `aria-checked`/`aria-expanded`/`aria-selected` etc. (state). 🔴 `<div>`/`<span>` made interactive via script with no role (F59); custom control with no accessible name (F68); state not exposed/updated (F79).
- **4.1.3 Status Messages (AA)** — status messages reach AT **without moving focus**. ✅ `role="status"`/`aria-live="polite"` for success/progress; `role="alert"`/`aria-live="assertive"` for errors/warnings; `role="log"` for sequential updates. 🔴 status only conveyed visually (F103); `role="alert"` on non-urgent content.
- *(4.1.1 Parsing was removed in WCAG 2.2 — obsolete; no action needed.)*

---

## Quick rules of thumb
1. Reach for native HTML elements first; they give role/name/keyboard/focus for free (satisfies much of 2.1.1, 4.1.2, 1.3.1).
2. Every interactive thing must be reachable, operable, and visibly focusable by keyboard (2.1.1, 2.4.7).
3. Never convey meaning by color/shape/position alone (1.4.1, 1.3.3).
4. Text contrast ≥4.5:1; UI/graphics/focus contrast ≥3:1 (1.4.3, 1.4.11).
5. Label every input; associate it programmatically; don't use placeholder as the label (3.3.2, 1.3.1).
6. Accessible name must include the visible label (2.5.3).
7. Don't trap focus; don't change context on focus/input without warning (2.1.2, 3.2.1, 3.2.2).
8. Announce dynamic changes via live regions, not focus stealing (4.1.3).
9. Support 200% zoom and 320px reflow with relative units and responsive CSS (1.4.4, 1.4.10).
10. Provide keyboard/pointer-simple alternatives to gestures, drag, and motion (2.5.1, 2.5.7, 2.5.4).

---

## Automated axe checks (SPEC-045)

The Vitest suite runs `axe-core` (via `vitest-axe`) against rendered routes and
components so the machine-detectable subset of these WCAG A/AA rules can't
silently regress. It runs under the normal `npm run test -w apps/portal` (CI
already gates on it); `npm run test:a11y -w apps/portal` runs only the axe specs.

**Adding a check for new UI:** co-locate a `*.a11y.test.tsx` next to the code and
call the shared helper:

```ts
import { expectNoA11yViolations, ROUTE_AXE_OPTIONS, COMPONENT_AXE_OPTIONS } from '../test/axe';

// A whole page (landmarks/heading-order enabled):
await expectNoA11yViolations(<MemoryRouter><MyPage /></MemoryRouter>, ROUTE_AXE_OPTIONS);

// A primitive rendered outside any landmark (region rule off):
await expectNoA11yViolations(<MyDialog open />, COMPONENT_AXE_OPTIONS);
```

The ruleset (WCAG `wcag2a`→`wcag22aa` tags) and the disabled rules live in one
place, `apps/portal/src/test/axe.ts`. Routes also assert exactly one `<h1>` + a
`<main>` via the DOM.

**What axe does NOT cover** — it complements manual testing, it doesn't replace
it. It can't see `color-contrast` (jsdom has no layout/computed style — verified
visually instead, per the design tokens), real `:focus-visible` rendering, true
focus order, screen-reader output, or whether copy/labels actually make sense.
Keep doing manual keyboard + screen-reader passes for those.
