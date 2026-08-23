# 👑 RezurXLib v4.0 "Aurora"

**A universal, premium UI library for Roblox** — built by RezurXLab for developers, trusted by players. The **Glass + Glow** edition.

---

## 📦 What Is RezurXLib?

RezurXLib is a **complete, self-contained UI framework** for Roblox. It provides everything you need to build beautiful, functional, and reliable interfaces — whether you're creating an admin panel, a settings menu, a game hub, or any other in-game UI.

**It works everywhere:** CoreGui, PlayerGui, executors, and any environment that supports standard Roblox APIs.

---

## ✨ What's New in v4.0 "Aurora"

### 🪟 Glass + Glow Visual Direction
- **Layered depth shadows** — three stacked soft halos fake a gaussian blur without any image asset
- **Frosted glass cards** — every panel gets a top-light sheen that dissolves downward
- **Glass edge highlight** — a 1px gradient hairline catches light on the window's top edge
- **Living header** — the title bar gradient slowly rocks back and forth, with a diagonal shimmer sweep gliding across every few seconds
- **Spring entrance** — the window materializes with a soft scale-and-fade
- **Staggered tab openings** — cards settle in one after another when you switch tabs
- **Cursor glow** — an accent ambient light follows your pointer, brightens on press, and breathes at idle (desktop only)
- **Primary button sheen** — a light band sweeps across accent buttons on hover and click

All of it respects `ReducedMotion` and `MotionScale`, and is on by default (`AnimatedAccents = false` to opt out, `CursorGlow = false` to disable the pointer light).

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
| **Buttons** | Ripple feedback, sheen sweeps, hover states, callback error handling |
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
| **Carousels** | Content sliders with arrows |
| **Search & Command Palette** | Live filtering, Ctrl+K palette |
| **Modals** | Confirmation dialogs |
| **Key Gate** | Styled key system with attempt tracking |

**7 built-in themes** — Ember, Ocean, Crimson, Slate, Midnight, Forest, Coral, Quiet — plus `Library:RegisterTheme()` for your own.

---

## 🛡️ Reliability & Trust
- **No telemetry** — zero analytics, zero data collection
- **No automatic requests** — the only network/file operations are the ones you explicitly configure (`KeySettings.GrabKeyFromSite`, `ConfigurationSaving`)
- **Error-handled** — every callback wrapped in `pcall`
- **Memory-safe** — Janitor pattern, flag pruning on element destroy, drag sessions can never outlive their owner
- **Headless-tested** — 82 integration tests run the entire library against a mocked Roblox API (window creation, every element, drag & touch simulation, config save/load, key gate flows)
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
| `AnimatedAccents` | `boolean` | Glass + Glow animations (default true) |
| `CursorGlow` | `boolean` | Pointer ambience on desktop (default true) |
| `ReducedMotion` | `boolean` | Disable all animation |
| `KeySystem` / `KeySettings` | — | See above |
| `ConfigurationSaving` | `table` | See above |

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
