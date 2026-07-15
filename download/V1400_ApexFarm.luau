--[[
    👑WELCOME DEVELOPER👑 V1400🔥: APEX FARM ENGINE
    ─────────────────────────────────────────────────────────
    NEW: APEX FARM ENGINE — 4 modes for insane muscle without crashing
      • Legacy:    Original 15-line pump (compatibility)
      • Burst:     0.5s intense pump + 0.15s rest (server-friendly)
      • MultiWorker: 1-10 parallel task.spawn workers (true parallelism)
      • Smart:     Auto-tunes worker count based on ACTUAL gains/sec
                   Reads your muscle value, measures delta, scales workers
                   up if gains are increasing, down if FPS drops or gains plateau

    NEW: POWER TRACKER
      • Reads Configuration.TrainSystem attributes every 1s
      • Calculates gains/sec, session total, average
      • Live display in UI: current power, gains/sec, session time

    KEPT FROM V1300:
      • V777 noclip (Directive 1 — untouched)
      • Glass-morphism fallback UI
      • Self-healing remotes (healRemotes + 30s periodic re-init)
      • Anti-detection (shuffle + micro-delays)
      • Anti-AFK
      • Error logging to _G.__V1400_ERRORS
      • xpcall top-level catcher with on-screen error box
      • Multi-host Rayfield loader (4 fallbacks)
      • Lua 5.1 compat (no goto, no +=, no table.unpack)
    ─────────────────────────────────────────────────────────
]]

-- ============================================================
-- DIRECTIVE 8 (early init): Global error log
-- ============================================================
if not _G.__V1400_ERRORS then _G.__V1400_ERRORS = {} end
local ERR_LOG = _G.__V1400_ERRORS

local function logError(source, msg)
    local entry = {
        time     = os.time(),
        timeStr  = os.date("%H:%M:%S"),
        source   = source,
        msg      = tostring(msg),
        traceback = debug.traceback("", 2):sub(1, 600),
    }
    ERR_LOG[#ERR_LOG + 1] = entry
    if #ERR_LOG > 200 then table.remove(ERR_LOG, 1) end
    warn(string.format("[V1400 ERR] %s: %s", source, msg))
end

local function safeCall(source, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then logError(source, err) end
    return ok, err
end

-- ============================================================
-- TOP-LEVEL ERROR CATCHER
-- ============================================================
local function showErrorToUser(msg)
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local sg = Instance.new("ScreenGui")
        sg.Name = "V1400_Error"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.Parent = CoreGui
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 540, 0, 220)
        f.Position = UDim2.new(0.5, -270, 0.5, -110)
        f.BackgroundColor3 = Color3.fromRGB(35, 0, 0)
        f.Parent = sg
        local c = Instance.new("UICorner") c.CornerRadius = UDim2.new(0, 10, 0, 10) c.Parent = f
        local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(220, 30, 30) s.Thickness = 2 s.Parent = f
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -24, 1, -24)
        t.Position = UDim2.new(0, 12, 0, 12)
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.Code
        t.TextSize = 13
        t.TextColor3 = Color3.fromRGB(255, 230, 230)
        t.TextWrapped = true
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.TextYAlignment = Enum.TextYAlignment.Top
        t.Text = "V1400 ERROR:\n\n" .. tostring(msg)
        t.Parent = f
        task.delay(25, function() pcall(function() sg:Destroy() end) end)
    end)
end

-- ============================================================
-- MAIN
-- ============================================================
local function runMain()

if not game:IsLoaded() then
    repeat task.wait(0.1) until game:IsLoaded()
end

-- ============================================================
-- SERVICES (locals — Directive 7 CPU reduction)
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local CoreGui           = game:GetService("CoreGui")
local StarterGui        = game:GetService("StarterGui")
local TweenService      = game:GetService("TweenService")
local player            = Players.LocalPlayer

-- ============================================================
-- FORWARD DECLARATIONS
-- ============================================================
local applyMovement, restoreMovement
local legacyDoTrain, burstDoTrain, multiWorkerDoTrain, smartDoTrain
local sendChatMessage
local initAllRemotes, healRemotes
local notify
local clearAllEspTags
local setTurbo
local Rayfield, Window
local liveStats, farmStatsParagraph
local startFarm, stopFarm
local powerTracker

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    CustomTag      = "",
    UserName       = "",
    TagColor       = Color3.fromRGB(128, 0, 0),
    UserColor      = Color3.fromRGB(255, 255, 255),
    MessageColor   = Color3.fromRGB(255, 255, 255),
    -- Farm
    FarmMode       = "Smart",          -- Legacy / Burst / MultiWorker / Smart
    FarmEnabled    = false,
    FarmSpeedMul   = 1,
    WorkerCount    = 5,                 -- for MultiWorker mode
    -- ESP
    EspEnabled     = false,
    -- Movement
    OverrideStats  = false,
    WalkSpeed      = 16,
    JumpPower      = 50,
    -- Combat
    RespectFarm    = false,
    -- Experimental
    Noclip         = false,             -- V777 — untouched
    PvpOff         = false,
    AntiAfk        = true,
    -- Turbo
    TurboActive    = false,
    TurboUntil     = 0,
    TurboCooldownUntil = 0,
    -- Anti-detect
    AntiDetect     = true,
}

-- ============================================================
-- HELPERS
-- ============================================================
local function dropValue(v)
    if typeof(v) == "table" then return v[1] or "" end
    return tostring(v)
end

-- Lua 5.1 compat shim
local unpack = unpack or table.unpack

local function formatNumber(n)
    local suffixes = {
        {1e33, "De"}, {1e30, "No"}, {1e27, "Oc"}, {1e24, "Sp"},
        {1e21, "Sx"}, {1e18, "Qi"}, {1e15, "Qa"}, {1e12, "T"},
        {1e9, "B"}, {1e6, "M"}, {1e3, "K"},
    }
    for _, s in ipairs(suffixes) do
        if n >= s[1] then
            return string.format("%.2f%s", n / s[1], s[2])
        end
    end
    return tostring(n)
end

local function safeInvoke(remote, ...)
    if not remote then healRemotes() return end
    local ok = pcall(remote.InvokeServer, remote, ...)
    if not ok then logError("InvokeServer", "failed, healing"); healRemotes() end
end

local function safeFire(remote, ...)
    if not remote then healRemotes() return end
    local ok = pcall(remote.FireServer, remote, ...)
    if not ok then logError("FireServer", "failed, healing"); healRemotes() end
end

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- ============================================================
-- REMOTE MANAGER (self-healing)
-- ============================================================
local Remotes = {}

