--[[
    ╔══════════════════════════════════════════════════════════╗
    ║  👑 RezurXLab | V1500🔥 OVERNIGHT APEX                    ║
    ╠══════════════════════════════════════════════════════════╣
    ║  THE MASTERPIECE BUILD                                    ║
    ║                                                          ║
    ║  UI: Custom RezurXLab glass-morphism, sidebar tabs,      ║
    ║      RichText logo, animated controls, mobile+desktop    ║
    ║      dragging, minimize/close, boot animation            ║
    ║                                                          ║
    ║  FARM ENGINE V2:                                         ║
    ║    • MultiWorker V2: generation-based lifecycle (clean   ║
    ║      shutdown), 20 max workers, staggered firing (5ms    ║
    ║      offsets), persistent loops (not per-frame spawns)   ║
    ║    • Overnight Mode: 5min work / 30s break cycles,       ║
    ║      forced low workers, GC during breaks, FPS emergency ║
    ║      pause, auto-remote-heal, no turbo, anti-detect ON   ║
    ║    • Legacy + Smart modes preserved                      ║
    ║    • Power tracker with live gains/sec display           ║
    ║                                                          ║
    ║  NOCLIP:                                                 ║
    ║    • V777 Simple (preserved exactly)                     ║
    ║    • Improved (smart filtering, auto-restore, respawn)   ║
    ║                                                          ║
    ║  TABS: Farm / Movement / Identity / System               ║
    ║  (Spectral/ESP removed — re-add if needed)               ║
    ║                                                          ║
    ║  Lua 5.1 compatible: no goto, no +=, unpack shim         ║
    ╚══════════════════════════════════════════════════════════╝
]]

-- ============================================================
-- ERROR LOG (early init — before anything can fail)
-- ============================================================
if not _G.__V1500_ERRORS then _G.__V1500_ERRORS = {} end
local ERR_LOG = _G.__V1500_ERRORS

local function logError(source, msg)
    local entry = {
        timeStr = os.date("%H:%M:%S"),
        source  = source,
        msg     = tostring(msg),
    }
    ERR_LOG[#ERR_LOG + 1] = entry
    if #ERR_LOG > 200 then table.remove(ERR_LOG, 1) end
    warn(string.format("[V1500] %s: %s", source, msg))
end

local function safeCall(source, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then logError(source, err) end
    return ok, err
end

-- ============================================================
-- ON-SCREEN ERROR BOX (top-level crash catcher)
-- ============================================================
local function showErrorToUser(msg)
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local sg = Instance.new("ScreenGui")
        sg.Name = "V1500_Error"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
        sg.Parent = CoreGui
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 540, 0, 220)
        f.Position = UDim2.new(0.5, -270, 0.5, -110)
        f.BackgroundColor3 = Color3.fromRGB(35, 0, 0); f.Parent = sg
        local c = Instance.new("UICorner") c.CornerRadius = UDim2.new(0, 10, 0, 10) c.Parent = f
        local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(220, 30, 30) s.Thickness = 2 s.Parent = f
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -24, 1, -24); t.Position = UDim2.new(0, 12, 0, 12)
        t.BackgroundTransparency = 1; t.Font = Enum.Font.Code; t.TextSize = 13
        t.TextColor3 = Color3.fromRGB(255, 230, 230); t.TextWrapped = true
        t.TextXAlignment = Enum.TextXAlignment.Left; t.TextYAlignment = Enum.TextYAlignment.Top
        t.Text = "V1500 ERROR:\n\n" .. tostring(msg); t.Parent = f
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
local player            = Players.LocalPlayer

-- ============================================================
-- FORWARD DECLARATIONS
-- ============================================================
local applyMovement, restoreMovement
local executePump, legacyDoTrain, multiWorkerDoTrain, smartDoTrain
local sendChatMessage
local initAllRemotes, healRemotes
local notify
local setTurbo
local startFarm, stopFarm
local startOvernight, stopOvernight
local setNoclipMode
local powerTracker

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
    FarmMode = "MultiWorker",   -- Legacy / MultiWorker / Smart
    FarmEnabled = false,
    FarmSpeedMul = 1,
    WorkerCount = 5,
    -- Overnight
    OvernightEnabled = false,
    -- Movement
    OverrideStats = false,
    WalkSpeed = 16, JumpPower = 50,
    -- Noclip
    NoclipEnabled = false,
    NoclipMode = "Improved",  -- "V777" or "Improved"
    -- Other
    AntiAfk = true,
    AntiDetect = true,
    -- Turbo
    TurboActive = false,
    TurboUntil = 0,
    TurboCooldownUntil = 0,
}

