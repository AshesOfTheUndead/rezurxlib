# 👑 RezurXLib

**A single-file Roblox Luau UI library.** Premium visuals, every component you need, runs in executors and Studio. v5.4.0.

```lua
local RezurXLib = loadstring(game:HttpGet(
  "https://raw.githubusercontent.com/AshesOfTheUndead/rezurxlib/main/RezurXLib.lua"
))()
local Window = RezurXLib:CreateWindow({ Name = "My Panel", Theme = "Lava" })
local Tab = Window:CreateTab("Main", "🏠")
Tab:CreateButton({ Name = "Click", Callback = function() print("hi") end })
```

---

## Install

**Executor** — one line, no ModuleScript needed:
```lua
local RezurXLib = loadstring(game:HttpGet(
  "https://raw.githubusercontent.com/AshesOfTheUndead/rezurxlib/main/RezurXLib.lua"
))()
```

**Studio** — drop `RezurXLib.lua` into a `ModuleScript` named `RezurXLib` under `ReplicatedStorage`, then:
```lua
local RezurXLib = require(game.ReplicatedStorage:WaitForChild("RezurXLib"))
```

**Global** — after first load, the library is also reachable as `_G.RezurXLib`.

### Diagnostic banners (v5.3.1)

When the library loads you'll see two prints in the executor output:
```
[RezurXLib] v5.4.0 module loaded. LocalPlayer=… PlayerGui=…
[RezurXLib] CreateWindow called: name="My Panel" theme=Lava host=Auto size=…
```
If neither print appears, the failure is upstream of the library — typically a syntax error in your consumer script. Run `luau-analyze` on your script to find it.

### Callback safety (v5.4.0)

Every `Callback` you pass to any component is isolated: it runs in its own thread, and if it **throws**, the error is contained — the element flashes red, swaps its label to `Callback Error` for one second, and the full error is printed to the output with the element's name. A broken script callback can never freeze or kill the UI. This mirrors the guarded-callback architecture used by Rayfield Gen2, Fluent, WindUI, Maclib and Luna.

---

## CreateWindow — config reference

```lua
local Window = RezurXLib:CreateWindow({
    Name             = "My Panel",      -- or Title =
    Subtitle         = "v1.0",
    LoadingTitle     = "MY PANEL",      -- shown on the boot splash
    LoadingEnabled   = true,
    Theme            = "Lava",          -- see Themes below
    ToggleUIKeybind  = Enum.KeyCode.K,  -- show/hide
    Size             = { 460, 500 },    -- {X, Y}, defaults to 460×500
    Icon             = 4483362458,      -- number id / "rbxassetid://" / emoji text
    Activity         = "running",       -- "running" | "paused" — header beacon
    QuickPause       = function(paused) end,   -- paused pill in the minimized bar
    Density          = "comfortable",  -- "compact" | "comfortable" (auto on mobile)
    DisplayOrder     = 9999,            -- ScreenGui z-order (default 9999)
    Sounds           = true,            -- tactical click table
    BackdropBlur     = true,            -- frost the world behind the window
    ShadowImage      = "rbxassetid://…",  -- optional 9-slice soft shadow
    ConfigurationSaving = { … },       -- see below
    KeySystem       = true,            -- see below
    KeySettings     = { … },
})
```

| Field | Type | Default | Notes |
|---|---|---|---|
| `Name` / `Title` | string | "RezurX UI" | Window title |
| `Subtitle` / `SubTitle` | string | "Control center" | Subtitle |
| `Theme` | string\|table | "Quiet" | Preset name or raw palette |
| `CustomTheme` | table | — | `{ PrimaryAccent=, SecondaryAccent=, CardBackground=, WindowBackground=, TextMain=, … }` — auto-derives the ladder |
| `ToggleUIKeybind` | Enum.KeyCode | K | Show/hide toggle |
| `Size` | {X, Y} | {460, 500} | Clamped to 320×360 … 1200×900 |
| `Icon` | number\|string | — | Asset id, `rbxassetid://…` URI, or emoji text |
| `Host` | string | "Auto" | `"Auto"` (gethui→CoreGui→PlayerGui) · `"PlayerGui"` · `"CoreGui"` · `"gethui"` · `cfg.Parent` |
| `DisplayOrder` | number | 9999 | ScreenGui z-order |
| `Density` | string | auto | `"compact"` for phones, `"comfortable"` for desktop |
| `Sounds` | bool\|table | false | Click sounds (v4.4) |
| `BackdropBlur` | bool | false | Frosts the world (refcounted) |
| `ShadowImage` | string | — | Optional 9-slice shadow asset |
| `Activity` | string | — | `"running"` / `"paused"` header beacon |
| `QuickPause` | function | — | Called from the minimized pill |
| `ReducedMotion` | bool | false | Disable all animation |
| `AnimatedAccents` | bool | false | Opt-in ambient loops |

