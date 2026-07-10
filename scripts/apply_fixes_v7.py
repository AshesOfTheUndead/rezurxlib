#!/usr/bin/env python3
"""Round 7 — fix drag flinging + improve UI fit.

Root cause of fling: UIScale makes AbsolutePosition (screen px) != Position
offset (unscaled px). Reading one and writing the other = jump.

Fix: Remove UIScale entirely. Size the window to fit the viewport directly.
This is how Rayfield does it — no scale mismatch possible.

Also:
- Bump float icon to 60x60
- Improve drag smoothness (remove threshold for window drag — it causes lag)
- Better default sizing for mobile
"""
import sys

filepath = "/home/z/my-project/RezurXLib.lua"
with open(filepath, "r") as f:
    src = f.read()

edits = 0

def replace_once(old, new, label):
    global src, edits
    if old not in src:
        print(f"ERROR: {label} — old text not found")
        sys.exit(1)
    if src.count(old) > 1:
        print(f"ERROR: {label} — found {src.count(old)} times")
        sys.exit(1)
    src = src.replace(old, new, 1)
    edits += 1
    print(f"OK: {label}")

# ── 1. Remove UIScale, replace with direct fit-to-viewport sizing ──
# The updateScale function used to set UIScale.Scale. Now it resizes
# WIN_W/WIN_H to fit the viewport directly.

old_scale = '''\tlocal uiScale = Instance.new("UIScale")
\tuiScale.Scale = 1
\tuiScale.Parent = screenGui

\t-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
\t-- AUTO SCALE (mobile friendly)
\t-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

\tlocal function getViewport()
\t\tlocal cam = workspace.CurrentCamera
\t\treturn cam and cam.ViewportSize or Vector2.new(1920, 1080)
\tend

\tlocal function updateScale()
\t\tlocal vp = getViewport()
\t\tlocal scaleX = (vp.X - 16) / WIN_W
\t\tlocal scaleY = (vp.Y - 120) / WIN_H
\t\tlocal scale = math.clamp(math.min(scaleX, scaleY), 0.5, 1.0)
\t\tuiScale.Scale = scale
\tend

\tupdateScale()
\tWindowJanitor:Add(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
\t-- Re-apply after delays — camera viewport may not be ready at script start
\ttask.delay(0.3, updateScale)
\ttask.delay(1.0, updateScale)'''

new_scale = '''\t-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
\t-- AUTO FIT (mobile friendly) — no UIScale, direct sizing
\t--
\t-- [FIX] Removed UIScale entirely. UIScale caused drag flinging because
\t-- AbsolutePosition returns screen pixels (post-scale) but Position
\t-- offset is in unscaled pixels — reading one and writing the other
\t-- made the window jump. Rayfield sizes the window directly; we do too.
\t-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

\tlocal function getViewport()
\t\tlocal cam = workspace.CurrentCamera
\t\treturn cam and cam.ViewportSize or Vector2.new(1920, 1080)
\tend

\t-- Default size — will be clamped to viewport on first updateFit
\tlocal DEFAULT_W, DEFAULT_H = WIN_W, WIN_H

\tlocal function updateFit()
\t\tlocal vp = getViewport()
\t\t-- Leave 16px horizontal margin, 120px vertical (status bars + controls)
\t\tlocal maxW = vp.X - 16
\t\tlocal maxH = vp.Y - 120
\t\t-- Clamp to viewport but don't exceed default, don't go below min
\t\tlocal newW = math.clamp(DEFAULT_W, MIN_W, math.min(DEFAULT_W, maxW))
\t\tlocal newH = math.clamp(DEFAULT_H, MIN_H, math.min(DEFAULT_H, maxH))
\t\tif newW ~= WIN_W or newH ~= WIN_H then
\t\t\tWIN_W = newW
\t\t\tWIN_H = newH
\t\t\tframe.Size = UDim2.new(0, WIN_W, 0, WIN_H)
\t\t\tshadow.Size = UDim2.new(0, WIN_W + 36, 0, WIN_H + 36)
\t\t\tif not Window._minimized then
\t\t\t\tbody.Size = UDim2.new(1, 0, 0, WIN_H - HEADER_H)
\t\t\tend
\t\tend
\tend

\t-- updateScale alias for code that references it (resize handle etc)
\tlocal function updateScale() updateFit() end'''

replace_once(old_scale, new_scale, "1. remove UIScale, add updateFit")

# ── 2. Fix initial position to offset-only (no scale component) ──
# This eliminates the first-drag jump from scale→offset conversion
replace_once(
    '\tshadow.Position = UDim2.new(0.5, -(WIN_W + 36) / 2, 0.55, -(WIN_H + 36) / 2)',
    '\tshadow.Position = UDim2.new(0, 0, 0, 0)  -- set properly by updateFit+centerWindow',
    "2a. shadow position offset-only"
)
replace_once(
    '\tframe.Position = UDim2.new(0.5, -WIN_W / 2, 0.55, -WIN_H / 2)',
    '\tframe.Position = UDim2.new(0, 0, 0, 0)  -- set properly by updateFit+centerWindow',
    "2b. frame position offset-only"
)

