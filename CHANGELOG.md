# Changelog

## v5.8.1 — "Lumen" + visual repair pass

Recovers and finishes the v5.8 "Lumen" tree (register refactor, profile
system, tab drag-reorder, glass accents) and repairs the three visual
defects reported against it: hard-edged shadows, the dead green restore
dot, and the straight top accent line poking past the window's rounded
corners.

**The three reported visual defects:**
- **Shadows.** The v5.8 rewrite shipped a degenerate 9-slice shadow —
  `SliceCenter 128,128,128,128` is a zero-area center, so the middle
  stretched from a single texel into a hard-edged near-black slab around
  the window, and the flat fallback re-used the image constants after the
  entrance, leaving it permanently darker than its own rest state.
  Restored the soft-falloff geometry: a 256px asset whose outer 64px band
  carries the falloff (proper `SliceCenter 64,64,192,192`), pad 14, rest
  transparency 0.80, drag-lift 0.64. When the texture cannot load
  (offline executor / moderated asset) the shadow retires to a flat
  concentric Frame resting at a **literal 0.86** (`SHADOW_REST_FLAT` —
  derived `0.80 + 0.06` evaluated to 0.8600000000000001 in IEEE 754 and
  every downstream equality check saw the epsilon-off value). One
  constant set now feeds creation, entrance, drag-lift, and the 1s
  watchdog; `cfg.ShadowImage` still overrides the asset for custom
  9-slice-ready art.
- **The green restore dot.** It was a no-op whenever the window was
  already shown and expanded, and its glyph was two 4x2 arms that never
  met — a 2.6px gap at the vertex, parked low in the dot, pointing DOWN
  (a collapse cue on an expand control). It is now a true toggle
  (hidden → show, minimized → expand, expanded → collapse) and the glyph
  is a centered up-chevron: 6x2 arms sharing the apex at top-center. The
  glyph container is center-anchored and `setMinimized` spins it 180
  degrees, so the chevron always points where the next click takes the
  window — up ("collapse to pill") when expanded, down ("expand back")
  when minimized.
- **The straight top accent line.** `TopEdgeAccent` spanned the FULL
  frame width, but `ClipsDescendants` clips to the rect, not the
  `UICorner` — the 2px bar poked ~12px past the 20px corner curve on
  both sides, reading as a hard red ledge on Lava (worst on the
  minimized pill, where the radius is a large share of the height). The
  strip now starts and ends exactly where the corner arcs begin
  (`Size (1, -2*R.outer, 0, 2)` at `x = R.outer`); the frame stroke
  carries the accent around the curves, so the top reads as one sealed
  edge — on the full window and on the minimized pill alike.

**Silent runtime errors fixed:**
- **Header double-click minimize** (new in v5.8) errored on every
  double-click: the handler was wired at the dragBar, above
  `setMinimized`'s declaration, so it resolved to a nil global. Now
  wired after the declaration as a second `InputBegan` connection — the
  drag router only engages after 5px of movement, so a clean
  double-click never fights it.
