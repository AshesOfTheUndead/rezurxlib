--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  👑 RezurXLab | V2300🔥 ORION EDITION                        ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  Clean, reliable UI using Orion Library (with Rayfield       ║
    ║  fallback). All engine features from V2200 preserved:        ║
    ║    • Hybrid farm engine (MultiWorker + math.huge + adaptive) ║
    ║    • Self-healing remotes with exponential backoff           ║
    ║    • V777 + Improved noclip (no upward glitch on disable)    ║
    ║    • Overnight mode (5min/30s cycles, GC, FPS emergency)     ║
    ║    • Turbo boost (2x / 10s, 5s cooldown)                     ║
    ║    • Chat with color pickers, ESP, PVP Off, Anti-AFK         ║
    ║    • Error logging (100-entry ring buffer)                   ║
    ║    • Lua 5.1 compatible                                      ║
    ╚══════════════════════════════════════════════════════════════╝
]]

-- ============================================================
-- [FIX] TOP-LEVEL ERROR CATCHER — displays any uncaught error on screen
-- ============================================================
local function showErrorToUser(msg)
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local sg = Instance.new("ScreenGui")
        sg.Name = "V2000_Error"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
        sg.Parent = CoreGui
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 560, 0, 240)
        f.Position = UDim2.new(0.5, -280, 0.5, -120)
        f.BackgroundColor3 = Color3.fromRGB(35, 0, 0); f.Parent = sg
        local c = Instance.new("UICorner") c.CornerRadius = UDim2.new(0, 12, 0, 12) c.Parent = f
        local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(220, 30, 30) s.Thickness = 2 s.Parent = f
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -24, 1, -24); t.Position = UDim2.new(0, 12, 0, 12)
        t.BackgroundTransparency = 1; t.Font = Enum.Font.Code; t.TextSize = 13
        t.TextColor3 = Color3.fromRGB(255, 230, 230); t.TextWrapped = true
        t.TextXAlignment = Enum.TextXAlignment.Left; t.TextYAlignment = Enum.TextYAlignment.Top
        t.Text = "V2000 ERROR:\n\n" .. tostring(msg); t.Parent = f
        task.delay(30, function() pcall(function() sg:Destroy() end) end)
    end)
end

-- ============================================================
-- [FIX] ERROR LOG — 100-entry ring buffer (was 200, but capped for memory)
-- ============================================================
if not _G.__V2000_ERRORS then _G.__V2000_ERRORS = {} end
local ERR_LOG = _G.__V2000_ERRORS
local ERR_LOG_MAX = 100