# Add centerWindow function and call it after frame/shadow exist.
# Insert right after the updateScale alias definition.
# Find the line with 'local function updateScale() updateFit() end' and add after it
replace_once(
    '\tlocal function updateScale() updateFit() end',
    '''\tlocal function updateScale() updateFit() end

\t-- Center the window on screen (offset-only, no scale component)
\tlocal function centerWindow()
\t\tlocal vp = getViewport()
\t\tlocal nx = math.floor((vp.X - WIN_W) / 2)
\t\tlocal ny = math.floor((vp.Y - WIN_H) / 2 - 20)  -- slightly above center
\t\tframe.Position = UDim2.new(0, nx, 0, ny)
\t\tshadow.Position = UDim2.new(0, nx - 18, 0, ny - 18)
\tend

\t-- Apply fit + center on load
\tupdateFit()
\tcenterWindow()
\tWindowJanitor:Add(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
\t\tupdateFit()
\t\tcenterWindow()
\tend))
\ttask.delay(0.3, function() updateFit() centerWindow() end)
\ttask.delay(1.0, function() updateFit() centerWindow() end)''',
    "2c. add centerWindow + initial call"
)

# ── 3. Fix window drag — no threshold (causes lag), use current WIN_W ──
replace_once(
    '''\t\t\tlocal dragStart = inp.Position
\t\t\tlocal startAbs = frame.AbsolutePosition
\t\t\tTween(shadow, T15, { BackgroundTransparency = 0.65 })
\t\t\tlocal vp = getViewport()
\t\t\t-- Threshold of 3px prevents accidental drags on tap
\t\t\tregisterDrag("window", function(pos)
\t\t\t\tlocal d = pos - dragStart
\t\t\t\tlocal nx = math.clamp(startAbs.X + d.X, -WIN_W + 100, vp.X - 100)
\t\t\t\tlocal ny = math.clamp(startAbs.Y + d.Y, 0, vp.Y - 30)
\t\t\t\tframe.Position = UDim2.new(0, nx, 0, ny)
\t\t\t\tshadow.Position = UDim2.new(0, nx - 18, 0, ny - 18)
\t\t\tend, function()
\t\t\t\tTween(shadow, T15, { BackgroundTransparency = 0.52 })
\t\t\tend, 3)''',

    '''\t\t\tlocal dragStart = inp.Position
\t\t\tlocal startAbs = frame.AbsolutePosition
\t\t\tTween(shadow, T15, { BackgroundTransparency = 0.65 })
\t\t\tlocal vp = getViewport()
\t\t\tregisterDrag("window", function(pos)
\t\t\t\tlocal d = pos - dragStart
\t\t\t\tlocal nx = math.clamp(startAbs.X + d.X, 0, math.max(0, vp.X - 80))
\t\t\t\tlocal ny = math.clamp(startAbs.Y + d.Y, 0, math.max(0, vp.Y - 40))
\t\t\t\tframe.Position = UDim2.new(0, nx, 0, ny)
\t\t\t\tshadow.Position = UDim2.new(0, nx - 18, 0, ny - 18)
\t\t\tend, function()
\t\t\t\tTween(shadow, T15, { BackgroundTransparency = 0.52 })
\t\t\tend)''',
    "3. window drag no threshold, better clamp"
)

# ── 4. Fix status bar drag — same approach ──
replace_once(
    '''\t\t\tlocal dragStart = inp.Position
\t\t\tlocal startAbs = frame.AbsolutePosition
\t\t\tTween(shadow, T15, { BackgroundTransparency = 0.65 })
\t\t\tlocal vp = getViewport()
\t\t\tregisterDrag("statusbar", function(pos)
\t\t\t\tlocal d = pos - dragStart
\t\t\t\tlocal nx = math.clamp(startAbs.X + d.X, -WIN_W + 100, vp.X - 100)
\t\t\t\tlocal ny = math.clamp(startAbs.Y + d.Y, 0, vp.Y - 30)
\t\t\t\tframe.Position = UDim2.new(0, nx, 0, ny)
\t\t\t\tshadow.Position = UDim2.new(0, nx - 18, 0, ny - 18)
\t\t\tend, function()
\t\t\t\tTween(shadow, T15, { BackgroundTransparency = 0.52 })
\t\t\tend, 3)''',

    '''\t\t\tlocal dragStart = inp.Position
\t\t\tlocal startAbs = frame.AbsolutePosition
\t\t\tTween(shadow, T15, { BackgroundTransparency = 0.65 })
\t\t\tlocal vp = getViewport()
\t\t\tregisterDrag("statusbar", function(pos)
\t\t\t\tlocal d = pos - dragStart
\t\t\t\tlocal nx = math.clamp(startAbs.X + d.X, 0, math.max(0, vp.X - 80))
\t\t\t\tlocal ny = math.clamp(startAbs.Y + d.Y, 0, math.max(0, vp.Y - 40))
\t\t\t\tframe.Position = UDim2.new(0, nx, 0, ny)
\t\t\t\tshadow.Position = UDim2.new(0, nx - 18, 0, ny - 18)
\t\t\tend, function()
\t\t\t\tTween(shadow, T15, { BackgroundTransparency = 0.52 })
\t\t\tend)''',
    "4. status bar drag no threshold"
)

