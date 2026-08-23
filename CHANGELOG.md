# Changelog

## v5.0.0 "Trace" — Geometry, One Motion, Subtraction

This release stops adding effects and fixes the foundation. Answering the
three open questions up front: **zero-asset is a hard rule for defaults**
(`cfg.ShadowImage` is the opt-in escape hatch), **the competing effects are
actually deleted** (not just disabled), and the phases shipped **together**
as v5.0.0 because every change is internal or additive and the full suite
runs green — 167/167.

### Phase 1 — Geometry (the "looks bad" fixes)
- **Concentric radius law, enforced in code.** `radiusFor(parent, inset)`
  = parent − inset (clamped ≥ 0) for nested frames; `concentric(r, pad)` =
  r + pad for outset layers. No hand-derived UICorner values anywhere — a
  test now asserts every radius in the tree is a legal value.
- **Stacked-frame shadows killed.** Three semi-transparent frames always
  stair-step at the corners. Now ONE shadow instance: a concentric frame by
  default (zero-asset, uniform falloff) or a 9-slice ImageLabel when the
  developer passes their own `cfg.ShadowImage`. The accent ambient glow was
  deleted outright — Trace is the accent presence now.
- **Integer-snap everything.** Resting positions/sizes carrying a UICorner
  are whole-pixel offsets (`snapPx`); springs snap on write. Fractional
  offsets were the "not perfectly round at 2x zoom" artifact.
- **True pills.** `UDim.new(0.5, 0)` everywhere (keybind pills, footer
  badge) — height-relative, never a fixed offset fighting the height.
- **UIScale entrances banned.** Scaling a rounded frame re-rasterizes its
  corners every frame (visible crawl). The window now LANDS via Size
  springs (position derives from size, corner geometry stays CONSTANT); the
  card cascade is a page-rise + stroke flash with zero UIScale; every popup
  (picker, menu, palette, modal, key gate) enters via position + opacity.
  Press-dip and the toggle squish stay — they're feedback.
- **Corner bleed + stroke audit.** Strokes stay ≤ 1.5px, Border mode; the
  ripple mask owns clipping so nothing squares off a rounded parent.

### Phase 2 — Motion engine
- **Spring solver**: stiffness/damping integration on RunService delta
  (never wall-clock — executor tick() can disagree with render time).
  Interruptible and velocity-preserving by design: retargeting mid-flight
  continues from current momentum. Springs never write to destroyed
  instances (destroy-race guard, killed on window teardown).
- **Four motion tokens** — `instant` / `snap` (0.12 Quad) / `settle`
  (0.24 Quint) / `enter` (0.42 Back). Every legacy T-constant aliases a
  token, so the entire library collapsed onto four curves with zero
  call-site churn. No more ad-hoc Quart 0.26.
- **Motion budget**: hard cap of 12 concurrent springs; overflow snaps to
  the end state. An entrance cascade can never hitch a 30 FPS host.
- **Frame-time guard**: a Heartbeat EMA degrades motion to 0.5x scale
  silently when the host runs worse than ~30 FPS, and self-heals when
  frames recover. No user config.

### Phase 3 — Aurora Trace (the one signature)
A single accent light travels the window perimeter: a narrow bright band
in a UIGradient on the border stroke, driven by an interruptible spring on
Rotation. One instance, one spring, near-zero cost. Reused everywhere:
window entrance (full lap), tab switch (quarter lap toward travel),
successful action (accent lap), error / wrong key (the same lap in red).
**Deleted to make room**: the shockwave ring, button glow halos, spine
sweeps, section tick pulses, and header shimmer. Six competitors out, one
voice in. BackdropBlur is now documented honestly: it blurs the ENTIRE
game world (a global Lighting side effect), stays off by default, and is
reference-counted across windows so it's destroyed exactly when the last
user goes away.

### Phase 4 — Mobile as a first-class target
- **Density modes** (Compact / Comfortable), auto-selected from viewport
  and TouchEnabled; `cfg.Density` overrides. Row heights, paddings, and
  list gaps all read from one token set.
- **Sheet mode**: below ~500px viewport width the window becomes a
  near-fullscreen pinned sheet (viewport−16 × viewport−110, scale 1) with
  hysteresis at the boundary — no more shrunken desktop panel on phones.
