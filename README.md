# 👑 RezurXLib v5.0.0 "Trace"

**A universal, premium UI library for Roblox** — built by RezurXLab for developers, trusted by players. The **Refined Depth** edition.

---

## 📦 What Is RezurXLib?

RezurXLib is a **complete, self-contained UI framework** for Roblox. It provides everything you need to build beautiful, functional, and reliable interfaces — whether you're creating an admin panel, a settings menu, a game hub, or any other in-game UI.

**It works everywhere:** CoreGui, PlayerGui, executors, and any environment that supports standard Roblox APIs.

---

## ✨ What's New in v4.0 "Aurora"

### ✨ Trace (v5.0.0) — the big one
- **Geometry law**: concentric radii enforced in code, single-instance shadow, integer-pixel resting offsets, true pills, zero UIScale entrances — corners are clean at any zoom
- **Motion engine**: interruptible velocity-preserving springs, exactly four motion tokens, a 12-spring budget cap, and a silent frame-time guard that degrades on slow hosts
- **Aurora Trace**: one accent light travels the window border — entrance lap, tab-switch quarter-lap, success lap, error lap in red. Six competing effects deleted to make room
- **Mobile first-class**: Compact/Comfortable density, near-fullscreen sheet mode under 500px, 44px touch targets, full ReducedMotion coverage
- **Repo hygiene**: .env removed (rotate your DATABASE_URL), scaffold deleted, src/ modules + byte-identical build script, 167-test headless suite

### 🔮 Prism (v4.4.0)
- **Pixel-perfect fixes** — status bar breathing room, clean minimize (no orange stripe), centered FPS divider, uniform section rules
- **Sliding underline tab indicator** — a 3px accent bar that glides beneath the active tab
- **Button glow halos** — soft accent halos that fade in on hover; primary buttons glow at rest
- **Glassmorphism** — opt-in `BackdropBlur = true` frosts the world behind the window
- **Animated light strips** — pulsing section ticks, sweeping button spines (UIGradient.Offset)
- **Squishy toggle physics** — the thumb stretches as it travels and springs back
- **CreateGraph** — live sparkline: `:Push(value)` or auto-`Sample`, scrolling window, auto-scale
- **UI sound design** — opt-in `Sounds = true`, pitched per action, engine-local assets
- **Keybind badge** — the footer shows a live `[K] HIDE` shortcut pill

### 🌶️ Spice (v4.3.0)
- **Active tab = accent fill** — the selected tab is a solid accent chip with white bold text, exactly as requested
- **Signature accent spines** — a 3px accent bar on every button that lights up and grows on hover
- **Hover raises** — buttons lift 1.5% on hover; the chevron slides and turns accent
- **Section headers with hierarchy** — accent tick + gradient rule from every title

### 🎰 The Jackpot Entrance (v4.2.0)
- **Spring landing** — the window pops in with a Back overshoot; it *lands*, not fades
- **Accent-line ignition** — the header strip sweeps on like a lightsaber
- **One-shot shockwave** — an accent ring bursts from behind the window and dissipates
- **Reward cascade** — every card pops with an accent stroke flash; the page rises into place
- **Reveal pop** — toggling the menu open replays the spring + cascade every time
- **Concentric curves** — shadow layers, accent rim, and glow now follow the parallel-curve law; pills are true pills

### 🪟 Refined Depth & Motion (v4.0.1)
- **Layered depth shadows** — three stacked soft halos hug the window tightly for a real gaussian-blur feel, no image assets. Dragging or resizing deepens the shadow so the window feels physically lifted
- **Subtle accent rim** — a faint accent-tinted glow hugs the window edge for branded presence
- **Spring entrance** — the window materializes with a gentle scale-and-fade
- **Staggered tab openings** — cards settle softly in sequence when you switch tabs
- **Choreographed entrances everywhere** — modals, color pickers, context menus, and the command palette now scale-settle in instead of popping (v4.1.0)
- **Button micro press-feedback** — buttons dip 3% on press and spring back (v4.1.0)

All of it respects `ReducedMotion` and `MotionScale`. Ambient pulse loops (logo glow, glow-strip shimmer) are opt-in via `AnimatedAccents = true`.

> **v4.0.1:** The cursor glow, frosted-glass card sheens, header shimmer sweeps, and button sheens from v4.0.0 were removed after feedback — they read as gimmicky. The look is now depth and restraint.

### 🖼️ Icon Support (Rayfield-style, no remote atlas)
- `CreateWindow({ Icon = 4483362458 })` — number asset ids, `"rbxassetid://…"` / `"rbxasset://…"` / `"rbxthumb://…"` URIs, or emoji text in the header badge
- `Window:CreateTab("Main", icon)` — same resolution on tabs (image or emoji)
- **Element icons** — `Icon = …` on Buttons, Toggles, Sliders, Inputs, Dropdowns, Keybinds, and Color Pickers — Rayfield only puts icons on the topbar and tabs
- Works fully offline: no icon atlas download, no HTTP dependency

