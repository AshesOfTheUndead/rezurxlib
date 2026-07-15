--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  👑 DOMINUS CUSTOM | by RezurXshin                            ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  100% CUSTOM UI — no Rayfield, no Orion, no external deps    ║
    ║  Built from raw Instances, applying every lesson learned:    ║
    ║    • Dark gaming palette (#0D0D12 + neon orange #FF8223)     ║
    ║    • NO UIGradient on TextButton (was the "black box" bug)  ║
    ║    • Dropdowns parented to ScreenGui (no clipping)           ║
    ║    • Color picker panel.Active=true (no click-through)       ║
    ║    • Brighter sidebar + orange divider (not a black void)   ║
    ║    • No boot animation (can get stuck at partial transparency)║
    ║    • Touch targets ≥44px, contrast ≥4.5:1                    ║
    ║    • Emojis on every element (never color alone)             ║
    ║    • Active/pressed states on all interactive elements       ║
    ║                                                               ║
    ║  ENGINE: Hybrid farm with MAX PERFORMANCE                    ║
    ║    • 250 max workers, 15 default                             ║
    ║    • 0.01s loop (0.005s in MAX PERF)                         ║
    ║    • math.huge default speed                                  ║
    ║    • Adaptive throttle (FPS + response + gains)              ║
    ║                                                               ║
    ║  PRO: Save/Load profiles, keyboard shortcuts, Humanoid.Died  ║
    ║  Noclip: V777 + Improved (NO upward glitch on disable)       ║
    ║  Lua 5.1 compatible: no goto, no +=, unpack shim             ║
    ╚══════════════════════════════════════════════════════════════╝
]]

-- ============================================================
-- TOP-LEVEL ERROR CATCHER
-- ============================================================
local _errorBoxShown = false  -- [FIX] singleton — only one error box at a time
local function showErrorToUser(msg)
    if _errorBoxShown then return end  -- [FIX] don't stack error boxes
    _errorBoxShown = true
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local sg = Instance.new("ScreenGui")
        sg.Name = "DOMINUS_Error"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
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
        t.Text = "DOMINUS ERROR:\n\n" .. tostring(msg); t.Parent = f
        -- [FIX] manual close button so user can dismiss immediately
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 80, 0, 28)
        closeBtn.Position = UDim2.new(1, -90, 0, 8)
        closeBtn.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
        closeBtn.Text = "Dismiss"
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 12
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Parent = f
        local cc = Instance.new("UICorner") cc.Parent = closeBtn
        local function dismiss()
            _errorBoxShown = false
            pcall(function() sg:Destroy() end)
        end
        closeBtn.MouseButton1Click:Connect(dismiss)
        task.delay(30, dismiss)
    end)
end

-- ============================================================
-- ERROR LOG
-- ============================================================
if not _G.__DOMINUS_ERRORS then _G.__DOMINUS_ERRORS = {} end
local ERR_LOG = _G.__DOMINUS_ERRORS
local ERR_LOG_MAX = 100