- **44px minimum touch targets** on every interactive row (buttons,
  toggles, sliders, inputs, dropdowns, keybinds, context menus) and the
  resize handle.
- **ReducedMotion audit**: every Phase 2/3 animation gates on it — verified
  by test (entrance snaps, zero springs, Trace no-ops). Roblox exposes no
  platform reduced-motion setting to Luau; the manual default stands,
  documented as such.
- **DisplayOrder** exposed (`cfg.DisplayOrder`) — never silently maxed, so
  competing GUIs can deliberately bury the window.
- Viewport resizes mid-animation resolve geometry springs and re-clamp
  instead of fighting them.

### Phase 5 — Hygiene & maintainability
- **`.env` removed from the repo** (it was public; `DATABASE_URL` must be
  ROTATED — removal doesn't purge git history). Next.js scaffold,
  lockfiles, skills/, upload/, download/, tool-results/ all removed; the
  repo is the library and its docs.
- **Module split**: `src/` (core / themes / motion / helpers / window /
  api) + `scripts/build_bundle.py` emits the single-file bundle. The build
  is verified byte-identical to the monolith. Consumers see no change;
  editing stops being a monolith job.
- **Extended headless suite** (167 checks, up from 142): radius-law
  invariants across the whole tree, motion-budget cap, spring interruption
  semantics, reduced-motion coverage, sheet-mode geometry, blur refcount
  lifecycle, DisplayOrder passthrough, plus every prior regression
  (including the ReplaceExisting ghost-window fix).

### Migration notes (v4 → v5)
- **No breaking API changes.** All v4 configs still work.
- `AnimatedAccents` is a deprecated no-op (all ambient loops were removed).
- `BackdropBlur` still works but is documented as blurring the whole game
  world, not the window.
- Visual deltas: single soft shadow (no stacked layers), accent-filled tab
  chips with a sliding spring underline, position-based entrances (no
  scale pops), Trace replaces all decorative effects, rows are ≥44px tall,
  and phones get sheet mode automatically.
- New opt-ins: `ShadowImage`, `Density`, `DisplayOrder`.

---

## v4.4.0 — Prism: Pixel Fixes, Glow, Sound & Graphs

A forensic design review of three live screenshots (vision-model audited)
confirmed seven pixel-level flaws and unlocked a batch of high-tier
features. Everything below is fixed, built, and verified — 142/142 tests.

### Pixel-level fixes (from the screenshot audit)
- **Status bar squeezed against the bottom border**: STATUSBAR_H 24 → 30.
  The READY dot and version text now have real vertical breathing room
  clear of the R.outer corner curve.
- **Minimized-state orange stripe**: minimizing left the header glow strip,
  accent line, and footer mask visible — a floating orange line and a
  panel-colored band beneath the header instead of clean rounded corners
  (ClipsDescendants clips to the RECT, not the UICorner, so full-width edge
  lines poked past the curve). All three decorations now hide on minimize
  and restore on expand.
- **"Black empty chip" at the tab rail's left edge + vertical misalignment**:
  the old full-size indicator pill was retired entirely. The active-tab
  indicator is now a 3px accent-gradient UNDERLINE that slides beneath the
  active chip on a fixed strip (y stays at 35 — never drifts). Exactly the
  "sliding indicator bar beneath tabs" requested, with Back easing.
- **FPS/Ping divider off-center**: FPS text is now right-aligned to hug the
  divider and ms text left-aligned to hug it from the other side (7px insets
  each) — the divider reads centered regardless of text width.
- **Section rule gap inconsistency**: section headers rebuilt on a
  horizontal UIListLayout — tick → title → rule with a fixed 8px gap. The
  rule now starts at exactly the same distance from every title ("ENGINE"
  and "PROFILES" match).

### Dynamic visual depth & lighting (as requested)
- **Button glow halos**: every button carries a soft accent halo extending
  7px past its rect. It fades in on hover; primary buttons keep a faint
  resting glow. Implemented via a dedicated ripple mask (clip moved off the
  button itself) so halos escape the card while ripples still clip cleanly.
- **Glassmorphism backdrop blur** (opt-in, `BackdropBlur = true`): a
  BlurEffect in Lighting frosts the game world behind the window while it
  is open; the UI renders above post-processing so only the backdrop
  blurs. Tweens in/out with show/hide, Janitor-cleaned.
- **Animated accent light strips**: section ticks now carry a vertical
  accentHi→accentDim gradient with a slow top-to-bottom Offset pulse (when
  AnimatedAccents is on), and button spines fire a one-shot gradient sweep
  on hover — "glowing indicators," as requested.

### High-end micro-interactions (as requested)
- **Toggle squishy spring physics**: the thumb now STRETCHES to 22x15 while
  it travels and springs back to 18x18 with a Quart settle — pulled-taffy
  feel instead of a plain shrink.
- **Min/close hover polish**: both window controls scale to 1.08x on hover;
  the minimize button gains an accent glow ring, and its stroke lights up.
- **Button hover**: stroke thickens to 1.5px in addition to the existing
  raise, arrow slide, and spine grow.

### Advanced features (as requested)
- **CreateGraph** — a live sparkline element: `:Push(value)` appends samples
  to a scrolling window (8–64 bars), or pass `Sample = function() … end`
  with `RefreshRate` for auto-polling. Auto-scales or takes a fixed `Max`,
  shows the latest value with an optional suffix, and color-fades older
  bars. Perfect for "$ Earned/min over time".
- **UI sound design** (opt-in, `Sounds = true` or a config table): crisp
  pitched feedback for tabs, toggles, buttons, and notifications. Defaults
  use engine-local `rbxasset://` assets — zero marketplace dependencies —
  with full per-action override support.
- **Quick-access keybind badge**: the footer now shows a live `[K] HIDE`
  pill that updates when `SetToggleKeybind` changes — the toggle shortcut
  is discoverable without reading any docs.

### Robustness
- `motionScaleFor` (the tween motion-preference walker) now guards against
  non-Instance ancestors — tweening service-parented objects (e.g. the new
  BlurEffect) no longer errors.

### Verified
- New tests: underline indicator geometry and strip-lock after switching,
  minimize decoration hiding/restoring, sounds+blur window lifecycle,
  graph push/cap/reset/geometry/bar heights, keybind badge default +
  rebind update, glow halos on both button variants + hover fade in/out.
  Mock harness extended (SoundService, Lighting, BlurEffect, Sound,
  UIGradient.Offset, EnumItem.EnumType). **142/142 passing.**

---

## v4.3.0 — Spice

Feedback: "these buttons look boring as hell… nothing special, no spice, no
flavour." A design audit of the live screenshot confirmed it — flat cookie-
cutter cards, zero depth on buttons, and an active tab distinguishable only
by transparency. Fixed on all three fronts.

### Active tab = accent highlight (as requested)
- Clicking a tab now fills it with the theme's accent color: a solid accent
  chip, white **GothamBold** text, and a bright accentHi stroke. Inactive
  tabs remain quiet dark chips (medium weight). The selected tab is
  unmistakable at a glance.
- Renders exactly the theme accent: the chip's gradient is a white identity
  (UIGradient multiplies with BackgroundColor3, so the fill color is carried
  by the background, never double-darkened by a tint).

### Buttons — redesigned with a signature
- **Accent spine**: a 3px rounded accent bar hugs the left edge of every
  button. On hover it lights up and grows (20→28px). This is the library's
  visual signature — no more anonymous gray slabs.
- **Hover raise**: buttons scale to 101.5% on hover and settle back — a
  physical "pick me up" cue (UIScale only, layout untouched).
- **Arrow slide**: the "›" chevron is bigger (15px), slides further on
  hover, and turns accent.
- Label inset widened to clear the spine.

### Section headers — typographic hierarchy
- Each section now leads with a small accent tick, and a gradient rule
  (accent → transparent) sweeps right from the title. Headers read as
  structure, not floating uppercase text.

### Rendering-safety note
- Secondary buttons intentionally stay solid-filled: the spine, raise, and
  chevron carry the flavor without risking gradient×background
  multiplication artifacts.

### Verified
- New tests: active-tab accent fill + white bold text + font-weight
  transitions on switch, accent spine / section rule / section tick
  presence, hover raise (1.015) and settle. **120/120 passing.**

---

## v4.2.0 — True Curves & the Jackpot Entrance

Two directives from the field: the curves were wrong, and opening the menu
should feel like pure dopamine. Both delivered.

### Curves fixed (geometrically)
- **Concentric shadow layers**: a layer extending `pad` px beyond a rounded
  rect must use radius `r + pad` (the parallel-curve law). The old values
  (+13/+7/+3 for pads 18/9/4) under-curved every layer, pinching the
  window's corners into a stepped wedge. Now +18/+9/+4 — the shadow flows
  in a smooth parallel curve off the window edge.
- **Ambient accent rim** made concentric (+13 for its 13px pad; was +8).
- **Key-gate card glow** made concentric (+12 for its 12px pad; was +8).
- **True pills**: keybind and bindable pills now use radius 12 (half the
  24px pill height; was 6 — they read as square chips). Roblox clamps the
  radius to half-height, so the 20px bindable pill rounds perfectly too.
- **Unified radius scale**: `small` 7→8, `tab` 9→10, aligned with
  `control` 10 — one consistent curve language across every element.

### The Jackpot entrance (dopamine choreography)
- **Spring landing**: the window now enters at 0.92 scale with a Back
  overshoot — it *lands*, it doesn't fade (was a whisper-soft 0.97 Quint).
- **Accent-line ignition**: the gradient strip under the header sweeps
  from 0 to full width like a lightsaber ignition the moment the window
  arrives.
- **One-shot shockwave**: an accent ring expands from behind the window
  and dissipates (0.55s, self-cleaning) — the "jackpot" burst.
- **Reward cascade on every tab open**: cards now pop at 0.94 with a Back
  overshoot (was a subtle 0.98 Quint settle), each card's stroke **flashes
  the accent color** as it lands, and the whole page rises 12px into place.
- **Reveal pop**: re-showing the window (toggle key, float icon tap)
  replays a spring landing plus a fresh card cascade — opening the menu
  is a reward every single time, not just the first.
- **Snappier loading**: wordmark now pops in with a scale bounce, and the
  whole sequence tightened to ~0.75s so the reveal lands sooner.
- Key-gate unlock plays the full entrance — entering a correct key feels
  like winning.

All new motion respects `ReducedMotion` (skipped entirely when set), and
the shockwave/ignition are one-shot — no idle loops.

### Verified
- New tests: concentric radii for all three shadow layers + ambient rim,
  shockwave self-cleanup, glow-strip ignition end-state, reveal-pop settle,
  page-rise rest position, true-pill radius. **106/106 passing.**

---

## v4.1.0 — Smoothness & Final Polish

The final pass: one real performance fix, snappier interactions, and entrance
animations for every surface that used to pop in instantly. 92/92 tests.

### Performance
- **FPS label repaint throttled to 4Hz** (was every frame): writing
  `fpsLabel.Text` 60+ times per second forced a full text re-layout each
  frame — a measurable cost on low-end devices for a chip nobody reads at
  60Hz. The EMA still integrates every frame, so the number stays accurate;
  it just repaints at most 4x per second and only when the rounded value
  changed. In tests: ~120 text writes over 120 frames dropped to <= 8.

### Snappier interactions
- **Toggle timing**: knob 0.45s → 0.26s, track 0.80s → 0.30s. The switch now
  completes before your finger leaves it; the track no longer lags behind
  the knob.
- **Button micro press-feedback**: buttons dip to 97% scale on press and
  spring back with a Quint ease on release (0.06s in / 0.16s back) — a
  physical, snappy feel with zero layout shift (UIScale only).

### Entrances (previously instant → now choreographed)
- **Modal dialog**: scrim fades in (0.18s) while the card settles from 96%
  scale with a soft Back ease.
- **Color picker popup**: springs from 94% scale, anchored on the swatch it
  opened from.
- **Context menu**: unfolds from its trigger button at 95% scale.
- **Command palette**: scrim fade + a 97%-scale drop-in settle.
- **Notification**: entrance refined (0.3s Back) so the toast reads as
  arriving rather than growing.

### Verified
- New tests: FPS throttle write-count, press-scale dip/restore, modal
  entrance end-state, picker entrance, toggle timing regression, plus a fix
  to the test harness's signal Disconnect mock.
- Full suite: **92/92 passing**.

---

## v4.0.1 — Feedback Pass on the Visual Direction

User feedback on v4.0.0: the cursor glow was weird, the frosted-glass card
sheens looked bad, and the always-running effects read as noise. This release
removes the gimmicks and keeps the class.

### Removed
- **Cursor glow** (entire system): the three-ring accent light that followed
  the pointer is gone — it read as a gimmicky blob rather than ambience.
- **Frosted-glass card sheens**: the white top-light overlay on every element
  panel washed out card colors on dark themes. Cards are back to the clean
  two-stop surface gradient.
- **Window glass edge highlight**: the 1px white gradient hairline inside the
  window border.
- **Header shimmer sweep**: the diagonal light band gliding across the title
  bar every ~6 seconds.
- **Living header gradient**: the slow back-and-forth rocking of the header
  gradient's rotation — the header is a stable surface again.
- **Primary-button sheen sweeps**: light bands no longer sweep across accent
  buttons on hover/click; the ripple and color states remain.

### Reverted
- **`AnimatedAccents` is opt-in again** (v3 behavior, `= true` to enable).
  With it on by default, the logo-glow pulse and glow-strip shimmer ran
  constantly; now the resting UI is still unless you ask for motion.

### Tuned
- **Depth shadows tightened**: the three layers now hug the window (18/9/4px
  pads at 93.5/88/78% transparency, up from 30/16/7px at ~95/92/84.5%) so the
  shadow reads as real depth instead of a wide gray halo.
- **Accent rim tightened**: the ambient accent glow shrank from a 70px halo
  to a 26px rim hugging the window edge.
- **Entrance softened**: 0.97→1.0 over 0.34s (was 0.94→1.0 over 0.42s) — a
  whisper of motion instead of a pronounced pop.
- **Stagger softened**: cards settle at 2% scale with a smooth Quint ease and
  an 18ms cascade (was 3.5% with Back easing at 22ms) — an elegant settle,
  not a bounce.

### Kept
- Layered shadows with drag/resize "lift" depth cue
- Spring entrance and staggered tab openings (subtler now)
- Click ripples, hover states, sliding tab indicator
- All v4.0 features: icons, ConfigurationSaving, KeySystem, all 22 bug fixes

Tests updated accordingly — 80/80 passing.

---

## v4.0.0 "Aurora" — Glass + Glow Edition

The largest release in RezurXLib history: a full visual overhaul, three flagship
Rayfield-parity features, and 22 bug fixes — every one of them verified by a new
82-test headless integration suite.

---

### ✨ Features

#### Glass + Glow visual direction
- **Layered depth shadows**: the window now sits on three stacked, increasingly
  transparent halos that read as a soft gaussian blur (no image assets). Dragging
  or resizing deepens the shadow for focus ("lift"/"rest" states).
- **Frosted glass cards**: every element panel carries a top-light sheen frame
  (white gradient, ~10% opacity, dissolving downward) beneath its content.
- **Glass edge highlight**: a 1px-inset gradient hairline on the window catches
  light along the top edge and fades toward the bottom.
- **Living header gradient**: the title-bar gradient's rotation slowly rocks
  between 78° and 124° so the surface reads as lit glass.
- **Header shimmer sweep**: a soft diagonal light band glides across the title
  bar every ~6.4 seconds.
- **Spring entrance**: windows materialize with a Back-eased scale from 0.94
  plus a coordinated fade of every depth layer.
- **Staggered tab entrances**: up to 16 cards settle in sequentially (22ms
  stagger, Back easing) each time a tab opens — implemented with per-element
  UIScale so the UIListLayout keeps owning positions.
- **Cursor glow**: a three-ring accent light follows the pointer on desktop,
  brightens on mouse-down, settles on release, and breathes at idle. Hidden on
  touch-only devices and under ReducedMotion; `CursorGlow = false` opts out.
- **Primary button sheen**: hovering or clicking an accent-variant button
  sweeps a light band across it.
- **Animated accents are now ON by default** (`AnimatedAccents = false` to
  opt out; everything remains gated behind ReducedMotion).

#### Icon support (Rayfield-style, offline)
- `CreateWindow({ Icon = … })`: number asset ids and `rbxassetid://`,
  `rbxasset://`, `rbxthumb://` URIs render as an image inside the header badge;
  emoji/text values keep the text badge. The floating restore button mirrors
  the image automatically.
- `Window:CreateTab(name, icon)`: same resolution for tab chips — an 18px
  image with the title shifted right, or the previous emoji-prefix text.
- **Element icons** (beyond Rayfield, which stops at topbar/tabs): optional
  `Icon = …` on Buttons, Toggles, Sliders, Inputs, Dropdowns, Keybinds, and
  Color Pickers, rendered as an 18px ImageLabel with the label inset.
- No remote icon atlas is ever downloaded — the trust boundary is intact.

#### Configuration auto-save
- New `ConfigurationSaving = { Enabled, FolderName, FileName, Autosave,
  SaveOnUnload, Notify }` window config; `.rezx` JSON files under
  `RezurXLib/Configurations/` (or your `FolderName`) on executors with
  filesystem support.
- Elements with a `Flag` persist: toggles/inputs (CurrentValue), sliders,
  dropdowns (CurrentOption, incl. multi-select), keybinds (by name), color
  pickers (as {R,G,B}).
- **Signature-diffed autosaving**: a 2-second loop compares a stable
  serialization of all flagged values and writes only on real change — no
  Rayfield-style per-click rewrite storms.
- **Per-window isolation**: each window saves/loads its own flag registry, so
  multiple windows never cross-contaminate configs.
- Load replays through each element's `:Set` (callbacks fire, `false` and
  Color3 values preserved) and **waits for the key gate** when one is active.