-- ============================================================
-- THEME — RezurXLab aesthetic
-- ============================================================
local C = {
    bg       = Color3.fromRGB(13, 13, 18),
    panel    = Color3.fromRGB(20, 20, 30),
    panelAlt = Color3.fromRGB(17, 17, 24),
    accent   = Color3.fromRGB(255, 115, 30),
    accentDim= Color3.fromRGB(204, 92, 24),
    inputBg  = Color3.fromRGB(20, 20, 30),
    text     = Color3.fromRGB(225, 225, 235),
    muted    = Color3.fromRGB(100, 100, 125),
    green    = Color3.fromRGB(50, 200, 95),
    red      = Color3.fromRGB(210, 65, 65),
    border   = Color3.fromRGB(38, 38, 55),
    white    = Color3.fromRGB(255, 255, 255),
    sidebar  = Color3.fromRGB(16, 16, 22),
    tabActive= Color3.fromRGB(255, 115, 30),
    tabHover = Color3.fromRGB(35, 35, 48),
    track    = Color3.fromRGB(45, 45, 60),
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

local unpack = unpack or table.unpack  -- Lua 5.1 compat

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
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or C.border
    s.Thickness = thickness or 1
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
-- REMOTE MANAGER (self-healing)
-- ============================================================
local Remotes = {}

initAllRemotes = function()
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
end
healRemotes = initAllRemotes
initAllRemotes()

-- Periodic re-init every 30s
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
    samples = {}, history = {},
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
    powerTracker.history = {}
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
-- APEX FARM ENGINE V2
-- ============================================================
local TRAIN_SPEED = 1e9

-- Shared pump logic (15 calls, anti-detect shuffles + jitters)
executePump = function(r, speed)
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
        if Config.AntiDetect and math.random() < 0.3 then
            task.wait(math.random() * 0.003)
        end
    end
end

-- Mode 1: Legacy (single pump per Heartbeat)
legacyDoTrain = function()
    if not Remotes.ApplyAddFrenzyValue then healRemotes() end
    if not Remotes.ApplyAddFrenzyValue then return end
    executePump(Remotes, TRAIN_SPEED)
end

-- Mode 2: MultiWorker V2 — generation-based persistent workers
-- KEY IMPROVEMENT: Workers are persistent loops, NOT per-frame task.spawn.
-- This means 20 workers = 20 threads total, not 1200 threads/sec.
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
            -- Stagger: each worker starts with a small offset so they don't all fire simultaneously
            task.wait((workerId - 1) * 0.005)
            while gen == workerGeneration and Config.FarmEnabled do
                if not Remotes.ApplyAddFrenzyValue then healRemotes() end
                if Remotes.ApplyAddFrenzyValue then
                    pcall(executePump, Remotes, TRAIN_SPEED)
                end
                -- Staggered yield: each worker waits slightly different time
                -- This spreads load across the frame instead of bursting
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

multiWorkerDoTrain = function()
    -- This mode is handled by spawnWorkers/killWorkers, not per-frame.
    -- The function exists for compatibility but does nothing per Heartbeat.
    -- Workers are persistent loops started in startFarm().
end

-- Mode 3: Smart — auto-tunes worker count
local smartWorkerCount = 3
local smartLastAdjust = 0
local smartFpsHistory = {}

smartDoTrain = function()
    -- Auto-tune every 3s (handled in startFarm for Smart mode)
    -- Per Heartbeat: just fire with current worker count via task.spawn
    if not Remotes.ApplyAddFrenzyValue then healRemotes() end
    if not Remotes.ApplyAddFrenzyValue then return end
    local turboMul = Config.TurboActive and 2 or 1
    local n = math.max(1, math.floor(smartWorkerCount * turboMul * Config.FarmSpeedMul))
    for _ = 1, n do
        task.spawn(function() pcall(executePump, Remotes, TRAIN_SPEED) end)
    end
end

-- Farm controller
local farmHeartbeatConn = nil
local smartTuneConn = nil

startFarm = function()
    if farmHeartbeatConn then farmHeartbeatConn:Disconnect() farmHeartbeatConn = nil end
    if smartTuneConn then smartTuneConn:Disconnect() smartTuneConn = nil end
    powerTracker.startSession()

    if Config.FarmMode == "MultiWorker" then
        -- V2: persistent workers
        local n = math.max(1, math.min(20, Config.WorkerCount * Config.FarmSpeedMul))
        if Config.TurboActive then n = math.min(20, n * 2) end
        spawnWorkers(n)
    elseif Config.FarmMode == "Smart" then
        -- Smart: Heartbeat + auto-tune
        farmHeartbeatConn = RunService.Heartbeat:Connect(function()
            safeCall("farm-smart", smartDoTrain)
        end)
        smartTuneConn = RunService.Heartbeat:Connect(function()
            local now = tick()
            if now - smartLastAdjust >= 3 then
                smartLastAdjust = now
                local avgGains = powerTracker.avgGainsPerSec()
                local trend = powerTracker.trend()
                -- FPS check
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
                -- Decision
                if avgFps < 25 then
                    smartWorkerCount = math.max(1, smartWorkerCount - 1)
                elseif trend == "down" and smartWorkerCount > 2 then
                    smartWorkerCount = math.max(1, smartWorkerCount - 1)
                elseif trend == "up" and avgFps > 50 and smartWorkerCount < 20 then
                    smartWorkerCount = math.min(20, smartWorkerCount + 1)
                elseif trend == "flat" and avgFps > 50 and smartWorkerCount < 15 then
                    smartWorkerCount = math.min(15, smartWorkerCount + 1)
                end
            end
        end)
    else
        -- Legacy: Heartbeat pump
        farmHeartbeatConn = RunService.Heartbeat:Connect(function()
            safeCall("farm-legacy", legacyDoTrain)
        end)
    end
end

stopFarm = function()
    if farmHeartbeatConn then farmHeartbeatConn:Disconnect() farmHeartbeatConn = nil end
    if smartTuneConn then smartTuneConn:Disconnect() smartTuneConn = nil end
    killWorkers()
end

-- ============================================================
-- OVERNIGHT MODE — farm overnight without crashing
-- ============================================================
-- 5min work / 30s break cycles. Forces low workers, anti-detect ON,
-- turbo OFF. Runs GC during breaks. FPS emergency pause if needed.
local overnightConn = nil
local overnightOriginal = {}
local overnightPhase = "idle"  -- "work" / "break" / "emergency"

startOvernight = function()
    if overnightConn then return end
    -- Save original settings
    overnightOriginal.FarmMode = Config.FarmMode
    overnightOriginal.WorkerCount = Config.WorkerCount
    overnightOriginal.AntiDetect = Config.AntiDetect
    overnightOriginal.TurboActive = Config.TurboActive
    -- Force safe settings
    Config.FarmMode = "MultiWorker"
    Config.WorkerCount = 2  -- low for stability
    Config.AntiDetect = true
    Config.TurboActive = false
    Config.TurboUntil = 0
    -- Start farm
    Config.FarmEnabled = true
    startFarm()
    overnightPhase = "work"
    logError("overnight", "Started — 5min work / 30s break cycles")
    -- Cycle watcher
    local cycleStart = tick()
    local WORK_DUR = 300  -- 5 min
    local BREAK_DUR = 30  -- 30s
    local lastFpsCheck = tick()
    local fpsLowStreak = 0
    overnightConn = RunService.Heartbeat:Connect(function()
        local now = tick()
        -- FPS emergency check (every 5s)
        if now - lastFpsCheck >= 5 then
            lastFpsCheck = now
            local fpsT0 = tick()
            local fpsCount = 0
            local fc = RunService.Heartbeat:Connect(function()
                fpsCount = fpsCount + 1
            end)
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
                            spawnWorkers(2)
                            logError("overnight", "Resumed after emergency")
                        end
                    end)
                end
            else
                fpsLowStreak = 0
            end
        end
        -- Cycle management
        if overnightPhase == "work" and now - cycleStart >= WORK_DUR then
            overnightPhase = "break"
            killWorkers()
            collectgarbage("collect")
            logError("overnight", "Break — GC + 30s rest")
            task.delay(BREAK_DUR, function()
                if Config.OvernightEnabled then
                    overnightPhase = "work"
                    cycleStart = tick()
                    spawnWorkers(2)
                    logError("overnight", "Work cycle resumed")
                end
            end)
        end
    end)