# ── 5. Bump float icon to 60x60 + fix drag clamp ──
replace_once(
    '\tfloatIcon.Size = UDim2.new(0, 52, 0, 52)',
    '\tfloatIcon.Size = UDim2.new(0, 60, 0, 60)',
    "5a. float icon 60x60"
)
replace_once(
    '''\t\t\tlocal nx = math.clamp(startAbs.X + d.X, 0, vp.X - 52)
\t\t\t\t\tlocal ny = math.clamp(startAbs.Y + d.Y, 0, vp.Y - 52)''',
    '''\t\t\tlocal nx = math.clamp(startAbs.X + d.X, 0, math.max(0, vp.X - 60))
\t\t\t\t\tlocal ny = math.clamp(startAbs.Y + d.Y, 0, math.max(0, vp.Y - 60))''',
    "5b. float icon drag clamp 60"
)

# ── 6. Fix dropdown — remove UIScale division (no UIScale anymore) ──
replace_once(
    '''\t\t\t\t-- Compensate for UIScale: divide SIZE by scale so the
\t\t\t\t-- popup's visual width matches the holder's visual width.
\t\t\t\t-- Position is NOT divided — Position offset is in screen
\t\t\t\t-- pixels and UIScale doesn't affect it.
\t\t\t\tlocal s = uiScale.Scale
\t\t\t\tif s <= 0 then s = 1 end

\t\t\t\tlocal ITEM_H = 30
\t\t\t\tlocal LIST_H = math.min(#options, 7) * (ITEM_H + 2) + 10
\t\t\t\tlocal cam = workspace.CurrentCamera
\t\t\t\tlocal vpH = cam and cam.ViewportSize.Y or 800
\t\t\t\tlocal dropDown = (hPos.Y + hSize.Y + LIST_H + 6 <= vpH)
\t\t\t\tlocal listY = dropDown and (hPos.Y + hSize.Y + 4) or (hPos.Y - LIST_H - 4)

\t\t\t\tlocal list = Instance.new("ScrollingFrame")
\t\t\t\tlist.Size = UDim2.new(0, hSize.X / s, 0, 0)''',

    '''\t\t\t\tlocal ITEM_H = 30
\t\t\t\tlocal LIST_H = math.min(#options, 7) * (ITEM_H + 2) + 10
\t\t\t\tlocal cam = workspace.CurrentCamera
\t\t\t\tlocal vpH = cam and cam.ViewportSize.Y or 800
\t\t\t\tlocal dropDown = (hPos.Y + hSize.Y + LIST_H + 6 <= vpH)
\t\t\t\tlocal listY = dropDown and (hPos.Y + hSize.Y + 4) or (hPos.Y - LIST_H - 4)

\t\t\t\t-- [FIX] No UIScale division — UIScale was removed. hSize is
\t\t\t\t-- already in screen pixels, list uses it directly.
\t\t\t\tlocal list = Instance.new("ScrollingFrame")
\t\t\t\tlist.Size = UDim2.new(0, hSize.X, 0, 0)''',
    "6a. dropdown no UIScale division"
)

# Fix the Tween on list size too
replace_once(
    '''\t\t\tTween(list, T15, {
\t\t\t\t\tSize = UDim2.new(0, hSize.X / s, 0, LIST_H),
\t\t\t\t\tPosition = UDim2.new(0, hPos.X, 0, listY),
\t\t\t\t\tBackgroundTransparency = 0,
\t\t\t\t})''',
    '''\t\t\tTween(list, T15, {
\t\t\t\t\tSize = UDim2.new(0, hSize.X, 0, LIST_H),
\t\t\t\t\tPosition = UDim2.new(0, hPos.X, 0, listY),
\t\t\t\t\tBackgroundTransparency = 0,
\t\t\t\t})''',
    "6b. dropdown tween no UIScale"
)

# ── 7. Fix color picker — remove UIScale reference ──
replace_once(
    '''\t\t\t\t-- Position popup near the swatch — account for UIScale on SIZE only
\t\t\t\tlocal sp = swatch.AbsolutePosition
\t\t\t\tlocal scale = uiScale.Scale
\t\t\t\tif scale <= 0 then scale = 1 end
\t\t\t\tlocal cam = workspace.CurrentCamera''',
    '''\t\t\t\t-- Position popup near the swatch
\t\t\t\tlocal sp = swatch.AbsolutePosition
\t\t\t\tlocal cam = workspace.CurrentCamera''',
    "7. color picker no UIScale"
)

with open(filepath, "w") as f:
    f.write(src)

print(f"\n{edits} edits applied.")