local function logError(source, msg)
    local entry = {
        timeStr  = os.date("%H:%M:%S"),
        source   = tostring(source),
        msg      = tostring(msg):sub(1, 500),
        traceback = debug.traceback("", 2):sub(1, 400),
    }
    ERR_LOG[#ERR_LOG + 1] = entry
    if #ERR_LOG > ERR_LOG_MAX then table.remove(ERR_LOG, 1) end
    warn(string.format("[V2000] %s: %s", source, msg))
end

-- [FIX] safeCall with error logging — use everywhere instead of raw pcall
local function safeCall(source, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then logError(source, err) end
    return ok, err
end

-- ============================================================
-- MAIN — wrapped in xpcall
-- ============================================================
local function runMain()

if not game:IsLoaded() then
    repeat task.wait(0.1) until game:IsLoaded()
end

-- ============================================================
-- [ENHANCEMENT] SERVICES — all cached as locals (CPU reduction)
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local TweenService      = game:GetService("TweenService")
local StarterGui        = game:GetService("StarterGui")
local CoreGui           = game:GetService("CoreGui")
local player            = Players.LocalPlayer

-- ============================================================
-- [FIX] FORWARD DECLARATIONS — eliminates forward-reference crashes
-- ============================================================
local applyMovement, restoreMovement
local executePump, hybridDoTrain
local sendChatMessage
local initAllRemotes, healRemotes
local notify
local setTurbo
local startFarm, stopFarm
local startOvernight, stopOvernight
local setNoclipMode
local powerTracker
local Rayfield, Window

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    -- Identity
    CustomTag = "", UserName = "",
    TagColor = Color3.fromRGB(128, 0, 0),
    UserColor = Color3.fromRGB(255, 255, 255),
    MessageColor = Color3.fromRGB(255, 255, 255),
    -- Farm
    FarmMode = "Hybrid",     -- [ENHANCEMENT] Hybrid is the new default
    FarmEnabled = false,
    FarmSpeedMul = 1,
    WorkerCount = 5,
    TrainSpeedValue = "Infinity (math.huge)",
    -- Overnight
    OvernightEnabled = false,
    -- Movement
    OverrideStats = false,
    WalkSpeed = 16, JumpPower = 50,
    -- Noclip
    NoclipEnabled = false,
    NoclipMode = "Improved",
    -- Lab
    PvpOff = false,
    EspEnabled = false,
    -- Other
    AntiAfk = true,
    AntiDetect = true,
    -- Turbo
    TurboActive = false,
    TurboUntil = 0,
    TurboCooldownUntil = 0,
}

-- [ENHANCEMENT] HYBRID adaptive throttle state
local hybridState = {
    currentWorkers = 5,
    lastAdjust = 0,
    fpsHistory = {},
    responseTimes = {},     -- track InvokeServer durations
    consecutiveFailures = 0,
    emergencyMode = false,
}

-- ============================================================
-- [FIX] THEME — dark base + bright orange outlines (user-confirmed look)
-- ============================================================
local C = {
    bg       = Color3.fromRGB(13, 13, 18),
    panel    = Color3.fromRGB(28, 28, 40),     -- [FIX] brighter so sidebar is visible
    panelAlt = Color3.fromRGB(38, 38, 54),     -- [FIX] brighter than panel so tab buttons stand out
    accent   = Color3.fromRGB(255, 130, 35),
    accentDim= Color3.fromRGB(204, 100, 28),
    inputBg  = Color3.fromRGB(24, 24, 36),
    text     = Color3.fromRGB(240, 240, 250),
    muted    = Color3.fromRGB(150, 150, 175),
    green    = Color3.fromRGB(60, 210, 100),
    red      = Color3.fromRGB(220, 75, 75),
    border   = Color3.fromRGB(255, 130, 35),  -- ORANGE outlines
    white    = Color3.fromRGB(255, 255, 255),
    sidebar  = Color3.fromRGB(20, 20, 30),
    tabActive= Color3.fromRGB(255, 130, 35),
    tabHover = Color3.fromRGB(52, 52, 72),
    track    = Color3.fromRGB(52, 52, 72),
}

local TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_FAST = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ============================================================
-- HELPERS
-- ============================================================
local function dropValue(v)
    if typeof(v) == "table" then return v[1] or "" end
    return tostring(v)
end

-- [FIX] Lua 5.1 compat: unpack shim
local unpack = unpack or table.unpack

local function formatNumber(n)
    local s = {
        {1e33,"De"},{1e30,"No"},{1e27,"Oc"},{1e24,"Sp"},{1e21,"Sx"},
        {1e18,"Qi"},{1e15,"Qa"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"},
    }
    for _, v in ipairs(s) do
        if n >= v[1] then return string.format("%.2f%s", n / v[1], v[2]) end
    end
    return tostring(n)
end

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 12)
    c.Parent = parent
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or C.border
    s.Thickness = thickness or 1.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
end

local function gradient(parent, colorSeq, rot)
    local g = Instance.new("UIGradient")
    g.Color = colorSeq
    g.Rotation = rot or 90
    g.Parent = parent
end

-- ============================================================
-- [FIX] REMOTE MANAGER — self-healing with exponential backoff + mutex
-- ============================================================
local Remotes = {}
local remoteMutex = false          -- [FIX] prevents re-init collision
local consecutiveHealFailures = 0  -- [FIX] exponential backoff tracker
local lastHealTime = 0

initAllRemotes = function()
    -- [FIX] mutex — don't re-init while another re-init is running
    if remoteMutex then return end
    remoteMutex = true
    pcall(function()
        local tsRoot = ReplicatedStorage:FindFirstChild("TrainSystem")
        local tsRem = tsRoot and tsRoot:FindFirstChild("Remote")
        if tsRem then
            Remotes.ApplyAddFrenzyValue  = tsRem:FindFirstChild("ApplyAddFrenzyValue")
            Remotes.TrainSpeedHasChanged = tsRem:FindFirstChild("TrainSpeedHasChanged")
        end
        local teRoot = ReplicatedStorage:FindFirstChild("TrainEquipment")
        local teRem = teRoot and teRoot:FindFirstChild("Remote")
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
    remoteMutex = false
end
healRemotes = initAllRemotes
initAllRemotes()

-- [FIX] healRemotesWithBackoff — exponential backoff to prevent spam
local function healRemotesWithBackoff()
    local now = tick()
    -- [FIX] exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s cap
    local backoff = math.min(30, 2 ^ consecutiveHealFailures)
    if now - lastHealTime < backoff then return end
    lastHealTime = now
    initAllRemotes()
    -- [FIX] check if heal succeeded (any critical remote exists)
    if Remotes.ApplyAddFrenzyValue then
        consecutiveHealFailures = 0
    else
        consecutiveHealFailures = consecutiveHealFailures + 1
        if consecutiveHealFailures > 5 then
            logError("remote-heal", "5 consecutive failures — giving up gracefully")
        end
    end
end

-- [FIX] Periodic re-init every 30s (mutex-safe, won't collide with calls)
task.spawn(function()
    while task.wait(30) do safeCall("periodic-init", initAllRemotes) end
end)

-- ============================================================
-- [FIX] SAFE REMOTE WRAPPERS — track response time + auto-heal
-- ============================================================
local function safeInvokeTracked(remote, ...)
    if not remote then healRemotesWithBackoff() return nil end
    local t0 = tick()
    local ok, result = pcall(remote.InvokeServer, remote, ...)
    local dt = tick() - t0
    -- [ENHANCEMENT] track response time for adaptive throttle
    if dt > 0.001 then
        table.insert(hybridState.responseTimes, dt * 1000)  -- ms
        if #hybridState.responseTimes > 20 then table.remove(hybridState.responseTimes, 1) end
    end
    if not ok then
        logError("InvokeServer", "failed, healing")
        healRemotesWithBackoff()
        return nil
    end
    return result
end

local function safeFireTracked(remote, ...)
    if not remote then healRemotesWithBackoff() return end
    local ok = pcall(remote.FireServer, remote, ...)
    if not ok then
        logError("FireServer", "failed, healing")
        healRemotesWithBackoff()
    end
end

-- ============================================================
-- POWER TRACKER
-- ============================================================
powerTracker = {
    sessionStart = 0, sessionStartPower = 0,
    lastTickTime = 0, lastTickPower = 0,
    gainsPerSec = 0, gainsThisSession = 0,
    samples = {},
}

function powerTracker.readPower()
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
    powerTracker.sessionStart = tick()
    powerTracker.sessionStartPower = powerTracker.readPower()
    powerTracker.lastTickTime = tick()
    powerTracker.lastTickPower = powerTracker.sessionStartPower
    powerTracker.gainsThisSession = 0
    powerTracker.samples = {}
end

function powerTracker.tick()
    local now = tick()
    local power = powerTracker.readPower()
    local dt = now - powerTracker.lastTickTime
    if dt > 0 then
        local delta = power - powerTracker.lastTickPower
        powerTracker.gainsPerSec = delta / dt
        powerTracker.gainsThisSession = powerTracker.gainsThisSession + delta
        table.insert(powerTracker.samples, powerTracker.gainsPerSec)
        if #powerTracker.samples > 10 then table.remove(powerTracker.samples, 1) end
    end
    powerTracker.lastTickTime = now
    powerTracker.lastTickPower = power
    return power
end

function powerTracker.avgGainsPerSec()
    local sum = 0
    for _, v in ipairs(powerTracker.samples) do sum = sum + v end
    return #powerTracker.samples > 0 and (sum / #powerTracker.samples) or 0
end

function powerTracker.trend()
    if #powerTracker.samples < 4 then return "flat" end
    local recent, older = 0, 0
    local half = math.floor(#powerTracker.samples / 2)
    for i = 1, half do older = older + powerTracker.samples[i] end
    for i = half + 1, #powerTracker.samples do recent = recent + powerTracker.samples[i] end
    older = older / half
    recent = recent / (#powerTracker.samples - half)
    if recent > older * 1.15 then return "up" end
    if recent < older * 0.85 then return "down" end
    return "flat"
end

function powerTracker.reset() powerTracker.startSession() end

-- ============================================================
-- [ENHANCEMENT] HYBRID FARM ENGINE — MultiWorker V2 + math.huge + adaptive
-- ============================================================
-- Default: math.huge (user-confirmed max gains). Dropdown lets user switch.
local TRAIN_SPEED = math.huge

local function getTrainSpeed()
    -- [FIX] re-read from Config so dropdown changes take effect immediately
    local v = Config.TrainSpeedValue
    if v:find("Infinity") then return math.huge
    elseif v:find("1e9") then return 1e9
    elseif v:find("1e15") then return 1e15
    elseif v:find("1e18") then return 1e18
    elseif v:find("1e30") then return 1e30
    else return math.huge end
end

-- [FIX] executePump — all 15 calls, anti-detect shuffles ORDER (not which calls)
-- The shuffle preserves the call SET (15 calls) but randomizes order.
-- This breaks deterministic patterns without breaking the pump logic.
executePump = function(speed)
    if not Remotes.ApplyAddFrenzyValue then healRemotesWithBackoff() end
    if not Remotes.ApplyAddFrenzyValue then return end
    local r = Remotes
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
    -- [FIX] anti-detect: shuffle order (preserves all 15 calls)
    if Config.AntiDetect then shuffle(calls) end
    for _, c in ipairs(calls) do
        if c.remote then
            if c.func == "Invoke" then
                pcall(c.remote.InvokeServer, c.remote, unpack(c.args))
            else
                pcall(c.remote.FireServer, c.remote, unpack(c.args))
            end
        end
        -- [FIX] micro-delay: 30% chance of 0-3ms (anti-detect, won't kill throughput)
        if Config.AntiDetect and math.random() < 0.3 then
            task.wait(math.random() * 0.003)
        end
    end
end

-- [ENHANCEMENT] HYBRID mode — persistent workers + adaptive throttle
-- Generation counter ensures clean shutdown.
local workerGeneration = 0
local activeWorkers = 0

local function spawnWorkers(n)
    workerGeneration = workerGeneration + 1
    local gen = workerGeneration
    activeWorkers = n
    for i = 1, n do
        local workerId = i
        task.spawn(function()
            -- [FIX] staggered start: each worker offset 5ms
            task.wait((workerId - 1) * 0.005)
            while gen == workerGeneration and Config.FarmEnabled do
                local speed = getTrainSpeed()
                -- [FIX] emergency mode: drop to finite speed
                if hybridState.emergencyMode then
                    speed = 1e9
                end
                pcall(executePump, speed)
                -- [FIX] staggered yield: spreads load across frame
                local baseWait = 0.05
                local stagger = (workerId * 0.003) % 0.02
                task.wait(baseWait + stagger)
            end
        end)
    end
end

local function killWorkers()
    workerGeneration = workerGeneration + 1
    activeWorkers = 0
end

-- [ENHANCEMENT] Adaptive throttle — runs every 2s, adjusts worker count
local adaptiveConn = nil
local function startAdaptiveThrottle()
    if adaptiveConn then adaptiveConn:Disconnect() end
    adaptiveConn = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - hybridState.lastAdjust < 2 then return end
        hybridState.lastAdjust = now

        -- [FIX] measure FPS (0.5s window)
        local fpsT0 = tick()
        local fpsCount = 0
        local fc = RunService.Heartbeat:Connect(function() fpsCount = fpsCount + 1 end)
        task.wait(0.5)
        fc:Disconnect()
        local fps = math.floor(fpsCount / 0.5)
        table.insert(hybridState.fpsHistory, fps)
        if #hybridState.fpsHistory > 5 then table.remove(hybridState.fpsHistory, 1) end
        local avgFps = 0
        for _, v in ipairs(hybridState.fpsHistory) do avgFps = avgFps + v end
        avgFps = avgFps / #hybridState.fpsHistory

        -- [FIX] average server response time
        local avgResponse = 0
        if #hybridState.responseTimes > 0 then
            for _, v in ipairs(hybridState.responseTimes) do avgResponse = avgResponse + v end
            avgResponse = avgResponse / #hybridState.responseTimes
        end

        local trend = powerTracker.trend()
        local oldWorkers = hybridState.currentWorkers

        -- [ENHANCEMENT] Decision matrix:
        -- Emergency: FPS < 15 → 1 worker + finite speed
        if avgFps < 15 then
            hybridState.emergencyMode = true
            hybridState.currentWorkers = 1
            logError("adaptive", "EMERGENCY: FPS " .. avgFps .. " → 1 worker, finite speed")
        -- Critical: FPS < 25 → reduce workers
        elseif avgFps < 25 then
            hybridState.emergencyMode = false
            hybridState.currentWorkers = math.max(1, hybridState.currentWorkers - 1)
            logError("adaptive", "FPS low " .. avgFps .. " → " .. hybridState.currentWorkers .. " workers")
        -- Server slow: response > 150ms → reduce workers
        elseif avgResponse > 150 then
            hybridState.emergencyMode = false
            hybridState.currentWorkers = math.max(1, hybridState.currentWorkers - 1)
            logError("adaptive", "Response slow " .. math.floor(avgResponse) .. "ms → " .. hybridState.currentWorkers .. " workers")
        -- Gains down + workers > 2 → reduce
        elseif trend == "down" and hybridState.currentWorkers > 2 then
            hybridState.emergencyMode = false
            hybridState.currentWorkers = hybridState.currentWorkers - 1
        -- All good + headroom → add workers
        elseif trend == "up" and avgFps > 50 and avgResponse < 80 and hybridState.currentWorkers < 20 then
            hybridState.emergencyMode = false
            hybridState.currentWorkers = hybridState.currentWorkers + 1
        -- Plateau + headroom → try more workers
        elseif trend == "flat" and avgFps > 50 and avgResponse < 100 and hybridState.currentWorkers < 15 then
            hybridState.emergencyMode = false
            hybridState.currentWorkers = hybridState.currentWorkers + 1
        end

        -- [FIX] if worker count changed, restart workers
        if hybridState.currentWorkers ~= oldWorkers and Config.FarmEnabled and Config.FarmMode == "Hybrid" then
            killWorkers()
            task.wait(0.05)
            spawnWorkers(hybridState.currentWorkers)
        end
    end)
end

local function stopAdaptiveThrottle()
    if adaptiveConn then adaptiveConn:Disconnect() adaptiveConn = nil end
end

-- ============================================================
-- FARM CONTROLLER
-- ============================================================
local farmConn = nil

startFarm = function()
    if farmConn then farmConn:Disconnect() farmConn = nil end
    stopAdaptiveThrottle()
    powerTracker.startSession()

    if Config.FarmMode == "Hybrid" then
        -- [ENHANCEMENT] HYBRID: persistent workers + adaptive throttle
        hybridState.currentWorkers = math.max(1, math.min(20, Config.WorkerCount * Config.FarmSpeedMul))
        if Config.TurboActive then hybridState.currentWorkers = math.min(20, hybridState.currentWorkers * 2) end
        hybridState.emergencyMode = false
        hybridState.fpsHistory = {}
        hybridState.responseTimes = {}
        spawnWorkers(hybridState.currentWorkers)
        startAdaptiveThrottle()
    else
        -- Legacy / other modes: single Heartbeat pump
        farmConn = RunService.Heartbeat:Connect(function()
            safeCall("farm-" .. Config.FarmMode, function()
                local speed = getTrainSpeed()
                pcall(executePump, speed)
            end)
        end)
    end
end

stopFarm = function()
    if farmConn then farmConn:Disconnect() farmConn = nil end
    stopAdaptiveThrottle()
    killWorkers()
end

-- ============================================================
-- OVERNIGHT MODE
-- ============================================================
local overnightConn = nil
local overnightPhase = "idle"
local overnightOriginal = {}

startOvernight = function()
    if overnightConn then return end
    overnightOriginal.FarmMode = Config.FarmMode
    overnightOriginal.WorkerCount = Config.WorkerCount
    overnightOriginal.AntiDetect = Config.AntiDetect
    overnightOriginal.TrainSpeedValue = Config.TrainSpeedValue
    -- [FIX] force safe settings for overnight
    Config.FarmMode = "Hybrid"
    Config.WorkerCount = 3
    Config.AntiDetect = true
    Config.TrainSpeedValue = "Infinity (math.huge)"
    Config.TurboActive = false
    Config.TurboUntil = 0
    Config.FarmEnabled = true
    startFarm()
    overnightPhase = "work"
    logError("overnight", "Started — 5min work / 30s break cycles")
    local cycleStart = tick()
    local WORK_DUR = 300
    local BREAK_DUR = 30
    local lastFpsCheck = tick()
    local fpsLowStreak = 0
    overnightConn = RunService.Heartbeat:Connect(function()
        local now = tick()
        -- [FIX] FPS emergency check every 5s
        if now - lastFpsCheck >= 5 then
            lastFpsCheck = now
            local fpsT0 = tick()
            local fpsCount = 0
            local fc = RunService.Heartbeat:Connect(function() fpsCount = fpsCount + 1 end)
            task.wait(0.5)
            fc:Disconnect()
            local fps = math.floor(fpsCount / 0.5)
            if fps < 15 then
                fpsLowStreak = fpsLowStreak + 1
                if fpsLowStreak >= 2 and overnightPhase ~= "emergency" then
                    overnightPhase = "emergency"
                    killWorkers()
                    logError("overnight", "FPS emergency — pausing 2min")
                    task.delay(120, function()
                        if Config.OvernightEnabled then
                            overnightPhase = "work"
                            cycleStart = tick()
                            spawnWorkers(3)
                            logError("overnight", "Resumed after emergency")
                        end
                    end)
                end
            else
                fpsLowStreak = 0
            end
        end
        -- [FIX] cycle management
        if overnightPhase == "work" and now - cycleStart >= WORK_DUR then
            overnightPhase = "break"
            killWorkers()
            collectgarbage("collect")  -- [FIX] GC during breaks
            logError("overnight", "Break — GC + 30s rest")
            task.delay(BREAK_DUR, function()
                if Config.OvernightEnabled then
                    overnightPhase = "work"
                    cycleStart = tick()
                    spawnWorkers(3)
                    logError("overnight", "Work cycle resumed")
                end
            end)
        end
    end)
end

stopOvernight = function()
    if overnightConn then overnightConn:Disconnect() overnightConn = nil end
    -- [FIX] restore original settings
    Config.FarmMode = overnightOriginal.FarmMode or "Hybrid"
    Config.WorkerCount = overnightOriginal.WorkerCount or 5
    Config.AntiDetect = overnightOriginal.AntiDetect ~= nil and overnightOriginal.AntiDetect or true
    Config.TrainSpeedValue = overnightOriginal.TrainSpeedValue or "Infinity (math.huge)"
    Config.TurboActive = false
    Config.FarmEnabled = false
    stopFarm()
    overnightPhase = "idle"
    logError("overnight", "Stopped — settings restored")
end

-- ============================================================
-- TURBO BOOST
-- ============================================================
local TURBO_DUR = 10
local TURBO_CD = 5
setTurbo = function()
    if Config.OvernightEnabled then
        notify("Turbo", "Disabled in Overnight mode", 3)
        return
    end
    local now = tick()
    if Config.TurboActive then notify("Turbo", "Already active!", 3) return end
    if now < Config.TurboCooldownUntil then
        notify("Turbo Cooldown", "Wait " .. math.ceil(Config.TurboCooldownUntil - now) .. "s", 3)
        return
    end
    Config.TurboActive = true
    Config.TurboUntil = now + TURBO_DUR
    notify("TURBO", "2x farming for 10s!", 3)
    -- [FIX] if Hybrid running, restart with doubled workers
    if Config.FarmMode == "Hybrid" and Config.FarmEnabled then
        killWorkers()
        task.wait(0.05)
        local n = math.min(20, hybridState.currentWorkers * 2)
        spawnWorkers(n)
    end
    task.spawn(function()
        while Config.TurboActive and tick() < Config.TurboUntil do
            task.wait(0.5)
        end
        Config.TurboActive = false
        Config.TurboCooldownUntil = tick() + TURBO_CD
        -- [FIX] restart with normal count
        if Config.FarmMode == "Hybrid" and Config.FarmEnabled then
            killWorkers()
            task.wait(0.05)
            spawnWorkers(hybridState.currentWorkers)
        end
        notify("Turbo End", "Cooldown 5s", 3)
    end)
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
    if not Remotes.SendTextChatMessage then healRemotesWithBackoff() end
    if not Remotes.SendTextChatMessage or not msg or msg == "" then return end
    local full = buildChatMessage(msg)
    -- [FIX] try table format, fall back to plain string
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
    hum.WalkSpeed = Config.WalkSpeed
    hum.JumpPower = Config.JumpPower
    hum.UseJumpPower = true
end

restoreMovement = function()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
end

-- ============================================================
-- [FIX] NOCLIP — V777 Simple + Improved (respawn-safe)
-- ============================================================
local noclipConn = nil
local noclipCharConn = nil  -- [FIX] CharacterAdded reconnect

setNoclipMode = function(enabled)
    Config.NoclipEnabled = enabled
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if noclipCharConn then noclipCharConn:Disconnect() noclipCharConn = nil end
    if not enabled then
        -- [FIX] DO NOT restore CanCollide on disable!
        -- Restoring CanCollide=true on parts currently overlapping terrain
        -- causes the physics engine to violently push the character upward.
        -- Instead, just stop the Stepped loop. The game's natural physics
        -- will handle collisions — when the character moves to a clear area,
        -- parts will collide normally again. New parts spawned (respawn, etc)
        -- will have CanCollide=true by default.
        return
    end
    local function startNoclip()
        if Config.NoclipMode == "V777" then
            -- [FIX] V777 EXACT: touch every BasePart every Stepped
            noclipConn = RunService.Stepped:Connect(function()
                local char = player.Character
                if char then
                    for _, v in pairs(char:GetDescendants()) do
                        if v:IsA("BasePart") then v.CanCollide = false end
                    end
                end
            end)
        else
            -- [FIX] IMPROVED: skip already-non-collide, skip HRP
            noclipConn = RunService.Stepped:Connect(function()
                local char = player.Character
                if not char then return end
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide and v.Name ~= "HumanoidRootPart" then
                        v.CanCollide = false
                    end
                end
            end)
        end
    end
    startNoclip()
    -- [FIX] reconnect on respawn
    noclipCharConn = player.CharacterAdded:Connect(function()
        task.wait(0.3)  -- wait for character to fully load
        if Config.NoclipEnabled then
            if noclipConn then noclipConn:Disconnect() noclipConn = nil end
            startNoclip()
        end
    end)
end

-- ============================================================
-- [NEW] ORION LIBRARY LOADER — with Rayfield fallback
-- Tries Orion first (cleaner look), falls back to Rayfield if Orion fails.
-- ============================================================
local UI_LIB = nil  -- "Orion" or "Rayfield"
local Window = nil

-- Orion hosts (try multiple in case one is down)
local ORION_HOSTS = {
    "https://raw.githubusercontent.com/dawid-scripts/Orion/main/source.lua",
    "https://github.com/dawid-scripts/Orion/raw/main/source.lua",
}

-- Rayfield hosts (fallback)
local RAYFIELD_HOSTS = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
}

local function tryLoad(hosts)
    for _, url in ipairs(hosts) do
        local okHttp, src = pcall(function() return game:HttpGet(url) end)
        if okHttp and src and #src > 100 then
            local okLoad, fn = pcall(function() return loadstring(src) end)
            if okLoad and fn then
                local okCall, lib = pcall(fn)
                if okCall and lib then return lib end
            end
        end
    end
    return nil
end

-- Try Orion first
local OrionLib = tryLoad(ORION_HOSTS)
if OrionLib and OrionLib.MakeWindow then
    UI_LIB = "Orion"
    warn("[V2300] Orion Library loaded")
else
    -- Fall back to Rayfield
    OrionLib = nil
    local Rayfield = tryLoad(RAYFIELD_HOSTS)
    if Rayfield and Rayfield.CreateWindow then
        UI_LIB = "Rayfield"
        OrionLib = Rayfield  -- use same variable name for unified API
        warn("[V2300] Rayfield loaded (Orion failed, falling back)")
    else
        -- Last resort: minimal native UI
        UI_LIB = "Native"
        warn("[V2300] All UI libraries failed — using native notifications only")
    end
end

-- Unified notify function
local function notify(title, content, duration)
    if UI_LIB == "Orion" then
        pcall(function()
            OrionLib:MakeNotification({
                Name = title or "V2300",
                Content = content or "",
                Image = "rbxassetid://4483362458",
                Time = duration or 5,
            })
        end)
    elseif UI_LIB == "Rayfield" then
        pcall(function()
            OrionLib:Notify({
                Title = title or "V2300",
                Content = content or "",
                Duration = duration or 5,
            })
        end)
    else
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = title or "V2300",
                Text = content or "",
                Duration = duration or 5,
            })
        end)
    end
end

-- Expose notify globally for the rest of the script
notify = notify

-- ============================================================
-- BUILD UI
-- ============================================================
if UI_LIB == "Orion" then
    -- ============================================================
    -- ORION UI BUILD
    -- ============================================================
    Window = OrionLib:MakeWindow({
        Name = "RezurXLab V2300 | Orion",
        HidePremium = false,
        SaveConfig = false,
        ConfigFolder = "RezurXLab"
    })

    -- ── TAB 1: FARM ──
    local FarmTab = Window:MakeTab({ Name = "Farm", Icon = "rbxassetid://4483362458", PremiumOnly = false })
    FarmTab:AddSection({ Name = "Hybrid Apex Engine" })
    FarmTab:AddDropdown({
        Name = "Mode",
        Default = "Hybrid (recommended)",
        Options = {"Hybrid (recommended)", "Legacy"},
        Callback = function(v)
            Config.FarmMode = v:find("Hybrid") and "Hybrid" or "Legacy"
            if Config.FarmEnabled then
                stopFarm()
                task.wait(0.1)
                startFarm()
            end
        end
    })
    FarmTab:AddDropdown({
        Name = "Speed Value",
        Default = "Infinity (math.huge)",
        Options = {"Infinity (math.huge)", "1e9 (safe)", "1e15 (very large)", "1e18 (extreme)", "1e30 (max finite)"},
        Callback = function(v) Config.TrainSpeedValue = v end
    })
    FarmTab:AddSlider({
        Name = "Workers",
        Min = 1, Max = 20, Default = 5, Increment = 1,
        Callback = function(v)
            Config.WorkerCount = v
            if Config.FarmEnabled and Config.FarmMode == "Hybrid" then
                killWorkers()
                local n = math.max(1, math.min(20, v * Config.FarmSpeedMul))
                if Config.TurboActive then n = math.min(20, n * 2) end
                hybridState.currentWorkers = n
                spawnWorkers(n)
            end
        end
    })
    FarmTab:AddDropdown({
        Name = "Speed Multiplier",
        Default = "1x",
        Options = {"0.5x", "1x", "2x"},
        Callback = function(v)
            if v == "0.5x" then Config.FarmSpeedMul = 0.5
            elseif v == "2x" then Config.FarmSpeedMul = 2
            else Config.FarmSpeedMul = 1 end
        end
    })
    FarmTab:AddToggle({
        Name = "Anti-Detect",
        Default = true,
        Callback = function(t) Config.AntiDetect = t end
    })
    FarmTab:AddToggle({
        Name = "START FARM",
        Default = false,
        Callback = function(t)
            Config.FarmEnabled = t
            if t then startFarm() else stopFarm() end
        end
    })
    FarmTab:AddButton({
        Name = "TURBO BOOST (2x / 10s)",
        Callback = function() setTurbo() end
    })
    FarmTab:AddSection({ Name = "Overnight Mode" })
    FarmTab:AddToggle({
        Name = "Overnight (5min on / 30s off)",
        Default = false,
        Callback = function(t)
            Config.OvernightEnabled = t
            if t then startOvernight() else stopOvernight() end
        end
    })
    FarmTab:AddSection({ Name = "Live Stats" })
    local statsParagraph = FarmTab:AddParagraph({ Name = "Power Tracker", Content = "Start farm to begin..." })

    -- ── TAB 2: MOVEMENT ──
    local MoveTab = Window:MakeTab({ Name = "Movement", Icon = "rbxassetid://4483362458", PremiumOnly = false })
    MoveTab:AddSection({ Name = "Walk / Jump" })
    local overrideToggle = MoveTab:AddToggle({
        Name = "Override Stats",
        Default = false,
        Callback = function(t)
            Config.OverrideStats = t
            if t then applyMovement() else restoreMovement() end
        end
    })
    local walkSlider = MoveTab:AddSlider({
        Name = "WalkSpeed",
        Min = 16, Max = 1000, Default = 16, Increment = 1,
        Callback = function(v) Config.WalkSpeed = v; applyMovement() end
    })
    local jumpSlider = MoveTab:AddSlider({
        Name = "JumpPower",
        Min = 50, Max = 1000, Default = 50, Increment = 1,
        Callback = function(v) Config.JumpPower = v; applyMovement() end
    })
    MoveTab:AddButton({
        Name = "Reset (16 / 50)",
        Callback = function()
            Config.WalkSpeed = 16
            Config.JumpPower = 50
            Config.OverrideStats = false
            -- Orion toggles/sliders don't have Set, so just restore movement
            restoreMovement()
            notify("Movement", "Reset to 16/50. Toggle Override OFF manually.", 4)
        end
    })
    MoveTab:AddSection({ Name = "Noclip" })
    MoveTab:AddDropdown({
        Name = "Mode",
        Default = "Improved",
        Options = {"V777 (Simple)", "Improved"},
        Callback = function(v)
            Config.NoclipMode = v:find("V777") and "V777" or "Improved"
            if Config.NoclipEnabled then
                setNoclipMode(false)
                task.wait(0.05)
                setNoclipMode(true)
            end
        end
    })
    MoveTab:AddToggle({
        Name = "Noclip",
        Default = false,
        Callback = function(t) setNoclipMode(t) end
    })

    -- ── TAB 3: IDENTITY ──
    local IdTab = Window:MakeTab({ Name = "Identity", Icon = "rbxassetid://4483362458", PremiumOnly = false })
    IdTab:AddSection({ Name = "Chat Identity Setup" })
    IdTab:AddDropdown({
        Name = "Title",
        Default = "None",
        Options = {"GLOBAL", "SERVER ANNOUNCEMENT", "👑Head Administrator👑", "👑Head Executive Lead Developer👑", "None"},
        Callback = function(v) Config.CustomTag = (v == "None" or v == "") and "" or v end
    })
    IdTab:AddDropdown({
        Name = "Username",
        Default = "None",
        Options = {"RezurXshin☑️", "Jandel", "Administrator", "None"},
        Callback = function(v) Config.UserName = (v == "None" or v == "") and "" or v end
    })
    IdTab:AddTextBox({
        Name = "Custom Title",
        Default = "",
        TextDisappear = false,
        Callback = function(v) Config.CustomTag = v or "" end
    })
    IdTab:AddTextBox({
        Name = "Custom Name",
        Default = "",
        TextDisappear = false,
        Callback = function(v) Config.UserName = v or "" end
    })
    IdTab:AddColorPicker({
        Name = "Title / Tag Color",
        Default = Config.TagColor,
        Callback = function(v) Config.TagColor = v end
    })
    IdTab:AddColorPicker({
        Name = "User Name Color",
        Default = Config.UserColor,
        Callback = function(v) Config.UserColor = v end
    })
    IdTab:AddColorPicker({
        Name = "Message Text Color",
        Default = Config.MessageColor,
        Callback = function(v) Config.MessageColor = v end
    })

    -- ── TAB 4: CHAT ──
    local ChatTab = Window:MakeTab({ Name = "Chat", Icon = "rbxassetid://4483362458", PremiumOnly = false })
    ChatTab:AddSection({ Name = "Ghost Shout" })
    ChatTab:AddTextBox({
        Name = "Message (type then click Send)",
        Default = "",
        TextDisappear = false,
        Callback = function(v)
            -- Orion TextBox fires on Enter or focus lost
            if v and v ~= "" then
                sendChatMessage(v)
                notify("Shout Sent", v:sub(1, 40), 3)
            end
        end
    })
    ChatTab:AddButton({
        Name = "Send Plain-Text Test",
        Callback = function()
            if not Remotes.SendTextChatMessage then healRemotesWithBackoff() end
            if not Remotes.SendTextChatMessage then notify("Chat", "Remote not found", 4) return end
            local ok = pcall(function() Remotes.SendTextChatMessage:InvokeServer("V2300 test ping") end)
            notify("Test", ok and "Sent" or "Failed", 3)
        end
    })
    ChatTab:AddButton({
        Name = "Re-scan Chat Remote",
        Callback = function()
            healRemotesWithBackoff()
            notify("Chat", Remotes.SendTextChatMessage and "Found" or "Missing", 4)
        end
    })

    -- ── TAB 5: LAB ──
    local LabTab = Window:MakeTab({ Name = "Lab", Icon = "rbxassetid://4483362458", PremiumOnly = false })
    LabTab:AddSection({ Name = "Experimental Tools" })
    LabTab:AddToggle({
        Name = "Anti-AFK",
        Default = true,
        Callback = function(t) Config.AntiAfk = t end
    })
    LabTab:AddToggle({
        Name = "PVP Off",
        Default = false,
        Callback = function(t) Config.PvpOff = t end
    })
    LabTab:AddSection({ Name = "Spectral Scan (ESP)" })
    local espCache = {}
    local espConn = nil
    local function clearAllEspTags()
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
    LabTab:AddToggle({
        Name = "ESP (Power Scan)",
        Default = false,
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
        end
    })
    LabTab:AddButton({
        Name = "Clear All ESP Tags",
        Callback = function() clearAllEspTags() notify("ESP", "All tags cleared", 3) end
    })

    -- ── TAB 6: SYSTEM ──
    local SysTab = Window:MakeTab({ Name = "System", Icon = "rbxassetid://4483362458", PremiumOnly = false })
    SysTab:AddSection({ Name = "Remote Status" })
    SysTab:AddButton({
        Name = "Show Remote Status",
        Callback = function()
            healRemotesWithBackoff()
            notify("Remotes",
                "Frenzy:" .. (Remotes.ApplyAddFrenzyValue and "Y" or "N") ..
                " Speed:" .. (Remotes.TrainSpeedHasChanged and "Y" or "N") ..
                " Mobile:" .. (Remotes.ApplyMobileTrain and "Y" or "N") ..
                " Stationary:" .. (Remotes.ApplyStationaryTrain and "Y" or "N") ..
                " Chat:" .. (Remotes.SendTextChatMessage and "Y" or "N"), 10)
        end
    })
    SysTab:AddButton({
        Name = "Re-init All Remotes",
        Callback = function() healRemotesWithBackoff() notify("Remotes", "Re-scanned", 3) end
    })
    SysTab:AddSection({ Name = "Error Log (last 100)" })
    SysTab:AddButton({
        Name = "Show Last 10 Errors",
        Callback = function()
            local n = #ERR_LOG
            if n == 0 then notify("Errors", "No errors logged", 4) return end
            local lines = {}
            for i = math.max(1, n - 9), n do
                local e = ERR_LOG[i]
                if e then table.insert(lines, string.format("%s [%s] %s", e.timeStr, e.source, e.msg:sub(1, 60))) end
            end
            notify("Errors (" .. n .. " total)", table.concat(lines, "\n"), 12)
        end
    })
    SysTab:AddButton({
        Name = "Clear Error Log",
        Callback = function() table.clear(ERR_LOG) notify("Errors", "Cleared", 3) end
    })
    SysTab:AddSection({ Name = "UI" })
    SysTab:AddButton({
        Name = "Destroy UI",
        Callback = function() pcall(function() OrionLib:Destroy() end) end
    })

    -- Live stats updater
    task.spawn(function()
        while task.wait(1) do
            local power = powerTracker.tick()
            local gains = powerTracker.avgGainsPerSec()
            local trend = powerTracker.trend()
            local trendIcon = trend == "up" and "↑" or (trend == "down" and "↓" or "→")
            local sessionTime = powerTracker.sessionStart > 0
                            and math.floor(tick() - powerTracker.sessionStart) or 0
            local turbo = Config.TurboActive and "🚀" or ""
            local overnight = Config.OvernightEnabled and "🌙" or ""
            local emergency = hybridState.emergencyMode and "⚠️" or ""
            local content = string.format(
                "%s%s%s Power: %s\n%s Gains/s: %s\nSession: %ds | Total: %s\nWorkers: %d | Mode: %s | Speed: %s",
                overnight, turbo, emergency, formatNumber(power),
                trendIcon, formatNumber(gains),
                sessionTime, formatNumber(powerTracker.gainsThisSession),
                activeWorkers, Config.FarmMode, Config.TrainSpeedValue
            )
            pcall(function() statsParagraph:Set({ Content = content }) end)
        end
    end)

    -- FPS counter (Orion doesn't have a built-in FPS display, so skip it)
    -- K toggles UI
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.K then
            pcall(function() OrionLib:Toggle() end)
        end
    end)

    OrionLib:Init()

elseif UI_LIB == "Rayfield" then
    -- ============================================================
    -- RAYFIELD UI BUILD (fallback)
    -- ============================================================
    Window = OrionLib:CreateWindow({
        Name = "RezurXLab V2300 | Rayfield",
        LoadingTitle = "V2300 Booting...",
        LoadingSubtitle = "Rayfield fallback active",
        ConfigurationSaving = { Enabled = false },
        Keybind = { Key = Enum.KeyCode.K, Mods = nil },
    })

    -- Farm tab
    local FarmTab = Window:CreateTab("Farm", 4483362458)
    FarmTab:CreateDropdown({
        Name = "Mode",
        Options = {"Hybrid (recommended)", "Legacy"},
        CurrentOption = "Hybrid (recommended)",
        Callback = function(v)
            local val = dropValue(v)
            Config.FarmMode = val:find("Hybrid") and "Hybrid" or "Legacy"
            if Config.FarmEnabled then stopFarm() task.wait(0.1) startFarm() end
        end
    })
    FarmTab:CreateDropdown({
        Name = "Speed Value",
        Options = {"Infinity (math.huge)", "1e9 (safe)", "1e15 (very large)", "1e18 (extreme)", "1e30 (max finite)"},
        CurrentOption = "Infinity (math.huge)",
        Callback = function(v) Config.TrainSpeedValue = dropValue(v) end
    })
    FarmTab:CreateSlider({
        Name = "Workers", Range = {1, 20}, Increment = 1, CurrentValue = 5, Suffix = "",
        Callback = function(v)
            Config.WorkerCount = v
            if Config.FarmEnabled and Config.FarmMode == "Hybrid" then
                killWorkers()
                local n = math.max(1, math.min(20, v * Config.FarmSpeedMul))
                if Config.TurboActive then n = math.min(20, n * 2) end
                hybridState.currentWorkers = n
                spawnWorkers(n)
            end
        end
    })
    FarmTab:CreateDropdown({
        Name = "Speed Multiplier",
        Options = {"0.5x", "1x", "2x"}, CurrentOption = "1x",
        Callback = function(v)
            local val = dropValue(v)
            if val == "0.5x" then Config.FarmSpeedMul = 0.5
            elseif val == "2x" then Config.FarmSpeedMul = 2
            else Config.FarmSpeedMul = 1 end
        end
    })
    FarmTab:CreateToggle({ Name = "Anti-Detect", CurrentValue = true, Callback = function(t) Config.AntiDetect = t end })
    FarmTab:CreateToggle({
        Name = "START FARM", CurrentValue = false,
        Callback = function(t) Config.FarmEnabled = t; if t then startFarm() else stopFarm() end end
    })
    FarmTab:CreateButton({ Name = "TURBO BOOST (2x / 10s)", Callback = function() setTurbo() end })
    FarmTab:CreateToggle({
        Name = "Overnight (5min on / 30s off)", CurrentValue = false,
        Callback = function(t) Config.OvernightEnabled = t; if t then startOvernight() else stopOvernight() end end
    })
    local statsParagraph
    pcall(function()
        statsParagraph = FarmTab:CreateParagraph({ Title = "Power Tracker", Content = "Start farm to begin..." })
    end)

    -- Movement tab
    local MoveTab = Window:CreateTab("Movement", 4483362458)
    MoveTab:CreateToggle({ Name = "Override Stats", CurrentValue = false,
        Callback = function(t) Config.OverrideStats = t; if t then applyMovement() else restoreMovement() end end })
    MoveTab:CreateSlider({ Name = "WalkSpeed", Range = {16, 1000}, Increment = 1, CurrentValue = 16, Suffix = " sp",
        Callback = function(v) Config.WalkSpeed = v; applyMovement() end })
    MoveTab:CreateSlider({ Name = "JumpPower", Range = {50, 1000}, Increment = 1, CurrentValue = 50, Suffix = " pw",
        Callback = function(v) Config.JumpPower = v; applyMovement() end })
    MoveTab:CreateButton({ Name = "Reset (16 / 50)", Callback = function()
        Config.WalkSpeed = 16; Config.JumpPower = 50; Config.OverrideStats = false
        restoreMovement()
        notify("Movement", "Reset to 16/50. Toggle Override OFF manually.", 4)
    end })
    MoveTab:CreateDropdown({ Name = "Noclip Mode", Options = {"V777 (Simple)", "Improved"}, CurrentOption = "Improved",
        Callback = function(v)
            local val = dropValue(v)
            Config.NoclipMode = val:find("V777") and "V777" or "Improved"
            if Config.NoclipEnabled then setNoclipMode(false) task.wait(0.05) setNoclipMode(true) end
        end })
    MoveTab:CreateToggle({ Name = "Noclip", CurrentValue = false, Callback = function(t) setNoclipMode(t) end })

    -- Identity tab
    local IdTab = Window:CreateTab("Identity", 4483362458)
    IdTab:CreateDropdown({ Name = "Title", Options = {"GLOBAL", "SERVER ANNOUNCEMENT", "👑Head Administrator👑", "👑Head Executive Lead Developer👑", "None"}, CurrentOption = "None",
        Callback = function(v) Config.CustomTag = (dropValue(v) == "None" or dropValue(v) == "") and "" or dropValue(v) end })
    IdTab:CreateDropdown({ Name = "Username", Options = {"RezurXshin☑️", "Jandel", "Administrator", "None"}, CurrentOption = "None",
        Callback = function(v) Config.UserName = (dropValue(v) == "None" or dropValue(v) == "") and "" or dropValue(v) end })
    IdTab:CreateInput({ Name = "Custom Title", PlaceholderText = "Empty = no tag", Callback = function(v) Config.CustomTag = v or "" end })
    IdTab:CreateInput({ Name = "Custom Name", PlaceholderText = "Empty = no name", Callback = function(v) Config.UserName = v or "" end })
    IdTab:CreateColorPicker({ Name = "Title / Tag Color", Color = Config.TagColor, Callback = function(v) Config.TagColor = v end })
    IdTab:CreateColorPicker({ Name = "User Name Color", Color = Config.UserColor, Callback = function(v) Config.UserColor = v end })
    IdTab:CreateColorPicker({ Name = "Message Text Color", Color = Config.MessageColor, Callback = function(v) Config.MessageColor = v end })

    -- Chat tab
    local ChatTab = Window:CreateTab("Chat", 4483362458)
    ChatTab:CreateInput({ Name = "Send Shout (type then press Enter)", PlaceholderText = "Type message...",
        RemoveTextAfterFocusLost = true, Callback = function(msg) sendChatMessage(msg) notify("Shout Sent", msg:sub(1, 40), 3) end })
    ChatTab:CreateButton({ Name = "Send Plain-Text Test", Callback = function()
        if not Remotes.SendTextChatMessage then healRemotesWithBackoff() end
        if not Remotes.SendTextChatMessage then notify("Chat", "Remote not found", 4) return end
        local ok = pcall(function() Remotes.SendTextChatMessage:InvokeServer("V2300 test ping") end)
        notify("Test", ok and "Sent" or "Failed", 3)
    end })
    ChatTab:CreateButton({ Name = "Re-scan Chat Remote", Callback = function()
        healRemotesWithBackoff()
        notify("Chat", Remotes.SendTextChatMessage and "Found" or "Missing", 4)
    end })

    -- Lab tab
    local LabTab = Window:CreateTab("Lab", 4483362458)
    LabTab:CreateToggle({ Name = "Anti-AFK", CurrentValue = true, Callback = function(t) Config.AntiAfk = t end })
    LabTab:CreateToggle({ Name = "PVP Off", CurrentValue = false, Callback = function(t) Config.PvpOff = t end })
    local espCache = {}
    local espConn = nil
    local function clearAllEspTags()
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
        for i = 1, 4 do total = total + (ts:GetAttribute(tostring(i)) or 0) end
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
    LabTab:CreateToggle({ Name = "ESP (Power Scan)", CurrentValue = false, Callback = function(t)
        Config.EspEnabled = t
        if not t then clearAllEspTags() return end
        espConn = RunService.RenderStepped:Connect(function()
            pcall(function()
                local creature = workspace:FindFirstChild("Creature")
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
    end })
    LabTab:CreateButton({ Name = "Clear All ESP Tags", Callback = function() clearAllEspTags() notify("ESP", "All tags cleared", 3) end })

    -- System tab
    local SysTab = Window:CreateTab("System", 4483362458)
    SysTab:CreateButton({ Name = "Show Remote Status", Callback = function()
        healRemotesWithBackoff()
        notify("Remotes",
            "Frenzy:" .. (Remotes.ApplyAddFrenzyValue and "Y" or "N") ..
            " Speed:" .. (Remotes.TrainSpeedHasChanged and "Y" or "N") ..
            " Mobile:" .. (Remotes.ApplyMobileTrain and "Y" or "N") ..
            " Stationary:" .. (Remotes.ApplyStationaryTrain and "Y" or "N") ..
            " Chat:" .. (Remotes.SendTextChatMessage and "Y" or "N"), 10)
    end })
    SysTab:CreateButton({ Name = "Re-init All Remotes", Callback = function() healRemotesWithBackoff() notify("Remotes", "Re-scanned", 3) end })
    SysTab:CreateButton({ Name = "Show Last 10 Errors", Callback = function()
        local n = #ERR_LOG
        if n == 0 then notify("Errors", "No errors logged", 4) return end
        local lines = {}
        for i = math.max(1, n - 9), n do
            local e = ERR_LOG[i]
            if e then table.insert(lines, string.format("%s [%s] %s", e.timeStr, e.source, e.msg:sub(1, 60))) end
        end
        notify("Errors (" .. n .. " total)", table.concat(lines, "\n"), 12)
    end })
    SysTab:CreateButton({ Name = "Clear Error Log", Callback = function() table.clear(ERR_LOG) notify("Errors", "Cleared", 3) end })
    SysTab:CreateButton({ Name = "Destroy UI", Callback = function() pcall(function() OrionLib:Destroy() end) end })

    -- Live stats updater
    task.spawn(function()
        while task.wait(1) do
            if statsParagraph then
                local power = powerTracker.tick()
                local gains = powerTracker.avgGainsPerSec()
                local trend = powerTracker.trend()
                local trendIcon = trend == "up" and "↑" or (trend == "down" and "↓" or "→")
                local sessionTime = powerTracker.sessionStart > 0 and math.floor(tick() - powerTracker.sessionStart) or 0
                local turbo = Config.TurboActive and "🚀" or ""
                local overnight = Config.OvernightEnabled and "🌙" or ""
                local emergency = hybridState.emergencyMode and "⚠️" or ""
                local content = string.format(
                    "%s%s%s Power: %s\n%s Gains/s: %s\nSession: %ds | Total: %s\nWorkers: %d | Mode: %s | Speed: %s",
                    overnight, turbo, emergency, formatNumber(power),
                    trendIcon, formatNumber(gains),
                    sessionTime, formatNumber(powerTracker.gainsThisSession),
                    activeWorkers, Config.FarmMode, Config.TrainSpeedValue
                )
                pcall(function() statsParagraph:Set({ Content = content }) end)
            end
        end
    end)

else
    -- ============================================================
    -- NATIVE FALLBACK — no UI library, just notifications + basic toggles via chat
    -- ============================================================
    notify("V2300 Fallback", "All UI libraries failed. Using native notifications. Features still active via config.", 10)
    -- Auto-start nothing; user can't control via UI. Just keep error logging alive.
end


-- ============================================================
-- CORE LOOPS
-- ============================================================
-- [FIX] Movement re-apply only when OverrideStats on AND values drifted
RunService.Heartbeat:Connect(function()
    if not Config.OverrideStats then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hum.WalkSpeed ~= Config.WalkSpeed or hum.JumpPower ~= Config.JumpPower then
        hum.WalkSpeed = Config.WalkSpeed
        hum.JumpPower = Config.JumpPower
        hum.UseJumpPower = true
    end
end)

-- [FIX] CharacterAdded reconnect for movement
player.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum and Config.OverrideStats then
        task.wait(0.2)
        applyMovement()
    end
end)

-- [FIX] Anti-AFK — simulates input without interfering with gameplay
player.Idled:Connect(function()
    if not Config.AntiAfk then return end
    safeCall("anti-afk", function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- [FIX] PVP Off — area spam loop (nil-safe, pcall-wrapped)
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
                    healRemotesWithBackoff()
                end
            end)
        end
    end
end)

-- ============================================================
-- LIVE STATS UPDATER (FPS + Power Tracker)
-- ============================================================
-- [FIX] FPS counter — uses RenderStepped to count ACTUAL frames (was counting task.wait calls)
task.spawn(function()
    local frames = 0
    local t0 = tick()
    local conn = RunService.RenderStepped:Connect(function()
        frames = frames + 1
    end)
    while task.wait(1) do
        local fps = frames  -- frames in the last 1 second = FPS
        UI.FpsLabel.Text = fps .. " FPS"
        UI.FpsLabel.TextColor3 = fps >= 50 and C.green
                                or fps >= 30 and Color3.fromRGB(220, 220, 120)
                                or C.red
        frames = 0
    end
    conn:Disconnect()
end)

task.spawn(function()
    while task.wait(1) do
        local power = powerTracker.tick()
        local gains = powerTracker.avgGainsPerSec()
        local trend = powerTracker.trend()
        local trendIcon = trend == "up" and "↑" or (trend == "down" and "↓" or "→")
        local sessionTime = powerTracker.sessionStart > 0
                        and math.floor(tick() - powerTracker.sessionStart) or 0
        local turbo = Config.TurboActive and "🚀" or ""
        local overnight = Config.OvernightEnabled and "🌙" or ""
        local emergency = hybridState.emergencyMode and "⚠️" or ""
        local content = string.format(
            "%s%s%s Power: %s\n%s Gains/s: %s\nSession: %ds | Total: %s\nWorkers: %d | Mode: %s | Speed: %s",
            overnight, turbo, emergency, formatNumber(power),
            trendIcon, formatNumber(gains),
            sessionTime, formatNumber(powerTracker.gainsThisSession),
            activeWorkers, Config.FarmMode, Config.TrainSpeedValue
        )
        pcall(function() statsParagraph:Set({Content = content}) end)
    end
end)

-- ============================================================
-- BOOT NOTIFY
-- ============================================================
notify("RezurXLab V2300", "Orion UI loaded. math.huge + adaptive throttle. Press K to toggle.", 6)

end  -- end of runMain()

-- ============================================================
-- TOP-LEVEL XPCALL
-- ============================================================
local ok, err = xpcall(runMain, function(e)
    return debug.traceback(tostring(e), 2)
end)
if not ok then
    showErrorToUser(err)
end