end

stopOvernight = function()
    if overnightConn then overnightConn:Disconnect() overnightConn = nil end
    -- Restore original settings
    Config.FarmMode = overnightOriginal.FarmMode or "MultiWorker"
    Config.WorkerCount = overnightOriginal.WorkerCount or 5
    Config.AntiDetect = overnightOriginal.AntiDetect ~= nil and overnightOriginal.AntiDetect or true
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
    -- If MultiWorker, restart with doubled count
    if Config.FarmMode == "MultiWorker" and Config.FarmEnabled then
        killWorkers()
        local n = math.max(1, math.min(20, Config.WorkerCount * Config.FarmSpeedMul * 2))
        spawnWorkers(n)
    end
    task.spawn(function()
        while Config.TurboActive and tick() < Config.TurboUntil do
            task.wait(0.5)
        end
        Config.TurboActive = false
        Config.TurboCooldownUntil = tick() + TURBO_CD
        -- Restart with normal count
        if Config.FarmMode == "MultiWorker" and Config.FarmEnabled then
            killWorkers()
            local n = math.max(1, math.min(20, Config.WorkerCount * Config.FarmSpeedMul))
            spawnWorkers(n)
        end
        notify("Turbo End", "Cooldown 5s", 3)
    end)
end

-- ============================================================
-- CHAT
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
        safeCall("chat", function() Remotes.SendTextChatMessage:InvokeServer(full) end)
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
-- NOCLIP — V777 Simple + Improved
-- ============================================================
local noclipConn = nil

setNoclipMode = function(enabled)
    Config.NoclipEnabled = enabled
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if not enabled then
        -- Restore collisions on disable (Improved mode only)
        if Config.NoclipMode == "Improved" then
            pcall(function()
                local char = player.Character
                if not char then return end
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
                        v.CanCollide = true
                    end
                end
            end)
        end
        return
    end
    -- Start noclip connection
    if Config.NoclipMode == "V777" then
        -- V777 EXACT: touch every BasePart every Stepped
        noclipConn = RunService.Stepped:Connect(function()
            local char = player.Character
            if char then
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)
    else
        -- IMPROVED: skip already-non-collide, skip HumanoidRootPart
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

-- ============================================================
-- CUSTOM UI LIBRARY — RezurXLab glass-morphism with sidebar tabs
-- ============================================================
local UI = {}