- `Window:SaveConfiguration()` / `Window:LoadConfiguration()` for manual
  control; flush-on-destroy via `SaveOnUnload`.
- Filesystem access is entirely pcall-guarded and degrades to a no-op in
  environments without `writefile`/`readfile`/`isfile`.

#### Key system
- New `KeySystem = true` + `KeySettings = { Title, Subtitle, Note, FileName,
  SaveKey, GrabKeyFromSite, Key, MaxAttempts, OnExhausted }`.
- A styled unlock card (library's own design language — no external ScreenGui
  asset fetch): dimmed backdrop, accent-glow card, spring-in animation,
  note text, input, and unlock button.
- Exact-match validation (Rayfield uses substring matching for saved keys —
  this is stricter); elastic shake + red stroke flash on wrong keys; attempt
  counter with color escalation.
- Exhaustion policy: `"Lock"` (default — input disabled with a message;
  no player Kick unless you ask), `"Kick"`, or `"None"` (reset counter).
- `GrabKeyFromSite` fetches raw key URLs via `game:HttpGet` when explicitly
  enabled — the library performs zero network operations otherwise.
- Saved keys (`RezurXLib/Keys/<FileName>.rezx`) skip the gate entirely; the
  window's entrance animation defers until the gate passes.
- Enter submits from the input; the input auto-focuses on desktop.

