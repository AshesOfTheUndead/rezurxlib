# Changelog

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
