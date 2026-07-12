# 👑 RezurXLab — Rayfield UI Clone + DOMINUS Engine

A RezurXLab UI library (RezurXLib) with the same API surface as Rayfield, plus the DOMINUS V7 engine for Train to Fight.

## 📦 Files

| File | Description |
|------|-------------|
| `RezurXLib.lua` | The UI library (ModuleScript). Janitor, shared drag router, Tween manager, themes, full component set. |
| `DOMINUS_V7.luau` | DOMINUS V7 engine — loads RezurXLib from this repo, wires the full farm/noclip/chat/ESP engine. 1000 workers, math.huge, PVP Off default ON. |
| `ExampleUsage.client.lua` | Example admin panel showing all RezurXLib components. |

## 🚀 Quick Start (DOMINUS V7)

Execute `DOMINUS_V7.luau` in your executor. It auto-loads RezurXLib from this repo's `main` branch.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/AshesOfTheUndead/rayfield-ui-clone/main/DOMINUS_V7.luau"))()
```

## 🎨 RezurXLib Features

- **Frame-synchronized gestures** — one pointer owner with exponential smoothing, touch capture, cancellation, and no per-move tween spam
- **Scale-correct positioning** — drag, resize, restore control, dropdowns, and color picker stay anchored and viewport-clamped on desktop and mobile
- **Lifecycle safety** — window teardown cancels active gestures, closes overlays, clears flags, and removes stale window references
- **Conflict-free tween manager** — newer property animations cancel superseded work cleanly
- **7 themes** — Ember, Ocean, Crimson, Slate, Midnight, Forest, and Coral
- **Full component suite** — Button, MultiButton, Toggle, Slider, Dropdown, ColorPicker, Input, Keybind, Bindable, Paragraph, Label, Divider, Section, Image, Spacer, and Accordion
- **Hardened state** — zero-range sliders, invalid values, keybind configuration round-trips, empty selections, and focused text input are handled safely
- **Responsive chrome** — compact header behavior, readable phone scaling, draggable restore control, minimize, resize, loading, and notifications
- **Drop-in compatibility** — existing Rayfield-shaped constructors, flags, callbacks, short aliases, and configuration APIs remain supported

## ⚡ DOMINUS V7 Engine

- 1000 max workers (100 default)
- `math.huge` train speed
- 0.001s worker loop (no anti-cheat delays)
- PVP Off default ON (0.2s aggressive spam, multiple area paths)
- Adaptive throttle (FPS + gains trend based)
- Overnight mode (5min work / 30s break cycles)
- Turbo boost (2x / 10s, 5s cooldown)
- V777 + Improved noclip (no upward glitch)
- ESP with cached BillboardGuis
- Chat bypass with RichText + color pickers
- Save/Load profiles
- Keyboard shortcuts (K, Ctrl+F, Ctrl+N, Ctrl+T)

## 👑 Credits

**Creator:** RezurXshin  
**Studio:** RezurXLabs  
**All rights reserved.** (c) 2026 RezurXshin.

---

## Next.js Project (v0)

This repository also contains a Next.js project for the RezurXLab website.

```bash
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000).
