-- ============================================================
-- RezurXLib v1.0 — Rayfield-shaped UI Library (RezurXlab skin)
--
-- A callable UI library with the same API surface as Rayfield
-- (CreateWindow -> Window:CreateTab -> Tab:CreateButton({...}),
-- Window/Library, Flags, themes, functional keybinds,
-- multi-select dropdowns) but wearing the RezurXlab Admin Panel
-- visual language: aurora header, sliding tab-pill indicator,
-- glow strip shimmer, chip tabs, status bar.
--
-- Intentionally NOT included (this is game-owner admin UI, not
-- exploit tooling): no key system, no config-file persistence
-- via writefile, no remote script loading, no obfuscation or
-- anti-detection of any kind. Every callback is yours to wire
-- into your own server-validated RemoteEvents.
--
-- USAGE (ModuleScript):
--   local Lib = require(path.to.RezurXLib)
--   local Window = Lib:CreateWindow({
--       Name            = "Admin Panel",
--       Subtitle        = "Management Console · RezurXlab",
--       LoadingTitle    = "RezurX lab",
--       LoadingEnabled  = true,
--       Theme           = "Ember",             -- "Ember" | "Ocean" | "Crimson" | "Slate"
--       ToggleUIKeybind = Enum.KeyCode.K,
--   })
--   local Tab = Window:CreateTab("Main", "📊")
--   Tab:CreateButton({ Name = "Refresh", Callback = function() end })
--   See ExampleUsage.client.lua for the full element catalogue.
-- ============================================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local Stats            = game:GetService("Stats")
local CoreGui          = game:GetService("CoreGui")
local TextService      = game:GetService("TextService")
local HttpService      = game:GetService("HttpService")

local player    = Players.LocalPlayer
local playerGui = player and player:WaitForChild("PlayerGui")