do
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RezurXLab_V1500"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    pcall(function() screenGui.Parent = CoreGui end)
    if not screenGui.Parent then
        screenGui.Parent = player:WaitForChild("PlayerGui")
    end
    UI.ScreenGui = screenGui

    -- Main window frame
    local WIN_W, WIN_H = 340, 400
    local frame = Instance.new("Frame")
    frame.Name = "Window"
    frame.Size = UDim2.new(0, WIN_W, 0, WIN_H)
    frame.Position = UDim2.new(0.5, -WIN_W/2, 0.4, -WIN_H/2)
    frame.BackgroundColor3 = C.bg
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = screenGui
    corner(frame, 14)
    stroke(frame, C.border, 1.5)
    -- Subtle gradient overlay
    gradient(frame, ColorSequence.new(C.bg, Color3.fromRGB(8, 8, 12)), 90)
    UI.Frame = frame

    -- Boot animation: scale up from 0.8
    frame.Size = UDim2.new(0, WIN_W, 0, 0)
    frame.BackgroundTransparency = 1
    TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, WIN_W, 0, WIN_H),
        BackgroundTransparency = 0,
    }):Play()

    -- ── HEADER ──
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = C.panel
    header.BorderSizePixel = 0
    header.Parent = frame
    corner(header, 14)

    -- Square off header bottom corners
    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0.5, 0)
    headerFix.Position = UDim2.new(0, 0, 0.5, 0)
    headerFix.BackgroundColor3 = C.panel
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header

    -- Orange accent line
    local accentLine = Instance.new("Frame")
    accentLine.Size = UDim2.new(1, 0, 0, 2)
    accentLine.Position = UDim2.new(0, 0, 1, -2)
    accentLine.BackgroundColor3 = C.accent
    accentLine.BorderSizePixel = 0
    accentLine.Parent = header

    -- Logo: RezurX white + Lab orange
    local logo = Instance.new("TextLabel")
    logo.RichText = true
    logo.Text = '<font color="#E1E1EB">RezurX</font><font color="#FF731E">Lab</font>'
    logo.Size = UDim2.new(0, 160, 0, 26)
    logo.Position = UDim2.new(0, 14, 0, 5)
    logo.BackgroundTransparency = 1
    logo.TextColor3 = C.text
    logo.TextSize = 20
    logo.Font = Enum.Font.GothamBold
    logo.TextXAlignment = Enum.TextXAlignment.Left
    logo.Parent = header

    -- Subtitle
    local sub = Instance.new("TextLabel")
    sub.Text = "V1500 Overnight Apex"
    sub.Size = UDim2.new(0, 160, 0, 14)
    sub.Position = UDim2.new(0, 15, 0, 30)
    sub.BackgroundTransparency = 1
    sub.TextColor3 = C.muted
    sub.TextSize = 11
    sub.Font = Enum.Font.Gotham
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = header

    -- FPS counter (top right of header)
    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Size = UDim2.new(0, 56, 0, 22)
    fpsLabel.Position = UDim2.new(1, -90, 0.5, -11)
    fpsLabel.BackgroundColor3 = C.panelAlt
    fpsLabel.BackgroundTransparency = 0.3
    fpsLabel.Font = Enum.Font.Code
    fpsLabel.TextSize = 11
    fpsLabel.TextColor3 = C.green
    fpsLabel.Text = "60 FPS"
    fpsLabel.Parent = header
    corner(fpsLabel, 6)
    UI.FpsLabel = fpsLabel

    -- Minimize button
    local minBtn = Instance.new("TextButton")
    minBtn.Text = "—"
    minBtn.Size = UDim2.new(0, 26, 0, 26)
    minBtn.Position = UDim2.new(1, -58, 0.5, -13)
    minBtn.BackgroundColor3 = C.panelAlt
    minBtn.TextColor3 = C.muted
    minBtn.TextSize = 16
    minBtn.Font = Enum.Font.GothamBold
    minBtn.BorderSizePixel = 0
    minBtn.AutoButtonColor = false
    minBtn.Parent = header
    corner(minBtn, 6)
    stroke(minBtn, C.border)

    local minimized = false
    minBtn.MouseEnter:Connect(function()
        TweenService:Create(minBtn, TWEEN_FAST, {BackgroundColor3 = C.tabHover, TextColor3 = C.text}):Play()
    end)
    minBtn.MouseLeave:Connect(function()
        TweenService:Create(minBtn, TWEEN_FAST, {BackgroundColor3 = C.panelAlt, TextColor3 = C.muted}):Play()
    end)
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        local targetH = minimized and 50 or WIN_H
        TweenService:Create(frame, TWEEN, {Size = UDim2.new(0, WIN_W, 0, targetH)}):Play()
        minBtn.Text = minimized and "+" or "—"
    end)

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Text = "✕"
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -28, 0.5, -13)
    closeBtn.BackgroundColor3 = C.red
    closeBtn.TextColor3 = C.white
    closeBtn.TextSize = 12
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = header
    corner(closeBtn, 6)
    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TWEEN_FAST, {BackgroundColor3 = Color3.fromRGB(230, 80, 80)}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TWEEN_FAST, {BackgroundColor3 = C.red}):Play()
    end)
    closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

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

    -- ── SIDEBAR ──
    local SIDEBAR_W = 90
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -52)
    sidebar.Position = UDim2.new(0, 0, 0, 52)
    sidebar.BackgroundColor3 = C.sidebar
    sidebar.BorderSizePixel = 0
    sidebar.Parent = frame

    local sbLayout = Instance.new("UIListLayout")
    sbLayout.Padding = UDim.new(0, 4)
    sbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sbLayout.Parent = sidebar

    local sbPad = Instance.new("UIPadding")
    sbPad.PaddingTop = UDim.new(0, 6)
    sbPad.Parent = sidebar

    -- ── CONTENT AREA ──
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -SIDEBAR_W - 4, 1, -56)
    content.Position = UDim2.new(0, SIDEBAR_W + 2, 0, 54)
    content.BackgroundTransparency = 1
    content.Parent = frame
    UI.Content = content

    UI.Tabs = {}
    UI.ActiveTab = nil

    -- ============================================================
    -- GLOBAL DROPDOWN MANAGER
    -- Only one dropdown open at a time. List is parented to ScreenGui
    -- (NOT the page/holder) so it NEVER gets clipped by ScrollingFrame.
    -- A full-screen transparent TextButton catches outside clicks.
    -- ============================================================
    local currentDropdown = nil
    local function closeCurrentDropdown()
        if currentDropdown then
            if currentDropdown.catcher then pcall(function() currentDropdown.catcher:Destroy() end) end
            if currentDropdown.list then pcall(function() currentDropdown.list:Destroy() end) end
            if currentDropdown.arrow then pcall(function() currentDropdown.arrow.Text = "▼" end) end
            currentDropdown = nil
        end
    end
    UI.CloseCurrentDropdown = closeCurrentDropdown

    -- Notification container
    local notifContainer = Instance.new("Frame")
    notifContainer.Size = UDim2.new(0, 280, 1, -20)
    notifContainer.Position = UDim2.new(1, -290, 0, 10)
    notifContainer.BackgroundTransparency = 1
    notifContainer.Parent = screenGui
    local nLayout = Instance.new("UIListLayout")
    nLayout.Padding = UDim.new(0, 6)
    nLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    nLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    nLayout.Parent = notifContainer

    -- ============================================================
    -- WINDOW METHODS
    -- ============================================================
    function UI:Notify(cfg)
        local n = Instance.new("Frame")
        n.Size = UDim2.new(1, 0, 0, 56)
        n.BackgroundColor3 = C.panel
        n.BackgroundTransparency = 0.05
        n.Parent = notifContainer
        corner(n, 8)
        stroke(n, C.accent, 1.5)
        gradient(n, ColorSequence.new(C.panel, C.panelAlt), 90)

        local ttl = Instance.new("TextLabel")
        ttl.Size = UDim2.new(1, -14, 0, 16)
        ttl.Position = UDim2.new(0, 7, 0, 5)
        ttl.BackgroundTransparency = 1
        ttl.Font = Enum.Font.GothamBold
        ttl.TextSize = 12
        ttl.TextColor3 = C.accent
        ttl.TextXAlignment = Enum.TextXAlignment.Left
        ttl.Text = cfg.Title or "V1500"
        ttl.Parent = n

        local cnt = Instance.new("TextLabel")
        cnt.Size = UDim2.new(1, -14, 0, 28)
        cnt.Position = UDim2.new(0, 7, 0, 22)
        cnt.BackgroundTransparency = 1
        cnt.Font = Enum.Font.Gotham
        cnt.TextSize = 11
        cnt.TextColor3 = C.text
        cnt.TextXAlignment = Enum.TextXAlignment.Left
        cnt.TextYAlignment = Enum.TextYAlignment.Top
        cnt.TextWrapped = true
        cnt.Text = cfg.Content or ""
        cnt.Parent = n

        -- Slide-in animation
        n.Size = UDim2.new(1, 0, 0, 0)
        n.BackgroundTransparency = 1
        TweenService:Create(n, TWEEN, {
            Size = UDim2.new(1, 0, 0, 56),
            BackgroundTransparency = 0.05,
        }):Play()

        task.delay(cfg.Duration or 5, function()
            local t = TweenService:Create(n, TWEEN, {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
            })
            t:Play()
            t.Completed:Connect(function() n:Destroy() end)
        end)
    end

    notify = function(t, c, d) UI:Notify({Title = t, Content = c, Duration = d or 5}) end

    function UI:CreateTab(name, icon)
        local tab = {}

        -- Tab button in sidebar
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 82, 0, 32)
        btn.BackgroundColor3 = C.panelAlt
        btn.Text = (icon or "") .. " " .. name
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 10
        btn.TextColor3 = C.muted
        btn.TextWrapped = true
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.Parent = sidebar
        corner(btn, 6)

        -- Page (scrolling frame)
        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = C.accent
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Visible = false
        page.Parent = content

        local pLayout = Instance.new("UIListLayout")
        pLayout.Padding = UDim.new(0, 6)
        pLayout.Parent = page

        local pPad = Instance.new("UIPadding")
        pPad.PaddingTop = UDim.new(0, 4)
        pPad.PaddingLeft = UDim.new(0, 4)
        pPad.PaddingRight = UDim.new(0, 4)
        pPad.Parent = page

        -- Manual canvas size tracking (more reliable than AutomaticCanvasSize)
        local function updateCanvas()
            page.CanvasSize = UDim2.new(0, 0, 0, pLayout.AbsoluteContentSize.Y + 12)
        end
        pLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
        updateCanvas()

        tab.Page = page
        tab.Btn = btn
        tab.Name = name

        -- Hover/active animations
        btn.MouseEnter:Connect(function()
            if UI.ActiveTab ~= tab then
                TweenService:Create(btn, TWEEN_FAST, {
                    BackgroundColor3 = C.tabHover, TextColor3 = C.text,
                }):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if UI.ActiveTab ~= tab then
                TweenService:Create(btn, TWEEN_FAST, {
                    BackgroundColor3 = C.panelAlt, TextColor3 = C.muted,
                }):Play()
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
            l.Size = UDim2.new(1, 0, 0, 20)
            l.BackgroundTransparency = 1
            l.Font = Enum.Font.GothamBold
            l.TextSize = 11
            l.TextColor3 = C.accent
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Text = "  " .. text
            l.Parent = page
            return l
        end

        function tab:Button(name, callback)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 34)
            b.BackgroundColor3 = C.panel
            b.Text = "  " .. name
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 12
            b.TextColor3 = C.text
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.AutoButtonColor = false
            b.BorderSizePixel = 0
            b.Parent = page
            corner(b, 8)
            stroke(b, C.border)
            gradient(b, ColorSequence.new(C.panel, C.panelAlt), 90)

            b.MouseEnter:Connect(function()
                TweenService:Create(b, TWEEN_FAST, {BackgroundColor3 = C.tabHover}):Play()
            end)
            b.MouseLeave:Connect(function()
                TweenService:Create(b, TWEEN_FAST, {BackgroundColor3 = C.panel}):Play()
            end)
            b.MouseButton1Click:Connect(function()
                -- Click flash
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
            holder.Size = UDim2.new(1, 0, 0, 34)
            holder.BackgroundColor3 = C.panel
            holder.BorderSizePixel = 0
            holder.Parent = page
            corner(holder, 8)
            stroke(holder, C.border)
            gradient(holder, ColorSequence.new(C.panel, C.panelAlt), 90)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -56, 1, 0)
            lbl.Position = UDim2.new(0, 10, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 12
            lbl.TextColor3 = C.text
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = "  " .. name
            lbl.Parent = holder

            -- Switch track
            local sw = Instance.new("Frame")
            sw.Size = UDim2.new(0, 38, 0, 20)
            sw.Position = UDim2.new(1, -46, 0.5, -10)
            sw.BackgroundColor3 = state and C.accent or C.track
            sw.Parent = holder
            corner(sw, UDim.new(1, 0))

            -- Knob
            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 16, 0, 16)
            knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            knob.BackgroundColor3 = C.white
            knob.Parent = sw
            corner(knob, UDim.new(1, 0))

            local obj = {Set = function(_, v)
                state = v
                TweenService:Create(sw, TWEEN, {BackgroundColor3 = state and C.accent or C.track}):Play()
                TweenService:Create(knob, TWEEN, {
                    Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
                }):Play()
                if callback then callback(state) end
            end, Get = function() return state end}

            holder.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    state = not state
                    TweenService:Create(sw, TWEEN, {BackgroundColor3 = state and C.accent or C.track}):Play()
                    TweenService:Create(knob, TWEEN, {
                        Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
                    }):Play()
                    if callback then callback(state) end
                end
            end)
            return obj
        end

        function tab:Slider(name, minVal, maxVal, default, suffix, callback)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 42)
            holder.BackgroundColor3 = C.panel
            holder.BorderSizePixel = 0
            holder.Parent = page
            corner(holder, 8)
            stroke(holder, C.border)
            gradient(holder, ColorSequence.new(C.panel, C.panelAlt), 90)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -70, 0, 16)
            lbl.Position = UDim2.new(0, 10, 0, 4)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 11
            lbl.TextColor3 = C.text
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = "  " .. name
            lbl.Parent = holder

            local valLbl = Instance.new("TextLabel")
            valLbl.Size = UDim2.new(0, 56, 0, 16)
            valLbl.Position = UDim2.new(1, -62, 0, 4)
            valLbl.BackgroundTransparency = 1
            valLbl.Font = Enum.Font.GothamBold
            valLbl.TextSize = 11
            valLbl.TextColor3 = C.accent
            valLbl.TextXAlignment = Enum.TextXAlignment.Right
            valLbl.Text = tostring(default) .. (suffix or "")
            valLbl.Parent = holder

            local track = Instance.new("Frame")
            track.Size = UDim2.new(1, -20, 0, 5)
            track.Position = UDim2.new(0, 10, 0, 28)
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
            knob.Size = UDim2.new(0, 12, 0, 12)
            knob.Position = UDim2.new(0, -6, 0.5, -6)
            knob.BackgroundColor3 = C.white
            knob.BorderSizePixel = 0
            knob.Parent = track
            corner(knob, UDim.new(1, 0))

            local value = default
            local function update()
                local pct = (value - minVal) / (maxVal - minVal)
                pct = math.clamp(pct, 0, 1)
                TweenService:Create(fill, TWEEN_FAST, {Size = UDim2.new(pct, 0, 1, 0)}):Play()
                TweenService:Create(knob, TWEEN_FAST, {Position = UDim2.new(pct, -6, 0.5, -6)}):Play()
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
            holder.Size = UDim2.new(1, 0, 0, 40)
            holder.BackgroundColor3 = C.panel
            holder.BorderSizePixel = 0
            holder.Parent = page
            corner(holder, 8)
            stroke(holder, C.border)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -14, 0, 14)
            lbl.Position = UDim2.new(0, 10, 0, 4)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 10
            lbl.TextColor3 = C.muted
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = "  " .. name
            lbl.Parent = holder

            local box = Instance.new("TextBox")
            box.Size = UDim2.new(1, -20, 0, 16)
            box.Position = UDim2.new(0, 10, 0, 20)
            box.BackgroundTransparency = 1
            box.Font = Enum.Font.Gotham
            box.TextSize = 12
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

        function tab:Dropdown(name, options, default, callback)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 34)
            holder.BackgroundColor3 = C.panel
            holder.BorderSizePixel = 0
            holder.Parent = page
            corner(holder, 8)
            stroke(holder, C.border)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -30, 1, 0)
            lbl.Position = UDim2.new(0, 10, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 11
            lbl.TextColor3 = C.text
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = "  " .. name .. ": " .. (default or options[1] or "")
            lbl.Parent = holder

            local arrow = Instance.new("TextLabel")
            arrow.Size = UDim2.new(0, 20, 1, 0)
            arrow.Position = UDim2.new(1, -24, 0, 0)
            arrow.BackgroundTransparency = 1
            arrow.Font = Enum.Font.GothamBold
            arrow.TextSize = 12
            arrow.TextColor3 = C.muted
            arrow.Text = "▼"
            arrow.Parent = holder

            local obj = {Selected = default or options[1] or ""}

            local function openList()
                -- Close any existing dropdown first (global manager)
                closeCurrentDropdown()

                arrow.Text = "▲"

                -- Full-screen transparent click catcher
                -- Parented to screenGui AFTER the frame so it renders on top
                -- and blocks all clicks except to the list (which is above it)
                local catcher = Instance.new("TextButton")
                catcher.Size = UDim2.new(1, 0, 1, 0)
                catcher.BackgroundColor3 = Color3.new(0, 0, 0)
                catcher.BackgroundTransparency = 1
                catcher.Text = ""
                catcher.AutoButtonColor = false
                catcher.Parent = screenGui

                -- Calculate list position — below holder, or above if not enough space
                local holderPos = holder.AbsolutePosition
                local holderSize = holder.AbsoluteSize
                local itemH = 26
                local listH = #options * (itemH + 2) + 8
                local cam = workspace.CurrentCamera
                local viewportH = cam and cam.ViewportSize.Y or 800
                local openDownward = (holderPos.Y + holderSize.Y + listH + 4 <= viewportH)
                local listY = openDownward
                    and (holderPos.Y + holderSize.Y + 4)
                    or (holderPos.Y - listH - 4)

                -- The list is parented to screenGui (NOT the page/holder)
                -- so it NEVER gets clipped by the ScrollingFrame
                local list = Instance.new("Frame")
                list.Size = UDim2.new(0, holderSize.X, 0, listH)
                list.Position = UDim2.new(0, holderPos.X, 0, listY)
                list.BackgroundColor3 = C.panel
                list.BorderSizePixel = 0
                list.Parent = screenGui
                corner(list, 8)
                stroke(list, C.border)

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
                    item.TextSize = 11
                    item.TextColor3 = C.text
                    item.TextXAlignment = Enum.TextXAlignment.Left
                    item.AutoButtonColor = false
                    item.Parent = list
                    corner(item, 6)
                    item.MouseEnter:Connect(function()
                        TweenService:Create(item, TWEEN_FAST, {BackgroundColor3 = C.accentDim}):Play()
                    end)
                    item.MouseLeave:Connect(function()
                        TweenService:Create(item, TWEEN_FAST, {BackgroundColor3 = C.panelAlt}):Play()
                    end)
                    item.MouseButton1Click:Connect(function()
                        obj.Selected = opt
                        lbl.Text = "  " .. name .. ": " .. opt
                        closeCurrentDropdown()
                        if callback then callback(opt) end
                    end)
                end

                -- Click catcher closes dropdown
                catcher.MouseButton1Click:Connect(function()
                    closeCurrentDropdown()
                end)

                currentDropdown = { catcher = catcher, list = list, arrow = arrow }
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

        function tab:Paragraph(title, content)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 70)
            holder.BackgroundColor3 = C.panelAlt
            holder.BorderSizePixel = 0
            holder.Parent = page
            corner(holder, 8)
            stroke(holder, C.border)
            holder.AutomaticSize = Enum.AutomaticSize.Y

            local ttl = Instance.new("TextLabel")
            ttl.Size = UDim2.new(1, -14, 0, 16)
            ttl.Position = UDim2.new(0, 7, 0, 5)
            ttl.BackgroundTransparency = 1
            ttl.Font = Enum.Font.GothamBold
            ttl.TextSize = 11
            ttl.TextColor3 = C.accent
            ttl.TextXAlignment = Enum.TextXAlignment.Left
            ttl.Text = title or ""
            ttl.Parent = holder

            local cnt = Instance.new("TextLabel")
            cnt.Size = UDim2.new(1, -14, 0, 50)
            cnt.Position = UDim2.new(0, 7, 0, 22)
            cnt.BackgroundTransparency = 1
            cnt.Font = Enum.Font.Code
            cnt.TextSize = 10
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
-- BUILD UI — 4 TABS
-- ============================================================

