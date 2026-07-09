#!/usr/bin/env python3
"""Patch the CreateSlider function in RezurXLib.lua to add a transparent overlay
TextButton over the track area. This fixes the issue where tapping on the fill or
knob (children of track with visible backgrounds) doesn't fire track.InputBegan
because the input goes to the child elements instead of the track.
"""
import sys

filepath = "/home/z/my-project/RezurXLib.lua"
with open(filepath, "r") as f:
    src = f.read()

# The old input handler block (track.InputBegan). We replace it with an overlay
# TextButton that covers the entire holder, so taps anywhere on the slider work.
old_block = (
"                                local function setFromX(x)\n"
"                                        local pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)\n"
"                                        local v = snap(minVal + pct * (maxVal - minVal))\n"
"                                        if v ~= value then\n"
"                                                value = v\n"
"                                                obj.CurrentValue = v\n"
"                                                update(false)\n"
"                                        end\n"
"                                end\n"
"                                local function fireCallback()\n"
"                                        if callback then pcall(callback, value) end\n"
"                                end\n"
"                                track.InputBegan:Connect(function(inp)\n"
"                                        if inp.UserInputType == Enum.UserInputType.MouseButton1\n"
"                                                or inp.UserInputType == Enum.UserInputType.Touch then\n"
"                                                Tween(knob, T10, { Size = UDim2.new(0, 20, 0, 20) })\n"
"                                                setFromX(inp.Position.X)\n"
"                                                fireCallback()\n"
"                                                registerDrag(track, function(pos) setFromX(pos.X) end, function()\n"
"                                                        Tween(knob, T10, { Size = UDim2.new(0, 16, 0, 16) })\n"
"                                                        fireCallback()\n"
"                                                end)\n"
"                                        end\n"
"                        end)"
)

# Build the new block with proper indentation (20 spaces for body level, 24 nested, 28 deeper)
I2  = " " * 20
I3  = " " * 24
I4  = " " * 28

new_block = (
I3 + "local function setFromX(x)\n"
+ I4 + "local pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)\n"
+ I4 + "local v = snap(minVal + pct * (maxVal - minVal))\n"
+ I4 + "if v ~= value then\n"
+ I4 + "    value = v\n"
+ I4 + "    obj.CurrentValue = v\n"
+ I4 + "    update(false)\n"
+ I4 + "end\n"
+ I3 + "end\n"
+ I3 + "local function fireCallback()\n"
+ I4 + "if callback then pcall(callback, value) end\n"
+ I3 + "end\n"
+ I3 + "-- [FIX] Transparent overlay button covering the track row. Tapping the\n"
+ I3 + "-- fill or knob (children of track with visible backgrounds) would\n"
+ I3 + "-- otherwise steal the input and track.InputBegan would never fire.\n"
+ I3 + "local hit = Instance.new(\"TextButton\")\n"
+ I3 + "hit.Size = UDim2.new(1, 0, 1, 0)\n"
+ I3 + "hit.BackgroundTransparency = 1\n"
+ I3 + "hit.Text = \"\"\n"
+ I3 + "hit.AutoButtonColor = false\n"
+ I3 + "hit.BorderSizePixel = 0\n"
+ I3 + "hit.ZIndex = 10\n"
+ I3 + "hit.Parent = holder\n"
+ I3 + "hit.InputBegan:Connect(function(inp)\n"
+ I4 + "if inp.UserInputType == Enum.UserInputType.MouseButton1\n"
+ I4 + "    or inp.UserInputType == Enum.UserInputType.Touch then\n"
+ I4 + "    Tween(knob, T10, { Size = UDim2.new(0, 20, 0, 20) })\n"
+ I4 + "    setFromX(inp.Position.X)\n"
+ I4 + "    fireCallback()\n"
+ I4 + "    registerDrag(hit, function(pos) setFromX(pos.X) end, function()\n"
+ I4 + "        Tween(knob, T10, { Size = UDim2.new(0, 16, 0, 16) })\n"
+ I4 + "        fireCallback()\n"
+ I4 + "    end)\n"
+ I4 + "end\n"
+ I3 + "end)"
)

if old_block not in src:
    print("ERROR: slider old block not found")
    # Try to find what's different
    import difflib
    search_snippet = "track.InputBegan:Connect(function(inp)"
    idx = src.find(search_snippet)
    if idx >= 0:
        print(f"Found '{search_snippet}' at index {idx}")
        print("Context (200 chars before, 800 after):")
        print(repr(src[max(0,idx-200):idx+800]))
    sys.exit(1)

new_src = src.replace(old_block, new_block, 1)

with open(filepath, "w") as f:
    f.write(new_src)

print("OK: CreateSlider patched")
