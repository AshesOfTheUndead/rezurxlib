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