#### Mobile
- Resize grip hit area enlarged to 40×40 (visible grip unchanged).
- Searchable dropdown popups no longer self-destruct when the on-screen
  keyboard resizes the viewport (focus grace window).
- ReducedMotion / MotionScale attributes mirrored onto the popup layer so
  dropdowns, pickers, modals, and the command palette honor them.

---

### 🐛 Fixes

**Critical**
1. **ReplaceExisting left zombie windows**: destroying only the previous
   ScreenGui instance never ran the old Window's Janitor — its
   UserInputService connections survived forever (keybinds fired twice, the
   FPS heartbeat wrote to a dead label, a mid-flight drag kept erroring
   against destroyed widgets). The old Window object is now found via
   `Library._windows` and destroyed properly.
2. **`Library:Destroy()` skipped every second window**: `w:Destroy()` removes
   each entry from `_windows` while `ipairs` walks it. Now iterates backwards.

**High**
3. **Resize read `minimized` as a global** (the local was declared 200+ lines
   below the resize closure), so a resize started before minimizing fought
   the minimize tween and any stray global named `minimized` hijacked resize.
   `minimized` is now forward-declared before the resize handler.

**Medium**
4. **Popups closed mid-drag stranded the drag session**: closing a color
   picker (second finger on Done, catcher tap, or hiding the window) while
   dragging its pad left `activeDrag` pointing at destroyed instances — every
   mouse move kept firing the live-color callback. `closeCurrentPopup` now
   ends any active drag before cleanup.
