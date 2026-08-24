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
        Color3.fromRGB(255, 69, 0), Color3.fromRGB(255, 170, 0), Color3.fromRGB(11, 13, 20),
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

local ThemeTokenSet = {}
for token in pairs(Themes.Quiet) do ThemeTokenSet[token] = true end
ThemeTokenSet.secondary = true -- [v5.2.0]

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