---

## Window methods

| Method | Returns | Description |
|---|---|---|
| `:CreateTab(name, icon)` | Tab | icon is emoji text or asset id/URI |
| `:Notify({ Title, Content, Duration, Type, Actions })` | toast | Type: `"info"`/`"success"`/`"warn"`/`"error"` |
| `:ShowModal({ Title, Content, ConfirmText, CancelText, ConfirmCallback, CancelCallback })` | `:Confirm`/`:Cancel`/`:Close` | Confirmation dialog |
| `:SaveConfiguration()` | table | Write flagged values to disk (if `ConfigurationSaving.Enabled`) |
| `:LoadConfiguration()` | appliedCount | Read and replay saved values onto elements |
| `:ModifyTheme(name\|palette)` | palette | Swap theme live |
| `:CreateSettingsPanel(name?, icon?)` | Tab | Built-in settings tab (themes, motion, sounds) |
| `:SetToggleKeybind(keycode)` | Enum.KeyCode | Rebind the show/hide key — refuses a key already bound to an element keybind |
| `:OpenCommandPalette()` | overlay | Ctrl+K palette |
| `:SetBrandText(text)` | applied text | Header badge (≤4 UTF-8 chars) |
| `:SetRestoreText(text)` | applied text | Floating restore button text |
| `:Destroy()` | — | Clean up everything |

---

## Tab — components

| Method | Returns | Notes |
|---|---|---|
| `:CreateSection(text)` | `:Set` | Uppercase section label |
| `:CreateDivider(text?)` | obj | Optional-caption rule |
| `:CreateSpacer(pixels?)` | obj | Vertical gap |
| `:CreateLabel(Text, Color?, Bold?, TextSize?, Align?)` | `:Set`/`:SetColor` | Static text line |
| `:CreateParagraph(Title, Content)` | obj | Wrapped title + body |
| `:CreateImage(Image, Height?, ScaleType?, CornerRadius?, Tooltip?)` | obj | Inline image |
| `:CreateButton({ Name, Variant?, Icon?, Callback, Tooltip? })` | `:Set` | Variant: `"Primary"` / `"Secondary"` |
| `:CreateMultiButton({ Buttons, Tooltip? })` | obj | Shared-row actions |
| `:CreateToggle({ Name, CurrentValue?, Callback, Flag? })` | `:Set`/`:Get`/`:Reset` | Animated boolean |
| `:CreateSlider({ Name, Range, CurrentValue, Increment?, Suffix?, Callback, Flag? })` | `:Set`/`:Get`/`:Reset` | Pointer + touch + **typeable value box** (v5.4.0) |
| `:CreateInput({ Name, CurrentValue?, PlaceholderText?, Callback, Flag? })` | `:Set`/`:Get`/`:Reset` | Single-line |
| `:CreateTextArea({ Title, Text?, Placeholder?, Callback?, Flag? })` | `:Set`/`:Get`/`:Reset` | Multi-line |
| `:CreateDropdown({ Name, Options, CurrentOption?, MultipleOptions?, Searchable?, Tooltip?, Callback, Flag? })` | `:Set`/`:Get`/`:Refresh`/`:Add`/`:Remove`/`:Reset` | Single/multi with fuzzy search; living list ops (v5.4.0) |
| `:CreateKeybind({ Name, CurrentKeybind?, HoldToInteract?, Callback, ChangedCallback?, Flag? })` | `:Set`/`:Get`/`:Reset` | Click to rebind; refuses the window toggle key |
| `:CreateColorPicker({ Name, Color?, Presets?, Callback, Flag? })` | `:Set`/`:Get`/`:Reset` | HSV + RGB + Hex + swatches |
| `:CreateAccordion({ Title, DefaultExpanded?, Tooltip? })` | obj | Collapsible container — call its `:Create*` to add children |
| `:CreateBindable({ Name, Keybind?, Enabled?, Callback, Flag? })` | `:SetEnabled`/`:SetKeybind` | Toggle + keybind combined |
| `:CreateNotice({ Title, Content, Type?, Height?, Tooltip? })` | `:Set`/`:SetType` | Durable inline callout |
| `:CreateProgress({ Title, Value, Min?, Max?, Suffix?, Callback?, Flag? })` | `:Set`/`:Get`/`:Reset` | Live meter |
| `:CreateSpinner({ Title, Detail?, Running?, Tooltip?, Flag? })` | `:Start`/`:Stop`/`:Set`/`:Get` | On-demand loader |
| `:CreateCarousel({ Items, CurrentIndex?, Callback?, Tooltip?, Flag? })` | `:Next`/`:Previous`/`:SetItems`/`:Get` | Rotating content |
| `:CreateContextMenu({ Name, ButtonText, Items, Tooltip?, Flag? })` | `:Open`/`:Close`/`:SetItems` | On-demand action menu |
| `:CreateStatus({ Title, Text, State?, Detail?, Value?, Flag? })` | `:Set`/`:Get` | Status indicator |
| `:CreateGraph({ Name, Max?, Bars?, Height?, Suffix?, Sample?, RefreshRate?, Tooltip?, Flag? })` | `:Push`/`:Reset`/`:SetMax`/`:Get` | Live sparkline |
| `:AddStatGrid({ Columns, UpdateRate?, ChipHeight?, Flag?, Tooltip? })` | `:AddChip`/`:UpdateChip`/`:RemoveChip`/`:GetChipCount` | Telemetry chips |
| `:CreateCodeBlock({ Title, Content, CopyCallback?, Height? })` | `:Set`/`:Get` | Monospace copyable |
| `:CreateTable({ Title, Columns, Rows, OnRowActivated?, Height? })` | `:SetRows`/`:GetRows` | Compact data grid |