-- ── TAB 1: FARM ──
local FarmTab = UI:CreateTab("Farm", "💪")
FarmTab:Label("APEX FARM ENGINE")
FarmTab:Dropdown("Mode", {
    "Legacy", "MultiWorker", "Smart"
}, "MultiWorker", function(v)
    Config.FarmMode = v
    -- Restart farm if running
    if Config.FarmEnabled then
        stopFarm()
        task.wait(0.1)
        startFarm()
    end
end)
FarmTab:Slider("Workers", 1, 20, 5, "", function(v)
    Config.WorkerCount = v
    if Config.FarmEnabled and Config.FarmMode == "MultiWorker" then
        killWorkers()
        local n = math.max(1, math.min(20, v * Config.FarmSpeedMul))
        if Config.TurboActive then n = math.min(20, n * 2) end
        spawnWorkers(n)
    end
end)
FarmTab:Dropdown("Speed", {"0.5x", "1x", "2x"}, "1x", function(v)
    if v == "0.5x" then Config.FarmSpeedMul = 0.5
    elseif v == "2x" then Config.FarmSpeedMul = 2
    else Config.FarmSpeedMul = 1 end
end)
FarmTab:Toggle("Anti-Detect", true, function(t) Config.AntiDetect = t end)

local farmToggle = FarmTab:Toggle("START FARM", false, function(t)
    Config.FarmEnabled = t
    if t then startFarm() else stopFarm() end
end)