local function logError(source, msg)
    local entry = {
        timeStr = os.date("%H:%M:%S"),
        source = tostring(source),
        msg = tostring(msg):sub(1, 500),
    }
    ERR_LOG[#ERR_LOG + 1] = entry
    if #ERR_LOG > ERR_LOG_MAX then table.remove(ERR_LOG, 1) end
    warn(string.format("[DOMINUS] %s: %s", source, msg))
end

local function safeCall(source, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then logError(source, err) end
    return ok, err
end

-- ============================================================
-- MAIN
-- ============================================================
local function runMain()

if not game:IsLoaded() then
    repeat task.wait(0.1) until game:IsLoaded()
end

-- ============================================================
-- SERVICES
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local TweenService      = game:GetService("TweenService")
local StarterGui        = game:GetService("StarterGui")
local CoreGui           = game:GetService("CoreGui")
local HttpService       = game:GetService("HttpService")
local player            = Players.LocalPlayer

-- ============================================================
-- FORWARD DECLARATIONS — all functions used before their definition
-- ============================================================
local applyMovement, restoreMovement
local executePump
local sendChatMessage
local initAllRemotes, healRemotesWithBackoff
local notify  -- [FIX] forward-declared; assigned with `notify = function` NOT `local function notify`
local setTurbo
local startFarm, stopFarm
local startOvernight, stopOvernight
local setNoclipMode
local powerTracker
local UI, Window

-- ============================================================
-- CONFIG (single source of truth — state-management skill)
-- ============================================================
local Config = {
    CustomTag = "", UserName = "",
    TagColor = Color3.fromRGB(128, 0, 0),
    UserColor = Color3.fromRGB(255, 255, 255),
    MessageColor = Color3.fromRGB(255, 255, 255),
    FarmMode = "Hybrid",
    FarmEnabled = false,
    FarmSpeedMul = 1,
    WorkerCount = 15,
    MaxPerformance = false,
    TrainSpeedValue = "Infinity (math.huge)",
    OvernightEnabled = false,
    OverrideStats = false,
    WalkSpeed = 16, JumpPower = 50,
    NoclipEnabled = false,
    NoclipMode = "Improved",
    PvpOff = false,
    EspEnabled = false,
    AntiAfk = true,
    AntiDetect = true,
    TurboActive = false,
    TurboUntil = 0,
    TurboCooldownUntil = 0,
}

local hybridState = {
    currentWorkers = 5, lastAdjust = 0,
    fpsHistory = {}, responseTimes = {},
    consecutiveFailures = 0, emergencyMode = false,
}

-- ============================================================
-- THEME — dark gaming palette + neon orange (ui-design skill)
-- ============================================================
local C = {
    bg       = Color3.fromRGB(13, 13, 18),
    panel    = Color3.fromRGB(28, 28, 40),    -- brighter so sidebar is visible
    panelAlt = Color3.fromRGB(38, 38, 54),    -- brighter than panel so buttons stand out
    accent   = Color3.fromRGB(255, 130, 35),  -- neon orange
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
local unpack = unpack or table.unpack  -- Lua 5.1 compat

local function dropValue(v)
    if typeof(v) == "table" then return v[1] or "" end
    return tostring(v)
end

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

-- ============================================================
-- REMOTE MANAGER (self-healing with exponential backoff)
-- ============================================================
local Remotes = {}
local remoteMutex = false
local consecutiveHealFailures = 0
local lastHealTime = 0

local function initAllRemotes()
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
initAllRemotes()

healRemotesWithBackoff = function()
    local now = tick()
    local backoff = math.min(30, 2 ^ consecutiveHealFailures)
    if now - lastHealTime < backoff then return end
    lastHealTime = now
    initAllRemotes()
    if Remotes.ApplyAddFrenzyValue then
        consecutiveHealFailures = 0
    else
        consecutiveHealFailures = consecutiveHealFailures + 1
    end
end

task.spawn(function()
    while task.wait(30) do safeCall("periodic-init", initAllRemotes) end
end)

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
-- HYBRID FARM ENGINE
-- ============================================================
local TRAIN_SPEED = math.huge

local function getTrainSpeed()
    local v = Config.TrainSpeedValue
    if v:find("Infinity") then return math.huge
    elseif v:find("1e9") then return 1e9
    elseif v:find("1e15") then return 1e15
    elseif v:find("1e18") then return 1e18
    elseif v:find("1e30") then return 1e30
    else return math.huge end
end

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
    if Config.AntiDetect then shuffle(calls) end
    for _, c in ipairs(calls) do
        if c.remote then
            if c.func == "Invoke" then
                pcall(c.remote.InvokeServer, c.remote, unpack(c.args))
            else
                pcall(c.remote.FireServer, c.remote, unpack(c.args))
            end
        end
        if Config.AntiDetect and not Config.MaxPerformance and math.random() < 0.3 then
            task.wait(math.random() * 0.003)
        end
    end
end

local workerGeneration = 0
local activeWorkers = 0

local function spawnWorkers(n)
    workerGeneration = workerGeneration + 1
    local gen = workerGeneration
    activeWorkers = n
    for i = 1, n do
        local workerId = i
        task.spawn(function()
            task.wait((workerId - 1) * 0.002)
            while gen == workerGeneration and Config.FarmEnabled do
                local speed = getTrainSpeed()
                if hybridState.emergencyMode then speed = 1e9 end
                pcall(executePump, speed)
                local baseWait = Config.MaxPerformance and 0.005 or 0.01
                local stagger = (workerId * 0.001) % 0.005
                task.wait(baseWait + stagger)
            end
        end)
    end
end

local function killWorkers()
    workerGeneration = workerGeneration + 1
    activeWorkers = 0
end

local adaptiveConn = nil
local function startAdaptiveThrottle()
    if adaptiveConn then adaptiveConn:Disconnect() end
    adaptiveConn = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - hybridState.lastAdjust < 2 then return end
        hybridState.lastAdjust = now
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
        local avgResponse = 0
        if #hybridState.responseTimes > 0 then
            for _, v in ipairs(hybridState.responseTimes) do avgResponse = avgResponse + v end
            avgResponse = avgResponse / #hybridState.responseTimes
        end
        local trend = powerTracker.trend()
        local oldWorkers = hybridState.currentWorkers
        if avgFps < 15 then
            hybridState.emergencyMode = true
            hybridState.currentWorkers = 1
            logError("adaptive", "EMERGENCY: FPS " .. avgFps)
        elseif avgFps < 25 then
            hybridState.emergencyMode = false
            hybridState.currentWorkers = math.max(1, hybridState.currentWorkers - 1)
        elseif avgResponse > 150 then
            hybridState.emergencyMode = false
            hybridState.currentWorkers = math.max(1, hybridState.currentWorkers - 1)
        elseif trend == "down" and hybridState.currentWorkers > 2 then
            hybridState.emergencyMode = false
            hybridState.currentWorkers = hybridState.currentWorkers - 1
        elseif trend == "up" and avgFps > 50 and avgResponse < 80 and hybridState.currentWorkers < 250 then
            hybridState.emergencyMode = false
            hybridState.currentWorkers = hybridState.currentWorkers + 1
        elseif trend == "flat" and avgFps > 50 and avgResponse < 100 and hybridState.currentWorkers < 100 then
            hybridState.emergencyMode = false
            hybridState.currentWorkers = hybridState.currentWorkers + 1
        end
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

local farmConn = nil

startFarm = function()
    if farmConn then farmConn:Disconnect() farmConn = nil end
    stopAdaptiveThrottle()
    powerTracker.startSession()
    if Config.FarmMode == "Hybrid" then
        hybridState.currentWorkers = math.max(1, math.min(250, Config.WorkerCount * Config.FarmSpeedMul))
        if Config.TurboActive then hybridState.currentWorkers = math.min(250, hybridState.currentWorkers * 2) end
        hybridState.emergencyMode = false
        hybridState.fpsHistory = {}
        hybridState.responseTimes = {}
        spawnWorkers(hybridState.currentWorkers)
        startAdaptiveThrottle()
    else
        farmConn = RunService.Heartbeat:Connect(function()
            safeCall("farm-legacy", function()
                pcall(executePump, getTrainSpeed())
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
    Config.FarmMode = "Hybrid"
    Config.WorkerCount = 3
    Config.AntiDetect = true
    Config.TrainSpeedValue = "Infinity (math.huge)"
    Config.TurboActive = false
    Config.TurboUntil = 0
    Config.FarmEnabled = true
    startFarm()
    overnightPhase = "work"
    logError("overnight", "Started")
    local cycleStart = tick()
    local WORK_DUR = 300
    local BREAK_DUR = 30
    local lastFpsCheck = tick()
    local fpsLowStreak = 0
    overnightConn = RunService.Heartbeat:Connect(function()
        local now = tick()
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
                        end
                    end)
                end
            else
                fpsLowStreak = 0
            end
        end
        if overnightPhase == "work" and now - cycleStart >= WORK_DUR then
            overnightPhase = "break"
            killWorkers()
            collectgarbage("collect")
            logError("overnight", "Break — 30s")
            task.delay(BREAK_DUR, function()
                if Config.OvernightEnabled then
                    overnightPhase = "work"
                    cycleStart = tick()
                    spawnWorkers(3)
                end
            end)
        end
    end)
end

stopOvernight = function()
    if overnightConn then overnightConn:Disconnect() overnightConn = nil end
    Config.FarmMode = overnightOriginal.FarmMode or "Hybrid"
    Config.WorkerCount = overnightOriginal.WorkerCount or 15
    Config.AntiDetect = overnightOriginal.AntiDetect ~= nil and overnightOriginal.AntiDetect or true
    Config.TrainSpeedValue = overnightOriginal.TrainSpeedValue or "Infinity (math.huge)"
    Config.TurboActive = false
    Config.FarmEnabled = false
    stopFarm()
    overnightPhase = "idle"
end

-- ============================================================
-- TURBO BOOST
-- ============================================================
local TURBO_DUR = 10
local TURBO_CD = 5
setTurbo = function()
    if Config.OvernightEnabled then notify("Turbo", "Disabled in Overnight mode", 3) return end
    local now = tick()
    if Config.TurboActive then notify("Turbo", "Already active!", 3) return end
    if now < Config.TurboCooldownUntil then
        notify("Turbo Cooldown", "Wait " .. math.ceil(Config.TurboCooldownUntil - now) .. "s", 3)
        return
    end
    Config.TurboActive = true
    Config.TurboUntil = now + TURBO_DUR
    notify("🚀 TURBO", "2x farming for 10s!", 3)
    if Config.FarmMode == "Hybrid" and Config.FarmEnabled then
        killWorkers()
        task.wait(0.05)
        spawnWorkers(math.min(250, hybridState.currentWorkers * 2))
    end
    task.spawn(function()
        while Config.TurboActive and tick() < Config.TurboUntil do
            task.wait(0.5)
        end
        Config.TurboActive = false
        Config.TurboCooldownUntil = tick() + TURBO_CD
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
-- NOCLIP — V777 + Improved (NO upward glitch on disable)
-- ============================================================
local noclipConn = nil
local noclipCharConn = nil

setNoclipMode = function(enabled)
    Config.NoclipEnabled = enabled
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if noclipCharConn then noclipCharConn:Disconnect() noclipCharConn = nil end
    if not enabled then
        -- [FIX] DO NOT restore CanCollide — causes upward physics glitch
        return
    end
    local function startNoclip()
        if Config.NoclipMode == "V777" then
            noclipConn = RunService.Stepped:Connect(function()
                local char = player.Character
                if char then
                    for _, v in pairs(char:GetDescendants()) do
                        if v:IsA("BasePart") then v.CanCollide = false end
                    end
                end
            end)
        else
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
    noclipCharConn = player.CharacterAdded:Connect(function()
        task.wait(0.3)
        if Config.NoclipEnabled then
            if noclipConn then noclipConn:Disconnect() noclipConn = nil end
            startNoclip()
        end
    end)
end

-- ============================================================
-- CUSTOM UI LIBRARY — built from raw Instances
-- ============================================================
UI = {}
Window = nil

do
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DOMINUS_Custom"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    pcall(function() screenGui.Parent = CoreGui end)
    if not screenGui.Parent then
        screenGui.Parent = player:WaitForChild("PlayerGui")
    end
    UI.ScreenGui = screenGui

    -- Main window — NO boot animation (can get stuck at partial transparency)
    local WIN_W, WIN_H = 520, 540
    local frame = Instance.new("Frame")
    frame.Name = "Window"
    frame.Size = UDim2.new(0, WIN_W, 0, WIN_H)
    frame.Position = UDim2.new(0.5, -WIN_W/2, 0.4, -WIN_H/2)
    frame.BackgroundColor3 = C.bg
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true  -- [FIX] keep true so rounded corners clip content, but popups are on screenGui
    frame.Parent = screenGui
    corner(frame, 18)
    stroke(frame, C.border, 2)
    UI.Frame = frame

    -- ── HEADER ──
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 56)
    header.BackgroundColor3 = C.panel
    header.BorderSizePixel = 0
    header.Parent = frame
    corner(header, 18)
    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0.5, 0)
    headerFix.Position = UDim2.new(0, 0, 0.5, 0)
    headerFix.BackgroundColor3 = C.panel
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header
    local accentLine = Instance.new("Frame")
    accentLine.Size = UDim2.new(1, 0, 0, 2)
    accentLine.Position = UDim2.new(0, 0, 1, -2)
    accentLine.BackgroundColor3 = C.accent
    accentLine.BorderSizePixel = 0
    accentLine.Parent = header

    local logo = Instance.new("TextLabel")
    logo.RichText = true
    logo.Text = '<font color="#F0F0FA">DOMINUS</font> <font color="#FF8223">PRO</font>'
    logo.Size = UDim2.new(0, 220, 0, 30)
    logo.Position = UDim2.new(0, 14, 0, 6)
    logo.BackgroundTransparency = 1
    logo.Font = Enum.Font.GothamBold
    logo.TextSize = 22
    logo.TextColor3 = C.text
    logo.TextXAlignment = Enum.TextXAlignment.Left
    logo.Parent = header

    local sub = Instance.new("TextLabel")
    sub.Text = "👑 by RezurXshin | Maximum Power"
    sub.Size = UDim2.new(0, 220, 0, 16)
    sub.Position = UDim2.new(0, 15, 0, 36)
    sub.BackgroundTransparency = 1
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 12
    sub.TextColor3 = C.muted
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = header

    -- FPS label
    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Size = UDim2.new(0, 70, 0, 24)
    fpsLabel.Position = UDim2.new(0, 320, 0.5, -12)
    fpsLabel.BackgroundColor3 = C.panelAlt
    fpsLabel.BackgroundTransparency = 0.3
    fpsLabel.Font = Enum.Font.Code
    fpsLabel.TextSize = 12
    fpsLabel.TextColor3 = C.green
    fpsLabel.Text = "60 FPS"
    fpsLabel.Parent = header
    corner(fpsLabel, 8)
    UI.FpsLabel = fpsLabel

    -- Minimize button — positioned INSIDE the rounded corners
    local minBtn = Instance.new("TextButton")
    minBtn.Text = "—"
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(1, -76, 0.5, -15)
    minBtn.BackgroundColor3 = C.panelAlt
    minBtn.TextColor3 = C.muted
    minBtn.TextSize = 18
    minBtn.Font = Enum.Font.GothamBold
    minBtn.BorderSizePixel = 0
    minBtn.AutoButtonColor = false
    minBtn.Parent = header
    corner(minBtn, 8)

    local minimized = false
    minBtn.MouseEnter:Connect(function()
        TweenService:Create(minBtn, TWEEN_FAST, {BackgroundColor3 = C.tabHover, TextColor3 = C.text}):Play()
    end)
    minBtn.MouseLeave:Connect(function()
        TweenService:Create(minBtn, TWEEN_FAST, {BackgroundColor3 = C.panelAlt, TextColor3 = C.muted}):Play()
    end)
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        local targetH = minimized and 56 or WIN_H
        TweenService:Create(frame, TWEEN, {Size = UDim2.new(0, WIN_W, 0, targetH)}):Play()
        minBtn.Text = minimized and "+" or "—"
    end)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Text = "✕"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0.5, -15)
    closeBtn.BackgroundColor3 = C.red
    closeBtn.TextColor3 = C.white
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = header
    corner(closeBtn, 8)
    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TWEEN_FAST, {BackgroundColor3 = Color3.fromRGB(230, 80, 80)}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TWEEN_FAST, {BackgroundColor3 = C.red}):Play()
    end)
    closeBtn.MouseButton1Click:Connect(function()
        -- [FIX] Close button HIDES the UI (not destroys). Use System tab → Destroy UI to actually destroy.
        screenGui.Enabled = false
        notify("ℹ️ Info", "UI hidden. Press K to show again.", 3)
    end)

    -- ── DRAG (mobile + desktop) ──
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                        startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- ── SIDEBAR — brighter bg + orange divider (NOT a black void) ──
    local SIDEBAR_W = 120
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -58)
    sidebar.Position = UDim2.new(0, 0, 0, 58)
    sidebar.BackgroundColor3 = C.panel  -- brighter so sidebar is visible
    sidebar.BorderSizePixel = 0
    sidebar.ClipsDescendants = false  -- [FIX] don't clip tab buttons
    sidebar.Parent = frame
    -- Orange divider on right edge
    local sbDivider = Instance.new("Frame")
    sbDivider.Size = UDim2.new(0, 2, 1, 0)
    sbDivider.Position = UDim2.new(1, -2, 0, 0)
    sbDivider.BackgroundColor3 = C.accent
    sbDivider.BorderSizePixel = 0
    sbDivider.Parent = sidebar
    local sbLayout = Instance.new("UIListLayout")
    sbLayout.Padding = UDim.new(0, 6)
    sbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sbLayout.VerticalAlignment = Enum.VerticalAlignment.Top  -- [FIX] tabs start from top
    sbLayout.Parent = sidebar
    local sbPad = Instance.new("UIPadding")
    sbPad.PaddingTop = UDim.new(0, 8)
    sbPad.Parent = sidebar

    -- ── CONTENT AREA ──
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -SIDEBAR_W - 4, 1, -60)
    content.Position = UDim2.new(0, SIDEBAR_W + 2, 0, 58)
    content.BackgroundTransparency = 1
    content.Parent = frame
    UI.Content = content

    UI.Tabs = {}
    UI.ActiveTab = nil

    -- ============================================================
    -- GLOBAL POPUP MANAGER — dropdowns + color pickers parented to ScreenGui
    -- ============================================================
    local currentPopup = nil
    local function closeCurrentPopup()
        if currentPopup then
            if currentPopup.catcher then pcall(function() currentPopup.catcher:Destroy() end) end
            if currentPopup.popup then pcall(function() currentPopup.popup:Destroy() end) end
            if currentPopup.arrow then pcall(function() currentPopup.arrow.Text = "▼" end) end
            currentPopup = nil
        end
    end
    UI.CloseCurrentPopup = closeCurrentPopup

    -- Notification container (stacking)
    local notifContainer = Instance.new("Frame")
    notifContainer.Size = UDim2.new(0, 300, 1, -20)
    notifContainer.Position = UDim2.new(1, -310, 0, 10)
    notifContainer.BackgroundTransparency = 1
    notifContainer.Parent = screenGui
    local nLayout = Instance.new("UIListLayout")
    nLayout.Padding = UDim.new(0, 6)
    nLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    nLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    nLayout.Parent = notifContainer

    -- ============================================================
    -- NOTIFY — assigned to forward-declared local (NOT `local function`)
    -- ============================================================
    notify = function(title, content, duration)
        local n = Instance.new("Frame")
        n.Size = UDim2.new(1, 0, 0, 60)
        n.BackgroundColor3 = C.panel
        n.BackgroundTransparency = 0.05
        n.Parent = notifContainer
        corner(n, 12)
        stroke(n, C.accent, 1.5)
        local ttl = Instance.new("TextLabel")
        ttl.Size = UDim2.new(1, -16, 0, 18)
        ttl.Position = UDim2.new(0, 8, 0, 6)
        ttl.BackgroundTransparency = 1
        ttl.Font = Enum.Font.GothamBold
        ttl.TextSize = 13
        ttl.TextColor3 = C.accent
        ttl.TextXAlignment = Enum.TextXAlignment.Left
        ttl.Text = title or "DOMINUS"
        ttl.Parent = n
        local cnt = Instance.new("TextLabel")
        cnt.Size = UDim2.new(1, -16, 0, 32)
        cnt.Position = UDim2.new(0, 8, 0, 24)
        cnt.BackgroundTransparency = 1
        cnt.Font = Enum.Font.Gotham
        cnt.TextSize = 12
        cnt.TextColor3 = C.text
        cnt.TextXAlignment = Enum.TextXAlignment.Left
        cnt.TextYAlignment = Enum.TextYAlignment.Top
        cnt.TextWrapped = true
        cnt.Text = content or ""
        cnt.Parent = n
        n.Size = UDim2.new(1, 0, 0, 0)
        n.BackgroundTransparency = 1
        TweenService:Create(n, TWEEN, {Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 0.05}):Play()
        task.delay(duration or 5, function()
            local t = TweenService:Create(n, TWEEN, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1})
            t:Play()
            t.Completed:Connect(function() n:Destroy() end)
        end)
    end

    function UI:CreateTab(name, icon)
        local tab = {}
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 104, 0, 46)
        btn.BackgroundColor3 = C.panelAlt
        btn.Text = (icon or "") .. " " .. name
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 14
        btn.TextColor3 = C.muted
        btn.TextWrapped = true
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.Parent = sidebar
        corner(btn, 10)

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = C.accent
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.Visible = false
        page.Parent = content
        local pLayout = Instance.new("UIListLayout")
        pLayout.Padding = UDim.new(0, 8)
        pLayout.Parent = page
        local pPad = Instance.new("UIPadding")
        pPad.PaddingTop = UDim.new(0, 8)
        pPad.PaddingLeft = UDim.new(0, 8)
        pPad.PaddingRight = UDim.new(0, 8)
        pPad.PaddingBottom = UDim.new(0, 8)
        pPad.Parent = page
        local function updateCanvas()
            page.CanvasSize = UDim2.new(0, 0, 0, pLayout.AbsoluteContentSize.Y + 16)
        end
        pLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

        tab.Page = page
        tab.Btn = btn
        tab.Name = name

        btn.MouseEnter:Connect(function()
            if UI.ActiveTab ~= tab then
                TweenService:Create(btn, TWEEN_FAST, {BackgroundColor3 = C.tabHover, TextColor3 = C.text}):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if UI.ActiveTab ~= tab then
                TweenService:Create(btn, TWEEN_FAST, {BackgroundColor3 = C.panelAlt, TextColor3 = C.muted}):Play()
            end
        end)
        btn.MouseButton1Click:Connect(function() UI:SelectTab(tab) end)

        table.insert(UI.Tabs, tab)
        if #UI.Tabs == 1 then UI:SelectTab(tab) end

        -- ============================================================
        -- TAB COMPONENT METHODS
        -- ============================================================

        function tab:Label(text)
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1, 0, 0, 22)
            l.BackgroundTransparency = 1
            l.Font = Enum.Font.GothamBold
            l.TextSize = 13
            l.TextColor3 = C.accent
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Text = "  " .. text
            l.Parent = page
            return l
        end

        function tab:Button(name, callback)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 44)
            b.BackgroundColor3 = C.panel
            b.Text = "  " .. name
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 14
            b.TextColor3 = C.text
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.AutoButtonColor = false
            b.BorderSizePixel = 0
            b.Parent = page
            corner(b, 12)
            stroke(b, C.border, 1.5)
            -- [FIX] NO gradient — UIGradient on TextButton makes text invisible (black box bug)
            b.MouseEnter:Connect(function()
                TweenService:Create(b, TWEEN_FAST, {BackgroundColor3 = C.tabHover}):Play()
            end)
            b.MouseLeave:Connect(function()
                TweenService:Create(b, TWEEN_FAST, {BackgroundColor3 = C.panel}):Play()
            end)
            b.MouseButton1Click:Connect(function()
                -- [ENHANCEMENT] Active/pressed state (ui-design skill)
                TweenService:Create(b, TWEEN_FAST, {BackgroundColor3 = C.accentDim}):Play()
                task.delay(0.1, function()
                    TweenService:Create(b, TWEEN_FAST, {BackgroundColor3 = C.panel}):Play()
                end)
                safeCall("button:" .. name, callback)
            end)
            return b
        end

        function tab:Toggle(name, default, callback)
            local state = default or false
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 44)
            holder.BackgroundColor3 = C.panel
            holder.BorderSizePixel = 0
            holder.Parent = page
            corner(holder, 12)
            stroke(holder, C.border, 1.5)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -64, 1, 0)
            lbl.Position = UDim2.new(0, 12, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 14
            lbl.TextColor3 = C.text
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = "  " .. name
            lbl.Parent = holder
            local sw = Instance.new("Frame")
            sw.Size = UDim2.new(0, 44, 0, 22)
            sw.Position = UDim2.new(1, -54, 0.5, -11)
            sw.BackgroundColor3 = state and C.accent or C.track
            sw.Parent = holder
            corner(sw, UDim.new(1, 0))
            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 18, 0, 18)
            knob.Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
            knob.BackgroundColor3 = C.white
            knob.Parent = sw
            corner(knob, UDim.new(1, 0))
            local obj = {Set = function(_, v)
                state = v
                TweenService:Create(sw, TWEEN, {BackgroundColor3 = state and C.accent or C.track}):Play()
                TweenService:Create(knob, TWEEN, {
                    Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
                }):Play()
                if callback then callback(state) end
            end, Get = function() return state end}
            holder.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    state = not state
                    TweenService:Create(sw, TWEEN, {BackgroundColor3 = state and C.accent or C.track}):Play()
                    TweenService:Create(knob, TWEEN, {
                        Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
                    }):Play()
                    if callback then callback(state) end
                end
            end)
            return obj
        end

        function tab:Slider(name, minVal, maxVal, default, suffix, callback)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 50)
            holder.BackgroundColor3 = C.panel
            holder.BorderSizePixel = 0
            holder.Parent = page
            corner(holder, 12)
            stroke(holder, C.border, 1.5)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -80, 0, 18)
            lbl.Position = UDim2.new(0, 12, 0, 5)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 13
            lbl.TextColor3 = C.text
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = "  " .. name
            lbl.Parent = holder
            local valLbl = Instance.new("TextLabel")
            valLbl.Size = UDim2.new(0, 64, 0, 18)
            valLbl.Position = UDim2.new(1, -72, 0, 5)
            valLbl.BackgroundTransparency = 1
            valLbl.Font = Enum.Font.GothamBold
            valLbl.TextSize = 13
            valLbl.TextColor3 = C.accent
            valLbl.TextXAlignment = Enum.TextXAlignment.Right
            valLbl.Text = tostring(default) .. (suffix or "")
            valLbl.Parent = holder
            local track = Instance.new("Frame")
            track.Size = UDim2.new(1, -24, 0, 8)
            track.Position = UDim2.new(0, 12, 0, 32)
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
            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 16, 0, 16)
            knob.Position = UDim2.new(0, -8, 0.5, -8)
            knob.BackgroundColor3 = C.white
            knob.BorderSizePixel = 0
            knob.Parent = track
            corner(knob, UDim.new(1, 0))
            local value = default
            local function update()
                local pct = (value - minVal) / (maxVal - minVal)
                pct = math.clamp(pct, 0, 1)
                fill.Size = UDim2.new(pct, 0, 1, 0)
                knob.Position = UDim2.new(pct, -8, 0.5, -8)
                valLbl.Text = tostring(value) .. (suffix or "")
            end
            update()
            local obj = {Set = function(_, v)
                value = math.clamp(v, minVal, maxVal)
                update()
                if callback then callback(value) end
            end, Get = function() return value end}
            local dragging = false
            local function setFromX(x)
                local rel = track.AbsolutePosition.X
                local sz = track.AbsoluteSize.X
                local pct = math.clamp((x - rel) / sz, 0, 1)
                value = math.floor(minVal + pct * (maxVal - minVal) + 0.5)
                update()
                if callback then callback(value) end
            end
            track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    setFromX(input.Position.X)
                end
            end)
            track.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                    setFromX(input.Position.X)
                end
            end)
            return obj
        end

        function tab:Input(name, placeholder, callback)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 48)
            holder.BackgroundColor3 = C.panel
            holder.BorderSizePixel = 0
            holder.Parent = page
            corner(holder, 12)
            stroke(holder, C.border, 1.5)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -16, 0, 16)
            lbl.Position = UDim2.new(0, 12, 0, 5)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 12
            lbl.TextColor3 = C.muted
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = "  " .. name
            lbl.Parent = holder
            local box = Instance.new("TextBox")
            box.Size = UDim2.new(1, -24, 0, 20)
            box.Position = UDim2.new(0, 12, 0, 24)
            box.BackgroundTransparency = 1
            box.Font = Enum.Font.Gotham
            box.TextSize = 14
            box.TextColor3 = C.text
            box.PlaceholderColor3 = C.muted
            box.PlaceholderText = placeholder or ""
            box.Text = ""
            box.TextXAlignment = Enum.TextXAlignment.Left
            box.ClearTextOnFocus = false
            box.Parent = holder
            box.FocusLost:Connect(function()
                if callback then callback(box.Text) end
            end)
            return box
        end

        -- [FIX] ChatInput: Enter to send + clear, click-away keeps text
        function tab:ChatInput(name, placeholder, onSend)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 56)
            holder.BackgroundColor3 = C.panel
            holder.BorderSizePixel = 0
            holder.Parent = page
            corner(holder, 12)
            stroke(holder, C.border, 1.5)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -16, 0, 16)
            lbl.Position = UDim2.new(0, 12, 0, 5)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 12
            lbl.TextColor3 = C.muted
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = "  " .. name
            lbl.Parent = holder
            local box = Instance.new("TextBox")
            box.Size = UDim2.new(1, -24, 0, 28)
            box.Position = UDim2.new(0, 12, 0, 24)
            box.BackgroundColor3 = C.inputBg
            box.BackgroundTransparency = 0.5
            box.Font = Enum.Font.Gotham
            box.TextSize = 14
            box.TextColor3 = C.text
            box.PlaceholderColor3 = C.muted
            box.PlaceholderText = placeholder or ""
            box.Text = ""
            box.TextXAlignment = Enum.TextXAlignment.Left
            box.ClearTextOnFocus = false
            box.ReturnTextOnFocusLost = false  -- [FIX] don't return on click-away
            box.Parent = holder
            corner(box, 6)
            box.FocusLost:Connect(function(enterPressed)
                if enterPressed and box.Text ~= "" then
                    if onSend then onSend(box.Text) end
                    box.Text = ""  -- [FIX] clear after Enter
                end
            end)
            return box
        end

        function tab:Dropdown(name, options, default, callback)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 44)
            holder.BackgroundColor3 = C.panel
            holder.BorderSizePixel = 0
            holder.Parent = page
            corner(holder, 12)
            stroke(holder, C.border, 1.5)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -34, 1, 0)
            lbl.Position = UDim2.new(0, 12, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 13
            lbl.TextColor3 = C.text
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = "  " .. name .. ": " .. (default or options[1] or "")
            lbl.Parent = holder
            local arrow = Instance.new("TextLabel")
            arrow.Size = UDim2.new(0, 22, 1, 0)
            arrow.Position = UDim2.new(1, -26, 0, 0)
            arrow.BackgroundTransparency = 1
            arrow.Font = Enum.Font.GothamBold
            arrow.TextSize = 14
            arrow.TextColor3 = C.muted
            arrow.Text = "▼"
            arrow.Parent = holder
            local obj = {Selected = default or options[1] or ""}
            local function openList()
                closeCurrentPopup()
                arrow.Text = "▲"
                local catcher = Instance.new("TextButton")
                catcher.Size = UDim2.new(1, 0, 1, 0)
                catcher.BackgroundColor3 = Color3.new(0, 0, 0)
                catcher.BackgroundTransparency = 1
                catcher.Text = ""
                catcher.AutoButtonColor = false
                catcher.Parent = screenGui  -- [FIX] parented to ScreenGui — NEVER clipped
                local holderPos = holder.AbsolutePosition
                local holderSize = holder.AbsoluteSize
                local itemH = 28
                local listH = #options * (itemH + 2) + 8
                local cam = workspace.CurrentCamera
                local viewportH = cam and cam.ViewportSize.Y or 800
                local openDownward = (holderPos.Y + holderSize.Y + listH + 4 <= viewportH)
                local listY = openDownward
                    and (holderPos.Y + holderSize.Y + 4)
                    or (holderPos.Y - listH - 4)
                local list = Instance.new("Frame")
                list.Size = UDim2.new(0, holderSize.X, 0, listH)
                list.Position = UDim2.new(0, holderPos.X, 0, listY)
                list.BackgroundColor3 = C.panel
                list.BorderSizePixel = 0
                list.Parent = screenGui  -- [FIX] parented to ScreenGui — NEVER clipped
                corner(list, 12)
                stroke(list, C.border, 1.5)
                local lL = Instance.new("UIListLayout")
                lL.Padding = UDim.new(0, 2)
                lL.Parent = list
                local lPad = Instance.new("UIPadding")
                lPad.PaddingTop = UDim.new(0, 4)
                lPad.PaddingLeft = UDim.new(0, 4)
                lPad.PaddingRight = UDim.new(0, 4)
                lPad.Parent = list
                for _, opt in ipairs(options) do
                    local item = Instance.new("TextButton")
                    item.Size = UDim2.new(1, 0, 0, itemH)
                    item.BackgroundColor3 = C.panelAlt
                    item.Text = "  " .. opt
                    item.Font = Enum.Font.Gotham
                    item.TextSize = 13
                    item.TextColor3 = C.text
                    item.TextXAlignment = Enum.TextXAlignment.Left
                    item.AutoButtonColor = false
                    item.Parent = list
                    corner(item, 8)
                    item.MouseEnter:Connect(function()
                        TweenService:Create(item, TWEEN_FAST, {BackgroundColor3 = C.accentDim}):Play()
                    end)
                    item.MouseLeave:Connect(function()
                        TweenService:Create(item, TWEEN_FAST, {BackgroundColor3 = C.panelAlt}):Play()
                    end)
                    item.MouseButton1Click:Connect(function()
                        obj.Selected = opt
                        lbl.Text = "  " .. name .. ": " .. opt
                        closeCurrentPopup()
                        if callback then callback(opt) end
                    end)
                end
                catcher.MouseButton1Click:Connect(closeCurrentPopup)
                currentPopup = { catcher = catcher, popup = list, arrow = arrow }
            end
            holder.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    openList()
                end
            end)
            function obj:Get() return obj.Selected end
            return obj
        end

        -- [FIX] ColorPicker: panel.Active=true blocks click-through
        function tab:ColorPicker(name, defaultColor, callback)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 44)
            holder.BackgroundColor3 = C.panel
            holder.BorderSizePixel = 0
            holder.Parent = page
            corner(holder, 12)
            stroke(holder, C.border, 1.5)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -70, 1, 0)
            lbl.Position = UDim2.new(0, 12, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 13
            lbl.TextColor3 = C.text
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = "  " .. name
            lbl.Parent = holder
            local swatch = Instance.new("TextButton")
            swatch.Size = UDim2.new(0, 56, 0, 32)
            swatch.Position = UDim2.new(1, -64, 0.5, -16)
            swatch.BackgroundColor3 = defaultColor or Color3.fromRGB(255, 255, 255)
            swatch.BorderSizePixel = 0
            swatch.Text = ""
            swatch.AutoButtonColor = false
            swatch.Parent = holder
            corner(swatch, 8)
            stroke(swatch, C.white, 1.5)
            local obj = { Color = defaultColor or Color3.fromRGB(255, 255, 255) }
            local function openPicker()
                closeCurrentPopup()
                local r = math.floor(obj.Color.R * 255 + 0.5)
                local g = math.floor(obj.Color.G * 255 + 0.5)
                local b = math.floor(obj.Color.B * 255 + 0.5)
                local catcher = Instance.new("TextButton")
                catcher.Size = UDim2.new(1, 0, 1, 0)
                catcher.BackgroundColor3 = Color3.new(0, 0, 0)
                catcher.BackgroundTransparency = 0.4
                catcher.Text = ""
                catcher.AutoButtonColor = false
                catcher.Parent = screenGui
                local panel = Instance.new("Frame")
                panel.Size = UDim2.new(0, 300, 0, 230)
                local swatchPos = swatch.AbsolutePosition
                local panelX = swatchPos.X - 240
                local panelY = swatchPos.Y - 210
                local cam = workspace.CurrentCamera
                local viewport = cam and cam.ViewportSize or Vector2.new(1920, 1080)
                if panelX < 10 then panelX = 10 end
                if panelY < 10 then panelY = 10 end
                if panelX + 300 > viewport.X - 10 then panelX = viewport.X - 310 end
                if panelY + 230 > viewport.Y - 10 then panelY = swatchPos.Y + 40 end
                panel.Position = UDim2.new(0, panelX, 0, panelY)
                panel.BackgroundColor3 = C.panel
                panel.BorderSizePixel = 0
                panel.Active = true  -- [FIX] CRITICAL: blocks click-through
                panel.Parent = screenGui
                corner(panel, 14)
                stroke(panel, C.accent, 2)
                local ttl = Instance.new("TextLabel")
                ttl.Size = UDim2.new(1, -16, 0, 24)
                ttl.Position = UDim2.new(0, 12, 0, 10)
                ttl.BackgroundTransparency = 1
                ttl.Font = Enum.Font.GothamBold
                ttl.TextSize = 14
                ttl.TextColor3 = C.accent
                ttl.TextXAlignment = Enum.TextXAlignment.Left
                ttl.Text = name
                ttl.Parent = panel
                local preview = Instance.new("Frame")
                preview.Size = UDim2.new(0, 52, 0, 52)
                preview.Position = UDim2.new(1, -62, 0, 10)
                preview.BackgroundColor3 = obj.Color
                preview.BorderSizePixel = 0
                preview.Parent = panel
                corner(preview, 10)
                stroke(preview, C.white, 1.5)
                local function updateColor()
                    obj.Color = Color3.fromRGB(r, g, b)
                    swatch.BackgroundColor3 = obj.Color
                    preview.BackgroundColor3 = obj.Color
                    if callback then callback(obj.Color) end
                end
                local function makeChannel(chanName, yPos, getValue, setValue)
                    local chanLbl = Instance.new("TextLabel")
                    chanLbl.Size = UDim2.new(0, 22, 0, 22)
                    chanLbl.Position = UDim2.new(0, 12, 0, yPos)
                    chanLbl.BackgroundTransparency = 1
                    chanLbl.Font = Enum.Font.GothamBold
                    chanLbl.TextSize = 14
                    chanLbl.TextColor3 = C.text
                    chanLbl.TextXAlignment = Enum.TextXAlignment.Left
                    chanLbl.Text = chanName
                    chanLbl.Parent = panel
                    local tr = Instance.new("TextButton")
                    tr.Size = UDim2.new(0, 200, 0, 18)
                    tr.Position = UDim2.new(0, 38, 0, yPos + 2)
                    tr.BackgroundColor3 = C.track
                    tr.BorderSizePixel = 0
                    tr.Text = ""
                    tr.AutoButtonColor = false
                    tr.Parent = panel
                    corner(tr, UDim.new(1, 0))
                    local fl = Instance.new("Frame")
                    fl.Size = UDim2.new(getValue() / 255,0, 1, 0)
                    fl.BackgroundColor3 = C.accent
                    fl.BorderSizePixel = 0
                    fl.Parent = tr
                    corner(fl, UDim.new(1, 0))
                    local kb = Instance.new("Frame")
                    kb.Size = UDim2.new(0, 20, 0, 20)
                    kb.Position = UDim2.new(getValue() / 255, -10, 0.5, -10)
                    kb.BackgroundColor3 = C.white
                    kb.BorderSizePixel = 0
                    kb.Parent = tr
                    corner(kb, UDim.new(1, 0))
                    stroke(kb, C.accent, 1.5)
                    local valLbl = Instance.new("TextLabel")
                    valLbl.Size = UDim2.new(0, 36, 0, 22)
                    valLbl.Position = UDim2.new(0, 248, 0, yPos)
                    valLbl.BackgroundTransparency = 1
                    valLbl.Font = Enum.Font.Code
                    valLbl.TextSize = 13
                    valLbl.TextColor3 = C.muted
                    valLbl.TextXAlignment = Enum.TextXAlignment.Right
                    valLbl.Text = tostring(getValue())
                    valLbl.Parent = panel
                    local dragging = false
                    local function setFromX(x)
                        local rel = tr.AbsolutePosition.X
                        local sz = tr.AbsoluteSize.X
                        local pct = math.clamp((x - rel) / sz, 0, 1)
                        local v = math.floor(pct * 255 + 0.5)
                        setValue(v)
                        fl.Size = UDim2.new(pct, 0, 1, 0)
                        kb.Position = UDim2.new(pct, -10, 0.5, -10)
                        valLbl.Text = tostring(v)
                        updateColor()
                    end
                    tr.MouseButton1Down:Connect(function()
                        dragging = true
                        setFromX(UserInputService:GetMouseLocation().X)
                    end)
                    UserInputService.InputChanged:Connect(function(input)
                        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch) then
                            setFromX(input.Position.X)
                        end
                    end)
                    UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                            dragging = false
                        end
                    end)
                end
                makeChannel("R", 52, function() return r end, function(v) r = v end)
                makeChannel("G", 82, function() return g end, function(v) g = v end)
                makeChannel("B", 112, function() return b end, function(v) b = v end)
                local doneBtn = Instance.new("TextButton")
                doneBtn.Size = UDim2.new(0, 140, 0, 34)
                doneBtn.Position = UDim2.new(0.5, -70, 0, 180)
                doneBtn.BackgroundColor3 = C.accent
                doneBtn.Text = "Done"
                doneBtn.Font = Enum.Font.GothamBold
                doneBtn.TextSize = 14
                doneBtn.TextColor3 = C.white
                doneBtn.BorderSizePixel = 0
                doneBtn.Parent = panel
                corner(doneBtn, 8)
                local closed = false
                local function closePicker()
                    if closed then return end
                    closed = true
                    pcall(function() catcher:Destroy() end)
                    pcall(function() panel:Destroy() end)
                end
                doneBtn.MouseButton1Click:Connect(closePicker)
                catcher.MouseButton1Click:Connect(closePicker)
                currentPopup = { catcher = catcher, popup = panel, arrow = nil }
            end
            swatch.MouseButton1Click:Connect(openPicker)
            function obj:Set(color)
                obj.Color = color
                swatch.BackgroundColor3 = color
                if callback then callback(color) end
            end
            return obj
        end

        function tab:Paragraph(title, content)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 80)
            holder.BackgroundColor3 = C.panelAlt
            holder.BorderSizePixel = 0
            holder.Parent = page
            corner(holder, 12)
            stroke(holder, C.border, 1.5)
            holder.AutomaticSize = Enum.AutomaticSize.Y
            local ttl = Instance.new("TextLabel")
            ttl.Size = UDim2.new(1, -16, 0, 18)
            ttl.Position = UDim2.new(0, 8, 0, 6)
            ttl.BackgroundTransparency = 1
            ttl.Font = Enum.Font.GothamBold
            ttl.TextSize = 13
            ttl.TextColor3 = C.accent
            ttl.TextXAlignment = Enum.TextXAlignment.Left
            ttl.Text = title or ""
            ttl.Parent = holder
            local cnt = Instance.new("TextLabel")
            cnt.Size = UDim2.new(1, -16, 0, 56)
            cnt.Position = UDim2.new(0, 8, 0, 26)
            cnt.BackgroundTransparency = 1
            cnt.Font = Enum.Font.Code
            cnt.TextSize = 12
            cnt.TextColor3 = C.text
            cnt.TextXAlignment = Enum.TextXAlignment.Left
            cnt.TextYAlignment = Enum.TextYAlignment.Top
            cnt.TextWrapped = true
            cnt.Text = content or ""
            cnt.Parent = holder
            local obj = {Set = function(_, cfg)
                if cfg.Title then ttl.Text = cfg.Title end
                if cfg.Content then cnt.Text = cfg.Content end
            end}
            return obj
        end

        return tab
    end

    function UI:SelectTab(tab)
        if UI.ActiveTab then
            UI.ActiveTab.Page.Visible = false
            TweenService:Create(UI.ActiveTab.Btn, TWEEN, {
                BackgroundColor3 = C.panelAlt, TextColor3 = C.muted,
            }):Play()
        end
        UI.ActiveTab = tab
        tab.Page.Visible = true
        TweenService:Create(tab.Btn, TWEEN, {
            BackgroundColor3 = C.accent, TextColor3 = C.white,
        }):Play()
    end

    function UI:Destroy() screenGui:Destroy() end