Every component accepts an optional `Flag = "name"` to opt into `ConfigurationSaving`. Element objects support `:Set()` to programmatically update their state.

---

## Themes

Built-in presets:
- **`Quiet`** — the default neutral palette
- **`Lava`** — warm orange/red
- **`Cyberpunk`** — neon pink/cyan
- **`Obsidian`** — dark with violet accent
- **`Emerald`** — green on charcoal

Register your own:
```lua
RezurXLib:RegisterTheme("Violet", {
    accent    = Color3.fromRGB(136, 105, 244),
    accentHi  = Color3.fromRGB(193, 174, 255),
    accentDim = Color3.fromRGB(88, 66, 170),
    secondary = Color3.fromRGB(244, 105, 192),
    -- missing tokens inherit from Quiet
})

-- Or override per-window without registering:
Window = RezurXLib:CreateWindow({
    CustomTheme = {
        PrimaryAccent   = Color3.fromRGB(136, 105, 244),
        SecondaryAccent = Color3.fromRGB(244, 105, 192),
        CardBackground  = Color3.fromRGB(28, 22, 48),
        WindowBackground= Color3.fromRGB(20, 16, 36),
        TextMain        = Color3.fromRGB(240, 235, 255),
    },
    -- Raw token passthrough also works: { accent = …, panel = …, bg = …, … }
})
```

List at runtime: `RezurXLib:GetThemeNames()`.

---

## ConfigurationSaving (auto-save to disk)

```lua
ConfigurationSaving = {
    Enabled      = true,
    FolderName   = "MyHub",        -- default: "RezurXLib/Configurations"
    FileName     = "AdminPanel",   -- default: game.PlaceId
    Autosave     = true,           -- signature-diffed (no rewrite storms)
    SaveOnUnload = true,           -- flush on :Destroy()
    Notify       = true,           -- toast after restoring
},
```

Every element with a `Flag` persists itself to JSON on the executor filesystem and restores on the next run. Improvements over Rayfield's equivalent:
- **Writes only when values actually changed** (2-second signature diffing)
- **Atomic writes (v5.4.0)** — every save writes a parked `.saving` copy first, reads it back, and only then overwrites the real file. A crash mid-write can never shred your config.
- **Corrupt-file recovery (v5.4.0)** — a config that fails to decode is preserved as `"<name> (Incorrect Format).rezx"`, removed, and you're told — instead of hammering the same corrupt bytes every session.
- **Per-window flag isolation** — multiple windows never mix their configs
- **Loads only after the key gate passes** — callbacks never replay behind a locked UI
- **Manual control**: `Window:SaveConfiguration()` / `Window:LoadConfiguration()`

