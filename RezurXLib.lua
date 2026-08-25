-- ============================================================
-- RezurXLib v5.5.1 "Magma" - self-contained Roblox UI library
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
                print(("[RezurXLib] v5.5.1 module loaded. LocalPlayer=%s PlayerGui=%s"):format(
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
        outer  = 16,  -- window shell (v5.5.0: Rayfield 20 × Maclib 10 cross)
        panel  = 12,  -- cards / popups
        control = 10, -- buttons / inputs
        small  = 8,   -- chips / icon tiles
        tab    = 10,  -- legacy tab chip radius (v5.5.0: live chips use PILL)
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

-- ============================================================
-- THEMES — full token sets. "Ember" is the original RezurXlab
-- palette. Each theme must define every token.
-- ============================================================
local Themes = {
        Ember = {
                bg        = Color3.fromRGB(8, 8, 13),
                panel     = Color3.fromRGB(20, 20, 30),
                panelAlt  = Color3.fromRGB(30, 30, 44),
                panelHov  = Color3.fromRGB(40, 40, 58),
                accent    = Color3.fromRGB(255, 122, 28),
                accentHi  = Color3.fromRGB(255, 155, 65),
                accentDim = Color3.fromRGB(185, 88, 20),
                accentDark= Color3.fromRGB(65, 32, 8),
                text      = Color3.fromRGB(232, 232, 248),
                textDim   = Color3.fromRGB(170, 170, 198),
                muted     = Color3.fromRGB(108, 108, 142),
                green     = Color3.fromRGB(48, 215, 92),
                greenDim  = Color3.fromRGB(22, 75, 38),
                yellow    = Color3.fromRGB(255, 210, 48),
                red       = Color3.fromRGB(225, 58, 58),
                border    = Color3.fromRGB(46, 46, 70),
                track     = Color3.fromRGB(38, 38, 58),
                white     = Color3.fromRGB(255, 255, 255),
                black     = Color3.fromRGB(0, 0, 0),
                tabBarBg  = Color3.fromRGB(14, 14, 21),
                tabChip   = Color3.fromRGB(36, 36, 52),
                tabChipHov= Color3.fromRGB(48, 48, 68),
                headerA   = Color3.fromRGB(26, 22, 36),
                headerB   = Color3.fromRGB(16, 16, 26),
                indGradA  = Color3.fromRGB(80, 40, 10),
                indGradB  = Color3.fromRGB(55, 26, 6),
        },
        Ocean = {
                bg        = Color3.fromRGB(7, 10, 15),
                panel     = Color3.fromRGB(17, 23, 32),
                panelAlt  = Color3.fromRGB(25, 33, 46),
                panelHov  = Color3.fromRGB(33, 44, 61),
                accent    = Color3.fromRGB(46, 170, 240),
                accentHi  = Color3.fromRGB(96, 200, 255),
                accentDim = Color3.fromRGB(28, 118, 176),
                accentDark= Color3.fromRGB(10, 38, 58),
                text      = Color3.fromRGB(230, 238, 248),
                textDim   = Color3.fromRGB(165, 180, 200),
                muted     = Color3.fromRGB(102, 118, 142),
                green     = Color3.fromRGB(48, 215, 92),
                greenDim  = Color3.fromRGB(22, 75, 38),
                yellow    = Color3.fromRGB(255, 210, 48),
                red       = Color3.fromRGB(225, 58, 58),
                border    = Color3.fromRGB(40, 52, 72),
                track     = Color3.fromRGB(32, 42, 58),
                white     = Color3.fromRGB(255, 255, 255),
                black     = Color3.fromRGB(0, 0, 0),
                tabBarBg  = Color3.fromRGB(12, 16, 22),
                tabChip   = Color3.fromRGB(30, 40, 55),
                tabChipHov= Color3.fromRGB(40, 53, 72),
                headerA   = Color3.fromRGB(20, 28, 40),
                headerB   = Color3.fromRGB(13, 18, 26),
                indGradA  = Color3.fromRGB(14, 52, 80),
                indGradB  = Color3.fromRGB(8, 34, 54),
        },
        Crimson = {
                bg        = Color3.fromRGB(12, 7, 9),
                panel     = Color3.fromRGB(28, 18, 21),
                panelAlt  = Color3.fromRGB(40, 26, 30),
                panelHov  = Color3.fromRGB(54, 34, 40),
                accent    = Color3.fromRGB(235, 64, 82),
                accentHi  = Color3.fromRGB(255, 110, 124),
                accentDim = Color3.fromRGB(165, 42, 56),
                accentDark= Color3.fromRGB(58, 14, 20),
                text      = Color3.fromRGB(246, 232, 234),
                textDim   = Color3.fromRGB(196, 168, 174),
                muted     = Color3.fromRGB(138, 104, 112),
                green     = Color3.fromRGB(48, 215, 92),
                greenDim  = Color3.fromRGB(22, 75, 38),
                yellow    = Color3.fromRGB(255, 210, 48),
                red       = Color3.fromRGB(255, 92, 92),
                border    = Color3.fromRGB(64, 42, 48),
                track     = Color3.fromRGB(52, 34, 40),
                white     = Color3.fromRGB(255, 255, 255),
                black     = Color3.fromRGB(0, 0, 0),
                tabBarBg  = Color3.fromRGB(18, 11, 13),
                tabChip   = Color3.fromRGB(46, 30, 34),
                tabChipHov= Color3.fromRGB(60, 40, 46),
                headerA   = Color3.fromRGB(38, 22, 28),
                headerB   = Color3.fromRGB(22, 13, 16),
                indGradA  = Color3.fromRGB(84, 22, 30),
                indGradB  = Color3.fromRGB(56, 14, 20),
        },
        Slate = {
                bg        = Color3.fromRGB(10, 11, 13),
                panel     = Color3.fromRGB(23, 25, 29),
                panelAlt  = Color3.fromRGB(33, 36, 42),
                panelHov  = Color3.fromRGB(44, 48, 56),
                accent    = Color3.fromRGB(148, 226, 132),
                accentHi  = Color3.fromRGB(184, 244, 172),
                accentDim = Color3.fromRGB(96, 158, 84),
                accentDark= Color3.fromRGB(30, 52, 26),
                text      = Color3.fromRGB(234, 238, 240),
                textDim   = Color3.fromRGB(172, 180, 190),
                muted     = Color3.fromRGB(110, 118, 130),
                green     = Color3.fromRGB(48, 215, 92),
                greenDim  = Color3.fromRGB(22, 75, 38),
                yellow    = Color3.fromRGB(255, 210, 48),
                red       = Color3.fromRGB(225, 58, 58),
                border    = Color3.fromRGB(50, 54, 64),
                track     = Color3.fromRGB(40, 44, 52),
                white     = Color3.fromRGB(255, 255, 255),
                black     = Color3.fromRGB(0, 0, 0),
                tabBarBg  = Color3.fromRGB(15, 16, 19),
                tabChip   = Color3.fromRGB(38, 42, 49),
                tabChipHov= Color3.fromRGB(50, 55, 64),
                headerA   = Color3.fromRGB(28, 32, 36),
                headerB   = Color3.fromRGB(17, 19, 22),
                indGradA  = Color3.fromRGB(40, 70, 34),
                indGradB  = Color3.fromRGB(26, 48, 22),
        },
        Midnight = {
                bg=Color3.fromRGB(6,6,12),panel=Color3.fromRGB(16,16,28),panelAlt=Color3.fromRGB(24,24,40),panelHov=Color3.fromRGB(34,34,54),
                accent=Color3.fromRGB(140,110,255),accentHi=Color3.fromRGB(175,150,255),accentDim=Color3.fromRGB(90,70,180),accentDark=Color3.fromRGB(40,30,80),
                text=Color3.fromRGB(228,228,248),textDim=Color3.fromRGB(165,165,200),muted=Color3.fromRGB(100,100,140),
                green=Color3.fromRGB(48,215,92),greenDim=Color3.fromRGB(22,75,38),yellow=Color3.fromRGB(255,210,48),red=Color3.fromRGB(225,58,58),
                border=Color3.fromRGB(40,40,64),track=Color3.fromRGB(32,32,52),white=Color3.fromRGB(255,255,255),black=Color3.fromRGB(0,0,0),
                tabBarBg=Color3.fromRGB(10,10,18),tabChip=Color3.fromRGB(28,28,46),tabChipHov=Color3.fromRGB(40,40,62),
                headerA=Color3.fromRGB(22,22,38),headerB=Color3.fromRGB(14,14,24),indGradA=Color3.fromRGB(50,36,100),indGradB=Color3.fromRGB(32,22,66),
        },
        Forest = {
                bg=Color3.fromRGB(8,14,10),panel=Color3.fromRGB(18,28,20),panelAlt=Color3.fromRGB(26,38,28),panelHov=Color3.fromRGB(34,50,36),
                accent=Color3.fromRGB(80,200,100),accentHi=Color3.fromRGB(120,230,140),accentDim=Color3.fromRGB(50,140,65),accentDark=Color3.fromRGB(22,60,30),
                text=Color3.fromRGB(228,240,230),textDim=Color3.fromRGB(165,185,170),muted=Color3.fromRGB(100,120,105),
                green=Color3.fromRGB(48,215,92),greenDim=Color3.fromRGB(22,75,38),yellow=Color3.fromRGB(255,210,48),red=Color3.fromRGB(225,58,58),
                border=Color3.fromRGB(36,50,40),track=Color3.fromRGB(28,40,32),white=Color3.fromRGB(255,255,255),black=Color3.fromRGB(0,0,0),
                tabBarBg=Color3.fromRGB(12,18,13),tabChip=Color3.fromRGB(26,38,28),tabChipHov=Color3.fromRGB(36,52,38),
                headerA=Color3.fromRGB(22,34,24),headerB=Color3.fromRGB(14,22,16),indGradA=Color3.fromRGB(30,80,38),indGradB=Color3.fromRGB(20,54,26),
        },
        Coral = {
                bg=Color3.fromRGB(14,8,10),panel=Color3.fromRGB(28,18,22),panelAlt=Color3.fromRGB(40,26,32),panelHov=Color3.fromRGB(54,34,42),
                accent=Color3.fromRGB(255,130,140),accentHi=Color3.fromRGB(255,165,175),accentDim=Color3.fromRGB(195,80,90),accentDark=Color3.fromRGB(80,30,36),
                text=Color3.fromRGB(248,232,234),textDim=Color3.fromRGB(200,168,174),muted=Color3.fromRGB(145,104,112),
                green=Color3.fromRGB(48,215,92),greenDim=Color3.fromRGB(22,75,38),yellow=Color3.fromRGB(255,210,48),red=Color3.fromRGB(225,58,58),
                border=Color3.fromRGB(66,42,48),track=Color3.fromRGB(54,34,40),white=Color3.fromRGB(255,255,255),black=Color3.fromRGB(0,0,0),
                tabBarBg=Color3.fromRGB(18,11,13),tabChip=Color3.fromRGB(46,30,34),tabChipHov=Color3.fromRGB(60,40,46),
                headerA=Color3.fromRGB(38,22,28),headerB=Color3.fromRGB(22,13,16),indGradA=Color3.fromRGB(100,30,40),indGradB=Color3.fromRGB(66,18,26),
        },
}

-- The default v3 palette trades decorative neon for quiet precision: deep
-- neutral surfaces, clear high-contrast copy, and one jade action color.
Themes.Quiet = {
        bg = Color3.fromRGB(10, 14, 16),
        panel = Color3.fromRGB(19, 26, 29),
        panelAlt = Color3.fromRGB(28, 37, 40),
        panelHov = Color3.fromRGB(39, 51, 53),
        accent = Color3.fromRGB(34, 166, 120),
        accentHi = Color3.fromRGB(133, 239, 189),
        accentDim = Color3.fromRGB(17, 112, 79),
        accentDark = Color3.fromRGB(13, 61, 45),
        text = Color3.fromRGB(242, 248, 247),
        textDim = Color3.fromRGB(194, 209, 204),
        muted = Color3.fromRGB(145, 166, 159),
        green = Color3.fromRGB(73, 207, 128),
        greenDim = Color3.fromRGB(21, 67, 42),
        yellow = Color3.fromRGB(240, 190, 76),
        red = Color3.fromRGB(228, 82, 90),
        border = Color3.fromRGB(48, 65, 65),
        track = Color3.fromRGB(42, 55, 57),
        white = Color3.fromRGB(255, 255, 255),
        black = Color3.fromRGB(0, 0, 0),
        tabBarBg = Color3.fromRGB(13, 19, 21),
        tabChip = Color3.fromRGB(22, 31, 34),
        tabChipHov = Color3.fromRGB(33, 45, 47),
        headerA = Color3.fromRGB(24, 34, 35),
        headerB = Color3.fromRGB(13, 20, 22),
        indGradA = Color3.fromRGB(16, 71, 54),
        indGradB = Color3.fromRGB(11, 48, 39),
}

local function cloneTheme(source)
        local result = {}
        for key, value in pairs(source) do result[key] = value end
        return result
end

Themes.HighContrast = cloneTheme(Themes.Quiet)
Themes.HighContrast.bg = Color3.fromRGB(0, 0, 0)
Themes.HighContrast.panel = Color3.fromRGB(12, 12, 12)
Themes.HighContrast.panelAlt = Color3.fromRGB(25, 25, 25)
Themes.HighContrast.panelHov = Color3.fromRGB(42, 42, 42)
Themes.HighContrast.accent = Color3.fromRGB(0, 150, 82)
Themes.HighContrast.accentHi = Color3.fromRGB(119, 255, 179)
Themes.HighContrast.accentDim = Color3.fromRGB(0, 106, 57)
Themes.HighContrast.accentDark = Color3.fromRGB(0, 58, 31)
Themes.HighContrast.text = Color3.fromRGB(255, 255, 255)
Themes.HighContrast.textDim = Color3.fromRGB(232, 232, 232)
Themes.HighContrast.muted = Color3.fromRGB(205, 205, 205)
Themes.HighContrast.border = Color3.fromRGB(213, 213, 213)
Themes.HighContrast.track = Color3.fromRGB(70, 70, 70)

Themes.Soft = cloneTheme(Themes.Quiet)
Themes.Soft.bg = Color3.fromRGB(20, 24, 22)
Themes.Soft.panel = Color3.fromRGB(29, 35, 31)
Themes.Soft.panelAlt = Color3.fromRGB(38, 46, 41)
Themes.Soft.panelHov = Color3.fromRGB(48, 58, 51)
Themes.Soft.accent = Color3.fromRGB(31, 126, 83)
Themes.Soft.accentHi = Color3.fromRGB(135, 222, 177)
Themes.Soft.accentDim = Color3.fromRGB(23, 94, 62)
Themes.Soft.accentDark = Color3.fromRGB(30, 64, 45)
Themes.Soft.textDim = Color3.fromRGB(202, 213, 205)
Themes.Soft.muted = Color3.fromRGB(168, 184, 174)
Themes.Soft.border = Color3.fromRGB(61, 72, 65)
Themes.Soft.track = Color3.fromRGB(56, 66, 60)

-- [v5.2.0] Color math helpers for deriving a full token family from one
-- primary (guarantees the accentHi/accentDim/accentDark contrast ladder).
local function lightenColor(c, t)
        return Color3.new(c.R + (1 - c.R) * t, c.G + (1 - c.G) * t, c.B + (1 - c.B) * t)
end
local function darkenColor(c, t)
        return Color3.new(c.R * (1 - t), c.G * (1 - t), c.B * (1 - t))
end
-- Build a complete RezurX palette from Primary/Secondary/Surface trio.
local function buildPreset(name, primary, secondary, surface, bestFor)
        local p = {
                bg        = surface,
                panel     = lightenColor(surface, 0.05),
                panelAlt  = lightenColor(surface, 0.10),
                panelHov  = lightenColor(surface, 0.16),
                accent    = primary,
                accentHi  = lightenColor(primary, 0.28),
                accentDim = darkenColor(primary, 0.30),
                accentDark= darkenColor(primary, 0.62),
                secondary = secondary,
                text      = Color3.fromRGB(240, 243, 248),
                textDim   = Color3.fromRGB(190, 196, 207),
                muted     = Color3.fromRGB(140, 147, 158),
                green     = Color3.fromRGB(0, 255, 136),
                greenDim  = Color3.fromRGB(0, 90, 48),
                yellow    = Color3.fromRGB(255, 187, 0),
                red       = Color3.fromRGB(255, 61, 61),
                border    = lightenColor(surface, 0.18),
                track     = lightenColor(surface, 0.12),
                white     = Color3.fromRGB(255, 255, 255),
                black     = Color3.fromRGB(0, 0, 0),
                tabBarBg  = darkenColor(surface, 0.35),
                tabChip   = lightenColor(surface, 0.08),
                tabChipHov= lightenColor(surface, 0.15),
                headerA   = lightenColor(surface, 0.06),
                headerB   = darkenColor(surface, 0.25),
                indGradA  = darkenColor(primary, 0.15),
                indGradB  = darkenColor(primary, 0.45),
        }
        if bestFor then p._bestFor = bestFor end
        return p
end

-- [v5.2.0] Universal preset matrix (Gemini spec table).
Themes.Lava = buildPreset("Lava",
        Color3.fromRGB(255, 69, 0), Color3.fromRGB(255, 170, 0), Color3.fromRGB(20, 15, 13),
        "Simulators, high-intensity hubs")
Themes.Cyberpunk = buildPreset("Cyberpunk",
        Color3.fromRGB(0, 240, 255), Color3.fromRGB(161, 0, 255), Color3.fromRGB(13, 14, 21),
        "Exploits, combat, admin tools")
Themes.Obsidian = buildPreset("Obsidian",
        Color3.fromRGB(58, 68, 84), Color3.fromRGB(160, 171, 186), Color3.fromRGB(8, 9, 12),
        "Minimalist & stealth scripts")
Themes.Emerald = buildPreset("Emerald",
        Color3.fromRGB(0, 255, 136), Color3.fromRGB(0, 179, 89), Color3.fromRGB(10, 18, 14),
        "Utility, ESP, engine trackers")

-- [v5.5.1 FIX — RUNTIME CRASH] Legacy themes predate the `secondary` token
-- (added with the v5.2.0 presets). A nil secondary crashed every
-- C.secondary gradient keypoint with "bad ColorSequence keypoint" inside
-- CreateWindow — on any legacy or secondary-less palette. Normalize the
-- SOURCE themes so GetTheme/RegisterTheme clones are always complete; the
-- CreateWindow and ModifyTheme guards remain as belt-and-braces for
-- hand-built palette tables passed directly as cfg.Theme.
for _, preset in pairs(Themes) do
        if typeof(preset.secondary) ~= "Color3" then
                preset.secondary = typeof(preset.accentHi) == "Color3" and preset.accentHi or preset.accent
        end
end

local ThemeTokenSet = {}
for token in pairs(Themes.Quiet) do ThemeTokenSet[token] = true end
ThemeTokenSet.secondary = true -- [v5.2.0] (redundant since v5.5.1: Quiet now owns it)

-- Active palette. Mutated in place by ApplyTheme so every
-- closure that captured `C` keeps reading fresh values.
local C = {}
for k, v in pairs(Themes.Quiet) do C[k] = v end
C.borderAcc = C.accent

-- ============================================================
-- JANITOR
-- ============================================================
local Janitor = {}
Janitor.__index = Janitor
function Janitor.new()
        return setmetatable({ _items = {}, _n = 0 }, Janitor)
end
function Janitor:Add(obj, method)
        self._n = self._n + 1
        self._items[self._n] = { obj = obj, method = method or "Disconnect" }
        return obj
end
function Janitor:Cleanup()
        for i = self._n, 1, -1 do
                local e = self._items[i]
                if e and e.obj then
                        pcall(function()
                                if type(e.obj) == "function" then
                                        e.obj()
                                elseif typeof(e.obj) == "Instance" then
                                        -- [FIX] Instances don't have Disconnect — calling e.obj["Disconnect"]
                                        -- on an Instance throws (Instances error on missing members, unlike
                                        -- tables which return nil). The pcall swallows the error silently,
                                        -- so Destroy never runs and the Instance leaks forever. Fall through
                                        -- to Destroy for any Instance.
                                        e.obj:Destroy()
                                elseif e.obj[e.method] then
                                        e.obj[e.method](e.obj)
                                elseif e.obj.Destroy then
                                        e.obj:Destroy()
                                end
                        end)
                end
                self._items[i] = nil
        end
        self._n = 0
end

-- ============================================================
-- CENTRALIZED TWEEN MANAGER — cancels any in-flight tween on
-- the same instance/property before starting a new one.
-- ============================================================
local _tweens = setmetatable({}, { __mode = "k" })

-- Per-window motion preferences are stored on the window's ScreenGui. This
-- keeps separate RezurX windows independent when one needs reduced motion.
local function motionScaleFor(inst)
        local cursor = inst
        while cursor and typeof(cursor) == "Instance" do
                if cursor:IsA("ScreenGui") then
                        if cursor:GetAttribute("RezurXReducedMotion") then return 0 end
                        local scale = cursor:GetAttribute("RezurXMotionScale")
                        if type(scale) == "number" then
                                return math.clamp(scale, 0.05, 3)
                        end
                        return 1
                end
                cursor = cursor.Parent
        end
        return 1
end

local function Tween(inst, info, props)
        if not inst or not inst.Parent then return nil end
        local motionScale = motionScaleFor(inst)
        if motionScale == 0 then
                for property, value in pairs(props) do
                        pcall(function() inst[property] = value end)
                end
                return nil
        end
        if motionScale ~= 1 then
                info = TweenInfo.new(
                        info.Time * motionScale,
                        info.EasingStyle,
                        info.EasingDirection,
                        info.RepeatCount,
                        info.Reverses,
                        info.DelayTime * motionScale
                )
        end
        if _tweens[inst] then
                for prop, tw in pairs(_tweens[inst]) do
                        if props[prop] ~= nil then
                                pcall(function() tw:Cancel() end)
                        end
                end
        else
                _tweens[inst] = {}
        end
        local tw = TweenService:Create(inst, info, props)
        for prop in pairs(props) do
                _tweens[inst][prop] = tw
        end
        tw.Completed:Connect(function()
                if _tweens[inst] then
                        for prop in pairs(props) do
                                if _tweens[inst][prop] == tw then
                                        _tweens[inst][prop] = nil
                                end
                        end
                end
        end)
        tw:Play()
        return tw
end

-- ============================================================
-- SPRING SOLVER (v5.0.0) — the motion engine core.
-- Stiffness/damping integration on RunService delta (NEVER wall-clock:
-- executor tick()/os.clock() can disagree with render time). Springs
-- are interruptible and velocity-preserving: retargeting mid-flight
-- continues from the current velocity instead of restarting — grab a
-- toggle mid-animation and it keeps its momentum.
--
-- Hard budget: at most MAX_SPRINGS concurrent. Overflow requests snap
-- straight to their end state, so an entrance cascade can never hitch
-- a 30 FPS host.
-- ============================================================
local MAX_SPRINGS = 12
local Spring = { active = {}, count = 0, _conn = nil }

local function springStep(dt)
        -- Clamp dt for stability (tab-out / hitch protection).
        if dt <= 0 then return end
        if dt > 1 / 20 then dt = 1 / 20 end
        local active = Spring.active
        for i = #active, 1, -1 do
                local h = active[i]
                -- Destroy-race guard: a spring never writes to a dead instance.
                if not h.alive or h.instance == nil or h.instance.Parent == nil then
                        table.remove(active, i)
                        Spring.count = #active
                else
                        local force = h.stiffness * (h.target - h.value) - h.damping * h.velocity
                        h.velocity = h.velocity + force * dt
                        h.value = h.value + h.velocity * dt
                        if math.abs(h.target - h.value) < 0.35 and math.abs(h.velocity) < 3 then
                                h.value = h.target
                                h.velocity = 0
                                table.remove(active, i)
                                Spring.count = #active
                                h.alive = false
                                pcall(h.apply, h.value, true)
                                if h.done then pcall(h.done) end
                        else
                                pcall(h.apply, h.value, false)
                        end
                end
        end
        if #active == 0 and Spring._conn then
                Spring._conn:Disconnect()
                Spring._conn = nil
        end
end

local function springEnsureHeartbeat()
        if not Spring._conn then
                Spring._conn = RunService.Heartbeat:Connect(function(dt)
                        springStep(dt)
                end)
        end
end

--- Create (or retarget) a spring on a single scalar.
--- Retargeting an existing handle preserves velocity — interruption is
--- the feature, not a bug: flick between tabs and the indicator keeps
--- gliding with its momentum.
--- @param handle table|nil existing handle to retarget
--- @param instance Instance instance written to (Parent-checked each step)
--- @param target number end value
--- @param opts table { stiffness=170, damping=22, apply=function(value, finished) }
--- @return table handle
local function springTo(handle, instance, target, opts)
        opts = opts or {}
        if handle and handle.alive and handle.instance == instance then
                handle.target = target
                return handle
        end
        local h = handle or {}
        h.instance = instance
        h.target = target
        h.stiffness = opts.stiffness or 170
        h.damping = opts.damping or 22
        h.apply = opts.apply
        h.done = opts.done
        h.velocity = (handle and handle.velocity) or 0
        h.value = (handle and handle.value ~= nil) and handle.value or (opts.from or target)
        h.alive = true
        -- Motion budget: over the cap, snap to the end state immediately.
        if Spring.count >= MAX_SPRINGS then
                h.value = target
                h.alive = false
                if h.apply then pcall(h.apply, target, true) end
                if h.done then pcall(h.done) end
                return h
        end
        if h.value ~= target then
                table.insert(Spring.active, h)
                Spring.count = #Spring.active
                springEnsureHeartbeat()
        else
                h.alive = false
                if h.apply then pcall(h.apply, target, true) end
                if h.done then pcall(h.done) end
        end
        return h
end

--- Snap a spring to its target immediately (viewport resizes, teardown).
local function springCancel(handle, snapToEnd)
        if not handle then return end
        if handle.alive then
                handle.alive = false
                for i, h in ipairs(Spring.active) do
                        if h == handle then table.remove(Spring.active, i) break end
                end
                Spring.count = #Spring.active
                if snapToEnd and handle.apply then
                        pcall(handle.apply, handle.target, true)
                end
        end
end

--- Kill every spring writing to a given instance (window teardown).
local function springsForgetInstance(instance)
        for i = #Spring.active, 1, -1 do
                local h = Spring.active[i]
                if h.instance == instance then
                        h.alive = false
                        table.remove(Spring.active, i)
                end
        end
        Spring.count = #Spring.active
end

-- Integer snap helper: every resting Offset that carries a UICorner is a
-- whole pixel (fractional offsets = half-pixel corners = "not perfectly
-- round" at any zoom).
local function snapPx(v)
        return math.floor(v + 0.5)
end

-- ============================================================
-- BASIC BUILDER HELPERS
-- ============================================================
local function corner(p, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = (type(r) == "number") and UDim.new(0, r) or (r or UDim.new(0, R.panel))
        c.Parent = p
        return c
end
local function stroke(p, col, thick)
        local s = Instance.new("UIStroke")
        s.Color = col or C.border
        s.Thickness = thick or 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = p
        return s
end
local function pad(p, t, b, l, r)
        local u = Instance.new("UIPadding")
        u.PaddingTop = UDim.new(0, t or 0)
        u.PaddingBottom = UDim.new(0, b or 0)
        u.PaddingLeft = UDim.new(0, l or 0)
        u.PaddingRight = UDim.new(0, r or 0)
        u.Parent = p
        return u
end
local function gradient(p, colorSeq, rot)
        local g = Instance.new("UIGradient")
        g.Color = colorSeq
        g.Rotation = rot or 0
        g.Parent = p
        return g
end

local function keyName(keyCode)
        if keyCode == nil then return "None" end
        local n = keyCode.Name
        return n
end

-- ============================================================
-- TRUST + GUI HOSTING
-- ============================================================
-- RezurX deliberately contains no remote loader, analytics, executor APIs,
-- filesystem APIs, or hidden GUI-parent bypass. Keeping these guarantees in
-- source makes a library audit quick for teams deciding whether to adopt it.
-- [v5.3.0] A single opt-in executor hook is now exposed: `gethui()`. When
-- present (executors only — never in plain Studio), the library will parent
-- its ScreenGui to that protected container so the host game's own UI cannot
-- reach, modify, or bury the window. Plain Roblox environments keep using
-- PlayerGui exactly as before. No other executor globals are touched.
local TrustManifest = {
        RemoteCode = false,
        Analytics = false,
        FileSystem = false,
        ExecutorBypass = "gethui only; off in plain Roblox.",
        DefaultHost = "Auto",
        CoreGuiOptIn = true,
        CoreGuiFallback = "PlayerGui",
        Configuration = "Memory only; developers own persistence.",
}

local function isGuiHost(instance)
        if typeof(instance) ~= "Instance" then return false end
        local ok, result = pcall(function()
                return instance:IsA("LayerCollector")
        end)
        return ok and result
end

local function resolvePlayerGui()
        if playerGui and playerGui.Parent then return playerGui end
        if not player then return nil end
        local found = nil
        pcall(function()
                found = player:FindFirstChildOfClass("PlayerGui")
                        or player:WaitForChild("PlayerGui", 5)
        end)
        if found and isGuiHost(found) then playerGui = found end
        return playerGui
end

-- [v5.3.0] Probe for the executor-protected GUI container (gethui). Returns
-- the container Instance if usable, otherwise nil. The probe is pcall-wrapped
-- so a non-executor environment (Studio, plain game client) never throws.
-- Not cached: gethui() is cheap, an executor's protected container is stable,
-- and uncached lets test harnesses inject a fake gethui between windows.
local function resolveGethui()
        local ok, host = pcall(function()
                local g = gethui
                if type(g) ~= "function" then return nil end
                return g()
        end)
        if ok and host and isGuiHost(host) then
                return host
        end
        return nil
end

local function resolveGuiHost(cfg)
        cfg = cfg or {}
        local preferred = cfg.Host or "Auto"
        local info = {
                Requested = preferred,
                Resolved = nil,
                UsedFallback = false,
                AllowCoreGui = cfg.AllowCoreGui == true,
                UsedExecutorHost = false,
        }

        -- A supplied parent wins only when it is a standard Roblox GUI host.
        -- This prevents a confusing invisible UI from an accidental Frame or
        -- Folder parent while still supporting advanced developer containers.
        if cfg.Parent ~= nil then
                if isGuiHost(cfg.Parent) then
                        info.Resolved = "Custom"
                        return cfg.Parent, info
                end
                warn("[RezurXLib] Parent must be a LayerCollector; using Auto instead.")
        end

        -- [v5.3.0] "Auto" (new default): try gethui() -> CoreGui (with opt-in)
        -- -> PlayerGui. This puts the window in a container the host game's
        -- UI cannot bury, eliminating the "UI never shows up" regression
        -- where the game's own ScreenGuis at DisplayOrder > 0 hid our window.
        if preferred == "Auto" or preferred == "gethui" then
                local hui = resolveGethui()
                if hui then
                        info.Resolved = "gethui"
                        info.UsedExecutorHost = true
                        return hui, info
                end
                if preferred == "gethui" then
                        warn("[RezurXLib] gethui() is not available in this environment; falling back to PlayerGui.")
                        info.UsedFallback = true
                end
                -- Auto silently falls through to PlayerGui (executor detection
                -- is best-effort; never warn in plain Studio / plain game runs).
        elseif preferred == "CoreGui" then
                if cfg.AllowCoreGui ~= true and not resolveGethui() then
                        warn("[RezurXLib] CoreGui needs AllowCoreGui = true; using PlayerGui.")
                        info.UsedFallback = true
                elseif isGuiHost(CoreGui) then
                        info.Resolved = "CoreGui"
                        return CoreGui, info
                else
                        warn("[RezurXLib] CoreGui is unavailable here; using PlayerGui.")
                        info.UsedFallback = true
                end
        elseif preferred ~= "PlayerGui" then
                warn("[RezurXLib] Unknown Host '" .. tostring(preferred) .. "'; using PlayerGui.")
                info.UsedFallback = true
        end

        local fallback = resolvePlayerGui()
        if fallback then
                info.Resolved = info.Resolved or "PlayerGui"
                return fallback, info
        end
        return nil, info
end

local function readDimension(size, axis, fallback)
        if typeof(size) == "Vector2" then return math.floor(size[axis] + 0.5) end
        if typeof(size) == "UDim2" then return math.floor(size[axis].Offset + 0.5) end
        if type(size) == "table" then
                -- [v5.5.0 FIX] The documented API shape is Size = { 560, 580 } —
                -- an ARRAY table — but only the .X/.Y KEY form was read, so every
                -- array-form Size silently fell back to the 460×500 default
                -- (Rayfield accepts every shape; so do we now).
                if type(size[axis]) == "number" then return math.floor(size[axis] + 0.5) end
                local idx = axis == "X" and 1 or 2
                if type(size[idx]) == "number" then return math.floor(size[idx] + 0.5) end
        end
        return fallback
end

local function normalizeSize(size, defaultX, defaultY, minX, minY, maxX, maxY)
        local x = readDimension(size, "X", defaultX)
        local y = readDimension(size, "Y", defaultY)
        return math.clamp(x, minX, maxX), math.clamp(y, minY, maxY)
end

-- ============================================================
-- LIBRARY ROOT
-- ============================================================
-- ============================================================
-- TOOLTIP SYSTEM — hover-activated info labels
-- ============================================================
local tooltipFrame = nil
local tooltipText = nil
local tooltipStroke = nil
local tooltipHost = nil

local function initTooltip(host, palette)
        host = host or resolvePlayerGui()
        if not host then return false end
        if tooltipFrame and tooltipHost == host then return true end
        if tooltipFrame then
                tooltipFrame:Destroy()
                tooltipFrame, tooltipText, tooltipStroke, tooltipHost = nil, nil, nil, nil
        end
        tooltipFrame = Instance.new("Frame")
        tooltipFrame.Name = "Tooltip"
        tooltipFrame.Size = UDim2.new(0, 0, 0, 24)
        tooltipFrame.BackgroundColor3 = (palette or C).panelAlt
        tooltipFrame.BackgroundTransparency = 0.05
        tooltipFrame.BorderSizePixel = 0
        tooltipFrame.ZIndex = 200
        tooltipFrame.Visible = false
        tooltipFrame.Parent = host
        tooltipHost = host
        corner(tooltipFrame, R.small)
        tooltipStroke = stroke(tooltipFrame, (palette or C).border, 1)
        tooltipText = Instance.new("TextLabel")
        tooltipText.Name = "Text"
        tooltipText.Size = UDim2.new(1, -12, 1, 0)
        tooltipText.Position = UDim2.new(0, 6, 0, 0)
        tooltipText.BackgroundTransparency = 1
        tooltipText.Font = Enum.Font.GothamMedium
        tooltipText.TextSize = 11
        tooltipText.TextColor3 = (palette or C).textDim
        tooltipText.ZIndex = 201
        tooltipText.Parent = tooltipFrame
        return true
end

local function showTooltip(text, anchorGui, host, palette)
        if not text or text == "" then return end
        if not initTooltip(host, palette) then return end
        -- [FIX v4.0] A destroyed owner (window or overlayGui removed) can leave
        -- initTooltip true while the frame is parented nowhere; writing into a
        -- detached frame renders nothing but also errors on some renderers.
        if not tooltipFrame.Parent then return end
        local activePalette = palette or C
        tooltipText.Text = text
        tooltipFrame.Visible = true
        tooltipFrame.BackgroundColor3 = activePalette.panelAlt
        tooltipStroke.Color = activePalette.border
        tooltipText.TextColor3 = activePalette.textDim
        local txtSize = TextService:GetTextSize(text, 11, Enum.Font.GothamMedium, Vector2.new(400, 24))
        tooltipFrame.Size = UDim2.new(0, txtSize.X + 14, 0, 26)
        if anchorGui and anchorGui.AbsolutePosition then
                local pos = anchorGui.AbsolutePosition
                local size = anchorGui.AbsoluteSize
                local tipW = txtSize.X + 14
                local tipH = 26
                local x = pos.X
                local y = pos.Y + size.Y + 4
                -- [FIX v4.0] Viewport clamping: tooltips anchored near the right
                -- or bottom edge (most elements on a phone) used to render
                -- fully off-screen. Flip above the anchor and clamp horizontally.
                local cam = workspace.CurrentCamera
                local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
                if x + tipW > vp.X - 8 then x = math.max(8, vp.X - 8 - tipW) end
                if y + tipH > vp.Y - 8 then
                        y = pos.Y - tipH - 4
                        if y < 8 then y = math.max(8, vp.Y - 8 - tipH) end
                end
                tooltipFrame.Position = UDim2.new(0, x, 0, y)
        end
end

local function hideTooltip()
        if tooltipFrame then tooltipFrame.Visible = false end
end

-- ============================================================
-- [v4.0] OPTIONAL EXECUTOR FILESYSTEM — used ONLY when a developer
-- explicitly enables ConfigurationSaving or the KeySystem. The library
-- performs zero automatic file or network operations. Every call is
-- pcall-guarded so non-executor environments (Studio, regular games)
-- degrade gracefully to in-memory behavior.
-- ============================================================
local FS = {}
do
        local function callSafely(fn, ...)
                if type(fn) ~= "function" then return false, nil end
                local ok, result = pcall(fn, ...)
                if ok then return true, result end
                return false, nil
        end
        FS.available = type(writefile) == "function"
                and type(readfile) == "function"
                and type(isfile) == "function"
        function FS.ensureFolder(path)
                if type(isfolder) == "function" then
                        local ok, exists = callSafely(isfolder, path)
                        if ok and exists == true then return end
                end
                if type(makefolder) == "function" then
                        callSafely(makefolder, path)
                end
        end
        function FS.write(path, content)
                local ok = callSafely(writefile, path, content)
                return ok
        end
        function FS.read(path)
                return callSafely(readfile, path)
        end
        function FS.exists(path)
                -- [v5.4.0 FIX] The old body was `return callSafely(isfile, path) == true`,
                -- which compared only callSafely's FIRST return (the ok flag) —
                -- making FS.exists ALWAYS true. Every caller masked the bug
                -- (failed reads handled the miss) until the corrupt-backup
                -- loop turned it into a hard hang. Compare the actual result.
                local ok, result = callSafely(isfile, path)
                return ok and result == true
        end
        -- [v5.4.0] ATOMIC WRITE (Rayfield Gen2 parked-copy pattern): executors
        -- give us no rename(), so the next-best guarantee is: write the whole
        -- payload to a temp file beside the real one, read it back and verify
        -- byte-equality, then overwrite the real file. If the executor dies
        -- mid-overwrite, the parked .saving copy is still intact for the next
        -- load to recover from. A short read-back means the disk is full or
        -- ejected — we stop right there rather than shred the real file.
        function FS.writeAtomic(path, content)
                if type(content) ~= "string" then return false end
                local tempPath = path .. ".saving"
                if not FS.write(tempPath, content) then return false end
                local okBack, readBack = FS.read(tempPath)
                if not okBack or readBack ~= content then
                        -- Parked copy did not write cleanly (disk full?). Do NOT
                        -- touch the real file — the previous config stays intact.
                        if type(delfile) == "function" then pcall(delfile, tempPath) end
                        return false
                end
                if not FS.write(path, content) then return false end
                if type(delfile) == "function" then pcall(delfile, tempPath) end
                return true
        end
        -- [v5.4.0] CORRUPT FILE RECOVERY: when a config file fails to decode,
        -- preserve the user's broken file as "<name> (Incorrect Format)<ext>"
        -- (unique-numbered so a second corruption can't destroy the first
        -- backup) and remove the original so the next save starts clean.
        -- Returns the backup path on success.
        function FS.backupCorrupt(path)
                local dir, base = path:match("^(.*)/([^/]+)$")
                if not dir then dir, base = "", path end
                local stem, ext = base:match("^(.+)(%.[^%.]+)$")
                if not stem then stem, ext = base, "" end
                local backup = dir .. "/" .. stem .. " (Incorrect Format)" .. ext
                local n = 2
                while FS.exists(backup) do
                        backup = dir .. "/" .. stem .. " (Incorrect Format " .. n .. ")" .. ext
                        n = n + 1
                end
                local okCopy = FS.write(backup, "")
                if okCopy then
                        local okRead, raw = FS.read(path)
                        if okRead and type(raw) == "string" then FS.write(backup, raw) end
                        if type(delfile) == "function" then
                                pcall(delfile, path)
                        else
                                -- No delfile (some executors / Studio sim): neutralize
                                -- the file with valid empty JSON so the next load
                                -- decodes it cleanly instead of re-entering recovery.
                                FS.write(path, "{}")
                        end
                        return backup
                end
                return nil
        end
end

local Library = {}
Library.Flags = {}          -- flag -> element object (has CurrentValue / CurrentOption / etc.)
Library.Version = "5.5.1"
Library._windows = {}
Library.Options = { ReducedMotion = false }

-- ============================================================
-- [v5.4.0] SAFECALLBACK — the unified consumer-callback funnel.
-- Every one of the five reference libraries (Rayfield Gen2, Fluent,
-- WindUI, Maclib, Luna) converges on this exact pattern, and it is
-- the single biggest "functionally perfect" differentiator:
--   1. task.spawn isolation — a yielding or expensive consumer
--      callback can never block the input event or the UI thread.
--   2. pcall containment — a throwing callback can never kill the
--      event connection that fired it.
--   3. Visual surfacing — the element that owns the callback flashes
--      error-red and swaps its title to "Callback Error" for 1s so
--      the user sees exactly WHICH control misbehaved (Luna/Rayfield
--      pattern), instead of silently swallowing the failure.
--   4. Per-element debounce — a slider firing every drag frame or a
--      color picker firing every mouse-move flashes exactly once.
--   5. Console trace with the library prefix and element name.
-- surf: optional error surface table
--   { frame = row Frame, label = title TextLabel, name = "Slider 'Speed'",
--     baseBg = resting Color3, baseText = resting text color }
-- ============================================================
function Library.SafeCallback(surf, callback, ...)
        if type(callback) ~= "function" then return end
        local args = table.pack(...)
        task.spawn(function()
                local ok, err = pcall(callback, table.unpack(args, 1, args.n))
                if ok then return end
                local label = (surf and surf.name) or "<unknown element>"
                warn("[RezurXLib] " .. label .. " callback error: " .. tostring(err))
                local frame = surf and surf.frame
                local lbl = surf and surf.label
                if frame and lbl and not surf._rxErrored then
                        surf._rxErrored = true
                        local origText = lbl.Text
                        local baseBg = surf.baseBg or frame.BackgroundColor3
                        local baseText = surf.baseText or lbl.TextColor3
                        pcall(function()
                                Tween(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint,
                                        Enum.EasingDirection.Out),
                                        { BackgroundColor3 = Color3.fromRGB(85, 0, 0) })
                                lbl.Text = "Callback Error"
                                Tween(lbl, TweenInfo.new(0.25, Enum.EasingStyle.Quint,
                                        Enum.EasingDirection.Out),
                                        { TextColor3 = Color3.fromRGB(255, 120, 120) })
                        end)
                        task.delay(1, function()
                                surf._rxErrored = false
                                pcall(function()
                                        Tween(frame, TweenInfo.new(0.45, Enum.EasingStyle.Quint,
                                                Enum.EasingDirection.Out),
                                                { BackgroundColor3 = baseBg })
                                        if lbl.Text == "Callback Error" then lbl.Text = origText end
                                        Tween(lbl, TweenInfo.new(0.45, Enum.EasingStyle.Quint,
                                                Enum.EasingDirection.Out),
                                                { TextColor3 = baseText })
                                end)
                        end)
                end
        end)
end

-- ============================================================
-- CreateWindow
-- ============================================================
function Library:CreateWindow(cfg)
        cfg = cfg or {}
        -- [v5.3.1] DIAGNOSTIC ENTRY BANNER. The most common consumer-side
        -- failure is "nothing shows up": previously the library silently
        -- swallowed errors inside the long CreateWindow body, so the user
        -- could not tell whether the call was reached, the host detection
        -- failed, or an internal instance step threw. We now print a
        -- one-line banner at the very top so the executor's output panel
        -- shows the call landed; if the window then fails to appear, the
        -- search space narrows to host detection or render path. Gated
        -- behind pcall + RunService:IsStudio() off so Studio runs stay
        -- quiet (the headless suite injects a fake RunService that IS
        -- Studio, so the suite output stays clean).
        pcall(function()
                if RunService and not RunService:IsStudio() then
                        print(("[RezurXLib] CreateWindow called: name=%q theme=%s host=%s size=%s"):format(
                                tostring(cfg.Name or cfg.Title or "RezurX UI"),
                                tostring(cfg.Theme or "Quiet"),
                                tostring(cfg.Host or "Auto"),
                                tostring(cfg.Size or "460x500 default")
                        ))
                end
        end)
        -- [v5.2.0] Universal aliases: Title/SubTitle map onto Name/Subtitle so
        -- scripts written against other libraries drop in unchanged.
        local windowName   = cfg.Name or cfg.Title or "RezurX UI"
        local subtitle     = cfg.Subtitle or cfg.SubTitle or "Control center"
        local loadingTitle = cfg.LoadingTitle or windowName
        local loadingOn    = cfg.LoadingEnabled ~= false
        local toggleKey    = cfg.ToggleUIKeybind or Enum.KeyCode.K

        -- Compact shell labels intentionally accept emoji, symbols, and text.
        -- Four Unicode codepoints keeps them readable in the 28px badge while
        -- avoiding an accidental full title inside an icon-sized control.
        local function limitBadgeText(value, fallback)
                local text = tostring(value == nil and fallback or value)
                if text == "" then text = tostring(fallback or "R") end
                local ok, count = pcall(function() return utf8.len(text) end)
                if not ok or type(count) ~= "number" then count = #text end
                if count > 4 then
                        local cut = nil
                        pcall(function() cut = utf8.offset(text, 5) end)
                        text = cut and string.sub(text, 1, cut - 1) or string.sub(text, 1, 4)
                end
                return text
        end
        local function badgeCharacterCount(text)
                local ok, count = pcall(function() return utf8.len(text) end)
                return ok and type(count) == "number" and count or #text
        end
        -- Four characters are readable only when their typography tightens
        -- progressively. Keeping this in one helper makes the header badge
        -- and its floating restore counterpart visually consistent.
        local function badgeTextSize(text, floating)
                local count = badgeCharacterCount(text)
                if count <= 1 then return floating and 18 or 16 end
                if count == 2 then return floating and 16 or 14 end
                if count == 3 then return floating and 14 or 12 end
                return floating and 12 or 10
        end
        local brandText = limitBadgeText(cfg.BrandText or cfg.BrandIcon, "R")
        local restoreText = limitBadgeText(
                cfg.RestoreText or cfg.RestoreIcon or cfg.ClosedButtonText,
                brandText
        )

        -- Each window receives a private palette. Older versions mutated the
        -- module palette directly, so changing one window's theme could leave
        -- another window partially recolored. This isolates theme updates.
        local C = {}
        for key, value in pairs(Themes.Quiet) do C[key] = value end
        local initialTheme = (type(cfg.Theme) == "table") and cfg.Theme or Themes[cfg.Theme]
        -- [FIX v4.0] An unknown string theme used to keep the Quiet palette but
        -- record the bogus name, so GetThemeName() lied and the settings-panel
        -- theme dropdown showed a phantom selection. Unknown names now warn and
        -- fall back to the palette actually in use.
        local activeThemeName = "Quiet"
        if type(cfg.Theme) == "string" then
                if Themes[cfg.Theme] then
                        activeThemeName = cfg.Theme
                elseif cfg.Theme ~= "" then
                        warn("[RezurXLib] Unknown theme '" .. cfg.Theme .. "' — using 'Quiet'. Valid: " .. table.concat(Library:GetThemeNames(), ", "))
                end
        end
        if initialTheme then
                for key, value in pairs(initialTheme) do
                        if ThemeTokenSet[key] and typeof(value) == "Color3" then C[key] = value end
                end
        end
        -- [v5.2.0] CUSTOM THEME OVERRIDES — friendly names mapped onto the
        -- token system, applied AFTER the preset so both can combine:
        --   CustomTheme = { PrimaryAccent = …, SecondaryAccent = …,
        --                   CardBackground = …, WindowBackground = …, TextMain = … }
        -- Raw token names (accent, panel, bg, …) are also accepted directly.
        if type(cfg.CustomTheme) == "table" then
                local ct = cfg.CustomTheme
                local function setTok(tok, v)
                        if typeof(v) == "Color3" then C[tok] = v end
                end
                if typeof(ct.PrimaryAccent) == "Color3" then
                        local prim = ct.PrimaryAccent
                        setTok("accent", prim)
                        if typeof(ct.SecondaryAccent) == "Color3" then setTok("secondary", ct.SecondaryAccent) end
                        -- Derive the contrast ladder unless explicitly provided.
                        if not (typeof(ct.accentHi) == "Color3" or typeof(ct.BrightAccent) == "Color3") then
                                C.accentHi = lightenColor(prim, 0.28)
                        end
                        if not (typeof(ct.accentDim) == "Color3" or typeof(ct.DimAccent) == "Color3") then
                                C.accentDim = darkenColor(prim, 0.30)
                        end
                        if typeof(ct.accentDark) ~= "Color3" then
                                C.accentDark = darkenColor(prim, 0.62)
                        end
                end
                setTok("secondary", ct.SecondaryAccent)
                if typeof(ct.CardBackground) == "Color3" then
                        local card = ct.CardBackground
                        setTok("panel", card)
                        if typeof(ct.panelAlt) ~= "Color3" then C.panelAlt = lightenColor(card, 0.06) end
                        if typeof(ct.panelHov) ~= "Color3" then C.panelHov = lightenColor(card, 0.13) end
                end
                if typeof(ct.WindowBackground) == "Color3" then
                        local base = ct.WindowBackground
                        setTok("bg", base)
                        if typeof(ct.headerA) ~= "Color3" then C.headerA = lightenColor(base, 0.06) end
                        if typeof(ct.headerB) ~= "Color3" then C.headerB = darkenColor(base, 0.25) end
                        if typeof(ct.tabBarBg) ~= "Color3" then C.tabBarBg = darkenColor(base, 0.35) end
                end
                if typeof(ct.TextMain) == "Color3" then
                        local txt = ct.TextMain
                        setTok("text", txt)
                        if typeof(ct.textDim) ~= "Color3" then C.textDim = darkenColor(txt, 0.22) end
                        if typeof(ct.muted) ~= "Color3" then C.muted = darkenColor(txt, 0.42) end
                end
                -- Power users: raw token passthrough.
                for key, value in pairs(ct) do
                        if ThemeTokenSet[key] and typeof(value) == "Color3" then C[key] = value end
                end
        end
        -- [v5.5.1 FIX — RUNTIME CRASH] Legacy themes (Quiet/Ember/Ocean/Crimson)
        -- predate the `secondary` token; custom palettes may omit it too. A
        -- nil secondary made every C.secondary gradient keypoint throw
        -- "bad ColorSequence keypoint" inside CreateWindow (the TopEdge
        -- gradient since v5.2.0; the Magma edge-bar + divider since v5.5.0).
        -- Normalized here so the token is ALWAYS a Color3: presets keep their
        -- explicit secondary; everything else inherits the accent's bright
        -- ladder step — visually harmonious on every legacy palette.
        if typeof(C.secondary) ~= "Color3" then
                C.secondary = C.accentHi
        end
        C.borderAcc = C.accent

        local MIN_W = math.max(280, readDimension(cfg.MinSize, "X", 300))
        local MIN_H = math.max(260, readDimension(cfg.MinSize, "Y", 360))
        local MAX_W = math.max(MIN_W, readDimension(cfg.MaxSize, "X", 900))
        local MAX_H = math.max(MIN_H, readDimension(cfg.MaxSize, "Y", 900))
        local WIN_W, WIN_H = normalizeSize(cfg.Size, 460, 500, MIN_W, MIN_H, MAX_W, MAX_H)
        local resizable = cfg.Resizable ~= false
        local accessibility = type(cfg.Accessibility) == "table" and cfg.Accessibility or {}
        local reducedMotion = cfg.ReducedMotion == true or accessibility.ReducedMotion == true or Library.Options.ReducedMotion == true
        -- [v5.0.0] AnimatedAccents is a deprecated no-op: every ambient loop
        -- (logo pulse, shimmer, tick pulse) was removed to give Aurora Trace
        -- one clear voice. Accepted for backward compatibility; does nothing.
        local animatedAccents = false
        local motionScale = math.clamp(tonumber(cfg.MotionScale) or 1, 0.05, 3)
        local guiHost, hostInfo = resolveGuiHost(cfg)
        if not guiHost then
                error("[RezurXLib] Unable to find a supported GUI host (PlayerGui or approved CoreGui).", 2)
        end

        -- ------------------------------------------------------------
        -- [v4.0] KEY GATE PRE-CHECK — resolved BEFORE any visuals exist so
        -- the entrance animation can be deferred until the gate is passed.
        -- Pure logic + explicitly-opted-in file/HTTP reads; nothing runs
        -- unless the developer sets KeySystem = true.
        -- ------------------------------------------------------------
        local keyGatePending = false
        local keyGateKeys = nil
        local keySettingsRef = nil
        do
                if cfg.KeySystem == true then
                        local ks = type(cfg.KeySettings) == "table" and cfg.KeySettings or {}
                        local keys = {}
                        if type(ks.Key) == "string" and ks.Key ~= "" then
                                keys = { ks.Key }
                        elseif type(ks.Key) == "table" then
                                for _, k in ipairs(ks.Key) do
                                        if type(k) == "string" and k ~= "" then table.insert(keys, k) end
                                end
                        end
                        -- GrabKeyFromSite: fetch RAW key pages over HTTP (executor
                        -- HttpGet). Explicit opt-in — the library itself never
                        -- performs network operations otherwise.
                        if ks.GrabKeyFromSite == true then
                                for i, k in ipairs(keys) do
                                        if string.sub(k, 1, 8) == "https://" or string.sub(k, 1, 7) == "http://" then
                                                local ok, body = pcall(function() return game:HttpGet(k) end)
                                                if ok and type(body) == "string" and body ~= "" then
                                                        keys[i] = string.gsub(body, "[%c%s]", "")
                                                else
                                                        warn("[RezurXLib] KeySystem: GrabKeyFromSite failed for '" .. tostring(k) .. "'")
                                                end
                                        end
                                end
                        end
                        if #keys == 0 then
                                warn("[RezurXLib] KeySystem enabled but KeySettings.Key is empty — gate disabled")
                        else
                                keyGateKeys = keys
                                keySettingsRef = ks
                                local keyFile = "RezurXLib/Keys/" .. tostring(ks.FileName or "Key") .. ".rezx"
                                local passed = false
                                if ks.SaveKey ~= false and FS.available and FS.exists(keyFile) then
                                        local ok, saved = FS.read(keyFile)
                                        if ok and type(saved) == "string" then
                                                for _, k in ipairs(keys) do
                                                        if saved == k then passed = true break end
                                                end
                                        end
                                end
                                keyGatePending = not passed
                        end
                end
        end

        -- ------------------------------------------------------------
        -- IDEMPOTENT GUARD — keyed to THIS window's name, so re-running
        -- a script that creates "Admin Panel" replaces the old "Admin
        -- Panel" instead of stacking a duplicate, without touching any
        -- other windows the library may be running.
        -- ------------------------------------------------------------
        local panelId = tostring(cfg.Id or windowName):gsub("%W", "")
        if panelId == "" then panelId = "Panel" end
        local PANEL_NAME = "RezurX_" .. panelId
        if cfg.ReplaceExisting ~= false then
                -- [FIX v4.0] Destroying only the previous ScreenGui instance left the
                -- old Window's UserInputService connections alive: keybinds fired
                -- twice, the FPS heartbeat kept writing to a dead label, and a
                -- mid-flight drag session kept erroring against destroyed widgets
                -- (the classic "ghost callback / stuck drag" report). Destroy the
                -- Window OBJECT itself so its Janitor runs and it deregisters.
                for i = #Library._windows, 1, -1 do
                        local w = Library._windows[i]
                        local okGui, wGui = pcall(function()
                                return type(w.GetGui) == "function" and w:GetGui()
                        end)
                        if okGui and wGui and wGui.Name == PANEL_NAME then
                                pcall(function() w:Destroy() end)
                        end
                end
                -- Belt and braces: remove any leftover instance (e.g. from a
                -- crashed prior run that never registered a Window object).
                local ok, existing = pcall(function() return guiHost:FindFirstChild(PANEL_NAME) end)
                if ok and existing then existing:Destroy() end
        end

        local Window = {}
        Window.Name = windowName
        Window.Host = hostInfo
        -- [v4.0] Per-window flag registry: keeps each window's auto-saved
        -- configuration isolated even when several windows coexist.
        Window.Flags = {}
        local WindowJanitor = Janitor.new()

        -- Theme refreshers: each stateful element registers a closure
        -- that re-applies its colors from `C` for its current state.
        -- Gradients can't be tweened, so they're updated directly.
        -- [FIX v4.0] onTheme now returns an unregister handle so elements
        -- can prune their refresher on Destroy. Without pruning, every
        -- destroyed element kept its whole GUI subtree referenced and its
        -- refresher kept re-rendering dead widgets on each theme change.
        local ThemeRefreshers = {}
        local function onTheme(fn)
                table.insert(ThemeRefreshers, fn)
                local removed = false
                return fn, function()
                        if removed then return end
                        removed = true
                        for i = #ThemeRefreshers, 1, -1 do
                                if ThemeRefreshers[i] == fn then
                                        table.remove(ThemeRefreshers, i)
                                        break
                                end
                        end
                end
        end

        -- ------------------------------------------------------------
        -- [FIX v4.0] `minimized` is declared here, BEFORE the resize handler
        -- further down. It used to be declared 200+ lines later, so the
        -- resize closure read it as a GLOBAL (always nil under non-strict
        -- Luau) — a resize started before minimizing fought the minimize
        -- tween, and any stray global named `minimized` could hijack resize.
        -- ------------------------------------------------------------
        local minimized = false

        -- ------------------------------------------------------------
        -- SHARED DRAG ROUTER — one global InputChanged/InputEnded pair
        -- dispatching to whichever control is mid-drag.
        -- ------------------------------------------------------------
        -- A window owns exactly one pointer interaction at a time. This avoids
        -- the old broadcast behavior, where one interrupted touch could drive
        -- a window, slider, and color picker simultaneously.
        local activeDrag = nil
        local function finishDrag(reason)
                local session = activeDrag
                activeDrag = nil
                if session and session.onEnd then pcall(session.onEnd, reason) end
        end
        local function registerDrag(owner, sourceInput, moveFn, onEndFn)
                if not sourceInput then return end
                finishDrag("replaced")
                activeDrag = {
                        owner = owner,
                        input = sourceInput,
                        inputType = sourceInput.UserInputType,
                        move = moveFn,
                        onEnd = onEndFn,
                        born = os.clock(),
                }
        end
        WindowJanitor:Add(UserInputService.InputChanged:Connect(function(input)
                local session = activeDrag
                if not session then return end
                local mouseMove = session.inputType == Enum.UserInputType.MouseButton1
                        and input.UserInputType == Enum.UserInputType.MouseMovement
                local touchMove = session.inputType == Enum.UserInputType.Touch and input == session.input
                if mouseMove or touchMove then
                        local ok, err = pcall(session.move, input.Position)
                        if not ok then
                                warn("[RezurX UI] Drag '" .. tostring(session.owner) .. "' failed: " .. tostring(err))
                                finishDrag("error")
                        end
                end
        end))
        WindowJanitor:Add(UserInputService.InputEnded:Connect(function(input)
                local session = activeDrag
                if not session then return end
                local mouseEnd = session.inputType == Enum.UserInputType.MouseButton1
                        and input.UserInputType == Enum.UserInputType.MouseButton1
                local touchEnd = session.inputType == Enum.UserInputType.Touch and input == session.input
                if mouseEnd or touchEnd then finishDrag("released") end
        end))
        -- A destroyed window must release its active pointer session too;
        -- otherwise a slider/resize end-state can be stranded mid-animation.
        WindowJanitor:Add(function() finishDrag("destroyed") end)
        -- [FIX v4.0] Some touch releases are swallowed by the OS (gesture nav,
        -- notification shade, incoming-call overlay) and never raise
        -- InputEnded. TouchEnded is the authoritative companion there.
        WindowJanitor:Add(UserInputService.TouchEnded:Connect(function(input)
                local session = activeDrag
                if session and session.inputType == Enum.UserInputType.Touch and input == session.input then
                        finishDrag("touch-ended")
                end
        end))
        -- [FIX v4.0] Watchdog: a mouse released outside the Roblox window can
        -- also skip InputEnded. Retire any session older than 30s defensively.
        local dragWatchdogConnection = RunService.Heartbeat:Connect(function()
                local session = activeDrag
                if session and os.clock() - session.born > 30 then
                        finishDrag("watchdog")
                end
        end)
        WindowJanitor:Add(function() dragWatchdogConnection:Disconnect() end)

        -- [FIX v4.0] Forward-declared so helpers defined above this point
        -- (ripple, dropdown portal math) capture the REAL local
        -- instead of reading a nil global that silently fell back to scale 1.
        local uiScale = Instance.new("UIScale")
        uiScale.Scale = 1

        local function ripple(parent, posX, posY, col)
                local rp = Instance.new("Frame")
                rp.Size = UDim2.new(0, 0, 0, 0)
                rp.Position = UDim2.new(0, posX, 0, posY)
                rp.AnchorPoint = Vector2.new(0.5, 0.5)
                rp.BackgroundColor3 = col or C.accent
                rp.BackgroundTransparency = 0.55
                rp.BorderSizePixel = 0
                rp.ZIndex = 20
                rp.Parent = parent
                corner(rp, UDim.new(1, 0))
                -- [FIX v4.0] AbsoluteSize is PHYSICAL (post-uiScale) while the
                -- ripple offsets are LOGICAL (pre-scale). Dividing by the live
                -- scale keeps the ripple centered and sized correctly on
                -- phones, where it used to land off-center and clipped.
                local rippleScale = math.max(uiScale and uiScale.Scale or 1, 0.01)
                local base = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) / rippleScale
                local target = base * 1.6
                local t = Tween(rp, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { Size = UDim2.new(0, target, 0, target), BackgroundTransparency = 1 })
                if t then t.Completed:Connect(function() rp:Destroy() end) else rp:Destroy() end
        end

        -- ------------------------------------------------------------
        -- SCREEN GUI
        -- ------------------------------------------------------------
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = PANEL_NAME
        screenGui.ResetOnSpawn = false
        screenGui.IgnoreGuiInset = true
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        -- [v5.3.0] DisplayOrder: when the developer does not specify one, the
        -- window defaults to a HIGH order so the host game's own ScreenGuis
        -- (almost always at DisplayOrder 0..10) cannot bury ours. This was the
        -- root cause of the "UI doesn't show up" regression: under the prior
        -- default (Roblox's 0), the game's chat, billboard, and toast UI sat
        -- on top of the RezurX window and the user saw nothing. Set
        -- cfg.DisplayOrder explicitly to override.
        if tonumber(cfg.DisplayOrder) then
                screenGui.DisplayOrder = math.floor(tonumber(cfg.DisplayOrder))
        else
                screenGui.DisplayOrder = 9999
        end
        screenGui:SetAttribute("RezurXReducedMotion", reducedMotion)
        screenGui:SetAttribute("RezurXMotionScale", motionScale)
        screenGui:SetAttribute("RezurXHost", hostInfo.Resolved or "PlayerGui")
        local attached, attachError = pcall(function() screenGui.Parent = guiHost end)
        if not attached or not screenGui.Parent then
                -- CoreGui can be unavailable in normal game contexts. A clear,
                -- safe fallback is more trustworthy than forcing an unsupported
                -- parent or leaving an invisible ScreenGui behind.
                local fallback = resolvePlayerGui()
                if fallback then
                        screenGui.Parent = fallback
                        hostInfo.Resolved = "PlayerGui"
                        hostInfo.UsedFallback = true
                        screenGui:SetAttribute("RezurXHost", "PlayerGui")
                else
                        screenGui:Destroy()
                        error("[RezurXLib] Could not attach ScreenGui: " .. tostring(attachError), 2)
                end
        end
        WindowJanitor:Add(screenGui, "Destroy")

        -- Popups intentionally live in an unscaled sibling layer. The window
        -- itself scales on small screens; menus, dialogs, and dismiss catchers
        -- use physical screen coordinates and must never be scaled a second
        -- time or clipped by the window's scrolling content.
        local overlayName = PANEL_NAME .. "_Overlay"
        local oldOverlay = screenGui.Parent and screenGui.Parent:FindFirstChild(overlayName)
        if oldOverlay then oldOverlay:Destroy() end
        local overlayGui = Instance.new("ScreenGui")
        overlayGui.Name = overlayName
        overlayGui.ResetOnSpawn = false
        overlayGui.IgnoreGuiInset = true
        overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        overlayGui.DisplayOrder = screenGui.DisplayOrder + 1
        overlayGui:SetAttribute("RezurXOverlay", true)
        -- [FIX v4.0] Mirror the motion-preference attributes onto the popup
        -- layer. motionScaleFor() walks ancestors reading these attributes;
        -- the overlay never had them, so dropdowns, pickers, modals, and the
        -- command palette ignored ReducedMotion/MotionScale entirely while
        -- the settings panel happily claimed they worked.
        overlayGui:SetAttribute("RezurXReducedMotion", reducedMotion)
        overlayGui:SetAttribute("RezurXMotionScale", motionScale)
        local overlayAttached = pcall(function() overlayGui.Parent = screenGui.Parent end)
        if overlayAttached and overlayGui.Parent then
                WindowJanitor:Add(overlayGui, "Destroy")
        else
                -- A popup is still functional in the main layer if a host
                -- rejects a sibling ScreenGui, albeit without portal scaling.
                overlayGui:Destroy()
                overlayGui = screenGui
        end

        -- ═══ LAYOUT / DENSITY / SHEET MODE + AUTO SCALE (v5.0.0) ═══
        local function getViewport()
                local cam = workspace.CurrentCamera
                return cam and cam.ViewportSize or Vector2.new(1920, 1080)
        end
        -- [v5.0.0] DENSITY: Compact (phones / touch) vs Comfortable (desktop).
        -- Auto-selected; override with cfg.Density = "compact"|"comfortable".
        local density = cfg.Density
        if density ~= "compact" and density ~= "comfortable" then
                density = (UserInputService.TouchEnabled or getViewport().X < 520) and "compact" or "comfortable"
        end
        local D = density == "compact"
                and { pagePad = 10, pageGap = 7, row = 44 }
                or  { pagePad = 12, pageGap = 8, row = 46 }
        -- uiScale was forward-declared above (before ripple) and is only
        -- parented here, once the ScreenGui itself exists.
        uiScale.Parent = screenGui
        -- [v5.0.0] SHEET MODE: below ~500px viewport width the floating panel
        -- becomes a near-fullscreen sheet (pinned, margins respected) instead
        -- of a shrunk-down desktop window. Hysteresis at the boundary.
        -- The real implementation is assigned AFTER frame/shadow/clamp exist
        -- (see the resize section); camera events go through this forward
        -- declaration so early events are safe no-ops.
        local sheetMode = false
        local FLOAT_W, FLOAT_H = WIN_W, WIN_H
        local entranceSpringTable = {}
        local updateLayout = function() end
        local function updateScale() updateLayout() end -- legacy alias
        -- CurrentCamera may be nil during startup, respawns, and teleports.
        -- Rebind a single listener whenever Roblox supplies a replacement.
        -- [v5.0.0] A viewport change also resolves any in-flight window
        -- geometry springs (mobile keyboard, rotation): re-clamp instead of
        -- letting a stale spring fight the new bounds.
        local cameraJanitor = Janitor.new()
        WindowJanitor:Add(function() cameraJanitor:Cleanup() end)
        local function bindCamera()
                cameraJanitor:Cleanup()
                local camera = workspace.CurrentCamera
                if camera then
                        cameraJanitor:Add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
                                -- Resolve in-flight geometry springs, then let the
                                -- real updateLayout re-clamp (it owns frame refs).
                                for i = 1, #entranceSpringTable do
                                        springCancel(entranceSpringTable[i], true)
                                end
                                updateLayout()
                        end))
                end
                updateLayout()
        end
        WindowJanitor:Add(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
        bindCamera()

        -- [v5.0.0] FRAME-TIME GUARD: silently auto-degrade on slow hosts.
        -- A Heartbeat EMA; if the host runs worse than ~30 FPS, drop the
        -- auto motion scale to 0.5 (the UI stays usable on mid-range
        -- Android). No user config; it self-heals when frames recover.
        do
                local dtAvg = 1 / 60
                local samples = 0
                local degraded = false
                local guardConn = RunService.Heartbeat:Connect(function(dt)
                        dtAvg = dtAvg * 0.92 + dt * 0.08
                        samples = samples + 1
                        if samples < 45 then return end -- settle first
                        if not degraded and dtAvg > 0.033 then
                                degraded = true
                                screenGui:SetAttribute("RezurXAutoMotionScale", 0.5)
                        elseif degraded and dtAvg < 0.024 then
                                degraded = false
                                screenGui:SetAttribute("RezurXAutoMotionScale", 1)
                        end
                end)
                WindowJanitor:Add(function() guardConn:Disconnect() end)
        end

        -- [v4.4.0 FIX] STATUSBAR_H 24 → 30: the old 24px bar left the READY dot
        -- and version text squeezed against the frame's bottom border (the
        -- R.outer=20 corner curve eats into the bar's vertical space). 30px
        -- gives the 14px text real breathing room.
        local HEADER_H, STATUSBAR_H = 54, 30

        -- ------------------------------------------------------------
        -- WINDOW SHADOW (v5.0.0) — ONE instance, never a stack.
        -- Three stacked semi-transparent frames always stair-step at the
        -- corners; a single concentric layer cannot. Default is zero-asset
        -- (one frame, uniform falloff). Developers who want a true soft
        -- falloff pass cfg.ShadowImage = "rbxassetid://…" (their own
        -- 9-slice-ready asset) — rendered as a 9-slice ImageLabel.
        -- ------------------------------------------------------------
        local SHADOW_PAD = 10
        local SHADOW_REST = 0.86
        local shadow -- single shadow instance (Frame or 9-slice ImageLabel)
        local shadowIsImage = type(cfg.ShadowImage) == "string" and cfg.ShadowImage ~= ""
        if shadowIsImage then
                local img = Instance.new("ImageLabel")
                img.Name = "Shadow"
                img.BackgroundTransparency = 1
                img.Image = cfg.ShadowImage
                img.ScaleType = Enum.ScaleType.Slice
                img.SliceCenter = Rect.new(64, 64, 192, 192)
                img.SliceScale = 1
                img.ImageColor3 = Color3.new(0, 0, 0)
                img.ImageTransparency = SHADOW_REST - 0.15
                img.Size = UDim2.new(0, WIN_W + SHADOW_PAD * 2, 0, WIN_H + SHADOW_PAD * 2)
                img.Position = UDim2.new(0.5, -(WIN_W + SHADOW_PAD * 2) / 2, 0.5, -(WIN_H + SHADOW_PAD * 2) / 2)
                img.ZIndex = 1
                img.Parent = screenGui
                shadow = img
        else
                local sh = Instance.new("Frame")
                sh.Name = "Shadow"
                sh.Size = UDim2.new(0, WIN_W + SHADOW_PAD * 2, 0, WIN_H + SHADOW_PAD * 2)
                sh.Position = UDim2.new(0.5, -(WIN_W + SHADOW_PAD * 2) / 2, 0.5, -(WIN_H + SHADOW_PAD * 2) / 2)
                sh.BackgroundColor3 = Color3.new(0, 0, 0)
                sh.BackgroundTransparency = SHADOW_REST
                sh.BorderSizePixel = 0
                sh.ZIndex = 1
                sh.Parent = screenGui
                corner(sh, concentric(R.outer, SHADOW_PAD))
                shadow = sh
        end
        -- Single source of truth for shadow geometry: minimize / resize /
        -- drag / hide all stay in lockstep with `frame`. Integer offsets only.
        local function applyShadowBox(w, h)
                shadow.Size = UDim2.new(0, snapPx(w + SHADOW_PAD * 2), 0, snapPx(h + SHADOW_PAD * 2))
        end
        local function setShadowVisible(v)
                shadow.Visible = v
        end
        local function setShadowTransparency(mode)
                -- "lift" (dragging / resizing): deepen for focus. "rest": return.
                local lift = mode == "lift"
                if shadowIsImage then
                        Tween(shadow, T15, { ImageTransparency = lift and 0.62 or (SHADOW_REST - 0.15) })
                else
                        Tween(shadow, T15, { BackgroundTransparency = lift and 0.72 or SHADOW_REST })
                end
        end

        local frame = Instance.new("Frame")
        frame.Name = "Window"
        frame.Size = UDim2.new(0, WIN_W, 0, WIN_H)
        frame.Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2)
        frame.BackgroundColor3 = C.bg
        frame.BorderSizePixel = 0
        frame.ClipsDescendants = true
        frame.ZIndex = 2
        frame.Parent = screenGui
        corner(frame, R.outer)
        local frameStroke = stroke(frame, C.borderAcc, 1.5)
        frameStroke.Transparency = 0.55

        -- [v5.2.0] TOP EDGE ACCENT LINE: a 2px gradient strip across the very
        -- top border (accent -> secondary, e.g. orange->gold) that separates
        -- the window cleanly against bright game backgrounds. Stays visible
        -- when minimized — it seals the pill.
        local topEdge = Instance.new("Frame")
        topEdge.Name = "TopEdgeAccent"
        topEdge.Size = UDim2.new(1, 0, 0, 2)
        topEdge.Position = UDim2.new(0, 0, 0, 0)
        topEdge.BackgroundColor3 = C.accent
        topEdge.BorderSizePixel = 0
        topEdge.ZIndex = 8
        topEdge.Parent = frame
        local topEdgeGrad = Instance.new("UIGradient")
        topEdgeGrad.Rotation = 0
        topEdgeGrad.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0.0, C.accent),
                ColorSequenceKeypoint.new(1.0, C.secondary),
        }
        topEdgeGrad.Parent = topEdge
        onTheme(function()
                Tween(topEdge, T20, { BackgroundColor3 = C.accent })
                topEdgeGrad.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0.0, C.accent),
                        ColorSequenceKeypoint.new(1.0, C.secondary),
                }
        end)

        local traceRunning = false -- forward-declared (onTheme below reads it)
        -- Round joins prevent sharp pixels where the outer radius meets the
        -- footer on renderers that expose the optional LineJoinMode property.
        pcall(function()
                frameStroke.LineJoinMode = Enum.LineJoinMode.Round
        end)
        onTheme(function()
                Tween(frame, T20, { BackgroundColor3 = C.bg })
                if not traceRunning then
                        Tween(frameStroke, T20, { Color = C.borderAcc })
                end
        end)

        -- ============================================================
        -- AURORA TRACE (v5.0.0) — THE one signature animation.
        -- A single accent light travels the window perimeter: a narrow
        -- bright band in a UIGradient on the border stroke, driven by an
        -- interruptible spring on Rotation. One instance, one spring,
        -- near-zero cost. Reused everywhere, never duplicated:
        --   window entrance → one full lap
        --   tab switch      → quarter lap toward the new tab
        --   success action  → accent lap
        --   error           → same lap in red
        -- It replaced: the shockwave ring, spine sweeps, glow halos,
        -- section tick pulses, and the header shimmer. One light, one
        -- voice. (Spring-driven: rapid tab flicks redirect mid-flight
        -- and the light keeps its angular momentum.)
        -- ============================================================
        local traceGrad = Instance.new("UIGradient")
        traceGrad.Name = "TraceGradient"
        traceGrad.Rotation = 0
        traceGrad.Color = ColorSequence.new(C.accent, C.accent)
        traceGrad.Transparency = NumberSequence.new(0.55) -- flat at rest
        traceGrad.Parent = frameStroke
        local traceHandle = nil
        local TRACE_FLAT = NumberSequence.new(0.55)
        local function traceBand()
                return NumberSequence.new({
                        NumberSequenceKeypoint.new(0.00, 1),
                        NumberSequenceKeypoint.new(0.42, 1),
                        NumberSequenceKeypoint.new(0.50, 0.05),
                        NumberSequenceKeypoint.new(0.58, 1),
                        NumberSequenceKeypoint.new(1.00, 1),
                })
        end
        local function traceLap(color, turns, durationScale)
                if reducedMotion then return end
                turns = turns or 1
                local col = (typeof(color) == "Color3") and color or C.accent
                traceRunning = true
                traceGrad.Color = ColorSequence.new(col, col)
                traceGrad.Transparency = traceBand()
                frameStroke.Transparency = 0.25
                -- Spring the rotation: interruptible + velocity-preserving,
                -- so a second lap called mid-flight accelerates through
                -- instead of restarting.
                local goal = (traceHandle and traceHandle.value or traceGrad.Rotation) + 360 * turns
                traceHandle = springTo(traceHandle, traceGrad, goal, {
                        stiffness = 170, damping = 26,
                        apply = function(v, finished)
                                traceGrad.Rotation = v
                                if finished then
                                        traceRunning = false
                                        traceGrad.Transparency = TRACE_FLAT
                                        frameStroke.Transparency = 0.55
                                        traceGrad.Color = ColorSequence.new(C.accent, C.accent)
                                end
                        end,
                })
        end

        -- ENTRANCE (v5.0.0): the window LANDS via Size — never UIScale.
        -- Scaling a rounded frame re-rasterizes its corners every frame
        -- (visible corner crawl); animating Size keeps the corner geometry
        -- CONSTANT while the edges extend. Position derives from size
        -- (centered), so one integer pair drives both. Springs make it
        -- interruptible; the Trace lap (below) plays alongside.
        -- When the key gate is pending, the play is deferred until unlock.
        local runEntrance = nil
        -- entranceSpringTable is forward-declared in the layout section
        do
                local enterW = WIN_W - 24
                local enterH = WIN_H - 18
                if enterW % 2 ~= 0 then enterW = enterW - 1 end
                if enterH % 2 ~= 0 then enterH = enterH - 1 end
                local function applyWinSize(w, h)
                        w = snapPx(w)
                        h = snapPx(h)
                        frame.Size = UDim2.new(0, w, 0, h)
                        frame.Position = UDim2.new(0.5, -snapPx(w / 2), 0.5, -snapPx(h / 2))
                        applyShadowBox(w, h)
                end
                runEntrance = function()
                        -- [v5.2.2] HARDENED ENTRANCE: the frame is NEVER hidden.
                        -- Previous pattern set BackgroundTransparency = 1 then faded
                        -- back in via Tween — on executors where TweenService misbehaves,
                        -- the fade-in never landed and the window stayed invisible.
                        -- Now the frame stays at transparency 0 throughout; only the
                        -- Size springs carry the arrival motion.
                        pcall(function()
                                if shadow then
                                        shadow.Visible = true
                                        if shadowIsImage then
                                                shadow.ImageTransparency = SHADOW_REST - 0.15
                                        else
                                                shadow.BackgroundTransparency = SHADOW_REST
                                        end
                                end
                        end)
                        if reducedMotion then
                                -- Instant token: write the end state directly.
                                applyWinSize(WIN_W, WIN_H)
                                pcall(function() frame.BackgroundTransparency = 0 end)
                                pcall(function() frameStroke.Transparency = 0.55 end)
                                return
                        end
                        -- Shrink to the smaller integer rect, then spring-grow to
                        -- the resting size. Frame stays visible the whole time;
                        -- springs are interruptible so a viewport change mid-flight
                        -- retargets instead of fighting.
                        local ok = pcall(function()
                                applyWinSize(enterW, enterH)
                                frame.BackgroundTransparency = 0
                                frameStroke.Transparency = 0.55
                                -- Aurora Trace: one full accent lap on arrival.
                                traceLap(C.accent, 1)
                                entranceSpringTable[1] = springTo(entranceSpringTable[1], frame, WIN_W, {
                                        from = enterW,
                                        stiffness = 420, damping = 30,
                                        apply = function(v) applyWinSize(v, frame.Size.Y.Offset) end,
                                })
                                entranceSpringTable[2] = springTo(entranceSpringTable[2], frame, WIN_H, {
                                        from = enterH,
                                        stiffness = 420, damping = 30,
                                        apply = function(v) applyWinSize(frame.Size.X.Offset, v) end,
                                        done = function()
                                                applyWinSize(WIN_W, WIN_H)
                                        end,
                                })
                        end)
                        if not ok and frame.Parent then
                                -- Never leave a half-entranced window on screen.
                                pcall(applyWinSize, WIN_W, WIN_H)
                                pcall(function() frame.BackgroundTransparency = 0 end)
                                pcall(function() frameStroke.Transparency = 0.55 end)
                        end
                end
                -- The play is deferred until after frameStroke/Trace exist
                -- (see the Trace section below for the actual spawn point).
        end

        local body = Instance.new("Frame")
        body.Name = "Body"
        body.Size = UDim2.new(1, 0, 1, -HEADER_H)
        body.Position = UDim2.new(0, 0, 0, HEADER_H)
        body.BackgroundTransparency = 1
        body.ClipsDescendants = true
        body.ZIndex = 2
        body.Parent = frame

        -- Glow strip under the header — gradient refs captured for the
        -- theme system (gradients need direct updates, not re-creation).
        -- (Declared above as a forward local; assigned here.)
        glowStrip = Instance.new("Frame")
        glowStrip.Size = UDim2.new(1, 0, 0, 3)
        glowStrip.Position = UDim2.new(0, 0, 0, HEADER_H - 3)
        glowStrip.BackgroundColor3 = C.accent
        glowStrip.BorderSizePixel = 0
        glowStrip.ZIndex = 3
        glowStrip.Parent = frame
        local glowGrad = gradient(glowStrip, ColorSequence.new{
                ColorSequenceKeypoint.new(0.0, C.accentDim),
                ColorSequenceKeypoint.new(0.5, C.accentHi),
                ColorSequenceKeypoint.new(1.0, C.accentDim),
        })
        onTheme(function()
                glowStrip.BackgroundColor3 = C.accent
                glowGrad.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0.0, C.accentDim),
                        ColorSequenceKeypoint.new(0.5, C.accentHi),
                        ColorSequenceKeypoint.new(1.0, C.accentDim),
                }
        end)
        -- (Entrance spawn moved below, after updateLayout is installed.)

        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, HEADER_H)
        header.BackgroundColor3 = C.headerA
        header.BorderSizePixel = 0
        -- The brand glow and close-button halo must respect the rounded
        -- header shell; without clipping, they leak into the top corners.
        header.ClipsDescendants = true
        header.ZIndex = 4
        header.Parent = frame
        corner(header, R.outer)
        local headerGrad = gradient(header, ColorSequence.new{
                ColorSequenceKeypoint.new(0.0, C.headerA),
                ColorSequenceKeypoint.new(1.0, C.headerB),
        }, 100)

        local hFix = Instance.new("Frame")
        hFix.Size = UDim2.new(1, 0, 0.5, 0)
        hFix.Position = UDim2.new(0, 0, 0.5, 0)
        -- [FIX] Blend headerA and headerB for the midpoint color instead of
        -- using pure headerB — the gradient only reaches headerB at the very
        -- bottom, so a pure headerB patch created a visible seam.
        hFix.BackgroundColor3 = Color3.new(
                (C.headerA.R + C.headerB.R) * 0.5,
                (C.headerA.G + C.headerB.G) * 0.5,
                (C.headerA.B + C.headerB.B) * 0.5
        )
        hFix.BorderSizePixel = 0
        hFix.ZIndex = 4
        hFix.Parent = header

        local accentLine = Instance.new("Frame")
        accentLine.Size = UDim2.new(1, 0, 0, 2)
        accentLine.Position = UDim2.new(0, 0, 1, -2)
        accentLine.BackgroundColor3 = C.accent
        accentLine.BorderSizePixel = 0
        accentLine.ZIndex = 5
        accentLine.Parent = header

        local logoGlow = Instance.new("Frame")
        logoGlow.Size = UDim2.new(0, 44, 0, 44)
        logoGlow.AnchorPoint = Vector2.new(0.5, 0.5)
        logoGlow.Position = UDim2.new(0, 30, 0.5, 0)
        logoGlow.BackgroundColor3 = C.accent
        logoGlow.BackgroundTransparency = 0.97
        logoGlow.BorderSizePixel = 0
        logoGlow.ZIndex = 4
        logoGlow.Parent = header
        corner(logoGlow, UDim.new(1, 0))
        local logoGlowGrad = gradient(logoGlow, ColorSequence.new{
                ColorSequenceKeypoint.new(0.0, C.accent),
                ColorSequenceKeypoint.new(1.0, C.headerA),
        })
        -- A compact brand mark gives the header a focal point without
        -- turning the shell into a decorative dashboard.
        -- [v5.2.0] Sound forward-declarations: header-level controls (quick
        -- pause) reference these before the sound system initializes below.
        local playSfx = function() end
        local playSfxDual = function() end
        local humSound = nil
        local stopHum = function() end

        local brandMark = Instance.new("Frame")
        brandMark.Name = "BrandMark"
        brandMark.Size = UDim2.fromOffset(28, 28)
        brandMark.Position = UDim2.fromOffset(16, 13)
        brandMark.BackgroundColor3 = C.accentDark
        brandMark.BorderSizePixel = 0
        brandMark.ZIndex = 5
        brandMark.Parent = header
        corner(brandMark, R.small)
        local brandStroke = stroke(brandMark, C.accentDim, 1)
        local brandGradient = gradient(brandMark, ColorSequence.new{
                ColorSequenceKeypoint.new(0.0, C.accentDim),
                ColorSequenceKeypoint.new(1.0, C.accentDark),
        }, 135)
        local brandLetter = Instance.new("TextLabel")
        brandLetter.Size = UDim2.fromScale(1, 1)
        brandLetter.BackgroundTransparency = 1
        brandLetter.Font = Enum.Font.GothamBlack
        brandLetter.TextSize = 14
        brandLetter.TextColor3 = C.accentHi
        -- The badge deliberately renders the developer-provided UTF-8 text.
        -- Its length is capped and its size is adjusted by applyBrandText.
        brandLetter.TextXAlignment = Enum.TextXAlignment.Center
        brandLetter.TextYAlignment = Enum.TextYAlignment.Center
        brandLetter.ZIndex = 6
        brandLetter.Parent = brandMark
        -- [v4.0] WINDOW ICON — a number asset id or rbx URI replaces the badge
        -- letter with an image (Rayfield-style topbar icon). Emoji/text values
        -- keep the text badge.
        local windowIconUri = nil
        do
                local iconValue = cfg.Icon
                if type(iconValue) == "number" and iconValue ~= 0 then
                        windowIconUri = "rbxassetid://" .. iconValue
                elseif type(iconValue) == "string" then
                        local lower = string.lower(iconValue)
                        if string.sub(lower, 1, 13) == "rbxassetid://"
                                or string.sub(lower, 1, 11) == "rbxasset://"
                                or string.sub(lower, 1, 11) == "rbxthumb://" then
                                windowIconUri = iconValue
                        end
                end
        end
        if windowIconUri then
                local iconImg = Instance.new("ImageLabel")
                iconImg.Name = "WindowIcon"
                iconImg.Size = UDim2.fromScale(0.72, 0.72)
                iconImg.Position = UDim2.fromScale(0.5, 0.5)
                iconImg.AnchorPoint = Vector2.new(0.5, 0.5)
                iconImg.BackgroundTransparency = 1
                iconImg.Image = windowIconUri
                iconImg.ZIndex = 7
                iconImg.Parent = brandMark
                brandLetter.Visible = false
                -- The floating restore button mirrors the icon later, once
                -- floatIcon exists (see the restore-button section).
        end
        -- [v5.2.0] LIVE ACTIVITY BEACON: a breathing dot beside the logo so
        -- users can see background scripts are running while minimized.
        -- green = running, yellow = paused. Window:SetActivity(mode).
        local activityDot = nil
        local activityToken = 0
        local activityMode = nil
        local function setActivity(mode)
                activityMode = mode
                activityToken = activityToken + 1
                local myToken = activityToken
                if activityDot and activityDot.Parent then activityDot:Destroy() end
                activityDot = nil
                if mode == nil then return end
                activityDot = Instance.new("Frame")
                activityDot.Name = "ActivityBeacon"
                activityDot.Size = UDim2.fromOffset(7, 7)
                activityDot.AnchorPoint = Vector2.new(0, 0.5)
                activityDot.Position = UDim2.new(0, 50, 0.5, 0)
                activityDot.BackgroundColor3 = (mode == "paused") and C.yellow or C.green
                activityDot.BorderSizePixel = 0
                activityDot.ZIndex = 6
                activityDot.Parent = header
                corner(activityDot, UDim.new(1, 0))
                if mode == "running" and not reducedMotion then
                        task.spawn(function()
                                while activityToken == myToken and activityDot and activityDot.Parent do
                                        Tween(activityDot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                                                { BackgroundTransparency = 0.45, Size = UDim2.fromOffset(9, 9),
                                                        Position = UDim2.new(0, 49, 0.5, 0) })
                                        task.wait(0.8)
                                        if not (activityToken == myToken and activityDot and activityDot.Parent) then break end
                                        Tween(activityDot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                                                { BackgroundTransparency = 0, Size = UDim2.fromOffset(7, 7),
                                                        Position = UDim2.new(0, 50, 0.5, 0) })
                                        task.wait(0.8)
                                end
                        end)
                end
        end
        setActivity(type(cfg.Activity) == "string" and cfg.Activity or nil)

        local function applyBrandText(nextText)
                brandText = limitBadgeText(nextText, "R")
                brandLetter.Text = brandText
                brandLetter.TextSize = badgeTextSize(brandText, false)
                return brandText
        end
        applyBrandText(brandText)
        onTheme(function()
                Tween(header, T20, { BackgroundColor3 = C.headerA })
                Tween(hFix, T20, { BackgroundColor3 = Color3.new(
                        (C.headerA.R + C.headerB.R) * 0.5,
                        (C.headerA.G + C.headerB.G) * 0.5,
                        (C.headerA.B + C.headerB.B) * 0.5
                ) })
                Tween(accentLine, T20, { BackgroundColor3 = C.accent })
                logoGlow.BackgroundColor3 = C.accent
                Tween(brandMark, T20, { BackgroundColor3 = C.accentDark })
                Tween(brandStroke, T20, { Color = C.accentDim })
                Tween(brandLetter, T20, { TextColor3 = C.accentHi })
                headerGrad.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0.0, C.headerA),
                        ColorSequenceKeypoint.new(1.0, C.headerB),
                }
                logoGlowGrad.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0.0, C.accent),
                        ColorSequenceKeypoint.new(1.0, C.headerA),
                }
                brandGradient.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0.0, C.accentDim),
                        ColorSequenceKeypoint.new(1.0, C.accentDark),
                }
        end)
        -- Reserve a real lane for the controls instead of merely drawing text
        -- beneath them. The stats chip needs more space when it is enabled.
        -- The compact diagnostics chip is useful in a universal library and
        -- is visible by default. Projects can still opt out explicitly with
        -- ShowStats = false.
        local showStats = cfg.ShowStats ~= false
        -- [v5.2.0] The quick-pause control reserves a lane when configured.
        local quickPauseCfg = type(cfg.QuickPause) == "function" and cfg.QuickPause or nil
        local headerTextInset = showStats and (quickPauseCfg and 312 or 270) or (quickPauseCfg and 204 or 162)

        local logo = Instance.new("TextLabel")
        logo.Text = windowName
        logo.Size = UDim2.new(1, -headerTextInset, 0, 22)
        logo.Position = UDim2.new(0, 52, 0, 7)
        logo.BackgroundTransparency = 1
        logo.Font = Enum.Font.GothamBold
        logo.TextSize = 18
        logo.TextColor3 = C.text
        logo.TextStrokeColor3 = C.black
        logo.TextStrokeTransparency = 0.84
        logo.TextStrokeTransparency = 0.5
        logo.TextStrokeColor3 = Color3.new(0, 0, 0)
        logo.TextXAlignment = Enum.TextXAlignment.Left
        logo.TextTruncate = Enum.TextTruncate.AtEnd
        logo.ZIndex = 5
        logo.Parent = header

        local subLbl = Instance.new("TextLabel")
        subLbl.Text = subtitle
        subLbl.Size = UDim2.new(1, -headerTextInset, 0, 13)
        subLbl.Position = UDim2.new(0, 53, 0, 31)
        subLbl.BackgroundTransparency = 1
        subLbl.Font = Enum.Font.GothamMedium
        subLbl.TextSize = 10
        subLbl.TextColor3 = C.muted
        subLbl.TextStrokeColor3 = C.black
        subLbl.TextStrokeTransparency = 0.94
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
        subLbl.TextTruncate = Enum.TextTruncate.AtEnd
        subLbl.ZIndex = 5
        subLbl.Parent = header
        onTheme(function()
                Tween(logo, T20, { TextColor3 = C.text })
                Tween(subLbl, T20, { TextColor3 = C.muted })
        end)

        -- FPS / PING chip
        -- [v5.2.0] QUICK MACRO BUTTON: a tiny pause/resume control beside the
        -- FPS/ping chip so users can freeze features WITHOUT expanding the
        -- window. cfg.QuickPause = function(paused) ... end (or
        -- Window:SetQuickPause(fn)). The library only renders state + calls
        -- the callback — it never guesses what "pause" means for your script.
        if quickPauseCfg then
                local qpPaused = false
                local qpBtn = Instance.new("TextButton")
                qpBtn.Name = "QuickPause"
                qpBtn.Size = UDim2.new(0, 30, 0, 26)
                qpBtn.Position = UDim2.new(1, -222, 0.5, -13)
                qpBtn.BackgroundColor3 = C.panelAlt
                qpBtn.Text = ""
                qpBtn.AutoButtonColor = false
                qpBtn.BorderSizePixel = 0
                qpBtn.Selectable = true
                qpBtn.ZIndex = 5
                qpBtn.Parent = header
                corner(qpBtn, R.small)
                local qpStroke = stroke(qpBtn, C.border, 1)
                local qpLbl = Instance.new("TextLabel")
                qpLbl.Size = UDim2.fromScale(1, 1)
                qpLbl.BackgroundTransparency = 1
                qpLbl.Font = Enum.Font.GothamBold
                qpLbl.TextSize = 13
                qpLbl.TextColor3 = C.green
                qpLbl.Text = "❚❚"
                qpLbl.ZIndex = 6
                qpLbl.Parent = qpBtn
                local function qpRender()
                        qpLbl.Text = qpPaused and "▶" or "❚❚"
                        qpLbl.TextColor3 = qpPaused and C.yellow or C.green
                        Tween(qpStroke, T10, { Color = qpPaused and C.yellow or C.border })
                end
                qpBtn.MouseEnter:Connect(function()
                        Tween(qpBtn, T10, { BackgroundColor3 = C.panelHov })
                end)
                qpBtn.MouseLeave:Connect(function()
                        Tween(qpBtn, T10, { BackgroundColor3 = C.panelAlt })
                end)
                qpBtn.Activated:Connect(function()
                        qpPaused = not qpPaused
                        qpRender()
                        playSfx(qpPaused and "ToggleOff" or "ToggleOn")
                        task.spawn(function()
                                local ok, err = pcall(quickPauseCfg, qpPaused)
                                if not ok then warn("[RezurXLib] QuickPause callback error: " .. tostring(err)) end
                        end)
                end)
                onTheme(function()
                        Tween(qpBtn, T20, { BackgroundColor3 = C.panelAlt })
                        qpRender()
                end)
                --- Attach/replace the quick-pause behavior at runtime.
                function Window:SetQuickPause(fn)
                        if type(fn) == "function" then quickPauseCfg = fn end
                        return quickPauseCfg
                end
                Window._quickPauseState = function() return qpPaused end
        end

        local statFrame = Instance.new("Frame")
        statFrame.Size = UDim2.new(0, 118, 0, 26)
        statFrame.Position = UDim2.new(1, quickPauseCfg and -262 or -224, 0.5, -13)
        statFrame.BackgroundColor3 = C.panelAlt
        statFrame.BorderSizePixel = 0
        statFrame.ZIndex = 5
        statFrame.Visible = showStats
        statFrame.Parent = header
        corner(statFrame, R.small)
        local statStroke = stroke(statFrame, C.border, 1)

        local fpsLabel = Instance.new("TextLabel")
        -- [v4.4.0 FIX] Both labels now HUG the divider (FPS right-aligned with
        -- an 7px inset, ms left-aligned with a 7px inset) so the divider reads
        -- perfectly centered between the two values regardless of text width.
        fpsLabel.Size = UDim2.new(0.5, -7, 1, 0)
        fpsLabel.BackgroundTransparency = 1
        fpsLabel.Font = Enum.Font.Code
        fpsLabel.TextStrokeTransparency = 0.5
        fpsLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        fpsLabel.TextSize = 12
        fpsLabel.TextColor3 = C.green
        fpsLabel.TextXAlignment = Enum.TextXAlignment.Right
        fpsLabel.Text = "60 FPS"
        fpsLabel.ZIndex = 5
        fpsLabel.Parent = statFrame

        local statDivider = Instance.new("Frame")
        statDivider.Size = UDim2.new(0, 1, 0.6, 0)
        statDivider.Position = UDim2.new(0.5, 0, 0.2, 0)
        statDivider.BackgroundColor3 = C.border
        statDivider.BorderSizePixel = 0
        statDivider.ZIndex = 5
        statDivider.Parent = statFrame

        local pingLabel = Instance.new("TextLabel")
        pingLabel.Size = UDim2.new(0.5, -7, 1, 0)
        pingLabel.Position = UDim2.new(0.5, 7, 0, 0)
        pingLabel.BackgroundTransparency = 1
        pingLabel.Font = Enum.Font.Code
        pingLabel.TextStrokeTransparency = 0.5
        pingLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        pingLabel.TextSize = 12
        pingLabel.TextColor3 = C.green
        pingLabel.TextXAlignment = Enum.TextXAlignment.Left
        pingLabel.Text = "— ms"
        pingLabel.ZIndex = 5
        pingLabel.Parent = statFrame
        onTheme(function()
                Tween(statFrame, T20, { BackgroundColor3 = C.panelAlt })
                Tween(statStroke, T20, { Color = C.border })
                Tween(statDivider, T20, { BackgroundColor3 = C.border })
        end)

        local fpsAvg = 60
        if showStats then
                -- [v4.1.0 PERF] Writing fpsLabel.Text EVERY frame forced a full
                -- text re-layout ~60x/s — a measurable frame cost on low-end
                -- devices for a chip nobody reads at 60Hz. The EMA still
                -- integrates every frame (accuracy), but the label only
                -- repaints at 4Hz and only when the rounded value changed.
                local lastShownFps = -1
                local fpsAccum = 0
                WindowJanitor:Add(RunService.Heartbeat:Connect(function(dt)
                        fpsAvg = fpsAvg * 0.88 + (1 / math.max(dt, 0.001)) * 0.12
                        fpsAccum = fpsAccum + dt
                        if fpsAccum < 0.25 then return end
                        fpsAccum = 0
                        local avg = math.floor(fpsAvg + 0.5)
                        if avg == lastShownFps then return end
                        lastShownFps = avg
                        fpsLabel.Text = avg .. " FPS"
                        fpsLabel.TextColor3 = avg >= 55 and C.green or avg >= 30 and C.yellow or C.red
                end))
        end
        if showStats then task.spawn(function()
                while screenGui.Parent do
                        local ok, ms = pcall(function()
                                return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
                        end)
                        if ok and typeof(ms) == "number" then
                                ms = math.floor(ms + 0.5)
                                pingLabel.Text = ms .. " ms"
                                pingLabel.TextColor3 = ms <= 80 and C.green or ms <= 150 and C.yellow or C.red
                        else
                                pingLabel.Text = "N/A"
                                pingLabel.TextColor3 = C.muted
                        end
                        task.wait(1)
                end
        end) end


        -- MINIMIZE + HIDE buttons
        local minBtn = Instance.new("TextButton")
        minBtn.Text = ""
        minBtn.Size = UDim2.new(0, 38, 0, 32)
        minBtn.Position = UDim2.new(1, -98, 0.5, -14)
        minBtn.BackgroundColor3 = C.panelAlt
        minBtn.BorderSizePixel = 0
        minBtn.AutoButtonColor = false
        minBtn.ZIndex = 5
        minBtn.Selectable = true
        minBtn.Parent = header
        corner(minBtn, R.small)
        local minStroke = stroke(minBtn, C.border, 1)

        local minGlyph = Instance.new("Frame")
        minGlyph.Size = UDim2.new(0, 12, 0, 2)
        minGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
        minGlyph.Position = UDim2.new(0.5, 0, 0.5, 0)
        minGlyph.BackgroundColor3 = C.muted
        minGlyph.BorderSizePixel = 0
        minGlyph.ZIndex = 5
        minGlyph.Parent = minBtn
        corner(minGlyph, UDim.new(1, 0))

        -- [v4.4.0] Min/close hover: 1.08x scale + soft glow ring — the window
        -- controls now feel as polished as the content (as requested).
        local minScale = Instance.new("UIScale")
        minScale.Name = "_HoverScale"
        minScale.Scale = 1
        minScale.Parent = minBtn
        local minRing = Instance.new("Frame")
        minRing.Name = "HoverGlow"
        minRing.Size = UDim2.new(1, 8, 1, 8)
        minRing.Position = UDim2.new(0, -4, 0, -4)
        minRing.BackgroundColor3 = C.accent
        minRing.BackgroundTransparency = 1
        minRing.BorderSizePixel = 0
        minRing.ZIndex = 4
        minRing.Parent = minBtn
        corner(minRing, concentric(R.small, 4))
        minBtn.MouseEnter:Connect(function()
                Tween(minBtn, T10, { BackgroundColor3 = C.panelHov })
                Tween(minGlyph, T10, { BackgroundColor3 = C.text })
                Tween(minStroke, T10, { Color = C.accentDim })
                Tween(minScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.08 })
                Tween(minRing, T15, { BackgroundTransparency = 0.88 })
        end)
        minBtn.MouseLeave:Connect(function()
                Tween(minBtn, T10, { BackgroundColor3 = C.panelAlt })
                Tween(minGlyph, T10, { BackgroundColor3 = C.muted })
                Tween(minStroke, T10, { Color = C.border })
                Tween(minScale, TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 })
                Tween(minRing, T15, { BackgroundTransparency = 1 })
        end)
        onTheme(function()
                Tween(minBtn, T20, { BackgroundColor3 = C.panelAlt })
                Tween(minStroke, T20, { Color = C.border })
        end)

        -- MINIMIZE LOGIC moved below — it references tabBar/content/statusBar,
        -- which aren't created until later in this function. Wiring
        -- minBtn.Activated here referenced them as nil globals instead of
        -- upvalues; clicking minimize threw silently (visible in the dev
        -- console, invisible to the player) and did nothing. See the
        -- consolidated HIDE / SHOW / MINIMIZE / TOGGLE KEYBIND section.

        local closeBtn = Instance.new("TextButton")
        closeBtn.Text = ""
        closeBtn.Size = UDim2.new(0, 38, 0, 32)
        closeBtn.Position = UDim2.new(1, -56, 0.5, -14)
        closeBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
        closeBtn.BorderSizePixel = 0
        closeBtn.AutoButtonColor = false
        closeBtn.ZIndex = 5
        closeBtn.Selectable = true
        closeBtn.Parent = header
        corner(closeBtn, R.small)
        local closeStroke = stroke(closeBtn, Color3.fromRGB(160, 50, 50), 1)
        local closeGrad = gradient(closeBtn, ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 40, 40)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(95, 22, 22)),
        }), 90)

        -- soft glow ring behind the button, only visible on hover
        local closeGlow = Instance.new("Frame")
        closeGlow.Size = UDim2.new(1, 14, 1, 14)
        closeGlow.AnchorPoint = Vector2.new(0.5, 0.5)
        closeGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
        closeGlow.BackgroundColor3 = C.red
        closeGlow.BackgroundTransparency = 1
        closeGlow.BorderSizePixel = 0
        closeGlow.ZIndex = 4
        closeGlow.Parent = header
        corner(closeGlow, R.small + 4)

        -- line-drawn X (two crossed bars) instead of a text glyph — matches
        -- minGlyph's visual language rather than mixing fonts/weights
        local xBar1 = Instance.new("Frame")
        xBar1.Size = UDim2.new(0, 13, 0, 2)
        xBar1.AnchorPoint = Vector2.new(0.5, 0.5)
        xBar1.Position = UDim2.new(0.5, 0, 0.5, 0)
        xBar1.Rotation = 45
        xBar1.BackgroundColor3 = C.white
        xBar1.BorderSizePixel = 0
        xBar1.ZIndex = 6
        xBar1.Parent = closeBtn
        corner(xBar1, UDim.new(1, 0))
        local xBar2 = xBar1:Clone()
        xBar2.Rotation = -45
        xBar2.Parent = closeBtn

        local closeScale = Instance.new("UIScale")
        closeScale.Name = "_HoverScale"
        closeScale.Scale = 1
        closeScale.Parent = closeBtn
        closeBtn.MouseEnter:Connect(function()
                Tween(closeBtn, T10, { BackgroundColor3 = Color3.fromRGB(210, 55, 55) })
                Tween(closeStroke, T10, { Color = Color3.fromRGB(255, 120, 120) })
                Tween(closeGlow, T15, { BackgroundTransparency = 0.75 })
                Tween(closeScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.08 })
        end)
        closeBtn.MouseLeave:Connect(function()
                Tween(closeBtn, T10, { BackgroundColor3 = Color3.fromRGB(120, 30, 30) })
                Tween(closeStroke, T10, { Color = Color3.fromRGB(160, 50, 50) })
                Tween(closeGlow, T15, { BackgroundTransparency = 1 })
                Tween(closeScale, TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 })
        end)
        closeBtn.MouseButton1Down:Connect(function()
                Tween(closeBtn, TPRESS, { Size = UDim2.new(0, 34, 0, 29) })
        end)
        closeBtn.MouseButton1Up:Connect(function()
                Tween(closeBtn, T10, { Size = UDim2.new(0, 38, 0, 32) })
        end)

        -- ═══ FLOATING RESTORE ICON ═══
        local floatIcon = Instance.new("TextButton")
        floatIcon.Name = "FloatIcon"
        floatIcon.Size = UDim2.new(0, 52, 0, 52)
        -- [FIX] Center the ball on screen instead of top-left corner
        floatIcon.Position = UDim2.new(0.5, -26, 0.5, -26)
        floatIcon.BackgroundColor3 = C.accent
        -- The restore control is intentionally configurable; Roblox will use
        -- its normal font fallback for emoji and symbols when available.
        floatIcon.Text = restoreText
        floatIcon.Font = Enum.Font.GothamBold
        floatIcon.TextSize = badgeTextSize(restoreText, true)
        floatIcon.TextColor3 = C.white
        floatIcon.AutoButtonColor = false
        floatIcon.BorderSizePixel = 0
        -- The restore control sits above the window but below modal layers.
        floatIcon.ZIndex = 65
        floatIcon.Selectable = true
        floatIcon.Visible = false
        floatIcon.Parent = overlayGui
        corner(floatIcon, UDim.new(1, 0))
        stroke(floatIcon, C.white, 2)
        local function applyRestoreText(nextText)
                restoreText = limitBadgeText(nextText, brandText)
                floatIcon.Text = restoreText
                floatIcon.TextSize = badgeTextSize(restoreText, true)
                return restoreText
        end
        applyRestoreText(restoreText)
        -- [v4.0] Mirror the window's asset icon onto the floating restore
        -- button (and hide the text) when one is configured.
        if windowIconUri then
                local floatImg = Instance.new("ImageLabel")
                floatImg.Name = "FloatIconImage"
                floatImg.Size = UDim2.fromScale(0.62, 0.62)
                floatImg.Position = UDim2.fromScale(0.5, 0.5)
                floatImg.AnchorPoint = Vector2.new(0.5, 0.5)
                floatImg.BackgroundTransparency = 1
                floatImg.Image = windowIconUri
                floatImg.ZIndex = 2
                floatImg.Parent = floatIcon
        end
        -- [FIX] Track movement so tap (restore) vs drag (move) is distinguished
        local floatDragMoved = false
        floatIcon.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        local startPointer = Vector2.new(inp.Position.X, inp.Position.Y)
                        floatDragMoved = false
                        -- Pointer events and AbsolutePosition are both in physical
                        -- screen pixels. Mixing them with Position.Offset discards
                        -- the initial 0.5 scale position and caused the first move to
                        -- snap to the top-left corner.
                        local startAbs = floatIcon.AbsolutePosition
                        local startPosition = floatIcon.Position
                        local pointerOffset = startPointer - startAbs
                        local iconWidth = math.max(floatIcon.AbsoluteSize.X, 1)
                        local iconHeight = math.max(floatIcon.AbsoluteSize.Y, 1)
                        registerDrag("floatIcon", inp, function(pos)
                                local pointer = Vector2.new(pos.X, pos.Y)
                                local d = pointer - startPointer
                                if d.Magnitude > 6 then floatDragMoved = true end
                                -- [FIX v4.0] Re-read the viewport and overlay scale every
                                -- move instead of freezing them at press time: rotating
                                -- the device (or resizing the window) mid-drag used to
                                -- clamp against stale bounds and could drop the icon
                                -- outside the new viewport until the next drag.
                                local vp = getViewport()
                                local overlayScale = overlayGui == screenGui
                                        and math.max(uiScale.Scale, 0.01) or 1
                                -- Preserve the point the user grabbed. This keeps an
                                -- edge grab under the cursor/finger instead of snapping
                                -- the button's top-left toward the pointer on first move.
                                local targetX = math.clamp(pointer.X - pointerOffset.X, 0, math.max(0, vp.X - iconWidth))
                                local targetY = math.clamp(pointer.Y - pointerOffset.Y, 0, math.max(0, vp.Y - iconHeight))
                                -- Keep the original scale terms intact and apply only
                                -- the physical drag delta. Replacing a centered
                                -- UDim2 with pure offsets is what caused the first
                                -- restore-button movement to jump upward.
                                floatIcon.Position = UDim2.new(
                                        startPosition.X.Scale, startPosition.X.Offset + (targetX - startAbs.X) / overlayScale,
                                        startPosition.Y.Scale, startPosition.Y.Offset + (targetY - startAbs.Y) / overlayScale
                                )
                        end)
                end
        end)
        -- floatIcon.Activated is wired up later, after setHidden exists (see the
        -- consolidated HIDE / SHOW / MINIMIZE / TOGGLE KEYBIND section below) —
        -- a local declared later in this same function isn't visible to a
        -- closure written before it, so wiring it here would have called a
        -- nonexistent global and errored the first time someone tapped the icon.

        -- Keep all window layers locked together in physical screen space.
        -- Position uses logical offsets under UIScale, so every physical delta
        -- is converted exactly once before it is applied.
        local function clampWindowPosition(x, y)
                local viewport = getViewport()
                local windowSize = frame.AbsoluteSize
                local visibleX = math.min(96, math.max(52, windowSize.X - 20))
                local visibleY = math.min(74, math.max(44, windowSize.Y - 10))
                return math.clamp(x, visibleX - windowSize.X, viewport.X - visibleX),
                        math.clamp(y, 6, viewport.Y - visibleY)
        end
        local function moveWindowTo(x, y)
                local current = frame.AbsolutePosition
                local scale = math.max(uiScale.Scale, 0.01)
                local deltaX = (x - current.X) / scale
                local deltaY = (y - current.Y) / scale
                local function translate(gui)
                        local position = gui.Position
                        gui.Position = UDim2.new(
                                position.X.Scale, position.X.Offset + deltaX,
                                position.Y.Scale, position.Y.Offset + deltaY
                        )
                end
                translate(frame)
                translate(shadow)
        end

        -- ------------------------------------------------------------
        -- WINDOW DRAG (via shared drag router)
        -- [FIX] Use dedicated dragBar instead of header.InputBegan
        -- to prevent drag from firing when clicking minBtn/closeBtn
        -- ------------------------------------------------------------
        local dragBar = Instance.new("TextButton")
        dragBar.Name = "DragBar"
        dragBar.Size = UDim2.new(1, -108, 1, 0)
        dragBar.Position = UDim2.new(0, 0, 0, 0)
        dragBar.BackgroundTransparency = 1
        dragBar.Text = ""
        dragBar.AutoButtonColor = false
        dragBar.BorderSizePixel = 0
        -- [FIX] ZIndex 6 = above logoGlow(4), statFrame(5), logo(5), subLbl(5)
        -- and leaves a 108px control lane, so minBtn/closeBtn stay tappable.
        dragBar.ZIndex = 6
        dragBar.Active = true
        dragBar.Selectable = false
        dragBar.Parent = header

        WindowJanitor:Add(dragBar.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                        or inp.UserInputType == Enum.UserInputType.Touch then
                        local dragStart = inp.Position
                        local startAbs = frame.AbsolutePosition
                        local moved = false
                        if Window.Focus then Window:Focus() end
                        registerDrag("window", inp, function(pos)
                                local d = pos - dragStart
                                if not moved and d.Magnitude < 5 then return end
                                if not moved then
                                        moved = true
                                        setShadowTransparency("lift")
                                        Tween(frameStroke, T15, { Transparency = 0.15 })
                                end
                                local targetX, targetY = clampWindowPosition(startAbs.X + d.X, startAbs.Y + d.Y)
                                moveWindowTo(targetX, targetY)
                        end, function()
                                setShadowTransparency("rest")
                                Tween(frameStroke, T15, { Transparency = 0.55 })
                        end)
                end
        end))

        -- ------------------------------------------------------------
        -- [v5.5.0 MAGMA] SIDEBAR NAVIGATION RAIL — Rayfield Gen2 × Maclib
        -- cross. Tabs live in a VERTICAL rail on the left (Maclib sidebar
        -- discipline) with Rayfield-style pill chips and a sliding edge-bar
        -- selector carrying the lava gradient. Narrow/sheet windows collapse
        -- the rail to an icon strip so phones keep their content width.
        -- ------------------------------------------------------------
        -- [v5.5.0] Forward-declared here: the sidebar's adaptive-mode helpers
        -- and the chip-mode refresher close over Tabs/ActiveTab/
        -- moveIndicatorTo, which gain their real values further below.
        local Tabs = {}
        local ActiveTab = nil
        local moveIndicatorTo = function() end
        local SIDEBAR_W = 156
        local SIDEBAR_ICON_W = 54
        local sidebarIconMode = false
        local tabBar = Instance.new("ScrollingFrame")
        tabBar.Name = "TabRail"
        tabBar.Size = UDim2.new(0, SIDEBAR_W, 1, -STATUSBAR_H)
        tabBar.Position = UDim2.new(0, 0, 0, 0)
        tabBar.BackgroundColor3 = C.tabBarBg
        tabBar.BorderSizePixel = 0
        tabBar.ZIndex = 3
        tabBar.ScrollingDirection = Enum.ScrollingDirection.Y
        tabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
        tabBar.ScrollBarThickness = 3
        tabBar.ScrollBarImageColor3 = C.accent
        tabBar.ScrollBarImageTransparency = 0.5
        tabBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
        tabBar.ElasticBehavior = Enum.ElasticBehavior.Never
        tabBar.Parent = body
        local tabBarStroke = stroke(tabBar, C.border, 1)

        -- [v5.5.0] VERTICAL FADE MASKS: tabs that run past the rail's top or
        -- bottom edge fade out smoothly instead of cutting off hard. Tinted
        -- to the rail background; the TOP mask only shows once scrolled.
        -- (Scoped: the masks are referenced only here and inside onTheme —
        -- freeing their registers for the rest of this very large function.)
        do
                local tabFadeRight = Instance.new("Frame")
                tabFadeRight.Name = "TabFadeBottom"
                tabFadeRight.Size = UDim2.new(1, 0, 0, 22)
                tabFadeRight.Position = UDim2.new(0, 0, 1, -22)
                tabFadeRight.BackgroundColor3 = C.tabBarBg
                tabFadeRight.BorderSizePixel = 0
                tabFadeRight.ZIndex = 7
                tabFadeRight.Parent = tabBar
                local tabFadeRightGrad = Instance.new("UIGradient")
                tabFadeRightGrad.Rotation = 90
                tabFadeRightGrad.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0.0, 1.0),
                        NumberSequenceKeypoint.new(1.0, 0.0),
                })
                tabFadeRightGrad.Parent = tabFadeRight
                local tabFadeLeft = tabFadeRight:Clone()
                tabFadeLeft.Name = "TabFadeTop"
                tabFadeLeft.Position = UDim2.new(0, 0, 0, 0)
                tabFadeLeft.BackgroundColor3 = C.tabBarBg
                tabFadeLeft.ZIndex = 7
                tabFadeLeft.Parent = tabBar
                local tabFadeLeftGrad = tabFadeLeft:FindFirstChildOfClass("UIGradient")
                tabFadeLeftGrad.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0.0, 0.0),
                        NumberSequenceKeypoint.new(1.0, 1.0),
                })
                tabFadeLeft.Visible = false
                tabBar:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                        tabFadeLeft.Visible = tabBar.CanvasPosition.Y > 2
                end)
                onTheme(function()
                        Tween(tabFadeRight, T20, { BackgroundColor3 = C.tabBarBg })
                        Tween(tabFadeLeft, T20, { BackgroundColor3 = C.tabBarBg })
                end)
        end

        local tabRail = Instance.new("Frame")
        tabRail.Name = "TabList"
        tabRail.Size = UDim2.new(1, -14, 0, 0)
        tabRail.Position = UDim2.fromOffset(7, 10)
        tabRail.AutomaticSize = Enum.AutomaticSize.Y
        tabRail.BackgroundTransparency = 1
        tabRail.Parent = tabBar
        local tabLayout = Instance.new("UIListLayout")
        tabLayout.FillDirection = Enum.FillDirection.Vertical
        tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        tabLayout.VerticalAlignment = Enum.VerticalAlignment.Top
        tabLayout.Padding = UDim.new(0, 5)
        tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tabLayout.Parent = tabRail

        -- [v5.5.0 MAGMA] The selector is a VERTICAL EDGE BAR on the rail's
        -- left edge — a 3px lava-gradient core with a soft 5px glow backing,
        -- both moving as ONE instance pair on ONE spring (interruptible,
        -- momentum preserving). Rayfield's pill indicator, rotated Maclib.
        local tabIndicator = Instance.new("Frame")
        tabIndicator.Name = "ActiveIndicatorGlow"
        tabIndicator.Size = UDim2.new(0, 5, 0, 30)
        tabIndicator.Position = UDim2.new(0, 2, 0, 10)
        tabIndicator.BackgroundColor3 = C.accent
        tabIndicator.BackgroundTransparency = 0.86
        tabIndicator.BorderSizePixel = 0
        tabIndicator.ZIndex = 5
        tabIndicator.Parent = tabBar
        corner(tabIndicator, PILL)
        local tabIndCore = Instance.new("Frame")
        tabIndCore.Name = "ActiveIndicator"
        tabIndCore.Size = UDim2.new(0, 3, 1, 0)
        tabIndCore.Position = UDim2.new(0, 1, 0, 0)
        tabIndCore.BackgroundColor3 = C.accent
        tabIndCore.BorderSizePixel = 0
        tabIndCore.ZIndex = 6
        tabIndCore.Parent = tabIndicator
        corner(tabIndCore, PILL)
        local tabIndGrad = gradient(tabIndCore, ColorSequence.new{
                ColorSequenceKeypoint.new(0.0, C.accent),
                ColorSequenceKeypoint.new(0.5, C.accentHi),
                ColorSequenceKeypoint.new(1.0, C.secondary),
        }, 90)
        onTheme(function()
                Tween(tabBar, T20, { BackgroundColor3 = C.tabBarBg })
                tabBar.ScrollBarImageColor3 = C.accent
                Tween(tabBarStroke, T20, { Color = C.border })
                Tween(tabIndicator, T20, { BackgroundColor3 = C.accent })
                Tween(tabIndCore, T20, { BackgroundColor3 = C.accent })
                tabIndGrad.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0.0, C.accent),
                        ColorSequenceKeypoint.new(0.5, C.accentHi),
                        ColorSequenceKeypoint.new(1.0, C.secondary),
                }
        end)

        local content = Instance.new("Frame")
        content.Name = "Content"
        content.Size = UDim2.new(1, -SIDEBAR_W, 1, -STATUSBAR_H)
        content.Position = UDim2.new(0, SIDEBAR_W, 0, 0)
        content.BackgroundTransparency = 1
        content.Parent = body

        -- [v5.5.0] Lava hairline between rail and content: a 1px vertical
        -- divider carrying the accent at whisper transparency — Rayfield's
        -- separator detail in the library's signature gradient.
        local tabDivider = Instance.new("Frame")
        tabDivider.Name = "SidebarDivider"
        tabDivider.Size = UDim2.new(0, 1, 1, -STATUSBAR_H)
        tabDivider.Position = UDim2.new(0, SIDEBAR_W, 0, 0)
        tabDivider.BackgroundColor3 = C.accent
        tabDivider.BackgroundTransparency = 0.82
        tabDivider.BorderSizePixel = 0
        tabDivider.ZIndex = 4
        tabDivider.Parent = body
        do
                local tabDividerGrad = gradient(tabDivider, ColorSequence.new{
                        ColorSequenceKeypoint.new(0.0, C.accent),
                        ColorSequenceKeypoint.new(0.45, C.secondary),
                        ColorSequenceKeypoint.new(1.0, C.accent),
                }, 90)
                onTheme(function()
                        Tween(tabDivider, T20, { BackgroundColor3 = C.accent })
                        tabDividerGrad.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(0.0, C.accent),
                                ColorSequenceKeypoint.new(0.45, C.secondary),
                                ColorSequenceKeypoint.new(1.0, C.accent),
                        }
                end)
        end

        -- [v5.5.0] Adaptive rail: sheet mode (phones) and narrow floating
        -- windows collapse the sidebar to an icon strip so content keeps
        -- its width. Chips restyle themselves (emoji-only labels, centered);
        -- asset icons center; text-only chips shrink to quiet squares.
        local function refreshTabChipModes()
                for _, t in ipairs(Tabs) do
                        local chip, lbl = t.Btn, t._textLbl
                        local iconImg = t._tabIconImg
                        if not chip or not chip.Parent or not lbl then continue end
                        if sidebarIconMode then
                                lbl.Text = t._iconText or ""
                                lbl.TextXAlignment = Enum.TextXAlignment.Center
                                lbl.Size = UDim2.new(1, 0, 1, 0)
                                lbl.Position = UDim2.fromOffset(0, 0)
                                if iconImg then
                                        iconImg.Position = UDim2.new(0.5, -9, 0.5, -9)
                                end
                        else
                                lbl.Text = t._fullLabel or ""
                                lbl.TextXAlignment = Enum.TextXAlignment.Left
                                if iconImg then
                                        iconImg.Position = UDim2.new(0, 11, 0.5, -9)
                                        lbl.Size = UDim2.new(1, -44, 1, 0)
                                        lbl.Position = UDim2.fromOffset(38, 0)
                                else
                                        lbl.Size = UDim2.new(1, -20, 1, 0)
                                        lbl.Position = UDim2.fromOffset(10, 0)
                                end
                        end
                end
        end
        local function applySidebarMode()
                local iconMode = sheetMode or WIN_W < 420
                if iconMode == sidebarIconMode then return end
                sidebarIconMode = iconMode
                local w = iconMode and SIDEBAR_ICON_W or SIDEBAR_W
                tabBar.Size = UDim2.new(0, w, 1, -STATUSBAR_H)
                content.Size = UDim2.new(1, -w, 1, -STATUSBAR_H)
                content.Position = UDim2.new(0, w, 0, 0)
                tabDivider.Position = UDim2.new(0, w, 0, 0)
                refreshTabChipModes()
                task.defer(function()
                        if ActiveTab and ActiveTab.Btn and ActiveTab.Btn.Parent then
                                moveIndicatorTo(ActiveTab.Btn, false)
                        end
                end)
        end

        -- The footer owns a taller rounded surface. Its top rounding is above
        -- the visible bar, while its lower rounding precisely follows the
        -- shell's corner radius and prevents square footer pixels from bleeding.
        local footerMask = Instance.new("Frame")
        footerMask.Name = "FooterMask"
        footerMask.Size = UDim2.new(1, 0, 0, STATUSBAR_H + R.outer)
        footerMask.Position = UDim2.new(0, 0, 1, -(STATUSBAR_H + R.outer))
        footerMask.BackgroundColor3 = C.panel
        footerMask.BackgroundTransparency = 0
        footerMask.BorderSizePixel = 0
        footerMask.ClipsDescendants = true
        footerMask.ZIndex = 3
        footerMask.Parent = frame
        corner(footerMask, R.outer)

        -- UICorner rounds the surface that owns it, not a child's fill. Use
        -- the rounded footer surface as the actual background, then cover its
        -- upper setup area with the window color. The remaining 24px footer
        -- has genuinely smooth lower corners on every renderer.
        local footerCover = Instance.new("Frame")
        footerCover.Name = "FooterTopCover"
        footerCover.Size = UDim2.new(1, 0, 0, R.outer)
        footerCover.Position = UDim2.new(0, 0, 0, 0)
        footerCover.BackgroundColor3 = C.bg
        footerCover.BorderSizePixel = 0
        footerCover.ZIndex = 4
        footerCover.Parent = footerMask

        local statusBar = Instance.new("Frame")
        statusBar.Size = UDim2.new(1, 0, 0, STATUSBAR_H)
        statusBar.Position = UDim2.new(0, 0, 1, -STATUSBAR_H)
        statusBar.BackgroundTransparency = 1
        statusBar.BorderSizePixel = 0
        statusBar.ClipsDescendants = true
        statusBar.Parent = footerMask
        local sbFix = Instance.new("Frame")
        sbFix.Size = UDim2.new(1, 0, 0.5, 0)
        sbFix.BackgroundTransparency = 1
        sbFix.BorderSizePixel = 0
        sbFix.ZIndex = 4
        sbFix.Parent = statusBar
        local sbTopLine = Instance.new("Frame")
        sbTopLine.Size = UDim2.new(1, 0, 0, 1)
        sbTopLine.BackgroundColor3 = C.border
        sbTopLine.BorderSizePixel = 0
        sbTopLine.ZIndex = 5
        sbTopLine.Parent = statusBar
        onTheme(function()
                Tween(footerMask, T20, { BackgroundColor3 = C.panel })
                Tween(footerCover, T20, { BackgroundColor3 = C.bg })
                Tween(statusBar, T20, { BackgroundColor3 = C.panel })
                Tween(sbFix, T20, { BackgroundColor3 = C.panel })
                Tween(sbTopLine, T20, { BackgroundColor3 = C.border })
        end)

        local sDot = Instance.new("Frame")
        sDot.Size = UDim2.new(0, 7, 0, 7)
        sDot.Position = UDim2.new(0, 16, 0.5, -3)
        sDot.BackgroundColor3 = C.green
        sDot.BorderSizePixel = 0
        sDot.ZIndex = 6
        sDot.Parent = statusBar
        corner(sDot, 4)
        if cfg.ShowStatusPulse == true and not reducedMotion then
                task.spawn(function()
                        while sDot.Parent do
                                Tween(sDot, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                                        { BackgroundColor3 = C.greenDim })
                                task.wait(0.7)
                                if not sDot.Parent then break end
                                Tween(sDot, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                                        { BackgroundColor3 = C.green })
                                task.wait(0.7)
                        end
                end)
        end

        local sTxt = Instance.new("TextLabel")
        sTxt.AutomaticSize = Enum.AutomaticSize.X
        sTxt.Size = UDim2.new(0, 0, 0, 14)
        sTxt.Position = UDim2.new(0, 30, 0.5, -7)
        sTxt.BackgroundTransparency = 1
        sTxt.Font = Enum.Font.Code
        sTxt.TextSize = 10
        sTxt.TextColor3 = C.muted
        sTxt.TextXAlignment = Enum.TextXAlignment.Left
        sTxt.ZIndex = 6
        sTxt.Text = cfg.StatusText or "READY"
        sTxt.Parent = statusBar
        if cfg.ShowUptime == true then
                local sBootTime = os.clock()
                task.spawn(function()
                        while sTxt.Parent do
                                local e = os.clock() - sBootTime
                                sTxt.Text = string.format("UP %02d:%02d", math.floor(e / 60), math.floor(e % 60))
                                task.wait(1)
                        end
                end)
        end

        local sVer = Instance.new("TextLabel")
        sVer.AutomaticSize = Enum.AutomaticSize.X
        sVer.Size = UDim2.new(0, 0, 0, 14)
        sVer.AnchorPoint = Vector2.new(1, 0.5)
        -- [v4.4.0] Shifted left to make room for the new keybind badge chip.
        sVer.Position = UDim2.new(1, -84, 0.5, -7)
        sVer.BackgroundTransparency = 1
        sVer.Font = Enum.Font.Code
        sVer.TextSize = 10
        sVer.TextColor3 = C.muted
        sVer.TextXAlignment = Enum.TextXAlignment.Right
        sVer.TextTruncate = Enum.TextTruncate.AtEnd
        sVer.ZIndex = 6
        sVer.Text = windowName .. " · RezurXLib v" .. Library.Version
        sVer.Parent = statusBar

        -- [v4.4.0] QUICK-ACCESS KEYBIND BADGE: a chip in the footer showing the
        -- live toggle shortcut (e.g. "[K] HIDE") — discoverable accessibility
        -- without reading docs. Updates when SetToggleKeybind changes.
        local keyBadge = Instance.new("Frame")
        keyBadge.Name = "KeybindBadge"
        keyBadge.AutomaticSize = Enum.AutomaticSize.X
        keyBadge.Size = UDim2.new(0, 0, 0, 18)
        keyBadge.AnchorPoint = Vector2.new(1, 0.5)
        keyBadge.Position = UDim2.new(1, -14, 0.5, -9)
        keyBadge.BackgroundColor3 = C.panelAlt
        keyBadge.BorderSizePixel = 0
        keyBadge.ZIndex = 6
        keyBadge.Parent = statusBar
        corner(keyBadge, PILL)
        local keyBadgeStroke = stroke(keyBadge, C.border, 1)
        pad(keyBadge, 2, 2, 8, 8)
        local keyBadgeLbl = Instance.new("TextLabel")
        keyBadgeLbl.Size = UDim2.new(0, 0, 1, 0)
        keyBadgeLbl.AutomaticSize = Enum.AutomaticSize.X
        keyBadgeLbl.BackgroundTransparency = 1
        keyBadgeLbl.Font = Enum.Font.Code
        keyBadgeLbl.TextSize = 9
        keyBadgeLbl.TextColor3 = C.textDim
        keyBadgeLbl.TextXAlignment = Enum.TextXAlignment.Left
        keyBadgeLbl.Text = "[" .. string.upper(keyName(toggleKey)) .. "] HIDE"
        keyBadgeLbl.ZIndex = 7
        keyBadgeLbl.Parent = keyBadge
        local function refreshKeyBadge()
                keyBadgeLbl.Text = "[" .. string.upper(keyName(toggleKey)) .. "] HIDE"
        end
        onTheme(function()
                Tween(keyBadge, T20, { BackgroundColor3 = C.panelAlt })
                Tween(keyBadgeStroke, T20, { Color = C.border })
                Tween(keyBadgeLbl, T20, { TextColor3 = C.textDim })
        end)
        onTheme(function()
                Tween(sTxt, T20, { TextColor3 = C.muted })
                Tween(sVer, T20, { TextColor3 = C.muted })
        end)

        -- [FIX] Make status bar draggable (move window from bottom too)
        -- The footer is informational only. Letting it drag the window made
        -- scrolls and taps near status text feel unpredictable on touch.

        -- A full-size resize button looked like a detached square at the
        -- rounded corner. Keep the hit target generous but render only a
        -- compact, fully inset three-dot grip.
        local resizeHandle = Instance.new("TextButton")
        resizeHandle.Name = "ResizeHandle"
        -- [FIX v4.0] 40x40 hit area (mobile minimum) while the visible grip
        -- stays a compact three-dot cluster; 24x24 was nearly impossible to
        -- hit reliably with a thumb.
        resizeHandle.Size = UDim2.fromOffset(44, 44)
        resizeHandle.Position = UDim2.new(1, -50, 1, -46)
        resizeHandle.BackgroundTransparency = 1
        resizeHandle.Text = ""
        resizeHandle.AutoButtonColor = false
        resizeHandle.BorderSizePixel = 0
        resizeHandle.ZIndex = 8
        resizeHandle.Selectable = true
        resizeHandle.Visible = resizable
        resizeHandle.Parent = frame
        local gripDots = {}
        for index = 1, 3 do
                local dot = Instance.new("Frame")
                dot.Name = "GripDot" .. index
                dot.Size = UDim2.fromOffset(3, 3)
                dot.Position = UDim2.fromOffset(15 + (index - 1) * 4, 25 - (index - 1) * 4)
                dot.BackgroundColor3 = C.muted
                dot.BorderSizePixel = 0
                dot.ZIndex = 9
                dot.Parent = resizeHandle
                corner(dot, UDim.new(1, 0))
                table.insert(gripDots, dot)
        end
        resizeHandle.MouseEnter:Connect(function()
                for _, dot in ipairs(gripDots) do Tween(dot, T10, { BackgroundColor3 = C.accent }) end
        end)
        resizeHandle.MouseLeave:Connect(function()
                for _, dot in ipairs(gripDots) do Tween(dot, T10, { BackgroundColor3 = C.muted }) end
        end)
        WindowJanitor:Add(resizeHandle.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                        or inp.UserInputType == Enum.UserInputType.Touch then
                -- Lock top-left corner: record it in absolute pixels, resize from there
                local dragStart = inp.Position
                local startW, startH = WIN_W, WIN_H
                local startFramePosition = frame.Position
                local startShadowPosition = shadow.Position
                local scale = math.max(uiScale.Scale, 0.01)
                setShadowTransparency("lift")
                Tween(frameStroke, T15, { Transparency = 0.15 })
                registerDrag("resize", inp, function(pos)
                        local d = pos - dragStart
                        local newW = math.clamp(startW + d.X / scale, MIN_W, MAX_W)
                        local newH = math.clamp(startH + d.Y / scale, MIN_H, MAX_H)
                        WIN_W = newW
                        WIN_H = newH
                        frame.Position = startFramePosition
                        frame.Size = UDim2.new(0, newW, 0, newH)
                        shadow.Position = startShadowPosition
                        applyShadowBox(newW, newH)
                        if not minimized then
                                body.Size = UDim2.new(1, 0, 0, newH - HEADER_H)
                        end
                end, function()
                        -- Keep the top-left corner under the pointer after a
                        -- possible mobile re-scale. Re-scaling every movement
                        -- made resize feel like it was fighting the user.
                        local pinned = frame.AbsolutePosition
                        updateScale()
                        local x, y = clampWindowPosition(pinned.X, pinned.Y)
                        moveWindowTo(x, y)
                        setShadowTransparency("rest")
                        Tween(frameStroke, T15, { Transparency = 0.55 })
                end)
                end
        end))
        onTheme(function()
                for _, dot in ipairs(gripDots) do Tween(dot, T20, { BackgroundColor3 = C.muted }) end
        end)

        -- ============================================================
        -- [v5.0.0] REAL updateLayout — assigned now that frame, shadow,
        -- resize handle, and window clamping all exist. (The camera
        -- listener captured the forward-declared local above, so this
        -- reassignment is what it calls from now on.)
        -- ============================================================
        local function applyWindowSize(w, h)
                WIN_W = snapPx(w)
                WIN_H = snapPx(h)
                frame.Size = UDim2.new(0, WIN_W, 0, WIN_H)
                applyShadowBox(WIN_W, WIN_H)
                -- [v5.5.0] Manual resizes can cross the icon-rail threshold.
                pcall(applySidebarMode)
        end
        updateLayout = function()
                local vp = getViewport()
                if not sheetMode and vp.X <= 500 then
                        -- Enter sheet mode: near-fullscreen, pinned, unscaled.
                        sheetMode = true
                        applyWindowSize(vp.X - 16, vp.Y - 110)
                        frame.Position = UDim2.new(0.5, -snapPx(WIN_W / 2), 0, 12)
                        if resizeHandle then resizeHandle.Visible = false end
                        uiScale.Scale = 1
                elseif sheetMode and vp.X > 560 then
                        -- Leave sheet mode (hysteresis): back to floating size.
                        sheetMode = false
                        applyWindowSize(FLOAT_W, FLOAT_H)
                        if resizeHandle then resizeHandle.Visible = resizable end
                end
                -- [v5.5.0] Sheet-mode transitions and floating resizes both
                -- re-evaluate the sidebar's icon-rail mode.
                pcall(applySidebarMode)
                if sheetMode then
                        -- Track viewport while pinned; handle stays hidden.
                        applyWindowSize(vp.X - 16, vp.Y - 110)
                        uiScale.Scale = 1
                        if resizeHandle then resizeHandle.Visible = false end
                else
                        FLOAT_W, FLOAT_H = WIN_W, WIN_H -- manual resizes update the float size
                        local scaleX = (vp.X - 16) / math.max(WIN_W, 1)
                        local scaleY = (vp.Y - 120) / math.max(WIN_H, 1)
                        uiScale.Scale = math.clamp(math.min(scaleX, scaleY), 0.5, 1.0)
                        -- Re-clamp the window inside the (possibly new) bounds.
                        local pinned = frame.AbsolutePosition
                        if pinned and pinned.X + pinned.Y > 0 then
                                local x, y = clampWindowPosition(pinned.X, pinned.Y)
                                moveWindowTo(x, y)
                        end
                end
        end
        updateLayout()
        -- Defensive re-apply — camera viewport may not be fully settled yet
        -- on some clients.
        task.delay(0.3, updateLayout)

        -- [v5.0.0] Entrance plays only AFTER layout is resolved (sheet mode
        -- may have resized the window): the springs target the FINAL size.
        -- [v5.2.2] pcall the spawn so a buggy executor's task.spawn can
        -- never strand the window invisible. A 1s watchdog then FORCES the
        -- window to its resting state regardless of entrance success — the
        -- "UI doesn't show up" regression ends here.
        if not keyGatePending then
                pcall(function() task.spawn(runEntrance) end)
                task.delay(1, function()
                        pcall(function()
                                if not frame.Parent or not frame.Parent.Parent then return end
                                local w, h = WIN_W, WIN_H
                                frame.Size = UDim2.new(0, w, 0, h)
                                frame.Position = UDim2.new(0.5, -snapPx(w / 2), 0.5, -snapPx(h / 2))
                                applyShadowBox(w, h)
                                frame.BackgroundTransparency = 0
                                frameStroke.Transparency = 0.55
                                if shadow then
                                        shadow.Visible = true
                                        if shadowIsImage then
                                                shadow.ImageTransparency = SHADOW_REST - 0.15
                                        else
                                                shadow.BackgroundTransparency = SHADOW_REST
                                        end
                                end
                        end)
                end)
        end

        -- ------------------------------------------------------------
        -- POPUP MANAGER
        -- ------------------------------------------------------------
        local currentPopupJanitor = nil
        local function closeCurrentPopup()
                if currentPopupJanitor then
                        local jan = currentPopupJanitor
                        currentPopupJanitor = nil
                        -- [FIX v4.0] A popup closed mid-drag (second finger tapping
                        -- Done, catcher, toggle-keybind hiding the window) used to
                        -- leave the active drag session stranded: every mouse move
                        -- kept driving a destroyed pad/hue slider and kept firing
                        -- the live-color callback. Ending the drag BEFORE cleanup
                        -- guarantees the session can never outlive its popup.
                        finishDrag("popup-closed")
                        jan:Cleanup()
                end
        end
        WindowJanitor:Add(closeCurrentPopup)

        -- ------------------------------------------------------------
        -- ------------------------------------------------------------
        -- [v5.1.0] TACTILE SOUND MAPPING — the full Kinetic spec table.
        -- Opt-in via cfg.Sounds = true (or per-action overrides:
        -- { Volume = 0.4, Click = "rbxassetid://…", Tab = …, … }).
        -- ONE engine-local rbxasset:// ping, pitched per action — a coherent
        -- sound language with zero marketplace dependencies:
        --   open 1.0/0.40   close 0.9/0.30   tab 1.2/0.25
        --   toggleOn 1.15/0.30  toggleOff 0.85/0.30  click 1.0/0.35
        --   sliderStep 1.3/0.15  toast 1.0/0.40 (dual-tone)  confirm 1.3/0.30
        --   hum 0.55/0.12 (looped while a keybind listens for input)
        -- ------------------------------------------------------------
        do
                local scfg = cfg.Sounds == true and {} or cfg.Sounds
                if type(scfg) == "table" then
                        local masterVol = math.clamp(tonumber(scfg.Volume) or 1, 0, 1)
                        local baseId = "rbxasset://sounds/electronicpingshort.wav"
                        local SPEC = {
                                Open       = { pitch = 1.0,  vol = 0.40, id = scfg.Open or baseId },
                                Close      = { pitch = 0.9,  vol = 0.30, id = scfg.Close or baseId },
                                Tab        = { pitch = 1.2,  vol = 0.25, id = scfg.Tab or baseId },
                                ToggleOn   = { pitch = 1.15, vol = 0.30, id = scfg.Toggle or baseId },
                                ToggleOff  = { pitch = 0.85, vol = 0.30, id = scfg.Toggle or baseId },
                                Click      = { pitch = 1.0,  vol = 0.35, id = scfg.Click or baseId },
                                SliderStep = { pitch = 1.3,  vol = 0.15, id = scfg.SliderStep or baseId },
                                Toast      = { pitch = 1.0,  vol = 0.40, id = scfg.Notify or baseId },
                                Confirm    = { pitch = 1.3,  vol = 0.30, id = scfg.Confirm or baseId },
                                Hum        = { pitch = 0.55, vol = 0.12, id = scfg.Hum or baseId },
                        }
                        local function playOne(spec, pitchMul)
                                pcall(function()
                                        local s = Instance.new("Sound")
                                        s.SoundId = spec.id
                                        s.Volume = spec.vol * masterVol
                                        s.PlaybackSpeed = spec.pitch * (pitchMul or 1)
                                        s.Parent = SoundService
                                        SoundService:PlayLocalSound(s)
                                        task.delay(1.5, function()
                                                if s.Parent then s:Destroy() end
                                        end)
                                end)
                        end
                        playSfx = function(kind, pitchMul)
                                local spec = SPEC[kind]
                                if spec then playOne(spec, pitchMul) end
                        end
                        playSfxDual = function(kind)
                                local spec = SPEC[kind]
                                if not spec then return end
                                playOne(spec, 1)
                                task.delay(0.09, function() playOne(spec, 1.28) end)
                        end
                        stopHum = function()
                                if humSound and humSound.Parent then
                                        pcall(function() humSound:Destroy() end)
                                end
                                humSound = nil
                        end
                end
        end

        -- [v5.0.0] BACKDROP BLUR — opt-in via cfg.BackdropBlur = true.
        -- IMPORTANT, documented honestly: this is a Lighting.BlurEffect —
        -- it blurs the ENTIRE GAME WORLD, not this window. That is a global
        -- side effect, so it is off by default and REFERENCE-COUNTED at the
        -- library level: two blurred windows share one effect, and it is
        -- destroyed exactly when the last one goes away (regardless of
        -- which window destroys first).
        local backdropBlur = nil
        if cfg.BackdropBlur == true then
                local shared = Library._blurRefs
                if not shared then
                        shared = { instance = nil, refs = 0 }
                        Library._blurRefs = shared
                end
                shared.refs = shared.refs + 1
                if not shared.instance then
                        shared.instance = Instance.new("BlurEffect")
                        shared.instance.Name = "RezurXBackdropBlur"
                        shared.instance.Size = 0
                        shared.instance.Parent = Lighting
                end
                backdropBlur = shared.instance
                WindowJanitor:Add(function()
                        -- Release exactly one reference; teardown at zero.
                        shared.refs = shared.refs - 1
                        if shared.refs <= 0 and shared.instance then
                                if shared.instance.Parent then shared.instance:Destroy() end
                                shared.instance = nil
                                Library._blurRefs = nil
                        end
                end)
                task.delay(0.05, function()
                        if backdropBlur and backdropBlur.Parent and frame.Visible then
                                if reducedMotion then
                                        backdropBlur.Size = 14
                                else
                                        Tween(backdropBlur, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                                { Size = 14 })
                                end
                        end
                end)
        end

        -- ------------------------------------------------------------
        -- NOTIFICATIONS
        -- ------------------------------------------------------------
        local notifContainer = Instance.new("Frame")
        notifContainer.Size = UDim2.new(0, 300, 1, -20)
        notifContainer.Position = UDim2.new(1, -308, 0, 10)
        notifContainer.BackgroundTransparency = 1
        notifContainer.Active = false
        notifContainer.ZIndex = 6
        notifContainer.Parent = overlayGui
        local nLayout = Instance.new("UIListLayout")
        nLayout.Padding = UDim.new(0, 6)
        nLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        nLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        nLayout.Parent = notifContainer

        local function notify(title, body_, duration, ntype, actions)
                local NTYPES = {
                        info    = { icon = "ℹ", color = C.accent },
                        success = { icon = "✓", color = C.green },
                        warning = { icon = "⚠", color = C.yellow },
                        error   = { icon = "✕", color = C.red },
                }
                ntype = ntype or "info"
                -- [FIX v4.0] Coerce duration: a string or other truthy non-number
                -- (very common when configs come from deserialized JSON) used to
                -- make task.delay throw "invalid argument #1" straight into the
                -- caller of Window:Notify, and the toast was never created.
                -- [v5.4.0] READING-TIME DURATION (Luna/Rayfield pattern): when
                -- the caller does not specify a Duration, size it from the
                -- content length — a one-liner stays the 3s minimum, a
                -- paragraph stays long enough to actually read. Clamped to
                -- a sane 3–9s band; explicit Durations still win.
                local bodyLen = #tostring(body_ or "")
                duration = math.clamp(tonumber(duration)
                        or math.clamp(bodyLen * 0.06 + 3, 3, 9), 0.1, 3600)
                local ncfg = NTYPES[ntype] or NTYPES.info
                local col = ncfg.color
                local actionList = type(actions) == "table" and actions or {}
                local notificationHeight = #actionList > 0 and 98 or 68

                local n = Instance.new("Frame")
                n.Size = UDim2.new(1, 30, 0, 0)
                n.Position = UDim2.new(0, 30, 0, 0)
                n.BackgroundColor3 = C.panel
                n.BackgroundTransparency = 1
                n.ClipsDescendants = true
                n.Active = true
                n.ZIndex = 6
                n.Parent = notifContainer
                corner(n, R.panel)
                stroke(n, C.border, 1)

                local strip = Instance.new("Frame")
                strip.Size = UDim2.new(0, 3, 1, 0)
                strip.BackgroundColor3 = col
                strip.BorderSizePixel = 0
                strip.ZIndex = 6
                strip.Parent = n
                corner(strip, 2)

                local iconF = Instance.new("Frame")
                iconF.Size = UDim2.new(0, 26, 0, 26)
                iconF.Position = UDim2.new(0, 10, 0, 11)
                iconF.BackgroundColor3 = col
                iconF.BackgroundTransparency = 0.82
                iconF.BorderSizePixel = 0
                iconF.ZIndex = 6
                iconF.Parent = n
                corner(iconF, R.small)
                local iconLbl = Instance.new("TextLabel")
                iconLbl.Size = UDim2.new(1, 0, 1, 0)
                iconLbl.BackgroundTransparency = 1
                iconLbl.Font = Enum.Font.GothamBold
                iconLbl.TextSize = 13
                iconLbl.TextColor3 = col
                iconLbl.Text = ncfg.icon
                iconLbl.ZIndex = 6
                iconLbl.Parent = iconF

                local ttl = Instance.new("TextLabel")
                ttl.Size = UDim2.new(1, -50, 0, 17)
                ttl.Position = UDim2.new(0, 44, 0, 9)
                ttl.BackgroundTransparency = 1
                ttl.Font = Enum.Font.GothamBold
                ttl.TextSize = 13
                ttl.TextColor3 = col
                ttl.TextXAlignment = Enum.TextXAlignment.Left
                ttl.Text = title or ""
                ttl.ZIndex = 6
                ttl.Parent = n

                local cnt = Instance.new("TextLabel")
                cnt.Size = UDim2.new(1, -50, 0, 32)
                cnt.Position = UDim2.new(0, 44, 0, 27)
                cnt.BackgroundTransparency = 1
                cnt.Font = Enum.Font.Gotham
                cnt.TextSize = 12
                cnt.TextColor3 = C.textDim
                cnt.TextXAlignment = Enum.TextXAlignment.Left
                cnt.TextYAlignment = Enum.TextYAlignment.Top
                cnt.TextWrapped = true
                cnt.Text = body_ or ""
                cnt.ZIndex = 6
                cnt.Parent = n

                -- Actions turn a passive toast into a compact decision point.  They
                -- are deliberately capped at two so the notification never becomes
                -- a small modal or obscures the game.
                local dismissed = false
                local actionButtons = {}
                local function dismiss()
                        if dismissed then return end
                        dismissed = true
                        local t = Tween(n, T20, { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 })
                        if t then
                                t.Completed:Connect(function()
                                        if n and n.Parent then n:Destroy() end
                                end)
                        elseif n and n.Parent then
                                n:Destroy()
                        end
                end

                local actionCount = math.min(#actionList, 2)
                for index = 1, actionCount do
                        local action = actionList[index]
                        if type(action) == "table" then
                                local button = Instance.new("TextButton")
                                local width = actionCount == 1 and 104 or 86
                                local rightOffset = 10 + (actionCount - index) * (width + 6)
                                button.Size = UDim2.new(0, width, 0, 24)
                                button.Position = UDim2.new(1, -rightOffset - width, 1, -30)
                                button.BackgroundColor3 = index == 1 and col or C.panelAlt
                                button.BorderSizePixel = 0
                                button.AutoButtonColor = false
                                button.Text = tostring(action.Text or action.Name or "Action")
                                button.Font = Enum.Font.GothamBold
                                button.TextSize = 11
                                button.TextColor3 = index == 1 and C.white or C.text
                                button.ZIndex = 7
                                button.Parent = n
                                button.Selectable = true
                                corner(button, R.small)
                                stroke(button, index == 1 and col or C.border, 1)
                                table.insert(actionButtons, button)
                                button.Activated:Connect(function()
                                        if type(action.Callback) == "function" then
                                                task.spawn(function()
                                                        local ok, err = pcall(action.Callback, n, action)
                                                        if not ok then warn("[RezurXLib] Notification action failed:", err) end
                                                end)
                                        end
                                        if action.Dismiss ~= false then dismiss() end
                                end)
                        end
                end

                -- A toast can be dismissed by tapping its empty surface.  Action
                -- buttons are excluded so an action with Dismiss = false remains
                -- available after it runs.
                n.InputBegan:Connect(function(input)
                        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                        local pos = input.Position
                        for _, button in ipairs(actionButtons) do
                                local p, s = button.AbsolutePosition, button.AbsoluteSize
                                if pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y then return end
                        end
                        dismiss()
                end)

                local prog = Instance.new("Frame")
                prog.Size = UDim2.new(1, 0, 0, 2)
                prog.Position = UDim2.new(0, 0, 1, -2)
                prog.BackgroundColor3 = col
                prog.BackgroundTransparency = 0.45
                prog.BorderSizePixel = 0
                prog.ZIndex = 6
                prog.Parent = n

                Tween(n, T20, { BackgroundTransparency = 0.05 })
                playSfxDual("Toast") -- [v5.1.0] dual-tone notification chime
                -- [v4.1.0] Entrance: slide in from the right edge with a soft
                -- overshoot settle — reads as "arriving" rather than growing.
                Tween(n, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, 0, 0, notificationHeight),
                        Position = UDim2.new(0, 0, 0, 0),
                })
                -- [v5.4.0] HOVER DWELL PAUSE (Rayfield pattern): the dismiss
                -- countdown freezes while the pointer rests on the toast, so
                -- users can finish reading — or aim at an action button —
                -- before it slides away. The progress bar re-tweens from its
                -- current width on unhover (the Tween helper cancels the
                -- previous one per property), so bar and countdown stay in
                -- lockstep.
                local hovered = false
                n.MouseEnter:Connect(function() hovered = true end)
                n.MouseLeave:Connect(function() hovered = false end)
                task.spawn(function()
                        local remaining = duration
                        while remaining > 0 and n.Parent do
                                task.wait(0.2)
                                if n.Parent == nil then return end
                                if hovered then
                                        -- freeze: re-anchor the bar so it does not
                                        -- finish early while we hold the toast
                                        Tween(prog, TweenInfo.new(math.max(remaining, 0.05),
                                                Enum.EasingStyle.Linear),
                                                { Size = UDim2.new(0, 0, 0, 2) })
                                else
                                        remaining = remaining - 0.2
                                end
                        end
                        if n.Parent and not hovered then dismiss() end
                end)
                task.delay(0.25, function()
                        if not n.Parent or hovered then return end
                        Tween(prog, TweenInfo.new(duration, Enum.EasingStyle.Linear),
                                { Size = UDim2.new(0, 0, 0, 2) })
                end)
                return n
        end

        -- Table-form notification API: Window:Notify({Title, Content, Duration, Type})
        function Window:Notify(ncfg)
                ncfg = ncfg or {}
                return notify(ncfg.Title, ncfg.Content, ncfg.Duration, ncfg.Type, ncfg.Actions)
        end

        -- ------------------------------------------------------------
        -- ------------------------------------------------------------
        -- MINIMIZE LOGIC (moved here from right after minBtn's creation —
        -- it needs tabBar/content/statusBar, which don't exist that early)
        -- [FIX v4.0] `minimized` itself is forward-declared above the resize
        -- handler. Re-declaring it here would shadow that upvalue and
        -- reintroduce the resize/minimize desync bug.
        -- ------------------------------------------------------------
        local function setMinimized(nextValue)
                minimized = nextValue == true
                if minimized then
                        tabBar.Visible = false
                        content.Visible = false
                        statusBar.Visible = false
                        resizeHandle.Visible = false
                        -- [v4.4.0 FIX] The minimized window kept the glow strip,
                        -- header accent line, and footer mask visible — producing
                        -- a floating orange stripe and a panel-colored band
                        -- beneath the header instead of clean rounded corners.
                        -- (ClipsDescendants clips to the RECT, not the UICorner,
                        -- so full-width edge lines poke past the curve.)
                        glowStrip.Visible = false
                        footerMask.Visible = false
                        accentLine.Visible = false
                        Tween(frame, TMIN, { Size = UDim2.new(0, WIN_W, 0, HEADER_H) })
                        Tween(body, TMIN, { Size = UDim2.new(1, 0, 0, 0) })
                        Tween(shadow, TMIN, { Size = UDim2.new(0, WIN_W + SHADOW_PAD * 2, 0, HEADER_H + SHADOW_PAD * 2) })
                        Tween(minGlyph, T20, { Rotation = 180 })
                else
                        tabBar.Visible = true
                        content.Visible = true
                        statusBar.Visible = true
                        resizeHandle.Visible = resizable
                        glowStrip.Visible = true
                        footerMask.Visible = true
                        accentLine.Visible = true
                        -- recompute body height from current WIN_H (supports resize)
                        Tween(frame, TMIN, { Size = UDim2.new(0, WIN_W, 0, WIN_H) })
                        Tween(body, TMIN, { Size = UDim2.new(1, 0, 0, WIN_H - HEADER_H) })
                        Tween(shadow, TMIN, { Size = UDim2.new(0, WIN_W + SHADOW_PAD * 2, 0, WIN_H + SHADOW_PAD * 2) })
                        Tween(minGlyph, T20, { Rotation = 0 })
                end
                return minimized
        end
        minBtn.Activated:Connect(function()
                setMinimized(not minimized)
        end)

        -- ------------------------------------------------------------
        -- ------------------------------------------------------------
        -- HIDE / SHOW / MINIMIZE / TOGGLE KEYBIND
        -- ------------------------------------------------------------
        -- [FIX] closeBtn used to set frame/shadow/floatIcon visibility
        -- directly, completely bypassing `hidden`. That left `hidden` stuck
        -- at false after using the X button, so the toggle key silently did
        -- nothing on its first press afterward (setHidden(not false) just
        -- hid an already-hidden window), and a second press could bring back
        -- the main window while floatIcon stayed stuck on screen too — both
        -- visible at once. setHidden is now the single source of truth for
        -- all three entry points (X button, toggle key, floating icon tap).
        -- Defined below once their on-demand overlays are available. Declaring
        -- the upvalues here lets hiding the window clean every portal layer.
        local closeCommandPalette = function() end
        local closeModal = function() end
        -- [v4.2.0] Forward-declared: setHidden (defined before CreateTab)
        -- uses this to replay the card cascade when the window is revealed.
        -- Assigned its real implementation once ActiveTab exists below.
        local replayRevealCascade = function() end
        local hidden = false
        -- [v5.4.0] ONE-TIME HIDE-KEY HINT (Fluent/Maclib pattern): the first
        -- time the window is hidden, tell the user how to bring it back —
        -- exactly once per session, never again. Stored on the Window table
        -- (NOT a new local — CreateWindow sits at Luau's 200-local ceiling).
        Window._hideHintShown = false
        local function setHidden(h)
                hidden = h
                if h then
                        playSfx("Close") -- [v5.1.0] reverse soft snap (spec)
                        closeCurrentPopup()
                        closeCommandPalette()
                        closeModal()
                        if not Window._hideHintShown then
                                Window._hideHintShown = true
                                task.delay(0.5, function()
                                        if hidden and screenGui.Parent then
                                                notify("Interface",
                                                        "Press " .. keyName(toggleKey) .. " to toggle the interface.",
                                                        6, "info")
                                        end
                                end)
                        end
                        frame.Visible = false
                        setShadowVisible(false)
                        floatIcon.Visible = true
                        if backdropBlur and backdropBlur.Parent then
                                Tween(backdropBlur, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                        { Size = 0 })
                        end
                else
                        playSfx("Open") -- [v5.1.0] low sub-bass pop (spec)
                        floatIcon.Visible = false
                        frame.Visible = true
                        setShadowVisible(true)
                        if not minimized then
                                tabBar.Visible = true
                                content.Visible = true
                                statusBar.Visible = true
                        end
                        if backdropBlur and backdropBlur.Parent then
                                Tween(backdropBlur, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                        { Size = 14 })
                        end
                        -- [v5.0.0] REVEAL: the window returns with an Aurora
                        -- Trace lap and a fresh card cascade — no UIScale
                        -- (corner-rasterization law). Opening the menu is a
                        -- reward every time; the lap IS the arrival.
                        traceLap(C.accent, 1)
                        task.defer(replayRevealCascade)
                end
        end
        closeBtn.Activated:Connect(function()
                setHidden(true)
        end)
        floatIcon.Activated:Connect(function()
                if floatDragMoved then return end  -- [FIX] was a drag, not a tap
                setHidden(false)
        end)
        WindowJanitor:Add(UserInputService.InputBegan:Connect(function(inp, gp)
                if gp then return end
                if inp.KeyCode == toggleKey and not UserInputService:GetFocusedTextBox() then
                        setHidden(not hidden)
                end
        end))

        -- LOADING OVERLAY — contained inside `body` (never full-screen),
        -- pcall-wrapped, hard watchdog. Header stays live from frame one.
        -- ------------------------------------------------------------
        if loadingOn then
                local loadingOverlay = Instance.new("Frame")
                loadingOverlay.Name = "LoadingOverlay"
                loadingOverlay.Size = UDim2.new(1, 0, 1, 0)
                loadingOverlay.BackgroundColor3 = C.bg
                loadingOverlay.BorderSizePixel = 0
                loadingOverlay.ZIndex = 50
                loadingOverlay.Parent = body

                local loadWordmark = Instance.new("TextLabel")
                loadWordmark.Size = UDim2.new(1, 0, 0, 34)
                loadWordmark.AnchorPoint = Vector2.new(0.5, 0.5)
                loadWordmark.Position = UDim2.new(0.5, 0, 0.42, 0)
                loadWordmark.BackgroundTransparency = 1
                loadWordmark.Font = Enum.Font.GothamBlack
                loadWordmark.TextSize = 24
                loadWordmark.TextColor3 = C.accent
                loadWordmark.TextTransparency = 1
                loadWordmark.Text = loadingTitle
                loadWordmark.ZIndex = 51
                loadWordmark.Parent = loadingOverlay

                local loadBarBg = Instance.new("Frame")
                loadBarBg.Size = UDim2.new(0, 150, 0, 4)
                loadBarBg.AnchorPoint = Vector2.new(0.5, 0)
                loadBarBg.Position = UDim2.new(0.5, 0, 0.42, 24)
                loadBarBg.BackgroundColor3 = C.track
                loadBarBg.BackgroundTransparency = 1
                loadBarBg.BorderSizePixel = 0
                loadBarBg.ZIndex = 51
                loadBarBg.Parent = loadingOverlay
                corner(loadBarBg, UDim.new(1, 0))

                local loadBarFill = Instance.new("Frame")
                loadBarFill.Size = UDim2.new(0, 0, 1, 0)
                loadBarFill.BackgroundColor3 = C.accent
                loadBarFill.BackgroundTransparency = 1
                loadBarFill.BorderSizePixel = 0
                loadBarFill.ZIndex = 52
                loadBarFill.Parent = loadBarBg
                corner(loadBarFill, UDim.new(1, 0))
                gradient(loadBarFill, ColorSequence.new{
                        ColorSequenceKeypoint.new(0, C.accentDim),
                        ColorSequenceKeypoint.new(1, C.accentHi),
                })

                local cleared = false
                local function clearOverlay()
                        if cleared then return end
                        cleared = true
                        pcall(function()
                                if loadingOverlay and loadingOverlay.Parent then
                                        loadingOverlay:Destroy()
                                end
                        end)
                end
                task.delay(2.5, clearOverlay) -- hard watchdog
                task.spawn(function()
                        local ok, err = pcall(function()
                                -- [v4.2.0] Wordmark pops in (scale, not just fade) and
                                -- the whole sequence is tighter (~0.75s): anticipation
                                -- without dragging, so the reveal lands sooner.
                                local markScale = Instance.new("UIScale")
                                markScale.Scale = 1
                                markScale.Parent = loadWordmark
                                if not reducedMotion then
                                        markScale.Scale = 0.88
                                        Tween(markScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                                                { Scale = 1 })
                                end
                                Tween(loadWordmark, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                                        { TextTransparency = 0 })
                                Tween(loadBarBg, T20, { BackgroundTransparency = 0 })
                                Tween(loadBarFill, T20, { BackgroundTransparency = 0 })
                                task.wait(0.1)
                                Tween(loadBarFill, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                        { Size = UDim2.new(1, 0, 1, 0) })
                                task.wait(0.42)
                                Tween(loadWordmark, T15, { TextTransparency = 1 })
                                Tween(loadBarBg, T15, { BackgroundTransparency = 1 })
                                Tween(loadBarFill, T15, { BackgroundTransparency = 1 })
                                task.wait(0.08)
                                Tween(loadingOverlay, T20, { BackgroundTransparency = 1 })
                                task.wait(0.15)
                        end)
                        if not ok then
                                warn("[RezurXLib] loading overlay error: " .. tostring(err))
                        end
                        clearOverlay()
                end)
        end

        -- ------------------------------------------------------------
        -- THEME API
        -- ------------------------------------------------------------
        function Window:ModifyTheme(theme)
                closeCurrentPopup()
                local set = (type(theme) == "table") and theme or Themes[theme]
                if not set then
                        warn("[RezurXLib] Unknown theme: " .. tostring(theme))
                        return
                end
                for k, v in pairs(set) do
                        if ThemeTokenSet[k] and typeof(v) == "Color3" then
                                C[k] = v
                        elseif type(theme) == "table" then
                                warn("[RezurXLib] Ignoring invalid theme token: " .. tostring(k))
                        end
                end
                if type(theme) == "string" then activeThemeName = theme end
                -- [v5.5.1] Same secondary normalization as CreateWindow: a
                -- partial custom table merge must never leave the token nil.
                if typeof(C.secondary) ~= "Color3" then
                        C.secondary = C.accentHi
                end
                C.borderAcc = C.accent
                for _, fn in ipairs(ThemeRefreshers) do
                        pcall(fn)
                end
        end

        -- ============================================================
        -- CreateTab
        -- ============================================================
        replayRevealCascade = function()
                if ActiveTab and ActiveTab._setActive then
                        pcall(ActiveTab._setActive, true)
                end
        end
        local keyboardAdjusters = setmetatable({}, { __mode = "k" })

        -- Keyboard focus is opt-in per interactive control (Selectable = true)
        -- so invisible input overlays never become dead stops in the tab order.
        function Window:FocusNext(reverse)
                local root = ActiveTab and ActiveTab.Page or screenGui
                local candidates = {}
                for _, instance in ipairs(root:GetDescendants()) do
                        if instance:IsA("GuiButton") and instance.Visible and instance.Active and instance.Selectable then
                                table.insert(candidates, instance)
                        end
                end
                table.sort(candidates, function(a, b)
                        local ap, bp = a.AbsolutePosition, b.AbsolutePosition
                        if math.abs(ap.Y - bp.Y) > 4 then return ap.Y < bp.Y end
                        return ap.X < bp.X
                end)
                if #candidates == 0 then return nil end
                local selected = GuiService.SelectedObject
                local index = 0
                for candidateIndex, candidate in ipairs(candidates) do
                        if candidate == selected then index = candidateIndex break end
                end
                if reverse then
                        index = index <= 1 and #candidates or index - 1
                else
                        index = index >= #candidates and 1 or index + 1
                end
                GuiService.SelectedObject = candidates[index]
                return candidates[index]
        end

        local tabIndicatorSpring = nil
        moveIndicatorTo = function(btn, animated)
                local scale = math.max(uiScale.Scale, 0.01)
                local h = snapPx(btn.AbsoluteSize.Y / scale)
                -- [v5.5.0] VERTICAL rail: convert the visible Y coordinate
                -- back into the scrolling canvas coordinate so the edge bar
                -- stays beside a tab even after the vertical rail has been
                -- scrolled. X stays fixed: the bar always rides the rail's
                -- left edge strip.
                local relY = snapPx((btn.AbsolutePosition.Y - tabBar.AbsolutePosition.Y) / scale
                        + tabBar.CanvasPosition.Y)
                local goal = UDim2.new(0, 2, 0, relY)
                local goalSize = UDim2.new(0, 5, 0, h)
                if animated and not reducedMotion then
                        -- [v5.0.0] SPRING: the bar glides with momentum.
                        -- Flicking across tabs retargets mid-flight and the
                        -- velocity carries — interruptible by design.
                        tabIndicatorSpring = springTo(tabIndicatorSpring, tabIndicator, relY, {
                                stiffness = 320, damping = 26,
                                apply = function(v)
                                        tabIndicator.Position = UDim2.new(0, 2, 0, snapPx(v))
                                end,
                        })
                        Tween(tabIndicator, MT.move, { Size = goalSize })
                else
                        springCancel(tabIndicatorSpring, false)
                        tabIndicator.Position = goal
                        tabIndicator.Size = goalSize
                end
        end

        -- Shared across every Keybind element this window creates. Each
        -- Keybind previously tracked its own "am I listening for a rebind"
        -- flag only for itself — while Keybind A was mid-rebind, Keybind B's
        -- own InputBegan listener had no idea and would still fire its bound
        -- callback if the key you pressed to rebind A happened to match B's
        -- current binding. This flag lets every Keybind check "is ANY keybind
        -- currently listening" before firing its own callback.
        local anyKeybindListening = false

        function Window:CreateTab(name, icon)
                local tab = {}
                local tabName = tostring(name or "Tab")
                -- [v4.0] Tab icons accept three kinds of value, mirroring the
                -- window icon: number asset ids and rbxasset/rbxthumb URIs
                -- render as an ImageLabel; any other string stays emoji text.
                local tabIconUri = nil
                if type(icon) == "number" and icon ~= 0 then
                        tabIconUri = "rbxassetid://" .. icon
                elseif type(icon) == "string" and icon ~= "" then
                        local lower = string.lower(icon)
                        if string.sub(lower, 1, 13) == "rbxassetid://"
                                or string.sub(lower, 1, 11) == "rbxasset://"
                                or string.sub(lower, 1, 11) == "rbxthumb://" then
                                tabIconUri = icon
                        end
                end
                local iconText = (not tabIconUri) and (icon ~= nil and tostring(icon) or "") or ""

                local btn = Instance.new("TextButton")
                btn.Name = "TabChip"
                -- Each tab gets a dedicated title label: button input stays
                -- independent from text rendering and works consistently on touch.
                local btnText = iconText ~= "" and (iconText .. "  " .. tabName) or tabName
                -- [v5.5.0 MAGMA] Vertical sidebar pill: fixed full-rail width,
                -- 36px tall, fully rounded (Maclib row discipline × Rayfield
                -- pill). No text measurement — the rail owns the width and
                -- long titles truncate with an ellipsis like macOS sidebars.
                btn.Size = UDim2.new(1, -4, 0, 36)
                btn.BackgroundColor3 = C.tabChip
                btn.AutoButtonColor = false
                btn.BorderSizePixel = 0
                btn.Selectable = true
                btn.Text = ""
                btn.ZIndex = 4
                btn.Parent = tabRail
                corner(btn, PILL)
                local chipStroke = stroke(btn, C.borderAcc, 1)
                -- [v5.2.0 CRITICAL FIX — PRESERVED] No identity-multiplying
                -- gradient on the chip fill: the solid accent fill renders
                -- exactly, on every theme, every time. [v5.5.0] The lava
                -- signature lives on the EDGE BAR indicator (its own small
                -- gradient instance) — never multiplied through the chip.
                -- Render tab text in a dedicated label. This is deliberately
                -- separate from the button hit target so labels remain visible
                -- on every client renderer and never compete with input.
                local textLbl = Instance.new("TextLabel")
                textLbl.Name = "Title"
                textLbl.Size = UDim2.new(1, -20, 1, 0)
                textLbl.Position = UDim2.fromOffset(10, 0)
                textLbl.BackgroundTransparency = 1
                -- [v5.2.0] ZIndex GUARANTEE: text and icons always render above
                -- the chip fill and any indicator — the active highlight can
                -- never cover them (the blank-active-tab bug).
                textLbl.ZIndex = 7
                textLbl.Active = false
                textLbl.Font = Enum.Font.GothamMedium
                textLbl.TextSize = 12
                textLbl.TextColor3 = C.text
                textLbl.TextXAlignment = Enum.TextXAlignment.Left
                textLbl.TextStrokeTransparency = 0.5
                textLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
                textLbl.TextTruncate = Enum.TextTruncate.AtEnd
                textLbl.Text = btnText
                textLbl.Parent = btn
                -- [v4.0] Asset tab icon: an 18px image sits left of the title
                -- (Rayfield-style), and the title label shifts right to fit.
                local tabIconImg = nil
                if tabIconUri then
                        tabIconImg = Instance.new("ImageLabel")
                        tabIconImg.Name = "TabIcon"
                        tabIconImg.Size = UDim2.fromOffset(18, 18)
                        tabIconImg.Position = UDim2.new(0, 11, 0.5, -9)
                        tabIconImg.BackgroundTransparency = 1
                        tabIconImg.Image = tabIconUri
                        tabIconImg.ZIndex = 7 -- [v5.2.0] above the chip fill, always
                        tabIconImg.Parent = btn
                        textLbl.Position = UDim2.fromOffset(38, 0)
                        textLbl.Size = UDim2.new(1, -44, 1, 0)
                end

                -- Page wrapper (a plain Frame, not CanvasGroup — CanvasGroup is
                -- not universally supported across executors and can render
                -- content invisible on some clients).
                local pageGroup = Instance.new("Frame")
                pageGroup.Name = "PageGroup"
                pageGroup.Size = UDim2.new(1, 0, 1, 0)
                pageGroup.BackgroundTransparency = 1
                pageGroup.Visible = false
                pageGroup.Parent = content
                local page = Instance.new("ScrollingFrame")
                page.Size = UDim2.new(1, 0, 1, 0)
                page.BackgroundTransparency = 1
                page.BorderSizePixel = 0
                page.ScrollBarThickness = 3
                page.ScrollBarImageColor3 = C.accent
                page.ScrollBarImageTransparency = 0.40
                page.CanvasSize = UDim2.new(0, 0, 0, 0)
                page.Parent = pageGroup

                local pLayout = Instance.new("UIListLayout")
                pLayout.Padding = UDim.new(0, D.pageGap) -- [v5.0.0] density token
                pLayout.SortOrder = Enum.SortOrder.LayoutOrder
                pLayout.Parent = page
                pad(page, D.pagePad, D.pagePad, D.pagePad - 1, D.pagePad) -- [v5.0.0] density token
                pLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                        page.CanvasSize = UDim2.new(0, 0, 0, pLayout.AbsoluteContentSize.Y + 20)
                end)

                tab.Page = page
                tab._pageGroup = pageGroup
                tab.Btn = btn
                tab.Name = tabName

                -- Update the rendered title and chip width together. Public setters
                -- make late localisation and live workspace names safe without
                -- sacrificing the measured, horizontally-scrollable tab rail.
                local function applyTabTitle()
                        btnText = iconText ~= "" and (iconText .. "  " .. tabName) or tabName
                        -- [v5.5.0] The rail owns the chip width — retitling is a
                        -- pure text swap (long titles ellipsize). Only the edge
                        -- bar needs a re-snap if the active tab relabels.
                        tab._fullLabel = btnText
                        tab._iconText = iconText
                        if not sidebarIconMode then
                                textLbl.Text = btnText
                        elseif iconText ~= "" then
                                textLbl.Text = iconText
                        end
                        task.defer(function()
                                if ActiveTab == tab and btn.Parent then
                                        moveIndicatorTo(btn, false)
                                end
                        end)
                end

                --- Change this tab's visible text and preserve its active state.
                --- @param nextTitle any Display value; converted safely to text.
                --- @return string The applied tab title.
                function tab:SetTitle(nextTitle)
                        tabName = tostring(nextTitle or "Tab")
                        tab.Name = tabName
                        applyTabTitle()
                        return tabName
                end

                --- Change this tab's optional leading icon.
                --- @param nextIcon any|nil Icon text, or nil to remove it.
                --- @return string The applied icon text.
                function tab:SetIcon(nextIcon)
                        iconText = nextIcon ~= nil and tostring(nextIcon) or ""
                        applyTabTitle()
                        return iconText
                end

                        -- [FIX] updateBtnSize removed — btn uses AutomaticSize.X now
                        -- Just move the indicator to the btn's current position on load
                        task.defer(function()
                                if ActiveTab == tab then
                                        moveIndicatorTo(btn, false)
                                end
                end)

                local function setActive(skipAnim)
                        closeCurrentPopup()
                        local prevIndex = nil
                        if ActiveTab and ActiveTab ~= tab then
                                local prev = ActiveTab
                                for i, t in ipairs(Tabs) do
                                        if t == prev then prevIndex = i end
                                end
                                prev.Page.Visible = false
                                if prev._pageGroup then prev._pageGroup.Visible = false end
                                prev.Btn.BackgroundTransparency = 0
                                Tween(prev.Btn, T20, { BackgroundColor3 = C.tabChip })
                                Tween(prev._chipStroke, T20, { Color = C.borderAcc, Transparency = 0 })
                                Tween(prev._textLbl, T20, { TextColor3 = C.text })
                                prev._textLbl.Font = Enum.Font.GothamMedium
                        end
                        ActiveTab = tab
                        tab.Page.Visible = true
                        pageGroup.Visible = true
                        -- Panel transition: the incoming page slides in horizontally
                        -- (+8px) on the move curve. (No CanvasGroup — executors
                        -- vary; the slide alone reads as a clean arrival.)
                        if not skipAnim and not reducedMotion then
                                page.Position = UDim2.new(0, 0, 0, 8)
                                Tween(page, MT.move, { Position = UDim2.new(0, 0, 0, 0) })
                        else
                                page.Position = UDim2.new(0, 0, 0, 0)
                        end
                        -- [v4.3.0] ACTIVE TAB = ACCENT FILL: the selected tab is a
                        -- solid accent chip with white bold text — unmistakable,
                        -- exactly as requested. Inactive tabs stay quiet chips.
                        Tween(btn, T20, { BackgroundColor3 = C.accent })
                        Tween(chipStroke, T20, { Color = C.accentHi, Transparency = 0.15 })
                        -- [v5.2.0] EXPLICIT pure white — the active label must be
                        -- readable on ANY accent fill, independent of the theme's
                        -- `white` token (a bad custom theme can no longer blank it).
                        Tween(textLbl, T20, { TextColor3 = Color3.new(1, 1, 1) })
                        textLbl.Font = Enum.Font.GothamBold
                        moveIndicatorTo(btn, not skipAnim)
                        -- [v5.0.0] TRACE: quarter lap toward the new tab — the
                        -- light sweeps the border in the direction of travel.
                        if prevIndex ~= nil then
                                local myIndex = 1
                                for i, t in ipairs(Tabs) do
                                        if t == tab then myIndex = i end
                                end
                                local dir = (myIndex >= prevIndex) and 1 or -1
                                traceLap(C.accent, 0.25 * dir)
                        end
                        -- CARD CASCADE (v5.0.0): the page rises 12px into place
                        -- while each card's stroke flashes accent on a stagger —
                        -- a reward cascade with ZERO UIScale (scaling rounded
                        -- frames re-rasterizes corners every frame). The
                        -- UIListLayout keeps owning positions throughout.
                        -- Capped so giant pages don't drag.
                        if not reducedMotion then
                                local cards = {}
                                for _, child in ipairs(page:GetChildren()) do
                                        if child:IsA("GuiObject") and not child:IsA("UIGridStyleLayout") then
                                                if child:IsA("Frame") or child:IsA("TextButton") then
                                                        table.insert(cards, child)
                                                end
                                        end
                                end
                                page.Position = UDim2.new(0, 0, 0, 12)
                                Tween(page, MT.settle, { Position = UDim2.new(0, 0, 0, 0) })
                                for index = 1, math.min(#cards, 16) do
                                        local card = cards[index]
                                        task.delay((index - 1) * 0.026, function()
                                                if not card.Parent or not tab.Page.Visible then return end
                                                local cardStroke = card:FindFirstChildOfClass("UIStroke")
                                                if cardStroke then
                                                        local origColor = cardStroke.Color
                                                        cardStroke.Color = C.accentDim
                                                        Tween(cardStroke, MT.settle, { Color = origColor })
                                                end
                                        end)
                                end
                        end
                        -- Let Roblox settle the horizontal layout once, then
                        -- snap the indicator to the final measured label width.
                        task.defer(function()
                                if ActiveTab == tab and btn.Parent then
                                        moveIndicatorTo(btn, false)
                                end
                        end)
                end
                tab._chipStroke = chipStroke
                tab._textLbl = textLbl
                tab._tabIconImg = tabIconImg
                tab._fullLabel = btnText
                tab._iconText = iconText
                tab._setActive = setActive

                onTheme(function()
                        page.ScrollBarImageColor3 = C.accent
                        if ActiveTab == tab then
                                Tween(btn, T20, { BackgroundColor3 = C.accent })
                                Tween(chipStroke, T20, { Color = C.accentHi, Transparency = 0.15 })
                                Tween(textLbl, T20, { TextColor3 = Color3.new(1, 1, 1) })
                        else
                                Tween(btn, T20, { BackgroundColor3 = C.tabChip })
                                Tween(chipStroke, T20, { Color = C.borderAcc, Transparency = 0 })
                                Tween(textLbl, T20, { TextColor3 = C.text })
                        end
                end)

                btn.MouseEnter:Connect(function()
                        if ActiveTab ~= tab then
                                Tween(btn, T10, { BackgroundColor3 = C.tabChipHov })
                                Tween(chipStroke, T10, { Color = C.accentDim })
                                Tween(textLbl, T10, { TextColor3 = C.text })
                        end
                end)
                btn.MouseLeave:Connect(function()
                        if ActiveTab ~= tab then
                                Tween(btn, T10, { BackgroundColor3 = C.tabChip })
                                Tween(chipStroke, T10, { Color = C.borderAcc })
                                Tween(textLbl, T10, { TextColor3 = C.text })
                        end
                end)
                btn.Activated:Connect(function()
                        playSfx("Tab")
                        ripple(btn, btn.AbsoluteSize.X / 2, btn.AbsoluteSize.Y / 2, C.accent)
                        setActive(false)
                end)

                table.insert(Tabs, tab)
                -- [v5.5.0] If the rail was already collapsed (narrow window
                -- resolved its layout before this tab existed), restyle this
                -- chip to icon mode immediately — must run AFTER the Tabs
                -- insert above so the refresher can see this tab.
                if sidebarIconMode then refreshTabChipModes() end
                if #Tabs == 1 then
                        task.defer(function() setActive(true) end)
                end

                -- ========================================================
                -- SHARED ELEMENT SCAFFOLD — panel holder with themed stroke
                -- ========================================================
                local function makeHolder(h)
                        local holder = Instance.new("Frame")
                        holder.Size = UDim2.new(1, 0, 0, h)
                        holder.BackgroundColor3 = C.panel
                        holder.BorderSizePixel = 0
                        holder.Parent = page
                        corner(holder, R.panel)
                        local strk = stroke(holder, C.border, 1)
                        -- A restrained two-stop surface gradient gives cards
                        -- depth without relying on noisy textures or shadows.
                        local surfaceGradient = gradient(holder, ColorSequence.new({
                                ColorSequenceKeypoint.new(0, C.panelAlt),
                                ColorSequenceKeypoint.new(1, C.panel),
                        }), 90)
                        onTheme(function()
                                surfaceGradient.Color = ColorSequence.new({
                                        ColorSequenceKeypoint.new(0, C.panelAlt),
                                        ColorSequenceKeypoint.new(1, C.panel),
                                })
                        end)
                        -- [FIX v4.0] A tooltip showing on an element that gets
                        -- destroyed used to float ownerless until the next hover
                        -- somewhere else. Destroying is the reliable last beat.
                        holder.Destroying:Connect(hideTooltip)
                        return holder, strk
                end

                local function registerFlag(flag, obj)
                        if not flag then return end
                        Library.Flags[flag] = obj
                        -- [v4.0] Also register per-window for ConfigurationSaving.
                        Window.Flags[flag] = obj
                        -- [FIX v4.0] Auto-deregister the flag when the element is
                        -- destroyed. Destroyed elements used to keep reporting
                        -- stale values through Library.Flags — GetFlag kept
                        -- returning them and SaveConfiguration serialized dead
                        -- state. Also hides any tooltip the element was showing.
                        if type(obj) == "table" and type(obj.Destroy) == "function" then
                                local origDestroy = obj.Destroy
                                local destroyed = false
                                obj.Destroy = function(self, ...)
                                        if not destroyed then
                                                destroyed = true
                                                if Library.Flags[flag] == obj then
                                                        Library.Flags[flag] = nil
                                                end
                                                if Window.Flags[flag] == obj then
                                                        Window.Flags[flag] = nil
                                                end
                                                hideTooltip()
                                        end
                                        return origDestroy(self, ...)
                                end
                        end
                end

                -- ========================================================
                -- [v4.0] ELEMENT ICONS — Rayfield-style asset support.
                -- number          -> "rbxassetid://<n>"
                -- "rbxassetid://…", "rbxasset://…", "rbxthumb://…" -> passthrough
                -- any other string -> treated as emoji/text (no ImageLabel)
                -- ========================================================
                local function iconAssetUri(value)
                        if value == nil or value == 0 or value == "" then return nil end
                        if type(value) == "number" then
                                return "rbxassetid://" .. value
                        elseif type(value) == "string" then
                                local lower = string.lower(value)
                                if string.sub(lower, 1, 13) == "rbxassetid://"
                                        or string.sub(lower, 1, 11) == "rbxasset://"
                                        or string.sub(lower, 1, 11) == "rbxthumb://" then
                                        return value
                                end
                        end
                        return nil
                end

                -- Renders an icon ImageLabel at the left of an element and shifts
                -- the element's text label right to make room. Returns the
                -- ImageLabel (or nil when the value was emoji/text/absent).
                local function applyElementIcon(container, iconValue, label)
                        local uri = iconAssetUri(iconValue)
                        if not uri or not container then return nil end
                        local iconInset = 14
                        local img = Instance.new("ImageLabel")
                        img.Name = "ElementIcon"
                        img.Size = UDim2.fromOffset(18, 18)
                        img.AnchorPoint = Vector2.new(0, 0.5)
                        img.Position = UDim2.new(0, iconInset, 0.5, 0)
                        img.BackgroundTransparency = 1
                        img.Image = uri
                        img.ZIndex = 3
                        img.Parent = container
                        if label then
                                local pos = label.Position
                                label.Position = UDim2.new(0, iconInset + 26, pos.Y.Scale, pos.Y.Offset)
                                local size = label.Size
                                if size.X.Scale >= 1 then
                                        label.Size = UDim2.new(1, size.X.Offset - 26, size.Y.Scale, size.Y.Offset)
                                end
                        end
                        return img
                end

                local function applyTooltip(instance, text)
                        if not text or text == "" then return end
                        instance.MouseEnter:Connect(function()
                                showTooltip(text, instance, overlayGui, C)
                        end)
                        instance.MouseLeave:Connect(function()
                                hideTooltip()
                        end)
                        -- Touch does not expose hover. A short, non-blocking
                        -- hint on first press keeps tooltips useful on mobile
                        -- without turning them into modal popups.
                        instance.InputBegan:Connect(function(input)
                                if input.UserInputType ~= Enum.UserInputType.Touch then return end
                                showTooltip(text, instance, overlayGui, C)
                                task.delay(1.6, function()
                                        if tooltipFrame and tooltipFrame.Parent then hideTooltip() end
                                end)
                        end)
                end

                -- ========================================================
                -- CreateSection / CreateDivider / CreateLabel / CreateParagraph
                -- ========================================================
                function tab:CreateSection(text)
                        -- [v4.3.0/v4.4.0] Section headers: accent tick + title +
                        -- gradient rule. Built with a horizontal UIListLayout so
                        -- the gap between the text and the rule is IDENTICAL for
                        -- every section regardless of title length (the old
                        -- right-anchored rule started at varying distances —
                        -- "ENGINE" hugged the text, "PROFILES" didn't).
                        local holder = Instance.new("Frame")
                        holder.Size = UDim2.new(1, 0, 0, 18)
                        holder.BackgroundTransparency = 1
                        holder.Parent = page

                        local layout = Instance.new("UIListLayout")
                        layout.FillDirection = Enum.FillDirection.Horizontal
                        layout.SortOrder = Enum.SortOrder.LayoutOrder
                        layout.Padding = UDim.new(0, 8)
                        layout.VerticalAlignment = Enum.VerticalAlignment.Center
                        layout.Parent = holder

                        local tick = Instance.new("Frame")
                        tick.Name = "SectionTick"
                        tick.LayoutOrder = 0
                        tick.AnchorPoint = Vector2.new(0, 0.5)
                        tick.Position = UDim2.new(0, 2, 0.5, -5)
                        tick.Size = UDim2.fromOffset(3, 10)
                        tick.BackgroundColor3 = C.accent
                        tick.BorderSizePixel = 0
                        tick.ZIndex = 2
                        tick.Parent = holder
                        corner(tick, UDim.new(1, 0))
                        -- [v4.4.0] Living tick: the gradient offset slides
                        -- top-to-bottom in a slow loop when AnimatedAccents is on.
                        local tickGrad = Instance.new("UIGradient")
                        tickGrad.Rotation = 90
                        tickGrad.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(0.0, C.accentHi),
                                ColorSequenceKeypoint.new(1.0, C.accentDim),
                        }
                        tickGrad.Parent = tick
                        local l = Instance.new("TextLabel")
                        l.Name = "SectionTitle"
                        l.LayoutOrder = 1
                        l.AutomaticSize = Enum.AutomaticSize.X
                        l.Size = UDim2.new(0, 0, 1, 0)
                        l.BackgroundTransparency = 1
                        l.Font = Enum.Font.GothamBold
                        l.TextSize = 10
                        l.TextColor3 = C.accent
                        l.TextXAlignment = Enum.TextXAlignment.Left
                        l.Text = string.upper(tostring(text or ""))
                        l.ZIndex = 2
                        l.Parent = holder

                        local rule = Instance.new("Frame")
                        rule.Name = "SectionRule"
                        rule.LayoutOrder = 2
                        rule.Size = UDim2.new(1, 0, 0, 1)
                        rule.BackgroundColor3 = C.accent
                        rule.BackgroundTransparency = 0.45
                        rule.BorderSizePixel = 0
                        rule.ZIndex = 2
                        rule.Parent = holder
                        local ruleGrad = Instance.new("UIGradient")
                        ruleGrad.Rotation = 0
                        ruleGrad.Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0.0, 0.15),
                                NumberSequenceKeypoint.new(1.0, 1.0),
                        })
                        ruleGrad.Parent = rule

                        onTheme(function()
                                tick.BackgroundColor3 = C.accent
                                tickGrad.Color = ColorSequence.new{
                                        ColorSequenceKeypoint.new(0.0, C.accentHi),
                                        ColorSequenceKeypoint.new(1.0, C.accentDim),
                                }
                                Tween(l, T20, { TextColor3 = C.accent })
                                rule.BackgroundColor3 = C.accent
                        end)
                        local obj = {}
                        function obj:Set(newText) l.Text = string.upper(tostring(newText or "")) end
                        return obj
                end

                function tab:CreateDivider(text)
                        local holder = Instance.new("Frame")
                        holder.Size = UDim2.new(1, 0, 0, 20)
                        holder.BackgroundTransparency = 1
                        holder.Parent = page
                        if text and text ~= "" then
                                local lbl = Instance.new("TextLabel")
                                lbl.Size = UDim2.new(1, 0, 1, 0)
                                lbl.BackgroundTransparency = 1
                                lbl.Font = Enum.Font.GothamBold
                                lbl.TextSize = 10
                                lbl.TextColor3 = C.muted
                                lbl.TextXAlignment = Enum.TextXAlignment.Left
                                lbl.Text = "── " .. string.upper(tostring(text))
                                lbl.Parent = holder
                                onTheme(function() Tween(lbl, T20, { TextColor3 = C.muted }) end)
                        else
                                local line = Instance.new("Frame")
                                line.Size = UDim2.new(1, 0, 0, 1)
                                line.Position = UDim2.new(0, 0, 0.5, 0)
                                line.BackgroundColor3 = C.border
                                line.BorderSizePixel = 0
                                line.Parent = holder
                                onTheme(function() Tween(line, T20, { BackgroundColor3 = C.border }) end)
                        end
                        return holder
                end

                function tab:CreateSpacer(px)
                        local f = Instance.new("Frame")
                        f.Name = "Spacer"
                        f.Size = UDim2.new(1, 0, 0, px or 6)
                        f.BackgroundTransparency = 1
                        f.Parent = page
                        return f
                end

                function tab:CreateLabel(textOrConfig)
                        local lcfg = type(textOrConfig) == "table" and textOrConfig or { Text = textOrConfig }
                        local customColor = typeof(lcfg.Color) == "Color3"
                        local function resolveAlignment(value)
                                if typeof(value) == "EnumItem" and value.EnumType == Enum.TextXAlignment then
                                        return value
                                end
                                if type(value) == "string" then
                                        return Enum.TextXAlignment[string.upper(value)]
                                                or Enum.TextXAlignment.Left
                                end
                                return Enum.TextXAlignment.Left
                        end
                        local holder, strk = makeHolder(34)
                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, -28, 1, 0)
                        lbl.Position = UDim2.new(0, 14, 0, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = (typeof(lcfg.Font) == "EnumItem" and lcfg.Font.EnumType == Enum.Font)
                                and lcfg.Font or (lcfg.Bold == true and Enum.Font.GothamBold or Enum.Font.GothamMedium)
                        lbl.TextSize = math.clamp(tonumber(lcfg.TextSize) or 13, 8, 36)
                        lbl.TextColor3 = customColor and lcfg.Color or C.textDim
                        lbl.TextXAlignment = resolveAlignment(lcfg.Align)
                        lbl.TextTruncate = Enum.TextTruncate.AtEnd
                        lbl.Text = tostring(lcfg.Text or lcfg.Name or "")
                        lbl.Parent = holder
                        onTheme(function()
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(strk, T20, { Color = C.border })
                                if not customColor then Tween(lbl, T20, { TextColor3 = C.textDim }) end
                        end)
                        local obj = {}
                        function obj:Set(newText) lbl.Text = tostring(newText or "") end
                        function obj:SetColor(newColor)
                                if typeof(newColor) ~= "Color3" then return nil end
                                customColor = true
                                Tween(lbl, T20, { TextColor3 = newColor })
                                return newColor
                        end
                        function obj:Get() return lbl.Text end
                        return obj
                end

                function tab:CreateParagraph(pcfg)
                        pcfg = pcfg or {}
                        local holder = Instance.new("Frame")
                        holder.Size = UDim2.new(1, 0, 0, 0)
                        holder.BackgroundColor3 = C.panelAlt
                        holder.BorderSizePixel = 0
                        holder.AutomaticSize = Enum.AutomaticSize.Y
                        holder.Parent = page
                        corner(holder, R.panel)
                        local strk = stroke(holder, C.border, 1)

                        local ttl = Instance.new("TextLabel")
                        ttl.Size = UDim2.new(1, -20, 0, 16)
                        ttl.Position = UDim2.new(0, 10, 0, 8)
                        ttl.BackgroundTransparency = 1
                        ttl.Font = Enum.Font.GothamBold
                        ttl.TextSize = 10
                        ttl.TextColor3 = C.accent
                        ttl.TextXAlignment = Enum.TextXAlignment.Left
                        ttl.Text = string.upper(pcfg.Title or "")
                        ttl.Parent = holder

                        local cnt = Instance.new("TextLabel")
                        cnt.Size = UDim2.new(1, -20, 0, 0)
                        cnt.Position = UDim2.new(0, 10, 0, 26)
                        cnt.BackgroundTransparency = 1
                        cnt.Font = Enum.Font.Code
                        cnt.TextSize = 12
                        cnt.TextColor3 = C.textDim
                        cnt.TextXAlignment = Enum.TextXAlignment.Left
                        cnt.TextYAlignment = Enum.TextYAlignment.Top
                        cnt.TextWrapped = true
                        cnt.AutomaticSize = Enum.AutomaticSize.Y
                        cnt.Text = pcfg.Content or ""
                        cnt.Parent = holder
                        pad(holder, 0, 10, 0, 0)

                        onTheme(function()
                                Tween(holder, T20, { BackgroundColor3 = C.panelAlt })
                                Tween(strk, T20, { Color = C.border })
                                Tween(ttl, T20, { TextColor3 = C.accent })
                                Tween(cnt, T20, { TextColor3 = C.textDim })
                        end)
                        local obj = {}
                        function obj:Set(ncfg)
                                if ncfg.Title then ttl.Text = string.upper(ncfg.Title) end
                                if ncfg.Content then cnt.Text = ncfg.Content end
                        end
                        return obj
                end

                -- ========================================================
                -- CreateButton({ Name, Variant = "Primary" | "Secondary",
                --                Tooltip, Callback })
                -- ========================================================
                function tab:CreateImage(icfg)
                        icfg = icfg or {}
                        local holder, strk = makeHolder(icfg.Height or 120)
                        local img = Instance.new("ImageLabel")
                        img.Name = "Image"
                        img.Size = UDim2.new(1, 0, 1, 0)
                        img.BackgroundTransparency = 1
                        img.Image = Library:ResolveImage(icfg.Image or "")
                        img.ScaleType = icfg.ScaleType or Enum.ScaleType.Stretch
                        img.Parent = holder
                        corner(img, R.panel)
                        if icfg.CornerRadius then corner(img, icfg.CornerRadius) end
                        onTheme(function()
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(strk, T20, { Color = C.border })
                        end)
                        applyTooltip(holder, icfg.Tooltip)
                        local obj = {}
                        function obj:Set(imageId) img.Image = Library:ResolveImage(imageId) end
                        return obj
                end

                function tab:CreateButton(bcfg)
                        bcfg = bcfg or {}
                        local nameText = bcfg.Name or "Button"
                        local callback = bcfg.Callback
                        local variant = string.lower(tostring(bcfg.Variant or "Secondary"))
                        local primary = variant == "primary" or variant == "accent"

                        local b = Instance.new("TextButton")
                        b.Size = UDim2.new(1, 0, 0, D.row) -- [v5.0.0] >=44px touch target
                        b.BackgroundColor3 = primary and C.accentDark or C.panel
                        b.Text = ""
                        b.AutoButtonColor = false
                        b.BorderSizePixel = 0
                        -- [v4.4.0] ClipsDescendants moved OFF the button and ONTO a
                        -- dedicated ripple mask: the outer glow halo must be able
                        -- to render beyond the button's rect (cards that pop off
                        -- the background), while ripples still clip cleanly.
                        b.Selectable = true
                        b.Parent = page
                        corner(b, R.panel)
                        local strk = stroke(b, primary and C.accentDim or C.border, 1)
                        local buttonGradient = nil
                        if primary then
                                buttonGradient = gradient(b, ColorSequence.new{
                                        ColorSequenceKeypoint.new(0.0, C.accentDim),
                                        ColorSequenceKeypoint.new(1.0, C.accentDark),
                                }, 100)
                        end
                        -- (Secondary buttons stay SOLID panel: the accent spine,
                        -- hover raise, and arrow slide carry the flavor — and a
                        -- solid fill renders exactly as themed, no gradient
                        -- multiplication surprises.)

                        -- [v4.4.0] Ripple mask: owns clipping so ripples respect
                        -- the rounded rect.
                        local rippleMask = Instance.new("Frame")
                        rippleMask.Name = "RippleMask"
                        rippleMask.Size = UDim2.new(1, 0, 1, 0)
                        rippleMask.BackgroundTransparency = 1
                        rippleMask.BorderSizePixel = 0
                        rippleMask.ClipsDescendants = true
                        rippleMask.ZIndex = 4
                        rippleMask.Parent = b
                        corner(rippleMask, R.panel)

                        -- [v5.1.0] SHEEN SWEEP (spec): a 20° diagonal light
                        -- reflection fires across the card face on press.
                        -- One-shot press feedback (not idle decoration), clipped
                        -- by the ripple mask so it respects the rounded rect.
                        local sheen = Instance.new("Frame")
                        sheen.Name = "PressSheen"
                        sheen.Size = UDim2.new(0, 46, 1.8, 0)
                        sheen.AnchorPoint = Vector2.new(0.5, 0.5)
                        sheen.Position = UDim2.new(-0.35, 0, 0.5, 0)
                        sheen.Rotation = 20
                        sheen.BackgroundColor3 = C.white
                        sheen.BackgroundTransparency = 0.62
                        sheen.BorderSizePixel = 0
                        sheen.ZIndex = 5
                        sheen.Parent = rippleMask
                        corner(sheen, PILL)
                        local sheenGrad = Instance.new("UIGradient")
                        sheenGrad.Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0.0, 1.0),
                                NumberSequenceKeypoint.new(0.5, 0.06),
                                NumberSequenceKeypoint.new(1.0, 1.0),
                        })
                        sheenGrad.Parent = sheen
                        local sheenBusy = false
                        local function fireSheen()
                                if sheenBusy or reducedMotion or not sheen.Parent then return end
                                sheenBusy = true
                                sheen.Position = UDim2.new(-0.35, 0, 0.5, 0)
                                Tween(sheen, TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                                        { Position = UDim2.new(1.3, 0, 0.5, 0) })
                                task.delay(0.5, function() sheenBusy = false end)
                        end

                        -- [v4.4.0] SIGNATURE SPINE with LIVING GRADIENT: the spine
                        -- now carries a vertical accentHi→accentDim gradient; on
                        -- hover a one-shot highlight sweeps top-to-bottom through
                        -- it (UIGradient.Offset) — a glowing indicator, as asked.
                        local spine = Instance.new("Frame")
                        spine.Name = "AccentSpine"
                        spine.AnchorPoint = Vector2.new(0, 0.5)
                        spine.Position = UDim2.new(0, 5, 0.5, -10)
                        spine.Size = UDim2.fromOffset(3, 20)
                        spine.BackgroundColor3 = primary and C.accentHi or C.accentDim
                        spine.BorderSizePixel = 0
                        spine.ZIndex = 3
                        spine.Parent = b
                        corner(spine, UDim.new(1, 0))
                        local spineGrad = Instance.new("UIGradient")
                        spineGrad.Rotation = 90
                        spineGrad.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(0.0, C.accentHi),
                                ColorSequenceKeypoint.new(1.0, C.accentDim),
                        }
                        spineGrad.Parent = spine
                        onTheme(function()
                                spineGrad.Color = ColorSequence.new{
                                        ColorSequenceKeypoint.new(0.0, C.accentHi),
                                        ColorSequenceKeypoint.new(1.0, C.accentDim),
                                }
                        end)
                        -- [v4.1.0/v4.3.0] Press + hover scale: declared before the
                        -- hover handlers because they share it for the hover raise.
                        local btnPressScale = Instance.new("UIScale")
                        btnPressScale.Name = "_PressScale"
                        btnPressScale.Scale = 1
                        btnPressScale.Parent = b

                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, -36, 1, 0)
                        lbl.Position = UDim2.new(0, 18, 0, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamMedium
                        lbl.TextSize = 13
                        lbl.TextColor3 = primary and C.accentHi or C.text
                        lbl.TextXAlignment = Enum.TextXAlignment.Left
                        lbl.Text = nameText
                        lbl.Parent = b
                        -- [v4.0] Optional asset icon (number id / rbx URI).
                        applyElementIcon(b, bcfg.Icon, lbl)

                        local arr = Instance.new("TextLabel")
                        arr.Size = UDim2.new(0, 18, 1, 0)
                        arr.Position = UDim2.new(1, -24, 0, 0)
                        arr.BackgroundTransparency = 1
                        arr.Font = Enum.Font.GothamBold
                        arr.TextSize = 15
                        arr.TextColor3 = primary and C.accentHi or C.muted
                        arr.Text = "›"
                        arr.Parent = b

                        b.MouseEnter:Connect(function()
                                Tween(b, T20, { BackgroundColor3 = primary and C.accentDim or C.panelHov })
                                Tween(strk, T20, { Color = primary and C.accentHi or C.accentDim, Thickness = 1.5 })
                                Tween(arr, T20, { TextColor3 = primary and C.white or C.accent, Position = UDim2.new(1, -16, 0, 0) })
                                -- [v4.3.0] Spine lights up + grows on hover.
                                Tween(spine, T20, {
                                        BackgroundColor3 = C.accent,
                                        Size = UDim2.fromOffset(3, 28),
                                        Position = UDim2.new(0, 5, 0.5, -14),
                                })
                                -- [v4.3.0] Hover raise: 1.5% scale-up (layout stays owned
                                -- by UIListLayout — UIScale only).
                                if not reducedMotion then
                                        Tween(btnPressScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                                { Scale = 1.015 })
                                end
                        end)
                        b.MouseLeave:Connect(function()
                                Tween(b, T20, { BackgroundColor3 = primary and C.accentDark or C.panel })
                                Tween(strk, T20, { Color = primary and C.accentDim or C.border, Thickness = 1 })
                                Tween(arr, T20, { TextColor3 = primary and C.accentHi or C.muted, Position = UDim2.new(1, -24, 0, 0) })
                                Tween(spine, T20, {
                                        BackgroundColor3 = primary and C.accentHi or C.accentDim,
                                        Size = UDim2.fromOffset(3, 20),
                                        Position = UDim2.new(0, 5, 0.5, -10),
                                })
                                if not reducedMotion then
                                        Tween(btnPressScale, TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                                                { Scale = 1 })
                                end
                        end)
                        -- [v5.1.0] SPRING SHRINK (spec): 0.96x on press with the
                        -- 0.08s Sine micro-feedback curve — immediate tactile
                        -- response with no script latency. Release rides `move`.
                        b.MouseButton1Down:Connect(function()
                                Tween(btnPressScale, MT.press, { Scale = 0.96 })
                        end)
                        b.MouseButton1Up:Connect(function()
                                Tween(btnPressScale, MT.move, { Scale = 1 })
                        end)
                        b.MouseLeave:Connect(function()
                                Tween(btnPressScale, MT.move, { Scale = 1 })
                        end)

                        b.Activated:Connect(function()
                                playSfx("Click") -- [v5.1.0] metallic micro tick (spec pitch 1.0/0.35)
                                fireSheen()
                                ripple(rippleMask, b.AbsoluteSize.X - 30, b.AbsoluteSize.Y / 2, C.accent)
                                Tween(b, T20, { BackgroundColor3 = C.accentDim })
                                Tween(lbl, T20, { TextColor3 = C.white })
                                task.delay(0.15, function()
                                        Tween(b, T20, { BackgroundColor3 = primary and C.accentDim or C.panelHov })
                                        Tween(lbl, T20, { TextColor3 = primary and C.accentHi or C.text })
                                end)
                                if callback then
                                    task.spawn(function()
                                        local ok, err = pcall(callback)
                                        if not ok then
                                                -- [v5.0.0] ERROR TRACE: the lap runs red.
                                                traceLap(C.red, 1)
                                                -- Brief error state for a failed callback.
                                                Tween(b, T20, { BackgroundColor3 = Color3.fromRGB(85, 0, 0) })
                                                local origText = lbl.Text
                                                lbl.Text = "Callback Error"
                                                warn("[RezurXLib] Button '"..nameText.."' callback error: "..tostring(err))
                                                task.delay(0.5, function()
                                                        lbl.Text = origText
                                                        Tween(b, T20, { BackgroundColor3 = primary and C.accentDark or C.panel })
                                                end)
                                        else
                                                -- [v5.0.0] SUCCESS TRACE: one accent lap.
                                                traceLap(C.accent, 1)
                                        end
                                    end)
                                end
                        end)
                        onTheme(function()
                                Tween(b, T20, { BackgroundColor3 = primary and C.accentDark or C.panel })
                                Tween(strk, T20, { Color = primary and C.accentDim or C.border })
                                Tween(lbl, T20, { TextColor3 = primary and C.accentHi or C.text })
                                Tween(arr, T20, { TextColor3 = primary and C.accentHi or C.muted })
                                Tween(spine, T20, {
                                        BackgroundColor3 = primary and C.accentHi or C.accentDim,
                                        Size = UDim2.fromOffset(3, 20),
                                        Position = UDim2.new(0, 5, 0.5, -10),
                                })
                                if buttonGradient then
                                        buttonGradient.Color = ColorSequence.new{
                                                ColorSequenceKeypoint.new(0.0, C.accentDim),
                                                ColorSequenceKeypoint.new(1.0, C.accentDark),
                                        }
                                end
                        end)

                        local obj = {}
                        -- [FIX v4.0] Coerce nil like every other setter in the file.
                        function obj:Set(newName) lbl.Text = tostring(newName or nameText) end
                        function obj:SetCallback(fn) callback = fn end
                        return obj
                end

                -- ========================================================
                -- CreateToggle({ Name, CurrentValue, Flag, Callback })
                -- ========================================================
                function tab:CreateMultiButton(mcfg)
                        mcfg = mcfg or {}
                        local buttons = mcfg.Buttons or {}
                        local holder = Instance.new("Frame")
                        holder.Name = "MultiButton"
                        holder.Size = UDim2.new(1, 0, 0, 36)
                        holder.BackgroundTransparency = 1
                        holder.Parent = page
                        local hLayout = Instance.new("UIListLayout")
                        hLayout.FillDirection = Enum.FillDirection.Horizontal
                        hLayout.Padding = UDim.new(0, 6)
                        hLayout.Parent = holder
                        local objs = {}
                        for i, btnCfg in ipairs(buttons) do
                                local b = Instance.new("TextButton")
                                b.Name = btnCfg.Name or ("Btn" .. i)
                                b.Size = UDim2.new(1 / #buttons, -(6 * (#buttons - 1)) / #buttons, 1, 0)
                                b.BackgroundColor3 = C.panel
                                b.Text = ""
                                b.AutoButtonColor = false
                                b.BorderSizePixel = 0
                                b.Selectable = true
                                b.Parent = holder
                                corner(b, R.control)
                                local bStrk = stroke(b, C.border, 1)
                                local bLbl = Instance.new("TextLabel")
                                bLbl.Size = UDim2.new(1, 0, 1, 0)
                                bLbl.BackgroundTransparency = 1
                                bLbl.Font = Enum.Font.GothamMedium
                                bLbl.TextSize = 12
                                bLbl.TextColor3 = C.text
                                bLbl.Text = btnCfg.Name or ""
                                bLbl.Parent = b
                                b.MouseEnter:Connect(function() Tween(b, T10, { BackgroundColor3 = C.panelHov }) end)
                                b.MouseLeave:Connect(function() Tween(b, T10, { BackgroundColor3 = C.panel }) end)
                                b.Activated:Connect(function()
                                        ripple(b, b.AbsoluteSize.X / 2, b.AbsoluteSize.Y / 2, C.accent)
                                        if btnCfg.Callback then task.spawn(function() pcall(btnCfg.Callback) end) end
                                end)
                                onTheme(function()
                                        Tween(b, T20, { BackgroundColor3 = C.panel })
                                        Tween(bStrk, T20, { Color = C.border })
                                        Tween(bLbl, T20, { TextColor3 = C.text })
                                end)
                                table.insert(objs, { Set = function(t) bLbl.Text = t end, Fire = function() if btnCfg.Callback then pcall(btnCfg.Callback) end end })
                        end
                        applyTooltip(holder, mcfg.Tooltip)
                        return objs
                end

                function tab:CreateToggle(tcfg)
                        tcfg = tcfg or {}
                        local nameText = tcfg.Name or "Toggle"
                        local callback = tcfg.Callback
                        local state = tcfg.CurrentValue == true
                        local defaultState = state

                        local holder, hStroke = makeHolder(D.row)
                        -- [FIX] If toggle starts ON, outline the holder immediately
                        if state then hStroke.Color = C.accentDim end
                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, -68, 1, 0)
                        lbl.Position = UDim2.new(0, 14, 0, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamMedium
                        lbl.TextSize = 13
                        lbl.TextColor3 = C.text
                        lbl.TextXAlignment = Enum.TextXAlignment.Left
                        lbl.Text = nameText
                        lbl.Parent = holder
                        -- [v4.0] Optional asset icon (number id / rbx URI).
                        applyElementIcon(holder, tcfg.Icon, lbl)

                        local sw = Instance.new("Frame")
                        sw.Size = UDim2.new(0, 42, 0, 22)
                        sw.Position = UDim2.new(1, -52, 0.5, -11)
                        sw.BackgroundColor3 = state and C.accent or C.track
                        sw.BorderSizePixel = 0
                        sw.Parent = holder
                        corner(sw, UDim.new(1, 0))

                        local knob = Instance.new("Frame")
                        knob.Size = UDim2.new(0, 18, 0, 18)
                        knob.Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
                        knob.BackgroundColor3 = C.white
                        knob.BorderSizePixel = 0
                        knob.Parent = sw
                        corner(knob, UDim.new(1, 0))

                        -- [FIX] Transparent overlay button — captures ALL taps on the holder
                        -- (including over sw/knob which have visible backgrounds and would
                        -- otherwise steal the input on mobile touch).
                        local hit = Instance.new("TextButton")
                        hit.Size = UDim2.new(1, 0, 1, 0)
                        hit.BackgroundTransparency = 1
                        hit.Text = ""
                        hit.AutoButtonColor = false
                        hit.BorderSizePixel = 0
                        hit.ZIndex = 10
                        hit.Parent = holder
                        hit.Selectable = true

                        local obj = { CurrentValue = state }
                        local bloomTween = nil
                        local function apply(v, silent)
                                state = v
                                obj.CurrentValue = v
                                -- [v5.1.0] ELASTIC PILL MORPH (spec): the knob
                                -- STRETCHES horizontally while translating (taffy
                                -- pull: 24x16 on the 0.20s Quart component curve)
                                -- and snaps back to 18x18 with spring dampening
                                -- (Back overshoot) when it lands.
                                if not reducedMotion then
                                        Tween(knob, MT.move, { Size = UDim2.new(0, 24, 0, 16) })
                                        task.delay(0.18, function()
                                                if not knob.Parent then return end
                                                Tween(knob, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                                                        { Size = UDim2.new(0, 18, 0, 18) })
                                        end)
                                end
                                -- Switch background fades smoothly
                                Tween(sw, TTOGGLEBG, { BackgroundColor3 = state and C.accent or C.track })
                                -- [v5.1.0] AMBIENT BORDER BLOOM (spec): the active
                                -- state triggers a one-shot accent bloom on the
                                -- holder stroke — thicker + bright, then settling
                                -- to the resting accent. One-shot feedback (the
                                -- press moment), not an idle loop.
                                if state then
                                        -- [v5.2.0] ACTIVE-STATE CARD GLOW (spec): the whole
                                        -- card's border elevates from flat gray to a soft neon
                                        -- accent glow — accent color at 0.4 stroke transparency
                                        -- — and STAYS there while ON (ambient state, not a
                                        -- one-shot): the card visibly reads as "powered".
                                        if bloomTween then pcall(function() bloomTween:Cancel() end) end
                                        hStroke.Thickness = 2.2
                                        hStroke.Color = C.accentHi
                                        hStroke.Transparency = 0
                                        bloomTween = Tween(hStroke, MT.settle,
                                                { Thickness = 1.5, Color = C.accent, Transparency = 0.4 })
                                else
                                        Tween(hStroke, MT.move, { Color = C.border, Thickness = 1, Transparency = 0 })
                                end
                                -- Knob slides with smooth easing
                                Tween(knob, TTOGGLE, {
                                        Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
                                })
                                if callback and not silent then
                                        local ok, err = pcall(callback, state)
                                        if not ok then
                                                -- Brief error state for a failed callback.
                                                Tween(holder, T20, { BackgroundColor3 = Color3.fromRGB(85, 0, 0) })
                                                local origText = lbl.Text
                                                lbl.Text = "Callback Error"
                                                task.delay(0.5, function()
                                                        lbl.Text = origText
                                                        Tween(holder, T20, { BackgroundColor3 = C.panel })
                                                end)
                                                warn("[RezurXLib] Toggle '"..nameText.."' callback error: "..tostring(err))
                                        end
                                end
                        end
                        function obj:Set(v) apply(v == true) end
                        function obj:SetLabel(newText) lbl.Text = newText end
                        function obj:Get() return state end
                        -- Reset is intentionally public so a settings panel can
                        -- restore its declared default without recreating UI.
                        function obj:Reset() apply(defaultState) end

                        hit.Activated:Connect(function()
                                playSfx(state and "ToggleOn" or "ToggleOff") -- [v5.1.0] cyber chime ON / dull click OFF
                                apply(not state)
                        end)
                        onTheme(function()
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(lbl, T20, { TextColor3 = C.text })
                                Tween(sw, T20, { BackgroundColor3 = state and C.accent or C.track })
                                Tween(hStroke, T20, { Color = state and C.accentDim or C.border })
                        end)
                        registerFlag(tcfg.Flag, obj)
                        return obj
                end

                -- ========================================================
                -- CreateSlider({ Name, Range = {min,max}, Increment, Suffix,
                --                CurrentValue, Flag, Callback })
                -- ========================================================
                function tab:CreateSlider(scfg)
                        scfg = scfg or {}
                        local nameText  = scfg.Name or "Slider"
                        local range     = scfg.Range or { 0, 100 }
                        local minVal    = tonumber(range[1]) or 0
                        local maxVal    = tonumber(range[2]) or 100
                        if maxVal <= minVal then maxVal = minVal + 1 end
                        local increment = math.max(tonumber(scfg.Increment) or 1, 0.00001)
                        local suffix    = scfg.Suffix or ""
                        local callback  = scfg.Callback
                        -- [FIX v4.0] Snap the INITIAL value to the increment too.
                        -- CreateSlider({ Increment = 0.25, CurrentValue = 0.3 })
                        -- used to display 0.3 until the first drag jumped it to
                        -- 0.25 — a visible off-by-remainder on load. (Definition
                        -- hoisted above the initial value; the drag path reuses it.)
                        local function snap(v)
                                v = math.clamp(v, minVal, maxVal)
                                v = minVal + math.floor((v - minVal) / increment + 0.5) * increment
                                -- kill float noise on fractional increments
                                local mult = 1 / increment
                                if mult == math.floor(mult) then
                                        v = math.floor(v * mult + 0.5) / mult
                                end
                                return math.clamp(v, minVal, maxVal)
                        end
                        local value     = snap(tonumber(scfg.CurrentValue) or minVal)
                        local defaultValue = value

                        local holder, hStroke = makeHolder(52)
                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, -80, 0, 18)
                        lbl.Position = UDim2.new(0, 14, 0, 6)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamMedium
                        lbl.TextSize = 13
                        lbl.TextColor3 = C.text
                        lbl.TextXAlignment = Enum.TextXAlignment.Left
                        lbl.Text = nameText
                        lbl.Parent = holder
                        -- [v4.0] Optional asset icon (number id / rbx URI).
                        applyElementIcon(holder, scfg.Icon, lbl)

                        local valLbl = Instance.new("TextLabel")
                        valLbl.Size = UDim2.new(0, 64, 0, 18)
                        valLbl.Position = UDim2.new(1, -72, 0, 6)
                        valLbl.BackgroundTransparency = 1
                        valLbl.Font = Enum.Font.GothamBold
                        valLbl.TextSize = 13
                        valLbl.TextColor3 = C.accent
                                        valLbl.TextStrokeTransparency = 0.4
                                        valLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
                        valLbl.TextXAlignment = Enum.TextXAlignment.Right
                        valLbl.Text = tostring(value) .. suffix
                        valLbl.Parent = holder

                        local track = Instance.new("Frame")
                        track.Size = UDim2.new(1, -28, 0, 6)
                        track.Position = UDim2.new(0, 14, 0, 36)
                        track.BackgroundColor3 = C.track
                        track.BorderSizePixel = 0
                        track.Parent = holder
                        corner(track, UDim.new(1, 0))

                        local fill = Instance.new("Frame")
                        fill.Size = UDim2.new(0, 0, 1, 0)
                        fill.BackgroundColor3 = C.accent
                        fill.BorderSizePixel = 0
                        fill.Parent = track
                        corner(fill, UDim.new(1, 0))
                        local fillGrad = gradient(fill, ColorSequence.new{
                                ColorSequenceKeypoint.new(0, C.accentDim),
                                ColorSequenceKeypoint.new(1, C.accentHi),
                        })

                        local knob = Instance.new("Frame")
                        knob.Size = UDim2.new(0, 18, 0, 18)
                        -- Anchor to the physical centre so size changes never
                        -- shift the knob away from the cursor while dragging.
                        knob.AnchorPoint = Vector2.new(0.5, 0.5)
                        knob.Position = UDim2.new(0, 0, 0.5, 0)
                        knob.BackgroundColor3 = C.white
                        knob.BorderSizePixel = 0
                        knob.ZIndex = 3
                        knob.Parent = track
                        corner(knob, UDim.new(1, 0))
                        local knobStroke = stroke(knob, C.accent, 2)
                        -- Subtle knob shadow for depth.
                        -- [v5.1.0] DYNAMIC VALUE TOOLTIP (spec): a floating value
                        -- chip pops up above the thumb on press with elastic
                        -- spring physics, shows the live value, and retracts on
                        -- release. Attached to the track, positioned at the knob.
                        local valuePop = Instance.new("Frame")
                        valuePop.Name = "ValuePop"
                        valuePop.Size = UDim2.new(0, 62, 0, 24)
                        valuePop.AnchorPoint = Vector2.new(0.5, 1)
                        valuePop.Position = UDim2.new(0, 0, 0, -8)
                        valuePop.BackgroundColor3 = C.panelAlt
                        valuePop.BackgroundTransparency = 1
                        valuePop.BorderSizePixel = 0
                        valuePop.ZIndex = 12
                        valuePop.Visible = false
                        valuePop.Parent = holder
                        corner(valuePop, R.small)
                        stroke(valuePop, C.accentDim, 1)
                        local valuePopLbl = Instance.new("TextLabel")
                        valuePopLbl.Size = UDim2.new(1, -6, 1, 0)
                        valuePopLbl.Position = UDim2.new(0, 3, 0, 0)
                        valuePopLbl.BackgroundTransparency = 1
                        valuePopLbl.Font = Enum.Font.Code
                        valuePopLbl.TextSize = 12
                        valuePopLbl.TextColor3 = C.accentHi
                        valuePopLbl.TextXAlignment = Enum.TextXAlignment.Center
                        valuePopLbl.TextTransparency = 1
                        valuePopLbl.Text = ""
                        valuePopLbl.ZIndex = 13
                        valuePopLbl.Parent = valuePop
                        local valuePopSpring = nil
                        local function showValuePop(show)
                                if show then
                                        valuePop.Visible = true
                                        valuePopLbl.Text = tostring(value) .. suffix
                                        valuePopSpring = springTo(valuePopSpring, valuePop, 1, {
                                                from = 0, stiffness = 340, damping = 18,
                                                apply = function(v)
                                                        valuePop.BackgroundTransparency = 1 - v * 0.95
                                                        valuePopLbl.TextTransparency = 1 - v
                                                end,
                                        })
                                else
                                        springCancel(valuePopSpring, true)
                                        valuePop.Visible = false
                                end
                        end
                        local function trackValuePop()
                                local pct = math.clamp((value - minVal) / math.max(maxVal - minVal, 1), 0, 1)
                                local trackW = track.AbsoluteSize.X
                                valuePop.Position = UDim2.new(0, snapPx(14 + pct * math.max(trackW - 28, 1)), 0, -8)
                                valuePopLbl.Text = tostring(value) .. suffix
                        end

                        local knobShadow = Instance.new("ImageLabel")
                        knobShadow.Size = UDim2.new(1, 8, 1, 8)
                        knobShadow.Position = UDim2.new(0, -4, 0, -4)
                        knobShadow.BackgroundTransparency = 1
                        knobShadow.Image = "rbxassetid://1316045217"
                        knobShadow.ImageColor3 = Color3.new(0, 0, 0)
                        knobShadow.ImageTransparency = 0.7
                        knobShadow.ZIndex = 2
                        knobShadow.Parent = knob

                        local lastTicked = nil
                        local function update(animated)
                                local pct = math.clamp((value - minVal) / (maxVal - minVal), 0, 1)
                                if animated then
                                        Tween(fill, T10, { Size = UDim2.new(pct, 0, 1, 0) })
                                        Tween(knob, T10, { Position = UDim2.new(pct, 0, 0.5, 0) })
                                else
                                        fill.Size = UDim2.new(pct, 0, 1, 0)
                                        knob.Position = UDim2.new(pct, 0, 0.5, 0)
                                end
                                valLbl.Text = tostring(value) .. suffix
                                -- [v5.1.0] live popup tracking + soft friction tick
                                -- (spec 1.3/0.15) each time the snapped value steps.
                                if valuePop.Visible then trackValuePop() end
                                if value ~= lastTicked then
                                        lastTicked = value
                                        if valuePop.Visible then playSfx("SliderStep") end
                                end
                        end
                        update(false)

                        local obj = { CurrentValue = value }
                        local lastFired = value
                        -- [v5.4.0] ERROR SURFACE for the SafeCallback funnel: this
                        -- element's row flashes red + swaps its title if the
                        -- consumer callback throws (Rayfield/Luna pattern).
                        local surf = {
                                frame = holder, label = lbl,
                                name = "Slider '" .. nameText .. "'",
                                baseBg = C.panel, baseText = C.text,
                        }
                        function obj:Set(v)
                                value = snap(v)
                                obj.CurrentValue = value
                                update(true)
                                lastFired = value
                                Library.SafeCallback(surf, callback, value)
                        end
                        function obj:Get() return value end
                        function obj:Reset() return obj:Set(defaultValue) end

                        -- [v5.4.0] TYPEABLE VALUE BOX (Luna/Maclib pattern): click
                        -- the value readout and type an exact number. Enter commits
                        -- (clamped + snapped through obj:Set), Escape or clicking
                        -- away cancels. Power users no longer scrub a 0–1000 slider
                        -- to reach 847.
                        do
                                local editing = false
                                local editBox = Instance.new("TextBox")
                                editBox.Size = UDim2.new(0, 64, 0, 18)
                                editBox.Position = UDim2.new(1, -72, 0, 6)
                                editBox.BackgroundTransparency = 1
                                editBox.Font = Enum.Font.GothamBold
                                editBox.TextSize = 13
                                editBox.TextColor3 = C.accentHi
                                editBox.TextXAlignment = Enum.TextXAlignment.Right
                                editBox.Text = ""
                                editBox.Visible = false
                                editBox.ClearTextOnFocus = false
                                editBox.TextWrapped = false
                                editBox.Parent = holder

                                local editHit = Instance.new("TextButton")
                                editHit.Size = UDim2.new(0, 76, 0, 20)
                                editHit.Position = UDim2.new(1, -78, 0, 5)
                                editHit.BackgroundTransparency = 1
                                editHit.Text = ""
                                editHit.AutoButtonColor = false
                                editHit.BorderSizePixel = 0
                                editHit.Parent = holder

                                local function stopEdit(commit)
                                        if not editing then return end
                                        editing = false
                                        if commit then
                                                local n = tonumber(editBox.Text)
                                                if n then obj:Set(n) end -- Set snaps + clamps
                                        end
                                        editBox.Visible = false
                                        valLbl.Visible = true
                                        update(false) -- restore canonical display
                                end

                                editHit.Activated:Connect(function()
                                        if editing then return end
                                        editing = true
                                        editBox.Text = tostring(value)
                                        valLbl.Visible = false
                                        editBox.Visible = true
                                        editBox:CaptureFocus()
                                        editBox.CursorPosition = #editBox.Text + 1
                                        editBox.SelectionStart = 1
                                end)
                                editBox.FocusLost:Connect(function(enterPressed)
                                        -- commit on Enter only; a stray click elsewhere
                                        -- cancels instead of committing a half-typed value
                                        stopEdit(enterPressed == true)
                                end)
                                editBox:GetPropertyChangedSignal("Text"):Connect(function()
                                        -- numeric filter: optional leading minus, digits,
                                        -- at most one dot (Luna-style sanitiser)
                                        local t = editBox.Text
                                        if t == "" or t == "-" or t == "." then return end
                                        if not t:match("^%-?%d*%.?%d*$") then
                                                editBox.Text = t:match("^%-?%d*%.?%d*") or ""
                                        end
                                end)
                        end

                                local function setFromX(x)
                                        local trackWidth = math.max(track.AbsoluteSize.X, 1)
                                        local pct = math.clamp((x - track.AbsolutePosition.X) / trackWidth, 0, 1)
                                        local v = snap(minVal + pct * (maxVal - minVal))
                                        if v ~= value then
                                                value = v
                                                obj.CurrentValue = v
                                                update(false)
                                        end
                                end
                                local function fireCallback()
                                        -- [FIX] This used to only be called at drag-start and
                                        -- drag-end — never from the move handler during an actual
                                        -- drag. setFromX() updated the visual smoothly in real
                                        -- time, but the bound Callback only ever saw the value at
                                        -- the position you clicked and the position you released,
                                        -- nothing in between. Anything relying on live feedback
                                        -- (a volume preview, a live speed change, etc.) lagged
                                        -- until mouse-up. De-duped against lastFired so it only
                                        -- actually calls back when the snapped value changed.
                                        if callback and value ~= lastFired then
                                                lastFired = value
                                                Library.SafeCallback(surf, callback, value)
                                        end
                                end
                                -- [FIX] Transparent overlay covering the whole holder. Tapping the
                                -- fill or knob (children of track with visible backgrounds) would
                                -- otherwise steal input and track.InputBegan would never fire.
                                local hit = Instance.new("TextButton")
                                hit.Size = UDim2.new(1, 0, 1, 0)
                                hit.BackgroundTransparency = 1
                                hit.Text = ""
                                hit.AutoButtonColor = false
                                hit.BorderSizePixel = 0
                                hit.ZIndex = 10
                                hit.Parent = holder
                                hit.Selectable = true
                                keyboardAdjusters[hit] = function(direction)
                                        obj:Set(value + direction * increment)
                                end
                                hit.InputBegan:Connect(function(inp)
                                        if inp.UserInputType == Enum.UserInputType.MouseButton1
                                                or inp.UserInputType == Enum.UserInputType.Touch then
                                                -- [FIX] Guard against stale AbsolutePosition on first click.
                                                -- Roblox's layout engine may not have filled in
                                                -- track.AbsolutePosition/AbsoluteSize yet on the very
                                                -- first click after UI creation. If track width is 0 or
                                                -- position is (0,0), skip the setFromX call — just
                                                -- register the drag and let the next frame handle it.
                                                local trackPos = track.AbsolutePosition
                                                local trackSize = track.AbsoluteSize
                                                local layoutReady = trackSize.X > 1 and trackPos.X >= 0
                                                local currentPct = math.clamp(
                                                        (value - minVal) / math.max(maxVal - minVal, 1),
                                                        0,
                                                        1
                                                )
                                                local knobCenterX = trackPos.X + trackSize.X * currentPct
                                                local gripOffsetX = inp.Position.X - knobCenterX
                                                -- Preserve a direct grab on the knob. A click elsewhere
                                                -- on the track still jumps intentionally to that value.
                                                local grabbedKnob = layoutReady and math.abs(gripOffsetX) <= 14
                                                -- The knob grows slightly while it is grabbed.
                                                Tween(knob, T20, { Size = UDim2.new(0, 22, 0, 22) })
                                                -- [v5.1.0] value popup springs in on press.
                                                showValuePop(true)
                                                trackValuePop()
                                                if layoutReady then
                                                        setFromX(grabbedKnob and (inp.Position.X - gripOffsetX) or inp.Position.X)
                                                        fireCallback()
                                                end
                                                registerDrag(hit, inp, function(pos)
                                                        setFromX(grabbedKnob and (pos.X - gripOffsetX) or pos.X)
                                                        fireCallback()
                                                end, function()
                                                        -- Knob shrinks back on release
                                                        Tween(knob, T20, { Size = UDim2.new(0, 18, 0, 18) })
                                                        showValuePop(false)
                                                        fireCallback()
                                                end)
                                        end
                                end)
                        onTheme(function()
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(lbl, T20, { TextColor3 = C.text })
                                Tween(valLbl, T20, { TextColor3 = C.accent })
                                Tween(track, T20, { BackgroundColor3 = C.track })
                                Tween(knobStroke, T20, { Color = C.accent })
                                fillGrad.Color = ColorSequence.new{
                                        ColorSequenceKeypoint.new(0, C.accentDim),
                                        ColorSequenceKeypoint.new(1, C.accentHi),
                                }
                        end)
                        registerFlag(scfg.Flag, obj)
                        return obj
                end

                -- ========================================================
                -- CreateInput({ Name, PlaceholderText, CurrentValue,
                --               RemoveTextAfterFocusLost, Flag, Callback })
                -- ========================================================
                function tab:CreateInput(icfg)
                        icfg = icfg or {}
                        local nameText = icfg.Name or "Input"
                        local callback = icfg.Callback
                        local defaultValue = tostring(icfg.CurrentValue or "")

                        local holder, strk = makeHolder(48)
                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, -16, 0, 14)
                        lbl.Position = UDim2.new(0, 14, 0, 6)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamMedium
                        lbl.TextSize = 10
                        lbl.TextColor3 = C.muted
                        lbl.TextXAlignment = Enum.TextXAlignment.Left
                        lbl.Text = string.upper(nameText)
                        lbl.Parent = holder
                        -- [v4.0] Optional asset icon (number id / rbx URI).
                        applyElementIcon(holder, icfg.Icon, lbl)

                        local box = Instance.new("TextBox")
                        box.Size = UDim2.new(1, -28, 0, 20)
                        box.Position = UDim2.new(0, 14, 0, 24)
                        box.BackgroundTransparency = 1
                        box.Font = Enum.Font.Gotham
                        box.TextSize = 13
                        box.TextColor3 = C.text
                        box.PlaceholderColor3 = C.muted
                        box.PlaceholderText = icfg.PlaceholderText or ""
                        box.Text = defaultValue
                        box.TextXAlignment = Enum.TextXAlignment.Left
                        box.ClearTextOnFocus = false
                        box.Parent = holder

                        local obj = { CurrentValue = box.Text }
                        -- [v5.1.0] NEON FOCUS FLARE (spec): the stroke thickness
                        -- expands on focus; the placeholder shifts upward into a
                        -- floating mini-label above the field.
                        local floatLbl = Instance.new("TextLabel")
                        floatLbl.Name = "FloatLabel"
                        floatLbl.Size = UDim2.new(1, -28, 0, 12)
                        floatLbl.Position = UDim2.new(0, 14, 0, -13)
                        floatLbl.BackgroundTransparency = 1
                        floatLbl.Font = Enum.Font.GothamBold
                        floatLbl.TextSize = 9
                        floatLbl.TextColor3 = C.accent
                        floatLbl.TextXAlignment = Enum.TextXAlignment.Left
                        floatLbl.Text = string.upper(nameText)
                        floatLbl.TextTransparency = 0.65
                        floatLbl.Position = UDim2.new(0, 14, 0, 2)
                        floatLbl.ZIndex = 3
                        floatLbl.Parent = holder
                        box.Focused:Connect(function()
                                -- [v5.1.0] flare: stroke 1 -> 2 while focused
                                Tween(strk, MT.move, { Color = C.accent, Thickness = 2 })
                                Tween(lbl, T10, { TextColor3 = C.accent })
                                -- placeholder floats up into the mini-label
                                Tween(floatLbl, MT.move, {
                                        Position = UDim2.new(0, 14, 0, -13),
                                        TextTransparency = 0,
                                })
                        end)
                        -- [v5.4.0] SafeCallback error surface for this input row.
                        local inSurf = {
                                frame = holder, label = lbl,
                                name = "Input '" .. nameText .. "'",
                                baseBg = C.panel, baseText = C.text,
                        }
                        box.FocusLost:Connect(function()
                                Tween(strk, MT.move, { Color = C.border, Thickness = 1 })
                                Tween(lbl, T10, { TextColor3 = C.muted })
                                -- mini-label retracts when the field has content;
                                -- settles back over the field when empty
                                if box.Text == "" then
                                        Tween(floatLbl, MT.move, {
                                                Position = UDim2.new(0, 14, 0, 2),
                                                TextTransparency = 0.65,
                                        })
                                end
                                obj.CurrentValue = box.Text
                                Library.SafeCallback(inSurf, callback, box.Text)
                                if icfg.RemoveTextAfterFocusLost then
                                        box.Text = ""
                                end
                        end)
                        function obj:Set(text)
                                box.Text = text
                                obj.CurrentValue = text
                        end
                        function obj:Get() return box.Text end
                        function obj:Reset() obj:Set(defaultValue) end
                        onTheme(function()
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(strk, T20, { Color = C.border })
                                Tween(lbl, T20, { TextColor3 = C.muted })
                                Tween(box, T20, { TextColor3 = C.text })
                                box.PlaceholderColor3 = C.muted
                        end)
                        registerFlag(icfg.Flag, obj)
                        return obj
                end

                -- ========================================================
                -- CreateDropdown({ Name, Options, CurrentOption,
                --                  MultipleOptions, Searchable, Tooltip,
                --                  Flag, Callback })
                -- A portal-style dropdown which is scale-aware, searchable,
                -- keyboard activatable, and always closes before another
                -- popup opens. Options can be strings, numbers, or records:
                -- { Text, Value, Disabled }.
                -- ========================================================
                function tab:CreateDropdown(dcfg)
                        dcfg = dcfg or {}
                        local nameText = dcfg.Name or "Dropdown"
                        local multi = dcfg.MultipleOptions == true
                        local searchable = dcfg.Searchable == true
                        local callback = dcfg.Callback

                        local function makeEntries(source)
                                local result = {}
                                if type(source) ~= "table" then return result end
                                for index, raw in ipairs(source) do
                                        local value, label, disabled = raw, tostring(raw), false
                                        if type(raw) == "table" then
                                                value = raw.Value
                                                if value == nil then value = raw.Name or raw.Text end
                                                if value == nil then value = index end
                                                label = tostring(raw.Text or raw.Name or raw.Label or value)
                                                disabled = raw.Disabled == true
                                        end
                                        result[index] = {
                                                Value = value,
                                                Raw = raw,
                                                Label = label,
                                                Search = string.lower(label),
                                                Disabled = disabled,
                                        }
                                end
                                return result
                        end

                        local entries = makeEntries(dcfg.Options)
                        local selected = {}
                        local function matches(entry, value)
                                -- [FIX v4.0] Also match by the common record fields so
                                -- obj:Set({ Value = "x" }) with a FRESH table works —
                                -- identity comparison alone silently ignored it and
                                -- left the selection unchanged.
                                if entry.Value == value or entry.Raw == value then return true end
                                if type(value) == "table" then
                                        local inner = value.Value ~= nil and value.Value or (value.Name or value.Text or value.Label)
                                        if inner ~= nil and (entry.Value == inner or entry.Raw == inner) then return true end
                                end
                                return false
                        end
                        local function recordOption(value)
                                if type(value) ~= "table" then return false end
                                for _, entry in ipairs(entries) do
                                        if entry.Raw == value then return true end
                                end
                                return value.Value ~= nil or value.Name ~= nil
                                        or value.Text ~= nil or value.Label ~= nil
                        end
                        local function select(value)
                                for index, entry in ipairs(entries) do
                                        if matches(entry, value) then
                                                selected[index] = true
                                                return true
                                        end
                                end
                                return false
                        end
                        local function setSelection(valueOrList, chooseFirst)
                                table.clear(selected)
                                if type(valueOrList) == "table" and not recordOption(valueOrList) then
                                        for _, value in ipairs(valueOrList) do
                                                select(value)
                                                if not multi then break end
                                        end
                                elseif valueOrList ~= nil then
                                        select(valueOrList)
                                elseif chooseFirst and not multi and entries[1] then
                                        selected[1] = true
                                end
                        end
                        setSelection(dcfg.CurrentOption, true)

                        local holder, hStroke = makeHolder(D.row)
                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, -40, 1, 0)
                        label.Position = UDim2.fromOffset(14, 0)
                        label.BackgroundTransparency = 1
                        label.Font = Enum.Font.GothamMedium
                        label.TextSize = 13
                        label.TextColor3 = C.text
                        label.TextXAlignment = Enum.TextXAlignment.Left
                        label.TextTruncate = Enum.TextTruncate.AtEnd
                        label.Parent = holder
                        -- [v4.0] Optional asset icon (number id / rbx URI).
                        applyElementIcon(holder, dcfg.Icon, label)

                        local arrow = Instance.new("TextLabel")
                        arrow.Size = UDim2.fromOffset(20, 42)
                        arrow.Position = UDim2.new(1, -27, 0, 0)
                        arrow.BackgroundTransparency = 1
                        arrow.Font = Enum.Font.GothamBold
                        arrow.TextSize = 10
                        arrow.TextColor3 = C.muted
                        arrow.Text = "▾"
                        arrow.Parent = holder

                        local hit = Instance.new("TextButton")
                        hit.Size = UDim2.fromScale(1, 1)
                        hit.BackgroundTransparency = 1
                        hit.BorderSizePixel = 0
                        hit.AutoButtonColor = false
                        hit.Text = ""
                        hit.Selectable = true
                        hit.ZIndex = 5
                        hit.Parent = holder

                        local obj = {}
                        local function selectedValues()
                                local values = {}
                                for index, entry in ipairs(entries) do
                                        if selected[index] then table.insert(values, entry.Value) end
                                end
                                return values
                        end
                        local function selectedLabels()
                                local values = {}
                                for index, entry in ipairs(entries) do
                                        if selected[index] then table.insert(values, entry.Label) end
                                end
                                return values
                        end
                        local defaultValues = selectedValues()
                        local function refreshLabel()
                                local values = selectedLabels()
                                if #values == 0 then
                                        label.Text = nameText .. "  /  None"
                                elseif multi and #values > 2 then
                                        label.Text = nameText .. "  /  " .. #values .. " selected"
                                elseif multi then
                                        label.Text = nameText .. "  /  " .. table.concat(values, ", ")
                                else
                                        label.Text = nameText .. "  /  " .. values[1]
                                end
                        end
                        local function fire()
                                -- Take a stable value snapshot, then dispatch on the
                                -- next scheduler turn. A game callback is allowed to
                                -- yield or do expensive work; it must never hold the
                                -- input event open or strand the popup catcher above
                                -- the rest of the interface.
                                local selectedOption = multi and selectedValues() or selectedValues()[1]
                                obj.CurrentOption = selectedOption
                                if type(callback) == "function" then
                                        -- [v5.4.0] routed through the SafeCallback funnel:
                                        -- task.spawn isolation + visual error flash on the
                                        -- dropdown row if the consumer callback throws.
                                        Library.SafeCallback({
                                                frame = holder, label = label,
                                                name = "Dropdown '" .. tostring(nameText) .. "'",
                                                baseBg = C.panel, baseText = C.text,
                                        }, callback, selectedOption)
                                end
                        end
                        obj.CurrentOption = multi and selectedValues() or selectedValues()[1]
                        refreshLabel()

                        local popupOpen = false
                        local function openList()
                                if popupOpen then
                                        closeCurrentPopup()
                                        return
                                end
                                closeCurrentPopup()
                                popupOpen = true
                                arrow.Text = "▴"

                                -- Holder geometry and the portal use physical
                                -- screen pixels. The fallback retains the old
                                -- compensation only if the portal cannot attach.
                                local scale = overlayGui == screenGui
                                        and math.max(uiScale.Scale, 0.01) or 1
                                local function px(value)
                                        return math.max(1, math.floor(value / scale + 0.5))
                                end
                                local anchorPosition = holder.AbsolutePosition
                                local anchorSize = holder.AbsoluteSize
                                local viewport = getViewport()
                                local margin, rowHeight, rowGap = 8, 32, 3
                                local searchHeight = searchable and 34 or 0
                                local width = math.min(
                                        math.max(anchorSize.X, 190),
                                        math.max(120, viewport.X - margin * 2)
                                )
                                local maxHeight = math.max(1, viewport.Y - margin * 2)

                                local listGroup = Instance.new("Frame")
                                listGroup.Name = "DropdownPopupGroup"
                                listGroup.Size = UDim2.fromOffset(px(width), 0)
                                listGroup.BackgroundTransparency = 1
                                listGroup.ZIndex = 61
                                listGroup.Parent = overlayGui
                                local list = Instance.new("ScrollingFrame")
                                list.Name = "DropdownPopup"
                                list.Size = UDim2.new(1, 0, 1, 0)
                                list.BackgroundColor3 = C.panel
                                list.BackgroundTransparency = 0.03
                                list.BorderSizePixel = 0
                                list.ClipsDescendants = true
                                list.Active = true
                                list.ScrollingDirection = Enum.ScrollingDirection.Y
                                list.ScrollBarThickness = px(3)
                                list.ScrollBarImageColor3 = C.accent
                                list.CanvasSize = UDim2.fromOffset(0, 0)
                                list.ZIndex = 62
                                list.Parent = listGroup
                                corner(list, R.panel)
                                stroke(list, C.border, 1)

                                local layout = Instance.new("UIListLayout")
                                layout.Padding = UDim.new(0, px(rowGap))
                                layout.SortOrder = Enum.SortOrder.LayoutOrder
                                layout.Parent = list
                                pad(list, px(6), px(6), px(6), px(6))

                                local searchBox = nil
                                if searchable then
                                        local searchHolder = Instance.new("Frame")
                                        searchHolder.Name = "Search"
                                        searchHolder.LayoutOrder = 0
                                        searchHolder.Size = UDim2.new(1, 0, 0, px(30))
                                        searchHolder.BackgroundColor3 = C.panelAlt
                                        searchHolder.BorderSizePixel = 0
                                        searchHolder.ZIndex = 62
                                        searchHolder.Parent = list
                                        corner(searchHolder, R.small)
                                        stroke(searchHolder, C.border, 1)

                                        searchBox = Instance.new("TextBox")
                                        searchBox.Name = "SearchBox"
                                        searchBox.Size = UDim2.new(1, -px(12), 1, 0)
                                        searchBox.Position = UDim2.fromOffset(px(6), 0)
                                        searchBox.BackgroundTransparency = 1
                                        searchBox.ClearTextOnFocus = false
                                        searchBox.Font = Enum.Font.Gotham
                                        searchBox.TextSize = 12
                                        searchBox.TextColor3 = C.text
                                        searchBox.PlaceholderColor3 = C.muted
                                        searchBox.PlaceholderText = "Search options..."
                                        searchBox.TextXAlignment = Enum.TextXAlignment.Left
                                        searchBox.ZIndex = 63
                                        searchBox.Parent = searchHolder
                                end

                                local views = {}
                                for index, entry in ipairs(entries) do
                                        local item = Instance.new("TextButton")
                                        item.Name = "Option_" .. index
                                        item.LayoutOrder = index
                                        item.Size = UDim2.new(1, 0, 0, px(rowHeight))
                                        item.BackgroundColor3 = C.panelAlt
                                        item.BackgroundTransparency = entry.Disabled and 0.45 or 0
                                        item.BorderSizePixel = 0
                                        item.AutoButtonColor = false
                                        item.Text = ""
                                        item.Active = not entry.Disabled
                                        item.Selectable = not entry.Disabled
                                        item.ZIndex = 62
                                        item.Parent = list
                                        corner(item, R.small)

                                        local itemLabel = Instance.new("TextLabel")
                                        itemLabel.Size = UDim2.new(1, -px(34), 1, 0)
                                        itemLabel.Position = UDim2.fromOffset(px(10), 0)
                                        itemLabel.BackgroundTransparency = 1
                                        itemLabel.Font = Enum.Font.Gotham
                                        itemLabel.TextSize = 13
                                        itemLabel.TextColor3 = selected[index] and C.accent or C.text
                                        itemLabel.TextTransparency = entry.Disabled and 0.48 or 0
                                        itemLabel.TextXAlignment = Enum.TextXAlignment.Left
                                        itemLabel.TextTruncate = Enum.TextTruncate.AtEnd
                                        itemLabel.Text = entry.Label
                                        itemLabel.ZIndex = 63
                                        itemLabel.Parent = item

                                        local check = Instance.new("TextLabel")
                                        check.Size = UDim2.fromOffset(px(20), px(rowHeight))
                                        check.Position = UDim2.new(1, -px(26), 0, 0)
                                        check.BackgroundTransparency = 1
                                        check.Font = Enum.Font.GothamBold
                                        check.TextSize = 13
                                        check.TextColor3 = C.accent
                                        check.Text = selected[index] and "✓" or ""
                                        check.ZIndex = 63
                                        check.Parent = item
                                        table.insert(views, {
                                                Entry = entry,
                                                Frame = item,
                                                Label = itemLabel,
                                                Check = check,
                                                Index = index,
                                        })

                                        if not entry.Disabled then
                                                item.MouseEnter:Connect(function()
                                                        Tween(item, T10, { BackgroundColor3 = C.panelHov })
                                                end)
                                                item.MouseLeave:Connect(function()
                                                        Tween(item, T10, { BackgroundColor3 = C.panelAlt })
                                                end)
                                                item.Activated:Connect(function()
                                                        if multi then
                                                                selected[index] = not selected[index] or nil
                                                                check.Text = selected[index] and "✓" or ""
                                                                itemLabel.TextColor3 = selected[index] and C.accent or C.text
                                                                refreshLabel()
                                                                fire()
                                                        else
                                                                table.clear(selected)
                                                                selected[index] = true
                                                                refreshLabel()
                                                                -- Remove the full-screen dismissal layer
                                                                -- before notifying user code. This makes a
                                                                -- selected option immediately interactive
                                                                -- even if the callback yields or errors.
                                                                closeCurrentPopup()
                                                                fire()
                                                        end
                                                end)
                                        end
                                end

                                local emptyLabel = Instance.new("TextLabel")
                                emptyLabel.Name = "EmptyState"
                                emptyLabel.LayoutOrder = #entries + 1
                                emptyLabel.Size = UDim2.new(1, 0, 0, px(rowHeight))
                                emptyLabel.BackgroundTransparency = 1
                                emptyLabel.Font = Enum.Font.Gotham
                                emptyLabel.TextSize = 12
                                emptyLabel.TextColor3 = C.muted
                                emptyLabel.Text = #entries == 0 and "No options available" or "No matching options"
                                emptyLabel.ZIndex = 62
                                emptyLabel.Visible = #entries == 0
                                emptyLabel.Parent = list

                                local function updateMetrics(visibleCount)
                                        local shownRows = math.max(1, math.min(visibleCount, 7))
                                        local canvasRows = math.max(1, visibleCount)
                                        local height = math.min(
                                                12 + searchHeight + shownRows * rowHeight
                                                        + math.max(0, shownRows - 1) * rowGap,
                                                maxHeight
                                        )
                                        local belowY = anchorPosition.Y + anchorSize.Y + 6
                                        local aboveY = anchorPosition.Y - height - 6
                                        local opensBelow = belowY + height <= viewport.Y - margin
                                                or aboveY < margin
                                        local x = math.clamp(anchorPosition.X, margin, viewport.X - width - margin)
                                        local y = opensBelow and belowY or math.max(margin, aboveY)
                                        local collapsedY = opensBelow and (anchorPosition.Y + anchorSize.Y + 2)
                                                or (anchorPosition.Y - 2)
                                        list.CanvasSize = UDim2.fromOffset(
                                                0,
                                                px(12 + searchHeight + canvasRows * rowHeight
                                                        + math.max(0, canvasRows - 1) * rowGap)
                                        )
                                        if listGroup.AbsoluteSize.Y <= 1 then
                                                listGroup.Position = UDim2.fromOffset(px(x), px(collapsedY))
                                        end
                                        Tween(listGroup, T15, {
                                                Size = UDim2.fromOffset(px(width), px(height)),
                                                Position = UDim2.fromOffset(px(x), px(y)),
                                        })
                                end

                                local function matchesSearch(candidate, query)
                                        if query == "" or candidate:find(query, 1, true) then return true end
                                        local needle = 1
                                        for index = 1, #candidate do
                                                if candidate:sub(index, index) == query:sub(needle, needle) then
                                                        needle = needle + 1
                                                        if needle > #query then return true end
                                                end
                                        end
                                        return false
                                end
                                local function applyFilter()
                                        local query = searchBox and string.lower(searchBox.Text) or ""
                                        local visibleCount = 0
                                        for _, view in ipairs(views) do
                                                local visible = matchesSearch(view.Entry.Search, query)
                                                view.Frame.Visible = visible
                                                if visible then visibleCount = visibleCount + 1 end
                                        end
                                        emptyLabel.Visible = visibleCount == 0
                                        updateMetrics(visibleCount)
                                end

                                -- The catcher sits below the popup but above the
                                -- window. Compensating its scale makes every edge
                                -- of the physical screen dismiss reliably on touch.
                                local catcher = Instance.new("TextButton")
                                catcher.Name = "DropdownDismiss"
                                catcher.Size = UDim2.new(1 / scale, 0, 1 / scale, 0)
                                catcher.BackgroundTransparency = 1
                                catcher.BorderSizePixel = 0
                                catcher.Text = ""
                                catcher.AutoButtonColor = false
                                catcher.Active = true
                                catcher.ZIndex = 60
                                catcher.Parent = overlayGui
                                catcher.Activated:Connect(closeCurrentPopup)

                                local popupJanitor = Janitor.new()
                                popupJanitor:Add(catcher, "Destroy")
                                popupJanitor:Add(listGroup, "Destroy")
                                popupJanitor:Add(function()
                                        popupOpen = false
                                        arrow.Text = "▾"
                                end)
                                -- [FIX v4.0] Closing on ANY uiScale change made Searchable
                                -- dropdowns unusable on phones: focusing the search box
                                -- summons the on-screen keyboard, which resizes the
                                -- viewport, which changes uiScale, which instantly
                                -- destroyed the popup mid-typing. Now scale changes
                                -- inside the focus grace window are ignored; genuine
                                -- rotations/resizes afterwards still close the popup.
                                local scaleGraceUntil = 0
                                popupJanitor:Add(uiScale:GetPropertyChangedSignal("Scale"):Connect(function()
                                        if os.clock() < scaleGraceUntil then return end
                                        closeCurrentPopup()
                                end))
                                if searchBox then
                                        popupJanitor:Add(searchBox:GetPropertyChangedSignal("Text"):Connect(applyFilter))
                                end
                                currentPopupJanitor = popupJanitor
                                applyFilter()

                                -- [v5.1.0] UNFOLD: group alpha 1 -> 0 over 0.15s while
                                -- each option row drops 10px with a 0.02s stagger —
                                -- the spec's cascading dropdown fill.
                                do
                                        local rows = {}
                                        for _, view in ipairs(views) do
                                                if view.Frame.Visible then table.insert(rows, view.Frame) end
                                        end
                                        for rowIndex, row in ipairs(rows) do
                                                local origPos = row.Position
                                                row.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset,
                                                        origPos.Y.Scale, origPos.Y.Offset + 10)
                                                row.BackgroundTransparency = 1
                                                task.delay((rowIndex - 1) * 0.02, function()
                                                        if not row.Parent then return end
                                                        Tween(row, MT.move, { Position = origPos, BackgroundTransparency = 0 })
                                                end)
                                        end
                                        -- No GroupTransparency (CanvasGroup removed);
                                        -- the staggered row drop IS the unfold.
                                end

                                if searchBox then
                                        task.defer(function()
                                                if popupOpen and searchBox.Parent then
                                                        -- [FIX v4.0] Arm the scale-change grace window BEFORE
                                                        -- focusing: the mobile keyboard resizes the viewport
                                                        -- (→ uiScale change) the moment focus lands, which the
                                                        -- old close-on-scale listener treated as a rotation and
                                                        -- destroyed the popup mid-typing.
                                                        scaleGraceUntil = os.clock() + 1.25
                                                        searchBox:CaptureFocus()
                                                        -- Extend the window for the keyboard's settle animation.
                                                        task.delay(0.1, function()
                                                                if popupOpen and UserInputService:GetFocusedTextBox() == searchBox then
                                                                        scaleGraceUntil = math.max(scaleGraceUntil, os.clock() + 1.25)
                                                                end
                                                        end)
                                                end
                                        end)
                                end
                        end

                        hit.Activated:Connect(openList)
                        function obj:Set(valueOrList, silent)
                                setSelection(valueOrList, false)
                                refreshLabel()
                                if silent then
                                        obj.CurrentOption = multi and selectedValues() or selectedValues()[1]
                                else
                                        fire()
                                end
                        end
                        function obj:Refresh(newOptions, keepSelection)
                                local retained = selectedValues()
                                entries = makeEntries(newOptions)
                                setSelection(keepSelection and retained or nil, not keepSelection)
                                if popupOpen then closeCurrentPopup() end
                                refreshLabel()
                                obj.CurrentOption = multi and selectedValues() or selectedValues()[1]
                        end
                        -- [v5.4.0] LIVING DROPDOWN (Rayfield pattern): append / remove
                        -- single options without rebuilding the whole list. Values
                        -- present in the selection survive; a removed selected value
                        -- is dropped and the label refreshes. No callbacks fire —
                        -- these are data operations (Refresh never fired either).
                        function obj:Add(option)
                                if option == nil then return obj.CurrentOption end
                                local nextOpts = {}
                                for _, e in ipairs(entries) do nextOpts[#nextOpts + 1] = e.Raw end
                                nextOpts[#nextOpts + 1] = option
                                local retained = selectedValues()
                                entries = makeEntries(nextOpts)
                                setSelection(retained, true)
                                if popupOpen then closeCurrentPopup() end
                                refreshLabel()
                                obj.CurrentOption = multi and selectedValues() or selectedValues()[1]
                                return obj.CurrentOption
                        end
                        function obj:Remove(option)
                                if option == nil then return obj.CurrentOption end
                                local nextOpts, removed = {}, {}
                                for _, e in ipairs(entries) do
                                        if matches(e, option) then
                                                removed[#removed + 1] = e.Value
                                        else
                                                nextOpts[#nextOpts + 1] = e.Raw
                                        end
                                end
                                if #removed == 0 then return obj.CurrentOption end
                                local retained = {}
                                for _, v in ipairs(selectedValues()) do
                                        local stillThere = false
                                        for _, gone in ipairs(removed) do
                                                if v == gone then stillThere = true end
                                        end
                                        if not stillThere then retained[#retained + 1] = v end
                                end
                                entries = makeEntries(nextOpts)
                                setSelection(retained, true)
                                if popupOpen then closeCurrentPopup() end
                                refreshLabel()
                                obj.CurrentOption = multi and selectedValues() or selectedValues()[1]
                                return obj.CurrentOption
                        end
                        function obj:Get() return obj.CurrentOption end
                        function obj:Reset()
                                setSelection(multi and defaultValues or defaultValues[1], false)
                                refreshLabel()
                                fire()
                                return obj.CurrentOption
                        end

                        onTheme(function()
                                if popupOpen then closeCurrentPopup() end
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(label, T20, { TextColor3 = C.text })
                                Tween(arrow, T20, { TextColor3 = C.muted })
                        end)
                        applyTooltip(holder, dcfg.Tooltip)
                        registerFlag(dcfg.Flag, obj)
                        return obj
                end

                -- ========================================================
                -- CreateKeybind({ Name, CurrentKeybind, HoldToInteract,
                --                 Flag, Callback })
                -- Functional: click the pill to rebind (next key pressed
                -- becomes the bind, Escape cancels). Global listener fires
                -- Callback when the bound key is pressed anywhere (skipped
                -- while a TextBox is focused). HoldToInteract fires
                -- Callback(true) on press / Callback(false) on release.
                -- ========================================================
                function tab:CreateKeybind(kcfg)
                        kcfg = kcfg or {}
                        local nameText = kcfg.Name or "Keybind"
                        local callback = kcfg.Callback
                        local changedCallback = kcfg.ChangedCallback or kcfg.OnChanged
                        local hold     = kcfg.HoldToInteract == true
                        local bound    = kcfg.CurrentKeybind -- Enum.KeyCode or string
                        if type(bound) == "string" then
                                local ok, kc = pcall(function() return Enum.KeyCode[bound] end)
                                bound = ok and kc or nil
                        end
                        local defaultKey = bound
                        local listening = false

                        local holder, hStroke = makeHolder(D.row) -- [v5.0.0] was 38 — below the 44px touch minimum
                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, -104, 1, 0)
                        lbl.Position = UDim2.new(0, 12, 0, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.Gotham
                        lbl.TextSize = 13
                        lbl.TextColor3 = C.textDim
                        lbl.TextXAlignment = Enum.TextXAlignment.Left
                        lbl.Text = nameText
                        lbl.Parent = holder
                        -- [v4.0] Optional asset icon (number id / rbx URI).
                        applyElementIcon(holder, kcfg.Icon, lbl)

                        local pill = Instance.new("TextButton")
                        pill.Size = UDim2.new(0, 88, 0, 24)
                        pill.Position = UDim2.new(1, -96, 0.5, -12)
                        pill.BackgroundColor3 = C.accentDark
                        pill.Text = ""
                        pill.AutoButtonColor = false
                        pill.BorderSizePixel = 0
                        pill.Selectable = true
                        pill.Parent = holder
                        corner(pill, PILL)
                        local pillStroke = stroke(pill, C.accentDim, 1)

                        local keyLbl = Instance.new("TextLabel")
                        keyLbl.Size = UDim2.new(1, 0, 1, 0)
                        keyLbl.BackgroundTransparency = 1
                        keyLbl.Font = Enum.Font.GothamBold
                        keyLbl.TextSize = 11
                        keyLbl.TextColor3 = C.accent
                        keyLbl.Text = keyName(bound)
                        keyLbl.Parent = pill

                        -- [v5.1.0] PULSE RING (spec): a breathing neon ring around
                        -- the pill while listening for a key, plus a low-frequency
                        -- hum (opt-in sounds) until capture. Snap-confirm chime on
                        -- a successful rebind.
                        local pulseRing = Instance.new("Frame")
                        pulseRing.Name = "ListenPulseRing"
                        pulseRing.Size = UDim2.new(1, 10, 1, 10)
                        pulseRing.AnchorPoint = Vector2.new(0.5, 0.5)
                        pulseRing.Position = UDim2.new(0.5, 0, 0.5, 0)
                        pulseRing.BackgroundColor3 = C.accent
                        pulseRing.BackgroundTransparency = 1
                        pulseRing.BorderSizePixel = 0
                        pulseRing.ZIndex = 1
                        pulseRing.Visible = false
                        pulseRing.Parent = pill
                        corner(pulseRing, PILL)

                        local obj = { CurrentKeybind = bound }

                                local rebindCatcher = nil  -- set when rebind mode starts

                                local pulseLoopToken = 0
                                local function stopListening(newKey)
                                        listening = false
                                        anyKeybindListening = false
                                        pulseLoopToken = pulseLoopToken + 1 -- kills the breathing loop
                                        stopHum()
                                        pulseRing.Visible = false
                                        if rebindCatcher then rebindCatcher:Destroy() rebindCatcher = nil end
                                if newKey ~= nil then
                                        -- [v5.4.0] KEYBIND CLASH GUARD (Rayfield pattern): refuse
                                        -- to bind the window's own UI-toggle key — the user
                                        -- would lock themselves out of the interface the
                                        -- moment their script starts listening for it.
                                        -- Warn + notify so it is obvious WHY nothing bound.
                                        if newKey == toggleKey then
                                                notify("Keybind",
                                                        "That key toggles this interface — pick another.",
                                                        4, "warning")
                                                warn("[RezurXLib] Keybind '" .. nameText
                                                        .. "' refused: " .. keyName(newKey)
                                                        .. " is the window toggle key (Window:SetToggleKeybind).")
                                        else
                                                bound = newKey
                                                obj.CurrentKeybind = bound
                                                -- [v5.1.0] snap confirmation
                                                playSfx("Confirm")
                                                Library.SafeCallback({
                                                        frame = holder, label = lbl,
                                                        name = "Keybind '" .. nameText .. "' (ChangedCallback)",
                                                        baseBg = C.panel, baseText = C.text,
                                                }, changedCallback, bound, obj)
                                        end
                                end
                                keyLbl.Text = keyName(bound)
                                Tween(pill, T15, { BackgroundColor3 = C.accentDark })
                                Tween(pillStroke, T15, { Color = C.accentDim, Thickness = 1 })
                        end

                        pill.MouseEnter:Connect(function()
                                if not listening then
                                        Tween(pill, T10, { BackgroundColor3 = C.accentDim })
                                end
                        end)
                        pill.MouseLeave:Connect(function()
                                if not listening then
                                        Tween(pill, T10, { BackgroundColor3 = C.accentDark })
                                end
                        end)
                        pill.Activated:Connect(function()
                                if listening then
                                        stopListening(nil)
                                        return
                                end
                                if anyKeybindListening then return end -- another keybind is already being rebound
                                listening = true
                                anyKeybindListening = true
                                keyLbl.Text = "..."
                                Tween(pill, T15, { BackgroundColor3 = C.panelHov })
                                Tween(pillStroke, T15, { Color = C.accent, Thickness = 1.5 })
                                -- [v5.1.0] breathing ring + low hum while listening
                                pulseRing.Visible = true
                                playSfx("Hum")
                                local myToken = pulseLoopToken + 1
                                pulseLoopToken = myToken
                                task.spawn(function()
                                        while listening and pulseLoopToken == myToken and pulseRing.Parent do
                                                Tween(pulseRing, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                                                        { BackgroundTransparency = 0.82 })
                                                task.wait(0.6)
                                                if not (listening and pulseLoopToken == myToken) then break end
                                                Tween(pulseRing, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                                                        { BackgroundTransparency = 1 })
                                                task.wait(0.6)
                                        end
                                end)
                                -- Catcher: clicking outside the pill cancels rebind
                                rebindCatcher = Instance.new("TextButton")
                                rebindCatcher.Size = UDim2.new(1, 0, 1, 0)
                                rebindCatcher.BackgroundTransparency = 1
                                rebindCatcher.Text = ""
                                rebindCatcher.AutoButtonColor = false
                                rebindCatcher.Active = true
                                rebindCatcher.ZIndex = 1000
                                rebindCatcher.Parent = overlayGui
                                rebindCatcher.Activated:Connect(function()
                                        stopListening(nil)
                                end)
                        end)

                        WindowJanitor:Add(UserInputService.InputBegan:Connect(function(inp, gp)
                                if listening then
                                        if inp.UserInputType == Enum.UserInputType.Keyboard then
                                                if inp.KeyCode == Enum.KeyCode.Escape then
                                                        stopListening(nil)
                                                else
                                                        stopListening(inp.KeyCode)
                                                end
                                        end
                                        return
                                end
                                if gp then return end
                                if anyKeybindListening then return end -- a different keybind is being rebound right now
                                if bound and inp.KeyCode == bound and not UserInputService:GetFocusedTextBox() then
                                        Tween(pill, TPRESS, { BackgroundColor3 = C.accentDim })
                                        task.delay(0.12, function()
                                                if not listening then
                                                        Tween(pill, T15, { BackgroundColor3 = C.accentDark })
                                                end
                                        end)
                                        if callback then
                                                -- [v5.4.0] SafeCallback funnel: task.spawn
                                                -- isolation + row error flash (hold and tap
                                                -- paths share the surface).
                                                local kbSurf = {
                                                        frame = holder, label = lbl,
                                                        name = "Keybind '" .. nameText .. "'",
                                                        baseBg = C.panel, baseText = C.text,
                                                }
                                                if hold then
                                                        Library.SafeCallback(kbSurf, callback, true)
                                                else
                                                        Library.SafeCallback(kbSurf, callback)
                                                end
                                        end
                                end
                        end))
                        if hold then
                                WindowJanitor:Add(UserInputService.InputEnded:Connect(function(inp)
                                        if bound and inp.KeyCode == bound and not listening then
                                                if callback then
                                                        Library.SafeCallback(kbSurf, callback, false)
                                                end
                                        end
                                end))
                        end

                        function obj:Set(newKey)
                                if type(newKey) == "string" then
                                        local ok, kc = pcall(function() return Enum.KeyCode[newKey] end)
                                        newKey = ok and kc or nil
                                end
                                bound = newKey
                                obj.CurrentKeybind = bound
                                keyLbl.Text = keyName(bound)
                        end
                        function obj:Get() return bound end
                        function obj:Reset() obj:Set(defaultKey) end

                        onTheme(function()
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(lbl, T20, { TextColor3 = C.textDim })
                                Tween(pill, T20, { BackgroundColor3 = C.accentDark })
                                Tween(pillStroke, T20, { Color = C.accentDim })
                                Tween(keyLbl, T20, { TextColor3 = C.accent })
                        end)
                        registerFlag(kcfg.Flag, obj)
                        return obj
                end

                -- ========================================================
                -- CreateColorPicker({ Name, Color, Flag, Callback })
                -- ========================================================
                function tab:CreateColorPicker(ccfg)
                        ccfg = ccfg or {}
                        local nameText = ccfg.Name or "Color"
                        local callback = ccfg.Callback
                        local presets = type(ccfg.Presets) == "table" and ccfg.Presets or {}
                        local initialColor = typeof(ccfg.Color) == "Color3" and ccfg.Color or C.white

                        local holder, hStroke = makeHolder(D.row)
                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, -78, 1, 0)
                        lbl.Position = UDim2.new(0, 14, 0, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamMedium
                        lbl.TextSize = 13
                        lbl.TextColor3 = C.text
                        lbl.TextXAlignment = Enum.TextXAlignment.Left
                        lbl.Text = nameText
                        lbl.Parent = holder
                        -- [v4.0] Optional asset icon (number id / rbx URI).
                        applyElementIcon(holder, ccfg.Icon, lbl)

                        local swatch = Instance.new("TextButton")
                        swatch.Size = UDim2.new(0, 58, 0, 30)
                        swatch.Position = UDim2.new(1, -66, 0.5, -15)
                        swatch.BackgroundColor3 = initialColor
                        swatch.Text = ""
                        swatch.AutoButtonColor = false
                        swatch.BorderSizePixel = 0
                        swatch.Selectable = true
                        swatch.Parent = holder
                        corner(swatch, R.small)
                        stroke(swatch, C.border, 1.5)

                        local obj = { Color = initialColor }
                        local defaultColor = obj.Color

                        -- [v5.4.0] SafeCallback error surface for this picker row.
                        -- Declared before openPicker/update so every callback path
                        -- (live HSV drag, preset click, programmatic Set) shares it.
                        local cpSurf = {
                                frame = holder, label = lbl,
                                name = "ColorPicker '" .. nameText .. "'",
                                baseBg = C.panel, baseText = C.text,
                        }

                        local function openPicker()
                                closeCurrentPopup()
                                local h, s, v = obj.Color:ToHSV()

                                local catcher = Instance.new("TextButton")
                                catcher.Size = UDim2.new(1, 0, 1, 0)
                                catcher.BackgroundColor3 = C.black
                                catcher.BackgroundTransparency = 1
                                catcher.Text = ""
                                catcher.AutoButtonColor = false
                                catcher.Active = true
                                catcher.ZIndex = 8
                                catcher.Parent = overlayGui
                                Tween(catcher, T15, { BackgroundTransparency = 0.5 })

                                local sp = swatch.AbsolutePosition
                                local cam = workspace.CurrentCamera
                                local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
                                local panelHeight = #presets > 0 and 316 or 280
                                local px = math.clamp(sp.X - 160, 10, math.max(10, vp.X - 280))
                                local py = math.clamp(sp.Y - panelHeight + 10, 10, math.max(10, vp.Y - panelHeight - 10))

                                local panel = Instance.new("Frame")
                                panel.Size = UDim2.new(0, 270, 0, panelHeight)
                                panel.Position = UDim2.new(0, px, 0, py)
                                panel.BackgroundColor3 = C.panel
                                panel.BorderSizePixel = 0
                                panel.Active = true
                                panel.ZIndex = 9
                                panel.Parent = overlayGui
                                corner(panel, R.panel)
                                stroke(panel, C.accent, 1.5)
                                -- [v5.0.0] Entrance: fade + 8px rise (position-based;
                                -- UIScale would re-rasterize the corners every frame).
                                do
                                        panel.AnchorPoint = Vector2.new(0.5, 0.5)
                                        local restY = py + panelHeight / 2
                                        panel.Position = UDim2.new(0, px + 135, 0, restY + 8)
                                        panel.BackgroundTransparency = 0.35
                                        Tween(panel, MT.enter, {
                                                Position = UDim2.new(0, px + 135, 0, restY),
                                                BackgroundTransparency = 0,
                                        })
                                end

                                local pTtl = Instance.new("TextLabel")
                                pTtl.Size = UDim2.new(1, -72, 0, 20)
                                pTtl.Position = UDim2.new(0, 14, 0, 10)
                                pTtl.BackgroundTransparency = 1
                                pTtl.Font = Enum.Font.GothamBold
                                pTtl.TextSize = 13
                                pTtl.TextColor3 = C.accent
                                pTtl.TextXAlignment = Enum.TextXAlignment.Left
                                pTtl.Text = nameText
                                pTtl.ZIndex = 9
                                pTtl.Parent = panel

                                local preview = Instance.new("Frame")
                                preview.Size = UDim2.new(0, 40, 0, 40)
                                preview.Position = UDim2.new(1, -52, 0, 10)
                                preview.BackgroundColor3 = obj.Color
                                preview.BorderSizePixel = 0
                                preview.ZIndex = 9
                                preview.Parent = panel
                                corner(preview, R.small)
                                stroke(preview, C.border, 1.5)

                                -- HSV color pad (saturation x value)
                                local pad = Instance.new("TextButton")
                                pad.Size = UDim2.new(0, 200, 0, 150)
                                pad.Position = UDim2.new(0, 14, 0, 40)
                                pad.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                                pad.AutoButtonColor = false
                                pad.BorderSizePixel = 0
                                pad.Text = ""
                                pad.ZIndex = 9
                                pad.Parent = panel
                                corner(pad, R.small)
                                -- White gradient (left to right = saturation)
                                local padWhite = Instance.new("Frame")
                                padWhite.Size = UDim2.new(1, 0, 1, 0)
                                padWhite.BackgroundColor3 = C.white
                                padWhite.BackgroundTransparency = 0
                                padWhite.BorderSizePixel = 0
                                padWhite.ZIndex = 9
                                padWhite.Parent = pad
                                local padWhiteGrad = Instance.new("UIGradient")
                                padWhiteGrad.Color = ColorSequence.new(C.white, Color3.new(0,0,0))
                                padWhiteGrad.Transparency = NumberSequence.new(0, 1)
                                padWhiteGrad.Parent = padWhite
                                -- Black gradient (top to bottom = value)
                                local padBlack = Instance.new("Frame")
                                padBlack.Size = UDim2.new(1, 0, 1, 0)
                                padBlack.BackgroundColor3 = C.black
                                padBlack.BorderSizePixel = 0
                                padBlack.ZIndex = 10
                                padBlack.Parent = pad
                                local padBlackGrad = Instance.new("UIGradient")
                                padBlackGrad.Color = ColorSequence.new(C.black, Color3.new(0,0,0))
                                padBlackGrad.Transparency = NumberSequence.new(1, 0)
                                padBlackGrad.Rotation = 90
                                padBlackGrad.Parent = padBlack

                                -- Pointer on the pad
                                local pointer = Instance.new("Frame")
                                pointer.Size = UDim2.new(0, 10, 0, 10)
                                pointer.AnchorPoint = Vector2.new(0.5, 0.5)
                                pointer.Position = UDim2.new(s, 0, 1 - v, 0)
                                pointer.BackgroundColor3 = C.white
                                pointer.BorderSizePixel = 0
                                pointer.ZIndex = 12
                                pointer.Parent = pad
                                corner(pointer, UDim.new(1, 0))
                                stroke(pointer, C.black, 1.5)

                                -- Hue slider (rainbow)
                                local hueSlider = Instance.new("TextButton")
                                hueSlider.Size = UDim2.new(0, 200, 0, 14)
                                hueSlider.Position = UDim2.new(0, 14, 0, 200)
                                hueSlider.BackgroundColor3 = C.white
                                hueSlider.AutoButtonColor = false
                                hueSlider.BorderSizePixel = 0
                                hueSlider.Text = ""
                                hueSlider.ZIndex = 9
                                hueSlider.Parent = panel
                                corner(hueSlider, UDim.new(1, 0))
                                local hueGrad = Instance.new("UIGradient")
                                hueGrad.Color = ColorSequence.new({
                                        ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
                                        ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
                                        ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
                                        ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
                                        ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
                                        ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
                                        ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
                                })
                                hueGrad.Parent = hueSlider

                                local hueKnob = Instance.new("Frame")
                                hueKnob.Size = UDim2.new(0, 6, 0, 18)
                                hueKnob.AnchorPoint = Vector2.new(0.5, 0.5)
                                hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
                                hueKnob.BackgroundColor3 = C.white
                                hueKnob.BorderSizePixel = 0
                                hueKnob.ZIndex = 10
                                hueKnob.Parent = hueSlider
                                corner(hueKnob, UDim.new(1, 0))
                                stroke(hueKnob, C.black, 1.5)

                                -- Hex display
                                -- [v5.1.0] GLASS RADIAL EXPANDER hex copier: the hex
                                -- chip is click-to-copy (executor setclipboard when
                                -- present) with a snap-confirm toast.
                                local hexLbl = Instance.new("TextButton")
                                hexLbl.Name = "HexCopy"
                                hexLbl.Size = UDim2.new(0, 120, 0, 20)
                                hexLbl.Position = UDim2.new(0, 14, 0, 225)
                                hexLbl.BackgroundTransparency = 1
                                hexLbl.Font = Enum.Font.Code
                                hexLbl.TextSize = 12
                                hexLbl.TextColor3 = C.muted
                                hexLbl.TextXAlignment = Enum.TextXAlignment.Left
                                hexLbl.AutoButtonColor = false
                                hexLbl.ZIndex = 9
                                hexLbl.Parent = panel
                                hexLbl.Activated:Connect(function()
                                        local hexText = hexLbl.Text
                                        local copied = false
                                        if type(setclipboard) == "function" then
                                                copied = pcall(setclipboard, hexText)
                                        end
                                        playSfx("Confirm")
                                        notify("Color Picker", copied and ("Copied " .. hexText .. " to clipboard.")
                                                or (hexText .. " (clipboard unavailable)"), 3, "success")
                                end)

                                -- Done button
                                local doneBtn = Instance.new("TextButton")
                                doneBtn.Size = UDim2.new(0, 80, 0, 28)
                                doneBtn.Position = UDim2.new(1, -92, 0, #presets > 0 and 278 or 240)
                                doneBtn.BackgroundColor3 = C.accent
                                doneBtn.Text = "Done"
                                doneBtn.Font = Enum.Font.GothamBold
                                doneBtn.TextSize = 13
                                doneBtn.TextColor3 = C.white
                                doneBtn.BorderSizePixel = 0
                                doneBtn.AutoButtonColor = false
                                doneBtn.ZIndex = 10
                                doneBtn.Parent = panel
                                corner(doneBtn, R.small)

                                -- Update function — fires callback LIVE.
                                -- [FIX v4.0] Split into render + notify. The old code called
                                -- update() once on open, which fired the live callback
                                -- immediately — opening a picker triggered the user's
                                -- side effects (team color, remote event) with a
                                -- slightly-quantized HSV round-trip color before any
                                -- interaction. Rendering no longer notifies; only
                                -- user-driven paths (pad/hue drag, presets, :Set) do.
                                local function render()
                                        obj.Color = Color3.fromHSV(h, s, v)
                                        swatch.BackgroundColor3 = obj.Color
                                        preview.BackgroundColor3 = obj.Color
                                        pad.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                                        pointer.Position = UDim2.new(s, 0, 1 - v, 0)
                                        hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
                                        local r2, g2, b2 = math.floor(obj.Color.R * 255 + 0.5), math.floor(obj.Color.G * 255 + 0.5), math.floor(obj.Color.B * 255 + 0.5)
                                        hexLbl.Text = string.format("#%02X%02X%02X", r2, g2, b2)
                                        end
                                local function update()
                                        render()
                                        -- [v5.4.0] SafeCallback funnel: a throwing
                                        -- consumer callback flashes the picker's row
                                        -- instead of dying inside the HSV drag loop.
                                        Library.SafeCallback(cpSurf, callback, obj.Color)
                                end
                                render()

                                -- Optional presets provide fast, predictable choices
                                -- without making users hunt through the HSV surface.
                                if #presets > 0 then
                                        local presetCount = math.min(#presets, 8)
                                        for index = 1, presetCount do
                                                local preset = presets[index]
                                                if typeof(preset) == "Color3" then
                                                        local presetButton = Instance.new("TextButton")
                                                        presetButton.Size = UDim2.new(0, 25, 0, 20)
                                                        presetButton.Position = UDim2.new(0, 14 + (index - 1) * 29, 0, 248)
                                                        presetButton.BackgroundColor3 = preset
                                                        presetButton.BorderSizePixel = 0
                                                        presetButton.Text = ""
                                                        presetButton.AutoButtonColor = false
                                                        presetButton.ZIndex = 10
                                                        presetButton.Parent = panel
                                                        presetButton.Selectable = true
                                                        corner(presetButton, 5)
                                                        stroke(presetButton, C.border, 1)
                                                        presetButton.Activated:Connect(function()
                                                                h, s, v = preset:ToHSV()
                                                                update()
                                                        end)
                                                end
                                        end
                                end

                                -- Pad drag — uses InputBegan for mouse+touch support
                                pad.InputBegan:Connect(function(inp)
                                        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                                                registerDrag(pad, inp, function(pos)
                                                        local px2 = math.clamp((pos.X - pad.AbsolutePosition.X) / math.max(pad.AbsoluteSize.X, 1), 0, 1)
                                                        local py2 = math.clamp((pos.Y - pad.AbsolutePosition.Y) / math.max(pad.AbsoluteSize.Y, 1), 0, 1)
                                                        s = px2
                                                        v = 1 - py2
                                                        update()
                                                end)
                                                -- Set initial position
                                                s = math.clamp((inp.Position.X - pad.AbsolutePosition.X) / math.max(pad.AbsoluteSize.X, 1), 0, 1)
                                                v = 1 - math.clamp((inp.Position.Y - pad.AbsolutePosition.Y) / math.max(pad.AbsoluteSize.Y, 1), 0, 1)
                                                update()
                                        end
                                end)

                                -- Hue slider drag — uses InputBegan for mouse+touch
                                hueSlider.InputBegan:Connect(function(inp)
                                        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                                                registerDrag(hueSlider, inp, function(pos)
                                                        h = math.clamp((pos.X - hueSlider.AbsolutePosition.X) / math.max(hueSlider.AbsoluteSize.X, 1), 0, 1)
                                                        update()
                                                end)
                                                h = math.clamp((inp.Position.X - hueSlider.AbsolutePosition.X) / math.max(hueSlider.AbsoluteSize.X, 1), 0, 1)
                                                update()
                                        end
                                end)

                                -- [FIX] Was: bespoke closePopup() + currentPopupJanitor = nil
                                -- directly, same anti-pattern as Dropdown had — this popup was
                                -- never tracked, so opening a different popup while the color
                                -- picker was open left its full-screen catcher + panel stuck on
                                -- screen permanently. Same Janitor fix applied here.
                                doneBtn.Activated:Connect(closeCurrentPopup)
                                catcher.Activated:Connect(closeCurrentPopup)

                                local pj = Janitor.new()
                                pj:Add(catcher, "Destroy")
                                pj:Add(panel, "Destroy")
                                currentPopupJanitor = pj
                        end

                        swatch.Activated:Connect(openPicker)

                        function obj:Set(color)
                                if typeof(color) ~= "Color3" then
                                        warn("[RezurXLib] ColorPicker:Set expects a Color3.")
                                        return nil
                                end
                                obj.Color = color
                                swatch.BackgroundColor3 = color
                                Library.SafeCallback(cpSurf, callback, color)
                                return color
                        end
                        function obj:Get() return obj.Color end
                        function obj:Reset()
                                self:Set(defaultColor)
                        end

                        onTheme(function()
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(lbl, T20, { TextColor3 = C.text })
                        end)
                        registerFlag(ccfg.Flag, obj)
                        return obj
                end

                -- Short-form aliases, assigned directly onto tab — both
                -- tab:CreateButton(...) and tab:Button(...) work with zero
                -- collision, since they're just two different keys on the same
                -- table. [FIX] This used to return a metatable-proxy wrapper
                -- instead of tab itself, solving a collision problem that never
                -- existed (a table can hold both keys directly, no wrapper
                -- needed) while introducing two real ones: any future method
                -- that referenced `self` would silently get the wrapper instead
                -- of the real tab when called as Wrapper:Method(...), and
                -- pairs()/ipairs() on the returned Tab object iterated an empty
                -- table since the wrapper had no fields of its own.
                function tab:CreateAccordion(acfg)
                        acfg = acfg or {}
                        local titleText = acfg.Title or "Accordion"
                        local expanded = acfg.DefaultExpanded == true
                        local headerBtn = Instance.new("TextButton")
                        headerBtn.Name = "AccordionHeader"
                        headerBtn.Size = UDim2.new(1, 0, 0, 36)
                        headerBtn.BackgroundColor3 = C.panelAlt
                        headerBtn.Text = ""
                        headerBtn.AutoButtonColor = false
                        headerBtn.BorderSizePixel = 0
                        headerBtn.Selectable = true
                        headerBtn.Parent = page
                        corner(headerBtn, R.panel)
                        local accStroke = stroke(headerBtn, C.border, 1)
                        local arrow = Instance.new("TextLabel")
                        arrow.Size = UDim2.new(0, 20, 1, 0)
                        arrow.Position = UDim2.new(0, 8, 0, 0)
                        arrow.BackgroundTransparency = 1
                        arrow.Font = Enum.Font.GothamBold
                        arrow.TextSize = 12
                        arrow.TextColor3 = C.accent
                        arrow.Text = expanded and "▼" or "▶"
                        arrow.Parent = headerBtn
                        local ttl = Instance.new("TextLabel")
                        ttl.Size = UDim2.new(1, -36, 1, 0)
                        ttl.Position = UDim2.new(0, 28, 0, 0)
                        ttl.BackgroundTransparency = 1
                        ttl.Font = Enum.Font.GothamBold
                        ttl.TextSize = 12
                        ttl.TextColor3 = C.text
                        ttl.TextXAlignment = Enum.TextXAlignment.Left
                        ttl.Text = titleText
                        ttl.Parent = headerBtn
                        local container = Instance.new("Frame")
                        container.Name = "AccordionContent"
                        container.Size = UDim2.new(1, 0, 0, 0)
                        container.BackgroundColor3 = C.panel
                        container.BorderSizePixel = 0
                        container.ClipsDescendants = true
                        container.Visible = expanded
                        container.Parent = page
                        corner(container, R.panel)
                        stroke(container, C.border, 1)
                        pad(container, 8, 8, 10, 10)
                        local cLayout = Instance.new("UIListLayout")
                        cLayout.Padding = UDim.new(0, 6)
                        cLayout.SortOrder = Enum.SortOrder.LayoutOrder
                        cLayout.Parent = container
                        local function refreshSize()
                                container.Size = UDim2.new(1, 0, 0, cLayout.AbsoluteContentSize.Y + 16)
                        end
                        cLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshSize)
                        task.defer(refreshSize)
                        local obj = {}
                        function obj:SetExpanded(e)
                                expanded = e
                                arrow.Text = expanded and "▼" or "▶"
                                if expanded then
                                        container.Visible = true
                                        refreshSize()
                                        Tween(container, T20, { BackgroundTransparency = 0 })
                                else
                                        Tween(container, T20, { BackgroundTransparency = 1 })
                                        task.delay(0.2, function() if not expanded then container.Visible = false end end)
                                end
                        end
                        function obj:Toggle() obj:SetExpanded(not expanded) end
                        function obj:GetContainer() return container end
                        headerBtn.Activated:Connect(function() obj:Toggle() end)
                        headerBtn.MouseEnter:Connect(function() Tween(headerBtn, T10, { BackgroundColor3 = C.panelHov }) end)
                        headerBtn.MouseLeave:Connect(function() Tween(headerBtn, T10, { BackgroundColor3 = C.panelAlt }) end)
                        onTheme(function()
                                Tween(headerBtn, T20, { BackgroundColor3 = C.panelAlt })
                                Tween(accStroke, T20, { Color = C.border })
                                Tween(arrow, T20, { TextColor3 = C.accent })
                                Tween(ttl, T20, { TextColor3 = C.text })
                                Tween(container, T20, { BackgroundColor3 = C.panel })
                        end)
                        applyTooltip(headerBtn, acfg.Tooltip)
                        return obj
                end

                function tab:CreateBindable(bcfg)
                        bcfg = bcfg or {}
                        local nameText = bcfg.Name or "Bindable"
                        local callback = bcfg.Callback
                        local enabled = bcfg.Enabled ~= false
                        local bound = bcfg.Keybind
                        if type(bound) == "string" then
                                local ok, kc = pcall(function() return Enum.KeyCode[bound] end)
                                bound = ok and kc or Enum.KeyCode.E
                        elseif bound == nil then
                                bound = Enum.KeyCode.E
                        end
                        local holder, hStroke = makeHolder(D.row)
                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, -100, 1, 0)
                        lbl.Position = UDim2.new(0, 14, 0, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamMedium
                        lbl.TextSize = 13
                        lbl.TextColor3 = C.text
                        lbl.TextXAlignment = Enum.TextXAlignment.Left
                        lbl.Text = nameText
                        lbl.Parent = holder
                        local enSw = Instance.new("Frame")
                        enSw.Size = UDim2.new(0, 32, 0, 18)
                        enSw.Position = UDim2.new(1, -84, 0.5, -9)
                        enSw.BackgroundColor3 = enabled and C.accent or C.track
                        enSw.BorderSizePixel = 0
                        enSw.Parent = holder
                        corner(enSw, UDim.new(1, 0))
                        local enKnob = Instance.new("Frame")
                        enKnob.Size = UDim2.new(0, 14, 0, 14)
                        enKnob.Position = enabled and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
                        enKnob.BackgroundColor3 = C.white
                        enKnob.BorderSizePixel = 0
                        enKnob.Parent = enSw
                        corner(enKnob, UDim.new(1, 0))
                        local pill = Instance.new("TextLabel")
                        pill.Size = UDim2.new(0, 44, 0, 20)
                        pill.Position = UDim2.new(1, -48, 0.5, -10)
                        pill.BackgroundColor3 = C.accentDark
                        pill.Font = Enum.Font.GothamBold
                        pill.TextSize = 10
                        pill.TextColor3 = C.accent
                        pill.Text = keyName(bound)
                        pill.Parent = holder
                        corner(pill, PILL)
                        stroke(pill, C.accentDim, 1)
                        local obj = { Enabled = enabled, Keybind = bound }
                        local function updateState()
                                Tween(enSw, T20, { BackgroundColor3 = enabled and C.accent or C.track })
                                Tween(enKnob, T50, { Position = enabled and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7) })
                        end
                        local enHit = Instance.new("TextButton")
                        enHit.Size = UDim2.new(0, 36, 1, 0)
                        enHit.Position = UDim2.new(1, -86, 0, 0)
                        enHit.BackgroundTransparency = 1
                        enHit.Text = ""
                        enHit.AutoButtonColor = false
                        enHit.ZIndex = 10
                        enHit.Selectable = true
                        enHit.Parent = holder
                        enHit.Activated:Connect(function()
                                enabled = not enabled
                                obj.Enabled = enabled
                                updateState()
                        end)
                        WindowJanitor:Add(UserInputService.InputBegan:Connect(function(inp, gp)
                                if gp then return end
                                if not enabled then return end
                                if UserInputService:GetFocusedTextBox() then return end
                                if inp.KeyCode == bound and callback then
                                        Library.SafeCallback({
                                                frame = holder, label = lbl,
                                                name = "Bindable '" .. nameText .. "'",
                                                baseBg = C.panel, baseText = C.text,
                                        }, callback, enabled)
                                end
                        end))
                        function obj:SetEnabled(v) enabled = v obj.Enabled = v updateState() end
                        function obj:SetKeybind(kc) bound = kc obj.Keybind = kc pill.Text = keyName(kc) end
                        onTheme(function()
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(lbl, T20, { TextColor3 = C.text })
                                Tween(enSw, T20, { BackgroundColor3 = enabled and C.accent or C.track })
                                Tween(pill, T20, { BackgroundColor3 = C.accentDark })
                        end)
                        applyTooltip(holder, bcfg.Tooltip)
                        registerFlag(bcfg.Flag, obj)
                        return obj
                end

                -- ========================================================
                -- DEVELOPER COMPONENTS
                -- Purpose-built components for production tools. They share
                -- the same token vocabulary and lifecycle rules as the core
                -- controls above, rather than acting as one-off visual skins.
                -- ========================================================
                local function semanticColor(kind)
                        kind = string.lower(tostring(kind or "info"))
                        if kind == "success" or kind == "online" or kind == "healthy" then return C.green end
                        if kind == "warning" or kind == "pending" or kind == "idle" then return C.yellow end
                        if kind == "error" or kind == "danger" or kind == "offline" then return C.red end
                        return C.accent
                end

                local function semanticGlyph(kind)
                        kind = string.lower(tostring(kind or "info"))
                        if kind == "success" or kind == "online" or kind == "healthy" then return "OK" end
                        if kind == "warning" or kind == "pending" or kind == "idle" then return "!" end
                        if kind == "error" or kind == "danger" or kind == "offline" then return "X" end
                        return "i"
                end

                -- A notice is deliberately an inline, semantic component—not
                -- an interrupting modal. Use it for durable information users
                -- should see while completing their work.
                function tab:CreateNotice(ncfg)
                        ncfg = ncfg or {}
                        local holder, hStroke = makeHolder(ncfg.Height or 76)
                        holder.Name = "Notice"

                        local icon = Instance.new("TextLabel")
                        icon.Size = UDim2.new(0, 30, 0, 30)
                        icon.Position = UDim2.new(0, 14, 0, 14)
                        icon.BackgroundColor3 = C.accentDark
                        icon.BorderSizePixel = 0
                        icon.Font = Enum.Font.GothamBold
                        icon.TextSize = 11
                        icon.TextColor3 = C.accentHi
                        icon.ZIndex = 2
                        icon.Parent = holder
                        corner(icon, R.small)

                        local title = Instance.new("TextLabel")
                        title.Size = UDim2.new(1, -64, 0, 18)
                        title.Position = UDim2.new(0, 56, 0, 11)
                        title.BackgroundTransparency = 1
                        title.Font = Enum.Font.GothamBold
                        title.TextSize = 13
                        title.TextColor3 = C.text
                        title.TextXAlignment = Enum.TextXAlignment.Left
                        title.TextTruncate = Enum.TextTruncate.AtEnd
                        title.ZIndex = 2
                        title.Parent = holder

                        local content = Instance.new("TextLabel")
                        content.Size = UDim2.new(1, -70, 0, 34)
                        content.Position = UDim2.new(0, 56, 0, 30)
                        content.BackgroundTransparency = 1
                        content.Font = Enum.Font.Gotham
                        content.TextSize = 11
                        content.TextColor3 = C.textDim
                        content.TextXAlignment = Enum.TextXAlignment.Left
                        content.TextYAlignment = Enum.TextYAlignment.Top
                        content.TextWrapped = true
                        content.ZIndex = 2
                        content.Parent = holder

                        local obj = {
                                Title = ncfg.Title or ncfg.Name or "Notice",
                                Content = ncfg.Content or ncfg.Description or "",
                                Type = ncfg.Type or "info",
                        }

                        local function render()
                                local color = semanticColor(obj.Type)
                                icon.Text = semanticGlyph(obj.Type)
                                title.Text = obj.Title
                                content.Text = obj.Content
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(icon, T20, { BackgroundColor3 = C.accentDark, TextColor3 = color })
                                Tween(title, T20, { TextColor3 = C.text })
                                Tween(content, T20, { TextColor3 = C.textDim })
                        end

                        function obj:Set(nextValue)
                                if type(nextValue) == "table" then
                                        obj.Title = nextValue.Title or nextValue.Name or obj.Title
                                        obj.Content = nextValue.Content or nextValue.Description or obj.Content
                                        obj.Type = nextValue.Type or obj.Type
                                else
                                        obj.Content = tostring(nextValue or "")
                                end
                                render()
                                return obj
                        end

                        function obj:SetType(nextType)
                                obj.Type = nextType or "info"
                                render()
                                return obj
                        end

                        function obj:Destroy()
                                holder:Destroy()
                        end

                        render()
                        onTheme(render)
                        applyTooltip(holder, ncfg.Tooltip)
                        return obj
                end

                -- Progress is useful for loading, synchronization, and long
                -- developer actions. It has explicit value semantics instead
                -- of a decorative animated bar.
                function tab:CreateProgress(pcfg)
                        pcfg = pcfg or {}
                        local holder, hStroke = makeHolder(pcfg.Height or 62)
                        holder.Name = "Progress"

                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, -92, 0, 18)
                        label.Position = UDim2.new(0, 14, 0, 9)
                        label.BackgroundTransparency = 1
                        label.Font = Enum.Font.GothamMedium
                        label.TextSize = 12
                        label.TextColor3 = C.text
                        label.TextXAlignment = Enum.TextXAlignment.Left
                        label.TextTruncate = Enum.TextTruncate.AtEnd
                        label.ZIndex = 2
                        label.Parent = holder

                        local value = Instance.new("TextLabel")
                        value.Size = UDim2.new(0, 66, 0, 18)
                        value.Position = UDim2.new(1, -80, 0, 9)
                        value.BackgroundTransparency = 1
                        value.Font = Enum.Font.Code
                        value.TextSize = 11
                        value.TextColor3 = C.textDim
                        value.TextXAlignment = Enum.TextXAlignment.Right
                        value.ZIndex = 2
                        value.Parent = holder

                        local track = Instance.new("Frame")
                        track.Size = UDim2.new(1, -28, 0, 8)
                        track.Position = UDim2.new(0, 14, 0, 37)
                        track.BackgroundColor3 = C.track
                        track.BorderSizePixel = 0
                        track.ClipsDescendants = true
                        track.ZIndex = 2
                        track.Parent = holder
                        corner(track, 4)

                        local fill = Instance.new("Frame")
                        fill.Size = UDim2.new(0, 0, 1, 0)
                        fill.BackgroundColor3 = C.accent
                        fill.BorderSizePixel = 0
                        fill.ZIndex = 3
                        fill.Parent = track
                        corner(fill, 4)

                        local obj = {
                                Name = pcfg.Name or pcfg.Title or "Progress",
                                Min = tonumber(pcfg.Min) or 0,
                                Max = tonumber(pcfg.Max) or 100,
                                CurrentValue = tonumber(pcfg.CurrentValue or pcfg.Value) or 0,
                                Suffix = pcfg.Suffix or "%",
                        }
                        if obj.Max <= obj.Min then obj.Max = obj.Min + 1 end
                        local defaultValue = obj.CurrentValue

                        local function render(animated)
                                obj.CurrentValue = math.clamp(obj.CurrentValue, obj.Min, obj.Max)
                                local ratio = (obj.CurrentValue - obj.Min) / (obj.Max - obj.Min)
                                label.Text = obj.Name
                                if pcfg.ShowValue == false then
                                        value.Text = ""
                                elseif obj.Suffix == "%" then
                                        value.Text = string.format("%d%%", math.floor(ratio * 100 + 0.5))
                                else
                                        value.Text = tostring(obj.CurrentValue) .. tostring(obj.Suffix)
                                end
                                if animated == false then
                                        fill.Size = UDim2.new(ratio, 0, 1, 0)
                                else
                                        Tween(fill, T20, { Size = UDim2.new(ratio, 0, 1, 0) })
                                end
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(label, T20, { TextColor3 = C.text })
                                Tween(value, T20, { TextColor3 = C.textDim })
                                Tween(track, T20, { BackgroundColor3 = C.track })
                                Tween(fill, T20, { BackgroundColor3 = pcfg.Color or C.accent })
                        end

                        function obj:Set(nextValue, silent)
                                obj.CurrentValue = tonumber(nextValue) or obj.CurrentValue
                                render(true)
                                if not silent and pcfg.Callback then
                                        pcall(pcfg.Callback, obj.CurrentValue, obj)
                                end
                                return obj.CurrentValue
                        end

                        function obj:Increment(amount, silent)
                                return obj:Set(obj.CurrentValue + (tonumber(amount) or 1), silent)
                        end

                        function obj:Get()
                                return obj.CurrentValue
                        end

                        function obj:Reset()
                                return obj:Set(defaultValue)
                        end

                        function obj:Destroy()
                                holder:Destroy()
                        end

                        render(false)
                        onTheme(function() render(false) end)
                        applyTooltip(holder, pcfg.Tooltip)
                        registerFlag(pcfg.Flag, obj)
                        return obj
                end

                -- ========================================================
                -- [v5.2.0] AddStatGrid({ Columns, UpdateRate, Height })
                -- Universal telemetry grid: live metric chips in an auto-
                -- wrapping grid. Game-agnostic — the developer mounts whatever
                -- trackers they need:
                --   local g = Tab:AddStatGrid({ Columns = 3, UpdateRate = 0.5 })
                --   g:AddChip({ Id = "fps", Icon = "⚡", Label = "FPS", Value = "60" })
                --   g:UpdateChip("fps", "59")
                -- Chips may carry Sample = function() return "…" end for
                -- automatic polling at UpdateRate.
                -- [v5.3.2] Declarative chips: gcfg.Chips = { {Id, Label, Value, Icon, Sample}, … }
                -- lets the developer define the entire grid in one call. Matches
                -- the pattern of CreateDropdown's Options array (a single table
                -- of pre-built children) — consumer scripts that pass Chips now
                -- Just Work instead of getting an empty grid.
                -- ========================================================
                function tab:AddStatGrid(gcfg)
                        gcfg = gcfg or {}
                        local columns = math.clamp(math.floor(tonumber(gcfg.Columns) or 3), 1, 6)
                        local updateRate = math.clamp(tonumber(gcfg.UpdateRate) or 0.5, 0.1, 30)
                        local chipH = gcfg.ChipHeight or 52

                        local holder = Instance.new("Frame")
                        holder.Name = "StatGrid"
                        holder.Size = UDim2.new(1, 0, 0, chipH)
                        holder.BackgroundTransparency = 1
                        holder.Parent = page

                        local grid = Instance.new("UIGridLayout")
                        grid.CellSize = UDim2.new(1 / columns, -6, 0, chipH)
                        grid.CellPadding = UDim2.new(0, 6, 0, 6)
                        grid.SortOrder = Enum.SortOrder.LayoutOrder
                        grid.FillDirectionMaxCells = columns
                        grid.Parent = holder

                        local chips = {}      -- id -> { obj, sample }
                        local chipCount = 0
                        local orderCounter = 0

                        local function relayout()
                                local rows = math.max(1, math.ceil(chipCount / columns))
                                holder.Size = UDim2.new(1, 0, 0, rows * chipH + (rows - 1) * 6)
                        end

                        local gridObj = {}
                        function gridObj:AddChip(ccfg)
                                ccfg = ccfg or {}
                                local id = tostring(ccfg.Id or ccfg.Label or ("chip" .. (orderCounter + 1)))
                                if chips[id] then return chips[id].obj end
                                orderCounter = orderCounter + 1
                                chipCount = chipCount + 1

                                local card = Instance.new("Frame")
                                card.Name = "StatChip_" .. id
                                card.LayoutOrder = orderCounter
                                card.BackgroundColor3 = C.panelAlt
                                card.BackgroundTransparency = 0.25
                                card.BorderSizePixel = 0
                                card.Parent = holder
                                corner(card, R.control)

                                local topRow = Instance.new("Frame")
                                topRow.Size = UDim2.new(1, -16, 0, 14)
                                topRow.Position = UDim2.new(0, 8, 0, 7)
                                topRow.BackgroundTransparency = 1
                                topRow.Parent = card
                                local iconLbl = Instance.new("TextLabel")
                                iconLbl.Size = UDim2.new(0, 14, 1, 0)
                                iconLbl.BackgroundTransparency = 1
                                iconLbl.Font = Enum.Font.GothamMedium
                                iconLbl.TextSize = 10
                                iconLbl.TextColor3 = C.textDim
                                iconLbl.TextXAlignment = Enum.TextXAlignment.Left
                                iconLbl.Text = tostring(ccfg.Icon or "•")
                                iconLbl.Parent = topRow
                                local lbl = Instance.new("TextLabel")
                                lbl.Size = UDim2.new(1, -18, 1, 0)
                                lbl.Position = UDim2.new(0, 18, 0, 0)
                                lbl.BackgroundTransparency = 1
                                lbl.Font = Enum.Font.GothamBold
                                lbl.TextSize = 8
                                lbl.TextColor3 = C.muted
                                lbl.TextXAlignment = Enum.TextXAlignment.Left
                                lbl.Text = string.upper(tostring(ccfg.Label or id))
                                lbl.Parent = topRow

                                local val = Instance.new("TextLabel")
                                val.Size = UDim2.new(1, -16, 0, 18)
                                val.Position = UDim2.new(0, 8, 1, -22)
                                val.BackgroundTransparency = 1
                                val.Font = Enum.Font.Code
                                val.TextSize = 15
                                val.TextColor3 = C.accentHi
                                val.TextXAlignment = Enum.TextXAlignment.Left
                                val.TextTruncate = Enum.TextTruncate.AtEnd
                                val.Text = tostring(ccfg.Value or "—")
                                val.Parent = card

                                local chip = {
                                        obj = {
                                                Id = id,
                                                SetValue = function(_, v)
                                                        val.Text = tostring(v)
                                                end,
                                                SetLabel = function(_, v)
                                                        lbl.Text = string.upper(tostring(v))
                                                end,
                                        },
                                        card = card,
                                        val = val,
                                }
                                chip.sample = type(ccfg.Sample) == "function" and ccfg.Sample or nil
                                chips[id] = chip
                                relayout()
                                onTheme(function()
                                        Tween(card, T20, { BackgroundColor3 = C.panelAlt })
                                        Tween(val, T20, { TextColor3 = C.accentHi })
                                        iconLbl.TextColor3 = C.textDim
                                        lbl.TextColor3 = C.muted
                                end)
                                return chip.obj
                        end

                        --- Update a chip's displayed value by id.
                        function gridObj:UpdateChip(id, value)
                                local chip = chips[tostring(id)]
                                if chip then chip.val.Text = tostring(value) end
                        end

                        --- Remove a chip by id.
                        function gridObj:RemoveChip(id)
                                id = tostring(id)
                                local chip = chips[id]
                                if chip then
                                        chip.card:Destroy()
                                        chips[id] = nil
                                        chipCount = math.max(0, chipCount - 1)
                                        relayout()
                                end
                        end

                        function gridObj:GetChipCount()
                                return chipCount
                        end

                        function gridObj:Destroy()
                                holder:Destroy()
                        end

                        registerFlag(gcfg.Flag, gridObj)
                        applyTooltip(holder, gcfg.Tooltip)

                        -- [v5.3.2] Declarative chips: if gcfg.Chips is a list,
                        -- instantiate them now (after the methods are defined
                        -- so AddChip's dependencies are bound). Order preserved.
                        if type(gcfg.Chips) == "table" then
                                for _, chip in ipairs(gcfg.Chips) do
                                        if type(chip) == "table" then
                                                pcall(function() gridObj:AddChip(chip) end)
                                        end
                                end
                        end

                        -- Auto-poll any Sample functions at UpdateRate.
                        if updateRate then
                                task.spawn(function()
                                        while holder.Parent do
                                                task.wait(updateRate)
                                                if not holder.Parent then break end
                                                for _, chip in pairs(chips) do
                                                        if type(chip.sample) == "function" then
                                                                local ok, v = pcall(chip.sample)
                                                                if ok and v ~= nil then chip.val.Text = tostring(v) end
                                                        end
                                                end
                                        end
                                end)
                        end
                        return gridObj
                end

                -- ========================================================
                -- [v4.4.0] CreateGraph({ Name, Max, Bars, Height, Suffix,
                --                        Sample, RefreshRate, Flag })
                -- A live sparkline: feed it values with :Push(v) (or provide
                -- Sample = function() return n end for auto-polling) and it
                -- plots a scrolling window of the last N samples. Perfect for
                -- "$ Earned/min over time" style panels.
                -- ========================================================
                function tab:CreateGraph(gcfg)
                        gcfg = gcfg or {}
                        local nameText  = gcfg.Name or "Graph"
                        local barCount  = math.clamp(math.floor(tonumber(gcfg.Bars) or 28), 8, 64)
                        local fixedMax  = tonumber(gcfg.Max)
                        local suffix    = gcfg.Suffix or ""
                        local sampleFn  = type(gcfg.Sample) == "function" and gcfg.Sample or nil
                        local refreshRate = math.clamp(tonumber(gcfg.RefreshRate) or 1, 0.1, 60)

                        local holderHeight = math.clamp(math.floor(tonumber(gcfg.Height) or 86), 60, 200)
                        local holder, hStroke = makeHolder(holderHeight)

                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, -90, 0, 16)
                        lbl.Position = UDim2.new(0, 14, 0, 6)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamBold
                        lbl.TextSize = 11
                        lbl.TextColor3 = C.text
                        lbl.TextXAlignment = Enum.TextXAlignment.Left
                        lbl.TextTruncate = Enum.TextTruncate.AtEnd
                        lbl.Text = string.upper(tostring(nameText))
                        lbl.ZIndex = 2
                        lbl.Parent = holder
                        applyElementIcon(holder, gcfg.Icon, lbl)

                        local valLbl = Instance.new("TextLabel")
                        valLbl.Size = UDim2.new(0, 76, 0, 16)
                        valLbl.Position = UDim2.new(1, -88, 0, 6)
                        valLbl.BackgroundTransparency = 1
                        valLbl.Font = Enum.Font.Code
                        valLbl.TextSize = 11
                        valLbl.TextColor3 = C.accent
                        valLbl.TextXAlignment = Enum.TextXAlignment.Right
                        valLbl.TextTruncate = Enum.TextTruncate.AtEnd
                        valLbl.Text = "—" .. suffix
                        valLbl.ZIndex = 2
                        valLbl.Parent = holder

                        -- Plot surface: bars grow from the bottom edge.
                        local plot = Instance.new("Frame")
                        plot.Name = "Plot"
                        plot.Size = UDim2.new(1, -28, 1, -30)
                        plot.Position = UDim2.new(0, 14, 0, 24)
                        plot.BackgroundTransparency = 1
                        plot.ClipsDescendants = true
                        plot.ZIndex = 2
                        plot.Parent = holder
                        local plotLayout = Instance.new("UIListLayout")
                        plotLayout.FillDirection = Enum.FillDirection.Horizontal
                        plotLayout.SortOrder = Enum.SortOrder.LayoutOrder
                        plotLayout.Padding = UDim.new(0, 2)
                        plotLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
                        plotLayout.Parent = plot

                        local bars = {}
                        for index = 1, barCount do
                                local bar = Instance.new("Frame")
                                bar.Name = "Bar" .. index
                                bar.LayoutOrder = index
                                bar.Size = UDim2.new(1 / barCount, -2, 0, 0)
                                bar.AnchorPoint = Vector2.new(0, 1)
                                bar.BackgroundColor3 = C.accentDim
                                bar.BackgroundTransparency = 0.55
                                bar.BorderSizePixel = 0
                                bar.ZIndex = 2
                                bar.Parent = plot
                                corner(bar, UDim.new(1, 0))
                                bars[index] = bar
                        end

                        local obj = { Values = {}, Latest = nil }
                        local function render(animate)
                                local count = #obj.Values
                                local maxV = fixedMax
                                if not maxV then
                                        maxV = 0
                                        for _, v in ipairs(obj.Values) do
                                                if v > maxV then maxV = v end
                                        end
                                        if maxV <= 0 then maxV = 1 end
                                end
                                local plotH = plot.AbsoluteSize.Y
                                if plotH <= 1 then plotH = holderHeight - 30 end
                                for index = 1, barCount do
                                        local bar = bars[index]
                                        -- newest value maps to the LAST bar
                                        local valueIndex = count - (barCount - index)
                                        local v = valueIndex >= 1 and valueIndex <= count and obj.Values[valueIndex] or nil
                                        local h = 0
                                        if v then
                                                h = math.clamp(v / maxV, 0.04, 1) * (plotH - 2)
                                        end
                                        local age = v and (barCount - index) or barCount
                                        local isLatest = index == barCount and v ~= nil
                                        if animate then
                                                Tween(bar, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                                        Size = UDim2.new(1 / barCount, -2, 0, math.floor(h + 0.5)),
                                                        BackgroundTransparency = isLatest and 0 or math.min(0.35 + age / barCount * 0.45, 0.85),
                                                        BackgroundColor3 = isLatest and C.accentHi or C.accentDim,
                                                })
                                        else
                                                bar.Size = UDim2.new(1 / barCount, -2, 0, math.floor(h + 0.5))
                                                bar.BackgroundTransparency = isLatest and 0 or math.min(0.35 + age / barCount * 0.45, 0.85)
                                                bar.BackgroundColor3 = isLatest and C.accentHi or C.accentDim
                                        end
                                end
                                if obj.Latest ~= nil then
                                        valLbl.Text = tostring(obj.Latest) .. suffix
                                end
                        end

                        --- Append a sample to the graph (scrolls the window).
                        function obj:Push(value)
                                value = tonumber(value)
                                if value == nil then return obj.Latest end
                                table.insert(obj.Values, value)
                                while #obj.Values > barCount do
                                        table.remove(obj.Values, 1)
                                end
                                obj.Latest = value
                                render(true)
                                return value
                        end

                        --- Clear all samples.
                        function obj:Reset()
                                obj.Values = {}
                                obj.Latest = nil
                                valLbl.Text = "—" .. suffix
                                render(false)
                        end

                        --- Change the fixed scale (nil = auto-scale).
                        function obj:SetMax(newMax)
                                fixedMax = tonumber(newMax)
                                render(true)
                        end

                        function obj:Get()
                                return obj.Latest, obj.Values
                        end

                        function obj:Destroy()
                                holder:Destroy()
                        end

                        onTheme(function()
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(lbl, T20, { TextColor3 = C.text })
                                Tween(valLbl, T20, { TextColor3 = C.accent })
                                render(false)
                        end)
                        applyTooltip(holder, gcfg.Tooltip)
                        registerFlag(gcfg.Flag, obj)
                        render(false)

                        -- Optional auto-sampling.
                        if sampleFn then
                                task.spawn(function()
                                        while holder.Parent do
                                                local ok, value = pcall(sampleFn)
                                                if ok and tonumber(value) ~= nil then
                                                        obj:Push(tonumber(value))
                                                end
                                                task.wait(refreshRate)
                                        end
                                end)
                        end
                        return obj
                end

                -- A compact status row works well in operational panels where
                -- developers need a calm scan of services, systems, or checks.
                function tab:CreateStatus(scfg)
                        scfg = scfg or {}
                        local holder, hStroke = makeHolder(scfg.Height or 46)
                        holder.Name = "Status"

                        local dot = Instance.new("Frame")
                        dot.Size = UDim2.new(0, 8, 0, 8)
                        dot.Position = UDim2.new(0, 16, 0.5, -4)
                        dot.BackgroundColor3 = C.green
                        dot.BorderSizePixel = 0
                        dot.ZIndex = 2
                        dot.Parent = holder
                        corner(dot, 4)

                        local name = Instance.new("TextLabel")
                        name.Size = UDim2.new(0.56, -30, 0, 18)
                        name.Position = UDim2.new(0, 34, 0, 7)
                        name.BackgroundTransparency = 1
                        name.Font = Enum.Font.GothamMedium
                        name.TextSize = 12
                        name.TextColor3 = C.text
                        name.TextXAlignment = Enum.TextXAlignment.Left
                        name.TextTruncate = Enum.TextTruncate.AtEnd
                        name.ZIndex = 2
                        name.Parent = holder

                        local detail = Instance.new("TextLabel")
                        detail.Size = UDim2.new(0.56, -30, 0, 14)
                        detail.Position = UDim2.new(0, 34, 0, 24)
                        detail.BackgroundTransparency = 1
                        detail.Font = Enum.Font.Gotham
                        detail.TextSize = 10
                        detail.TextColor3 = C.muted
                        detail.TextXAlignment = Enum.TextXAlignment.Left
                        detail.TextTruncate = Enum.TextTruncate.AtEnd
                        detail.ZIndex = 2
                        detail.Parent = holder

                        local value = Instance.new("TextLabel")
                        value.Size = UDim2.new(0.4, -20, 0, 18)
                        value.Position = UDim2.new(0.6, 0, 0.5, -9)
                        value.BackgroundTransparency = 1
                        value.Font = Enum.Font.Code
                        value.TextSize = 11
                        value.TextColor3 = C.textDim
                        value.TextXAlignment = Enum.TextXAlignment.Right
                        value.TextTruncate = Enum.TextTruncate.AtEnd
                        value.ZIndex = 2
                        value.Parent = holder

                        local obj = {
                                Name = scfg.Name or scfg.Title or "Status",
                                Detail = scfg.Detail or scfg.Description or "",
                                Value = scfg.Value or scfg.Text or "",
                                State = scfg.State or "healthy",
                        }

                        local function render()
                                local color = semanticColor(obj.State)
                                name.Text = obj.Name
                                detail.Text = obj.Detail
                                value.Text = tostring(obj.Value)
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(dot, T20, { BackgroundColor3 = color })
                                Tween(name, T20, { TextColor3 = C.text })
                                Tween(detail, T20, { TextColor3 = C.muted })
                                Tween(value, T20, { TextColor3 = C.textDim })
                        end

                        function obj:Set(nextValue)
                                if type(nextValue) == "table" then
                                        obj.Name = nextValue.Name or nextValue.Title or obj.Name
                                        obj.Detail = nextValue.Detail or nextValue.Description or obj.Detail
                                        obj.Value = nextValue.Value or nextValue.Text or obj.Value
                                        obj.State = nextValue.State or obj.State
                                else
                                        obj.Value = nextValue
                                end
                                render()
                                return obj
                        end

                        function obj:SetState(nextState)
                                obj.State = nextState or "info"
                                render()
                                return obj
                        end

                        function obj:Destroy()
                                holder:Destroy()
                        end

                        render()
                        onTheme(render)
                        applyTooltip(holder, scfg.Tooltip)
                        registerFlag(scfg.Flag, obj)
                        return obj
                end

                -- Code blocks are read-only by design. Copying is delegated
                -- to the developer through CopyCallback rather than invoking
                -- executor clipboard helpers or other opaque environment APIs.
                function tab:CreateCodeBlock(ccfg)
                        ccfg = ccfg or {}
                        local blockHeight = math.clamp(tonumber(ccfg.Height) or 112, 72, 280)
                        local holder, hStroke = makeHolder(blockHeight)
                        holder.Name = "CodeBlock"

                        local title = Instance.new("TextLabel")
                        title.Size = UDim2.new(1, -96, 0, 22)
                        title.Position = UDim2.new(0, 14, 0, 8)
                        title.BackgroundTransparency = 1
                        title.Font = Enum.Font.GothamMedium
                        title.TextSize = 12
                        title.TextColor3 = C.text
                        title.TextXAlignment = Enum.TextXAlignment.Left
                        title.TextTruncate = Enum.TextTruncate.AtEnd
                        title.ZIndex = 2
                        title.Parent = holder

                        local copyButton = Instance.new("TextButton")
                        copyButton.Size = UDim2.new(0, 64, 0, 22)
                        copyButton.Position = UDim2.new(1, -76, 0, 8)
                        copyButton.BackgroundColor3 = C.panelAlt
                        copyButton.BorderSizePixel = 0
                        copyButton.AutoButtonColor = false
                        copyButton.Font = Enum.Font.GothamBold
                        copyButton.TextSize = 10
                        copyButton.TextColor3 = C.accentHi
                        copyButton.Text = "COPY"
                        copyButton.ZIndex = 3
                        copyButton.Selectable = true
                        copyButton.Parent = holder
                        corner(copyButton, R.small)
                        local copyStroke = stroke(copyButton, C.border, 1)

                        local codeSurface = Instance.new("Frame")
                        codeSurface.Size = UDim2.new(1, -28, 1, -45)
                        codeSurface.Position = UDim2.new(0, 14, 0, 35)
                        codeSurface.BackgroundColor3 = C.bg
                        codeSurface.BorderSizePixel = 0
                        codeSurface.ClipsDescendants = true
                        codeSurface.ZIndex = 2
                        codeSurface.Parent = holder
                        corner(codeSurface, R.small)
                        local codeStroke = stroke(codeSurface, C.border, 1)

                        local code = Instance.new("TextLabel")
                        code.Size = UDim2.new(1, -16, 1, -12)
                        code.Position = UDim2.new(0, 8, 0, 6)
                        code.BackgroundTransparency = 1
                        code.Font = Enum.Font.Code
                        code.TextSize = 11
                        code.TextColor3 = C.textDim
                        code.TextXAlignment = Enum.TextXAlignment.Left
                        code.TextYAlignment = Enum.TextYAlignment.Top
                        code.TextWrapped = false
                        code.TextTruncate = Enum.TextTruncate.AtEnd
                        code.RichText = false
                        code.ZIndex = 3
                        code.Parent = codeSurface

                        local obj = {
                                Title = ccfg.Title or ccfg.Name or "Code",
                                Code = ccfg.Code or ccfg.Content or "",
                        }

                        local function render()
                                title.Text = obj.Title
                                code.Text = obj.Code
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(title, T20, { TextColor3 = C.text })
                                Tween(copyButton, T20, { BackgroundColor3 = C.panelAlt, TextColor3 = C.accentHi })
                                Tween(copyStroke, T20, { Color = C.border })
                                Tween(codeSurface, T20, { BackgroundColor3 = C.bg })
                                Tween(codeStroke, T20, { Color = C.border })
                                Tween(code, T20, { TextColor3 = C.textDim })
                        end

                        function obj:Get()
                                return obj.Code
                        end

                        function obj:Set(nextCode)
                                obj.Code = tostring(nextCode or "")
                                render()
                                return obj.Code
                        end

                        function obj:Copy()
                                if ccfg.CopyCallback then
                                        pcall(ccfg.CopyCallback, obj.Code, obj)
                                end
                                copyButton.Text = "COPIED"
                                Tween(copyButton, T10, { BackgroundColor3 = C.accentDark })
                                task.delay(1, function()
                                        if copyButton.Parent then
                                                copyButton.Text = "COPY"
                                                Tween(copyButton, T10, { BackgroundColor3 = C.panelAlt })
                                        end
                                end)
                                return obj.Code
                        end

                        function obj:Destroy()
                                holder:Destroy()
                        end

                        copyButton.MouseEnter:Connect(function()
                                Tween(copyButton, T10, { BackgroundColor3 = C.panelHov })
                        end)
                        copyButton.MouseLeave:Connect(function()
                                Tween(copyButton, T10, { BackgroundColor3 = C.panelAlt })
                        end)
                        copyButton.Activated:Connect(function() obj:Copy() end)

                        render()
                        onTheme(render)
                        applyTooltip(holder, ccfg.Tooltip)
                        registerFlag(ccfg.Flag, obj)
                        return obj
                end

                -- Tables deliberately use rows rather than a repeating card
                -- grid. The resulting density is far easier to scan in admin
                -- tooling, diagnostics panels, and developer dashboards.
                function tab:CreateTable(tcfg)
                        tcfg = tcfg or {}
                        local tableHeight = math.clamp(tonumber(tcfg.Height) or 188, 112, 360)
                        local holder, hStroke = makeHolder(tableHeight)
                        holder.Name = "Table"

                        local rawColumns = tcfg.Columns or { "Name", "Value" }
                        if #rawColumns == 0 then rawColumns = { "Name", "Value" } end
                        local columns, totalWidth = {}, 0
                        for index, column in ipairs(rawColumns) do
                                local item = type(column) == "table" and column or { Name = tostring(column) }
                                local width = math.max(0.1, tonumber(item.Width) or 1)
                                totalWidth = totalWidth + width
                                columns[index] = {
                                        Name = item.Name or item.Title or ("Column " .. index),
                                        Key = item.Key or item.Name or index,
                                        Width = width,
                                        Align = item.Align or item.Alignment or "Left",
                                }
                        end

                        local hasTitle = tcfg.Title ~= nil or tcfg.Name ~= nil
                        local title = Instance.new("TextLabel")
                        title.Size = UDim2.new(1, -28, 0, 20)
                        title.Position = UDim2.new(0, 14, 0, 8)
                        title.BackgroundTransparency = 1
                        title.Font = Enum.Font.GothamMedium
                        title.TextSize = 12
                        title.TextColor3 = C.text
                        title.TextXAlignment = Enum.TextXAlignment.Left
                        title.TextTruncate = Enum.TextTruncate.AtEnd
                        title.Text = tcfg.Title or tcfg.Name or ""
                        title.Visible = hasTitle
                        title.ZIndex = 2
                        title.Parent = holder

                        local headerY = hasTitle and 34 or 10
                        local header = Instance.new("Frame")
                        header.Size = UDim2.new(1, -28, 0, 24)
                        header.Position = UDim2.new(0, 14, 0, headerY)
                        header.BackgroundColor3 = C.panelAlt
                        header.BorderSizePixel = 0
                        header.ZIndex = 2
                        header.Parent = holder
                        corner(header, R.small)
                        local headerStroke = stroke(header, C.border, 1)

                        local headerLabels = {}
                        local cursor = 0
                        for index, column in ipairs(columns) do
                                local portion = column.Width / totalWidth
                                local label = Instance.new("TextLabel")
                                label.Size = UDim2.new(portion, -12, 1, 0)
                                label.Position = UDim2.new(cursor, 6, 0, 0)
                                label.BackgroundTransparency = 1
                                label.Font = Enum.Font.GothamBold
                                label.TextSize = 10
                                label.TextColor3 = C.muted
                                label.TextXAlignment = Enum.TextXAlignment[column.Align] or Enum.TextXAlignment.Left
                                label.TextTruncate = Enum.TextTruncate.AtEnd
                                label.Text = string.upper(column.Name)
                                label.ZIndex = 3
                                label.Parent = header
                                headerLabels[index] = label
                                cursor = cursor + portion
                        end

                        local rows = Instance.new("ScrollingFrame")
                        rows.Size = UDim2.new(1, -28, 1, -(headerY + 42))
                        rows.Position = UDim2.new(0, 14, 0, headerY + 30)
                        rows.BackgroundTransparency = 1
                        rows.BorderSizePixel = 0
                        rows.ScrollBarThickness = 3
                        rows.ScrollBarImageColor3 = C.accent
                        rows.ScrollBarImageTransparency = 0.45
                        rows.CanvasSize = UDim2.new(0, 0, 0, 0)
                        rows.ElasticBehavior = Enum.ElasticBehavior.Never
                        rows.ZIndex = 2
                        rows.Parent = holder

                        local rowLayout = Instance.new("UIListLayout")
                        rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
                        rowLayout.Padding = UDim.new(0, 3)
                        rowLayout.Parent = rows

                        local empty = Instance.new("TextLabel")
                        empty.Size = UDim2.new(1, 0, 0, 42)
                        empty.BackgroundTransparency = 1
                        empty.Font = Enum.Font.Gotham
                        empty.TextSize = 11
                        empty.TextColor3 = C.muted
                        empty.Text = tcfg.EmptyText or "No rows to display"
                        empty.Visible = false
                        empty.ZIndex = 3
                        empty.Parent = rows

                        local obj = {
                                Title = tcfg.Title or tcfg.Name,
                                Columns = columns,
                                Rows = {},
                        }

                        local function updateCanvas()
                                local count = #obj.Rows
                                empty.Visible = count == 0
                                rows.CanvasSize = UDim2.new(0, 0, 0, rowLayout.AbsoluteContentSize.Y + 2)
                        end

                        local function rowBackground(index)
                                return index % 2 == 0 and C.panelAlt or C.bg
                        end

                        local function createRow(values, index)
                                local row = Instance.new("TextButton")
                                row.Name = "Row"
                                row.Size = UDim2.new(1, -4, 0, 28)
                                row.BackgroundColor3 = rowBackground(index)
                                row.BorderSizePixel = 0
                                row.AutoButtonColor = false
                                row.Selectable = true
                                row.Text = ""
                                row.LayoutOrder = index
                                row.ZIndex = 2
                                row.Parent = rows
                                corner(row, R.small)

                                local cells, x = {}, 0
                                for columnIndex, column in ipairs(columns) do
                                        local portion = column.Width / totalWidth
                                        local rawValue = ""
                                        if type(values) == "table" then
                                                rawValue = values[column.Key]
                                                if rawValue == nil then rawValue = values[columnIndex] end
                                        end
                                        if rawValue == nil then rawValue = "" end

                                        local cell = Instance.new("TextLabel")
                                        cell.Size = UDim2.new(portion, -12, 1, 0)
                                        cell.Position = UDim2.new(x, 6, 0, 0)
                                        cell.BackgroundTransparency = 1
                                        cell.Font = Enum.Font.Gotham
                                        cell.TextSize = 11
                                        cell.TextColor3 = C.textDim
                                        cell.TextXAlignment = Enum.TextXAlignment[column.Align] or Enum.TextXAlignment.Left
                                        cell.TextTruncate = Enum.TextTruncate.AtEnd
                                        cell.Text = tostring(rawValue)
                                        cell.ZIndex = 3
                                        cell.Parent = row
                                        cells[columnIndex] = cell
                                        x = x + portion
                                end

                                local entry = { Frame = row, Values = values, Cells = cells }
                                row.MouseEnter:Connect(function()
                                        Tween(row, T10, { BackgroundColor3 = C.panelHov })
                                end)
                                row.MouseLeave:Connect(function()
                                        Tween(row, T10, { BackgroundColor3 = rowBackground(index) })
                                end)
                                row.Activated:Connect(function()
                                        if tcfg.OnRowActivated then
                                                pcall(tcfg.OnRowActivated, values, index, entry)
                                        end
                                end)
                                return entry
                        end

                        function obj:AddRow(values)
                                local index = #obj.Rows + 1
                                local entry = createRow(values or {}, index)
                                table.insert(obj.Rows, entry)
                                task.defer(updateCanvas)
                                return entry
                        end

                        function obj:Clear()
                                for _, entry in ipairs(obj.Rows) do
                                        if entry.Frame then entry.Frame:Destroy() end
                                end
                                table.clear(obj.Rows)
                                task.defer(updateCanvas)
                                return obj
                        end

                        function obj:SetRows(nextRows)
                                obj:Clear()
                                if type(nextRows) == "table" then
                                        for _, rowValues in ipairs(nextRows) do obj:AddRow(rowValues) end
                                end
                                return obj
                        end

                        function obj:RemoveRow(index)
                                local entry = table.remove(obj.Rows, index)
                                if entry and entry.Frame then entry.Frame:Destroy() end
                                for rowIndex, remaining in ipairs(obj.Rows) do
                                        remaining.Frame.LayoutOrder = rowIndex
                                        Tween(remaining.Frame, T10, { BackgroundColor3 = rowBackground(rowIndex) })
                                end
                                task.defer(updateCanvas)
                                return entry and entry.Values or nil
                        end

                        function obj:GetRows()
                                local copy = {}
                                for index, entry in ipairs(obj.Rows) do copy[index] = entry.Values end
                                return copy
                        end

                        function obj:Destroy()
                                holder:Destroy()
                        end

                        local function render()
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(title, T20, { TextColor3 = C.text })
                                Tween(header, T20, { BackgroundColor3 = C.panelAlt })
                                Tween(headerStroke, T20, { Color = C.border })
                                rows.ScrollBarImageColor3 = C.accent
                                Tween(empty, T20, { TextColor3 = C.muted })
                                for _, label in ipairs(headerLabels) do
                                        Tween(label, T20, { TextColor3 = C.muted })
                                end
                                for index, entry in ipairs(obj.Rows) do
                                        Tween(entry.Frame, T20, { BackgroundColor3 = rowBackground(index) })
                                        for _, cell in ipairs(entry.Cells) do
                                                Tween(cell, T20, { TextColor3 = C.textDim })
                                        end
                                end
                        end

                        WindowJanitor:Add(rowLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
                        if type(tcfg.Rows) == "table" then
                                for _, rowValues in ipairs(tcfg.Rows) do obj:AddRow(rowValues) end
                        end
                        task.defer(updateCanvas)
                        render()
                        onTheme(render)
                        applyTooltip(holder, tcfg.Tooltip)
                        registerFlag(tcfg.Flag, obj)
                        return obj
                end

                -- Multi-line input is intentionally explicit: callbacks fire
                -- on commit by default, with Live = true available for search
                -- and editor-style experiences that genuinely need it.
                function tab:CreateTextArea(acfg)
                        acfg = acfg or {}
                        local areaHeight = math.clamp(tonumber(acfg.Height) or 142, 92, 300)
                        local defaultValue = tostring(acfg.CurrentValue or acfg.Text or "")
                        local holder, hStroke = makeHolder(areaHeight)
                        holder.Name = "TextArea"

                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, -118, 0, 19)
                        label.Position = UDim2.new(0, 14, 0, 8)
                        label.BackgroundTransparency = 1
                        label.Font = Enum.Font.GothamMedium
                        label.TextSize = 12
                        label.TextColor3 = C.text
                        label.TextXAlignment = Enum.TextXAlignment.Left
                        label.TextTruncate = Enum.TextTruncate.AtEnd
                        label.ZIndex = 2
                        label.Parent = holder

                        local counter = Instance.new("TextLabel")
                        counter.Size = UDim2.new(0, 92, 0, 19)
                        counter.Position = UDim2.new(1, -106, 0, 8)
                        counter.BackgroundTransparency = 1
                        counter.Font = Enum.Font.Code
                        counter.TextSize = 10
                        counter.TextColor3 = C.muted
                        counter.TextXAlignment = Enum.TextXAlignment.Right
                        counter.ZIndex = 2
                        counter.Parent = holder

                        local inputSurface = Instance.new("Frame")
                        inputSurface.Size = UDim2.new(1, -28, 1, -42)
                        inputSurface.Position = UDim2.new(0, 14, 0, 31)
                        inputSurface.BackgroundColor3 = C.bg
                        inputSurface.BorderSizePixel = 0
                        inputSurface.ZIndex = 2
                        inputSurface.Parent = holder
                        corner(inputSurface, R.small)
                        local inputStroke = stroke(inputSurface, C.border, 1)

                        local box = Instance.new("TextBox")
                        box.Size = UDim2.new(1, -16, 1, -12)
                        box.Position = UDim2.new(0, 8, 0, 6)
                        box.BackgroundTransparency = 1
                        box.ClearTextOnFocus = false
                        box.MultiLine = true
                        box.TextWrapped = true
                        box.TextXAlignment = Enum.TextXAlignment.Left
                        box.TextYAlignment = Enum.TextYAlignment.Top
                        box.Font = Enum.Font.Code
                        box.TextSize = 11
                        box.TextColor3 = C.text
                        box.PlaceholderColor3 = C.muted
                        box.PlaceholderText = acfg.PlaceholderText or acfg.Placeholder or ""
                        box.Text = defaultValue
                        box.ZIndex = 3
                        box.Parent = inputSurface

                        local obj = {
                                Name = acfg.Name or acfg.Title or "Text area",
                                CurrentValue = box.Text,
                                Disabled = acfg.Disabled == true,
                                Error = nil,
                        }
                        local maxLength = tonumber(acfg.MaxLength)

                        local function updateCounter()
                                local length = utf8.len(box.Text) or #box.Text
                                if maxLength then
                                        counter.Text = string.format("%d / %d", length, maxLength)
                                else
                                        counter.Text = tostring(length) .. " chars"
                                end
                        end

                        local function render()
                                label.Text = obj.Name
                                box.TextEditable = not obj.Disabled
                                box.TextTransparency = obj.Disabled and 0.45 or 0
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(label, T20, { TextColor3 = C.text })
                                Tween(counter, T20, { TextColor3 = obj.Error and C.red or C.muted })
                                Tween(inputSurface, T20, { BackgroundColor3 = C.bg })
                                Tween(inputStroke, T20, { Color = obj.Error and C.red or C.border })
                                Tween(box, T20, { TextColor3 = C.text, PlaceholderColor3 = C.muted })
                                updateCounter()
                        end

                        local function validate(value)
                                if maxLength and (utf8.len(value) or #value) > maxLength then
                                        return false, "Text exceeds the maximum length."
                                end
                                if acfg.Validate then
                                        local ok, accepted, reason = pcall(acfg.Validate, value, obj)
                                        if not ok then return false, "Validation failed safely." end
                                        if accepted == false then return false, reason or "Invalid value." end
                                end
                                return true, nil
                        end

                        function obj:Get()
                                return obj.CurrentValue
                        end

                        function obj:Set(nextValue, silent)
                                obj.CurrentValue = tostring(nextValue or "")
                                box.Text = obj.CurrentValue
                                local valid, reason = validate(obj.CurrentValue)
                                obj.Error = (not valid) and reason or nil  -- [FIX v4.0] was `valid and nil or reason`, which always yielded `reason`
                                render()
                                if not silent and acfg.Callback then
                                        pcall(acfg.Callback, obj.CurrentValue, obj)
                                end
                                return valid, obj.Error
                        end

                        function obj:Clear(silent)
                                return obj:Set("", silent)
                        end

                        function obj:Reset()
                                return obj:Set(defaultValue)
                        end

                        function obj:Focus()
                                if not obj.Disabled then box:CaptureFocus() end
                        end

                        function obj:SetDisabled(disabled)
                                obj.Disabled = disabled == true
                                render()
                                return obj
                        end

                        function obj:Destroy()
                                holder:Destroy()
                        end

                        WindowJanitor:Add(box.Focused:Connect(function()
                                -- [v5.1.0] neon focus flare
                                if not obj.Disabled then Tween(inputStroke, MT.move, { Color = C.accent, Thickness = 2 }) end
                        end))
                        WindowJanitor:Add(box.FocusLost:Connect(function()
                                if obj.Disabled then return end
                                obj.CurrentValue = box.Text
                                local valid, reason = validate(obj.CurrentValue)
                                obj.Error = (not valid) and reason or nil  -- [FIX v4.0] was `valid and nil or reason`, which always yielded `reason`
                                render()
                                if acfg.Callback then pcall(acfg.Callback, obj.CurrentValue, obj) end
                        end))
                        if acfg.Live == true then
                                WindowJanitor:Add(box:GetPropertyChangedSignal("Text"):Connect(function()
                                        if obj.Disabled then return end
                                        obj.CurrentValue = box.Text
                                        updateCounter()
                                        if acfg.Callback then pcall(acfg.Callback, obj.CurrentValue, obj) end
                                end))
                        end

                        render()
                        onTheme(render)
                        applyTooltip(holder, acfg.Tooltip)
                        registerFlag(acfg.Flag, obj)
                        return obj
                end

                -- A spinner only consumes animation work while it is running.
                -- It is suitable for short, visible waits rather than a hidden
                -- always-on decorative loop.
                function tab:CreateSpinner(scfg)
                        scfg = scfg or {}
                        local holder, hStroke = makeHolder(scfg.Height or 50)
                        holder.Name = "Spinner"

                        local orbit = Instance.new("Frame")
                        orbit.Size = UDim2.new(0, 24, 0, 24)
                        orbit.Position = UDim2.new(0, 14, 0.5, -12)
                        orbit.BackgroundTransparency = 1
                        orbit.ZIndex = 2
                        orbit.Parent = holder
                        local ring = Instance.new("Frame")
                        ring.Size = UDim2.new(0, 16, 0, 16)
                        ring.Position = UDim2.new(0.5, -8, 0.5, -8)
                        ring.BackgroundTransparency = 1
                        ring.ZIndex = 2
                        ring.Parent = orbit
                        corner(ring, UDim.new(1, 0))
                        local ringStroke = stroke(ring, C.accentDim, 2)
                        local dot = Instance.new("Frame")
                        dot.Size = UDim2.new(0, 6, 0, 6)
                        dot.Position = UDim2.new(0.5, -3, 0, 0)
                        dot.BackgroundColor3 = C.accentHi
                        dot.BorderSizePixel = 0
                        dot.ZIndex = 3
                        dot.Parent = orbit
                        corner(dot, UDim.new(1, 0))

                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, -54, 0, 18)
                        label.Position = UDim2.new(0, 48, 0, 8)
                        label.BackgroundTransparency = 1
                        label.Font = Enum.Font.GothamMedium
                        label.TextSize = 12
                        label.TextColor3 = C.text
                        label.TextXAlignment = Enum.TextXAlignment.Left
                        label.TextTruncate = Enum.TextTruncate.AtEnd
                        label.ZIndex = 2
                        label.Parent = holder
                        local detail = Instance.new("TextLabel")
                        detail.Size = UDim2.new(1, -54, 0, 15)
                        detail.Position = UDim2.new(0, 48, 0, 26)
                        detail.BackgroundTransparency = 1
                        detail.Font = Enum.Font.Gotham
                        detail.TextSize = 10
                        detail.TextColor3 = C.muted
                        detail.TextXAlignment = Enum.TextXAlignment.Left
                        detail.TextTruncate = Enum.TextTruncate.AtEnd
                        detail.ZIndex = 2
                        detail.Parent = holder

                        local obj = {
                                Name = scfg.Name or scfg.Title or "Loading",
                                Detail = scfg.Detail or scfg.Content or "Please wait",
                                Running = false,
                                _tween = nil,
                        }
                        local function render()
                                label.Text = obj.Name
                                detail.Text = obj.Detail
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(ringStroke, T20, { Color = C.accentDim })
                                Tween(dot, T20, { BackgroundColor3 = C.accentHi })
                                Tween(label, T20, { TextColor3 = C.text })
                                Tween(detail, T20, { TextColor3 = C.muted })
                        end
                        function obj:Start()
                                if obj.Running then return obj end
                                obj.Running = true
                                orbit.Rotation = 0
                                local ok, animation = pcall(function()
                                        return TweenService:Create(orbit, TweenInfo.new(0.9, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 })
                                end)
                                if ok and animation then
                                        obj._tween = animation
                                        animation:Play()
                                end
                                return obj
                        end
                        function obj:Stop()
                                obj.Running = false
                                if obj._tween then pcall(function() obj._tween:Cancel() end) end
                                obj._tween = nil
                                orbit.Rotation = 0
                                return obj
                        end
                        function obj:Set(nextValue)
                                if type(nextValue) == "table" then
                                        obj.Name = nextValue.Name or nextValue.Title or obj.Name
                                        obj.Detail = nextValue.Detail or nextValue.Content or obj.Detail
                                        if nextValue.Running ~= nil then
                                                if nextValue.Running then obj:Start() else obj:Stop() end
                                        end
                                else
                                        obj.Detail = tostring(nextValue or "")
                                end
                                render()
                                return obj
                        end
                        function obj:Get()
                                return { Name = obj.Name, Detail = obj.Detail, Running = obj.Running }
                        end
                        function obj:Destroy()
                                obj:Stop()
                                holder:Destroy()
                        end
                        holder.Destroying:Connect(function() obj:Stop() end)
                        render()
                        if scfg.Running ~= false then obj:Start() end
                        onTheme(render)
                        applyTooltip(holder, scfg.Tooltip)
                        registerFlag(scfg.Flag, obj)
                        return obj
                end

                -- A carousel is a compact way to rotate through onboarding
                -- tips, profiles, or previews without adding a full scrolling
                -- surface to a settings panel.
                function tab:CreateCarousel(ccfg)
                        ccfg = ccfg or {}
                        local holder, hStroke = makeHolder(ccfg.Height or 92)
                        holder.Name = "Carousel"
                        local previous = Instance.new("TextButton")
                        previous.Size = UDim2.new(0, 28, 0, 28)
                        previous.Position = UDim2.new(0, 12, 0.5, -14)
                        previous.BackgroundColor3 = C.panelAlt
                        previous.BorderSizePixel = 0
                        previous.AutoButtonColor = false
                        previous.Text = "<"
                        previous.Font = Enum.Font.GothamBold
                        previous.TextSize = 15
                        previous.TextColor3 = C.accentHi
                        previous.ZIndex = 3
                        previous.Parent = holder
                        previous.Selectable = true
                        corner(previous, R.small)
                        local previousStroke = stroke(previous, C.border, 1)
                        local nextButton = previous:Clone()
                        nextButton.Name = "Next"
                        nextButton.Position = UDim2.new(1, -40, 0.5, -14)
                        nextButton.Text = ">"
                        nextButton.Parent = holder
                        local nextStroke = nextButton:FindFirstChildOfClass("UIStroke")

                        local title = Instance.new("TextLabel")
                        title.Size = UDim2.new(1, -104, 0, 21)
                        title.Position = UDim2.new(0, 52, 0, 16)
                        title.BackgroundTransparency = 1
                        title.Font = Enum.Font.GothamBold
                        title.TextSize = 13
                        title.TextColor3 = C.text
                        title.TextXAlignment = Enum.TextXAlignment.Left
                        title.TextTruncate = Enum.TextTruncate.AtEnd
                        title.ZIndex = 2
                        title.Parent = holder
                        local bodyText = Instance.new("TextLabel")
                        bodyText.Size = UDim2.new(1, -104, 0, 30)
                        bodyText.Position = UDim2.new(0, 52, 0, 38)
                        bodyText.BackgroundTransparency = 1
                        bodyText.Font = Enum.Font.Gotham
                        bodyText.TextSize = 11
                        bodyText.TextColor3 = C.textDim
                        bodyText.TextXAlignment = Enum.TextXAlignment.Left
                        bodyText.TextYAlignment = Enum.TextYAlignment.Top
                        bodyText.TextWrapped = true
                        bodyText.ZIndex = 2
                        bodyText.Parent = holder
                        local counter = Instance.new("TextLabel")
                        counter.Size = UDim2.new(1, -104, 0, 14)
                        counter.Position = UDim2.new(0, 52, 1, -20)
                        counter.BackgroundTransparency = 1
                        counter.Font = Enum.Font.Code
                        counter.TextSize = 10
                        counter.TextColor3 = C.muted
                        counter.TextXAlignment = Enum.TextXAlignment.Left
                        counter.ZIndex = 2
                        counter.Parent = holder

                        local obj = { Items = {}, Index = 1 }
                        local function normalizeIndex(index)
                                local count = #obj.Items
                                if count == 0 then return 0 end
                                return ((math.floor(tonumber(index) or 1) - 1) % count) + 1
                        end
                        local function readItem(item)
                                if type(item) == "table" then
                                        return tostring(item.Title or item.Name or item.Text or "Untitled"), tostring(item.Content or item.Description or item.Detail or "")
                                end
                                return tostring(item or ""), ""
                        end
                        local function render(animated)
                                local count = #obj.Items
                                local item = count > 0 and obj.Items[obj.Index] or nil
                                local headline, copy = readItem(item)
                                if animated then
                                        -- [FIX v4.0] The immediate fade-in below used to cancel
                                        -- this fade-out (the tween manager replaces same-property
                                        -- tweens), so animated slide changes never actually
                                        -- faded. Sequence them instead.
                                        Tween(title, T10, { TextTransparency = 1 })
                                        Tween(bodyText, T10, { TextTransparency = 1 })
                                        title.Text = count > 0 and headline or (ccfg.EmptyText or "No slides")
                                        bodyText.Text = count > 0 and copy or "Add items with :SetItems()."
                                        counter.Text = count > 0 and string.format("%d / %d", obj.Index, count) or "0 / 0"
                                        task.delay(0.11, function()
                                                if not title.Parent then return end
                                                Tween(title, T20, { TextColor3 = C.text, TextTransparency = 0 })
                                                Tween(bodyText, T20, { TextColor3 = C.textDim, TextTransparency = 0 })
                                        end)
                                else
                                        title.Text = count > 0 and headline or (ccfg.EmptyText or "No slides")
                                        bodyText.Text = count > 0 and copy or "Add items with :SetItems()."
                                        counter.Text = count > 0 and string.format("%d / %d", obj.Index, count) or "0 / 0"
                                end
                                previous.Visible = count > 1
                                nextButton.Visible = count > 1
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(previous, T20, { BackgroundColor3 = C.panelAlt, TextColor3 = C.accentHi })
                                Tween(nextButton, T20, { BackgroundColor3 = C.panelAlt, TextColor3 = C.accentHi })
                                Tween(previousStroke, T20, { Color = C.border })
                                if nextStroke then Tween(nextStroke, T20, { Color = C.border }) end
                                if not animated then
                                        Tween(title, T20, { TextColor3 = C.text, TextTransparency = 0 })
                                        Tween(bodyText, T20, { TextColor3 = C.textDim, TextTransparency = 0 })
                                end
                                Tween(counter, T20, { TextColor3 = C.muted })
                        end
                        function obj:SetIndex(index, silent)
                                obj.Index = normalizeIndex(index)
                                render(true)
                                if not silent and ccfg.Callback and obj.Index > 0 then
                                        pcall(ccfg.Callback, obj.Items[obj.Index], obj.Index, obj)
                                end
                                return obj.Index
                        end
                        function obj:Next(silent)
                                return obj:SetIndex(obj.Index + 1, silent)
                        end
                        function obj:Previous(silent)
                                return obj:SetIndex(obj.Index - 1, silent)
                        end
                        function obj:SetItems(items, silent)
                                obj.Items = type(items) == "table" and items or {}
                                obj.Index = normalizeIndex(obj.Index)
                                render(false)
                                if not silent and ccfg.Callback and obj.Index > 0 then
                                        pcall(ccfg.Callback, obj.Items[obj.Index], obj.Index, obj)
                                end
                                return obj
                        end
                        function obj:Get()
                                return obj.Items[obj.Index], obj.Index
                        end
                        function obj:Destroy()
                                holder:Destroy()
                        end
                        previous.Activated:Connect(function() obj:Previous() end)
                        nextButton.Activated:Connect(function() obj:Next() end)
                        obj:SetItems(ccfg.Items or {}, true)
                        if ccfg.CurrentIndex then obj:SetIndex(ccfg.CurrentIndex, true) end
                        onTheme(function() render(false) end)
                        applyTooltip(holder, ccfg.Tooltip)
                        registerFlag(ccfg.Flag, obj)
                        return obj
                end

                -- Context menus are created on demand above the window, so
                -- they are never clipped by a ScrollingFrame or compete with
                -- the tab layout for space.
                function tab:CreateContextMenu(mcfg)
                        mcfg = mcfg or {}
                        local holder, hStroke = makeHolder(D.row)
                        holder.Name = "ContextMenu"
                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, -126, 1, 0)
                        label.Position = UDim2.new(0, 14, 0, 0)
                        label.BackgroundTransparency = 1
                        label.Font = Enum.Font.GothamMedium
                        label.TextSize = 13
                        label.TextColor3 = C.text
                        label.TextXAlignment = Enum.TextXAlignment.Left
                        label.TextTruncate = Enum.TextTruncate.AtEnd
                        label.Parent = holder
                        local openButton = Instance.new("TextButton")
                        openButton.Size = UDim2.new(0, 96, 0, 28)
                        openButton.Position = UDim2.new(1, -106, 0.5, -14)
                        openButton.BackgroundColor3 = C.panelAlt
                        openButton.BorderSizePixel = 0
                        openButton.AutoButtonColor = false
                        openButton.Font = Enum.Font.GothamBold
                        openButton.TextSize = 11
                        openButton.TextColor3 = C.accentHi
                        openButton.Text = mcfg.ButtonText or "OPTIONS"
                        openButton.Selectable = true
                        openButton.Parent = holder
                        corner(openButton, R.small)
                        local openStroke = stroke(openButton, C.border, 1)
                        local obj = { Name = mcfg.Name or mcfg.Title or "Menu", Items = type(mcfg.Items) == "table" and mcfg.Items or {} }
                        local function closeMenu()
                                closeCurrentPopup()
                        end
                        local function openMenu()
                                closeCurrentPopup()
                                local visibleItems = {}
                                for _, item in ipairs(obj.Items) do
                                        if type(item) == "table" and item.Hidden ~= true then table.insert(visibleItems, item) end
                                end
                                if #visibleItems == 0 then return nil end
                                local popupContentHeight = math.max(42, #visibleItems * 33 + 9)
                                local popupHeight = math.min(280, popupContentHeight)
                                local catcher = Instance.new("TextButton")
                                catcher.Size = UDim2.new(1, 0, 1, 0)
                                catcher.BackgroundTransparency = 1
                                catcher.BorderSizePixel = 0
                                catcher.AutoButtonColor = false
                                catcher.Text = ""
                                catcher.Active = true
                                catcher.ZIndex = 30
                                catcher.Parent = overlayGui
                                local camera = workspace.CurrentCamera
                                local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
                                local origin = openButton.AbsolutePosition
                                local x = math.clamp(origin.X + openButton.AbsoluteSize.X - 196, 8, math.max(8, viewport.X - 196))
                                local y = math.clamp(origin.Y + openButton.AbsoluteSize.Y + 6, 8, math.max(8, viewport.Y - popupHeight - 8))
                                local popup = Instance.new("ScrollingFrame")
                                popup.Size = UDim2.new(0, 188, 0, popupHeight)
                                popup.Position = UDim2.fromOffset(x, y)
                                popup.BackgroundColor3 = C.panel
                                popup.BorderSizePixel = 0
                                popup.ClipsDescendants = true
                                popup.Active = true
                                popup.ScrollingDirection = Enum.ScrollingDirection.Y
                                popup.ScrollBarThickness = 3
                                popup.ScrollBarImageColor3 = C.accent
                                popup.CanvasSize = UDim2.fromOffset(0, popupContentHeight)
                                -- [v5.0.0] Entrance: fade + 6px drop toward the
                                -- trigger (position-based, corner-safe).
                                do
                                        popup.AnchorPoint = Vector2.new(0, 0)
                                        popup.Position = UDim2.fromOffset(x, y - 6)
                                        popup.BackgroundTransparency = 0.3
                                        Tween(popup, MT.enter, {
                                                Position = UDim2.fromOffset(x, y),
                                                BackgroundTransparency = 0,
                                        })
                                end
                                popup.ZIndex = 31
                                popup.Parent = overlayGui
                                corner(popup, R.panel)
                                local popupStroke = stroke(popup, C.borderAcc, 1)
                                local layout = Instance.new("UIListLayout")
                                layout.Padding = UDim.new(0, 3)
                                layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
                                layout.VerticalAlignment = Enum.VerticalAlignment.Top
                                layout.Parent = popup
                                pad(popup, 6, 6, 0, 0)
                                for index, item in ipairs(visibleItems) do
                                        local choice = Instance.new("TextButton")
                                        choice.Size = UDim2.new(1, -12, 0, 30)
                                        choice.BackgroundColor3 = C.panelAlt
                                        choice.BackgroundTransparency = item.Disabled == true and 0.45 or 0
                                        choice.BorderSizePixel = 0
                                        choice.AutoButtonColor = false
                                        choice.Font = Enum.Font.GothamMedium
                                        choice.TextSize = 12
                                        choice.TextColor3 = item.Disabled == true and C.muted or C.text
                                        choice.TextXAlignment = Enum.TextXAlignment.Left
                                        choice.Text = "  " .. tostring(item.Text or item.Name or ("Option " .. index))
                                        choice.ZIndex = 32
                                        choice.Selectable = item.Disabled ~= true
                                        choice.Parent = popup
                                        corner(choice, R.small)
                                        local choiceStroke = stroke(choice, C.border, 1)
                                        choice.MouseEnter:Connect(function()
                                                if item.Disabled ~= true then
                                                        Tween(choice, T10, { BackgroundColor3 = C.panelHov })
                                                        Tween(choiceStroke, T10, { Color = C.accentDim })
                                                end
                                        end)
                                        choice.MouseLeave:Connect(function()
                                                Tween(choice, T10, { BackgroundColor3 = C.panelAlt })
                                                Tween(choiceStroke, T10, { Color = C.border })
                                        end)
                                        choice.Activated:Connect(function()
                                                if item.Disabled == true then return end
                                                if type(item.Callback) == "function" then
                                                        task.spawn(function()
                                                                local ok, err = pcall(item.Callback, item, index, obj)
                                                                if not ok then warn("[RezurXLib] Context action failed:", err) end
                                                        end)
                                                end
                                                if item.Close ~= false then closeMenu() end
                                        end)
                                end
                                catcher.Activated:Connect(closeMenu)
                                local popupJanitor = Janitor.new()
                                popupJanitor:Add(catcher, "Destroy")
                                popupJanitor:Add(popup, "Destroy")
                                currentPopupJanitor = popupJanitor
                                Tween(popup, T15, { BackgroundColor3 = C.panel })
                                Tween(popupStroke, T15, { Color = C.borderAcc })
                                return popup
                        end
                        function obj:Open() return openMenu() end
                        function obj:Close() closeMenu() end
                        function obj:SetItems(items)
                                obj.Items = type(items) == "table" and items or {}
                                return obj
                        end
                        function obj:Destroy()
                                closeMenu()
                                holder:Destroy()
                        end
                        label.Text = obj.Name
                        openButton.Activated:Connect(openMenu)
                        onTheme(function()
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(label, T20, { TextColor3 = C.text })
                                Tween(openButton, T20, { BackgroundColor3 = C.panelAlt, TextColor3 = C.accentHi })
                                Tween(openStroke, T20, { Color = C.border })
                        end)
                        applyTooltip(holder, mcfg.Tooltip)
                        registerFlag(mcfg.Flag, obj)
                        return obj
                end

                tab.Label = function(_, text) return tab:CreateLabel(text) end
                tab.Divider = function(_, text) return tab:CreateDivider(text) end
                tab.Button = function(_, n, cb) return tab:CreateButton({ Name = n, Callback = cb }) end
                tab.Toggle = function(_, n, d, cb) return tab:CreateToggle({ Name = n, CurrentValue = d, Callback = cb }) end
                tab.Slider = function(_, n, mn, mx, d, sfx, cb)
                        return tab:CreateSlider({ Name = n, Range = { mn, mx }, CurrentValue = d, Suffix = sfx, Callback = cb })
                end
                tab.Input = function(_, n, ph, cb) return tab:CreateInput({ Name = n, PlaceholderText = ph, Callback = cb }) end
                tab.Dropdown = function(_, n, opts, d, cb)
                        return tab:CreateDropdown({ Name = n, Options = opts, CurrentOption = d, Callback = cb })
                end
                tab.ColorPicker = function(_, n, d, cb) return tab:CreateColorPicker({ Name = n, Color = d, Callback = cb }) end
                tab.Paragraph = function(_, t, c) return tab:CreateParagraph({ Title = t, Content = c }) end
                tab.Keybind = function(_, n, k, cb) return tab:CreateKeybind({ Name = n, CurrentKeybind = k, Callback = cb }) end
                tab.Spacer = function(_, px) return tab:CreateSpacer(px) end
                tab.Image = function(_, img, h) return tab:CreateImage({ Image = img, Height = h }) end
                tab.Accordion = function(_, t, exp) return tab:CreateAccordion({ Title = t, DefaultExpanded = exp }) end
                tab.Bindable = function(_, n, k, cb) return tab:CreateBindable({ Name = n, Keybind = k, Callback = cb }) end
                tab.Notice = function(_, title, content, kind)
                        return tab:CreateNotice({ Title = title, Content = content, Type = kind })
                end
                tab.Progress = function(_, name, value, maximum, callback)
                        return tab:CreateProgress({ Name = name, CurrentValue = value, Max = maximum, Callback = callback })
                end
                tab.Spinner = function(_, name, detail)
                        return tab:CreateSpinner({ Name = name, Detail = detail })
                end
                tab.Carousel = function(_, items, callback)
                        return tab:CreateCarousel({ Items = items, Callback = callback })
                end
                tab.ContextMenu = function(_, name, items)
                        return tab:CreateContextMenu({ Name = name, Items = items })
                end
                tab.Status = function(_, name, value, state)
                        return tab:CreateStatus({ Name = name, Value = value, State = state })
                end
                tab.CodeBlock = function(_, title, code, copyCallback)
                        return tab:CreateCodeBlock({ Title = title, Code = code, CopyCallback = copyCallback })
                end
                tab.Table = function(_, columns, rows, options)
                        options = options or {}
                        options.Columns, options.Rows = columns, rows
                        return tab:CreateTable(options)
                end
                tab.TextArea = function(_, name, value, callback)
                        return tab:CreateTextArea({ Name = name, CurrentValue = value, Callback = callback })
                end

                return tab
        end

        -- ============================================================
        -- WINDOW CONTROL + DISCOVERY API
        -- These methods make RezurX practical as a library, not only as a
        -- collection of constructors. All operations are local and explicit.
        -- ============================================================
        local commandOverlay = nil
        local commandJanitor = nil

        function Window:SetTitle(nextTitle)
                Window.Name = tostring(nextTitle or windowName)
                logo.Text = Window.Name
                return Window.Name
        end

        -- Set the compact header badge. Values are capped at four UTF-8
        -- characters so the badge stays intentional rather than becoming a
        -- clipped second title.
        function Window:SetBrandText(nextText)
                return applyBrandText(nextText)
        end

        function Window:GetBrandText()
                return brandText
        end

        -- Set the text on the floating restore control shown after Close.
        -- Empty values inherit the current brand badge; text is capped at four
        -- UTF-8 characters and supports regular text, symbols, and emoji.
        function Window:SetRestoreText(nextText)
                return applyRestoreText(nextText)
        end

        function Window:GetRestoreText()
                return restoreText
        end

        -- Compatibility aliases for developers who think of these as icons
        -- or as the compact button displayed after the window is closed.
        Window.SetBrandIcon = Window.SetBrandText
        Window.GetBrandIcon = Window.GetBrandText
        Window.SetRestoreIcon = Window.SetRestoreText
        Window.GetRestoreIcon = Window.GetRestoreText
        Window.SetClosedButtonText = Window.SetRestoreText
        Window.GetClosedButtonText = Window.GetRestoreText

        function Window:SetSubtitle(nextSubtitle)
                subLbl.Text = tostring(nextSubtitle or "")
                return subLbl.Text
        end

        function Window:SetStatus(text, state)
                sTxt.Text = tostring(text or "READY")
                local normalized = string.lower(tostring(state or "healthy"))
                local color = C.accent
                if normalized == "success" or normalized == "healthy" or normalized == "online" then
                        color = C.green
                elseif normalized == "warning" or normalized == "pending" or normalized == "idle" then
                        color = C.yellow
                elseif normalized == "error" or normalized == "offline" or normalized == "danger" then
                        color = C.red
                end
                Tween(sDot, T20, { BackgroundColor3 = color })
                return sTxt.Text
        end

        function Window:SetVisible(visible)
                setHidden(visible ~= true)
                return not hidden
        end

        function Window:IsVisible()
                return not hidden
        end

        function Window:SetToggleKeybind(nextKey)
                if type(nextKey) == "string" then
                        local ok, value = pcall(function() return Enum.KeyCode[nextKey] end)
                        nextKey = ok and value or nil
                end
        if typeof(nextKey) ~= "EnumItem" or nextKey.EnumType ~= Enum.KeyCode then
                        warn("[RezurXLib] SetToggleKeybind expects an Enum.KeyCode or key name.")
                        return nil
                end
                -- [v5.4.0] BIDIRECTIONAL CLASH GUARD (Rayfield pattern): the
                -- window toggle key must not collide with a consumer element
                -- keybind either. Check every registered flag object for a
                -- matching CurrentKeybind and refuse with the element's flag
                -- name so the developer knows exactly which bind to move.
                for flag, obj in pairs(Window.Flags) do
                        if type(obj) == "table" and obj.CurrentKeybind == nextKey then
                                warn("[RezurXLib] SetToggleKeybind: " .. keyName(nextKey)
                                        .. " is already bound to flag '" .. tostring(flag) .. "'.")
                                notify("Keybind",
                                        keyName(nextKey) .. " is already used by '" .. tostring(flag) .. "'.",
                                        4, "warning")
                                return nil
                        end
                end
                toggleKey = nextKey
                refreshKeyBadge()
                return toggleKey
        end

        --- Set the activity beacon: "running" (green breathing), "paused"
        --- (yellow static), or nil to hide. Shown while minimized so users
        --- know background scripts are live.
        function Window:SetActivity(mode)
                setActivity(mode)
                return mode
        end

        function Window:GetToggleKeybind()
                return toggleKey
        end

        function Window:SetMinimized(nextValue)
                return setMinimized(nextValue)
        end

        function Window:IsMinimized()
                return minimized
        end

        function Window:SetReducedMotion(nextValue)
                reducedMotion = nextValue == true
                screenGui:SetAttribute("RezurXReducedMotion", reducedMotion)
                return reducedMotion
        end

        function Window:SetMotionScale(nextValue)
                motionScale = math.clamp(tonumber(nextValue) or 1, 0.05, 3)
                screenGui:SetAttribute("RezurXMotionScale", motionScale)
                return motionScale
        end

        function Window:GetAccessibility()
                return {
                        ReducedMotion = reducedMotion,
                        MotionScale = motionScale,
                        TouchFriendly = true,
                        KeyboardSafe = true,
                }
        end

        function Window:GetHostInfo()
                local copy = {}
                for key, value in pairs(hostInfo) do copy[key] = value end
                return copy
        end

        function Window:GetGui()
                return screenGui
        end

        function Window:Focus()
                Library._displayOrder = (Library._displayOrder or 100) + 1
                screenGui.DisplayOrder = Library._displayOrder
                if overlayGui ~= screenGui then
                        overlayGui.DisplayOrder = Library._displayOrder + 1
                end
                return screenGui.DisplayOrder
        end

        function Window:SetPosition(nextPosition)
                if typeof(nextPosition) ~= "Vector2" then
                        warn("[RezurXLib] SetPosition expects a Vector2 in viewport pixels.")
                        return nil
                end
                local x, y = clampWindowPosition(nextPosition.X, nextPosition.Y)
                moveWindowTo(x, y)
                return Vector2.new(x, y)
        end

        function Window:SetSize(nextSize)
                local newW, newH = normalizeSize(nextSize, WIN_W, WIN_H, MIN_W, MIN_H, MAX_W, MAX_H)
                local pinned = frame.AbsolutePosition
                WIN_W, WIN_H = newW, newH
                if minimized then
                        frame.Size = UDim2.new(0, newW, 0, HEADER_H)
                        applyShadowBox(newW, HEADER_H)
                else
                        frame.Size = UDim2.new(0, newW, 0, newH)
                        body.Size = UDim2.new(1, 0, 0, newH - HEADER_H)
                        applyShadowBox(newW, newH)
                end
                updateScale()
                local x, y = clampWindowPosition(pinned.X, pinned.Y)
                moveWindowTo(x, y)
                return Vector2.new(newW, newH)
        end

        function Window:GetSize()
                return Vector2.new(WIN_W, WIN_H)
        end

        function Window:GetTheme()
                local copy = {}
                for key, value in pairs(C) do copy[key] = value end
                return copy
        end

        function Window:GetThemeName()
                return activeThemeName
        end

        function Window:SetTheme(theme)
                return Window:ModifyTheme(theme)
        end

        -- Filter the contents of one or every tab without rebuilding the
        -- developer's controls. This is useful when a tool exposes a dense
        -- set of settings and needs a lightweight search surface.
        function Window:Search(query, options)
                options = options or {}
                local needle = string.lower(tostring(query or ""))
                local matched = 0
                local targets = options.AllTabs == true and Tabs or { ActiveTab }

                local function textMatches(root)
                        if not root then return false end
                        for _, descendant in ipairs(root:GetDescendants()) do
                                if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
                                        local content = string.lower(descendant.Text or "")
                                        if string.find(content, needle, 1, true) then return true end
                                end
                        end
                        return false
                end

                for _, candidate in ipairs(targets) do
                        if candidate and candidate.Page then
                                local tabHasMatch = needle == ""
                                for _, child in ipairs(candidate.Page:GetChildren()) do
                                        if child:IsA("GuiObject") then
                                                local show = needle == "" or textMatches(child)
                                                child.Visible = show
                                                if show then
                                                        matched = matched + 1
                                                        tabHasMatch = true
                                                end
                                        end
                                end
                                if options.AllTabs == true and candidate.Btn then
                                        candidate.Btn.Visible = tabHasMatch
                                end
                        end
                end
                return matched
        end

        function Window:ClearSearch(options)
                return Window:Search("", options)
        end

        closeCommandPalette = function()
                if commandJanitor then
                        commandJanitor:Cleanup()
                        commandJanitor = nil
                        commandOverlay = nil
                elseif commandOverlay then
                        commandOverlay:Destroy()
                        commandOverlay = nil
                end
        end

        -- A command palette is a familiar developer affordance. It is built
        -- only on demand, keeping the regular UI calm while making navigation
        -- immediate for tools with many tabs.
        function Window:OpenCommandPalette()
                closeCommandPalette()
                closeCurrentPopup()

                local overlay = Instance.new("TextButton")
                overlay.Name = "CommandPaletteOverlay"
                overlay.Size = UDim2.new(1, 0, 1, 0)
                overlay.BackgroundColor3 = C.black
                overlay.BackgroundTransparency = 0.38
                overlay.BorderSizePixel = 0
                overlay.AutoButtonColor = false
                overlay.Text = ""
                overlay.Active = true
                overlay.ZIndex = 70
                overlay.Parent = overlayGui
                commandOverlay = overlay
                commandJanitor = Janitor.new()
                commandJanitor:Add(overlay, "Destroy")

                local palette = Instance.new("Frame")
                local viewport = getViewport()
                local paletteWidth = math.min(360, math.max(240, viewport.X - 24))
                palette.Size = UDim2.new(0, paletteWidth, 0, 280)
                palette.AnchorPoint = Vector2.new(0.5, 0)
                palette.Position = UDim2.new(0.5, 0, 0, math.clamp(82, 12, math.max(12, viewport.Y - 292)))
                palette.BackgroundColor3 = C.panel
                palette.BorderSizePixel = 0
                palette.ZIndex = 71
                palette.Parent = overlay
                corner(palette, R.panel)
                local paletteStroke = stroke(palette, C.borderAcc, 1)
                -- [v5.0.0] Entrance: scrim fade + a 10px drop (position-based,
                -- corner-safe — no UIScale).
                do
                        local restY = math.clamp(82, 12, math.max(12, viewport.Y - 292))
                        palette.Position = UDim2.new(0.5, 0, 0, restY - 10)
                        overlay.BackgroundTransparency = 1
                        Tween(overlay, MT.snap, { BackgroundTransparency = 0.38 })
                        Tween(palette, MT.enter, { Position = UDim2.new(0.5, 0, 0, restY) })
                end

                local prompt = Instance.new("TextLabel")
                prompt.Size = UDim2.new(1, -28, 0, 18)
                prompt.Position = UDim2.new(0, 14, 0, 10)
                prompt.BackgroundTransparency = 1
                prompt.Font = Enum.Font.GothamMedium
                prompt.TextSize = 11
                prompt.TextColor3 = C.muted
                prompt.TextXAlignment = Enum.TextXAlignment.Left
                prompt.Text = "JUMP TO TAB"
                prompt.ZIndex = 72
                prompt.Parent = palette

                local input = Instance.new("TextBox")
                input.Size = UDim2.new(1, -28, 0, 38)
                input.Position = UDim2.new(0, 14, 0, 32)
                input.BackgroundColor3 = C.bg
                input.BorderSizePixel = 0
                input.ClearTextOnFocus = false
                input.Font = Enum.Font.Gotham
                input.TextSize = 13
                input.TextColor3 = C.text
                input.PlaceholderColor3 = C.muted
                input.PlaceholderText = "Search tabs..."
                input.TextXAlignment = Enum.TextXAlignment.Left
                input.ZIndex = 72
                input.Parent = palette
                corner(input, R.small)
                local inputStroke = stroke(input, C.border, 1)
                pad(input, 0, 0, 12, 12)

                local results = Instance.new("ScrollingFrame")
                results.Size = UDim2.new(1, -28, 1, -84)
                results.Position = UDim2.new(0, 14, 0, 76)
                results.BackgroundTransparency = 1
                results.BorderSizePixel = 0
                results.ScrollBarThickness = 3
                results.ScrollBarImageColor3 = C.accent
                results.ScrollBarImageTransparency = 0.45
                results.CanvasSize = UDim2.new(0, 0, 0, 0)
                results.ElasticBehavior = Enum.ElasticBehavior.Never
                results.ZIndex = 72
                results.Parent = palette
                local resultLayout = Instance.new("UIListLayout")
                resultLayout.Padding = UDim.new(0, 4)
                resultLayout.Parent = results

                local function refreshResults()
                        for _, child in ipairs(results:GetChildren()) do
                                if child.Name == "Result" then child:Destroy() end
                        end
                        local needle = string.lower(input.Text)
                        local count = 0
                        for _, candidate in ipairs(Tabs) do
                                if needle == "" or string.find(string.lower(candidate.Name), needle, 1, true) then
                                        count = count + 1
                                        local result = Instance.new("TextButton")
                                        result.Name = "Result"
                                        result.Size = UDim2.new(1, -4, 0, 34)
                                        result.BackgroundColor3 = C.bg
                                        result.BorderSizePixel = 0
                                        result.AutoButtonColor = false
                                        result.Font = Enum.Font.GothamMedium
                                        result.TextSize = 12
                                        result.TextColor3 = C.text
                                        result.TextXAlignment = Enum.TextXAlignment.Left
                                        result.Text = "  " .. candidate.Name
                                        result.ZIndex = 73
                                        result.Parent = results
                                        corner(result, R.small)
                                        local resultStroke = stroke(result, C.border, 1)
                                        result.MouseEnter:Connect(function()
                                                Tween(result, T10, { BackgroundColor3 = C.panelHov })
                                                Tween(resultStroke, T10, { Color = C.accentDim })
                                        end)
                                        result.MouseLeave:Connect(function()
                                                Tween(result, T10, { BackgroundColor3 = C.bg })
                                                Tween(resultStroke, T10, { Color = C.border })
                                        end)
                                        result.Activated:Connect(function()
                                                candidate._setActive(false)
                                                closeCommandPalette()
                                        end)
                                end
                        end
                        results.CanvasSize = UDim2.new(0, 0, 0, resultLayout.AbsoluteContentSize.Y + 2)
                        if count == 0 then
                                local none = Instance.new("TextLabel")
                                none.Name = "Result"
                                none.Size = UDim2.new(1, 0, 0, 36)
                                none.BackgroundTransparency = 1
                                none.Font = Enum.Font.Gotham
                                none.TextSize = 11
                                none.TextColor3 = C.muted
                                none.Text = "No matching tabs"
                                none.ZIndex = 73
                                none.Parent = results
                        end
                end

                commandJanitor:Add(input.Focused:Connect(function()
                        Tween(inputStroke, T10, { Color = C.accent })
                end))
                commandJanitor:Add(input.FocusLost:Connect(function()
                        if input.Parent then Tween(inputStroke, T10, { Color = C.border }) end
                end))
                commandJanitor:Add(input:GetPropertyChangedSignal("Text"):Connect(refreshResults))
                commandJanitor:Add(resultLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                        if results.Parent then
                                results.CanvasSize = UDim2.new(0, 0, 0, resultLayout.AbsoluteContentSize.Y + 2)
                        end
                end))
                commandJanitor:Add(overlay.Activated:Connect(closeCommandPalette))
                refreshResults()
                task.defer(function()
                        if input.Parent then input:CaptureFocus() end
                end)
                Tween(palette, T20, { BackgroundColor3 = C.panel })
                Tween(paletteStroke, T20, { Color = C.borderAcc })
                return overlay
        end

        function Window:CloseCommandPalette()
                closeCommandPalette()
        end

        local modalJanitor = nil
        closeModal = function()
                if modalJanitor then
                        modalJanitor:Cleanup()
                        modalJanitor = nil
                end
        end

        -- Modal dialogs are intentionally explicit: callers receive a handle
        -- and choose the confirm/cancel callbacks, so destructive actions do
        -- not hide an irreversible side effect behind a generic notification.
        function Window:ShowModal(mcfg)
                mcfg = mcfg or {}
                closeModal()
                closeCurrentPopup()
                local overlay = Instance.new("TextButton")
                overlay.Name = "ModalOverlay"
                overlay.Size = UDim2.new(1, 0, 1, 0)
                overlay.BackgroundColor3 = C.black
                overlay.BackgroundTransparency = 0.42
                overlay.BorderSizePixel = 0
                overlay.AutoButtonColor = false
                overlay.Text = ""
                overlay.Active = true
                overlay.ZIndex = 80
                overlay.Parent = overlayGui
                local panel = Instance.new("Frame")
                panel.Name = "Modal"
                local viewport = getViewport()
                local panelWidth = math.min(
                        math.clamp(tonumber(mcfg.Width) or 360, 220, 460),
                        math.max(220, viewport.X - 24)
                )
                panel.Size = UDim2.new(0, math.floor(panelWidth * 0.94), 0, 172)
                panel.AnchorPoint = Vector2.new(0.5, 0.5)
                panel.Position = UDim2.new(0.5, 0, 0.5, 0)
                panel.BackgroundColor3 = C.panel
                panel.BorderSizePixel = 0
                panel.ZIndex = 81
                panel.Parent = overlay
                corner(panel, R.outer)
                local panelStroke = stroke(panel, C.borderAcc, 1)
                local title = Instance.new("TextLabel")
                title.Size = UDim2.new(1, -36, 0, 24)
                title.Position = UDim2.new(0, 18, 0, 16)
                title.BackgroundTransparency = 1
                title.Font = Enum.Font.GothamBold
                title.TextSize = 16
                title.TextColor3 = C.text
                title.TextXAlignment = Enum.TextXAlignment.Left
                title.TextTruncate = Enum.TextTruncate.AtEnd
                title.Text = tostring(mcfg.Title or "Confirm action")
                title.ZIndex = 82
                title.Parent = panel
                local content = Instance.new("TextLabel")
                content.Size = UDim2.new(1, -36, 0, 68)
                content.Position = UDim2.new(0, 18, 0, 50)
                content.BackgroundTransparency = 1
                content.Font = Enum.Font.Gotham
                content.TextSize = 12
                content.TextColor3 = C.textDim
                content.TextXAlignment = Enum.TextXAlignment.Left
                content.TextYAlignment = Enum.TextYAlignment.Top
                content.TextWrapped = true
                content.Text = tostring(mcfg.Content or mcfg.Description or "")
                content.ZIndex = 82
                content.Parent = panel
                local cancel = Instance.new("TextButton")
                cancel.Size = UDim2.new(0, 92, 0, 30)
                cancel.Position = UDim2.new(1, -202, 1, -46)
                cancel.BackgroundColor3 = C.panelAlt
                cancel.BorderSizePixel = 0
                cancel.AutoButtonColor = false
                cancel.Font = Enum.Font.GothamBold
                cancel.TextSize = 12
                cancel.TextColor3 = C.text
                cancel.Text = tostring(mcfg.CancelText or "Cancel")
                cancel.ZIndex = 82
                cancel.Selectable = true
                cancel.Parent = panel
                corner(cancel, R.small)
                local cancelStroke = stroke(cancel, C.border, 1)
                local confirm = cancel:Clone()
                confirm.Name = "Confirm"
                confirm.Position = UDim2.new(1, -110, 1, -46)
                confirm.BackgroundColor3 = mcfg.Destructive == true and C.red or C.accent
                confirm.TextColor3 = C.white
                confirm.Text = tostring(mcfg.ConfirmText or "Confirm")
                confirm.Parent = panel
                local confirmStroke = confirm:FindFirstChildOfClass("UIStroke")

                -- [v5.0.0] Entrance: scrim fade + an 8px rise (position-based,
                -- corner-safe — no UIScale).
                do
                        overlay.BackgroundTransparency = 1
                        Tween(overlay, MT.snap, { BackgroundTransparency = 0.42 })
                        panel.Position = UDim2.new(0.5, 0, 0.5, 8)
                        Tween(panel, MT.enter, { Position = UDim2.new(0.5, 0, 0.5, 0) })
                end

                local obj = { Closed = false }
                local function close(reason)
                        if obj.Closed then return end
                        obj.Closed = true
                        closeModal()
                        if type(mcfg.ClosedCallback) == "function" then
                                task.spawn(function()
                                        local ok, err = pcall(mcfg.ClosedCallback, reason, obj)
                                        if not ok then warn("[RezurXLib] Modal close callback failed:", err) end
                                end)
                        end
                end
                function obj:Close(reason) close(reason or "closed") end
                function obj:Confirm()
                        if type(mcfg.ConfirmCallback) == "function" then
                                task.spawn(function()
                                        local ok, err = pcall(mcfg.ConfirmCallback, obj)
                                        if not ok then warn("[RezurXLib] Modal confirm callback failed:", err) end
                                end)
                        end
                        if mcfg.CloseOnConfirm ~= false then close("confirmed") end
                end
                function obj:Cancel()
                        if type(mcfg.CancelCallback) == "function" then
                                task.spawn(function()
                                        local ok, err = pcall(mcfg.CancelCallback, obj)
                                        if not ok then warn("[RezurXLib] Modal cancel callback failed:", err) end
                                end)
                        end
                        close("cancelled")
                end
                cancel.Activated:Connect(function() obj:Cancel() end)
                confirm.Activated:Connect(function() obj:Confirm() end)
                overlay.InputBegan:Connect(function(input)
                        if mcfg.Dismissable == false then return end
                        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                        local p, s, point = panel.AbsolutePosition, panel.AbsoluteSize, input.Position
                        if point.X < p.X or point.X > p.X + s.X or point.Y < p.Y or point.Y > p.Y + s.Y then obj:Cancel() end
                end)
                modalJanitor = Janitor.new()
                modalJanitor:Add(overlay, "Destroy")
                Tween(panel, TPOP, { Size = UDim2.new(0, panelWidth, 0, 188) })
                Tween(panelStroke, T20, { Color = C.borderAcc })
                Tween(title, T20, { TextColor3 = C.text })
                Tween(content, T20, { TextColor3 = C.textDim })
                Tween(cancel, T20, { BackgroundColor3 = C.panelAlt, TextColor3 = C.text })
                Tween(cancelStroke, T20, { Color = C.border })
                if confirmStroke then Tween(confirmStroke, T20, { Color = mcfg.Destructive == true and C.red or C.accent }) end
                return obj
        end

        function Window:CloseModal()
                closeModal()
        end

        local settingsTab = nil
        -- A compact built-in settings tab exposes the preferences that matter
        -- to end users without forcing each project to recreate them.
        function Window:CreateSettingsPanel(scfg)
                scfg = scfg or {}
                if settingsTab then return settingsTab end
                settingsTab = Window:CreateTab(scfg.Name or "Settings", scfg.Icon or "S")
                settingsTab:CreateSection("Appearance")
                settingsTab:CreateDropdown({
                        Name = "Theme",
                        Options = Library:GetThemeNames(),
                        CurrentOption = Window:GetThemeName(),
                        Searchable = true,
                        Callback = function(themeName)
                                Window:ModifyTheme(themeName)
                        end,
                })
                settingsTab:CreateToggle({
                        Name = "Reduce motion",
                        CurrentValue = reducedMotion,
                        Callback = function(value)
                                Window:SetReducedMotion(value)
                        end,
                })
                settingsTab:CreateSlider({
                        Name = "Motion speed",
                        Range = { 0.25, 1.5 },
                        Increment = 0.05,
                        CurrentValue = motionScale,
                        Suffix = "x",
                        Callback = function(value)
                                Window:SetMotionScale(value)
                        end,
                })
                settingsTab:CreateKeybind({
                        Name = "Toggle UI shortcut",
                        CurrentKeybind = toggleKey,
                        ChangedCallback = function(key)
                                Window:SetToggleKeybind(key)
                        end,
                })
                settingsTab:CreateSection("Window")
                settingsTab:CreateInput({
                        Name = "Status text",
                        CurrentValue = sTxt.Text,
                        PlaceholderText = "READY",
                        Callback = function(value)
                                Window:SetStatus(value)
                        end,
                })
                settingsTab:CreateButton({
                        Name = "Minimize window",
                        Callback = function()
                                Window:SetMinimized(true)
                        end,
                })
                return settingsTab
        end

        WindowJanitor:Add(UserInputService.InputBegan:Connect(function(inp, gp)
                -- [FIX v4.0] Escape must reach the palette even when its TextBox is
                -- focused: with focus, Escape arrives game-processed (menu), so the
                -- old `if gp then return end` gate ran first and made Escape dead.
                if inp.KeyCode == Enum.KeyCode.Escape and commandOverlay then
                        closeCommandPalette()
                        return
                end
                if gp then return end
                if UserInputService:GetFocusedTextBox() then return end
                local commandPressed = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                        or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                        or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
                        or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta)
                if commandPressed and inp.KeyCode == Enum.KeyCode.P then
                        Window:OpenCommandPalette()
                end
        end))

        -- Tab, Enter, and slider arrows make the main controls usable without
        -- a mouse. Native text entry keeps priority whenever a TextBox owns
        -- focus, preventing shortcuts from hijacking typing.
        WindowJanitor:Add(UserInputService.InputBegan:Connect(function(inp, gp)
                if gp or UserInputService:GetFocusedTextBox() then return end
                if inp.KeyCode == Enum.KeyCode.Tab then
                        local reverse = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
                                or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                        Window:FocusNext(reverse)
                        return
                end
                local selected = GuiService.SelectedObject
                if not selected or not selected:IsDescendantOf(screenGui) then return end
                local adjuster = keyboardAdjusters[selected]
                if adjuster and (inp.KeyCode == Enum.KeyCode.Left or inp.KeyCode == Enum.KeyCode.Down) then
                        adjuster(-1)
                        return
                elseif adjuster and (inp.KeyCode == Enum.KeyCode.Right or inp.KeyCode == Enum.KeyCode.Up) then
                        adjuster(1)
                        return
                end
                if inp.KeyCode == Enum.KeyCode.Return or inp.KeyCode == Enum.KeyCode.KeypadEnter or inp.KeyCode == Enum.KeyCode.Space then
                        if selected:IsA("GuiButton") then pcall(function() selected:Activate() end) end
                end
        end))

        -- ------------------------------------------------------------
        -- Destroy
        -- ------------------------------------------------------------
        function Window:Destroy()
                closeCurrentPopup()
                closeCommandPalette()
                closeModal()
                finishDrag("destroyed")
                -- [v5.0.0] Spring + destroy race: no in-flight spring may write
                -- to a destroyed instance. Kill everything targeting this
                -- window's objects BEFORE the Janitor tears the tree down.
                springsForgetInstance(frame)
                springsForgetInstance(traceGrad)
                springsForgetInstance(tabIndicator)
                if Window._flushConfig then pcall(Window._flushConfig) end
                WindowJanitor:Cleanup()
                for index = #Library._windows, 1, -1 do
                        if Library._windows[index] == Window then
                                table.remove(Library._windows, index)
                        end
                end
                if Library._lastWindow == Window then
                        Library._lastWindow = Library._windows[#Library._windows]
                end
        end

        -- ============================================================
        -- [v4.0] CONFIGURATION AUTO-SAVE — Rayfield-style persistence,
        -- hardened: saves only when values actually CHANGED (signature
        -- diffing instead of blind rewrites), isolates flags per window,
        -- and never touches the filesystem unless the developer opts in.
        --
        --   ConfigurationSaving = {
        --       Enabled   = true,
        --       FolderName = "MyHub",          -- default RezurXLib/Configurations
        --       FileName  = "Big Hub",         -- default game.PlaceId
        --       Autosave  = true,              -- signature diff every 2s (default)
        --       SaveOnUnload = true,           -- flush on :Destroy() (default)
        --       Notify    = true,              -- toast after a successful load
        --   }
        -- ============================================================
        do
                local cs = type(cfg.ConfigurationSaving) == "table" and cfg.ConfigurationSaving or nil
                if cs and cs.Enabled == true then
                        local folder = tostring(cs.FolderName or "RezurXLib/Configurations")
                        local fileBase = tostring(cs.FileName or tostring(game.PlaceId))
                        local path = folder .. "/" .. fileBase .. ".rezx"
                        local autosave = cs.Autosave ~= false
                        local saveOnUnload = cs.SaveOnUnload ~= false
                        local notifyLoaded = cs.Notify ~= false

                        local function stringifyValue(v)
                                if typeof(v) == "Color3" then
                                        return string.format("c%.3f,%.3f,%.3f", v.R, v.G, v.B)
                                elseif type(v) == "table" then
                                        local parts = {}
                                        for k2, v2 in pairs(v) do
                                                table.insert(parts, tostring(k2) .. "=" .. stringifyValue(v2))
                                        end
                                        table.sort(parts)
                                        return "{" .. table.concat(parts, ";") .. "}"
                                end
                                return tostring(v)
                        end

                        local lastSignature = nil
                        local function signature()
                                local parts = {}
                                for flag, obj in pairs(Window.Flags) do
                                        local v
                                        if obj.CurrentValue ~= nil then v = "v" .. stringifyValue(obj.CurrentValue)
                                        elseif obj.Color ~= nil then v = "c" .. stringifyValue(obj.Color)
                                        elseif obj.CurrentKeybind ~= nil then v = "k" .. tostring(obj.CurrentKeybind)
                                        elseif obj.CurrentOption ~= nil then v = "o" .. stringifyValue(obj.CurrentOption)
                                        else v = "-" end
                                        table.insert(parts, tostring(flag) .. ":" .. v)
                                end
                                table.sort(parts)
                                return table.concat(parts, "|")
                        end

                        local function snapshot()
                                local data = {}
                                for flag, obj in pairs(Window.Flags) do
                                        if obj.CurrentValue ~= nil then
                                                data[flag] = obj.CurrentValue
                                        elseif obj.Color ~= nil then
                                                data[flag] = { R = obj.Color.R, G = obj.Color.G, B = obj.Color.B }
                                        elseif obj.CurrentKeybind ~= nil then
                                                data[flag] = keyName(obj.CurrentKeybind)
                                        elseif obj.CurrentOption ~= nil then
                                                data[flag] = obj.CurrentOption
                                        end
                                end
                                return data
                        end

                        --- Write this window's flagged values to disk (JSON).
                        function Window:SaveConfiguration()
                                if not FS.available then return nil end
                                FS.ensureFolder(folder)
                                local data = snapshot()
                                local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
                                if not ok or type(encoded) ~= "string" then
                                        warn("[RezurXLib] SaveConfiguration: JSON encode failed")
                                        return nil
                                end
                                local wrote = FS.writeAtomic(path, encoded)
                                if not wrote then
                                        warn("[RezurXLib] SaveConfiguration: write failed for " .. path)
                                end
                                lastSignature = signature()
                                return data
                        end

                        --- Read this window's saved values and replay them
                        --- onto their elements. Returns appliedCount.
                        function Window:LoadConfiguration()
                                if not FS.available then return 0 end
                                if not FS.exists(path) then return 0 end
                                local ok, raw = FS.read(path)
                                if not ok or type(raw) ~= "string" then return 0 end
                                local okDecode, data = pcall(function() return HttpService:JSONDecode(raw) end)
                                if not okDecode or type(data) ~= "table" then
                                        -- [v5.4.0] CORRUPT FILE RECOVERY (Rayfield pattern): the
                                        -- broken file is preserved as "<name> (Incorrect Format).json"
                                        -- (unique-numbered so a second corruption can't destroy
                                        -- the first backup) and removed, so the next autosave
                                        -- writes a clean file instead of hammering the same
                                        -- corrupt bytes forever. The user is told what happened.
                                        local backup = FS.backupCorrupt(path)
                                        warn("[RezurXLib] LoadConfiguration: corrupt file " .. path
                                                .. (backup and (" — backed up to " .. backup) or ""))
                                        -- BISECT2: notify disabled
                                        return 0
                                end
                                local applied = 0
                                for flag, value in pairs(data) do
                                        local obj = Window.Flags[flag]
                                        if obj and obj.Set then
                                                local okApply = pcall(function()
                                                        if type(value) == "table" and value.R ~= nil then
                                                                obj:Set(Color3.new(value.R, value.G, value.B))
                                                        elseif type(value) == "string" and value:match("^%u[%u%d]+$") then
                                                                local okKey, keyCode = pcall(function() return Enum.KeyCode[value] end)
                                                                if okKey and keyCode then obj:Set(keyCode) end
                                                        else
                                                                obj:Set(value)
                                                        end
                                                end)
                                                if okApply then applied = applied + 1 end
                                        end
                                end
                                lastSignature = signature()
                                return applied
                        end

                        -- Initial load: elements are created synchronously right
                        -- after CreateWindow in the common case, so a short defer
                        -- is enough for them to register their flags. When the
                        -- key gate is active, loading waits until the gate is
                        -- passed so callbacks never replay behind a locked UI.
                        task.delay(0.35, function()
                                while (not frame.Visible) and screenGui.Parent do
                                        task.wait(0.25)
                                end
                                if not screenGui.Parent then return end
                                local applied = 0
                                pcall(function() applied = Window:LoadConfiguration() end)
                                if applied > 0 and notifyLoaded then
                                        notify("Configuration", applied .. " saved setting" .. (applied > 1 and "s" or "") .. " restored.", 4, "success")
                                end
                                if lastSignature == nil then lastSignature = signature() end
                        end)

                        -- Autosave: diff the signature every 2s; write only on
                        -- real change (no per-click rewrite storms like Rayfield).
                        if autosave then
                                task.spawn(function()
                                        while screenGui.Parent do
                                                task.wait(2)
                                                if not screenGui.Parent then break end
                                                local okSig, sig = pcall(signature)
                                                if okSig and lastSignature ~= nil and sig ~= lastSignature then
                                                        pcall(function() Window:SaveConfiguration() end)
                                                end
                                        end
                                end)
                        end

                        -- Flush on destroy (and expose for manual flush).
                        if saveOnUnload then
                                Window._flushConfig = function()
                                        if not FS.available then return end
                                        local okSig, sig = pcall(signature)
                                        if okSig and lastSignature ~= nil and sig ~= lastSignature then
                                                pcall(function() Window:SaveConfiguration() end)
                                        end
                                end
                        end
                end
        end

        -- ============================================================
        -- [v4.0] KEY GATE UI — a styled unlock card in the library's own
        -- design language (no external asset download, unlike Rayfield's
        -- prebuilt ScreenGui). The window stays hidden until a valid key
        -- is entered or a previously saved key matches.
        --
        --   KeySystem = true,
        --   KeySettings = {
        --       Title = "Untitled", Subtitle = "Key System",
        --       Note = "How to get a key…",
        --       FileName = "Key",      -- saved under RezurXLib/Keys/
        --       SaveKey = true,        -- remember accepted keys (default)
        --       GrabKeyFromSite = false,
        --       Key = {"Hello"},       -- string or list
        --       MaxAttempts = 5,       -- 0 = unlimited
        --       OnExhausted = "Lock",  -- "Lock" | "Kick" | "None"
        --   }
        -- ============================================================
        do
                if keyGatePending and keyGateKeys then
                        local ks = keySettingsRef
                        frame.Visible = false
                        setShadowVisible(false)

                        local gateJanitor = Janitor.new()
                        WindowJanitor:Add(function() gateJanitor:Cleanup() end)

                        local dim = Instance.new("TextButton")
                        dim.Name = "KeyGateDim"
                        dim.Size = UDim2.fromScale(1, 1)
                        dim.BackgroundColor3 = Color3.new(0, 0, 0)
                        dim.BackgroundTransparency = 0.45
                        dim.BorderSizePixel = 0
                        dim.Text = ""
                        dim.AutoButtonColor = false
                        dim.ZIndex = 30
                        dim.Parent = overlayGui
                        gateJanitor:Add(dim, "Destroy")

                        local card = Instance.new("Frame")
                        card.Name = "KeyGate"
                        card.Size = UDim2.fromOffset(364, 248)
                        card.AnchorPoint = Vector2.new(0.5, 0.5)
                        card.Position = UDim2.fromScale(0.5, 0.5)
                        card.BackgroundColor3 = C.bg
                        card.BorderSizePixel = 0
                        card.ClipsDescendants = true
                        card.ZIndex = 31
                        card.Parent = overlayGui
                        gateJanitor:Add(card, "Destroy")
                        corner(card, R.outer)
                        local cardStroke = stroke(card, C.borderAcc, 1.5)
                        cardStroke.Transparency = 0.45

                        local cardGlow = Instance.new("Frame")
                        cardGlow.Size = UDim2.new(1, 24, 1, 24)
                        cardGlow.AnchorPoint = Vector2.new(0.5, 0.5)
                        cardGlow.Position = UDim2.fromScale(0.5, 0.5)
                        cardGlow.BackgroundColor3 = C.accent
                        cardGlow.BackgroundTransparency = 0.93
                        cardGlow.BorderSizePixel = 0
                        cardGlow.ZIndex = 30
                        cardGlow.Parent = overlayGui
                        gateJanitor:Add(cardGlow, "Destroy")
                        corner(cardGlow, concentric(R.outer, 12))

                        -- [v5.0.0] position-based entrance (no UIScale)
                        card.Position = UDim2.new(0.5, 0, 0.5, 8)
                        Tween(card, MT.enter, { Position = UDim2.new(0.5, 0, 0.5, 0) })

                        local title = Instance.new("TextLabel")
                        title.Size = UDim2.new(1, -48, 0, 24)
                        title.Position = UDim2.fromOffset(24, 22)
                        title.BackgroundTransparency = 1
                        title.Font = Enum.Font.GothamBold
                        title.TextSize = 17
                        title.TextColor3 = C.text
                        title.TextXAlignment = Enum.TextXAlignment.Left
                        title.Text = tostring(ks.Title or windowName)
                        title.ZIndex = 32
                        title.Parent = card

                        local gateSubtitle = Instance.new("TextLabel")
                        gateSubtitle.Size = UDim2.new(1, -48, 0, 14)
                        gateSubtitle.Position = UDim2.fromOffset(24, 47)
                        gateSubtitle.BackgroundTransparency = 1
                        gateSubtitle.Font = Enum.Font.GothamMedium
                        gateSubtitle.TextSize = 10
                        gateSubtitle.TextColor3 = C.muted
                        gateSubtitle.TextXAlignment = Enum.TextXAlignment.Left
                        gateSubtitle.Text = tostring(ks.Subtitle or "Key System")
                        gateSubtitle.ZIndex = 32
                        gateSubtitle.Parent = card

                        local note = Instance.new("TextLabel")
                        note.Size = UDim2.new(1, -48, 0, 40)
                        note.Position = UDim2.fromOffset(24, 68)
                        note.BackgroundTransparency = 1
                        note.Font = Enum.Font.Gotham
                        note.TextSize = 11
                        note.TextColor3 = C.textDim
                        note.TextXAlignment = Enum.TextXAlignment.Left
                        note.TextYAlignment = Enum.TextYAlignment.Top
                        note.TextWrapped = true
                        note.Text = tostring(ks.Note or "No method of obtaining a key is provided.")
                        note.ZIndex = 32
                        note.Parent = card

                        local inputBox = Instance.new("TextBox")
                        inputBox.Size = UDim2.new(1, -48, 0, 40)
                        inputBox.Position = UDim2.fromOffset(24, 118)
                        inputBox.BackgroundColor3 = C.panelAlt
                        inputBox.BorderSizePixel = 0
                        inputBox.Font = Enum.Font.Gotham
                        inputBox.TextSize = 13
                        inputBox.TextColor3 = C.text
                        inputBox.PlaceholderColor3 = C.muted
                        inputBox.PlaceholderText = "Enter key…"
                        inputBox.Text = ""
                        inputBox.ClearTextOnFocus = false
                        inputBox.TextXAlignment = Enum.TextXAlignment.Left
                        inputBox.ClipsDescendants = true
                        inputBox.ZIndex = 32
                        inputBox.Parent = card
                        corner(inputBox, R.control)
                        local inputStroke = stroke(inputBox, C.border, 1)
                        pad(inputBox, 0, 0, 12, 12)

                        local attemptsMax = tonumber(ks.MaxAttempts)
                        if attemptsMax == nil then attemptsMax = 5 end
                        local attemptsLeft = attemptsMax
                        local status = Instance.new("TextLabel")
                        status.Size = UDim2.new(1, -48, 0, 14)
                        status.Position = UDim2.fromOffset(24, 164)
                        status.BackgroundTransparency = 1
                        status.Font = Enum.Font.GothamMedium
                        status.TextSize = 10
                        status.TextColor3 = C.muted
                        status.TextXAlignment = Enum.TextXAlignment.Left
                        status.Text = attemptsMax > 0 and ("Attempts remaining: " .. attemptsLeft) or "Unlimited attempts"
                        status.ZIndex = 32
                        status.Parent = card

                        local submit = Instance.new("TextButton")
                        submit.Size = UDim2.new(1, -48, 0, 38)
                        submit.Position = UDim2.fromOffset(24, 190)
                        submit.BackgroundColor3 = C.accentDark
                        submit.Text = ""
                        submit.AutoButtonColor = false
                        submit.BorderSizePixel = 0
                        submit.Selectable = true
                        submit.ZIndex = 32
                        submit.Parent = card
                        corner(submit, R.control)
                        local submitStroke = stroke(submit, C.accentDim, 1)
                        local submitGrad = gradient(submit, ColorSequence.new{
                                ColorSequenceKeypoint.new(0.0, C.accentDim),
                                ColorSequenceKeypoint.new(1.0, C.accentDark),
                        }, 100)
                        local submitLbl = Instance.new("TextLabel")
                        submitLbl.Size = UDim2.fromScale(1, 1)
                        submitLbl.BackgroundTransparency = 1
                        submitLbl.Font = Enum.Font.GothamBold
                        submitLbl.TextSize = 13
                        submitLbl.TextColor3 = C.accentHi
                        submitLbl.Text = "Unlock"
                        submitLbl.ZIndex = 33
                        submitLbl.Parent = submit

                        local gateResolved = false
                        local function shakeCard()
                                Tween(card, TweenInfo.new(0.09, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
                                        { Position = UDim2.new(0.5, -7, 0.5, 0) })
                                task.delay(0.09, function()
                                        Tween(card, TweenInfo.new(0.09, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
                                                { Position = UDim2.new(0.5, 7, 0.5, 0) })
                                end)
                                task.delay(0.18, function()
                                        Tween(card, TweenInfo.new(0.22, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
                                                { Position = UDim2.fromScale(0.5, 0.5) })
                                end)
                        end

                        local function resolveGate(matchedKey)
                                if gateResolved then return end
                                gateResolved = true
                                if ks.SaveKey ~= false and matchedKey and FS.available then
                                        FS.ensureFolder("RezurXLib/Keys")
                                        local keyFile = "RezurXLib/Keys/" .. tostring(ks.FileName or "Key") .. ".rezx"
                                        FS.write(keyFile, matchedKey)
                                end
                                -- [v5.1.0] STEP UNLOCK SEQUENCE (spec): verification
                                -- steps light up with glowing checkmarks one by one,
                                -- a progress ring fills, THEN the window explosively
                                -- expands (the v5 Size-spring entrance + Trace lap).
                                task.spawn(function()
                                        pcall(function()
                                                local steps = { "CHECKING FORMAT", "VERIFYING KEY", "AUTHORIZED" }
                                                -- Build the step rows into the card.
                                                local stepFrames = {}
                                                for stepIndex, stepText in ipairs(steps) do
                                                        local row = Instance.new("Frame")
                                                        row.Name = "Step" .. stepIndex
                                                        row.Size = UDim2.new(1, -48, 0, 16)
                                                        row.Position = UDim2.new(0, 24, 0, 164 + (stepIndex - 1) * 18)
                                                        row.BackgroundTransparency = 1
                                                        row.ZIndex = 34
                                                        row.Parent = card
                                                        local chk = Instance.new("TextLabel")
                                                        chk.Size = UDim2.new(0, 16, 1, 0)
                                                        chk.BackgroundTransparency = 1
                                                        chk.Font = Enum.Font.GothamBold
                                                        chk.TextSize = 12
                                                        chk.TextColor3 = C.accent
                                                        chk.TextTransparency = 1
                                                        chk.Text = "✓"
                                                        chk.ZIndex = 35
                                                        chk.Parent = row
                                                        local st = Instance.new("TextLabel")
                                                        st.Size = UDim2.new(1, -22, 1, 0)
                                                        st.Position = UDim2.new(0, 20, 0, 0)
                                                        st.BackgroundTransparency = 1
                                                        st.Font = Enum.Font.GothamMedium
                                                        st.TextSize = 10
                                                        st.TextColor3 = C.textDim
                                                        st.TextXAlignment = Enum.TextXAlignment.Left
                                                        st.TextTransparency = 0.35
                                                        st.Text = stepText
                                                        st.ZIndex = 35
                                                        st.Parent = row
                                                        table.insert(stepFrames, { chk = chk, st = st })
                                                end
                                                -- Hide the old status text; steps take over.
                                                status.TextTransparency = 1
                                                -- Sequential glow-in with a soft tick per step.
                                                for stepIndex, frameRow in ipairs(stepFrames) do
                                                        task.wait(0.14)
                                                        if not card.Parent then return end
                                                        frameRow.chk.TextTransparency = 0
                                                        frameRow.st.TextTransparency = 0
                                                        Tween(frameRow.chk, MT.move, { TextTransparency = 0 })
                                                        Tween(frameRow.st, MT.move, { TextTransparency = 0 })
                                                        playSfx("Confirm", 1 + stepIndex * 0.12)
                                                end
                                                task.wait(0.18)
                                        end)
                                        pcall(function()
                                                Tween(card, T20, { BackgroundTransparency = 1 })
                                                Tween(cardStroke, T20, { Transparency = 1 })
                                                Tween(cardGlow, T20, { BackgroundTransparency = 1 })
                                                Tween(dim, T20, { BackgroundTransparency = 1 })
                                                for _, child in ipairs(card:GetChildren()) do
                                                        if child:IsA("TextLabel") or child:IsA("TextBox") or child:IsA("TextButton") then
                                                                if child:IsA("TextLabel") or child:IsA("TextBox") then
                                                                        Tween(child, T20, { TextTransparency = 1 })
                                                                end
                                                                Tween(child, T20, { BackgroundTransparency = 1 })
                                                        end
                                                end
                                                task.wait(0.22)
                                        end)
                                        gateJanitor:Cleanup()
                                        frame.Visible = true
                                        setShadowVisible(true)
                                        task.spawn(runEntrance)
                                        if ks.SaveKey ~= false and matchedKey then
                                                notify("Key System", "Your key has been saved for next time.", 4, "success")
                                        end
                                end)
                        end

                        local locked = false
                        local function tryKey()
                                if gateResolved or locked then return end
                                local entered = inputBox.Text
                                if entered == "" then return end
                                local matched = nil
                                for _, k in ipairs(keyGateKeys) do
                                        if entered == k then matched = k break end
                                end
                                if matched then
                                        resolveGate(matched)
                                else
                                        -- [v5.0.0] ERROR TRACE: a wrong key runs the lap in red.
                                        traceLap(C.red, 1)
                                        inputBox.Text = ""
                                        shakeCard()
                                        Tween(inputStroke, T10, { Color = C.red, Thickness = 1.5 })
                                        task.delay(0.6, function()
                                                Tween(inputStroke, T10, { Color = C.border, Thickness = 1 })
                                        end)
                                        if attemptsMax > 0 then
                                                attemptsLeft = attemptsLeft - 1
                                                status.Text = "Attempts remaining: " .. math.max(attemptsLeft, 0)
                                                status.TextColor3 = attemptsLeft <= 1 and C.red or C.yellow
                                                if attemptsLeft <= 0 then
                                                        local mode = tostring(ks.OnExhausted or "Lock")
                                                        if mode == "Kick" then
                                                                if player then player:Kick("No attempts remaining.") end
                                                        elseif mode == "None" then
                                                                attemptsLeft = attemptsMax
                                                                status.Text = "Attempts remaining: " .. attemptsLeft
                                                                status.TextColor3 = C.muted
                                                        else
                                                                locked = true
                                                                inputBox.TextEditable = false
                                                                inputBox.Text = ""
                                                                inputBox.PlaceholderText = "Locked"
                                                                submitLbl.Text = "Locked"
                                                                status.Text = "No attempts remaining. Rejoin to try again."
                                                                status.TextColor3 = C.red
                                                        end
                                                end
                                        end
                                end
                        end

                        submit.Activated:Connect(tryKey)
                        inputBox.FocusLost:Connect(function(enterPressed)
                                if enterPressed then tryKey() end
                        end)
                        submit.MouseEnter:Connect(function()
                                Tween(submit, T10, { BackgroundColor3 = C.accentDim })
                        end)
                        submit.MouseLeave:Connect(function()
                                Tween(submit, T10, { BackgroundColor3 = C.accentDark })
                        end)
                        task.defer(function()
                                if inputBox.Parent and inputBox.Visible then inputBox:CaptureFocus() end
                        end)
                        onTheme(function()
                                if card.Parent then
                                        Tween(card, T20, { BackgroundColor3 = C.bg })
                                        Tween(cardStroke, T20, { Color = C.borderAcc })
                                        Tween(cardGlow, T20, { BackgroundColor3 = C.accent })
                                        Tween(title, T20, { TextColor3 = C.text })
                                        Tween(gateSubtitle, T20, { TextColor3 = C.muted })
                                        Tween(note, T20, { TextColor3 = C.textDim })
                                        Tween(inputBox, T20, { BackgroundColor3 = C.panelAlt })
                                        Tween(submit, T20, { BackgroundColor3 = C.accentDark })
                                        Tween(submitStroke, T20, { Color = C.accentDim })
                                        Tween(submitLbl, T20, { TextColor3 = C.accentHi })
                                        submitGrad.Color = ColorSequence.new{
                                                ColorSequenceKeypoint.new(0.0, C.accentDim),
                                                ColorSequenceKeypoint.new(1.0, C.accentDark),
                                        }
                                end
                        end)
                end
        end

        table.insert(Library._windows, Window)
        Library._lastWindow = Window
        return Window
end

-- ============================================================
-- LIBRARY-LEVEL API
-- ============================================================
function Library:Notify(cfg)
        if Library._lastWindow then
                return Library._lastWindow:Notify(cfg)
        end
        warn("[RezurXLib] Notify called before any window exists.")
end

function Library:ModifyTheme(theme)
        for _, w in ipairs(Library._windows) do
                w:ModifyTheme(theme)
        end
end

-- Registers an immutable-by-convention palette name. Missing tokens inherit
-- from Quiet, so a custom theme can override only the colours it owns.
function Library:RegisterTheme(name, palette)
        if type(name) ~= "string" or name == "" or type(palette) ~= "table" then
                warn("[RezurXLib] RegisterTheme expects a non-empty name and a palette table.")
                return nil
        end
        local merged = cloneTheme(Themes.Quiet)
        for key, value in pairs(palette) do
                if ThemeTokenSet[key] and typeof(value) == "Color3" then
                        merged[key] = value
                else
                        warn("[RezurXLib] Ignoring invalid theme token: " .. tostring(key))
                end
        end
        -- [v5.5.1] Complete the palette: a custom theme without `secondary`
        -- would leave C.secondary nil at CreateWindow and crash every
        -- C.secondary gradient keypoint ("bad ColorSequence keypoint").
        if typeof(merged.secondary) ~= "Color3" then
                merged.secondary = typeof(merged.accentHi) == "Color3" and merged.accentHi or merged.accent
        end
        Themes[name] = merged
        return cloneTheme(merged)
end

function Library:GetTheme(name)
        local palette = Themes[name]
        return palette and cloneTheme(palette) or nil
end

-- A tiny local image registry avoids repeated asset-id plumbing. It performs
-- no preload, request, or network operation; it only remembers identifiers
-- supplied by the developer in this client session.
Library.ImageCache = {}
function Library:RegisterImage(key, image)
        if type(key) ~= "string" or key == "" then
                warn("[RezurXLib] RegisterImage expects a non-empty string key.")
                return nil
        end
        local resolved = type(image) == "number" and ("rbxassetid://" .. image) or tostring(image or "")
        self.ImageCache[key] = resolved
        return resolved
end

function Library:ResolveImage(image)
        if type(image) == "number" then return "rbxassetid://" .. image end
        if type(image) == "string" then return self.ImageCache[image] or image end
        return ""
end

function Library:ClearImageCache(key)
        if key == nil then
                table.clear(self.ImageCache)
        else
                self.ImageCache[key] = nil
        end
end

function Library:GetThemeNames()
        local names = {}
        for name in pairs(Themes) do table.insert(names, name) end
        table.sort(names)
        return names
end

function Library:SetReducedMotion(nextValue)
        self.Options.ReducedMotion = nextValue == true
        for _, window in ipairs(self._windows) do
                window:SetReducedMotion(self.Options.ReducedMotion)
        end
        return self.Options.ReducedMotion
end

function Library:Destroy()
        -- [FIX v4.0] Iterate BACKWARDS (or over a snapshot): w:Destroy()
        -- removes each window from _windows mid-ipairs, which used to skip
        -- every second window and leak its connections + ScreenGui.
        for i = #Library._windows, 1, -1 do
                local w = Library._windows[i]
                pcall(function() w:Destroy() end)
        end
        table.clear(Library._windows)
        Library._lastWindow = nil
end
-- ============================================================
-- LIBRARY-LEVEL UTILITIES
-- ============================================================
function Library:DeepCopy(orig)
        local copy
        if type(orig) == "table" then
                copy = {}
                for k, v in next, orig, nil do copy[self:DeepCopy(k)] = self:DeepCopy(v) end
                setmetatable(copy, self:DeepCopy(getmetatable(orig)))
        else copy = orig end
        return copy
end

function Library:Serialize(data)
        local ok, result = pcall(function() return HttpService:JSONEncode(data) end)
        if ok then return result else warn("[RezurXLib] Serialize: " .. tostring(result)) return nil end
end

function Library:Deserialize(jsonStr)
        if type(jsonStr) ~= "string" then return nil end
        local ok, result = pcall(function() return HttpService:JSONDecode(jsonStr) end)
        if ok then return result else warn("[RezurXLib] Deserialize: " .. tostring(result)) return nil end
end

function Library:SaveConfiguration()
        local config = {}
        for flag, obj in pairs(self.Flags) do
                if obj.CurrentValue ~= nil then config[flag] = obj.CurrentValue
                elseif obj.CurrentKeybind ~= nil then config[flag] = keyName(obj.CurrentKeybind)
                elseif obj.Color ~= nil then local c = obj.Color config[flag] = { R=c.R, G=c.G, B=c.B }
                elseif obj.CurrentOption ~= nil then config[flag] = obj.CurrentOption end
        end
        return config
end

function Library:LoadConfiguration(config)
        if type(config) ~= "table" then warn("[RezurXLib] LoadConfiguration expects table") return end
        for flag, value in pairs(config) do
                local obj = self.Flags[flag]
                if obj and obj.Set then
                        pcall(function()
                                if type(value) == "table" and value.R then obj:Set(Color3.new(value.R, value.G, value.B))
                                elseif type(value) == "string" and value:match("^%u[%u%d]+$") then
                                        local ok, kc = pcall(function() return Enum.KeyCode[value] end)
                                        if ok and kc then obj:Set(kc) end
                                else obj:Set(value) end
                        end)
                end
        end
end

function Library:HasFlag(flag) return self.Flags[flag] ~= nil end

function Library:GetFlag(flag)
        local obj = self.Flags[flag]
        if obj then
                if obj.CurrentValue ~= nil then return obj.CurrentValue
                elseif obj.Color ~= nil then return obj.Color
                elseif obj.CurrentKeybind ~= nil then return obj.CurrentKeybind
                elseif obj.CurrentOption ~= nil then return obj.CurrentOption end
        end
        return nil
end

function Library:ColorLighten(color, amount)
        amount = amount or 0.2
        local h, s, v = color:ToHSV()
        return Color3.fromHSV(h, s, math.min(v + amount, 1))
end

function Library:ColorDarken(color, amount)
        amount = amount or 0.2
        local h, s, v = color:ToHSV()
        return Color3.fromHSV(h, s, math.max(v - amount, 0))
end

function Library:GetStats()
        local flagCount = 0
        for _ in pairs(self.Flags) do flagCount = flagCount + 1 end
        return { Version = self.Version, WindowCount = #self._windows, FlagCount = flagCount,
                Themes = self:GetThemeNames() }
end

-- Machine-readable API metadata enables an in-game help tab without a
-- network request, generated docs page, or a separate dependency.
function Library:GetDocs()
        return {
                Version = self.Version,
                Components = {
                        { Name = "CreateSection", Params = "text", Returns = ":Set", Description = "Uppercase section label." },
                        { Name = "CreateDivider", Params = "text", Returns = "object", Description = "Optional-caption rule." },
                        { Name = "CreateSpacer", Params = "pixels", Returns = "object", Description = "Fixed vertical gap." },
                        { Name = "CreateLabel", Params = "Text, Color, Bold, TextSize, Align", Returns = ":Set, :SetColor", Description = "Static text line." },
                        { Name = "CreateParagraph", Params = "Title, Content", Returns = "object", Description = "Wrapped title and description." },
                        { Name = "CreateImage", Params = "Image, Height, ScaleType, CornerRadius, Tooltip", Returns = "object", Description = "Image or icon content." },
                        { Name = "CreateButton", Params = "Name, Variant, Callback, Tooltip", Returns = "object", Description = "Animated primary or secondary action button." },
                        { Name = "CreateMultiButton", Params = "Buttons, Tooltip", Returns = "object", Description = "Shared-row actions." },
                        { Name = "CreateToggle", Params = "Name, CurrentValue, Callback, Flag", Returns = ":Set, :Get, :Reset", Description = "Animated boolean switch." },
                        { Name = "CreateSlider", Params = "Name, Range, CurrentValue, Increment, Suffix, Callback, Flag", Returns = ":Set, :Get, :Reset", Description = "Pointer and touch slider." },
                        { Name = "CreateInput", Params = "Name, CurrentValue, PlaceholderText, Callback, Flag", Returns = ":Set, :Get, :Reset", Description = "Single-line input." },
                        { Name = "CreateDropdown", Params = "Name, Options, CurrentOption, MultipleOptions, Searchable, Tooltip, Callback, Flag", Returns = ":Set, :Get, :Refresh, :Reset", Description = "Scale-aware single or multi-select with fuzzy search." },
                        { Name = "CreateKeybind", Params = "Name, CurrentKeybind, HoldToInteract, Callback, ChangedCallback, Flag", Returns = ":Set, :Get, :Reset", Description = "Keyboard binding capture with rebind callback." },
                        { Name = "CreateColorPicker", Params = "Name, Color, Presets, Callback, Flag", Returns = ":Set, :Get, :Reset", Description = "Live HSV picker and preset swatches." },
                        { Name = "CreateAccordion", Params = "Title, DefaultExpanded, Tooltip", Returns = "object", Description = "Collapsible content container." },
                        { Name = "CreateBindable", Params = "Name, Keybind, Enabled, Callback, Flag", Returns = ":SetEnabled, :SetKeybind", Description = "Enableable shortcut." },
                        { Name = "CreateNotice", Params = "Title, Content, Type, Height, Tooltip", Returns = ":Set, :SetType", Description = "Durable inline callout." },
                        { Name = "CreateProgress", Params = "Title, Value, Min, Max, Suffix, Callback, Flag", Returns = ":Set, :Get, :Reset", Description = "Live progress meter." },
                        { Name = "CreateSpinner", Params = "Title, Detail, Running, Tooltip, Flag", Returns = ":Start, :Stop, :Set, :Get", Description = "On-demand loading indicator." },
                        { Name = "CreateCarousel", Params = "Items, CurrentIndex, Callback, Tooltip, Flag", Returns = ":Next, :Previous, :SetItems, :Get", Description = "Compact rotating content." },
                        { Name = "CreateContextMenu", Params = "Name, ButtonText, Items, Tooltip, Flag", Returns = ":Open, :Close, :SetItems", Description = "On-demand action menu." },
                        { Name = "CreateStatus", Params = "Title, Text, State, Detail, Value, Flag", Returns = ":Set, :Get", Description = "Status indicator." },
                        { Name = "CreateGraph", Params = "Name, Max, Bars, Height, Suffix, Sample, RefreshRate, Tooltip, Flag", Returns = ":Push, :Reset, :SetMax, :Get", Description = "[v4.4] Live sparkline graph: push values (or auto-sample) and watch the trend scroll." },
                        { Name = "AddStatGrid", Params = "Columns, UpdateRate, ChipHeight, Flag, Tooltip", Returns = ":AddChip, :UpdateChip, :RemoveChip, :GetChipCount", Description = "[v5.2] Universal telemetry grid: auto-wrapping metric chips (Icon/Label/Value) with live UpdateChip calls or Sample auto-polling." },
                        { Name = "CreateCodeBlock", Params = "Title, Content, CopyCallback, Height", Returns = ":Set, :Get", Description = "Monospace copyable content." },
                        { Name = "CreateTable", Params = "Title, Columns, Rows, OnRowActivated, Height", Returns = ":SetRows, :GetRows", Description = "Compact data grid." },
                        { Name = "CreateTextArea", Params = "Title, Text, Placeholder, Callback, Flag", Returns = ":Set, :Get, :Reset", Description = "Multi-line input." },
                },
                Window = {
                        { Name = "CreateTab", Params = "name, optional icon (emoji text or asset id/URI)", Returns = "Tab (:SetTitle, :SetIcon)", Description = "Tab with a measured, horizontally scrolling rail; icons may be emoji text or image assets." },
                        { Name = "SaveConfiguration", Params = "", Returns = "table", Description = "With ConfigurationSaving enabled: write this window's flagged values to disk (JSON)." },
                        { Name = "LoadConfiguration", Params = "", Returns = "appliedCount", Description = "With ConfigurationSaving enabled: read and replay saved values onto elements." },
                        { Name = "SetBrandText", Params = "text (up to four UTF-8 characters)", Returns = "applied text", Description = "Sets the compact header badge; emoji and symbols are preserved." },
                        { Name = "GetBrandText", Params = "", Returns = "text", Description = "Gets the current compact header badge text." },
                        { Name = "SetRestoreText", Params = "text (up to four UTF-8 characters)", Returns = "applied text", Description = "Sets the floating restore button shown after Close." },
                        { Name = "GetRestoreText", Params = "", Returns = "text", Description = "Gets the current floating restore button text." },
                        { Name = "Notify", Params = "Title, Content, Duration, Type, Actions", Returns = "toast" },
                        { Name = "ShowModal", Params = "Title, Content, ConfirmText, CancelText, ConfirmCallback, CancelCallback", Returns = ":Confirm, :Cancel, :Close", Description = "Confirmation dialog." },
                        { Name = "ModifyTheme", Params = "name or palette", Returns = "palette" },
                        { Name = "CreateSettingsPanel", Params = "Name, Icon", Returns = "Tab" },
                        { Name = "SetToggleKeybind", Params = "Enum.KeyCode or key name", Returns = "Enum.KeyCode" },
                        { Name = "OpenCommandPalette", Params = "", Returns = "overlay" },
                },
                Library = {
                        { Name = "CreateWindow", Params = "Name/Title, Theme (incl. Lava/Cyberpunk/Obsidian/Emerald), CustomTheme, Size, Host, Parent, Accessibility, Icon, KeySystem, KeySettings, ConfigurationSaving, Sounds, BackdropBlur, Density, DisplayOrder, ShadowImage, Activity, QuickPause", Returns = "Window" },
                        { Name = "RegisterTheme", Params = "name, palette", Returns = "palette" },
                        { Name = "RegisterImage", Params = "key, imageId", Returns = "string" },
                        { Name = "SaveConfiguration", Params = "", Returns = "table" },
                        { Name = "LoadConfiguration", Params = "table", Returns = "nil" },
                        { Name = "GetDocs", Params = "", Returns = "table" },
                        { Name = "SetReducedMotion", Params = "boolean", Returns = "boolean" },
                },
                New = {
                        { Name = "Icon Support", Params = "Window Icon / tab icon / element Icon: number asset id, rbxassetid:// URI, or emoji text", Returns = "", Description = "Rayfield-style asset icons on the topbar badge, tabs, and every core element — with emoji fallback, no remote icon atlas required." },
                        { Name = "ConfigurationSaving", Params = "Enabled, FolderName, FileName, Autosave, SaveOnUnload, Notify", Returns = "", Description = "Auto-saves flagged elements to JSON on the executor filesystem. Signature-diffed writes (no rewrite storms), per-window isolation, load-replay on boot, flush on destroy." },
                        { Name = "KeySystem", Params = "KeySettings = Title, Subtitle, Note, FileName, SaveKey, GrabKeyFromSite, Key, MaxAttempts, OnExhausted", Returns = "", Description = "Styled key gate shown before the window. Exact-match validation, elastic shake on wrong keys, saved-key skip, optional HTTP key fetch, Lock/Kick/None on exhaustion." },
                        { Name = "Glass + Glow visuals", Params = "AnimatedAccents = true (opt-in ambient loops)", Returns = "", Description = "Layered depth shadows with a subtle accent rim, spring entrance, staggered tab-open settles, and drag-lift depth. Ambient pulse loops are opt-in." },
                },
        }
end

-- [v5.0.0] Test/inspection hook: live spring count (used by the headless
-- suite to verify the motion budget). Not part of the public API contract.
Library._springCount = function()
        return Spring.count
end

if type(_G) == "table" then
        _G.RezurXLib = Library
end

return Library
