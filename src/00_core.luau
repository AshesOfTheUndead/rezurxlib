-- ============================================================
-- RezurXLib v5.3.2 "Aurora" - self-contained Roblox UI library
--
-- Glass + Glow edition: layered depth shadows, a subtle accent rim,
-- spring entrance, staggered tab openings, icon support, an optional
-- key gate, and signature-diffed auto-saving configuration files.
--
-- Original implementation with tokenized themes, pointer-owned input,
-- popup ownership, callback isolation, and no package dependency.
--
-- Trust boundary: no remote loader, telemetry, obfuscation,
-- executor-global call, or automatic file access. The only network and
-- file operations are the ones a developer explicitly configures
-- (KeySettings.GrabKeyFromSite / ConfigurationSaving). Callbacks are
-- supplied by the host game and should target server-validated
-- RemoteEvents where needed.
--
-- USAGE (ModuleScript):
--   local Lib = require(path.to.RezurXLib)
--   local Window = Lib:CreateWindow({
--       Name            = "Admin Panel",
--       Subtitle        = "Management Console",
--       LoadingTitle    = "RezurXLib",
--       LoadingEnabled  = true,
--       Theme           = "Quiet",             -- see Library:GetThemeNames()
--       ToggleUIKeybind = Enum.KeyCode.K,
--       Icon            = 4483362458,          -- number asset id / uri / emoji
--       ConfigurationSaving = { Enabled = true, FileName = "Admin" },
--   })
--   local Tab = Window:CreateTab("Main", "M")
--   Tab:CreateButton({ Name = "Refresh", Callback = function() end })
--   See RezurXExample.client.lua for the full element catalogue.
-- ============================================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local Stats            = game:GetService("Stats")
local CoreGui          = game:GetService("CoreGui")
local GuiService       = game:GetService("GuiService")
local TextService      = game:GetService("TextService")
local HttpService      = game:GetService("HttpService")
local SoundService     = game:GetService("SoundService")
local Lighting         = game:GetService("Lighting")

-- [v5.3.1] NON-YIELDING PLAYER RESOLUTION. The previous pattern
-- (player:WaitForChild("PlayerGui")) at module top yielded the entire
-- loadstring chunk on first run; in some executor bootstraps that yield
-- never resumed if the executor's main thread was already in a task
-- chain, leaving the returned Library nil and the consumer's
-- `Library:CreateWindow(...)` call to silently fail. We now do a
-- non-yielding FindFirstChild; the live PlayerGui is re-resolved on
-- demand inside resolvePlayerGui() (which already handles nil).
local player = Players.LocalPlayer
local playerGui
if player then
        pcall(function()
                playerGui = player:FindFirstChildOfClass("PlayerGui")
        end)
end
-- [v5.3.1] DIAGNOSTIC BANNER: prints exactly once when the module
-- loads so a consumer can confirm (in the executor's output panel)
-- that the loadstring chunk actually ran to completion. Previously a
-- silent failure meant the consumer had no way to tell whether the
-- library never loaded or just never rendered. The banner is gated on
-- RunService:IsStudio() off so plain Studio runs without a print storm
-- when the same script is attached to multiple windows.
pcall(function()
        if RunService and not RunService:IsStudio() then
                print(("[RezurXLib] v5.3.2 module loaded. LocalPlayer=%s PlayerGui=%s"):format(
                        tostring(player),
                        tostring(playerGui and playerGui.Name or "pending")
                ))
        end
end)

-- ============================================================
-- TWEEN PRESETS
-- ============================================================
-- MOTION TOKENS (v5.1.0) — the standardized curve profiles from the
-- Kinetic spec. Every animation resolves to one of these; no ad-hoc
-- durations. Legacy T-constants alias the tokens so existing call sites
-- collapse onto the system without churn.
--   press : 0.08s Sine InOut  — micro tactile feedback, zero latency feel
--   move  : 0.20s Quart Out   — component motion (sliders, toggles, tabs)
--   enter : 0.32s Back Out    — entrances/popups with intentional overshoot
--   settle: 0.24s Quint Out   — general state transitions
--   snap  : 0.12s Quad Out    — hover feedback
-- ============================================================
local MT = {
        instant = nil, -- no tween: write the end state directly
        press   = TweenInfo.new(0.08, Enum.EasingStyle.Sine,  Enum.EasingDirection.InOut), -- micro press feedback
        move    = TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),  -- component motion
        settle  = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),  -- state transitions
        enter   = TweenInfo.new(0.32, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),  -- entrances (spec)
        snap    = TweenInfo.new(0.12, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),  -- hover feedback
}
local T10    = MT.snap
local T15    = MT.snap
local T20    = MT.settle
local T30    = MT.settle
local T40    = MT.settle
local T50    = MT.enter
local T60    = MT.settle
local TMIN   = MT.settle
local TTAB   = MT.move    -- [v5.1.0] tab motion rides the component curve
local TPRESS = MT.press
local TPOP   = MT.enter
local TTOGGLE   = MT.move -- [v5.1.0] toggle travel on the component curve
local TTOGGLEBG = MT.settle

-- ============================================================
-- SHARED CORNER RADII
-- ============================================================
local R = {
        outer  = 20,  -- window shell
        panel  = 12,  -- cards / popups
        control = 10, -- buttons / inputs
        small  = 8,   -- chips / icon tiles
        tab    = 10,  -- tab chips
}
-- PILLS are height-relative: always UDim.new(0.5, 0). Never a fixed
-- offset that fights the element height.
local PILL = UDim.new(0.5, 0)
-- CURVE LAW (v5.0.0), enforced in code — no hand-derived radii:
--   radiusFor(parentRadius, inset): a child inset `inset` px inside a
--   rounded parent inherits parentRadius - inset (clamped >= 0).
--   concentric(radius, pad): a layer extending `pad` px outside a
--   rounded rect inherits radius + pad (the parallel-curve rule).
local function radiusFor(parentRadius, inset)
        return math.max(parentRadius - inset, 0)
end
local function concentric(radius, pad)
        return radius + pad
end

