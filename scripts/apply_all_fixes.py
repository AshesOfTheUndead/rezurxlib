#!/usr/bin/env python3
"""Apply all RezurXLib.lua fixes, preserving each section's actual indentation.
The file mixes tabs and spaces in different sections (messy but we work with it).
"""
import sys

filepath = "/home/z/my-project/RezurXLib.lua"
with open(filepath, "r") as f:
    src = f.read()

T = "\t"
S8 = " " * 8  # dragBar section uses 8 spaces
edits_applied = 0

def replace_once(old, new, label):
    global src, edits_applied
    if old not in src:
        print(f"ERROR: {label} — old text not found")
        sys.exit(1)
    count = src.count(old)
    if count > 1:
        print(f"ERROR: {label} — old text found {count} times (expected 1)")
        sys.exit(1)
    src = src.replace(old, new, 1)
    edits_applied += 1
    print(f"OK: {label}")

# ── Fix 1: Mobile scaling (uses tabs, 1 tab base) ──
replace_once(
    T + "local function updateScale()\n"
    + T*2 + "local vp = getViewport()\n"
    + T*2 + "local scaleX = (vp.X - 20) / WIN_W\n"
    + T*2 + "local scaleY = (vp.Y - 60) / WIN_H\n"
    + T*2 + "local scale = math.clamp(math.min(scaleX, scaleY), 0.5, 1.0)\n"
    + T*2 + "if screenGui:FindFirstChild(\"UIScale\") then\n"
    + T*3 + "screenGui.UIScale.Scale = scale\n"
    + T*2 + "end\n"
    + T + "end",

    T + "local function updateScale()\n"
    + T*2 + "local vp = getViewport()\n"
    + T*2 + "-- Mobile-friendly: leave room for top status bar + bottom controls\n"
    + T*2 + "local scaleX = (vp.X - 16) / WIN_W\n"
    + T*2 + "local scaleY = (vp.Y - 120) / WIN_H\n"
    + T*2 + "-- Allow shrinking down to 0.35 on small phones (was 0.5 — too big)\n"
    + T*2 + "local scale = math.clamp(math.min(scaleX, scaleY), 0.35, 1.0)\n"
    + T*2 + "if screenGui:FindFirstChild(\"UIScale\") then\n"
    + T*3 + "screenGui.UIScale.Scale = scale\n"
    + T*2 + "end\n"
    + T + "end",
    "Fix 1: mobile scaling"
)

# ── Fix 2: Window position (1 tab) ──
replace_once(
    T + "shadow.Position = UDim2.new(0.5, -(WIN_W + 36) / 2, 0.4, -(WIN_H + 36) / 2)",
    T + "shadow.Position = UDim2.new(0.5, -(WIN_W + 36) / 2, 0.5, -(WIN_H + 36) / 2)",
    "Fix 2a: shadow position"
)
replace_once(
    T + "frame.Position = UDim2.new(0.5, -WIN_W / 2, 0.4, -WIN_H / 2)",
    T + "frame.Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2)",
    "Fix 2b: frame position"
)

# ── Fix 3: dragBar ZIndex (8 spaces) ──
replace_once(
    S8 + "dragBar.ZIndex = 3\n",
    S8 + "-- [FIX] ZIndex 6 = above logoGlow(4), statFrame(5), logo(5), subLbl(5)\n"
    + S8 + "-- but dragBar ends 80px before right edge, so minBtn/closeBtn stay tappable\n"
    + S8 + "dragBar.ZIndex = 6\n",
    "Fix 3: dragBar ZIndex"
)

# ── Fix 6: Delayed re-scale (1 tab) ──
replace_once(
    T + "updateScale()\n"
    + T + "WindowJanitor:Add(workspace.CurrentCamera:GetPropertyChangedSignal(\"ViewportSize\"):Connect(updateScale))\n"
    + T + "local uiScale = Instance.new(\"UIScale\")\n"
    + T + "uiScale.Scale = 1\n"
    + T + "uiScale.Parent = screenGui\n",

    T + "updateScale()\n"
    + T + "WindowJanitor:Add(workspace.CurrentCamera:GetPropertyChangedSignal(\"ViewportSize\"):Connect(updateScale))\n"
    + T + "local uiScale = Instance.new(\"UIScale\")\n"
    + T + "uiScale.Scale = 1\n"
    + T + "uiScale.Parent = screenGui\n"
    + T + "-- [FIX] Re-apply scale after delay — camera viewport may not be ready at script start\n"
    + T + "task.delay(0.3, updateScale)\n"
    + T + "task.delay(1.0, updateScale)\n",
    "Fix 6: delayed re-scale"
)