-- ============================================================
-- TWEEN PRESETS
-- Exponential easing for smooth Rayfield-style animations
-- ============================================================
local T10    = TweenInfo.new(0.10, Enum.EasingStyle.Quad,        Enum.EasingDirection.Out)
local T15    = TweenInfo.new(0.15, Enum.EasingStyle.Quad,        Enum.EasingDirection.Out)
local T20    = TweenInfo.new(0.20, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local T30    = TweenInfo.new(0.30, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local T40    = TweenInfo.new(0.40, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local T50    = TweenInfo.new(0.50, Enum.EasingStyle.Back,        Enum.EasingDirection.Out)
local T60    = TweenInfo.new(0.60, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local TMIN   = TweenInfo.new(0.32, Enum.EasingStyle.Quint,       Enum.EasingDirection.Out)
local TTAB   = TweenInfo.new(0.34, Enum.EasingStyle.Back,        Enum.EasingDirection.Out)
local TPRESS = TweenInfo.new(0.09, Enum.EasingStyle.Quad,        Enum.EasingDirection.Out)
local TPOP   = TweenInfo.new(0.24, Enum.EasingStyle.Back,        Enum.EasingDirection.Out)
local TTOGGLE = TweenInfo.new(0.45, Enum.EasingStyle.Quart,      Enum.EasingDirection.Out)
local TTOGGLEBG = TweenInfo.new(0.80, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

-- ============================================================
-- SHARED CORNER RADII
-- ============================================================
local R = { outer = 20, panel = 12, control = 10, small = 7, pill = 6, tab = 9 }

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

-- Active palette. Mutated in place by ApplyTheme so every
-- closure that captured `C` keeps reading fresh values.
local C = {}
for k, v in pairs(Themes.Ember) do C[k] = v end
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
local function Tween(inst, info, props)
        if not inst or not inst.Parent then return nil end
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
-- LIBRARY ROOT
-- ============================================================
-- ============================================================
-- TOOLTIP SYSTEM — hover-activated info labels
-- ============================================================
local tooltipFrame = nil
local tooltipText = nil
local tooltipStroke = nil

local function initTooltip()
        if tooltipFrame then return end
        tooltipFrame = Instance.new("Frame")
        tooltipFrame.Name = "Tooltip"
        tooltipFrame.Size = UDim2.new(0, 0, 0, 24)
        tooltipFrame.BackgroundColor3 = C.panelAlt
        tooltipFrame.BackgroundTransparency = 0.05
        tooltipFrame.BorderSizePixel = 0
        tooltipFrame.ZIndex = 200
        tooltipFrame.Visible = false
        pcall(function() tooltipFrame.Parent = CoreGui end)
        if not tooltipFrame.Parent then tooltipFrame.Parent = playerGui end
        corner(tooltipFrame, R.small)
        tooltipStroke = stroke(tooltipFrame, C.border, 1)
        tooltipText = Instance.new("TextLabel")
        tooltipText.Name = "Text"
        tooltipText.Size = UDim2.new(1, -12, 1, 0)
        tooltipText.Position = UDim2.new(0, 6, 0, 0)
        tooltipText.BackgroundTransparency = 1
        tooltipText.Font = Enum.Font.GothamMedium
        tooltipText.TextSize = 11
        tooltipText.TextColor3 = C.textDim
        tooltipText.ZIndex = 201
        tooltipText.Parent = tooltipFrame
end

local function showTooltip(text, anchorGui)
        if not text or text == "" then return end
        initTooltip()
        tooltipText.Text = text
        tooltipFrame.Visible = true
        tooltipFrame.BackgroundColor3 = C.panelAlt
        tooltipStroke.Color = C.border
        tooltipText.TextColor3 = C.textDim
        local txtSize = TextService:GetTextSize(text, 11, Enum.Font.GothamMedium, Vector2.new(400, 24))
        tooltipFrame.Size = UDim2.new(0, txtSize.X + 14, 0, 26)
        if anchorGui and anchorGui.AbsolutePosition then
                local pos = anchorGui.AbsolutePosition
                local size = anchorGui.AbsoluteSize
                tooltipFrame.Position = UDim2.new(0, pos.X, 0, pos.Y + size.Y + 4)
        end
end

local function hideTooltip()
        if tooltipFrame then tooltipFrame.Visible = false end
end

local Library = {}
Library.Flags = {}          -- flag -> element object (has CurrentValue / CurrentOption / etc.)
Library.Version = "1.0.0"
Library._windows = {}

-- ============================================================
-- CreateWindow
-- ============================================================
function Library:CreateWindow(cfg)
        cfg = cfg or {}
        local windowName   = cfg.Name or "RezurXlab Panel"
        local subtitle     = cfg.Subtitle or "Management Console · RezurXlab"
        local loadingTitle = cfg.LoadingTitle or windowName
        local loadingOn    = cfg.LoadingEnabled ~= false
        local toggleKey    = cfg.ToggleUIKeybind or Enum.KeyCode.K
        local WIN_W        = (cfg.Size and cfg.Size.X) or 460  -- bigger (was 420)
        local WIN_H        = (cfg.Size and cfg.Size.Y) or 500  -- bigger (was 480)
        local MIN_W, MIN_H = 300, 360  -- minimum resizable size
        local MAX_W, MAX_H = 900, 900  -- maximum resizable size

        -- ------------------------------------------------------------
        -- IDEMPOTENT GUARD — keyed to THIS window's name, so re-running
        -- a script that creates "Admin Panel" replaces the old "Admin
        -- Panel" instead of stacking a duplicate, without touching any
        -- other windows the library may be running.
        -- ------------------------------------------------------------
        local PANEL_NAME = "RezurX_" .. windowName:gsub("%W", "")
        for _, container in ipairs({ CoreGui, playerGui }) do
                local ok, existing = pcall(function() return container:FindFirstChild(PANEL_NAME) end)
                if ok and existing then existing:Destroy() end
        end

        -- Apply requested theme BEFORE building so everything is born
        -- with the right colors.
        if cfg.Theme and Themes[cfg.Theme] then
                for k, v in pairs(Themes[cfg.Theme]) do C[k] = v end
                C.borderAcc = C.accent
        end

        local Window = {}
        Window.Name = windowName
        local WindowJanitor = Janitor.new()

        -- Theme refreshers: each stateful element registers a closure
        -- that re-applies its colors from `C` for its current state.
        -- Gradients can't be tweened, so they're updated directly.
        local ThemeRefreshers = {}
        local function onTheme(fn)
                table.insert(ThemeRefreshers, fn)
                return fn
        end

        -- ------------------------------------------------------------
        -- SHARED DRAG ROUTER — one global InputChanged/InputEnded pair
        -- dispatching to whichever control is mid-drag.
        -- ------------------------------------------------------------
        local DragHandlers = {}
        local function registerDrag(key, moveFn, onEndFn)
                DragHandlers[key] = { move = moveFn, onEnd = onEndFn }
        end
        WindowJanitor:Add(UserInputService.InputChanged:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseMovement
                        or inp.UserInputType == Enum.UserInputType.Touch then
                        for _, h in pairs(DragHandlers) do
                                if h.move then h.move(inp.Position) end
                        end
                end
        end))
        WindowJanitor:Add(UserInputService.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                        or inp.UserInputType == Enum.UserInputType.Touch then
                        for _, h in pairs(DragHandlers) do
                                if h.onEnd then pcall(h.onEnd) end
                        end
                        table.clear(DragHandlers)
                end
        end))

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
                local target = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 1.6
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
        pcall(function() screenGui.Parent = CoreGui end)
        if not screenGui.Parent then screenGui.Parent = playerGui end
        WindowJanitor:Add(screenGui)

        -- ═══ AUTO SCALE (mobile friendly) ═══
        local function getViewport()
                local cam = workspace.CurrentCamera
                return cam and cam.ViewportSize or Vector2.new(1920, 1080)
        end
        -- [FIX] uiScale used to be created AFTER the first updateScale() call,
        -- but updateScale() only writes to it if it already exists
        -- (screenGui:FindFirstChild("UIScale")) — so that first call was a
        -- silent no-op, and the panel rendered at full (unscaled) size for up
        -- to 0.3s on every load before snapping down to the correct mobile
        -- scale. Creating it first means the very first call actually takes.
        local uiScale = Instance.new("UIScale")
        uiScale.Scale = 1
        uiScale.Parent = screenGui
        local function updateScale()
                local vp = getViewport()
                -- Mobile-friendly: leave room for top status bar + bottom controls
                local scaleX = (vp.X - 16) / WIN_W
                local scaleY = (vp.Y - 120) / WIN_H
                -- Allow shrinking down to 0.35 on small phones (was 0.5 — too big)
                local scale = math.clamp(math.min(scaleX, scaleY), 0.5, 1.0)  -- [FIX] floor 0.5 (was 0.4)
                uiScale.Scale = scale
        end
        updateScale()
        WindowJanitor:Add(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
        -- Defensive re-apply — camera viewport may not be fully settled yet on
        -- some clients even though the ordering fix above covers the common case.
        task.delay(0.3, updateScale)
        task.delay(1.0, updateScale)

        local HEADER_H, TABBAR_H, STATUSBAR_H = 54, 40, 24

        -- ------------------------------------------------------------
        -- SHADOW + OUTER WINDOW
        -- ------------------------------------------------------------
        local shadow = Instance.new("Frame")
        shadow.Name = "Shadow"
        shadow.Size = UDim2.new(0, WIN_W + 36, 0, WIN_H + 36)
        shadow.Position = UDim2.new(0.5, -(WIN_W + 36) / 2, 0.55, -(WIN_H + 36) / 2)
        shadow.BackgroundColor3 = Color3.new(0, 0, 0)
        shadow.BackgroundTransparency = 0.52
        shadow.BorderSizePixel = 0
        shadow.ZIndex = 1
        shadow.Parent = screenGui
        corner(shadow, R.outer + 8)

        -- Faint accent-tinted ambient glow, wider than the shadow and mostly
        -- transparent — gives the window a bit of branded "premium" presence
        -- instead of sitting on a purely neutral gray shadow.
        local ambientGlow = Instance.new("Frame")
        ambientGlow.Name = "AmbientGlow"
        ambientGlow.Size = UDim2.new(0, WIN_W + 70, 0, WIN_H + 70)
        ambientGlow.Position = UDim2.new(0.5, -(WIN_W + 70) / 2, 0.55, -(WIN_H + 70) / 2)
        ambientGlow.BackgroundColor3 = C.accent
        ambientGlow.BackgroundTransparency = 0.93
        ambientGlow.BorderSizePixel = 0
        ambientGlow.ZIndex = 1
        ambientGlow.Parent = screenGui
        corner(ambientGlow, R.outer + 16)
        onTheme(function()
                Tween(ambientGlow, T20, { BackgroundColor3 = C.accent })
        end)

        local frame = Instance.new("Frame")
        frame.Name = "Window"
        frame.Size = UDim2.new(0, WIN_W, 0, WIN_H)
        frame.Position = UDim2.new(0.5, -WIN_W / 2, 0.55, -WIN_H / 2)
        frame.BackgroundColor3 = C.bg
        frame.BorderSizePixel = 0
        frame.ClipsDescendants = true
        frame.ZIndex = 2
        frame.Parent = screenGui
        corner(frame, R.outer)
        local frameStroke = stroke(frame, C.borderAcc, 1.5)
        frameStroke.Transparency = 0.55
        onTheme(function()
                Tween(frame, T20, { BackgroundColor3 = C.bg })
                Tween(frameStroke, T20, { Color = C.borderAcc })
        end)

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
        local glowStrip = Instance.new("Frame")
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
        task.spawn(function()
                local shimmer = Instance.new("Frame")
                shimmer.Size = UDim2.new(0, 60, 1, 0)
                shimmer.BackgroundColor3 = C.white
                shimmer.BackgroundTransparency = 0.55
                shimmer.BorderSizePixel = 0
                shimmer.ZIndex = 3
                shimmer.Parent = glowStrip
                while glowStrip.Parent do
                        shimmer.Position = UDim2.new(-0.2, 0, 0, 0)
                        Tween(shimmer, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                                { Position = UDim2.new(1.2, 0, 0, 0) })
                        task.wait(3.8)
                end
        end)

        -- ------------------------------------------------------------
        -- HEADER
        -- ------------------------------------------------------------
        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, HEADER_H)
        header.BackgroundColor3 = C.headerA
        header.BorderSizePixel = 0
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
        hFix.BackgroundColor3 = C.headerB
        hFix.BorderSizePixel = 0
        hFix.Parent = header

        local accentLine = Instance.new("Frame")
        accentLine.Size = UDim2.new(1, 0, 0, 2)
        accentLine.Position = UDim2.new(0, 0, 1, -2)
        accentLine.BackgroundColor3 = C.accent
        accentLine.BorderSizePixel = 0
        accentLine.Parent = header

        local logoGlow = Instance.new("Frame")
        logoGlow.Size = UDim2.new(0, 70, 0, 70)
        logoGlow.AnchorPoint = Vector2.new(0.5, 0.5)
        logoGlow.Position = UDim2.new(0, 24, 0.5, 0)
        logoGlow.BackgroundColor3 = C.accent
        logoGlow.BackgroundTransparency = 0.9
        logoGlow.BorderSizePixel = 0
        logoGlow.ZIndex = 4
        logoGlow.Parent = header
        corner(logoGlow, UDim.new(1, 0))
        local logoGlowGrad = gradient(logoGlow, ColorSequence.new{
                ColorSequenceKeypoint.new(0.0, C.accent),
                ColorSequenceKeypoint.new(1.0, C.headerA),
        })
        onTheme(function()
                Tween(header, T20, { BackgroundColor3 = C.headerA })
                Tween(hFix, T20, { BackgroundColor3 = C.headerB })
                Tween(accentLine, T20, { BackgroundColor3 = C.accent })
                logoGlow.BackgroundColor3 = C.accent
                headerGrad.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0.0, C.headerA),
                        ColorSequenceKeypoint.new(1.0, C.headerB),
                }
                logoGlowGrad.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0.0, C.accent),
                        ColorSequenceKeypoint.new(1.0, C.headerA),
                }
        end)
        task.spawn(function()
                while header.Parent do
                        Tween(logoGlow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                                { BackgroundTransparency = 0.82 })
                        task.wait(1.6)
                        if not header.Parent then break end
                        Tween(logoGlow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                                { BackgroundTransparency = 0.94 })
                        task.wait(1.6)
                end
        end)

        local logo = Instance.new("TextLabel")
        logo.Text = windowName
        logo.Size = UDim2.new(0, 220, 0, 26)
        logo.Position = UDim2.new(0, 14, 0, 7)
        logo.BackgroundTransparency = 1
        logo.Font = Enum.Font.GothamBlack
        logo.TextSize = 22
        logo.TextColor3 = C.text
        logo.TextXAlignment = Enum.TextXAlignment.Left
        logo.TextTruncate = Enum.TextTruncate.AtEnd
        logo.ZIndex = 5
        logo.Parent = header

        local subLbl = Instance.new("TextLabel")
        subLbl.Text = subtitle
        subLbl.Size = UDim2.new(0, 240, 0, 13)
        subLbl.Position = UDim2.new(0, 15, 0, 37)
        subLbl.BackgroundTransparency = 1
        subLbl.Font = Enum.Font.GothamMedium
        subLbl.TextSize = 11
        subLbl.TextColor3 = C.muted
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
        subLbl.TextTruncate = Enum.TextTruncate.AtEnd
        subLbl.ZIndex = 5
        subLbl.Parent = header
        onTheme(function()
                Tween(logo, T20, { TextColor3 = C.text })
                Tween(subLbl, T20, { TextColor3 = C.muted })
        end)

        -- FPS / PING chip
        local statFrame = Instance.new("Frame")
        statFrame.Size = UDim2.new(0, 118, 0, 26)
        statFrame.Position = UDim2.new(1, -206, 0.5, -13)
        statFrame.BackgroundColor3 = C.panelAlt
        statFrame.BorderSizePixel = 0
        statFrame.ZIndex = 5
        statFrame.Parent = header
        corner(statFrame, R.small)
        local statStroke = stroke(statFrame, C.border, 1)

        local fpsLabel = Instance.new("TextLabel")
        fpsLabel.Size = UDim2.new(0.5, 0, 1, 0)
        fpsLabel.BackgroundTransparency = 1
        fpsLabel.Font = Enum.Font.Code
        fpsLabel.TextSize = 12
        fpsLabel.TextColor3 = C.green
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
        pingLabel.Size = UDim2.new(0.5, 0, 1, 0)
        pingLabel.Position = UDim2.new(0.5, 0, 0, 0)
        pingLabel.BackgroundTransparency = 1
        pingLabel.Font = Enum.Font.Code
        pingLabel.TextSize = 12
        pingLabel.TextColor3 = C.green
        pingLabel.Text = "— ms"
        pingLabel.ZIndex = 5
        pingLabel.Parent = statFrame
        onTheme(function()
                Tween(statFrame, T20, { BackgroundColor3 = C.panelAlt })
                Tween(statStroke, T20, { Color = C.border })
                Tween(statDivider, T20, { BackgroundColor3 = C.border })
        end)

        local fpsAvg = 60
        WindowJanitor:Add(RunService.Heartbeat:Connect(function(dt)
                fpsAvg = fpsAvg * 0.88 + (1 / math.max(dt, 0.001)) * 0.12
                local avg = math.floor(fpsAvg + 0.5)
                fpsLabel.Text = avg .. " FPS"
                fpsLabel.TextColor3 = avg >= 55 and C.green or avg >= 30 and C.yellow or C.red
        end))
        task.spawn(function()
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
        end)

        -- MINIMIZE + HIDE buttons
        local minBtn = Instance.new("TextButton")
        minBtn.Text = ""
        minBtn.Size = UDim2.new(0, 38, 0, 32)
        minBtn.Position = UDim2.new(1, -86, 0.5, -14)
        minBtn.BackgroundColor3 = C.panelAlt
        minBtn.BorderSizePixel = 0
        minBtn.AutoButtonColor = false
        minBtn.ZIndex = 5
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

        minBtn.MouseEnter:Connect(function()
                Tween(minBtn, T10, { BackgroundColor3 = C.panelHov })
                Tween(minGlyph, T10, { BackgroundColor3 = C.text })
        end)
        minBtn.MouseLeave:Connect(function()
                Tween(minBtn, T10, { BackgroundColor3 = C.panelAlt })
                Tween(minGlyph, T10, { BackgroundColor3 = C.muted })
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
        closeBtn.Position = UDim2.new(1, -44, 0.5, -14)
        closeBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
        closeBtn.BorderSizePixel = 0
        closeBtn.AutoButtonColor = false
        closeBtn.ZIndex = 5
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

        closeBtn.MouseEnter:Connect(function()
                Tween(closeBtn, T10, { BackgroundColor3 = Color3.fromRGB(210, 55, 55) })
                Tween(closeStroke, T10, { Color = Color3.fromRGB(255, 120, 120) })
                Tween(closeGlow, T15, { BackgroundTransparency = 0.75 })
        end)
        closeBtn.MouseLeave:Connect(function()
                Tween(closeBtn, T10, { BackgroundColor3 = Color3.fromRGB(120, 30, 30) })
                Tween(closeStroke, T10, { Color = Color3.fromRGB(160, 50, 50) })
                Tween(closeGlow, T15, { BackgroundTransparency = 1 })
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
        floatIcon.Position = UDim2.new(0, 10, 0, 10)
        floatIcon.BackgroundColor3 = C.accent
        floatIcon.Text = "👑"
        floatIcon.Font = Enum.Font.GothamBold
        floatIcon.TextSize = 20
        floatIcon.TextColor3 = C.white
        floatIcon.AutoButtonColor = false
        floatIcon.BorderSizePixel = 0
        floatIcon.ZIndex = 100
        floatIcon.Visible = false
        floatIcon.Parent = screenGui
        corner(floatIcon, UDim.new(1, 0))
        stroke(floatIcon, C.white, 2)
        -- [FIX] Track movement so tap (restore) vs drag (move) is distinguished
        local floatDragMoved = false
        floatIcon.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        local startDrag = inp.Position
                        local startAbs = floatIcon.AbsolutePosition  -- [FIX] screen pixels
                        floatDragMoved = false
                        local vp = getViewport()
                        registerDrag("floatIcon", function(pos)
                                local d = pos - startDrag
                                if d.Magnitude > 6 then floatDragMoved = true end  -- threshold
                                local nx = math.clamp(startAbs.X + d.X, 0, vp.X - 44)
                                local ny = math.clamp(startAbs.Y + d.Y, 0, vp.Y - 44)
                                floatIcon.Position = UDim2.new(0, nx, 0, ny)
                        end)
                end
        end)
        -- floatIcon.Activated is wired up later, after setHidden exists (see the
        -- consolidated HIDE / SHOW / MINIMIZE / TOGGLE KEYBIND section below) —
        -- a local declared later in this same function isn't visible to a
        -- closure written before it, so wiring it here would have called a
        -- nonexistent global and errored the first time someone tapped the icon.

        -- ------------------------------------------------------------
        -- WINDOW DRAG (via shared drag router)
        -- [FIX] Use dedicated dragBar instead of header.InputBegan
        -- to prevent drag from firing when clicking minBtn/closeBtn
        -- ------------------------------------------------------------
        local dragBar = Instance.new("TextButton")
        dragBar.Name = "DragBar"
        dragBar.Size = UDim2.new(1, -96, 1, 0)
        dragBar.Position = UDim2.new(0, 0, 0, 0)
        dragBar.BackgroundTransparency = 1
        dragBar.Text = ""
        dragBar.AutoButtonColor = false
        dragBar.BorderSizePixel = 0
        -- [FIX] ZIndex 6 = above logoGlow(4), statFrame(5), logo(5), subLbl(5)
        -- but dragBar ends 80px before right edge, so minBtn/closeBtn stay tappable
        dragBar.ZIndex = 6
        dragBar.Active = true
        dragBar.Selectable = false
        dragBar.Parent = header

        WindowJanitor:Add(dragBar.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                        or inp.UserInputType == Enum.UserInputType.Touch then
                        local dragStart = inp.Position
                        -- [FIX] Use AbsolutePosition (screen pixels) not Position.Offset
                        -- Position has scale 0.5/0.55, .Offset gives -WIN_W/2 → flinging
                        local startAbs = frame.AbsolutePosition
                        Tween(shadow, T15, { BackgroundTransparency = 0.65 })
                        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
                        registerDrag("window", function(pos)
                                local d = pos - dragStart
                                local nx = math.clamp(startAbs.X + d.X, -WIN_W + 100, vp.X - 100)
                                local ny = math.clamp(startAbs.Y + d.Y, 0, vp.Y - 30)
                                frame.Position = UDim2.new(0, nx, 0, ny)
                                shadow.Position = UDim2.new(0, nx - 18, 0, ny - 18)
                        end, function()
                                Tween(shadow, T15, { BackgroundTransparency = 0.52 })
                        end)
                end
        end))

        -- ------------------------------------------------------------
        -- TAB BAR + SLIDING INDICATOR
        -- ------------------------------------------------------------
        local tabBar = Instance.new("ScrollingFrame")
        tabBar.Size = UDim2.new(1, 0, 0, TABBAR_H)
        tabBar.BackgroundColor3 = C.tabBarBg
        tabBar.BorderSizePixel = 0
        tabBar.ZIndex = 3
        tabBar.ScrollingDirection = Enum.ScrollingDirection.X
        tabBar.CanvasSize = UDim2.new(0, 0, 1, 0)
        tabBar.ScrollBarThickness = 3
        tabBar.ScrollBarImageColor3 = C.accent
        tabBar.ScrollBarImageTransparency = 0.5
        tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
        tabBar.ElasticBehavior = Enum.ElasticBehavior.Never
        tabBar.Parent = body
        local tabBarStroke = stroke(tabBar, C.border, 1)

        local tabIndicator = Instance.new("Frame")
        tabIndicator.Name = "ActiveIndicator"
        tabIndicator.Size = UDim2.new(0, 70, 0, TABBAR_H - 10)
        tabIndicator.Position = UDim2.new(0, 4, 0, 5)
        tabIndicator.BackgroundColor3 = C.accentDark
        tabIndicator.BorderSizePixel = 0
        tabIndicator.ZIndex = 3
        tabIndicator.Parent = tabBar
        corner(tabIndicator, R.tab)
        local tabIndicatorStroke = stroke(tabIndicator, C.accentDim, 1.25)
        local tabIndGrad = gradient(tabIndicator, ColorSequence.new{
                ColorSequenceKeypoint.new(0.0, C.indGradA),
                ColorSequenceKeypoint.new(1.0, C.indGradB),
        }, 90)
        onTheme(function()
                Tween(tabBar, T20, { BackgroundColor3 = C.tabBarBg })
                tabBar.ScrollBarImageColor3 = C.accent
                Tween(tabBarStroke, T20, { Color = C.border })
                tabIndicator.BackgroundColor3 = C.accentDark
                Tween(tabIndicatorStroke, T20, { Color = C.accentDim })
                tabIndGrad.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0.0, C.indGradA),
                        ColorSequenceKeypoint.new(1.0, C.indGradB),
                }
        end)

        local tabShimmer = Instance.new("Frame")
        tabShimmer.Size = UDim2.new(0, 26, 1, 0)
        tabShimmer.BackgroundColor3 = C.white
        tabShimmer.BackgroundTransparency = 0.75
        tabShimmer.BorderSizePixel = 0
        tabShimmer.ZIndex = 3
        tabShimmer.Parent = tabIndicator
        corner(tabShimmer, R.tab)
        task.spawn(function()
                while tabIndicator.Parent do
                        local w = math.max(tabIndicator.AbsoluteSize.X, 40)
                        tabShimmer.Position = UDim2.new(0, -30, 0, 0)
                        Tween(tabShimmer, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                                { Position = UDim2.new(0, w + 10, 0, 0) })
                        task.wait(2.4)
                end
        end)

        local tabLayout = Instance.new("UIListLayout")
        tabLayout.FillDirection = Enum.FillDirection.Horizontal
        tabLayout.Padding = UDim.new(0, 4)
        tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tabLayout.Parent = tabBar
        pad(tabBar, 0, 0, 5, 5)

        -- ------------------------------------------------------------
        -- CONTENT + STATUS BAR
        -- ------------------------------------------------------------
        local content = Instance.new("Frame")
        content.Size = UDim2.new(1, 0, 1, -(TABBAR_H + STATUSBAR_H))
        content.Position = UDim2.new(0, 0, 0, TABBAR_H)
        content.BackgroundTransparency = 1
        content.Parent = body

        local statusBar = Instance.new("Frame")
        statusBar.Size = UDim2.new(1, 0, 0, STATUSBAR_H)
        statusBar.Position = UDim2.new(0, 0, 1, -STATUSBAR_H)
        statusBar.BackgroundColor3 = C.panel
        statusBar.BorderSizePixel = 0
        statusBar.ClipsDescendants = true
        statusBar.Parent = body
        corner(statusBar, R.outer)
        local sbFix = Instance.new("Frame")
        sbFix.Size = UDim2.new(1, 0, 0.5, 0)
        sbFix.BackgroundColor3 = C.panel
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
                Tween(statusBar, T20, { BackgroundColor3 = C.panel })
                Tween(sbFix, T20, { BackgroundColor3 = C.panel })
                Tween(sbTopLine, T20, { BackgroundColor3 = C.border })
        end)

        local sDot = Instance.new("Frame")
        sDot.Size = UDim2.new(0, 7, 0, 7)
        sDot.Position = UDim2.new(0, 12, 0.5, -3)
        sDot.BackgroundColor3 = C.green
        sDot.BorderSizePixel = 0
        sDot.ZIndex = 6
        sDot.Parent = statusBar
        corner(sDot, 4)
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

        local sTxt = Instance.new("TextLabel")
        sTxt.AutomaticSize = Enum.AutomaticSize.X
        sTxt.Size = UDim2.new(0, 0, 0, 14)
        sTxt.Position = UDim2.new(0, 26, 0.5, -7)
        sTxt.BackgroundTransparency = 1
        sTxt.Font = Enum.Font.Code
        sTxt.TextSize = 10
        sTxt.TextColor3 = C.muted
        sTxt.TextXAlignment = Enum.TextXAlignment.Left
        sTxt.ZIndex = 6
        sTxt.Text = "READY"
        sTxt.Parent = statusBar
        local sBootTime = os.clock()
        task.spawn(function()
                while sTxt.Parent do
                        local e = os.clock() - sBootTime
                        sTxt.Text = string.format("UP %02d:%02d", math.floor(e / 60), math.floor(e % 60))
                        task.wait(1)
                end
        end)

        local sVer = Instance.new("TextLabel")
        sVer.AutomaticSize = Enum.AutomaticSize.X
        sVer.Size = UDim2.new(0, 0, 0, 14)
        sVer.AnchorPoint = Vector2.new(1, 0.5)
        sVer.Position = UDim2.new(1, -18, 0.5, -7)
        sVer.BackgroundTransparency = 1
        sVer.Font = Enum.Font.Code
        sVer.TextSize = 10
        sVer.TextColor3 = C.muted
        sVer.TextXAlignment = Enum.TextXAlignment.Right
        sVer.TextTruncate = Enum.TextTruncate.AtEnd
        sVer.ZIndex = 6
        sVer.Text = windowName .. " · RezurXLib v" .. Library.Version
        sVer.Parent = statusBar
        onTheme(function()
                Tween(sTxt, T20, { TextColor3 = C.muted })
                Tween(sVer, T20, { TextColor3 = C.muted })
        end)

        -- [FIX] Make status bar draggable (move window from bottom too)
        WindowJanitor:Add(statusBar.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                        or inp.UserInputType == Enum.UserInputType.Touch then
                local dragStart = inp.Position
                local startAbs = frame.AbsolutePosition  -- [FIX] screen pixels
                Tween(shadow, T15, { BackgroundTransparency = 0.65 })
                local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
                registerDrag("statusbar", function(pos)
                        local d = pos - dragStart
                        local nx = math.clamp(startAbs.X + d.X, -WIN_W + 100, vp.X - 100)
                        local ny = math.clamp(startAbs.Y + d.Y, 0, vp.Y - 30)
                        frame.Position = UDim2.new(0, nx, 0, ny)
                        shadow.Position = UDim2.new(0, nx - 18, 0, ny - 18)
                end, function()
                        Tween(shadow, T15, { BackgroundTransparency = 0.52 })
                end)
                end
        end))

        -- [FIX] Resize handle (bottom-right corner) — drag to resize window
        local resizeHandle = Instance.new("TextButton")
        resizeHandle.Name = "ResizeHandle"
        resizeHandle.Size = UDim2.new(0, 22, 0, 22)
        resizeHandle.Position = UDim2.new(1, -22, 1, -22)
        resizeHandle.BackgroundColor3 = C.panelAlt
        resizeHandle.BackgroundTransparency = 0.3
        resizeHandle.Text = "⇲"
        resizeHandle.TextColor3 = C.muted
        resizeHandle.Font = Enum.Font.GothamBold
        resizeHandle.TextSize = 12
        resizeHandle.AutoButtonColor = false
        resizeHandle.BorderSizePixel = 0
        resizeHandle.ZIndex = 8
        resizeHandle.Parent = frame
        corner(resizeHandle, R.small)
        local resizeStroke = stroke(resizeHandle, C.border, 1)
        resizeHandle.MouseEnter:Connect(function()
                Tween(resizeHandle, T10, { BackgroundColor3 = C.panelHov, BackgroundTransparency = 0.1 })
                Tween(resizeHandle, T10, { TextColor3 = C.accent })
        end)
        resizeHandle.MouseLeave:Connect(function()
                Tween(resizeHandle, T10, { BackgroundColor3 = C.panelAlt, BackgroundTransparency = 0.3 })
                Tween(resizeHandle, T10, { TextColor3 = C.muted })
        end)
        WindowJanitor:Add(resizeHandle.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                        or inp.UserInputType == Enum.UserInputType.Touch then
                -- Lock top-left corner: record it in absolute pixels, resize from there
                local topLeft = frame.AbsolutePosition
                local dragStart = inp.Position
                local startW, startH = WIN_W, WIN_H
                Tween(shadow, T15, { BackgroundTransparency = 0.65 })
                registerDrag("resize", function(pos)
                        local d = pos - dragStart
                        local newW = math.clamp(startW + d.X, MIN_W, MAX_W)
                        local newH = math.clamp(startH + d.Y, MIN_H, MAX_H)
                        WIN_W = newW
                        WIN_H = newH
                        frame.Position = UDim2.new(0, topLeft.X, 0, topLeft.Y)
                        frame.Size = UDim2.new(0, newW, 0, newH)
                        shadow.Position = UDim2.new(0, topLeft.X - 18, 0, topLeft.Y - 18)
                        shadow.Size = UDim2.new(0, newW + 36, 0, newH + 36)
                        if not minimized then
                                body.Size = UDim2.new(1, 0, 0, newH - HEADER_H)
                        end
                        updateScale()
                end, function()
                        Tween(shadow, T15, { BackgroundTransparency = 0.52 })
                end)
                end
        end))
        onTheme(function()
                Tween(resizeHandle, T20, { BackgroundColor3 = C.panelAlt })
                Tween(resizeStroke, T20, { Color = C.border })
        end)

        -- ------------------------------------------------------------
        -- POPUP MANAGER
        -- ------------------------------------------------------------
        local currentPopupJanitor = nil
        local function closeCurrentPopup()
                if currentPopupJanitor then
                        currentPopupJanitor:Cleanup()
                        currentPopupJanitor = nil
                end
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
        notifContainer.Parent = screenGui
        local nLayout = Instance.new("UIListLayout")
        nLayout.Padding = UDim.new(0, 6)
        nLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        nLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        nLayout.Parent = notifContainer

        local function notify(title, body_, duration, ntype)
                local NTYPES = {
                        info    = { icon = "ℹ", color = C.accent },
                        success = { icon = "✓", color = C.green },
                        warning = { icon = "⚠", color = C.yellow },
                        error   = { icon = "✕", color = C.red },
                }
                ntype = ntype or "info"
                duration = duration or 5
                local ncfg = NTYPES[ntype] or NTYPES.info
                local col = ncfg.color

                local n = Instance.new("Frame")
                n.Size = UDim2.new(1, 30, 0, 0)
                n.Position = UDim2.new(0, 30, 0, 0)
                n.BackgroundColor3 = C.panel
                n.BackgroundTransparency = 1
                n.ClipsDescendants = true
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

                local prog = Instance.new("Frame")
                prog.Size = UDim2.new(1, 0, 0, 2)
                prog.Position = UDim2.new(0, 0, 1, -2)
                prog.BackgroundColor3 = col
                prog.BackgroundTransparency = 0.45
                prog.BorderSizePixel = 0
                prog.ZIndex = 6
                prog.Parent = n

                Tween(n, T20, { BackgroundTransparency = 0.05 })
                Tween(n, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, 0, 0, 68),
                        Position = UDim2.new(0, 0, 0, 0),
                })
                task.delay(0.25, function()
                        Tween(prog, TweenInfo.new(duration, Enum.EasingStyle.Linear),
                                { Size = UDim2.new(0, 0, 0, 2) })
                end)
                task.delay(duration, function()
                        local t = Tween(n, T20, { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 })
                        if t then t.Completed:Connect(function() n:Destroy() end) else n:Destroy() end
                end)
                return n
        end

        -- Rayfield-style: Window:Notify({Title, Content, Duration, Type})
        function Window:Notify(ncfg)
                ncfg = ncfg or {}
                return notify(ncfg.Title, ncfg.Content, ncfg.Duration, ncfg.Type)
        end

        -- ------------------------------------------------------------
        -- ------------------------------------------------------------
        -- MINIMIZE LOGIC (moved here from right after minBtn's creation —
        -- it needs tabBar/content/statusBar, which don't exist that early)
        -- ------------------------------------------------------------
        local minimized = false
        minBtn.Activated:Connect(function()
                minimized = not minimized
                if minimized then
                        tabBar.Visible = false
                        content.Visible = false
                        statusBar.Visible = false
                        Tween(frame, TMIN, { Size = UDim2.new(0, WIN_W, 0, HEADER_H) })
                        Tween(body, TMIN, { Size = UDim2.new(1, 0, 0, 0) })
                        Tween(shadow, TMIN, { Size = UDim2.new(0, WIN_W + 36, 0, HEADER_H + 36) })
                        Tween(minGlyph, T20, { Rotation = 180 })
                else
                        tabBar.Visible = true
                        content.Visible = true
                        statusBar.Visible = true
                        -- recompute body height from current WIN_H (supports resize)
                        Tween(frame, TMIN, { Size = UDim2.new(0, WIN_W, 0, WIN_H) })
                        Tween(body, TMIN, { Size = UDim2.new(1, 0, 0, WIN_H - HEADER_H) })
                        Tween(shadow, TMIN, { Size = UDim2.new(0, WIN_W + 36, 0, WIN_H + 36) })
                        Tween(minGlyph, T20, { Rotation = 0 })
                end
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
        local hidden = false
        local function setHidden(h)
                hidden = h
                if h then
                        closeCurrentPopup()
                        frame.Visible = false
                        shadow.Visible = false
                        floatIcon.Visible = true
                else
                        floatIcon.Visible = false
                        frame.Visible = true
                        shadow.Visible = true
                        if not minimized then
                                tabBar.Visible = true
                                content.Visible = true
                                statusBar.Visible = true
                        end
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
                                Tween(loadWordmark, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                                        { TextTransparency = 0 })
                                Tween(loadBarBg, T20, { BackgroundTransparency = 0 })
                                Tween(loadBarFill, T20, { BackgroundTransparency = 0 })
                                task.wait(0.12)
                                Tween(loadBarFill, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                        { Size = UDim2.new(1, 0, 1, 0) })
                                task.wait(0.5)
                                Tween(loadWordmark, T15, { TextTransparency = 1 })
                                Tween(loadBarBg, T15, { BackgroundTransparency = 1 })
                                Tween(loadBarFill, T15, { BackgroundTransparency = 1 })
                                task.wait(0.1)
                                Tween(loadingOverlay, T20, { BackgroundTransparency = 1 })
                                task.wait(0.2)
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
                local set = (type(theme) == "table") and theme or Themes[theme]
                if not set then
                        warn("[RezurXLib] Unknown theme: " .. tostring(theme))
                        return
                end
                for k, v in pairs(set) do C[k] = v end
                C.borderAcc = C.accent
                for _, fn in ipairs(ThemeRefreshers) do
                        pcall(fn)
                end
        end

        -- ============================================================
        -- CreateTab
        -- ============================================================
        local Tabs = {}
        local ActiveTab = nil

        local function moveIndicatorTo(btn, animated)
                local w = btn.AbsoluteSize.X
                -- [FIX] Use absolute position relative to tabBar
                local relX = btn.AbsolutePosition.X - tabBar.AbsolutePosition.X
                local goal = UDim2.new(0, relX, 0, tabIndicator.Position.Y.Offset)
                local goalSize = UDim2.new(0, w, 0, tabIndicator.Size.Y.Offset)
                if animated then
                        Tween(tabIndicator, TTAB, { Position = goal, Size = goalSize })
                else
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

                local btn = Instance.new("TextButton")
                btn.Name = "TabChip"
                -- [FIX] Use btn.Text directly for icon+text (Sirius/Rayfield style).
                -- Child labels had rendering issues on some devices → blank tabs.
                --
                -- [FIX] The comment here used to claim "btn uses AutomaticSize.X
                -- now" but that property was never actually set on the instance —
                -- Size was left hardcoded at UDim2.new(0, 90, 1, -10), so every
                -- tab chip was exactly 90px wide no matter what, and anything
                -- longer than a short one-word name overflowed the chip with no
                -- wrapping or truncation.
                --
                -- [FIX #2] AutomaticSize.X (the first fix) technically works, but
                -- it resolves through Roblox's layout engine asynchronously —
                -- there's a real gap between setting .Text and .AbsoluteSize
                -- actually reflecting it. moveIndicatorTo() reads AbsoluteSize /
                -- AbsolutePosition immediately when a tab activates. If that read
                -- happens before layout has settled (very plausible for the
                -- first tab, activated via task.defer right after creation), the
                -- sliding indicator snaps to the WRONG size/position, then jumps
                -- to the correct one a moment later once layout catches up —
                -- which reads exactly as "tabs weirdly move when clicked."
                -- TextService:GetTextSize computes the exact pixel width
                -- synchronously, before the button is even created, so there's
                -- no layout race to lose: Size is correct from frame one.
                local btnText = (icon or "") .. "  " .. name
                local CHIP_PAD = 14
                local textSize = TextService:GetTextSize(btnText, 12, Enum.Font.GothamBold, Vector2.new(1000, TABBAR_H))
                -- [FIX] Add 8px extra margin to prevent text clipping from UIPadding rounding
                local chipWidth = textSize.X + CHIP_PAD * 2 + 8
                btn.Size = UDim2.new(0, chipWidth, 1, -10)
                btn.Position = UDim2.new(0, 0, 0, 5)
                btn.BackgroundColor3 = C.tabChip
                btn.AutoButtonColor = false
                btn.BorderSizePixel = 0
                btn.Text = btnText
                btn.Font = Enum.Font.GothamBold
                btn.TextSize = 12
                -- [FIX] Use C.text (brighter) instead of C.textDim so text is visible
                btn.TextColor3 = C.text
                btn.TextXAlignment = Enum.TextXAlignment.Center
                btn.ZIndex = 4
                btn.Parent = tabBar
                -- [FIX] Removed pad() — UIPadding was clipping text. Extra width margin above handles spacing.
                corner(btn, R.tab)
                local chipStroke = stroke(btn, C.borderAcc, 1)
                -- Keep refs for setActive color tweens
                local iconLbl = btn  -- alias so setActive code works
                local textLbl = btn  -- alias so setActive code works

                local page = Instance.new("ScrollingFrame")
                page.Size = UDim2.new(1, 0, 1, 0)
                page.BackgroundTransparency = 1
                page.BorderSizePixel = 0
                page.ScrollBarThickness = 3
                page.ScrollBarImageColor3 = C.accent
                page.ScrollBarImageTransparency = 0.40
                page.CanvasSize = UDim2.new(0, 0, 0, 0)
                page.Visible = false
                page.Parent = content

                local pLayout = Instance.new("UIListLayout")
                pLayout.Padding = UDim.new(0, 8)  -- [FIX] 8px between items (was 6, cramped)
                pLayout.SortOrder = Enum.SortOrder.LayoutOrder
                pLayout.Parent = page
                pad(page, 12, 12, 11, 12)  -- [FIX] 12px page padding (was 10)
                pLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                        page.CanvasSize = UDim2.new(0, 0, 0, pLayout.AbsoluteContentSize.Y + 20)
                end)

                tab.Page = page
                tab.Btn = btn
                tab.Name = name

                        -- [FIX] updateBtnSize removed — btn uses AutomaticSize.X now
                        -- Just move the indicator to the btn's current position on load
                        task.defer(function()
                                if ActiveTab == tab then
                                        moveIndicatorTo(btn, false)
                                end
                end)

                local function setActive(skipAnim)
                        closeCurrentPopup()
                        if ActiveTab and ActiveTab ~= tab then
                                local prev = ActiveTab
                                prev.Page.Visible = false
                                prev.Btn.BackgroundTransparency = 0
                                Tween(prev.Btn, T20, { BackgroundColor3 = C.tabChip })
                                Tween(prev._chipStroke, T20, { Color = C.borderAcc, Transparency = 0 })
                                Tween(prev._iconLbl, T20, { TextColor3 = C.text })
                        end
                        ActiveTab = tab
                        tab.Page.Visible = true
                        Tween(btn, T20, { BackgroundTransparency = 1 })
                        Tween(chipStroke, T20, { Transparency = 1 })
                        Tween(iconLbl, T20, { TextColor3 = C.accentHi })
                        moveIndicatorTo(btn, not skipAnim)
                        -- [FIX] Removed rotation/pop animation (was for separate icon label,
                        -- now iconLbl=btn so rotating would rotate the whole button)
                end
                tab._chipStroke = chipStroke
                tab._iconLbl = iconLbl
                tab._textLbl = textLbl
                tab._setActive = setActive

                onTheme(function()
                        page.ScrollBarImageColor3 = C.accent
                        if ActiveTab == tab then
                                Tween(btn, T20, { TextColor3 = C.accentHi })
                        else
                                Tween(btn, T20, { BackgroundColor3 = C.tabChip })
                                Tween(chipStroke, T20, { Color = C.borderAcc })
                                Tween(btn, T20, { TextColor3 = C.text })
                        end
                end)

                btn.MouseEnter:Connect(function()
                        if ActiveTab ~= tab then
                                Tween(btn, T10, { BackgroundColor3 = C.tabChipHov })
                                Tween(chipStroke, T10, { Color = C.accentDim })
                                Tween(btn, T10, { TextColor3 = C.text })
                        end
                end)
                btn.MouseLeave:Connect(function()
                        if ActiveTab ~= tab then
                                Tween(btn, T10, { BackgroundColor3 = C.tabChip })
                                Tween(chipStroke, T10, { Color = C.borderAcc })
                                Tween(btn, T10, { TextColor3 = C.text })
                        end
                end)
                btn.MouseButton1Click:Connect(function()
                        ripple(btn, btn.AbsoluteSize.X / 2, btn.AbsoluteSize.Y / 2, C.accent)
                        setActive(false)
                end)

                table.insert(Tabs, tab)
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
                        return holder, strk
                end

                local function registerFlag(flag, obj)
                        if flag then Library.Flags[flag] = obj end
                end

                local function applyTooltip(instance, text)
                        if not text or text == "" then return end
                        instance.MouseEnter:Connect(function()
                                showTooltip(text, instance)
                        end)
                        instance.MouseLeave:Connect(function()
                                hideTooltip()
                        end)
                end

                -- ========================================================
                -- CreateSection / CreateDivider / CreateLabel / CreateParagraph
                -- ========================================================
                function tab:CreateSection(text)
                        local l = Instance.new("TextLabel")
                        l.Size = UDim2.new(1, 0, 0, 18)
                        l.BackgroundTransparency = 1
                        l.Font = Enum.Font.GothamBold
                        l.TextSize = 10
                        l.TextColor3 = C.accent
                        l.TextXAlignment = Enum.TextXAlignment.Left
                        l.Text = string.upper(text)
                        l.Parent = page
                        onTheme(function() Tween(l, T20, { TextColor3 = C.accent }) end)
                        local obj = {}
                        function obj:Set(newText) l.Text = string.upper(newText) end
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
                                lbl.Text = "── " .. string.upper(text)
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

                function tab:CreateLabel(text)
                        local holder, strk = makeHolder(34)
                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, -28, 1, 0)
                        lbl.Position = UDim2.new(0, 14, 0, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamMedium
                        lbl.TextSize = 13
                        lbl.TextColor3 = C.textDim
                        lbl.TextXAlignment = Enum.TextXAlignment.Left
                        lbl.Text = text or ""
                        lbl.Parent = holder
                        onTheme(function()
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(strk, T20, { Color = C.border })
                                Tween(lbl, T20, { TextColor3 = C.textDim })
                        end)
                        local obj = {}
                        function obj:Set(newText) lbl.Text = newText end
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
                -- CreateButton({ Name, Callback })
                -- ========================================================
                function tab:CreateImage(icfg)
                        icfg = icfg or {}
                        local holder, strk = makeHolder(icfg.Height or 120)
                        local img = Instance.new("ImageLabel")
                        img.Name = "Image"
                        img.Size = UDim2.new(1, 0, 1, 0)
                        img.BackgroundTransparency = 1
                        img.Image = icfg.Image or ""
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
                        function obj:Set(imageId) img.Image = imageId end
                        return obj
                end

                function tab:CreateButton(bcfg)
                        bcfg = bcfg or {}
                        local nameText = bcfg.Name or "Button"
                        local callback = bcfg.Callback

                        local b = Instance.new("TextButton")
                        b.Size = UDim2.new(1, 0, 0, 42)
                        b.BackgroundColor3 = C.panel
                        b.Text = ""
                        b.AutoButtonColor = false
                        b.BorderSizePixel = 0
                        b.ClipsDescendants = true
                        b.Parent = page
                        corner(b, R.panel)
                        local strk = stroke(b, C.border, 1)

                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, -32, 1, 0)
                        lbl.Position = UDim2.new(0, 14, 0, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamMedium
                        lbl.TextSize = 13
                        lbl.TextColor3 = C.text
                        lbl.TextXAlignment = Enum.TextXAlignment.Left
                        lbl.Text = nameText
                        lbl.Parent = b

                        local arr = Instance.new("TextLabel")
                        arr.Size = UDim2.new(0, 18, 1, 0)
                        arr.Position = UDim2.new(1, -22, 0, 0)
                        arr.BackgroundTransparency = 1
                        arr.Font = Enum.Font.GothamBold
                        arr.TextSize = 14
                        arr.TextColor3 = C.muted
                        arr.Text = "›"
                        arr.Parent = b

                        b.MouseEnter:Connect(function()
                                Tween(b, T20, { BackgroundColor3 = C.panelHov })
                                Tween(arr, T20, { TextColor3 = C.accent, Position = UDim2.new(1, -18, 0, 0) })
                        end)
                        b.MouseLeave:Connect(function()
                                Tween(b, T20, { BackgroundColor3 = C.panel })
                                Tween(arr, T20, { TextColor3 = C.muted, Position = UDim2.new(1, -22, 0, 0) })
                        end)
                        b.MouseButton1Click:Connect(function()
                                ripple(b, b.AbsoluteSize.X - 30, b.AbsoluteSize.Y / 2, C.accent)
                                Tween(b, T20, { BackgroundColor3 = C.accentDim })
                                Tween(lbl, T20, { TextColor3 = C.white })
                                task.delay(0.15, function()
                                        Tween(b, T20, { BackgroundColor3 = C.panelHov })
                                        Tween(lbl, T20, { TextColor3 = C.text })
                                end)
                                if callback then
                                    task.spawn(function()
                                        local ok, err = pcall(callback)
                                        if not ok then
                                                -- Rayfield-style: red flash on callback error
                                                Tween(b, T20, { BackgroundColor3 = Color3.fromRGB(85, 0, 0) })
                                                local origText = lbl.Text
                                                lbl.Text = "Callback Error"
                                                warn("[RezurXLib] Button '"..nameText.."' callback error: "..tostring(err))
                                                task.delay(0.5, function()
                                                        lbl.Text = origText
                                                        Tween(b, T20, { BackgroundColor3 = C.panel })
                                                end)
                                        end
                                    end)
                                end
                        end)
                        onTheme(function()
                                Tween(b, T20, { BackgroundColor3 = C.panel })
                                Tween(strk, T20, { Color = C.border })
                                Tween(lbl, T20, { TextColor3 = C.text })
                                Tween(arr, T20, { TextColor3 = C.muted })
                        end)

                        local obj = {}
                        function obj:Set(newName) lbl.Text = newName end
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
                                b.MouseButton1Click:Connect(function()
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

                        local holder, hStroke = makeHolder(42)
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

                        local obj = { CurrentValue = state }
                        local function apply(v, silent)
                                state = v
                                obj.CurrentValue = v
                                -- Rayfield-style: knob shrinks briefly then grows back (pop effect)
                                Tween(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                                        { Size = UDim2.new(0, 14, 0, 14) })
                                task.delay(0.15, function()
                                        Tween(knob, TTOGGLE, { Size = UDim2.new(0, 18, 0, 18) })
                                end)
                                -- Switch background fades smoothly
                                Tween(sw, TTOGGLEBG, { BackgroundColor3 = state and C.accent or C.track })
                                Tween(hStroke, T20, { Color = state and C.accentDim or C.border })
                                -- Knob slides with smooth easing
                                Tween(knob, TTOGGLE, {
                                        Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
                                })
                                if callback and not silent then
                                        local ok, err = pcall(callback, state)
                                        if not ok then
                                                -- Rayfield-style: red flash on callback error
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
                        function obj:Set(v) apply(v) end
                        function obj:SetLabel(newText) lbl.Text = newText end
                        function obj:Get() return state end

                        hit.Activated:Connect(function()
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
                        local minVal    = range[1]
                        local maxVal    = range[2]
                        local increment = scfg.Increment or 1
                        local suffix    = scfg.Suffix or ""
                        local callback  = scfg.Callback
                        local value     = math.clamp(scfg.CurrentValue or minVal, minVal, maxVal)

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

                        local valLbl = Instance.new("TextLabel")
                        valLbl.Size = UDim2.new(0, 64, 0, 18)
                        valLbl.Position = UDim2.new(1, -72, 0, 6)
                        valLbl.BackgroundTransparency = 1
                        valLbl.Font = Enum.Font.GothamBold
                        valLbl.TextSize = 13
                        valLbl.TextColor3 = C.accent
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
                        knob.Position = UDim2.new(0, -9, 0.5, -9)
                        knob.BackgroundColor3 = C.white
                        knob.BorderSizePixel = 0
                        knob.Parent = track
                        corner(knob, UDim.new(1, 0))
                        local knobStroke = stroke(knob, C.accent, 2)
                        -- Shadow under knob for depth (Rayfield-style)
                        local knobShadow = Instance.new("ImageLabel")
                        knobShadow.Size = UDim2.new(1, 8, 1, 8)
                        knobShadow.Position = UDim2.new(0, -4, 0, -4)
                        knobShadow.BackgroundTransparency = 1
                        knobShadow.Image = "rbxassetid://1316045217"
                        knobShadow.ImageColor3 = Color3.new(0, 0, 0)
                        knobShadow.ImageTransparency = 0.7
                        knobShadow.ZIndex = knob.ZIndex - 1
                        knobShadow.Parent = knob

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
                        local function update(animated)
                                local pct = math.clamp((value - minVal) / (maxVal - minVal), 0, 1)
                                if animated then
                                        Tween(fill, T10, { Size = UDim2.new(pct, 0, 1, 0) })
                                        Tween(knob, T10, { Position = UDim2.new(pct, -9, 0.5, -9) })
                                else
                                        fill.Size = UDim2.new(pct, 0, 1, 0)
                                        knob.Position = UDim2.new(pct, -9, 0.5, -9)
                                end
                                valLbl.Text = tostring(value) .. suffix
                        end
                        update(false)

                        local obj = { CurrentValue = value }
                        local lastFired = value
                        function obj:Set(v)
                                value = snap(v)
                                obj.CurrentValue = value
                                update(true)
                                lastFired = value
                                if callback then pcall(callback, value) end
                        end
                        function obj:Get() return value end

                                local function setFromX(x)
                                        local pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
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
                                                local ok, err = pcall(callback, value)
                                                if not ok then
                                                        warn("[RezurXLib] Slider '"..nameText.."' callback error: "..tostring(err))
                                                end
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
                                hit.InputBegan:Connect(function(inp)
                                        if inp.UserInputType == Enum.UserInputType.MouseButton1
                                                or inp.UserInputType == Enum.UserInputType.Touch then
                                                -- Knob grows on grab (Rayfield-style)
                                                Tween(knob, T20, { Size = UDim2.new(0, 22, 0, 22) })
                                                setFromX(inp.Position.X)
                                                fireCallback()
                                                registerDrag(hit, function(pos)
                                                        setFromX(pos.X)
                                                        fireCallback()
                                                end, function()
                                                        -- Knob shrinks back on release
                                                        Tween(knob, T20, { Size = UDim2.new(0, 18, 0, 18) })
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

                        local box = Instance.new("TextBox")
                        box.Size = UDim2.new(1, -28, 0, 20)
                        box.Position = UDim2.new(0, 14, 0, 24)
                        box.BackgroundTransparency = 1
                        box.Font = Enum.Font.Gotham
                        box.TextSize = 13
                        box.TextColor3 = C.text
                        box.PlaceholderColor3 = C.muted
                        box.PlaceholderText = icfg.PlaceholderText or ""
                        box.Text = icfg.CurrentValue or ""
                        box.TextXAlignment = Enum.TextXAlignment.Left
                        box.ClearTextOnFocus = false
                        box.Parent = holder

                        local obj = { CurrentValue = box.Text }
                        box.Focused:Connect(function()
                                Tween(strk, T10, { Color = C.accent, Thickness = 1.5 })
                                Tween(lbl, T10, { TextColor3 = C.accent })
                        end)
                        box.FocusLost:Connect(function()
                                Tween(strk, T10, { Color = C.border, Thickness = 1 })
                                Tween(lbl, T10, { TextColor3 = C.muted })
                                obj.CurrentValue = box.Text
                                if callback then pcall(callback, box.Text) end
                                if icfg.RemoveTextAfterFocusLost then
                                        box.Text = ""
                                end
                        end)
                        function obj:Set(text)
                                box.Text = text
                                obj.CurrentValue = text
                        end
                        function obj:Get() return box.Text end
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
                --                  MultipleOptions, Flag, Callback })
                -- Multi-select: CurrentOption is a table; list stays open
                -- while toggling; checkmarks flip in place.
                -- ========================================================
                function tab:CreateDropdown(dcfg)
                        dcfg = dcfg or {}
                        local nameText = dcfg.Name or "Dropdown"
                        local options  = dcfg.Options or {}
                        local multi    = dcfg.MultipleOptions == true
                        local callback = dcfg.Callback
                        local searchable = dcfg.Searchable == true

                        local selected = {} -- set: option -> true
                        do
                                local cur = dcfg.CurrentOption
                                if type(cur) == "table" then
                                        for _, o in ipairs(cur) do selected[o] = true end
                                elseif cur ~= nil then
                                        selected[cur] = true
                                elseif not multi and options[1] then
                                        selected[options[1]] = true
                                end
                        end

                        local holder, hStroke = makeHolder(42)
                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, -38, 1, 0)
                        lbl.Position = UDim2.new(0, 14, 0, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamMedium
                        lbl.TextSize = 13
                        lbl.TextColor3 = C.text
                        lbl.TextXAlignment = Enum.TextXAlignment.Left
                        lbl.TextTruncate = Enum.TextTruncate.AtEnd
                        lbl.Parent = holder

                        local arrow = Instance.new("TextLabel")
                        arrow.Size = UDim2.new(0, 22, 1, 0)
                        arrow.Position = UDim2.new(1, -26, 0, 0)
                        arrow.BackgroundTransparency = 1
                        arrow.Font = Enum.Font.GothamBold
                        arrow.TextSize = 12
                        arrow.TextColor3 = C.muted
                        arrow.Text = "▾"
                        arrow.Parent = holder

                        local obj = {}
                        local function selectionList()
                                local out = {}
                                for _, o in ipairs(options) do
                                        if selected[o] then table.insert(out, o) end
                                end
                                return out
                        end
                        local function displayText()
                                local sel = selectionList()
                                if #sel == 0 then return nameText .. " · —" end
                                if multi then
                                        if #sel <= 2 then
                                                return nameText .. " · " .. table.concat(sel, ", ")
                                        end
                                        return nameText .. " · " .. #sel .. " selected"
                                end
                                return nameText .. " · " .. sel[1]
                        end
                        local function refreshLabel()
                                lbl.Text = displayText()
                        end
                        refreshLabel()

                        local function fire()
                                obj.CurrentOption = multi and selectionList() or selectionList()[1]
                                if callback then pcall(callback, obj.CurrentOption) end
                        end
                        obj.CurrentOption = multi and selectionList() or selectionList()[1]

                                local function openList()
                                        closeCurrentPopup()
                                        arrow.Text = "▴"

                                        local hPos, hSize = holder.AbsolutePosition, holder.AbsoluteSize
                                        -- [FIX] Account for UIScale — AbsolutePosition is already scaled,
                                        -- but popup is in screenGui which scales AGAIN. Divide by scale.
                                        local _uiScale = screenGui:FindFirstChild("UIScale")
                                        local _s = _uiScale and _uiScale.Scale or 1
                                        if _s > 0 then hPos = Vector2.new(hPos.X / _s, hPos.Y / _s) hSize = Vector2.new(hSize.X / _s, hSize.Y / _s) end
                                        local ITEM_H = 30
                                        local LIST_H = math.min(#options, 7) * (ITEM_H + 2) + 10
                                        local cam = workspace.CurrentCamera
                                        local vpH = cam and cam.ViewportSize.Y or 800
                                        local dropDown = (hPos.Y + hSize.Y + LIST_H + 6 <= vpH)
                                        local listY = dropDown and (hPos.Y + hSize.Y + 4) or (hPos.Y - LIST_H - 4)

                                        local list = Instance.new("ScrollingFrame")
                                        list.Size = UDim2.new(0, hSize.X, 0, 0)
                                        list.Position = UDim2.new(0, hPos.X, 0, dropDown and (hPos.Y + hSize.Y + 4) or hPos.Y)
                                        list.BackgroundColor3 = C.panel
                                        list.BackgroundTransparency = 0.15
                                        list.BorderSizePixel = 0
                                        list.ClipsDescendants = true
                                        list.ScrollBarThickness = 3
                                        list.ScrollBarImageColor3 = C.accent
                                        list.CanvasSize = UDim2.new(0, 0, 0, #options * (ITEM_H + 2) + 10)
                                        list.ZIndex = 9
                                        list.Parent = screenGui
                                        corner(list, R.panel)
                                        stroke(list, C.accent, 1)

                                        Tween(list, T15, {
                                                Size = UDim2.new(0, hSize.X, 0, LIST_H),
                                                Position = UDim2.new(0, hPos.X, 0, listY),
                                                BackgroundTransparency = 0,
                                        })

                                        local lL = Instance.new("UIListLayout")
                                        lL.Padding = UDim.new(0, 2)
                                        lL.Parent = list
                                        pad(list, 4, 4, 4, 4)

                                        -- Searchable dropdown: add search box if enabled
                                        local searchBox = nil
                                        local itemFrames = {}
                                        if searchable then
                                                local searchHolder = Instance.new("Frame")
                                                searchHolder.Name = "Search"
                                                searchHolder.Size = UDim2.new(1, -4, 0, 28)
                                                searchHolder.BackgroundColor3 = C.panelAlt
                                                searchHolder.BorderSizePixel = 0
                                                searchHolder.ZIndex = 10
                                                searchHolder.Parent = list
                                                corner(searchHolder, R.small)
                                                stroke(searchHolder, C.border, 1)
                                                searchBox = Instance.new("TextBox")
                                                searchBox.Name = "SearchBox"
                                                searchBox.Size = UDim2.new(1, -8, 1, 0)
                                                searchBox.Position = UDim2.new(0, 4, 0, 0)
                                                searchBox.BackgroundTransparency = 1
                                                searchBox.Font = Enum.Font.Gotham
                                                searchBox.TextSize = 12
                                                searchBox.TextColor3 = C.text
                                                searchBox.PlaceholderColor3 = C.muted
                                                searchBox.PlaceholderText = "Search..."
                                                searchBox.Text = ""
                                                searchBox.ZIndex = 10
                                                searchBox.Parent = searchHolder
                                        end

                                        -- [FIX] Was: bespoke closePopup() + currentPopupJanitor set to
                                        -- nil directly ("no Janitor, direct cleanup"). That meant this
                                        -- popup was never actually tracked by the shared mechanism, so
                                        -- opening any OTHER popup (a different dropdown, the color
                                        -- picker, etc.) while this list was open left the catcher +
                                        -- list stuck on screen forever — nothing knew to clean them up.
                                        -- Registering both with a Janitor and handing it to
                                        -- currentPopupJanitor fixes it: whichever popup opens next
                                        -- correctly tears this one down first.
                                        for _, opt in ipairs(options) do
                                                local item = Instance.new("TextButton")
                                                item.Size = UDim2.new(1, -4, 0, ITEM_H)
                                                item.BackgroundColor3 = C.panelAlt
                                                item.Text = ""
                                                item.AutoButtonColor = false
                                                item.ZIndex = 10
                                                item.Parent = list
                                                corner(item, R.small)
                                                table.insert(itemFrames, { frame = item, text = opt:lower() })

                                                local iLbl = Instance.new("TextLabel")
                                                iLbl.Size = UDim2.new(1, -30, 1, 0)
                                                iLbl.Position = UDim2.new(0, 10, 0, 0)
                                                iLbl.BackgroundTransparency = 1
                                                iLbl.Font = Enum.Font.Gotham
                                                iLbl.TextSize = 13
                                                iLbl.TextColor3 = selected[opt] and C.accent or C.text
                                                iLbl.TextXAlignment = Enum.TextXAlignment.Left
                                                iLbl.Text = opt
                                                iLbl.ZIndex = 10
                                                iLbl.Parent = item

                                                local check = Instance.new("TextLabel")
                                                check.Size = UDim2.new(0, 18, 1, 0)
                                                check.Position = UDim2.new(1, -22, 0, 0)
                                                check.BackgroundTransparency = 1
                                                check.Font = Enum.Font.GothamBold
                                                check.TextSize = 13
                                                check.TextColor3 = C.accent
                                                check.Text = selected[opt] and "✓" or ""
                                                check.ZIndex = 10
                                                check.Parent = item

                                                item.MouseEnter:Connect(function()
                                                        Tween(item, T10, { BackgroundColor3 = C.panelHov })
                                                end)
                                                item.MouseLeave:Connect(function()
                                                        Tween(item, T10, { BackgroundColor3 = C.panelAlt })
                                                end)
                                                item.MouseButton1Click:Connect(function()
                                                        if multi then
                                                                selected[opt] = not selected[opt] or nil
                                                                check.Text = selected[opt] and "✓" or ""
                                                                iLbl.TextColor3 = selected[opt] and C.accent or C.text
                                                                refreshLabel()
                                                                fire()
                                                                else
                                                                table.clear(selected)
                                                                selected[opt] = true
                                                                refreshLabel()
                                                                closeCurrentPopup()
                                                                fire()
                                                        end
                                                end)
                                        end

                                        -- Search filtering: hide items that don't match query
                                        if searchBox then
                                                searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                                                        local query = searchBox.Text:lower()
                                                        for _, entry in ipairs(itemFrames) do
                                                                local match = query == "" or entry.text:find(query, 1, true)
                                                                entry.frame.Visible = match
                                                        end
                                                end)
                                        end

                                        -- [FIX] Create catcher DEFERRED so the opening tap doesn't
                                        -- immediately trigger closeCurrentPopup. On mobile, the same
                                        -- touch that opened the list would fire catcher.MouseButton1Click
                                        -- on release, closing it instantly — looked like "nothing happens."
                                        local catcher = Instance.new("TextButton")
                                        catcher.Size = UDim2.new(1, 0, 1, 0)
                                        catcher.BackgroundTransparency = 1
                                        catcher.Text = ""
                                        catcher.AutoButtonColor = false
                                        catcher.Active = true
                                        catcher.ZIndex = 8
                                        catcher.Visible = false  -- hidden until deferred
                                        catcher.Parent = screenGui

                                        catcher.MouseButton1Click:Connect(closeCurrentPopup)

                                        local pj = Janitor.new()
                                        pj:Add(catcher)
                                        pj:Add(list)
                                        pj:Add(function() arrow.Text = "▾" end)
                                        currentPopupJanitor = pj

                                        -- Show catcher next frame so the opening tap doesn't close it
                                        task.defer(function()
                                                catcher.Visible = true
                                        end)
                                end

                        holder.InputBegan:Connect(function(inp)
                                if inp.UserInputType == Enum.UserInputType.MouseButton1
                                        or inp.UserInputType == Enum.UserInputType.Touch then
                                        openList()
                                end
                        end)

                        function obj:Set(optionOrList, silent)
                                table.clear(selected)
                                if type(optionOrList) == "table" then
                                        for _, o in ipairs(optionOrList) do selected[o] = true end
                                elseif optionOrList ~= nil then
                                        selected[optionOrList] = true
                                end
                                refreshLabel()
                                if silent then
                                        obj.CurrentOption = multi and selectionList() or selectionList()[1]
                                else
                                        fire()
                                end
                        end
                        function obj:Refresh(newOptions, keepSelection)
                                options = newOptions or {}
                                if not keepSelection then
                                        table.clear(selected)
                                        if not multi and options[1] then selected[options[1]] = true end
                                else
                                        for o in pairs(selected) do
                                                if not table.find(options, o) then selected[o] = nil end
                                        end
                                end
                                refreshLabel()
                                obj.CurrentOption = multi and selectionList() or selectionList()[1]
                        end
                        function obj:Get() return obj.CurrentOption end

                        onTheme(function()
                                Tween(holder, T20, { BackgroundColor3 = C.panel })
                                Tween(hStroke, T20, { Color = C.border })
                                Tween(lbl, T20, { TextColor3 = C.text })
                                Tween(arrow, T20, { TextColor3 = C.muted })
                        end)
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
                        local hold     = kcfg.HoldToInteract == true
                        local bound    = kcfg.CurrentKeybind -- Enum.KeyCode or string
                        if type(bound) == "string" then
                                local ok, kc = pcall(function() return Enum.KeyCode[bound] end)
                                bound = ok and kc or nil
                        end
                        local listening = false

                        local holder, hStroke = makeHolder(38)
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

                        local pill = Instance.new("TextButton")
                        pill.Size = UDim2.new(0, 88, 0, 24)
                        pill.Position = UDim2.new(1, -96, 0.5, -12)
                        pill.BackgroundColor3 = C.accentDark
                        pill.Text = ""
                        pill.AutoButtonColor = false
                        pill.BorderSizePixel = 0
                        pill.Parent = holder
                        corner(pill, R.pill)
                        local pillStroke = stroke(pill, C.accentDim, 1)

                        local keyLbl = Instance.new("TextLabel")
                        keyLbl.Size = UDim2.new(1, 0, 1, 0)
                        keyLbl.BackgroundTransparency = 1
                        keyLbl.Font = Enum.Font.GothamBold
                        keyLbl.TextSize = 11
                        keyLbl.TextColor3 = C.accent
                        keyLbl.Text = keyName(bound)
                        keyLbl.Parent = pill

                        local obj = { CurrentKeybind = bound }

                                local rebindCatcher = nil  -- set when rebind mode starts

                                local function stopListening(newKey)
                                        listening = false
                                        anyKeybindListening = false
                                        if rebindCatcher then rebindCatcher:Destroy() rebindCatcher = nil end
                                if newKey ~= nil then
                                        bound = newKey
                                        obj.CurrentKeybind = bound
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
                        pill.MouseButton1Click:Connect(function()
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
                                -- Catcher: clicking outside the pill cancels rebind
                                rebindCatcher = Instance.new("TextButton")
                                rebindCatcher.Size = UDim2.new(1, 0, 1, 0)
                                rebindCatcher.BackgroundTransparency = 1
                                rebindCatcher.Text = ""
                                rebindCatcher.AutoButtonColor = false
                                rebindCatcher.Active = true
                                rebindCatcher.ZIndex = 1000
                                rebindCatcher.Parent = screenGui
                                rebindCatcher.MouseButton1Click:Connect(function()
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
                                                if hold then
                                                        pcall(callback, true)
                                                else
                                                        pcall(callback)
                                                end
                                        end
                                end
                        end))
                        if hold then
                                WindowJanitor:Add(UserInputService.InputEnded:Connect(function(inp)
                                        if bound and inp.KeyCode == bound and not listening then
                                                if callback then pcall(callback, false) end
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

                        local holder, hStroke = makeHolder(42)
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

                        local swatch = Instance.new("TextButton")
                        swatch.Size = UDim2.new(0, 58, 0, 30)
                        swatch.Position = UDim2.new(1, -66, 0.5, -15)
                        swatch.BackgroundColor3 = ccfg.Color or C.white
                        swatch.Text = ""
                        swatch.AutoButtonColor = false
                        swatch.BorderSizePixel = 0
                        swatch.Parent = holder
                        corner(swatch, R.small)
                        stroke(swatch, C.border, 1.5)

                        local obj = { Color = ccfg.Color or C.white }

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
                                catcher.Parent = screenGui
                                Tween(catcher, T15, { BackgroundTransparency = 0.5 })

                                local sp = swatch.AbsolutePosition
                                local cam = workspace.CurrentCamera
                                local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
                                local px = math.clamp(sp.X - 160, 10, vp.X - 280)
                                local py = math.clamp(sp.Y - 270, 10, vp.Y - 290)

                                local panel = Instance.new("Frame")
                                panel.Size = UDim2.new(0, 270, 0, 280)
                                panel.Position = UDim2.new(0, px, 0, py)
                                panel.BackgroundColor3 = C.panel
                                panel.BorderSizePixel = 0
                                panel.Active = true
                                panel.ZIndex = 9
                                panel.Parent = screenGui
                                corner(panel, R.panel)
                                stroke(panel, C.accent, 1.5)

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
                                local hexLbl = Instance.new("TextLabel")
                                hexLbl.Size = UDim2.new(0, 120, 0, 20)
                                hexLbl.Position = UDim2.new(0, 14, 0, 225)
                                hexLbl.BackgroundTransparency = 1
                                hexLbl.Font = Enum.Font.Code
                                hexLbl.TextSize = 12
                                hexLbl.TextColor3 = C.muted
                                hexLbl.TextXAlignment = Enum.TextXAlignment.Left
                                hexLbl.ZIndex = 9
                                hexLbl.Parent = panel

                                -- Done button
                                local doneBtn = Instance.new("TextButton")
                                doneBtn.Size = UDim2.new(0, 80, 0, 28)
                                doneBtn.Position = UDim2.new(1, -92, 0, 240)
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

                                -- Update function — fires callback LIVE
                                local function update()
                                        obj.Color = Color3.fromHSV(h, s, v)
                                        swatch.BackgroundColor3 = obj.Color
                                        preview.BackgroundColor3 = obj.Color
                                        pad.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                                        pointer.Position = UDim2.new(s, 0, 1 - v, 0)
                                        hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
                                        local r2, g2, b2 = math.floor(obj.Color.R * 255 + 0.5), math.floor(obj.Color.G * 255 + 0.5), math.floor(obj.Color.B * 255 + 0.5)
                                        hexLbl.Text = string.format("#%02X%02X%02X", r2, g2, b2)
                                        if callback then pcall(callback, obj.Color) end
                                        end
                                update()

                                -- Pad drag — uses InputBegan for mouse+touch support
                                pad.InputBegan:Connect(function(inp)
                                        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                                                registerDrag(pad, function(pos)
                                                        local px2 = math.clamp((pos.X - pad.AbsolutePosition.X) / pad.AbsoluteSize.X, 0, 1)
                                                        local py2 = math.clamp((pos.Y - pad.AbsolutePosition.Y) / pad.AbsoluteSize.Y, 0, 1)
                                                        s = px2
                                                        v = 1 - py2
                                                        update()
                                                end)
                                                -- Set initial position
                                                s = math.clamp((inp.Position.X - pad.AbsolutePosition.X) / pad.AbsoluteSize.X, 0, 1)
                                                v = 1 - math.clamp((inp.Position.Y - pad.AbsolutePosition.Y) / pad.AbsoluteSize.Y, 0, 1)
                                                update()
                                        end
                                end)

                                -- Hue slider drag — uses InputBegan for mouse+touch
                                hueSlider.InputBegan:Connect(function(inp)
                                        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                                                registerDrag(hueSlider, function(pos)
                                                        h = math.clamp((pos.X - hueSlider.AbsolutePosition.X) / hueSlider.AbsoluteSize.X, 0, 1)
                                                        update()
                                                end)
                                                h = math.clamp((inp.Position.X - hueSlider.AbsolutePosition.X) / hueSlider.AbsoluteSize.X, 0, 1)
                                                update()
                                        end
                                end)

                                -- [FIX] Was: bespoke closePopup() + currentPopupJanitor = nil
                                -- directly, same anti-pattern as Dropdown had — this popup was
                                -- never tracked, so opening a different popup while the color
                                -- picker was open left its full-screen catcher + panel stuck on
                                -- screen permanently. Same Janitor fix applied here.
                                doneBtn.MouseButton1Click:Connect(closeCurrentPopup)
                                catcher.MouseButton1Click:Connect(closeCurrentPopup)

                                local pj = Janitor.new()
                                pj:Add(catcher)
                                pj:Add(panel)
                                currentPopupJanitor = pj
                        end

                        swatch.MouseButton1Click:Connect(openPicker)

                        function obj:Set(color)
                                obj.Color = color
                                swatch.BackgroundColor3 = color
                                if callback then pcall(callback, color) end
                        end
                        function obj:Get() return obj.Color end

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
                        headerBtn.MouseButton1Click:Connect(function() obj:Toggle() end)
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
                        local holder, hStroke = makeHolder(42)
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
                        corner(pill, R.pill)
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
                        enHit.Parent = holder
                        enHit.MouseButton1Click:Connect(function()
                                enabled = not enabled
                                obj.Enabled = enabled
                                updateState()
                        end)
                        WindowJanitor:Add(UserInputService.InputBegan:Connect(function(inp, gp)
                                if gp then return end
                                if not enabled then return end
                                if UserInputService:GetFocusedTextBox() then return end
                                if inp.KeyCode == bound and callback then pcall(callback, enabled) end
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

                tab.Label = function(_, text) return tab:CreateSection(text) end
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

                return tab
        end

        -- ------------------------------------------------------------
        -- Destroy
        -- ------------------------------------------------------------
        function Window:Destroy()
                closeCurrentPopup()
                table.clear(DragHandlers)  -- clear stale drag handlers
                WindowJanitor:Cleanup()
        end

        table.insert(Library._windows, Window)
        Library._lastWindow = Window
        return Window
end

-- ============================================================
-- LIBRARY-LEVEL API (Rayfield-style)
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

function Library:Destroy()
        for _, w in ipairs(Library._windows) do
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
                Themes = { "Ember", "Ocean", "Crimson", "Slate", "Midnight", "Forest", "Coral" } }
end

return Library