FarmTab:Button("TURBO BOOST (2x / 10s)", function() setTurbo() end)

FarmTab:Label("OVERNIGHT MODE")
local overnightToggle = FarmTab:Toggle("Overnight (5min on / 30s off)", false, function(t)
    Config.OvernightEnabled = t
    if t then
        -- Disable normal farm toggle (overnight controls it)
        startOvernight()
    else
        stopOvernight()
        farmToggle:Set(false)
    end
end)

FarmTab:Label("LIVE STATS")
local statsParagraph = FarmTab:Paragraph("Power Tracker", "Start farm to begin...")

-- ── TAB 2: MOVEMENT ──
local MoveTab = UI:CreateTab("Movement", "🏃")
MoveTab:Label("WALK / JUMP")
MoveTab:Toggle("Override Stats", false, function(t)
    Config.OverrideStats = t
    if t then applyMovement() else restoreMovement() end
end)
MoveTab:Slider("WalkSpeed", 16, 1000, 16, " sp", function(v)
    Config.WalkSpeed = v
    applyMovement()
end)
MoveTab:Slider("JumpPower", 50, 1000, 50, " pw", function(v)
    Config.JumpPower = v
    applyMovement()
end)
MoveTab:Button("Reset (16 / 50)", function()
    Config.WalkSpeed = 16
    Config.JumpPower = 50
    restoreMovement()
    notify("Movement", "Reset to 16/50", 3)
end)