# ── Fix 4: Toggle — add overlay button + SetLabel (2 tabs base) ──
toggle_start = T*2 + "function tab:CreateToggle(tcfg)"
toggle_end_marker = T*2 + "end\n\n" + T*2 + "-- ========================================================\n" + T*2 + "-- CreateSlider"
ts_idx = src.find(toggle_start)
if ts_idx == -1:
    print("ERROR: toggle start not found"); sys.exit(1)
te_idx = src.find(toggle_end_marker, ts_idx)
if te_idx == -1:
    print("ERROR: toggle end not found"); sys.exit(1)
te_end = te_idx + len(T*2 + "end")

new_toggle = (
T*2 + "function tab:CreateToggle(tcfg)\n"
+ T*3 + "tcfg = tcfg or {}\n"
+ T*3 + "local nameText = tcfg.Name or \"Toggle\"\n"
+ T*3 + "local callback = tcfg.Callback\n"
+ T*3 + "local state = tcfg.CurrentValue == true\n"
+ "\n"
+ T*3 + "local holder, hStroke = makeHolder(42)\n"
+ T*3 + "local lbl = Instance.new(\"TextLabel\")\n"
+ T*3 + "lbl.Size = UDim2.new(1, -68, 1, 0)\n"
+ T*3 + "lbl.Position = UDim2.new(0, 14, 0, 0)\n"
+ T*3 + "lbl.BackgroundTransparency = 1\n"
+ T*3 + "lbl.Font = Enum.Font.GothamMedium\n"
+ T*3 + "lbl.TextSize = 13\n"
+ T*3 + "lbl.TextColor3 = C.text\n"
+ T*3 + "lbl.TextXAlignment = Enum.TextXAlignment.Left\n"
+ T*3 + "lbl.Text = nameText\n"
+ T*3 + "lbl.Parent = holder\n"
+ "\n"
+ T*3 + "local sw = Instance.new(\"Frame\")\n"
+ T*3 + "sw.Size = UDim2.new(0, 42, 0, 22)\n"
+ T*3 + "sw.Position = UDim2.new(1, -52, 0.5, -11)\n"
+ T*3 + "sw.BackgroundColor3 = state and C.accent or C.track\n"
+ T*3 + "sw.BorderSizePixel = 0\n"
+ T*3 + "sw.Parent = holder\n"
+ T*3 + "corner(sw, UDim.new(1, 0))\n"
+ "\n"
+ T*3 + "local knob = Instance.new(\"Frame\")\n"
+ T*3 + "knob.Size = UDim2.new(0, 18, 0, 18)\n"
+ T*3 + "knob.Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)\n"
+ T*3 + "knob.BackgroundColor3 = C.white\n"
+ T*3 + "knob.BorderSizePixel = 0\n"
+ T*3 + "knob.Parent = sw\n"
+ T*3 + "corner(knob, UDim.new(1, 0))\n"
+ "\n"
+ T*3 + "-- [FIX] Transparent overlay button — captures ALL taps on the holder\n"
+ T*3 + "-- (including over sw/knob which have visible backgrounds and would\n"
+ T*3 + "-- otherwise steal the input on mobile touch).\n"
+ T*3 + "local hit = Instance.new(\"TextButton\")\n"
+ T*3 + "hit.Size = UDim2.new(1, 0, 1, 0)\n"
+ T*3 + "hit.BackgroundTransparency = 1\n"
+ T*3 + "hit.Text = \"\"\n"
+ T*3 + "hit.AutoButtonColor = false\n"
+ T*3 + "hit.BorderSizePixel = 0\n"
+ T*3 + "hit.ZIndex = 10\n"
+ T*3 + "hit.Parent = holder\n"
+ "\n"
+ T*3 + "local obj = { CurrentValue = state }\n"
+ T*3 + "local function apply(v, silent)\n"
+ T*4 + "state = v\n"
+ T*4 + "obj.CurrentValue = v\n"
+ T*4 + "Tween(sw, T20, { BackgroundColor3 = state and C.accent or C.track })\n"
+ T*4 + "Tween(hStroke, T20, { Color = state and C.accentDim or C.border })\n"
+ T*4 + "Tween(knob, T50, {\n"
+ T*5 + "Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)\n"
+ T*4 + "})\n"
+ T*4 + "if callback and not silent then pcall(callback, state) end\n"
+ T*3 + "end\n"
+ T*3 + "function obj:Set(v) apply(v) end\n"
+ T*3 + "function obj:SetLabel(newText) lbl.Text = newText end\n"
+ T*3 + "function obj:Get() return state end\n"
+ "\n"
+ T*3 + "hit.Activated:Connect(function()\n"
+ T*4 + "apply(not state)\n"
+ T*3 + "end)\n"
+ T*3 + "onTheme(function()\n"
+ T*4 + "Tween(holder, T20, { BackgroundColor3 = C.panel })\n"
+ T*4 + "Tween(lbl, T20, { TextColor3 = C.text })\n"
+ T*4 + "Tween(sw, T20, { BackgroundColor3 = state and C.accent or C.track })\n"
+ T*4 + "Tween(hStroke, T20, { Color = state and C.accentDim or C.border })\n"
+ T*3 + "end)\n"
+ T*3 + "registerFlag(tcfg.Flag, obj)\n"
+ T*3 + "return obj\n"
+ T*2 + "end"
)
src = src[:ts_idx] + new_toggle + src[te_end:]
edits_applied += 1
print("OK: Fix 4: toggle overlay + SetLabel")