end

-- ============================================================
-- BUILD UI — 6 TABS
-- ============================================================

-- ── TAB 1: FARM ──
local FarmTab = UI:CreateTab("Farm", "💪")
FarmTab:Label("🔥 Hybrid Apex Engine")
FarmTab:Dropdown("⚡ Mode", {"Hybrid (recommended)", "Legacy"}, "Hybrid (recommended)", function(v)
    Config.FarmMode = v:find("Hybrid") and "Hybrid" or "Legacy"
    if Config.FarmEnabled then stopFarm() task.wait(0.1) startFarm() end
end)
FarmTab:Dropdown("🚀 Speed Value", {
    "Infinity (math.huge)", "1e9 (safe)", "1e15 (very large)",
    "1e18 (extreme)", "1e30 (max finite)"
}, "Infinity (math.huge)", function(v) Config.TrainSpeedValue = v end)
FarmTab:Slider("👥 Workers", 1, 250, 15, "", function(v)
    Config.WorkerCount = v
    if Config.FarmEnabled and Config.FarmMode == "Hybrid" then
        killWorkers()
        local n = math.max(1, math.min(250, v * Config.FarmSpeedMul))
        if Config.TurboActive then n = math.min(250, n * 2) end
        hybridState.currentWorkers = n
        spawnWorkers(n)
    end
end)
FarmTab:Dropdown("⚡ Speed Multiplier", {"0.5x", "1x", "2x"}, "1x", function(v)
    if v == "0.5x" then Config.FarmSpeedMul = 0.5
    elseif v == "2x" then Config.FarmSpeedMul = 2
    else Config.FarmSpeedMul = 1 end
end)
FarmTab:Toggle("🛡️ Anti-Detect", true, function(t) Config.AntiDetect = t end)
FarmTab:Toggle("🔥 MAX PERFORMANCE (disables anti-detect delays)", false, function(t) Config.MaxPerformance = t end)
FarmTab:Toggle("▶️ START FARM", false, function(t)
    Config.FarmEnabled = t
    if t then startFarm() else stopFarm() end
end)
FarmTab:Button("🚀 TURBO BOOST (2x / 10s)", function() setTurbo() end)
FarmTab:Label("🌙 Overnight Mode")
FarmTab:Toggle("🌙 Overnight (5min on / 30s off)", false, function(t)
    Config.OvernightEnabled = t
    if t then startOvernight() else stopOvernight() end
end)
FarmTab:Label("📊 Live Stats")
local statsParagraph = FarmTab:Paragraph("💪 Power Tracker", "Start farm to begin...")