initAllRemotes = function()
    pcall(function()
        local tsRoot = ReplicatedStorage:FindFirstChild("TrainSystem")
        local tsRem  = tsRoot and tsRoot:FindFirstChild("Remote")
        if tsRem then
            Remotes.ApplyAddFrenzyValue  = tsRem:FindFirstChild("ApplyAddFrenzyValue")
            Remotes.TrainSpeedHasChanged = tsRem:FindFirstChild("TrainSpeedHasChanged")
        end
        local teRoot = ReplicatedStorage:FindFirstChild("TrainEquipment")
        local teRem  = teRoot and teRoot:FindFirstChild("Remote")
        if teRem then
            Remotes.ApplyMobileTrain     = teRem:FindFirstChild("ApplyMobileTrain")
            Remotes.ApplyStationaryTrain = teRem:FindFirstChild("ApplyStationaryTrain")
        end
        local tc = ReplicatedStorage:FindFirstChild("TextChat")
        local tcRem = tc and tc:FindFirstChild("Remote")
        if tcRem then
            Remotes.SendTextChatMessage = tcRem:FindFirstChild("SendTextChatMessageToAllPlayer")
        end
        local ab = ReplicatedStorage:FindFirstChild("Ability")
        local abRem = ab and ab:FindFirstChild("Remote")
        if abRem then
            Remotes.ApplyCastAbility = abRem:FindFirstChild("ApplyCastAbility")
        end
        local ar = ReplicatedStorage:FindFirstChild("Area")
        local arRem = ar and ar:FindFirstChild("Remote")
        if arRem then
            Remotes.PlayerAreaIn = arRem:FindFirstChild("PlayerAreaIn")
        end
    end)
end
healRemotes = initAllRemotes
initAllRemotes()

-- Periodic re-init every 30s (catches server-side remote swaps)
task.spawn(function()
    while task.wait(30) do safeCall("periodic-remote-init", initAllRemotes) end
end)

-- ============================================================
-- POWER TRACKER — reads actual muscle value, calculates gains/sec
-- This is the key innovation. Instead of guessing how much we're gaining
-- by counting remote calls, we READ the actual muscle attribute and
-- measure the real delta. This lets Smart mode auto-tune.
-- ============================================================
local TRAIN_SPEED = 1e9

powerTracker = {
    sessionStart    = 0,
    sessionStartPower = 0,
    lastTickTime    = 0,
    lastTickPower   = 0,
    gainsPerSec     = 0,
    gainsThisSession = 0,
    samples         = {},  -- ring buffer of recent gains/sec readings
    history         = {},  -- ring buffer of (time, power) for trend
}

function powerTracker.readPower()
    -- Reads Configuration.TrainSystem attributes 1-4, sums them.
    -- This is the same logic the ESP uses, applied to yourself.
    local cfg = player:FindFirstChild("Configuration")
    local ts = cfg and cfg:FindFirstChild("TrainSystem")
    if not ts then return 0 end
    local total = 0
    for i = 1, 4 do
        total = total + (ts:GetAttribute(tostring(i)) or 0)
    end
    return total
end

function powerTracker.startSession()
    powerTracker.sessionStart      = tick()
    powerTracker.sessionStartPower = powerTracker.readPower()
    powerTracker.lastTickTime      = tick()
    powerTracker.lastTickPower     = powerTracker.sessionStartPower
    powerTracker.gainsThisSession  = 0
    powerTracker.samples           = {}
    powerTracker.history           = {}
end

function powerTracker.tick()
    -- Called every 1s by the UI updater. Measures actual gains.
    local now   = tick()
    local power = powerTracker.readPower()
    local dt    = now - powerTracker.lastTickTime
    if dt > 0 then
        local delta = power - powerTracker.lastTickPower
        powerTracker.gainsPerSec = delta / dt
        powerTracker.gainsThisSession = powerTracker.gainsThisSession + delta
        -- Push to samples ring buffer (keep last 10)
        table.insert(powerTracker.samples, powerTracker.gainsPerSec)
        if #powerTracker.samples > 10 then table.remove(powerTracker.samples, 1) end
        -- Push to history (keep last 60s)
        table.insert(powerTracker.history, { t = now, p = power })
        if #powerTracker.history > 60 then table.remove(powerTracker.history, 1) end
    end
    powerTracker.lastTickTime  = now
    powerTracker.lastTickPower = power
    return power
end

function powerTracker.avgGainsPerSec()
    -- Average of last 10 samples — smoother than instantaneous
    local sum = 0
    for _, v in ipairs(powerTracker.samples) do sum = sum + v end
    return #powerTracker.samples > 0 and (sum / #powerTracker.samples) or 0
end