# ── Fix 5: Slider — add overlay button over track (4 tabs base) ──
slider_old = (
T*4 + "local function setFromX(x)\n"
+ T*5 + "local pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)\n"
+ T*5 + "local v = snap(minVal + pct * (maxVal - minVal))\n"
+ T*5 + "if v ~= value then\n"
+ T*6 + "value = v\n"
+ T*6 + "obj.CurrentValue = v\n"
+ T*6 + "update(false)\n"
+ T*5 + "end\n"
+ T*4 + "end\n"
+ T*4 + "local function fireCallback()\n"
+ T*5 + "if callback then pcall(callback, value) end\n"
+ T*4 + "end\n"
+ T*4 + "track.InputBegan:Connect(function(inp)\n"
+ T*5 + "if inp.UserInputType == Enum.UserInputType.MouseButton1\n"
+ T*6 + "or inp.UserInputType == Enum.UserInputType.Touch then\n"
+ T*6 + "Tween(knob, T10, { Size = UDim2.new(0, 20, 0, 20) })\n"
+ T*6 + "setFromX(inp.Position.X)\n"
+ T*6 + "fireCallback()\n"
+ T*6 + "registerDrag(track, function(pos) setFromX(pos.X) end, function()\n"
+ T*7 + "Tween(knob, T10, { Size = UDim2.new(0, 16, 0, 16) })\n"
+ T*7 + "fireCallback()\n"
+ T*6 + "end)\n"
+ T*5 + "end\n"
+ T*3 + "end)"
)

slider_new = (
T*4 + "local function setFromX(x)\n"
+ T*5 + "local pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)\n"
+ T*5 + "local v = snap(minVal + pct * (maxVal - minVal))\n"
+ T*5 + "if v ~= value then\n"
+ T*6 + "value = v\n"
+ T*6 + "obj.CurrentValue = v\n"
+ T*6 + "update(false)\n"
+ T*5 + "end\n"
+ T*4 + "end\n"
+ T*4 + "local function fireCallback()\n"
+ T*5 + "if callback then pcall(callback, value) end\n"
+ T*4 + "end\n"
+ T*4 + "-- [FIX] Transparent overlay covering the whole holder. Tapping the\n"
+ T*4 + "-- fill or knob (children of track with visible backgrounds) would\n"
+ T*4 + "-- otherwise steal input and track.InputBegan would never fire.\n"
+ T*4 + "local hit = Instance.new(\"TextButton\")\n"
+ T*3 + "hit.Size = UDim2.new(1, 0, 1, 0)\n"
+ T*3 + "hit.BackgroundTransparency = 1\n"
+ T*3 + "hit.Text = \"\"\n"
+ T*3 + "hit.AutoButtonColor = false\n"
+ T*3 + "hit.BorderSizePixel = 0\n"
+ T*3 + "hit.ZIndex = 10\n"
+ T*3 + "hit.Parent = holder\n"
+ T*3 + "hit.InputBegan:Connect(function(inp)\n"
+ T*4 + "if inp.UserInputType == Enum.UserInputType.MouseButton1\n"
+ T*5 + "or inp.UserInputType == Enum.UserInputType.Touch then\n"
+ T*5 + "Tween(knob, T10, { Size = UDim2.new(0, 20, 0, 20) })\n"
+ T*5 + "setFromX(inp.Position.X)\n"
+ T*5 + "fireCallback()\n"
+ T*5 + "registerDrag(hit, function(pos) setFromX(pos.X) end, function()\n"
+ T*6 + "Tween(knob, T10, { Size = UDim2.new(0, 16, 0, 16) })\n"
+ T*6 + "fireCallback()\n"
+ T*5 + "end)\n"
+ T*4 + "end\n"
+ T*3 + "end)"
)

if slider_old not in src:
    print("ERROR: slider old block not found")
    idx = src.find("track.InputBegan:Connect")
    if idx >= 0:
        print(f"Found track.InputBegan at index {idx}")
        print("Context (50 chars before, 600 after):")
        print(repr(src[max(0,idx-50):idx+600]))
    sys.exit(1)

src = src.replace(slider_old, slider_new, 1)
edits_applied += 1
print("OK: Fix 5: slider overlay")

with open(filepath, "w") as f:
    f.write(src)

print(f"\nAll {edits_applied} edits applied successfully.")