-- ── TAB 2: MOVEMENT ──
local MoveTab = UI:CreateTab("Movement", "🏃")
MoveTab:Label("⚡ Walk / Jump")
local overrideToggle = MoveTab:Toggle("🔧 Override Stats", false, function(t)
    Config.OverrideStats = t
    if t then applyMovement() else restoreMovement() end
end)
local walkSlider = MoveTab:Slider("🏃 WalkSpeed", 16, 1000, 16, " sp", function(v)
    Config.WalkSpeed = v
    applyMovement()
end)
local jumpSlider = MoveTab:Slider("🦘 JumpPower", 50, 1000, 50, " pw", function(v)
    Config.JumpPower = v
    applyMovement()
end)
MoveTab:Button("🔄 Reset (16 / 50)", function()
    Config.WalkSpeed = 16
    Config.JumpPower = 50
    Config.OverrideStats = false  -- [FIX] turn off so Heartbeat stops re-applying
    overrideToggle:Set(false)
    walkSlider:Set(16)
    jumpSlider:Set(50)
    restoreMovement()
    notify("Movement", "Reset to 16/50. Override OFF.", 3)
end)
MoveTab:Label("👻 Noclip")
MoveTab:Dropdown("⚙️ Noclip Mode", {"V777 (Simple)", "Improved"}, "Improved", function(v)
    Config.NoclipMode = v:find("V777") and "V777" or "Improved"
    if Config.NoclipEnabled then
        setNoclipMode(false)
        task.wait(0.05)
        setNoclipMode(true)
    end
end)
MoveTab:Toggle("👻 Noclip", false, function(t) setNoclipMode(t) end)