function powerTracker.trend()
    -- Compare recent samples to older samples. Returns "up"/"down"/"flat".
    if #powerTracker.samples < 4 then return "flat" end
    local recent = 0
    local older = 0
    local half = math.floor(#powerTracker.samples / 2)
    for i = 1, half do older = older + powerTracker.samples[i] end
    for i = half + 1, #powerTracker.samples do recent = recent + powerTracker.samples[i] end
    older = older / half
    recent = recent / (#powerTracker.samples - half)
    if recent > older * 1.15 then return "up" end
    if recent < older * 0.85 then return "down" end
    return "flat"
end

function powerTracker.reset()
    powerTracker.startSession()
end

-- ============================================================
-- APEX FARM ENGINE — 4 modes
-- All modes use the same Remotes table. All support anti-detect.
-- ============================================================

-- The pure pump logic, shared by all modes.
-- 15 calls total (matches original). Anti-detect shuffles + jitters.
local function executePump(r, speed)
    local calls = {
        {func = "Invoke", remote = r.ApplyAddFrenzyValue,  args = {10000}},
        {func = "Fire",   remote = r.TrainSpeedHasChanged, args = {speed}},
        {func = "Invoke", remote = r.ApplyMobileTrain,     args = {speed}},
        {func = "Invoke", remote = r.ApplyStationaryTrain, args = {speed}},
        {func = "Invoke", remote = r.ApplyStationaryTrain, args = {speed}},
        {func = "Fire",   remote = r.TrainSpeedHasChanged, args = {speed}},
        {func = "Invoke", remote = r.ApplyMobileTrain,     args = {speed}},
        {func = "Invoke", remote = r.ApplyStationaryTrain, args = {speed}},
        {func = "Invoke", remote = r.ApplyStationaryTrain, args = {speed}},
        {func = "Fire",   remote = r.TrainSpeedHasChanged, args = {speed}},
        {func = "Invoke", remote = r.ApplyMobileTrain,     args = {speed}},
        {func = "Invoke", remote = r.ApplyStationaryTrain, args = {speed}},
        {func = "Invoke", remote = r.ApplyStationaryTrain, args = {speed}},
        {func = "Fire",   remote = r.TrainSpeedHasChanged, args = {speed}},
        {func = "Invoke", remote = r.ApplyAddFrenzyValue,  args = {10000}},
    }
    if Config.AntiDetect then shuffle(calls) end
    for _, c in ipairs(calls) do
        if c.remote then
            if c.func == "Invoke" then
                pcall(c.remote.InvokeServer, c.remote, unpack(c.args))
            else
                pcall(c.remote.FireServer, c.remote, unpack(c.args))
            end
        end
        -- Anti-detect: 30% chance of 0-3ms micro-delay
        if Config.AntiDetect and math.random() < 0.3 then
            task.wait(math.random() * 0.003)
        end
    end
end

-- MODE 1: LEGACY — original 15-line pump on Heartbeat
-- Same as V1300. Good baseline, max compatibility.
legacyDoTrain = function()
    if not Remotes.ApplyAddFrenzyValue then healRemotes() end
    if not Remotes.ApplyAddFrenzyValue then return end
    executePump(Remotes, TRAIN_SPEED)
end

-- MODE 2: BURST — 0.5s intense pump + 0.15s rest
-- Server-friendly: gives the server time to process between bursts.
-- Reduces rate-limit triggers while maintaining high throughput.
burstDoTrain = function()
    if not Remotes.ApplyAddFrenzyValue then healRemotes() end
    if not Remotes.ApplyAddFrenzyValue then return end
    local burstEnd = tick() + 0.5
    while tick() < burstEnd do
        executePump(Remotes, TRAIN_SPEED)
        RunService.Heartbeat:Wait()  -- yield to avoid blocking main thread
    end
    task.wait(0.15)  -- rest period — lets server process
end

-- MODE 3: MULTIWORKER — N parallel task.spawn workers
-- True parallelism. Each worker does the pump independently with its own yields.
-- Scales linearly up to server rate limit. Default 5 workers.
multiWorkerDoTrain = function()
    if not Remotes.ApplyAddFrenzyValue then healRemotes() end
    if not Remotes.ApplyAddFrenzyValue then return end
    local n = math.max(1, math.min(10, Config.WorkerCount * Config.FarmSpeedMul))
    for _ = 1, n do
        task.spawn(function()
            executePump(Remotes, TRAIN_SPEED)
        end)
    end
end

-- MODE 4: SMART — auto-tunes worker count based on actual gains/sec
-- Reads PowerTracker. If gains are increasing → add workers.
-- If gains plateau or FPS drops → reduce workers.
-- This is the "insane muscle without destroying your game" mode.
local smartWorkers = 3  -- dynamic, auto-adjusted
local smartLastAdjust = 0
local smartFpsHistory = {}

smartDoTrain = function()
    if not Remotes.ApplyAddFrenzyValue then healRemotes() end
    if not Remotes.ApplyAddFrenzyValue then return end

    -- Auto-tune every 3 seconds
    local now = tick()
    if now - smartLastAdjust >= 3 then
        smartLastAdjust = now
        local avgGains = powerTracker.avgGainsPerSec()
        local trend = powerTracker.trend()

        -- Measure FPS (count Heartbeat fires in 0.5s)
        local fpsT0 = tick()
        local fpsCount = 0
        local fpsConn = RunService.Heartbeat:Connect(function()
            fpsCount = fpsCount + 1
        end)
        task.wait(0.5)
        fpsConn:Disconnect()
        local fps = math.floor(fpsCount / 0.5)
        table.insert(smartFpsHistory, fps)
        if #smartFpsHistory > 5 then table.remove(smartFpsHistory, 1) end
        local avgFps = 0
        for _, v in ipairs(smartFpsHistory) do avgFps = avgFps + v end
        avgFps = avgFps / #smartFpsHistory

        -- Decision logic:
        -- If FPS < 25 → reduce workers (game is struggling)
        -- If gains trending down AND workers > 2 → reduce (we're hitting rate limit)
        -- If gains trending up AND FPS > 50 → add workers (we have headroom)
        -- If gains flat AND FPS > 50 → try adding (might break through plateau)
        local oldWorkers = smartWorkers
        if avgFps < 25 then
            smartWorkers = math.max(1, smartWorkers - 1)
            logError("smart-tune", "FPS low (" .. avgFps .. "), reducing workers to " .. smartWorkers)
        elseif trend == "down" and smartWorkers > 2 then
            smartWorkers = math.max(1, smartWorkers - 1)
            logError("smart-tune", "gains down, reducing workers to " .. smartWorkers)
        elseif trend == "up" and avgFps > 50 and smartWorkers < 10 then
            smartWorkers = math.min(10, smartWorkers + 1)
            logError("smart-tune", "gains up + FPS good, increasing workers to " .. smartWorkers)
        elseif trend == "flat" and avgFps > 50 and smartWorkers < 8 then
            smartWorkers = math.min(8, smartWorkers + 1)
            logError("smart-tune", "plateau, trying more workers: " .. smartWorkers)
        end
    end

    -- Fire with current worker count
    local turboMul = Config.TurboActive and 2 or 1
    local n = math.max(1, smartWorkers * turboMul * Config.FarmSpeedMul)
    for _ = 1, n do
        task.spawn(function()
            executePump(Remotes, TRAIN_SPEED)
        end)
    end
end

-- Dispatch: pick the right DoTrain based on Config.FarmMode
local function dispatchFarm()
    local mode = Config.FarmMode
    if mode == "Legacy" then return legacyDoTrain
    elseif mode == "Burst" then return burstDoTrain
    elseif mode == "MultiWorker" then return multiWorkerDoTrain
    else return smartDoTrain end  -- default: Smart
end

-- Farm controller — single Heartbeat connection, swaps DoTrain function dynamically
local farmConn
startFarm = function()
    if farmConn then farmConn:Disconnect() farmConn = nil end
    powerTracker.startSession()
    local fn = dispatchFarm()
    farmConn = RunService.Heartbeat:Connect(function()
        safeCall("farm-" .. Config.FarmMode, fn)
        -- Pick up mode changes without restarting the connection
        fn = dispatchFarm()
    end)
end
stopFarm = function()
    if farmConn then farmConn:Disconnect() farmConn = nil end
end

-- ============================================================
-- CHAT (GHOST SHOUT)
-- ============================================================
local function buildChatMessage(msg)
    local tagPart, namePart = "", ""
    if Config.CustomTag ~= "" then
        tagPart = string.format('<font color="#%s"><b>[%s]</b></font> ',
            Config.TagColor:ToHex(), Config.CustomTag)
    end
    if Config.UserName ~= "" then
        namePart = string.format('<font color="#%s"><b>%s:</b></font> ',
            Config.UserColor:ToHex(), Config.UserName)
    end
    return tagPart .. namePart ..
        string.format('<font color="#%s"><b>%s</b></font>',
            Config.MessageColor:ToHex(), msg)
end

sendChatMessage = function(msg)
    if not Remotes.SendTextChatMessage then healRemotes() end
    if not Remotes.SendTextChatMessage or not msg or msg == "" then return end
    local full = buildChatMessage(msg)
    local ok1 = pcall(function() Remotes.SendTextChatMessage:InvokeServer({ Text = full }) end)
    if not ok1 then
        safeCall("chat-send", function()
            Remotes.SendTextChatMessage:InvokeServer(full)
        end)
    end
end

-- ============================================================
-- MOVEMENT
-- ============================================================
applyMovement = function()
    if not Config.OverrideStats then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.WalkSpeed    = Config.WalkSpeed
    hum.JumpPower    = Config.JumpPower
    hum.UseJumpPower = true
end

restoreMovement = function()
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end
end

-- ============================================================
-- TURBO BOOST (Directive 6)
-- ============================================================
local TURBO_DURATION  = 10
local TURBO_COOLDOWN  = 5
setTurbo = function()
    local now = tick()
    if Config.TurboActive then notify("Turbo", "Already active!", 3) return end
    if now < Config.TurboCooldownUntil then
        local remaining = math.ceil(Config.TurboCooldownUntil - now)
        notify("Turbo Cooldown", "Wait " .. remaining .. "s", 3)
        return
    end
    Config.TurboActive = true
    Config.TurboUntil = now + TURBO_DURATION
    notify("🚀 TURBO", "2x farming for 10s!", 3)
    task.spawn(function()
        while Config.TurboActive and tick() < Config.TurboUntil do
            task.wait(0.5)
        end
        Config.TurboActive = false
        Config.TurboCooldownUntil = tick() + TURBO_COOLDOWN
        notify("Turbo End", "Cooldown 5s.", 3)
    end)
end

-- ============================================================
-- ESP — single RenderStepped loop + cache
-- ============================================================
local espCache = {}
local espConn = nil

clearAllEspTags = function()
    if espConn then espConn:Disconnect() espConn = nil end
    for head, entry in pairs(espCache) do
        if entry.gui and entry.gui.Parent then entry.gui:Destroy() end
    end
    table.clear(espCache)
end

local function getPowerFor(name)
    local p = Players:FindFirstChild(name)
    if not p then return 0 end
    local cfg = p:FindFirstChild("Configuration")
    local ts = cfg and cfg:FindFirstChild("TrainSystem")
    if not ts then return 0 end
    local total = 0
    for i = 1, 4 do
        total = total + (ts:GetAttribute(tostring(i)) or 0)
    end
    return total
end

local function makeEspTag(head, name)
    local bb = Instance.new("BillboardGui")
    bb.Name = "RezurTag"; bb.Adornee = head
    bb.Size = UDim2.new(0, 100, 0, 30); bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true; bb.Parent = head
    local l = Instance.new("TextLabel")
    l.Parent = bb; l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1; l.TextColor3 = Color3.new(1, 1, 1)
    l.TextStrokeTransparency = 0; l.TextScaled = true
    l.Text = formatNumber(getPowerFor(name))
    return bb, l
end

-- ============================================================
-- RAYFIELD LOADER (4 hosts)
-- ============================================================
local RAYFIELD_HOSTS = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
    "https://rayfield.sirius.menu/v2/source.lua",
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/master/source.lua",
}

local function loadRayfield()
    for i, url in ipairs(RAYFIELD_HOSTS) do
        local okHttp, src = pcall(function() return game:HttpGet(url) end)
        if okHttp and src and #src > 100 then
            local okLoad, fn = pcall(function() return loadstring(src) end)
            if okLoad and fn then
                local okCall, rf = pcall(fn)
                if okCall and rf and rf.CreateWindow then
                    warn(string.format("[V1400] Rayfield loaded from host #%d", i))
                    return rf
                end
            end
        end
    end
    return nil
end

Rayfield = loadRayfield()

-- ============================================================
-- FALLBACK UI (glass-morphism)
-- ============================================================
local FallbackUI = {}

if not Rayfield then
    warn("[V1400] All Rayfield hosts failed. Spawning fallback UI.")
    local sg = Instance.new("ScreenGui")
    sg.Name = "V1400_Fallback"; sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.IgnoreGuiInset = true
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = player:WaitForChild("PlayerGui") end

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 520, 0, 420)
    main.Position = UDim2.new(0.5, -260, 0.5, -210)
    main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    main.BackgroundTransparency = 0.05; main.BorderSizePixel = 0; main.Parent = sg
    local mc = Instance.new("UICorner") mc.CornerRadius = UDim2.new(0, 12, 0, 12) mc.Parent = main
    local ms = Instance.new("UIStroke") ms.Color = Color3.fromRGB(180, 30, 30)
    ms.Thickness = 1.5; ms.Transparency = 0.2; ms.Parent = main
    local mg = Instance.new("UIGradient")
    mg.Color = ColorSequence.new(Color3.fromRGB(28, 28, 34), Color3.fromRGB(14, 14, 18))
    mg.Rotation = 90; mg.Parent = main

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 36)
    topBar.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    topBar.BackgroundTransparency = 0.1; topBar.BorderSizePixel = 0; topBar.Parent = main
    local tc2 = Instance.new("UICorner") tc2.CornerRadius = UDim2.new(0, 12, 0, 12) tc2.Parent = topBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -100, 1, 0); title.Position = UDim2.new(0, 14, 0, 0)
    title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBold
    title.TextSize = 14; title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "👑 V1400 FALLBACK"; title.Parent = topBar

    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Size = UDim2.new(0, 60, 0, 24); fpsLabel.Position = UDim2.new(1, -110, 0.5, -12)
    fpsLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 50); fpsLabel.BackgroundTransparency = 0.3
    fpsLabel.Font = Enum.Font.Code; fpsLabel.TextSize = 11
    fpsLabel.TextColor3 = Color3.fromRGB(120, 220, 120); fpsLabel.Text = "60 FPS"
    fpsLabel.Parent = topBar
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim2.new(0, 6, 0, 6) fc.Parent = fpsLabel

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 24); closeBtn.Position = UDim2.new(1, -36, 0.5, -12)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0); closeBtn.Text = "X"
    closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 12
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); closeBtn.Parent = topBar
    local cc = Instance.new("UICorner") cc.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function() sg.Enabled = false end)

    local dragging, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = main.Position
        end
    end)
    topBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                       startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -50); scroll.Position = UDim2.new(0, 10, 0, 41)
    scroll.BackgroundTransparency = 1; scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(180, 30, 30)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.Parent = main
    local layout = Instance.new("UIListLayout") layout.Padding = UDim.new(0, 6) layout.Parent = scroll
    local pad = Instance.new("UIPadding") pad.PaddingTop = UDim.new(0, 4) pad.Parent = scroll

    FallbackUI.Scroll = scroll; FallbackUI.Sg = sg; FallbackUI.FpsLabel = fpsLabel

    function FallbackUI:Notify(cfg)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = cfg.Title or "V1400", Text = cfg.Content or "",
                Duration = cfg.Duration or 5,
            })
        end)
    end

    function FallbackUI:AddToggle(name, default, callback)
        local state = default or false
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 32)
        b.BackgroundColor3 = state and Color3.fromRGB(80, 30, 30) or Color3.fromRGB(35, 35, 42)
        b.Text = "  " .. name .. ": " .. (state and "ON" or "OFF")
        b.Font = Enum.Font.GothamMedium; b.TextSize = 12
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextXAlignment = Enum.TextXAlignment.Left; b.Parent = scroll
        local c = Instance.new("UICorner") c.CornerRadius = UDim2.new(0, 6, 0, 6) c.Parent = b
        b.MouseButton1Click:Connect(function()
            state = not state
            TweenService:Create(b, TweenInfo.new(0.15), {
                BackgroundColor3 = state and Color3.fromRGB(80, 30, 30) or Color3.fromRGB(35, 35, 42)
            }):Play()
            b.Text = "  " .. name .. ": " .. (state and "ON" or "OFF")
            pcall(callback, state)
        end)
        return b
    end

    function FallbackUI:AddButton(name, callback)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 32); b.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        b.Text = "  " .. name; b.Font = Enum.Font.GothamMedium; b.TextSize = 12
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextXAlignment = Enum.TextXAlignment.Left; b.Parent = scroll
        local c = Instance.new("UICorner") c.CornerRadius = UDim2.new(0, 6, 0, 6) c.Parent = b
        b.MouseEnter:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(50, 50, 60)}):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(35, 35, 42)}):Play()
        end)
        b.MouseButton1Click:Connect(function() pcall(callback) end)
        return b
    end

    function FallbackUI:AddLabel(text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 22); l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold; l.TextSize = 12
        l.TextColor3 = Color3.fromRGB(220, 50, 50)
        l.TextXAlignment = Enum.TextXAlignment.Left; l.Text = text
        l.Parent = scroll; return l
    end

    function FallbackUI:AddProgress(name)
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, 0, 0, 36)
        holder.BackgroundColor3 = Color3.fromRGB(28, 28, 34); holder.Parent = scroll
        local hc = Instance.new("UICorner") hc.CornerRadius = UDim2.new(0, 6, 0, 6) hc.Parent = holder
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -12, 0, 14); lbl.Position = UDim2.new(0, 6, 0, 4)
        lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11; lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = name; lbl.Parent = holder
        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -12, 0, 8); track.Position = UDim2.new(0, 6, 0, 22)
        track.BackgroundColor3 = Color3.fromRGB(45, 45, 55); track.Parent = holder
        local tc3 = Instance.new("UICorner") tc3.CornerRadius = UDim2.new(1, 0, 1, 0) tc3.Parent = track
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
        fill.Parent = track
        local fc2 = Instance.new("UICorner") fc2.CornerRadius = UDim2.new(1, 0, 1, 0) fc2.Parent = fill
        local fg = Instance.new("UIGradient")
        fg.Color = ColorSequence.new(Color3.fromRGB(220, 50, 50), Color3.fromRGB(180, 30, 30))
        fg.Parent = fill
        local obj = { Fill = fill, Label = lbl }
        function obj:Set(pct, text)
            pct = math.clamp(pct, 0, 1)
            TweenService:Create(fill, TweenInfo.new(0.2), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
            if text then lbl.Text = name .. ": " .. text end
        end
        return obj
    end

    notify = function(t, c, d) FallbackUI:Notify({ Title = t, Content = c, Duration = d or 5 }) end
else
    notify = function(t, c, d) pcall(Rayfield.Notify, Rayfield, { Title = t, Content = c, Duration = d or 5 }) end
end

-- ============================================================
-- BUILD UI
-- ============================================================
if Rayfield then
    Window = Rayfield:CreateWindow({
        Name = "👑WELCOME DEVELOPER👑 | V1400🔥 APEX FARM",
        LoadingTitle = "V1400🔥 APEX FARM ENGINE",
        LoadingSubtitle = "4 modes • Power tracker • Smart auto-tune",
        ConfigurationSaving = { Enabled = false },
        Keybind = { Key = Enum.KeyCode.K, Mods = nil },
    })
else
    Window = FallbackUI
    -- Fallback UI build
    FallbackUI:AddLabel("===== NEXUS IDENTITY =====")
    FallbackUI:AddButton("Send Test Shout", function() sendChatMessage("V1400 test") end)
    FallbackUI:AddButton("Re-scan Chat Remote", function()
        healRemotes()
        notify("Chat Remote", Remotes.SendTextChatMessage and "Found" or "Missing", 4)
    end)

    FallbackUI:AddLabel("===== APEX FARM ENGINE =====")
    local farmProgress = FallbackUI:AddProgress("Power")
    FallbackUI:AddToggle("Auto Train (Smart)", false, function(t)
        Config.FarmEnabled = t
        if t then startFarm() else stopFarm() end
    end)
    FallbackUI:AddButton("Turbo Boost (2x / 10s)", function() setTurbo() end)
    FallbackUI:AddToggle("Anti-Detect", true, function(t) Config.AntiDetect = t end)
    FallbackUI:AddToggle("Auto Respect Farm", false, function(t)
        Config.RespectFarm = t
        if not t then return end
        task.spawn(function()
            while Config.RespectFarm do
                for _, v in ipairs(Players:GetPlayers()) do
                    if v ~= player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                        local myChar = player.Character
                        if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                            safeCall("respect-farm", function()
                                myChar.HumanoidRootPart.CFrame = v.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,3)
                                if Remotes.ApplyCastAbility then Remotes.ApplyCastAbility:InvokeServer(v.Name, "1") end
                            end)
                        end
                    end
                    task.wait(0.1)
                end
                task.wait(0.5)
            end
        end)
    end)

    FallbackUI:AddLabel("===== PHYSICAL OVERRIDE =====")
    FallbackUI:AddToggle("Override Walk/Jump", false, function(t)
        Config.OverrideStats = t
        if t then applyMovement() else restoreMovement() end
    end)
    FallbackUI:AddToggle("Noclip (V777)", false, function(t) Config.Noclip = t end)

    FallbackUI:AddLabel("===== DARK EXPERIMENTS =====")
    FallbackUI:AddToggle("PVP Off", false, function(t) Config.PvpOff = t end)
    FallbackUI:AddToggle("Anti-AFK", true, function(t) Config.AntiAfk = t end)

    FallbackUI:AddLabel("===== STATUS / DEBUG =====")
    FallbackUI:AddButton("Show Remote Status", function()
        healRemotes()
        notify("Remote Status",
            "Train:" .. (Remotes.ApplyAddFrenzyValue and "Y" or "N") ..
            " Chat:" .. (Remotes.SendTextChatMessage and "Y" or "N") ..
            " Combat:" .. (Remotes.ApplyCastAbility and "Y" or "N") ..
            " Area:" .. (Remotes.PlayerAreaIn and "Y" or "N"), 10)
    end)
    FallbackUI:AddButton("Re-init All Remotes", function() healRemotes() notify("Remotes", "Re-scanned.", 3) end)
    FallbackUI:AddButton("Show Error Log", function()
        local n = #ERR_LOG
        if n == 0 then notify("Error Log", "No errors", 4) return end
        local lines = {}
        for i = math.max(1, n - 4), n do
            local e = ERR_LOG[i]
            if e then table.insert(lines, string.format("%s [%s] %s", e.timeStr, e.source, e.msg:sub(1, 80))) end
        end
        notify("Error Log (" .. n .. ")", table.concat(lines, "\n"), 12)
    end)
    FallbackUI:AddButton("Clear Error Log", function() table.clear(ERR_LOG) notify("Error Log", "Cleared.", 3) end)

    -- FPS + power tracker live update
    task.spawn(function()
        local frames = 0; local t0 = tick()
        while task.wait(0.5) do
            frames = frames + 1
            local elapsed = tick() - t0
            if elapsed >= 1 then
                local fps = math.floor(frames / elapsed)
                FallbackUI.FpsLabel.Text = fps .. " FPS"
                FallbackUI.FpsLabel.TextColor3 = fps >= 50 and Color3.fromRGB(120, 220, 120)
                                              or fps >= 30 and Color3.fromRGB(220, 220, 120)
                                              or Color3.fromRGB(220, 80, 80)
                frames = 0; t0 = tick()
            end
        end
    end)

    -- Power tracker live update for fallback
    task.spawn(function()
        while task.wait(1) do
            local power = powerTracker.tick()
            if Config.FarmEnabled then
                local pct = math.min(1, math.log10(power + 1) / 15)  -- log scale for big numbers
                farmProgress:Set(pct, formatNumber(power) .. " | " .. formatNumber(powerTracker.avgGainsPerSec()) .. "/s")
            end
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.K then
            FallbackUI.Sg.Enabled = not FallbackUI.Sg.Enabled
        end
    end)

    notify("V1400 Fallback", "Rayfield failed — minimal glass UI active. K to toggle.", 8)