5. **ColorPicker fired the live callback on open**: rendering was split from
   notification; opening a picker no longer triggers side effects (nor the
   HSV round-trip color shift).
6. **Searchable dropdowns died on mobile keyboards**: focusing the search box
   summons the keyboard → viewport resizes → `uiScale` changes → the popup's
   close-on-scale listener destroyed it mid-typing. A 1.25s grace window now
   arms around focus.
7. **Destroyed elements kept their flags**: `registerFlag` now wraps the
   element's `Destroy` to deregister from both `Library.Flags` and the
   window's registry — `GetFlag` and `SaveConfiguration` no longer report
   stale values from dead elements (and any showing tooltip is hidden).
8. **`Window:Notify({ Duration = "8" })` threw** `invalid argument #1` from
   `task.delay` straight into caller code. Duration is coerced and clamped.
9. **Tooltip lifecycle holes**: tooltips now hide when their owner element is
   destroyed (`holder.Destroying`), skip rendering when detached from the
   hierarchy, and clamp/flip within the viewport instead of rendering fully
   off-screen near edges.

**Low**
10. **Ripples mixed physical and logical pixels**: `AbsoluteSize` is
    post-`uiScale` while ripple offsets are pre-scale — ripples landed
    off-center and clipped on phones. Now scale-aware.