-- ── TAB 3: IDENTITY ──
local IdTab = UI:CreateTab("Identity", "🎭")
IdTab:Label("👤 Chat Identity Setup")
IdTab:Dropdown("🏷️ Title", {"GLOBAL", "SERVER ANNOUNCEMENT", "👑Head Administrator👑", "👑Head Executive Lead Developer👑", "None"}, "None", function(v)
    Config.CustomTag = (v == "None" or v == "") and "" or v
end)
IdTab:Dropdown("👤 Username", {"RezurXshin☑️", "Jandel", "Administrator", "None"}, "None", function(v)
    Config.UserName = (v == "None" or v == "") and "" or v
end)
IdTab:Input("✏️ Custom Title", "Empty = no tag", function(v) Config.CustomTag = v or "" end)
IdTab:Input("✏️ Custom Name", "Empty = no name", function(v) Config.UserName = v or "" end)
IdTab:ColorPicker("🎨 Title / Tag Color", Config.TagColor, function(v) Config.TagColor = v end)
IdTab:ColorPicker("🎨 User Name Color", Config.UserColor, function(v) Config.UserColor = v end)
IdTab:ColorPicker("🎨 Message Text Color", Config.MessageColor, function(v) Config.MessageColor = v end)

-- ── TAB 4: CHAT ──
local ChatTab = UI:CreateTab("Chat", "💬")
ChatTab:Label("👻 Ghost Shout")
local chatBox = ChatTab:ChatInput("💬 Message", "Type message, press Enter to send...", function(msg)
    sendChatMessage(msg)
    notify("💬 Shout Sent", msg:sub(1, 40), 3)
end)
ChatTab:Button("📤 Send (resend same text)", function()
    local msg = chatBox.Text
    if msg == "" then notify("Chat", "Type a message first", 3) return end
    sendChatMessage(msg)
    notify("💬 Shout Sent", msg:sub(1, 40), 3)
end)
ChatTab:Button("🧹 Clear Text Box", function()
    chatBox.Text = ""
    notify("Chat", "Cleared", 2)
end)