end

-- ============================================================
-- RAYFIELD UI BUILD (guarded for Lua 5.1 — no goto/label)
-- ============================================================
if Rayfield then

-- TAB 1: NEXUS IDENTITY
local IdTab = Window:CreateTab("Nexus Identity", 4483362458)
IdTab:CreateDropdown({
    Name = "Quick-Access Titles",
    Options = {"GLOBAL", "SERVER ANNOUNCEMENT", "👑Head Administrator👑",
               "👑Head Executive Lead Developer👑", "None"},
    CurrentOption = "None",
    Callback = function(v)
        local val = dropValue(v)
        Config.CustomTag = (val == "None" or val == "") and "" or val
    end,
})
IdTab:CreateDropdown({
    Name = "Quick-Access Usernames",
    Options = {"RezurXshin☑️", "Jandel", "Administrator", "None"},
    CurrentOption = "None",
    Callback = function(v)
        local val = dropValue(v)
        Config.UserName = (val == "None" or val == "") and "" or val
    end,
})
IdTab:CreateInput({Name = "Custom Title / Tag", PlaceholderText = "Empty = No Tag",
    Callback = function(v) Config.CustomTag = v or "" end})
IdTab:CreateInput({Name = "User Name", PlaceholderText = "Empty = No Name",
    Callback = function(v) Config.UserName = v or "" end})