MoveTab:Label("NOCLIP")
MoveTab:Dropdown("Mode", {"V777 (Simple)", "Improved"}, "Improved", function(v)
    Config.NoclipMode = v:find("V777") and "V777" or "Improved"
    -- Restart noclip if active
    if Config.NoclipEnabled then
        setNoclipMode(false)
        task.wait(0.05)
        setNoclipMode(true)
    end
end)
MoveTab:Toggle("Noclip", false, function(t) setNoclipMode(t) end)

MoveTab:Label("SYSTEM")
MoveTab:Toggle("Anti-AFK", true, function(t) Config.AntiAfk = t end)

-- ── TAB 3: IDENTITY ──
local IdTab = UI:CreateTab("Identity", "🎭")
IdTab:Label("CHAT BYPASS")
IdTab:Dropdown("Title", {"GLOBAL", "SERVER ANNOUNCEMENT", "👑Head Administrator👑", "👑Head Executive Lead Developer👑", "None"}, "None", function(v)
    Config.CustomTag = (v == "None" or v == "") and "" or v
end)
IdTab:Dropdown("Username", {"RezurXshin☑️", "Jandel", "Administrator", "None"}, "None", function(v)
    Config.UserName = (v == "None" or v == "") and "" or v
end)
IdTab:Input("Custom Title", "Empty = no tag", function(v) Config.CustomTag = v or "" end)
IdTab:Input("Custom Name", "Empty = no name", function(v) Config.UserName = v or "" end)
IdTab:Input("Send Shout", "Type message...", function(msg) sendChatMessage(msg) end)
IdTab:Button("Re-scan Chat Remote", function()
    healRemotes()
    notify("Chat", Remotes.SendTextChatMessage and "Found" or "Missing", 4)
end)