### 💾 Configuration Auto-Save
```lua
ConfigurationSaving = {
    Enabled   = true,
    FolderName = "RezurXHub",   -- default: RezurXLib/Configurations
    FileName  = "AdminPanel",   -- default: game.PlaceId
    Autosave  = true,           -- signature-diffed, no rewrite storms
    SaveOnUnload = true,        -- flush on :Destroy()
    Notify    = true,           -- toast after restoring
},
```
Every element with a `Flag` persists itself to JSON on the executor filesystem and restores on the next run — toggles, sliders, dropdowns, inputs, keybinds, color pickers. Improvements over Rayfield's equivalent:
- **Writes only when values actually changed** (2-second signature diffing, not a full rewrite per click)
- **Per-window flag isolation** — multiple windows never mix their configs
- **Loads only after the key gate passes** — callbacks never replay behind a locked UI
- Manual control too: `Window:SaveConfiguration()` / `Window:LoadConfiguration()`

### 🔑 Key System
```lua
KeySystem = true,
KeySettings = {
    Title = "My Hub", Subtitle = "Key System",
    Note = "Get a key from our Discord.",
    FileName = "MyHubKey",       -- saved under RezurXLib/Keys/
    SaveKey = true,              -- remember accepted keys (exact-match, not substring)
    GrabKeyFromSite = false,     -- optional: fetch the key from a raw URL
    Key = { "KEY-1", "KEY-2" },  -- string or list
    MaxAttempts = 5,             -- 0 = unlimited
    OnExhausted = "Lock",        -- "Lock" | "Kick" | "None"
},
```
A styled unlock card in the library's own design language (no external ScreenGui asset download, unlike Rayfield): elastic shake on wrong keys, attempt counter, saved-key skip, and a configurable exhaustion policy. The entrance animation defers until the gate passes.

### 🐛 22 Bug Fixes
Including two critical ones that explain the most common "ghost UI" reports:
- **ReplaceExisting destroyed the old ScreenGui but never ran the old window's cleanup** — keybinds kept firing twice, a mid-flight drag kept erroring against destroyed widgets. The Window object itself is now destroyed and deregistered.
- **`Library:Destroy()` skipped every second window** while mutating the table it was iterating.
- …plus: resize-vs-minimize desync (`minimized` was a global read), stranded drags when popups close mid-drag, ColorPicker firing the live callback on open, Searchable dropdowns self-destructing when the mobile keyboard appeared, tooltips floating after their owner died, ripples landing off-center under `uiScale`, slider initial values ignoring `Increment`, `obj:Set({Value=…})` with fresh tables, Escape unable to close the command palette while typing, stuck drags when the OS swallows touch release (TouchEnded watchdog + 30s session watchdog), and more. See `CHANGELOG.md`.

### 📱 Mobile Hardened
- 40×40 resize-grip hit area (visible grip unchanged)
- Searchable dropdowns survive the on-screen keyboard's viewport resize
- Motion preferences now apply to the popup layer (dropdowns, pickers, modals, palette)
- Scale-correct ripples, clamped tooltips, re-read viewport bounds during icon drags

---

## 🧩 Complete Component Library
| Component | Description |
|-----------|-------------|
| **Window** | Draggable, minimizable, closeable, resizable, spring entrance |
| **Tabs** | Auto-sizing, scrollable, sliding indicator, image or emoji icons |
| **Buttons** | Ripple feedback, hover states, callback error handling |
| **Toggles** | Smooth slide animation, reset method |
| **Sliders** | Throttled callbacks, live value display, increment snapping |
| **Dropdowns** | Searchable, multi-select, fuzzy matching, mobile-keyboard safe |
| **Inputs** | Text boxes with focus states |
| **Keybinds** | Click to rebind, collision protection |
| **Color Pickers** | HSV, RGB, Hex, live preview, preset palettes |
| **Notifications** | Action buttons, type icons, progress bars |
| **Tooltips** | Hover + touch support, viewport-clamped |
| **Context Menus** | Nested options with icons |
| **Progress Bars** | Indeterminate and value display |
| **Spinners** | Loop animations, no heartbeat required |
| **Accordions** | Collapsible content sections |
| **Bindable Controls** | Toggle + keybind combined |
| **Graphs** | Live sparklines with auto-sampling |
| **Carousels** | Content sliders with arrows |
| **Search & Command Palette** | Live filtering, Ctrl+K palette |
| **Modals** | Confirmation dialogs |
| **Key Gate** | Styled key system with attempt tracking |

**Snappy interactions** — 0.26s toggles, instant-feeling hover states, and a 4Hz-capped stats chip so the header never costs you frames

**7 built-in themes** — Ember, Ocean, Crimson, Slate, Midnight, Forest, Coral, Quiet — plus `Library:RegisterTheme()` for your own.

---