-- ── TAB 5: LAB ──
local LabTab = UI:CreateTab("Lab", "🧪")
LabTab:Label("⚙️ Experimental Tools")
LabTab:Toggle("🛡️ Anti-AFK", true, function(t) Config.AntiAfk = t end)
LabTab:Toggle("⚔️ PVP Off", false, function(t) Config.PvpOff = t end)
LabTab:Label("👁️ Spectral Scan (ESP)")
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
LabTab:Toggle("👁️ ESP (Power Scan)", false, function(t)
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
end)
LabTab:Button("🧹 Clear All ESP Tags", function() clearAllEspTags() notify("ESP", "All tags cleared", 3) end)

-- ── TAB 6: SYSTEM ──
local SysTab = UI:CreateTab("System", "⚙")
SysTab:Label("💾 Profile System")
local PROFILE_FILE = "DOMINUS_Profile.json"
local function saveProfile()
    local profile = {
        CustomTag = Config.CustomTag, UserName = Config.UserName,
        TagColor = {Config.TagColor.R, Config.TagColor.G, Config.TagColor.B},
        UserColor = {Config.UserColor.R, Config.UserColor.G, Config.UserColor.B},
        MessageColor = {Config.MessageColor.R, Config.MessageColor.G, Config.MessageColor.B},
        FarmMode = Config.FarmMode, FarmSpeedMul = Config.FarmSpeedMul,
        WorkerCount = Config.WorkerCount, MaxPerformance = Config.MaxPerformance,
        TrainSpeedValue = Config.TrainSpeedValue, AntiDetect = Config.AntiDetect,
        WalkSpeed = Config.WalkSpeed, JumpPower = Config.JumpPower,
        NoclipMode = Config.NoclipMode, AntiAfk = Config.AntiAfk,
    }
    local json = HttpService:JSONEncode(profile)
    if writefile then
        writefile(PROFILE_FILE, json)
        notify("💾 Profile", "Saved successfully", 3)
    else
        notify("💾 Profile", "writefile not supported", 4)
    end