IdTab:CreateColorPicker({Name = "Title / Tag Color", Color = Config.TagColor,
    Callback = function(v) Config.TagColor = v end})
IdTab:CreateColorPicker({Name = "User Name Color", Color = Config.UserColor,
    Callback = function(v) Config.UserColor = v end})
IdTab:CreateColorPicker({Name = "Message Text Color", Color = Config.MessageColor,
    Callback = function(v) Config.MessageColor = v end})
IdTab:CreateButton({Name = "Preview Current Identity", Callback = function()
    local tag = Config.CustomTag ~= "" and ("[" .. Config.CustomTag .. "] ") or ""
    local usr = Config.UserName ~= "" and Config.UserName or "(default)"
    notify("Identity Preview", tag .. usr, 4)
end})

-- TAB 2: GHOST SHOUT
local GlobalTab = Window:CreateTab("Ghost Shout", 4483362458)
GlobalTab:CreateInput({Name = "Send Shout (Box)", PlaceholderText = "Type message...",
    RemoveTextAfterFocusLost = true, Callback = function(msg) sendChatMessage(msg) end})
GlobalTab:CreateButton({Name = "Re-scan Chat Remote", Callback = function()
    healRemotes()
    notify("Chat Remote Status",
        Remotes.SendTextChatMessage and "Found" or "Missing", 4)
end})
GlobalTab:CreateButton({Name = "Send Plain-Text Test Shout", Callback = function()
    if not Remotes.SendTextChatMessage then healRemotes() end
    if not Remotes.SendTextChatMessage then notify("Chat Error", "Remote not found.", 4) return end
    local ok = pcall(function() Remotes.SendTextChatMessage:InvokeServer("V1400 test ping") end)
    notify("Test Shout", ok and "Sent" or "Failed", 3)
end})
GlobalTab:CreateButton({Name = "Send Full Rich-Text Test Shout", Callback = function()
    sendChatMessage("V1400 rich-text test")
    notify("Test Shout", "Rich-text attempt sent.", 3)
end})