- **The configuration-restored toast** crashed its delayed thread: the
  file-scope configuration builder referenced `notify` as a nil global
  (the v5.8 extraction moved the code out of `CreateWindow`'s scope).
  The builder now receives the notifier explicitly.

**v5.8 "Lumen" feature set (recovered and completed):**
- **Profile system.** Multi-slot flag profiles (default slots A/B/C):
  snapshot all flagged elements, persist to `RezurXLib/Profiles/<window>
  [slot].rezx`, apply back with live callbacks, per-slot "has data"
  indicator dots. File-scope builders keep CreateWindow under Luau's
  200-local register ceiling.
- **Tab drag-reorder** — grab a tab chip and drag it to a new position.
- **Glass accents ("Lumen"):** living accent sheen on the window title,
  breathing glow on the active tab indicator, lit top edges on
  notifications and cards, a one-shot radial entrance bloom, and a soft
  halo behind armed toggles.
- **Icon defaults:** windows and tabs without an explicit icon now draw
  a vector fallback (a "gem" mark for windows; name-derived for tabs) —
  no more empty squares.
- **Chrome simplification:** the header glow strip and the header/body
  accent line were removed — a single `TopEdgeAccent` carries the
  accent, and the header/body boundary is the header gradient itself.

**Verification:** 318 headless checks + 34 targeted fix checks, all
passing; `luau-analyze` clean (Roblox globals excepted); bundle
byte-identical to the src/ modules; RMAX UI block loads clean (frame
visible, zero warnings).

## v5.7.1 — "Aurora" hotfix + advanced key system

Built on the uncommitted v5.7.0 "Aurora" working tree (icon engine,
backdrops, throw physics, horizontal tab strip), this release makes that
tree actually compile, then lands the full audit fix list and the
advanced key system.

**Critical fixes:**
- **The bundle did not compile.** Luau's 200-local register ceiling was
  exceeded inside CreateWindow (the old inline key-gate do-block was the
  straw). The gate now lives in its own ctx-packed `buildKeyGate(ctx)`
  function — CreateWindow drops ~25 locals and the bundle compiles clean.
- **`glowStrip` was an accidental global** (the forward local went
  missing in the v5.7.0 refactor): two windows shared one header glow
  strip and hiding one window toggled the other's. Now a proper local.
- **Hold-style keybinds read `kbSurf` as a nil global** on release — the
  local lived only inside the InputBegan closure. The release path now
  builds its own SafeCallback surface (fresh theme colors per event).

**Advanced key system (replaces the stock gate):**
- **Providers**: up to 4 link providers rendered as a 2x2 grid on the
  gate card. Tapping copies the link (executor `setclipboard` when
  present) and flips the row to a check. `RequireProviderVisit = true`
  refuses redemption until at least one provider link was copied.
- **Pluggable backends** — validation chain at redeem time:
  1. `Backend.Validate = function(key) return ok, reason end` (custom)
  2. static key whitelist (`Key` / `Backend.Keys`, incl. legacy
     `GrabKeyFromSite` fetches)
  3. `Backend.Endpoint` — HTTP backend via the executor's `request`
     (custom `EndpointMethod` / `EndpointHeaders` / `EndpointBody` /
     `EndpointParse`; default POSTs `{key, hwid}` JSON and accepts
     `valid`/`success`/`ok` replies)
- **HWID binding**: `Backend.HwidLock = true` stores `{Key, Hwid,
  SavedAt}` as JSON; the boot pre-check auto-passes only when the device
  matches. A tap-to-copy HWID chip renders on the card while locked.
- **Async redeem**: validation runs in `task.spawn` with a "Checking…"
  busy state; the card can never freeze mid-check. Legacy raw-string
  saves still auto-pass (the reader understands both formats).
- Honest note preserved from the design: everything client-side is
  bypassable by a determined executor user — the Endpoint backend is the
  real gate; keep the unlock decision server-side.

**Audit fixes (F1-F15):**
- Chat-safe input gate: `inputBusy()` (drag / rebind / focused textbox)
  now backs the toggle key, Keybind, AND Bindable listeners — bindings no
  longer misfire while the user is typing in chat or any input field.
- Dropdown chevron keeps its center anchor (rotations spin in place, the
  glyph stays centered); dropdown selected-checks and key-gate step
  checks are drawn vector glyphs, not font-dependent "✓" text.
- Content edge fades (top 14px / bottom 18px) — cards no longer
  hard-clip at the scroll bounds; covered by new suite checks.
- Restore ball hover: accent halo ring + face brighten (was the last
  control without hover treatment).
- Command palette results render the tab's own icon next to the name.
- Duplicate `logo.TextStrokeTransparency` assignment removed.
- (F1/F3/F4/F5/F11/F14 — motes scope, https icon URIs, center anchors,
  net-image fallback path, content fades, aurora pulse wiring — were
  already present in the working tree and are now verified by tests.)

**Tests:** 318 passed, 0 failed (was 287 at v5.6.0). New: TEST 32
(22 checks) covering the provider grid cap + card growth, the
RequireProviderVisit refusal, custom-validator unlock, HTTP endpoint
denial reason + unlock + POST body shape, the HWID chip, the JSON save
envelope, same-HWID reboot skip, and different-HWID re-gate. Geometry
tests rewritten for the v5.7.0 horizontal tab strip; mock updated with
StarterGui/ContentProvider services.

## v5.7.0 — "Aurora" (uncommitted working tree, finalized in 5.7.1)

- Image-first icon engine with drawn-vector fallback: asset ids, rbx
  asset/rbxthumb/http URIs, `Library:RegisterIcon` names, and a built-in
  24x24 vector glyph table — zero assets and zero requests for the
  default icon set. HTTP icons stream through the NetImage pipeline
  (executor filesystem cache + `getcustomasset`) with a breathing glyph
  fallback while loading.
- Customizable window backdrop: `Backdrop = { Mode = "theme"|"image"|
  "gradient"|"aurora", ... }` with parallax on drag, settle on release,
  reveal on entrance, and a blob pulse on every tab switch.
- Throw physics + edge snap on the window drag.
- Horizontal top tab strip (38px, X-scrolling, measured-width chips)
  replacing the v5.6 sidebar rail; content edge fades; R.outer 16 -> 20.
- Universal task shim + environment probe (studio/executor/client) and
  a re-run guard handing back an already-exported identical Library.

## v5.6.0 — "Magma Cross": visual hybrid of Maclib + Rayfield Gen 2

A deep visual port that crosses the Maclib macOS sidebar-window idiom
with Rayfield Gen 2's clean accent geometry, themed in the RezurX lava
palette and branded with the RezurX wordmark. Every line of Luau is
original RezurXLib source implementing the hybrid visual spec — no
verbatim code from either reference library.

**Visual changes:**
- **Maclib traffic-light cluster** replaces the former 38×32 square
  minBtn/closeBtn pair at the top-right of the header. Three 14×14
  circular dots — amber = minimize, green = restore/expand, red = close
  — with glyphs hidden at rest and surfacing on hover (the macOS pattern).
  Colors are deliberately theme-independent (Maclib discipline).
- **Sidebar header card** (Maclib pattern) at the top of the rail: a
  pinned card with the RezurX logo mark (lava gradient square + "R"
  letter), the RezurX wordmark, and the section subtitle. Stays visible
  when the chip list scrolls.
- **Sidebar footer profile chip** (Maclib pattern) at the bottom of the
  rail: a pinned card with a RezurX avatar dot (lava gradient circle),
  the RezurX wordmark, and a role label.
- **Lava hairline dividers** on both cards — the accent language of the
  Magma rail extended to the sidebar chrome.
- **Adaptive rail collapse**: when the window narrows below 420px or
  enters sheet mode, the header card and footer profile chip narrow to
  the icon-strip width; wordmark/section/role labels hide; the logo mark
  and avatar dot center.
- **dragBar control lane** shrunk from 108px to 82px to match the new
  traffic-light cluster width (58px + 24px margin).

**Engineering notes:**
- Hit the Luau 200-local register ceiling in CreateWindow for the third
  time. Resolved by: (a) scoping the chrome helper function + constants
  to a `do…end` block (frees 6 locals after construction completes), (b)
  inlining the glyph-drawing switch inside `makeTrafficDot` (eliminates
  closures + helper-function captures), (c) bundling all sidebar header
  children into a single `sh` table and all sidebar footer children into
  a single `sf` table (the onTheme closures capture 1 local each instead
  of 8). Net local add: 6 (down from the naive 34).
- API surface unchanged: `Library:CreateWindow`, `:CreateTab`,
  `:CreateButton`, `:CreateSlider`, `:CreateToggle`, `:CreateDropdown`,
  `:CreateInput`, `:CreateKeybind`, `:CreateColorPicker`, `:Notify`,
  etc. all behave identically. RMAX loads without modification.
- All 287 headless checks pass; RMAX UI block runs clean against v5.6.0
  (ok=true, 0 warnings, frame visible).

## v5.5.1 — hotfix: "bad ColorSequence keypoint" crash on legacy themes

Runtime crash in `CreateWindow`, present since v5.2.0 on every legacy
theme (Quiet — the default — Ember, Ocean, Crimson) and on any custom
palette without a `secondary` token: `C.secondary` stayed nil and the
TopEdge gradient's `ColorSequenceKeypoint.new(1.0, C.secondary)` threw
at construction. v5.5.0's Magma edge-bar and divider added four more
`C.secondary` keypoints, widening the blast radius.

### The fix (three layers)

1. **Source normalization** — every built-in theme is completed at load:
   missing `secondary` inherits `accentHi` (the accent's bright ladder
   step). `GetTheme`/`RegisterTheme` clones are always complete.
2. **CreateWindow guard** — the per-window palette `C` normalizes after
   the preset + CustomTheme merge, covering hand-built palette tables
   passed directly as `cfg.Theme`.
3. **ModifyTheme guard** — live theme swaps can never leave the token
   nil on a running window.

### Harness hardening

The headless mock's `ColorSequenceKeypoint.new` now validates its
arguments exactly like the real engine (number time in [0,1], Color3
value) — the old mock silently accepted nil colors, which is why the
273-check suite never caught a crash real Roblox hit instantly. This
entire bug class is now detectable headlessly.

### Verification

- Suite: **286 passed, 0 failed** (13 new v5.5.1 checks: every legacy
  theme constructs cleanly, registered secondary-less palettes
  complete, live ModifyTheme to a legacy theme is safe).
- Restaurant MAX UI block: ok=true, zero warnings on v5.5.1.

---

# Changelog

## v5.5.0 "Magma" — Rayfield Gen2 × Maclib visual cross, lava signature

The layout redesign users asked for: the chrome DNA of Rayfield Gen2
crossed with Maclib's sidebar discipline, wearing RezurXLib's signature
lava colors. Benchmarked against the live sources of both references.

### 1. Sidebar navigation rail (Maclib × Rayfield)

Tabs moved from the horizontal top strip into a **vertical rail on the
left** (156px) — Maclib's sidebar discipline with Rayfield's pill
chips:

- **Pill chips**: fixed full-rail width, 36px tall, fully rounded,
  emoji/asset icon lane + left-aligned label, macOS-style ellipsis for
  long titles (no more text measurement — the rail owns the width).
- **Lava edge-bar selector**: the active-tab indicator is now a 3px
  vertical bar on the rail's left edge with a soft 5px glow backing,
  carrying the orangered→amber lava gradient. It slides vertically on
  the same interruptible spring, and tracks chip height.
- **Vertical fade masks**: tabs past the rail's edges fade smoothly
  (top mask appears only once scrolled).
- **Lava hairline divider**: 1px accent-gradient vertical hairline
  between rail and content.
- **Page transitions slide vertically** (content rises 8px) — Maclib's
  content-motion direction.
- **Adaptive icon rail**: sheet mode (phones) and narrow floating
  windows (< 420px) collapse the rail to a 54px icon strip; chips
  restyle to centered emoji/asset icons. Crosses back automatically.
  Chips created while collapsed restyle immediately.

### 2. Warm lava-rock surface

The Lava preset's surface moved from a cool navy (11,13,20) to a warm
lava-rock charcoal (20,15,13) — the whole derived palette (panels,
borders, header, rail) now reads warm. Window corner radius retuned to
16px (Rayfield 20 × Maclib 10 cross).

### 3. CRITICAL FIX: array-form Size was silently ignored

`readDimension` only read the `.X`/`.Y` KEY form — the DOCUMENTED
`Size = { 560, 580 }` array shape fell back to the 460×500 default on
every consumer (including Restaurant MAX, which believed it was
running 560×580 and was not). Array `[1]`/`[2]` indices are now read;
`Vector2`, `UDim2`, and key-form tables keep working. Applies to
`Size`, `MinSize`, and `MaxSize`.

### Verification

- Bundle rebuilt: 563121 bytes, 9961 lines, byte-identical via
  `build_bundle.py --check`; `luau-analyze` clean.
- Headless suite: **273 passed, 0 failures** (13 new v5.5.0 checks:
  rail geometry, vertical scrolling, divider, pill chips, icon-rail
  collapse + emoji restyle, edge-bar specs).
- Restaurant MAX v11 UI block runs end-to-end against v5.5.0:
  ok=true, zero warnings, correct 600×580 geometry (previously
  silently 460×500).

---

# Changelog

## v5.4.0 — the "functional perfection" pass

Benchmarked against the five reference libraries users actually praise —
Rayfield Gen2, Fluent, WindUI, Maclib and Luna — and hardened with the
reliability patterns ALL five share. Full sources of all five were audited
(Architecture, safety, persistence, theming, mobile, motion, ergonomics).

### 1. SafeCallback — the unified consumer-callback funnel

Every `Callback` in the library now routes through one guarded path
(`Library.SafeCallback`):

- **task.spawn isolation** — a yielding or expensive consumer callback
  can never block the input event or the UI thread.
- **pcall containment** — a throwing callback can never kill the event
  connection that fired it.
- **Visual surfacing** — the element that owns the callback flashes
  error-red and swaps its label to "Callback Error" for 1s (Luna /
  Rayfield pattern), with a per-element debounce so a slider firing
  every drag frame flashes exactly once.
- **Named console trace** — `[RezurXLib] Slider 'Speed' callback error: …`.

Routed through: slider (Set + live drag), input, dropdown, keybind
(press / hold / release / rebind-changed), color picker (live HSV drag,
presets, programmatic Set), and bindables.

### 2. Persistence hardening (Rayfield Gen2 patterns)

- **Atomic writes** — `FS.writeAtomic` writes the whole payload to a
  parked `.saving` copy, reads it back and verifies byte-equality, and
  only then overwrites the real file. A short read-back (disk full)
  never touches the original. Executors have no rename(); this is the
  next-best guarantee.
- **Corrupt-file recovery** — a config that fails to decode is backed
  up as `<name> (Incorrect Format)<ext>` (unique-numbered so a second
  corruption cannot destroy the first backup), removed, and the user
  is notified. The next autosave writes a clean file instead of
  hammering the same corrupt bytes forever.

### 3. Keybind clash guards (Rayfield pattern, bidirectional)

- Binding an element keybind to the window's UI-toggle key is refused
  with a toast + warning — the user can no longer lock themselves out.
- `Window:SetToggleKeybind` refuses a key already bound to any flagged
  element, naming the flag it collides with.

### 4. Notification ergonomics (Luna / Rayfield patterns)

- **Reading-time durations** — when no `Duration` is given, the toast
  sizes itself from the content length (3–9s band). One-liners stop
  lingering; paragraphs stop vanishing mid-read.
- **Hover dwell pause** — the dismiss countdown freezes while the
  pointer rests on the toast; the progress bar re-anchors in lockstep.

### 5. Element upgrades

- **Typeable slider value box** (Luna / Maclib pattern) — click the
  value readout, type an exact number, Enter commits through the same
  snap/clamp path as dragging. Escape / click-away cancels. Numeric
  input is sanitized live.
- **Living dropdown** — `obj:Add(option)` / `obj:Remove(option)` mutate
  the list without a full rebuild; selection survives; removed
  selected values drop cleanly; no callbacks fire (data ops, like
  Refresh).

### 6. One-time hide-key hint (Fluent / Maclib pattern)

The first time the window is hidden per session, a toast teaches the
toggle key ("Press K to toggle the interface.") — exactly once.

### 7. Fixes along the way

- `CreateWindow` sat at Luau's 200-local register ceiling; the new
  hide-hint state lives on the Window table instead of a local, and
  all future window-scope additions must do the same.
- Headless harness: the mock JSON parser looped forever on malformed
  input (real `HttpService:JSONDecode` errors); both object and array
  loops now detect no-progress and raise, matching real behavior.

### Verification

- Bundle rebuilt: 557061 bytes, 9846 lines, byte-identical via
  `build_bundle.py --check`.
- `luau-analyze`: zero syntax errors.
- Headless suite: **236 legacy + 16 new checks, 0 failures** — new
  coverage: SafeCallback containment, living dropdown ops, keybind
  clash guard, atomic save + corrupt recovery, typeable slider,
  plus regression versions of each.

---

# Changelog

## v5.3.1 — diagnostic banners + non-yielding module load

Hotfix follow-up to v5.3.0. The library was already functionally correct
after the v5.3.0 host-detection rewrite, but a class of "nothing shows
up, no UI no anything" reports kept coming in — and they were
impossible to triage because the library was silent. v5.3.1 makes
silent failure visible and removes the last module-load yield.

### 1. Diagnostic banners (loud-by-default)

When the library loads and when `CreateWindow` is called, two prints
land in the executor's output panel:

```
[RezurXLib] v5.3.1 module loaded. LocalPlayer=… PlayerGui=…
[RezurXLib] CreateWindow called: name="…" theme=… host=… size=…
```

This means the next time a consumer reports "nothing shows up", the
failure is immediately localizable:

- **Neither print appears** → the consumer's script never ran
  (typically a paste-artifact `\n` or unmatched bracket — run
  `luau-analyze` on it).
- **Only the module-load print appears** → the loadstring returned
  the Library but `CreateWindow` was never called (consumer wiring
  bug).
- **Both prints appear but no UI** → the failure is inside
  CreateWindow's host-detection or render path.

The banners are gated behind `pcall` + `RunService:IsStudio()` off so
Studio runs (and the headless test suite, whose fake `RunService`
lacks `IsStudio`) stay quiet.

### 2. Non-yielding player resolution at module top

The previous module-top line:

```lua
local playerGui = player and player:WaitForChild("PlayerGui")
```

yielded the entire `loadstring(game:HttpGet(...))()` chunk on first
run. In some executor bootstraps — particularly when the executor's
main thread was already inside a `task.spawn` chain or when the
LocalPlayer wasn't ready yet — that yield never resumed, the chunk
returned `nil`, and the consumer's `Library:CreateWindow(...)` call
silently failed.

The new pattern is non-yielding:

```lua
local player = Players.LocalPlayer
local playerGui
if player then
    pcall(function()
        playerGui = player:FindFirstChildOfClass("PlayerGui")
    end)
end
```

`resolvePlayerGui()` already had a 5-second `WaitForChild` fallback
for the case where `FindFirstChildOfClass` missed at boot; that
fallback now does the heavy lifting on the consumer's first
`CreateWindow` call instead of blocking module load.

### 3. Library version bump

`Library.Version` is now `"5.3.1"`. Consumers can read this in-game
via `print(RezurXLib.Version)` or via the diagnostic banner.

### 4. Repo cleanup

- Removed `DOMINUS.luau` (consumer hub script, not library source).
- Removed `ExampleUsage.client.lua` (outdated v4.0 example).
- Removed `RezurXExample.client.lua` (outdated v3.1 example).
- Added `Example.client.lua` — a tight <150-line worked example
  covering tabs, sections, buttons, toggles, sliders, dropdowns,
  keybinds, color pickers, stat grids, accordions, modals, custom
  themes, and configuration-saving.
- Rewrote `README.md` as proper usage docs: install, full
  `CreateWindow` config table, every Window/Tab method, themes,
  ConfigurationSaving, KeySystem, library-level API, trust
  guarantees, repo layout.

### 5. Verification

- 236/236 headless tests pass (was 233 in v5.2.0; +3 from the
  diagnostic-banner coverage).
- User-CW reproduction test (the user's exact `CreateWindow` call
  shape): parses cleanly, loads as `Version=5.3.1`, `CreateWindow
  ok=true`, frame visible at 436×482 (enterW×enterH pre-spring),
  `BackgroundTransparency=0`, `Visible=true`, parented to
  `RezurX_RestaurantMAX` → `PlayerGui`.
- Bundle byte-identical to source via
  `python3 scripts/build_bundle.py --check`.

---

## v5.3.0 "Universal" — root-cause the UI invisibility regression


The external design audit, implemented: the critical active-tab bug, the
flat-contrast fixes, the minimized-bar upgrades, and the universal-library
architecture (presets, CustomTheme, StatGrid). 233/233 tests.

### 1. Critical active-tab bug — fixed
- **Root cause**: the tab chip carried a white-identity UIGradient. Any theme
  path that re-applied dark gradient colors multiplied the chip fill to a
  BLACK box while the stroke stayed orange — the exact reported symptom.
- The gradient is **deleted entirely**; the solid accent fill now renders
  exactly on every theme.
- The active label tweens to **explicit pure white** (Color3.new(1,1,1)) —
  a broken custom `white` token can no longer blank the text.
- Tab text/icons carry **ZIndex 7** with a guarantee comment; nothing can
  render above them.

### 2. Visual depth & surface layering
- **Active toggle card glow** (spec): while ON, the card's border stroke
  elevates from flat gray to a soft neon accent glow — accent color at
  0.4 stroke transparency, 1.5px — and stays there (ambient "powered"
  state, not a one-shot).
- **Top edge accent line**: a 2px gradient strip (accent → secondary, e.g.
  orange → gold) across the window's very top border. Separates the window
  against bright game backgrounds and seals the minimized pill.

### 3. Minimized bar upgrades
- **Live activity beacon**: `Window:SetActivity("running"|"paused"|nil)`
  (or `cfg.Activity`) — a breathing green dot beside the logo while
  scripts run, yellow when paused, hidden when nil. Users see background
  activity at a glance while minimized.
- **Quick pause/resume button**: `cfg.QuickPause = function(paused) end`
  (or `Window:SetQuickPause(fn)`) renders a tiny ❚❚/▶ control beside the
  FPS/ping chip — freeze features WITHOUT expanding the window. The
  library renders state and calls the callback; it never guesses what
  "pause" means for your script.
- Edge trim: the top accent line + existing frame stroke seal the
  minimized pill (the v4.4 decoration-hiding already removed the floating
  orange border).

### 4. Universal theme engine
- **Preset matrix** (exact spec colors): `Lava` (#FF4500/#FFAA00 on
  #0B0D14), `Cyberpunk` (#00F0FF/#A100FF on #0D0E15), `Obsidian`
  (#3A4454/#A0ABBA on #08090C), `Emerald` (#00FF88/#00B359 on #0A120E).
  Each derives a full contrast ladder (accentHi/accentDim/accentDark,
  panel family, header, borders) from the primary via color math — the
  ladder can never be inconsistent.
- **New `secondary` theme token** (powers the top-edge gradient and is
  available to all elements).
- **`CustomTheme` config**: friendly names (`PrimaryAccent`,
  `SecondaryAccent`, `CardBackground`, `WindowBackground`, `TextMain`)
  mapped onto tokens with auto-derived ladders, PLUS raw token passthrough
  for power users. Combines with any preset.
- **`Title`/`SubTitle` aliases** for Name/Subtitle — scripts written
  against other libraries drop in unchanged.

### 5. Telemetry & navigation
- **`Tab:AddStatGrid({ Columns, UpdateRate })`**: the universal metric
  grid — auto-wrapping chips (Icon/Label/Value) on dark translucent cards
  with neon accent values. `:AddChip({Id, Icon, Label, Value, Sample})`,
  `:UpdateChip(id, v)`, `:RemoveChip(id)`, auto-polling `Sample`
  functions at `UpdateRate`. Replaces game-specific text logs with
  live stat cards.
- **Tab overflow fade masks**: tabs now fade out smoothly at the rail's
  right edge (and the left edge once scrolled) instead of cutting off
  hard against the frame.
- Section headers already carry the accent tick + fading rule (v4.3);
  auto-scrolling canvases, the Ctrl+K command palette, and contextual
  icons (asset IDs or emoji) were already in place — verified, not
  re-built.

### 6. Engineering notes
- Sound forward-declaration fixed a real closure-scope bug in the new
  header controls (quick pause would have called a nil global).
- Mock harness: Color3 value equality (`__eq`), `Color3.fromHex`,
  deep-copying `Clone()` (matches real Roblox), CanvasGroup support.

### Verified
- 37 new checks: gradient-free chips + explicit white + ZIndex, all four
  presets' exact colors, CustomTheme end-to-end, toggle glow resting
  state (accent @ 0.4/1.5px), beacon modes, quick-pause callback
  round-trip, fade masks + scroll visibility, StatGrid add/update/sample/
  remove/row-growth. **233/233 passing.**

---

## v5.1.0 "Kinetic" — The Micro-Interaction Blueprint, Implemented

The full component-upgrade blueprint, built: every table row, the motion
physics spec, the hardware drag physics, and the tactile sound map — all
running on the v5 motion engine (springs + tokens), all tested. 195/195.

### Motion physics spec (implemented as tokens)
- **press** 0.08s Sine InOut — micro tactile feedback, zero latency feel
- **move** 0.20s Quart Out — component motion (sliders, toggles, tabs)
- **enter** 0.32s Back Out — entrances with intentional overshoot
- Legacy constants alias the tokens; no ad-hoc curves anywhere.

### Component upgrades (every row of the blueprint)
- **Buttons — Spring Shrink & Sheen Sweep**: 0.96x press on the press
  curve, a 20° diagonal light reflection fires across the card face
  (clipped to the rounded rect), metallic micro-tick audio.
- **Toggles — Elastic Pill Morph**: the knob stretches horizontally
  during translation (24x16 taffy pull) and snaps back to 18x18 with a
  Back overshoot; the active state fires a one-shot accent border bloom.
- **Tabs — Gliding Glass Pillar**: the indicator is now a glowing glass
  bar (4px core + soft aura, one spring, interruptible). Content panels
  slide in horizontally (+8px) with a 0.18s CanvasGroup fade.
- **Sliders — Dynamic Value Tooltip**: a floating value chip springs up
  above the thumb on press (spring physics), tracks live while dragging
  with a soft friction tick per snapped step, retracts on release.
- **Dropdowns — 3D Card Unfold**: the popup renders in a CanvasGroup that
  alpha-unfolds (0.15s) while option rows drop 10px on a 0.02s stagger —
  the cascading fill.
- **Keybinds — Pulse Ring Listener**: a breathing neon ring around the
  pill while listening + a low-frequency hum (opt-in sounds); key capture
  ends with a snap-confirmation chime.
- **Color Pickers — Hex Copier**: the hex chip is click-to-copy (executor
  setclipboard when present) with a confirmation toast.
- **Text Inputs — Neon Focus Flare**: the stroke thickness expands on
  focus while the placeholder floats upward into a mini-label above the
  field; it retracts when the field empties.
- **Notifications — dual-tone chime** on arrival (countdown bar, bounce
  entrance, and stack push-up were already in place).
- **Key System — Step Unlock**: correct keys run a verification sequence
  (CHECKING FORMAT → VERIFYING KEY → AUTHORIZED) with glowing checkmarks
  lighting in one by one, then the explosive window expand + Trace lap.

### Hardware drag physics
- The window **tilts with its movement vector** while dragging — rotation
  = clamp(deltaX-influenced tilt, −3°, +3°) — and settles back to level
  with a Back ease on release. Physical weight, zero frame loops
  (InputBegan/InputChanged/InputEnded only, as spec'd).

### Tactile sound map (opt-in `Sounds = true`)
- Full spec table: open 1.0/0.40, close 0.9/0.30, tab 1.2/0.25,
  toggleOn 1.15/0.30, toggleOff 0.85/0.30, click 1.0/0.35,
  sliderStep 1.3/0.15, toast 1.0/0.40 (dual-tone), confirm 1.3/0.30,
  hum 0.55/0.12 (looped while a keybind listens). One engine-local
  ping, pitched per action; per-action asset overrides supported.

### Verified
- 27 new checks: sheen sweep geometry + sweep-on-click, toggle
  stretch/snap/bloom, PageGroup slide-fade lifecycle, slider popup
  spring-in/live-tracking/retract, dropdown group unfold + row render,
  keybind pulse ring show/hide on capture, input floating label up/down,
  drag tilt + settle. **195/195 passing.**

---

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