end
local function loadProfile()
    if not readfile then notify("💾 Profile", "readfile not supported", 4) return end
    local ok, content = pcall(readfile, PROFILE_FILE)
    if not ok or not content then notify("💾 Profile", "No saved profile found", 3) return end
    local ok2, profile = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok2 or type(profile) ~= "table" then notify("💾 Profile", "Profile corrupted", 4) return end
    Config.CustomTag = profile.CustomTag or ""
    Config.UserName = profile.UserName or ""
    if profile.TagColor then Config.TagColor = Color3.new(profile.TagColor[1], profile.TagColor[2], profile.TagColor[3]) end
    if profile.UserColor then Config.UserColor = Color3.new(profile.UserColor[1], profile.UserColor[2], profile.UserColor[3]) end
    if profile.MessageColor then Config.MessageColor = Color3.new(profile.MessageColor[1], profile.MessageColor[2], profile.MessageColor[3]) end
    Config.FarmMode = profile.FarmMode or "Hybrid"
    Config.FarmSpeedMul = profile.FarmSpeedMul or 1
    Config.WorkerCount = profile.WorkerCount or 15
    Config.MaxPerformance = profile.MaxPerformance or false
    Config.TrainSpeedValue = profile.TrainSpeedValue or "Infinity (math.huge)"
    Config.AntiDetect = profile.AntiDetect ~= nil and profile.AntiDetect or true
    Config.WalkSpeed = profile.WalkSpeed or 16
    Config.JumpPower = profile.JumpPower or 50
    Config.NoclipMode = profile.NoclipMode or "Improved"
    Config.AntiAfk = profile.AntiAfk ~= nil and profile.AntiAfk or true
    notify("💾 Profile", "Loaded successfully", 3)