-- ── TAB 4: SYSTEM ──
local SysTab = UI:CreateTab("System", "⚙")
SysTab:Label("REMOTE STATUS")
SysTab:Button("Show Remote Status", function()
    healRemotes()
    notify("Remotes",
        "Frenzy:" .. (Remotes.ApplyAddFrenzyValue and "Y" or "N") ..
        " Speed:" .. (Remotes.TrainSpeedHasChanged and "Y" or "N") ..
        " Mobile:" .. (Remotes.ApplyMobileTrain and "Y" or "N") ..
        " Stationary:" .. (Remotes.ApplyStationaryTrain and "Y" or "N") ..
        " Chat:" .. (Remotes.SendTextChatMessage and "Y" or "N"), 10)
end)
SysTab:Button("Re-init All Remotes", function() healRemotes() notify("Remotes", "Re-scanned", 3) end)

SysTab:Label("ERROR LOG")
SysTab:Button("Show Last 5 Errors", function()
    local n = #ERR_LOG
    if n == 0 then notify("Errors", "No errors logged", 4) return end
    local lines = {}
    for i = math.max(1, n - 4), n do
        local e = ERR_LOG[i]
        if e then table.insert(lines, string.format("%s [%s] %s", e.timeStr, e.source, e.msg:sub(1, 60))) end
    end
    notify("Errors (" .. n .. ")", table.concat(lines, "\n"), 12)
end)
SysTab:Button("Clear Error Log", function() table.clear(ERR_LOG) notify("Errors", "Cleared", 3) end)

SysTab:Label("UI")
SysTab:Button("Hide UI (K to toggle)", function() UI.ScreenGui.Enabled = false end)
SysTab:Button("Destroy UI", function() UI:Destroy() end)

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

-- Movement re-apply
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

player.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum and Config.OverrideStats then
        task.wait(0.2)
        applyMovement()
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
-- LIVE STATS UPDATER (FPS + Power Tracker)
-- ============================================================
task.spawn(function()
    local frames = 0
    local t0 = tick()
    while task.wait(0.5) do
        frames = frames + 1
        local elapsed = tick() - t0
        if elapsed >= 1 then
            local fps = math.floor(frames / elapsed)
            UI.FpsLabel.Text = fps .. " FPS"
            UI.FpsLabel.TextColor3 = fps >= 50 and C.green
                                    or fps >= 30 and Color3.fromRGB(220, 220, 120)
                                    or C.red
            frames = 0
            t0 = tick()
        end
    end
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
        local content = string.format(
            "%s%s Power: %s\n%s Gains/s: %s\nSession: %ds | Total: %s\nWorkers: %d | Mode: %s",
            overnight, turbo, formatNumber(power),
            trendIcon, formatNumber(gains),
            sessionTime, formatNumber(powerTracker.gainsThisSession),
            activeWorkers, Config.FarmMode
        )
        pcall(function() statsParagraph:Set({Content = content}) end)
    end
end)

-- ============================================================
-- BOOT NOTIFY
-- ============================================================
notify("RezurXLab V1500", "Overnight Apex loaded. K to toggle. 4 tabs.", 6)

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