-- ============================================================
-- TAB 3: APEX FARM ENGINE (the new hotness)
-- ============================================================
local FarmTab = Window:CreateTab("Apex Farm", 4483362458)

-- Mode selector — 4 modes
FarmTab:CreateDropdown({
    Name = "Farm Mode",
    Options = {
        "Legacy (15-line pump)",
        "Burst (server-friendly)",
        "MultiWorker (parallel)",
        "Smart (auto-tune)",
    },
    CurrentOption = "Smart (auto-tune)",
    Callback = function(v)
        local val = dropValue(v)
        if val:find("Legacy") then Config.FarmMode = "Legacy"
        elseif val:find("Burst") then Config.FarmMode = "Burst"
        elseif val:find("MultiWorker") then Config.FarmMode = "MultiWorker"
        else Config.FarmMode = "Smart" end
    end,
})

-- Speed multiplier
FarmTab:CreateDropdown({
    Name = "Speed Multiplier",
    Options = {"0.5x (Safe)", "1x (Default)", "2x (Aggressive)"},
    CurrentOption = "1x (Default)",
    Callback = function(v)
        local val = dropValue(v)
        if val:find("0.5") then Config.FarmSpeedMul = 0.5
        elseif val:find("2x") then Config.FarmSpeedMul = 2
        else Config.FarmSpeedMul = 1 end
    end,
})