---

## KeySystem

```lua
KeySystem = true,
KeySettings = {
    Title    = "My Hub",
    Subtitle = "Key System",
    Note     = "Get a key from our Discord.",
    FileName = "MyHubKey",       -- saved under RezurXLib/Keys/
    SaveKey  = true,             -- remember accepted keys (exact-match)
    GrabKeyFromSite = false,     -- or a raw URL to fetch the key
    Key      = { "KEY-1", "KEY-2" },  -- string or list
    MaxAttempts = 5,             -- 0 = unlimited
    OnExhausted = "Lock",        -- "Lock" | "Kick" | "None"
},
```

A styled unlock card in the library's own design language (no external asset download). Elastic shake on wrong keys, attempt counter, saved-key skip, configurable exhaustion policy. The entrance animation defers until the gate passes.

---

## Library-level API

| Method | Description |
|---|---|
| `RezurXLib:CreateWindow(cfg)` | Returns `Window` |
| `RezurXLib:Notify(cfg)` | Routes to the last window |
| `RezurXLib:RegisterTheme(name, palette)` | Adds a theme |
| `RezurXLib:GetThemeNames()` | Sorted list of registered themes |
| `RezurXLib:GetTheme(name)` | Deep clone of a palette |
| `RezurXLib:ModifyTheme(name\|palette)` | Swap theme live across all windows |
| `RezurXLib:RegisterImage(key, image)` | Friendly local alias for an asset |
| `RezurXLib:ResolveImage(image)` | Number / URI / alias → asset string |
| `RezurXLib:SaveConfiguration()` / `:LoadConfiguration(table)` | Serialize/deserialize flagged values |
| `RezurXLib:GetFlag(flag)` | Read a flagged element's current value |
| `RezurXLib:HasFlag(flag)` | Boolean check |
| `RezurXLib:SetReducedMotion(bool)` | Disable all animation globally |
| `RezurXLib:GetStats()` | `{ Version, WindowCount, FlagCount, Themes }` |
| `RezurXLib:GetDocs()` | Machine-readable API metadata |
| `RezurXLib:Destroy()` | Destroy every window + cleanup |

---

## Trust & reliability

- **No telemetry.** Zero analytics, zero data collection.
- **No automatic requests.** The only network/file operations are the ones you explicitly configure (`KeySettings.GrabKeyFromSite`, `ConfigurationSaving`).
- **No executor bypass globals** except `gethui()` (off in plain Roblox).
- **Error-handled.** Every callback wrapped in `pcall`. Every motion path degrades gracefully on slow hosts (frame-time guard, 12-spring budget cap, `ReducedMotion` honored).
- **Memory-safe.** Janitor pattern, flag pruning on element destroy, drag sessions can never outlive their owner.
- **Headless-tested.** 236 integration tests run the entire library against a mocked Roblox API (window creation, every element, drag & touch simulation, config save/load, key gate flows, animation end-states, FPS-throttle verification).
- **Executor-compatible.** Synapse, Krnl, Script-Ware, Xeno, Delta, and more.
- **100% backward compatible.** Existing v3/v4 scripts run unchanged; v5 features are strictly additive.

---

## Repo layout

```
├── src/                    # source modules (lexicographic concat order)
│   ├── 00_core.luau        # constants, motion tokens, services
│   ├── 05_themes.luau      # theme presets + color math
│   ├── 10_motion.luau      # spring solver
│   ├── 15_helpers.luau     # builders, gui-host resolution, Library root
│   ├── 20_window.luau     # Window + every element factory
│   └── 30_api.luau        # Library-level API + GetDocs
├── scripts/build_bundle.py # concatenate src/ → RezurXLib.lua
├── RezurXLib.lua           # the single-file bundle (byte-identical to src/)
├── Example.client.lua      # worked example
├── CHANGELOG.md            # full version history
├── LICENSE                 # MIT
└── README.md               # this file
```

To rebuild the bundle after editing source:
```sh
python3 scripts/build_bundle.py          # writes RezurXLib.lua
python3 scripts/build_bundle.py --check  # verify bundle is up to date
```

---

## Credits

**Creator:** RezurXshin · **Studio:** RezurXLabs · **License:** MIT — see [LICENSE](LICENSE).

Inspired by the Rayfield UI Library and its contributions to the Roblox community. Built with ❤️ for developers and players everywhere.