11. **`uiScale` was captured as a global** by helpers defined above its
    declaration (ripple) — forward-declared so scale math actually applies.
12. **Floating-icon drags froze the viewport bounds** captured at press time;
    rotating/resizing mid-drag could drop the icon outside the new viewport.
    Bounds and overlay scale are re-read on every move.
13. **Retitled tab chips measured 8px narrower** than at creation (padding
    `+28` vs `+36`), clipping emoji-bearing retitles. Consistent now, with
    the icon lane included.
14. **Carousel animated fades never rendered**: the fade-in tween was created
    in the same frame as the fade-out, and the central tween manager replaces
    same-property tweens. Fades are now sequenced with a 110ms delay.
15. **Slider initial values ignored `Increment`**: `CreateSlider({ Increment
    = 0.25, CurrentValue = 0.3 })` displayed 0.3 until the first drag snapped
    it. The initial value is snapped through the same `snap()` as drags.
16. **`dropdown:Set({ Value = "x" })` with a fresh table silently failed**
    (identity comparison only). Common record fields are now matched.
17. **Escape couldn't close the command palette while its input was focused**
    (game-processed gate ran first). The palette check runs before the gate.
18. **TextArea validation errors inverted**: `valid and nil or reason` always
    evaluates to `reason`, so the error state showed even for valid input.
    Corrected to `(not valid) and reason or nil` (2 occurrences).