-- Worker count slider (for MultiWorker mode)
FarmTab:CreateSlider({
    Name = "Worker Count (MultiWorker mode)",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = 5,
    Suffix = " workers",
    Callback = function(v) Config.WorkerCount = v end,
})

-- Anti-detect toggle
FarmTab:CreateToggle({
    Name = "Anti-Detect (random order + micro-delays)",
    CurrentValue = true,
    Callback = function(t) Config.AntiDetect = t end,
})

-- The big toggle — starts/stops the farm
FarmTab:CreateToggle({
    Name = "START APEX FARM",
    CurrentValue = false,
    Callback = function(t)
        Config.FarmEnabled = t
        if t then startFarm() else stopFarm() end
    end,
})

-- Turbo boost button
FarmTab:CreateButton({
    Name = "🚀 TURBO BOOST (2x for 10s, 5s cooldown)",
    Callback = function() setTurbo() end,
})

-- Live farm stats paragraph — shows power, gains/sec, session total
pcall(function()
    farmStatsParagraph = FarmTab:CreateParagraph({
        Title = "Live Power Tracker",
        Content = "Start the farm to begin tracking...",
    })
end)

-- Reset session button
FarmTab:CreateButton({
    Name = "Reset Session Stats",
    Callback = function()
        powerTracker.reset()
        notify("Session", "Stats reset.", 3)
    end,
})

-- Auto Respect Farm
FarmTab:CreateToggle({
    Name = "Auto Respect Farm",
    CurrentValue = false,
    Callback = function(t)
        Config.RespectFarm = t
        if not t then return end
        task.spawn(function()
            while Config.RespectFarm do
                for _, v in ipairs(Players:GetPlayers()) do
                    if v ~= player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                        local myChar = player.Character
                        if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                            safeCall("respect-farm", function()
                                myChar.HumanoidRootPart.CFrame =
                                    v.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                                if Remotes.ApplyCastAbility then
                                    Remotes.ApplyCastAbility:InvokeServer(v.Name, "1")
                                else
                                    healRemotes()
                                end
                            end)
                        end
                    end
                    task.wait(0.1)
                end
                task.wait(0.5)
            end
        end)
    end,
})

FarmTab:CreateButton({Name = "Force Re-scan Train Remotes", Callback = function()
    healRemotes()
    notify("Train Remotes",
        "Frenzy:" .. (Remotes.ApplyAddFrenzyValue and "Y" or "N") ..
        " Speed:" .. (Remotes.TrainSpeedHasChanged and "Y" or "N") ..
        " Mobile:" .. (Remotes.ApplyMobileTrain and "Y" or "N") ..
        " Stationary:" .. (Remotes.ApplyStationaryTrain and "Y" or "N"), 6)
end})

-- Live farm stats updater — reads PowerTracker every 1s
task.spawn(function()
    while task.wait(1) do
        if farmStatsParagraph then
            local power = powerTracker.tick()
            local gainsPerSec = powerTracker.avgGainsPerSec()
            local sessionTime = powerTracker.sessionStart > 0
                            and math.floor(tick() - powerTracker.sessionStart) or 0
            local trend = powerTracker.trend()
            local trendIcon = trend == "up" and "📈" or (trend == "down" and "📉" or "➡️")
            local turbo = Config.TurboActive and "🚀" or "  "
            local smartInfo = ""
            if Config.FarmMode == "Smart" then
                smartInfo = string.format("\nSmart workers: %d", smartWorkers or 3)
            end
            local content = string.format(
                "%s Power: %s\n%s Gains/sec: %s\nSession: %ds | Total: %s%s\nMode: %s | x%s | AntiDetect: %s",
                turbo, formatNumber(power),
                trendIcon, formatNumber(gainsPerSec),
                sessionTime, formatNumber(powerTracker.gainsThisSession), smartInfo,
                Config.FarmMode, Config.FarmSpeedMul,
                Config.AntiDetect and "ON" or "OFF"
            )
            pcall(function() farmStatsParagraph:Set({Content = content}) end)
        end
    end
end)

-- TAB 4: SPECTRAL SCAN — ESP
local VisTab = Window:CreateTab("Spectral Scan", 4483362458)
VisTab:CreateToggle({
    Name = "RezurXshin ESP (Power Scan) — RenderStepped",
    CurrentValue = false,
    Callback = function(t)
        Config.EspEnabled = t
        if not t then clearAllEspTags() return end
        espConn = RunService.RenderStepped:Connect(function()
            pcall(function()
                local creature   = workspace:FindFirstChild("Creature")
                local activation = creature and creature:FindFirstChild("Activation")
                if not activation then return end
                local seen = {}
                for _, obj in ipairs(activation:GetChildren()) do
                    for _, pMod in ipairs(obj:GetChildren()) do
                        local h = pMod:FindFirstChild("Head")
                        if h then
                            seen[h] = true
                            local entry = espCache[h]
                            local power = getPowerFor(pMod.Name)
                            if not entry then
                                local bb, label = makeEspTag(h, pMod.Name)
                                espCache[h] = { gui = bb, label = label, lastValue = power }
                            elseif entry.lastValue ~= power then
                                entry.label.Text = formatNumber(power)
                                entry.lastValue = power
                            end
                        end
                    end
                end
                for head, entry in pairs(espCache) do
                    if not seen[head] or not head.Parent then
                        if entry.gui then entry.gui:Destroy() end
                        espCache[head] = nil
                    end
                end
            end)
        end)
    end,
})
VisTab:CreateButton({Name = "Force Clear All ESP Tags",
    Callback = function() clearAllEspTags() notify("ESP", "All tags cleared.", 3) end})

-- TAB 5: PHYSICAL OVERRIDE
local LocalTab = Window:CreateTab("Physical Override", 4483362458)
LocalTab:CreateToggle({
    Name = "Override Walk/Jump Stats",
    CurrentValue = false,
    Callback = function(t)
        Config.OverrideStats = t
        if t then applyMovement() else restoreMovement() end
    end,
})
LocalTab:CreateSlider({Name = "WalkSpeed", Range = {16, 1000}, Increment = 1,
    CurrentValue = 16, Suffix = " Speed",
    Callback = function(v) Config.WalkSpeed = v applyMovement() end})
