#!/usr/bin/env python3
"""Patch the CreateToggle function in RezurXLib.lua to:
1. Add a transparent overlay TextButton (hit) that captures ALL taps on the holder,
   including over sw/knob which have visible backgrounds that steal input on mobile.
2. Add a SetLabel method so toggles can update their text dynamically (PVP: ON/OFF).
3. Switch from holder.InputBegan to hit.Activated for more reliable touch handling.
"""
import sys

filepath = "/home/z/my-project/RezurXLib.lua"
with open(filepath, "r") as f:
    src = f.read()

# 16 spaces per indent level (matches the file's actual indentation)
IND = " " * 16  # function tab:CreateToggle level
I2  = " " * 20  # body level
I3  = " " * 24  # nested
I4  = " " * 28  # deeper

start_marker = IND + "function tab:CreateToggle(tcfg)"
end_marker = IND + "end\n\n" + IND + "-- ========================================================\n" + IND + "-- CreateSlider"

start_idx = src.find(start_marker)
if start_idx == -1:
    print("ERROR: start marker not found")
    sys.exit(1)

end_idx = src.find(end_marker, start_idx)
if end_idx == -1:
    print("ERROR: end marker not found")
    sys.exit(1)

end_of_end = end_idx + len(IND + "end")

old_block = src[start_idx:end_of_end]

new_block = (
IND + "function tab:CreateToggle(tcfg)\n"
+ I2 + "tcfg = tcfg or {}\n"
+ I2 + "local nameText = tcfg.Name or \"Toggle\"\n"
+ I2 + "local callback = tcfg.Callback\n"
+ I2 + "local state = tcfg.CurrentValue == true\n"
+ "\n"
+ I2 + "local holder, hStroke = makeHolder(42)\n"
+ I2 + "local lbl = Instance.new(\"TextLabel\")\n"
+ I2 + "lbl.Size = UDim2.new(1, -68, 1, 0)\n"
+ I2 + "lbl.Position = UDim2.new(0, 14, 0, 0)\n"
+ I2 + "lbl.BackgroundTransparency = 1\n"
+ I2 + "lbl.Font = Enum.Font.GothamMedium\n"
+ I2 + "lbl.TextSize = 13\n"
+ I2 + "lbl.TextColor3 = C.text\n"
+ I2 + "lbl.TextXAlignment = Enum.TextXAlignment.Left\n"
+ I2 + "lbl.Text = nameText\n"
+ I2 + "lbl.Parent = holder\n"
+ "\n"
+ I2 + "local sw = Instance.new(\"Frame\")\n"
+ I2 + "sw.Size = UDim2.new(0, 42, 0, 22)\n"
+ I2 + "sw.Position = UDim2.new(1, -52, 0.5, -11)\n"
+ I2 + "sw.BackgroundColor3 = state and C.accent or C.track\n"
+ I2 + "sw.BorderSizePixel = 0\n"
+ I2 + "sw.Parent = holder\n"
+ I2 + "corner(sw, UDim.new(1, 0))\n"
+ "\n"
+ I2 + "local knob = Instance.new(\"Frame\")\n"
+ I2 + "knob.Size = UDim2.new(0, 18, 0, 18)\n"
+ I2 + "knob.Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)\n"
+ I2 + "knob.BackgroundColor3 = C.white\n"
+ I2 + "knob.BorderSizePixel = 0\n"
+ I2 + "knob.Parent = sw\n"
+ I2 + "corner(knob, UDim.new(1, 0))\n"
+ "\n"
+ I2 + "-- [FIX] Transparent overlay button — captures ALL taps on the\n"
+ I2 + "-- holder (including over sw/knob which have visible backgrounds\n"
+ I2 + "-- and would otherwise steal the input on mobile touch).\n"
+ I2 + "local hit = Instance.new(\"TextButton\")\n"
+ I2 + "hit.Size = UDim2.new(1, 0, 1, 0)\n"
+ I2 + "hit.BackgroundTransparency = 1\n"
+ I2 + "hit.Text = \"\"\n"
+ I2 + "hit.AutoButtonColor = false\n"
+ I2 + "hit.BorderSizePixel = 0\n"
+ I2 + "hit.ZIndex = 10\n"
+ I2 + "hit.Parent = holder\n"
+ "\n"
+ I2 + "local obj = { CurrentValue = state }\n"
+ I2 + "local function apply(v, silent)\n"
+ I3 + "state = v\n"
+ I3 + "obj.CurrentValue = v\n"
+ I3 + "Tween(sw, T20, { BackgroundColor3 = state and C.accent or C.track })\n"
+ I3 + "Tween(hStroke, T20, { Color = state and C.accentDim or C.border })\n"
+ I3 + "Tween(knob, T50, {\n"
+ I4 + "Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)\n"
+ I3 + "})\n"
+ I3 + "if callback and not silent then pcall(callback, state) end\n"
+ I2 + "end\n"
+ I2 + "function obj:Set(v) apply(v) end\n"
+ I2 + "function obj:SetLabel(newText) lbl.Text = newText end\n"
+ I2 + "function obj:Get() return state end\n"
+ "\n"
+ I2 + "hit.Activated:Connect(function()\n"
+ I3 + "apply(not state)\n"
+ I2 + "end)\n"
+ I2 + "onTheme(function()\n"
+ I3 + "Tween(holder, T20, { BackgroundColor3 = C.panel })\n"
+ I3 + "Tween(lbl, T20, { TextColor3 = C.text })\n"
+ I3 + "Tween(sw, T20, { BackgroundColor3 = state and C.accent or C.track })\n"
+ I3 + "Tween(hStroke, T20, { Color = state and C.accentDim or C.border })\n"
+ I2 + "end)\n"
+ I2 + "registerFlag(tcfg.Flag, obj)\n"
+ I2 + "return obj\n"
+ IND + "end"
)

new_src = src[:start_idx] + new_block + src[end_of_end:]

with open(filepath, "w") as f:
    f.write(new_src)

print("OK: CreateToggle patched")
print(f"Old block length: {len(old_block)} chars")
print(f"New block length: {len(new_block)} chars")