19. **Motion preferences ignored by the popup layer**: the overlay ScreenGui
    never carried the `RezurXReducedMotion` / `RezurXMotionScale` attributes,
    so dropdown/picker/modal/palette tweens ignored accessibility settings.
20. **Unknown theme names lied**: `GetThemeName()` reported the bogus name
    while the Quiet palette rendered. Now warns and keeps the current theme.
21. **Button/Toggle `obj:Set(nil)` threw** on the raw assignment; coerced via
    `tostring(newName or nameText)`.
22. **Stuck drags when the OS swallows the release** (gesture navigation,
    notification shade, releasing outside the Roblox window): added a
    `TouchEnded` listener mirroring InputEnded plus a 30-second heartbeat
    watchdog that retires stale sessions.

---

### 🧪 Quality Infrastructure
- New headless integration suite (82 checks) runs the entire library under a
  mocked Roblox API with a cooperative task scheduler: window creation and
  entrance, all 26 element types, mouse + touch drag simulation (including
  TouchEnded-only release and popup-close-mid-drag), notifications with
  non-number durations, minimize/hide/toggle-keybind, theme switching and
  fallback, modal + command palette, ReplaceExisting ghost-window behavior,
  multi-window `Library:Destroy`, ConfigurationSaving save/load/autosave/
  isolation, key-gate flows (wrong attempts, correct key, saved-key skip,
  GrabKeyFromSite), icon rendering, stagger animation, reduced-motion mode,
  custom themes, and a warning scan for drag failures.
- Library syntax validated with `luau-compile` after every change batch.

---

### 🔄 Compatibility
- **100% backward compatible**: all v3.2 APIs behave identically; v4.0
  additions are strictly additive opt-ins. Existing scripts run unchanged.
- Version bumped to `4.0.0`; `Library:GetDocs()` extended with the new
  `New` section covering icons, config saving, the key system, cursor glow,
  and the Glass + Glow direction.