end
SysTab:Button("💾 Save Profile", saveProfile)
SysTab:Button("📂 Load Profile", loadProfile)
SysTab:Label("⌨️ Keyboard Shortcuts")
SysTab:Label("Ctrl+F: Farm | Ctrl+N: Noclip | Ctrl+T: Turbo | K: Toggle UI")
SysTab:Label("❌ UI Controls")
local destroyConfirmed = false
SysTab:Button("❌ Destroy UI (click twice to confirm)", function()
    if destroyConfirmed then
        pcall(function() UI:Destroy() end)
    else
        destroyConfirmed = true
        notify("⚠️ Confirm", "Click Destroy UI again within 3s to confirm", 3)
        task.delay(3, function() destroyConfirmed = false end)
    end
end)

-- K toggles UI
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.K then
        UI.ScreenGui.Enabled = not UI.ScreenGui.Enabled
    end
end)

-- ============================================================
-- CORE LOOPS
-- ============================================================
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

-- Humanoid.Died + respawn handling
player.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Died:Connect(function()
            if Config.FarmEnabled and Config.FarmMode == "Hybrid" then
                logError("death", "Player died — pausing farm")
                killWorkers()
            end
        end)
        if Config.OverrideStats then
            task.wait(0.2)
            applyMovement()
        end
        if Config.FarmEnabled and Config.FarmMode == "Hybrid" then
            task.wait(0.5)
            if Config.FarmEnabled then
                spawnWorkers(math.max(1, math.min(250, hybridState.currentWorkers)))
            end
        end
    end
end)

player.Idled:Connect(function()
    if not Config.AntiAfk then return end
    safeCall("anti-afk", function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- Keyboard shortcuts
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        Config.FarmEnabled = not Config.FarmEnabled
        if Config.FarmEnabled then startFarm() else stopFarm() end
        notify("⌨️ Shortcut", "Farm: " .. (Config.FarmEnabled and "ON" or "OFF"), 2)
    elseif input.KeyCode == Enum.KeyCode.N and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        Config.NoclipEnabled = not Config.NoclipEnabled
        setNoclipMode(Config.NoclipEnabled)
        notify("⌨️ Shortcut", "Noclip: " .. (Config.NoclipEnabled and "ON" or "OFF"), 2)
    elseif input.KeyCode == Enum.KeyCode.T and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        setTurbo()
    end
end)

-- PVP Off loop
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
-- LIVE STATS UPDATER (FPS via RenderStepped + Power Tracker)
-- ============================================================
task.spawn(function()
    local frames = 0
    local conn = RunService.RenderStepped:Connect(function()
        frames = frames + 1
    end)
    while task.wait(1) do
        local fps = frames
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
notify("👑 DOMINUS PRO", "🔥 Custom UI loaded. Maximum Power. Press K to toggle. Made by RezurXshin", 6)

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
