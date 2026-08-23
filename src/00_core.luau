-- ============================================================
-- RezurXLib v4.0 "Aurora" - self-contained Roblox UI library
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

local player    = Players.LocalPlayer
local playerGui = player and player:WaitForChild("PlayerGui")

-- ============================================================
-- TWEEN PRESETS
-- ============================================================
-- MOTION TOKENS (v5.0.0) — exactly four named curves. Every
-- animation in the library resolves to one of these; no ad-hoc
-- durations. The legacy T-constants alias the tokens so existing
-- call sites collapse onto the system without churn.
-- ============================================================
local MT = {
        instant = nil, -- no tween: write the end state directly
        snap    = TweenInfo.new(0.12, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out), -- hover / press feedback
        settle  = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), -- state transitions
        enter   = TweenInfo.new(0.42, Enum.EasingStyle.Back,  Enum.EasingDirection.Out), -- entrances / arrivals
}
local T10    = MT.snap    -- hover/press
local T15    = MT.snap
local T20    = MT.settle  -- state changes
local T30    = MT.settle
local T40    = MT.settle  -- fades (opacity reads fine on settle)
local T50    = MT.enter
local T60    = MT.settle
local TMIN   = MT.settle  -- minimize/expand
local TTAB   = MT.enter   -- tab arrival
local TPRESS = MT.snap
local TPOP   = MT.enter
local TTOGGLE   = MT.settle
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