LocalTab:CreateSlider({Name = "JumpPower", Range = {50, 1000}, Increment = 1,
    CurrentValue = 50, Suffix = " Power",
    Callback = function(v) Config.JumpPower = v applyMovement() end})
LocalTab:CreateButton({Name = "Reset to Default (16 / 50)", Callback = function()
    Config.WalkSpeed = 16 Config.JumpPower = 50 restoreMovement()
    notify("Movement", "Reset to default 16/50.", 3)
end})

-- TAB 6: DARK EXPERIMENTS — V777 noclip preserved
local ExpTab = Window:CreateTab("Dark Experiments", 4483362458)
ExpTab:CreateToggle({Name = "Turn Off PVP", CurrentValue = false,
    Callback = function(t) Config.PvpOff = t end})
ExpTab:CreateToggle({Name = "Noclip (V777 mechanic — UNCHANGED)",
    CurrentValue = false, Callback = function(t) Config.Noclip = t end})
ExpTab:CreateToggle({Name = "Anti-AFK", CurrentValue = true,
    Callback = function(t) Config.AntiAfk = t end})

-- TAB 7: STATUS DASHBOARD
local StatusTab = Window:CreateTab("Status Dashboard", 4483362458)
pcall(function()
    liveStats = StatusTab:CreateParagraph({Title = "Live Stats", Content = "Loading..."})
end)

StatusTab:CreateButton({Name = "Show Full Remote Status", Callback = function()
    healRemotes()
    local report = string.format(
        "TRAIN: Frenzy:%s Speed:%s Mobile:%s Stationary:%s\nCHAT:%s\nCOMBAT:%s\nAREA:%s\nErrors logged: %d",
        Remotes.ApplyAddFrenzyValue and "Y" or "N",
        Remotes.TrainSpeedHasChanged and "Y" or "N",
        Remotes.ApplyMobileTrain and "Y" or "N",
        Remotes.ApplyStationaryTrain and "Y" or "N",
        Remotes.SendTextChatMessage and "Y" or "N",
        Remotes.ApplyCastAbility and "Y" or "N",
        Remotes.PlayerAreaIn and "Y" or "N",
        #ERR_LOG
    )
    notify("Remote Status", report, 12)
end})

StatusTab:CreateButton({Name = "Show Error Log (Last 5)", Callback = function()
    local n = #ERR_LOG
    if n == 0 then notify("Error Log", "No errors logged", 4) return end
    local lines = {}
    for i = math.max(1, n - 4), n do
        local e = ERR_LOG[i]
        if e then table.insert(lines, string.format("%s [%s] %s", e.timeStr, e.source, e.msg:sub(1, 80))) end
    end
    notify("Error Log (" .. n .. " total)", table.concat(lines, "\n"), 12)
end})

StatusTab:CreateButton({Name = "Clear Error Log", Callback = function()
    table.clear(ERR_LOG) notify("Error Log", "Cleared.", 3)
end})

StatusTab:CreateButton({Name = "Force Re-init ALL Remotes", Callback = function()
    healRemotes() notify("Remotes", "All remotes re-scanned.", 3)
end})

StatusTab:CreateButton({Name = "Destroy UI",
    Callback = function() pcall(Rayfield.Destroy, Rayfield) end})

end  -- closes `if Rayfield then`

-- ============================================================
-- CORE LOOPS
-- ============================================================

-- Movement re-apply (only when OverrideStats on AND values drifted)
RunService.Heartbeat:Connect(function()
    if not Config.OverrideStats then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hum.WalkSpeed ~= Config.WalkSpeed or hum.JumpPower ~= Config.JumpPower then
        hum.WalkSpeed    = Config.WalkSpeed
        hum.JumpPower    = Config.JumpPower
        hum.UseJumpPower = true
    end
end)

player.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum and Config.OverrideStats then
        task.wait(0.2)
        applyMovement()
    end
end)

-- ============================================================
-- V777 NOCLIP — UNCHANGED (Directive 1)
-- ============================================================
RunService.Stepped:Connect(function()
    if player.Character and Config.Noclip then
        for _, v in pairs(player.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

-- PvpOff area spam (nil-safe)
task.spawn(function()
    while task.wait(0.5) do
        if Config.PvpOff then
            safeCall("pvp-off", function()
                local areaRoot = workspace:FindFirstChild("Area")
                local playerArea = areaRoot and areaRoot:FindFirstChild("PlayerArea")
                local s2 = playerArea and playerArea:FindFirstChild("S2")
                if s2 and Remotes.PlayerAreaIn then
                    Remotes.PlayerAreaIn:InvokeServer(s2)
                elseif not Remotes.PlayerAreaIn then
                    healRemotes()
                end
            end)
        end
    end
end)

-- Anti-AFK
player.Idled:Connect(function()
    if not Config.AntiAfk then return end
    safeCall("anti-afk", function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- ============================================================
-- FPS meter + live stats updater (Rayfield UI)
-- ============================================================
if Rayfield and liveStats then
    task.spawn(function()
        while task.wait(1) do
            local players = #Players:GetPlayers()
            local trainActive = Config.FarmEnabled and "ON" or "OFF"
            local espActive = Config.EspEnabled and "ON" or "OFF"
            local noclipActive = Config.Noclip and "ON" or "OFF"
            local turbo = Config.TurboActive and "ON" or "OFF"
            local cdRemain = Config.TurboCooldownUntil > tick()
                            and math.ceil(Config.TurboCooldownUntil - tick()) or 0
            local content = string.format(
                "Players: %d\nFarm: %s (%s) | ESP: %s | Noclip: %s\nTurbo: %s | Errors: %d | AntiAfk: %s",
                players,
                trainActive, Config.FarmMode, espActive, noclipActive,
                Config.TurboActive and "ACTIVE" or (cdRemain > 0 and "CD " .. cdRemain .. "s" or "READY"),
                #ERR_LOG, Config.AntiAfk and "ON" or "OFF"
            )
            pcall(function() liveStats:Set({Content = content}) end)
        end
    end)
end

-- ============================================================
-- BOOT NOTIFY
-- ============================================================
notify("👑WELCOME DEVELOPER👑",
    "V1400🔥 APEX FARM loaded. 4 modes • Smart auto-tune • Power tracker. Press K to toggle.", 6)

end  -- end of runMain()

-- Run inside xpcall so any error shows on screen
local ok, err = xpcall(runMain, function(e)
    return debug.traceback(tostring(e), 2)
end)
if not ok then
    showErrorToUser(err)
end
