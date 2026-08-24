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
        if type(size) == "table" and type(size[axis]) == "number" then
                return math.floor(size[axis] + 0.5)
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
                return callSafely(isfile, path) == true
        end
end

local Library = {}
Library.Flags = {}          -- flag -> element object (has CurrentValue / CurrentOption / etc.)
Library.Version = "5.3.0"
Library._windows = {}
Library.Options = { ReducedMotion = false }

-- ============================================================
-- CreateWindow