## 🛡️ Reliability & Trust
- **No telemetry** — zero analytics, zero data collection
- **No automatic requests** — the only network/file operations are the ones you explicitly configure (`KeySettings.GrabKeyFromSite`, `ConfigurationSaving`)
- **Error-handled** — every callback wrapped in `pcall`
- **Memory-safe** — Janitor pattern, flag pruning on element destroy, drag sessions can never outlive their owner
- **Headless-tested** — 167 integration tests run the entire library against a mocked Roblox API (window creation, every element, drag & touch simulation, config save/load, key gate flows, animation end-states, FPS-throttle verification)
- **Executor-compatible** — works in Synapse, Krnl, Script-Ware, Xeno, Delta, and more
- **100% backward compatible** — existing v3 scripts run unchanged; v4 features are strictly additive

---

## 🚀 Quick Start

### In a ModuleScript
```lua
local RezurXLib = require(path.to.RezurXLib)

local Window = RezurXLib:CreateWindow({
    Name = "My Panel",
    Subtitle = "Built with RezurXLib",
    Theme = "Ember",
    Icon = 4483362458,                       -- optional
    ConfigurationSaving = { Enabled = true, FileName = "MyPanel" },
})

local Tab = Window:CreateTab("Main", "📊")
Tab:CreateButton({
    Name = "Click Me",
    Callback = function()
        print("Button clicked!")
    end
})
```

### In an Executor (Synapse, Krnl, Xeno, etc.)
```lua
local RezurXLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/AshesOfTheUndead/rezurxlib/main/RezurXLib.lua"))()
```

### Using the Global Reference
```lua
_G.RezurXLib:CreateWindow({ Name = "Admin Panel" })
```

---

## 📚 Documentation

### `Library:CreateWindow(config)`
| Parameter | Type | Description |
|-----------|------|-------------|
| `Name` | `string` | Window title |
| `Subtitle` | `string` | Subtitle text |
| `Theme` | `string / table` | Built-in theme name or palette table |
| `ToggleUIKeybind` | `Enum.KeyCode` | Keybind to toggle visibility (default K) |
| `LoadingEnabled` | `boolean` | Show loading animation |
| `LoadingTitle` | `string` | Loading screen wordmark |
| `Size` | `{X, Y}` | Window size (default: 460x500) |
| `Icon` | `number / string` | Asset id, rbx URI, or emoji text |
| `AnimatedAccents` | `boolean` | Ambient pulse loops — logo glow & glow-strip shimmer (opt-in) |
| `ReducedMotion` | `boolean` | Disable all animation |
| `KeySystem` / `KeySettings` | — | See above |
| `ConfigurationSaving` | `table` | See above |
| `Sounds` | `bool/table` | UI click sounds (v4.4) |
| `BackdropBlur` | `boolean` | Blurs the whole game world (global), refcounted (v5) |
| `ShadowImage` | `string` | Optional 9-slice shadow asset (v5) |
| `Density` | `string` | `"compact"` / `"comfortable"` (v5) |
| `DisplayOrder` | `number` | ScreenGui DisplayOrder (v5) |

**Returns:** `Window` object

### `Window:CreateTab(name, icon)`
Creates a tab. `icon` may be an emoji string or an asset id/URI.

### `Tab:CreateButton(config)`
| Parameter | Type | Description |
|-----------|------|-------------|
| `Name` | `string` | Button label |
| `Variant` | `string` | `"Primary"` or `"Secondary"` |
| `Icon` | `number/string` | Optional leading asset icon |
| `Callback` | `function` | Called when clicked |
| `Tooltip` | `string` | Optional tooltip text |

**Returns:** `Button` object with `:Set()` method

### `Tab:CreateToggle(config)`
| Parameter | Type | Description |
|-----------|------|-------------|
| `Name` | `string` | Toggle label |
| `CurrentValue` | `boolean` | Initial state |
| `Callback` | `function` | Called on state change |
| `Flag` | `string` | Optional flag for config auto-save |

**Returns:** `Toggle` object with `:Set()`, `:Get()`, `:Reset()` methods

See `Library:GetDocs()` in-game for the full machine-readable API reference, and `ExampleUsage.client.lua` for a complete worked example.

---

## 📦 Files in This Repository
| File | Description |
|------|-------------|
| `RezurXLib.lua` | The complete UI library (ModuleScript) |
| `ExampleUsage.client.lua` | Example showing all components in action |
| `CHANGELOG.md` | Full v4.0 change list with every fix |

---

## 🏢 Powered By
| Project | Description |
|---------|-------------|
| **DOMINUS Engine** | Full-featured automation engine using RezurXLib |
| **RezurXLab Tools** | Various tools and utilities built with RezurXLib |

---

## 👑 Credits

**Creator:** RezurXshin
**Studio:** RezurXLabs
**License:** MIT — open, free, and transparent.

---

## 🙏 Acknowledgments

- Inspired by the **Rayfield UI Library** and its contributions to the Roblox community.
- Built with ❤️ for developers and players everywhere.

---

## 📜 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

**RezurXLib — The UI library you can trust.** 🚀
