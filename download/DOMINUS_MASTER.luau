-- ============================================================
-- DOMINUS ENGINE + UI  —  Built per Master UI Guidelines
-- Every rule followed: ZIndex hierarchy, radius table, TextBox
-- Active/Selectable, ScrollingFrame Selectable=false, etc.
-- ============================================================

-- ============================================================
-- 0. DUPLICATE CHECK (Rule 10: prevent duplicate UI)
-- ============================================================
local CoreGui = game:GetService("CoreGui")
local existing = CoreGui:FindFirstChild("DOMINUS_Master")
if existing then existing:Destroy() end

-- ============================================================
-- 1. SERVICES
-- ============================================================
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local HttpService       = game:GetService("HttpService")
local StarterGui        = game:GetService("StarterGui")
local player            = Players.LocalPlayer

local unpack = unpack or table.unpack

-- ============================================================
-- 2. PALETTE + RADIUS TABLE (Rule 2)
-- ============================================================
local C = {
    bg        = Color3.fromRGB(8,   8,  13),
    panel     = Color3.fromRGB(20,  20,  30),
    panelAlt  = Color3.fromRGB(30,  30,  44),
    panelHov  = Color3.fromRGB(40,  40,  58),
    accent    = Color3.fromRGB(255, 122,  28),
    accentHi  = Color3.fromRGB(255, 155,  65),
    accentDim = Color3.fromRGB(185,  88,  20),
    accentDark= Color3.fromRGB(65,   32,   8),
    text      = Color3.fromRGB(232, 232, 248),
    textDim   = Color3.fromRGB(170, 170, 198),
    muted     = Color3.fromRGB(108, 108, 142),
    green     = Color3.fromRGB(48,  215,  92),
    greenDim  = Color3.fromRGB(22,   75,  38),
    yellow    = Color3.fromRGB(255, 210,  48),
    red       = Color3.fromRGB(225,  58,  58),
    border    = Color3.fromRGB(46,   46,  70),
    borderAcc = Color3.fromRGB(255, 122,  28),
    track     = Color3.fromRGB(38,   38,  58),
    white     = Color3.fromRGB(255, 255, 255),
}

local R = {
    outer   = 16,
    panel   = 12,
    control = 10,
    small   = 7,
    pill    = 6,
    tab     = 8,
}

-- ============================================================
-- 3. TWEENINFO PRESETS (Rule 7)
-- ============================================================
local T10 = TweenInfo.new(0.10, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local T15 = TweenInfo.new(0.15, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local T20 = TweenInfo.new(0.20, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local T35 = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- ============================================================
-- 4. HELPERS (Rule 2: UICorner from R table, UIStroke)
-- ============================================================
local function corner(p, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or R.control)
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

-- ============================================================
-- 5. ERROR LOG
-- ============================================================
if not _G.__DOMINUS_ERRORS then _G.__DOMINUS_ERRORS = {} end
local ERR_LOG = _G.__DOMINUS_ERRORS
local function logError(source, msg)
    ERR_LOG[#ERR_LOG + 1] = {timeStr = os.date("%H:%M:%S"), source = tostring(source), msg = tostring(msg):sub(1, 300)}
    if #ERR_LOG > 100 then table.remove(ERR_LOG, 1) end
    warn(string.format("[DOMINUS] %s: %s", source, msg))
end
local function safeCall(source, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then logError(source, err) end
    return ok, err
end

-- ============================================================
-- 6. FORWARD DECLARATIONS
-- ============================================================
local notify
local applyMovement, restoreMovement
local executePump, sendChatMessage
local initAllRemotes, healRemotesWithBackoff
local setTurbo, startFarm, stopFarm
local startOvernight, stopOvernight
local setNoclipMode, powerTracker

-- ============================================================
-- 7. CONFIG
-- ============================================================
local Config = {
    CustomTag = "", UserName = "",
    TagColor = Color3.fromRGB(128, 0, 0),
    UserColor = Color3.fromRGB(255, 255, 255),
    MessageColor = Color3.fromRGB(255, 255, 255),
    FarmMode = "Hybrid", FarmEnabled = false, FarmSpeedMul = 1,
    WorkerCount = 25, MaxPerformance = false,
    TrainSpeedValue = "Infinity",
    OvernightEnabled = false,
    OverrideStats = false, WalkSpeed = 16, JumpPower = 50,
    NoclipEnabled = false, NoclipMode = "Improved",
    PvpOff = false, EspEnabled = false,
    AntiAfk = true, AntiDetect = false,
    TurboActive = false, TurboUntil = 0, TurboCooldownUntil = 0,
}

local hybridState = {
    currentWorkers = 5, lastAdjust = 0,
    fpsHistory = {}, responseTimes = {},
    consecutiveFailures = 0, emergencyMode = false,
}

-- ============================================================
-- 8. REMOTE MANAGER (self-healing + exponential backoff)
-- ============================================================
local Remotes = {}
local remoteMutex = false
local consecutiveHealFailures = 0
local lastHealTime = 0

initAllRemotes = function()
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
        if abRem then Remotes.ApplyCastAbility = abRem:FindFirstChild("ApplyCastAbility") end
        local ar = ReplicatedStorage:FindFirstChild("Area")
        local arRem = ar and ar:FindFirstChild("Remote")
        if arRem then Remotes.PlayerAreaIn = arRem:FindFirstChild("PlayerAreaIn") end
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
    if Remotes.ApplyAddFrenzyValue then consecutiveHealFailures = 0
    else consecutiveHealFailures = consecutiveHealFailures + 1 end
end

task.spawn(function()
    while task.wait(30) do safeCall("periodic-init", initAllRemotes) end
end)

-- ============================================================
-- 9. POWER TRACKER
-- ============================================================
powerTracker = {
    sessionStart = 0, sessionStartPower = 0,
    lastTickTime = 0, lastTickPower = 0,
    gainsPerSec = 0, gainsThisSession = 0, samples = {},
}
function powerTracker.readPower()
    local cfg = player:FindFirstChild("Configuration")
    local ts = cfg and cfg:FindFirstChild("TrainSystem")
    if not ts then return 0 end
    local total = 0
    for i = 1, 4 do total = total + (ts:GetAttribute(tostring(i)) or 0) end
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

-- ============================================================
-- 10. FARM ENGINE (no anti-cheat = max speed)
-- ============================================================
local function getTrainSpeed()
    local v = Config.TrainSpeedValue
    if v == "1e9" then return 1e9
    elseif v == "1e15" then return 1e15
    else return math.huge end
end

executePump = function(speed)
    if not Remotes.ApplyAddFrenzyValue then healRemotesWithBackoff() end
    if not Remotes.ApplyAddFrenzyValue then return end
    local r = Remotes
    local calls = {
        {func="Invoke", remote=r.ApplyAddFrenzyValue,  args={10000}},
        {func="Fire",   remote=r.TrainSpeedHasChanged, args={speed}},
        {func="Invoke", remote=r.ApplyMobileTrain,     args={speed}},
        {func="Invoke", remote=r.ApplyStationaryTrain, args={speed}},
        {func="Invoke", remote=r.ApplyStationaryTrain, args={speed}},
        {func="Fire",   remote=r.TrainSpeedHasChanged, args={speed}},
        {func="Invoke", remote=r.ApplyMobileTrain,     args={speed}},
        {func="Invoke", remote=r.ApplyStationaryTrain, args={speed}},
        {func="Invoke", remote=r.ApplyStationaryTrain, args={speed}},
        {func="Fire",   remote=r.TrainSpeedHasChanged, args={speed}},
        {func="Invoke", remote=r.ApplyMobileTrain,     args={speed}},
        {func="Invoke", remote=r.ApplyStationaryTrain, args={speed}},
        {func="Invoke", remote=r.ApplyStationaryTrain, args={speed}},
        {func="Fire",   remote=r.TrainSpeedHasChanged, args={speed}},
        {func="Invoke", remote=r.ApplyAddFrenzyValue,  args={10000}},
    }
    for _, c in ipairs(calls) do
        if c.remote then
            if c.func == "Invoke" then pcall(c.remote.InvokeServer, c.remote, unpack(c.args))
            else pcall(c.remote.FireServer, c.remote, unpack(c.args)) end
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
        local wid = i
        task.spawn(function()
            task.wait((wid - 1) * 0.002)
            while gen == workerGeneration and Config.FarmEnabled do
                local speed = getTrainSpeed()
                if hybridState.emergencyMode then speed = 1e9 end
                pcall(executePump, speed)
                task.wait(0.001)
            end
        end)
    end
end
local function killWorkers() workerGeneration = workerGeneration + 1 activeWorkers = 0 end

local adaptiveConn = nil
local function startAdaptiveThrottle()
    if adaptiveConn then adaptiveConn:Disconnect() end
    adaptiveConn = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - hybridState.lastAdjust < 2 then return end
        hybridState.lastAdjust = now
        local fc = RunService.Heartbeat:Connect(function() end)
        local fpsT0 = tick()
        local fpsCount = 0
        local fc2 = RunService.Heartbeat:Connect(function() fpsCount = fpsCount + 1 end)
        task.wait(0.5)
        fc2:Disconnect()
        fc:Disconnect()
        local fps = math.floor(fpsCount / 0.5)
        table.insert(hybridState.fpsHistory, fps)
        if #hybridState.fpsHistory > 5 then table.remove(hybridState.fpsHistory, 1) end
        local avgFps = 0
        for _, v in ipairs(hybridState.fpsHistory) do avgFps = avgFps + v end
        avgFps = avgFps / #hybridState.fpsHistory
        local trend = powerTracker.trend()
        local old = hybridState.currentWorkers
        if avgFps < 15 then hybridState.emergencyMode = true hybridState.currentWorkers = 1
        elseif avgFps < 25 then hybridState.emergencyMode = false hybridState.currentWorkers = math.max(1, hybridState.currentWorkers - 1)
        elseif trend == "down" and hybridState.currentWorkers > 2 then hybridState.emergencyMode = false hybridState.currentWorkers = hybridState.currentWorkers - 1
        elseif trend == "up" and avgFps > 50 and hybridState.currentWorkers < 250 then hybridState.emergencyMode = false hybridState.currentWorkers = hybridState.currentWorkers + 1
        elseif trend == "flat" and avgFps > 50 and hybridState.currentWorkers < 100 then hybridState.emergencyMode = false hybridState.currentWorkers = hybridState.currentWorkers + 1
        end
        if hybridState.currentWorkers ~= old and Config.FarmEnabled and Config.FarmMode == "Hybrid" then
            killWorkers() task.wait(0.05) spawnWorkers(hybridState.currentWorkers)
        end
    end)
end
local function stopAdaptiveThrottle() if adaptiveConn then adaptiveConn:Disconnect() adaptiveConn = nil end end

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
        spawnWorkers(hybridState.currentWorkers)
        startAdaptiveThrottle()
    else
        farmConn = RunService.Heartbeat:Connect(function()
            safeCall("farm-legacy", function() pcall(executePump, getTrainSpeed()) end)
        end)
    end
end
stopFarm = function()
    if farmConn then farmConn:Disconnect() farmConn = nil end
    stopAdaptiveThrottle()
    killWorkers()
end

-- ============================================================
-- 11. OVERNIGHT MODE
-- ============================================================
local overnightConn = nil
local overnightOriginal = {}
startOvernight = function()
    if overnightConn then return end
    overnightOriginal = {Config.FarmMode, Config.WorkerCount, Config.AntiDetect, Config.TrainSpeedValue}
    Config.FarmMode = "Hybrid" Config.WorkerCount = 3 Config.AntiDetect = true
    Config.TrainSpeedValue = "Infinity" Config.TurboActive = false Config.TurboUntil = 0
    Config.FarmEnabled = true startFarm()
    local cycleStart = tick()
    local lastFpsCheck = tick()
    local fpsLowStreak = 0
    overnightConn = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - lastFpsCheck >= 5 then
            lastFpsCheck = now
            local fc = RunService.Heartbeat:Connect(function() end)
            local fpsCount = 0
            local fc2 = RunService.Heartbeat:Connect(function() fpsCount = fpsCount + 1 end)
            task.wait(0.5) fc2:Disconnect() fc:Disconnect()
            local fps = math.floor(fpsCount / 0.5)
            if fps < 15 then
                fpsLowStreak = fpsLowStreak + 1
                if fpsLowStreak >= 2 then
                    killWorkers()
                    task.delay(120, function() if Config.OvernightEnabled then cycleStart = tick() spawnWorkers(3) end end)
                end
            else fpsLowStreak = 0 end
        end
        if now - cycleStart >= 300 then
            killWorkers() collectgarbage("collect")
            task.delay(30, function() if Config.OvernightEnabled then cycleStart = tick() spawnWorkers(3) end end)
        end
    end)
end
stopOvernight = function()
    if overnightConn then overnightConn:Disconnect() overnightConn = nil end
    Config.FarmMode = overnightOriginal[1] or "Hybrid"
    Config.WorkerCount = overnightOriginal[2] or 25
    Config.AntiDetect = overnightOriginal[3] ~= nil and overnightOriginal[3] or false
    Config.TrainSpeedValue = overnightOriginal[4] or "Infinity"
    Config.TurboActive = false Config.FarmEnabled = false stopFarm()
end

-- ============================================================
-- 12. TURBO + CHAT + MOVEMENT + NOCLIP + ESP + CORE LOOPS
-- ============================================================
setTurbo = function()
    if Config.OvernightEnabled then return end
    local now = tick()
    if Config.TurboActive then return end
    if now < Config.TurboCooldownUntil then return end
    Config.TurboActive = true Config.TurboUntil = now + 10
    notify("TURBO", "2x for 10s!", 3, "success")
    if Config.FarmMode == "Hybrid" and Config.FarmEnabled then
        killWorkers() task.wait(0.05) spawnWorkers(math.min(250, hybridState.currentWorkers * 2))
    end
    task.spawn(function()
        while Config.TurboActive and tick() < Config.TurboUntil do task.wait(0.5) end
        Config.TurboActive = false Config.TurboCooldownUntil = tick() + 5
        if Config.FarmMode == "Hybrid" and Config.FarmEnabled then
            killWorkers() task.wait(0.05) spawnWorkers(hybridState.currentWorkers)
        end
    end)
end

local function buildChatMessage(msg)
    local tag, name = "", ""
    if Config.CustomTag ~= "" then tag = string.format('<font color="#%s"><b>[%s]</b></font> ', Config.TagColor:ToHex(), Config.CustomTag) end
    if Config.UserName ~= "" then name = string.format('<font color="#%s"><b>%s:</b></font> ', Config.UserColor:ToHex(), Config.UserName) end
    return tag .. name .. string.format('<font color="#%s"><b>%s</b></font>', Config.MessageColor:ToHex(), msg)
end
sendChatMessage = function(msg)
    if not Remotes.SendTextChatMessage then healRemotesWithBackoff() end
    if not Remotes.SendTextChatMessage or not msg or msg == "" then return end
    local full = buildChatMessage(msg)
    local ok = pcall(function() Remotes.SendTextChatMessage:InvokeServer({Text = full}) end)
    if not ok then safeCall("chat", function() Remotes.SendTextChatMessage:InvokeServer(full) end) end
end

applyMovement = function()
    if not Config.OverrideStats then return end
    local char = player.Character if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid") if not hum then return end
    hum.WalkSpeed = Config.WalkSpeed hum.JumpPower = Config.JumpPower hum.UseJumpPower = true
end
restoreMovement = function()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16 hum.JumpPower = 50 end
end

local noclipConn, noclipCharConn = nil, nil
setNoclipMode = function(enabled)
    Config.NoclipEnabled = enabled
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if noclipCharConn then noclipCharConn:Disconnect() noclipCharConn = nil end
    if not enabled then return end
    local function start()
        if Config.NoclipMode == "V777" then
            noclipConn = RunService.Stepped:Connect(function()
                local char = player.Character
                if char then for _, v in pairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end end
            end)
        else
            noclipConn = RunService.Stepped:Connect(function()
                local char = player.Character if not char then return end
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide and v.Name ~= "HumanoidRootPart" then v.CanCollide = false end
                end
            end)
        end
    end
    start()
    noclipCharConn = player.CharacterAdded:Connect(function()
        task.wait(0.3)
        if Config.NoclipEnabled then if noclipConn then noclipConn:Disconnect() noclipConn = nil end start() end
    end)
end

local espCache, espConn = {}, nil
local function clearEsp()
    if espConn then espConn:Disconnect() espConn = nil end
    for h, e in pairs(espCache) do if e.gui and e.gui.Parent then e.gui:Destroy() end end
    table.clear(espCache)
end
local function getPowerFor(name)
    local p = Players:FindFirstChild(name) if not p then return 0 end
    local cfg = p:FindFirstChild("Configuration")
    local ts = cfg and cfg:FindFirstChild("TrainSystem") if not ts then return 0 end
    local t = 0 for i = 1, 4 do t = t + (ts:GetAttribute(tostring(i)) or 0) end return t
end

RunService.Heartbeat:Connect(function()
    if not Config.OverrideStats then return end
    local char = player.Character if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid") if not hum then return end
    if hum.WalkSpeed ~= Config.WalkSpeed or hum.JumpPower ~= Config.JumpPower then
        hum.WalkSpeed = Config.WalkSpeed hum.JumpPower = Config.JumpPower hum.UseJumpPower = true
    end
end)
player.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Died:Connect(function() if Config.FarmEnabled and Config.FarmMode == "Hybrid" then killWorkers() end end)
        if Config.OverrideStats then task.wait(0.2) applyMovement() end
        if Config.FarmEnabled and Config.FarmMode == "Hybrid" then
            task.wait(0.5)
            if Config.FarmEnabled then spawnWorkers(math.max(1, math.min(250, hybridState.currentWorkers))) end
        end
    end
end)
player.Idled:Connect(function()
    if not Config.AntiAfk then return end
    safeCall("afk", function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end)
end)
task.spawn(function()
    while task.wait(0.5) do
        if Config.PvpOff then
            safeCall("pvp", function()
                local ar = workspace:FindFirstChild("Area")
                local pa = ar and ar:FindFirstChild("PlayerArea")
                local s2 = pa and pa:FindFirstChild("S2")
                if s2 and Remotes.PlayerAreaIn then Remotes.PlayerAreaIn:InvokeServer(s2)
                elseif not Remotes.PlayerAreaIn then healRemotesWithBackoff() end
            end)
        end
    end
end)

-- ============================================================
-- 13. SCREENGUI (Rule 1: ResetOnSpawn=false, IgnoreGuiInset=true, ZIndexBehavior=Sibling)
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DOMINUS_Master"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = player:WaitForChild("PlayerGui") end

-- ============================================================
-- 14. WINDOW (ZIndex hierarchy: Shadow=1, Window=2)
-- ============================================================
local WIN_W, WIN_H = 540, 480
local HEADER_H, TABBAR_H, STATUSBAR_H = 54, 36, 24

local shadow = Instance.new("Frame")
shadow.Size = UDim2.new(0, WIN_W + 36, 0, WIN_H + 36)
shadow.Position = UDim2.new(0.5, -(WIN_W+36)/2, 0.4, -(WIN_H+36)/2)
shadow.BackgroundColor3 = Color3.new(0, 0, 0)
shadow.BackgroundTransparency = 0.52
shadow.BorderSizePixel = 0
shadow.ZIndex = 1
shadow.Parent = screenGui
corner(shadow, R.outer + 8)

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, WIN_W, 0, WIN_H)
frame.Position = UDim2.new(0.5, -WIN_W/2, 0.4, -WIN_H/2)
frame.BackgroundColor3 = C.bg
frame.BorderSizePixel = 0
frame.ZIndex = 2
-- Rule 5: NO ClipsDescendants on frame that could hold popups (popups go to ScreenGui anyway)
frame.Parent = screenGui
corner(frame, R.outer)
stroke(frame, C.border, 1.5)

-- ============================================================
-- 15. HEADER (ZIndex=4)
-- ============================================================
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, HEADER_H)
header.BackgroundColor3 = C.panel
header.BorderSizePixel = 0
header.ZIndex = 4
header.Parent = frame
corner(header, R.outer)
local hFix = Instance.new("Frame")
hFix.Size = UDim2.new(1, 0, 0.5, 0)
hFix.Position = UDim2.new(0, 0, 0.5, 0)
hFix.BackgroundColor3 = C.panel
hFix.BorderSizePixel = 0
hFix.Parent = header
local accentLine = Instance.new("Frame")
accentLine.Size = UDim2.new(1, 0, 0, 2)
accentLine.Position = UDim2.new(0, 0, 1, -2)
accentLine.BackgroundColor3 = C.accent
accentLine.BorderSizePixel = 0
accentLine.Parent = header

local logo = Instance.new("TextLabel")
logo.RichText = true
logo.Text = '<font color="#E2E2F0">Rezur</font><b><font color="#FF7A1C">X</font></b><font color="#E2E2F0">Lab</font>'
logo.Size = UDim2.new(0, 200, 0, 24)
logo.Position = UDim2.new(0, 14, 0, 6)
logo.BackgroundTransparency = 1
logo.Font = Enum.Font.GothamBlack
logo.TextSize = 20
logo.TextXAlignment = Enum.TextXAlignment.Left
logo.Parent = header

local subLbl = Instance.new("TextLabel")
subLbl.Text = "DOMINUS - Maximum Power"
subLbl.Size = UDim2.new(0, 200, 0, 14)
subLbl.Position = UDim2.new(0, 15, 0, 32)
subLbl.BackgroundTransparency = 1
subLbl.Font = Enum.Font.GothamMedium
subLbl.TextSize = 11
subLbl.TextColor3 = C.muted
subLbl.TextXAlignment = Enum.TextXAlignment.Left
subLbl.Parent = header

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(0, 64, 0, 24)
fpsLabel.Position = UDim2.new(0, 340, 0.5, -12)
fpsLabel.BackgroundColor3 = C.panelAlt
fpsLabel.BorderSizePixel = 0
fpsLabel.Font = Enum.Font.Code
fpsLabel.TextSize = 11
fpsLabel.TextColor3 = C.green
fpsLabel.Text = "60 FPS"
fpsLabel.ZIndex = 5
fpsLabel.Parent = header
corner(fpsLabel, R.small)

local minBtn = Instance.new("TextButton")
minBtn.Text = "-"
minBtn.Size = UDim2.new(0, 28, 0, 28)
minBtn.Position = UDim2.new(1, -70, 0.5, -14)
minBtn.BackgroundColor3 = C.panelAlt
minBtn.TextColor3 = C.muted
minBtn.TextSize = 16
minBtn.Font = Enum.Font.GothamBold
minBtn.BorderSizePixel = 0
minBtn.AutoButtonColor = false
minBtn.ZIndex = 5
minBtn.Parent = header
corner(minBtn, R.small)
stroke(minBtn, C.border, 1)

local closeBtn = Instance.new("TextButton")
closeBtn.Text = "X"
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -38, 0.5, -14)
closeBtn.BackgroundColor3 = C.red
closeBtn.TextColor3 = C.white
closeBtn.TextSize = 12
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 5
closeBtn.Parent = header
corner(closeBtn, R.small)

-- ============================================================
-- 16. DRAG (Rule 8: header drag, both mouse + touch)
-- ============================================================
local dragging, dragStart, startPos
header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true dragStart = inp.Position startPos = frame.Position
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        local d = inp.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ============================================================
-- 17. MINIMIZE + CLOSE (Rule 8)
-- ============================================================
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    tabBar.Visible = not minimized
    content.Visible = not minimized
    statusBar.Visible = not minimized
    TweenService:Create(frame, T20, {Size = UDim2.new(0, WIN_W, 0, minimized and HEADER_H or WIN_H)}):Play()
    minBtn.Text = minimized and "+" or "-"
end)
closeBtn.MouseButton1Click:Connect(function()
    screenGui.Enabled = not screenGui.Enabled
end)

-- ============================================================
-- 18. TAB BAR (ZIndex=3, horizontal UIListLayout)
-- ============================================================
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, TABBAR_H)
tabBar.Position = UDim2.new(0, 0, 0, HEADER_H)
tabBar.BackgroundColor3 = C.panelAlt
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 3
tabBar.Parent = frame
stroke(tabBar, C.border, 0.5)

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 2)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar
pad(tabBar, 0, 0, 4, 4)

-- ============================================================
-- 19. CONTENT AREA (ZIndex=2)
-- ============================================================
local content = Instance.new("Frame")
content.Size = UDim2.new(1, 0, 1, -(HEADER_H + TABBAR_H + STATUSBAR_H))
content.Position = UDim2.new(0, 0, 0, HEADER_H + TABBAR_H)
content.BackgroundTransparency = 1
content.ZIndex = 2
content.Parent = frame

-- ============================================================
-- 20. STATUS BAR (ZIndex=4)
-- ============================================================
local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1, 0, 0, STATUSBAR_H)
statusBar.Position = UDim2.new(0, 0, 1, -STATUSBAR_H)
statusBar.BackgroundColor3 = C.panel
statusBar.BorderSizePixel = 0
statusBar.ZIndex = 4
statusBar.Parent = frame
corner(statusBar, R.outer)
local sbFix = Instance.new("Frame")
sbFix.Size = UDim2.new(1, 0, 0.5, 0)
sbFix.BackgroundColor3 = C.panel
sbFix.BorderSizePixel = 0
sbFix.Parent = statusBar
local sbLine = Instance.new("Frame")
sbLine.Size = UDim2.new(1, 0, 0, 1)
sbLine.BackgroundColor3 = C.border
sbLine.BorderSizePixel = 0
sbLine.Parent = statusBar

local sDot = Instance.new("Frame")
sDot.Size = UDim2.new(0, 6, 0, 6)
sDot.Position = UDim2.new(0, 8, 0.5, -3)
sDot.BackgroundColor3 = C.green
sDot.BorderSizePixel = 0
sDot.Parent = statusBar
corner(sDot, 3)

local sTxt = Instance.new("TextLabel")
sTxt.Size = UDim2.new(0, 100, 1, 0)
sTxt.Position = UDim2.new(0, 18, 0, 0)
sTxt.BackgroundTransparency = 1
sTxt.Font = Enum.Font.Code
sTxt.TextSize = 10
sTxt.TextColor3 = C.muted
sTxt.TextXAlignment = Enum.TextXAlignment.Left
sTxt.Text = "READY"
sTxt.Parent = statusBar
local sBoot = os.clock()
task.spawn(function()
    while true do
        local e = os.clock() - sBoot
        sTxt.Text = string.format("UP %02d:%02d", math.floor(e/60), math.floor(e%60))
        task.wait(1)
    end
end)

local sVer = Instance.new("TextLabel")
sVer.Size = UDim2.new(0, 200, 1, 0)
sVer.Position = UDim2.new(1, -204, 0, 0)
sVer.BackgroundTransparency = 1
sVer.Font = Enum.Font.Code
sVer.TextSize = 10
sVer.TextColor3 = C.muted
sVer.TextXAlignment = Enum.TextXAlignment.Right
sVer.Text = "RezurXLab DOMINUS"
sVer.Parent = statusBar

-- ============================================================
-- 21. NOTIFICATIONS (parented to ScreenGui, ZIndex=6)
-- ============================================================
local notifContainer = Instance.new("Frame")
notifContainer.Size = UDim2.new(0, 280, 1, -20)
notifContainer.Position = UDim2.new(1, -288, 0, 10)
notifContainer.BackgroundTransparency = 1
notifContainer.ZIndex = 6
notifContainer.Parent = screenGui
local nLayout = Instance.new("UIListLayout")
nLayout.Padding = UDim.new(0, 4)
nLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
nLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
nLayout.Parent = notifContainer

notify = function(title, body, duration, ntype)
    ntype = ntype or "info"
    duration = duration or 5
    local col = (ntype == "success" and C.green) or (ntype == "warning" and C.yellow) or (ntype == "error" and C.red) or C.accent
    local n = Instance.new("Frame")
    n.Size = UDim2.new(1, 0, 0, 56)
    n.BackgroundColor3 = C.panel
    n.BackgroundTransparency = 0.05
    n.ZIndex = 6
    n.Parent = notifContainer
    corner(n, R.panel)
    stroke(n, col, 1)
    local strip = Instance.new("Frame")
    strip.Size = UDim2.new(0, 3, 1, 0)
    strip.BackgroundColor3 = col
    strip.BorderSizePixel = 0
    strip.Parent = n
    corner(strip, 2)
    local ttl = Instance.new("TextLabel")
    ttl.Size = UDim2.new(1, -16, 0, 16)
    ttl.Position = UDim2.new(0, 10, 0, 6)
    ttl.BackgroundTransparency = 1
    ttl.Font = Enum.Font.GothamBold
    ttl.TextSize = 12
    ttl.TextColor3 = col
    ttl.TextXAlignment = Enum.TextXAlignment.Left
    ttl.TextWrapped = true
    ttl.TextTruncate = Enum.TextTruncate.AtEnd
    ttl.Text = title or ""
    ttl.Parent = n
    local cnt = Instance.new("TextLabel")
    cnt.Size = UDim2.new(1, -16, 0, 28)
    cnt.Position = UDim2.new(0, 10, 0, 22)
    cnt.BackgroundTransparency = 1
    cnt.Font = Enum.Font.Gotham
    cnt.TextSize = 11
    cnt.TextColor3 = C.textDim
    cnt.TextXAlignment = Enum.TextXAlignment.Left
    cnt.TextYAlignment = Enum.TextYAlignment.Top
    cnt.TextWrapped = true
    cnt.Text = body or ""
    cnt.Parent = n
    task.delay(duration, function()
        local t = TweenService:Create(n, T20, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1})
        t:Play()
        t.Completed:Connect(function() n:Destroy() end)
    end)
end

-- ============================================================
-- 22. FPS COUNTER
-- ============================================================
local fpsAvg = 60
RunService.Heartbeat:Connect(function(dt)
    fpsAvg = fpsAvg * 0.88 + (1 / math.max(dt, 0.001)) * 0.12
    local avg = math.floor(fpsAvg + 0.5)
    fpsLabel.Text = avg .. " FPS"
    fpsLabel.TextColor3 = avg >= 55 and C.green or avg >= 30 and C.yellow or C.red
end)

-- ============================================================
-- 23. COMPONENT LIBRARY (Rule 12: MANDATORY)
-- ============================================================
local Tabs = {}
local ActiveTab = nil
local currentPopup = nil

local function closePopup()
    if currentPopup then
        if currentPopup.catcher then pcall(function() currentPopup.catcher:Destroy() end) end
        if currentPopup.popup then pcall(function() currentPopup.popup:Destroy() end) end
        currentPopup = nil
    end
end

local function CreateTab(name, icon)
    local tab = {}

    -- Tab button (ZIndex=5, opaque, orange stroke)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 64, 1, -4)
    btn.BackgroundColor3 = C.panelAlt
    btn.BackgroundTransparency = 0
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.ZIndex = 5
    btn.LayoutOrder = #Tabs + 1
    btn.Parent = tabBar
    corner(btn, R.tab)
    stroke(btn, C.borderAcc, 1)

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.new(1, 0, 0.5, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.TextSize = 13
    iconLbl.TextColor3 = C.textDim
    iconLbl.Text = icon or ""
    iconLbl.ZIndex = 5
    iconLbl.Parent = btn

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0.5, 0)
    nameLbl.Position = UDim2.new(0, 0, 0.5, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 9
    nameLbl.TextColor3 = C.textDim
    nameLbl.Text = name
    nameLbl.TextWrapped = true
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.ZIndex = 5
    nameLbl.Parent = btn

    -- Page = ScrollingFrame (Rule 6: Selectable=false, Active=false, ClipsDescendants=true, CanvasSize update)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = C.accent
    page.ScrollBarImageTransparency = 0.4
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.ClipsDescendants = true
    page.Selectable = false  -- Rule 6: CRITICAL for TextBox to work
    page.Active = false      -- Rule 6: CRITICAL for TextBox to work
    page.Visible = false
    page.ZIndex = 2
    page.Parent = content

    local pLayout = Instance.new("UIListLayout")
    pLayout.Padding = UDim.new(0, 6)
    pLayout.Parent = page
    pad(page, 8, 8, 8, 8)

    -- Rule 6: Update CanvasSize on AbsoluteContentSize change
    pLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, pLayout.AbsoluteContentSize.Y + 16)
    end)

    tab.Page = page
    tab.Btn = btn
    tab.Name = name

    local function setActive()
        if ActiveTab and ActiveTab ~= tab then
            ActiveTab.Page.Visible = false
            TweenService:Create(ActiveTab.Btn, T20, {BackgroundColor3 = C.panelAlt}):Play()
        end
        ActiveTab = tab
        page.Visible = true
        TweenService:Create(btn, T20, {BackgroundColor3 = C.accentDark}):Play()
    end

    btn.MouseEnter:Connect(function()
        if ActiveTab ~= tab then TweenService:Create(btn, T10, {BackgroundColor3 = C.panelHov}):Play() end
    end)
    btn.MouseLeave:Connect(function()
        if ActiveTab ~= tab then TweenService:Create(btn, T10, {BackgroundColor3 = C.panelAlt}):Play() end
    end)
    btn.MouseButton1Click:Connect(setActive)

    table.insert(Tabs, tab)
    if #Tabs == 1 then setActive() end

    -- ============================================================
    -- COMPONENT METHODS (Rule 12: all reusable)
    -- ============================================================

    function tab:Label(text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 18)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold
        l.TextSize = 10
        l.TextColor3 = C.accent
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextWrapped = true
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Text = string.upper(text)
        l.ZIndex = 3
        l.Parent = page
        return l
    end

    function tab:Divider(text)
        local h = Instance.new("Frame")
        h.Size = UDim2.new(1, 0, 0, 16)
        h.BackgroundTransparency = 1
        h.ZIndex = 3
        h.Parent = page
        if text then
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1, 0, 1, 0)
            l.BackgroundTransparency = 1
            l.Font = Enum.Font.GothamBold
            l.TextSize = 9
            l.TextColor3 = C.muted
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.TextWrapped = true
            l.TextTruncate = Enum.TextTruncate.AtEnd
            l.Text = "-- " .. string.upper(text)
            l.Parent = h
        else
            local line = Instance.new("Frame")
            line.Size = UDim2.new(1, 0, 0, 1)
            line.Position = UDim2.new(0, 0, 0.5, 0)
            line.BackgroundColor3 = C.border
            line.BorderSizePixel = 0
            line.Parent = h
        end
        return h
    end

    function tab:Button(name, callback)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 38)
        b.BackgroundColor3 = C.panel
        b.Text = ""
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        b.ZIndex = 5
        b.Parent = page
        corner(b, R.control)
        stroke(b, C.border, 1)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -24, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 13
        lbl.TextColor3 = C.text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextWrapped = true
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Text = name
        lbl.ZIndex = 5
        lbl.Parent = b
        b.MouseEnter:Connect(function() TweenService:Create(b, T10, {BackgroundColor3 = C.panelHov}):Play() end)
        b.MouseLeave:Connect(function() TweenService:Create(b, T10, {BackgroundColor3 = C.panel}):Play() end)
        b.MouseButton1Click:Connect(function()
            TweenService:Create(b, T10, {BackgroundColor3 = C.accentDim}):Play()
            task.delay(0.1, function() TweenService:Create(b, T10, {BackgroundColor3 = C.panel}):Play() end)
            if callback then task.spawn(pcall, callback) end
        end)
        return b
    end

    function tab:Toggle(name, default, callback)
        local state = default == true
        local h = Instance.new("Frame")
        h.Size = UDim2.new(1, 0, 0, 38)
        h.BackgroundColor3 = C.panel
        h.BorderSizePixel = 0
        h.ZIndex = 5
        h.Parent = page
        corner(h, R.control)
        local hs = stroke(h, C.border, 1)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -60, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 13
        lbl.TextColor3 = C.text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextWrapped = true
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Text = name
        lbl.ZIndex = 5
        lbl.Parent = h
        local sw = Instance.new("Frame")
        sw.Size = UDim2.new(0, 38, 0, 20)
        sw.Position = UDim2.new(1, -46, 0.5, -10)
        sw.BackgroundColor3 = state and C.accent or C.track
        sw.BorderSizePixel = 0
        sw.ZIndex = 5
        sw.Parent = h
        corner(sw, UDim.new(1, 0))
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        knob.BackgroundColor3 = C.white
        knob.BorderSizePixel = 0
        knob.ZIndex = 5
        knob.Parent = sw
        corner(knob, UDim.new(1, 0))
        local obj = {}
        local function apply(v)
            state = v
            TweenService:Create(sw, T20, {BackgroundColor3 = state and C.accent or C.track}):Play()
            TweenService:Create(hs, T20, {Color = state and C.accentDim or C.border}):Play()
            TweenService:Create(knob, T20, {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
            if callback then callback(state) end
        end
        function obj:Set(v) apply(v) end
        function obj:Get() return state end
        h.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                apply(not state)
            end
        end)
        return obj
    end

    function tab:Slider(name, minVal, maxVal, default, suffix, callback)
        local h = Instance.new("Frame")
        h.Size = UDim2.new(1, 0, 0, 46)
        h.BackgroundColor3 = C.panel
        h.BorderSizePixel = 0
        h.ZIndex = 5
        h.Parent = page
        corner(h, R.control)
        stroke(h, C.border, 1)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -80, 0, 16)
        lbl.Position = UDim2.new(0, 12, 0, 5)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextColor3 = C.text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextWrapped = true
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Text = name
        lbl.ZIndex = 5
        lbl.Parent = h
        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0, 56, 0, 16)
        valLbl.Position = UDim2.new(1, -64, 0, 5)
        valLbl.BackgroundTransparency = 1
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 12
        valLbl.TextColor3 = C.accent
        valLbl.TextXAlignment = Enum.TextXAlignment.Right
        valLbl.Text = tostring(default) .. (suffix or "")
        valLbl.ZIndex = 5
        valLbl.Parent = h
        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -24, 0, 6)
        track.Position = UDim2.new(0, 12, 0, 30)
        track.BackgroundColor3 = C.track
        track.BorderSizePixel = 0
        track.ZIndex = 5
        track.Parent = h
        corner(track, UDim.new(1, 0))
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = C.accent
        fill.BorderSizePixel = 0
        fill.ZIndex = 5
        fill.Parent = track
        corner(fill, UDim.new(1, 0))
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 14, 0, 14)
        knob.Position = UDim2.new(0, -7, 0.5, -7)
        knob.BackgroundColor3 = C.white
        knob.BorderSizePixel = 0
        knob.ZIndex = 5
        knob.Parent = track
        corner(knob, UDim.new(1, 0))
        stroke(knob, C.accent, 1.5)
        local value = default
        local function update()
            local pct = math.clamp((value - minVal) / (maxVal - minVal), 0, 1)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            knob.Position = UDim2.new(pct, -7, 0.5, -7)
            valLbl.Text = tostring(value) .. (suffix or "")
        end
        update()
        local obj = {}
        function obj:Set(v) value = math.clamp(v, minVal, maxVal) update() if callback then callback(value) end end
        function obj:Get() return value end
        local sdrag = false
        local function setFromX(x)
            local pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            value = math.floor(minVal + pct * (maxVal - minVal) + 0.5)
            update() if callback then callback(value) end
        end
        track.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                sdrag = true setFromX(inp.Position.X)
            end
        end)
        track.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                sdrag = false
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if sdrag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
                setFromX(inp.Position.X)
            end
        end)
        return obj
    end

    -- Rule 5.4: TextBox MUST have Active=true, Selectable=true, ZIndex>=15
    function tab:Input(name, placeholder, callback)
        local h = Instance.new("Frame")
        h.Size = UDim2.new(1, 0, 0, 44)
        h.BackgroundColor3 = C.panel
        h.BorderSizePixel = 0
        h.ZIndex = 5
        h.Parent = page
        corner(h, R.control)
        local strk = stroke(h, C.border, 1)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -16, 0, 14)
        lbl.Position = UDim2.new(0, 12, 0, 5)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 10
        lbl.TextColor3 = C.muted
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextWrapped = true
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Text = string.upper(name)
        lbl.ZIndex = 5
        lbl.Parent = h
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -24, 0, 18)
        box.Position = UDim2.new(0, 12, 0, 22)
        box.BackgroundTransparency = 1
        box.Font = Enum.Font.Gotham
        box.TextSize = 13
        box.TextColor3 = C.text
        box.PlaceholderColor3 = C.muted
        box.PlaceholderText = placeholder or ""
        box.Text = ""
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.ClearTextOnFocus = false
        box.Active = true        -- Rule 5.4: CRITICAL
        box.Selectable = true    -- Rule 5.4: CRITICAL
        box.ZIndex = 15           -- Rule 5.4: CRITICAL (>= 15)
        box.Parent = h
        box.Focused:Connect(function() TweenService:Create(strk, T10, {Color = C.borderAcc, Thickness = 1.5}):Play() end)
        box.FocusLost:Connect(function()
            TweenService:Create(strk, T10, {Color = C.border, Thickness = 1}):Play()
            if callback then callback(box.Text) end
        end)
        return box
    end

    -- ChatInput: same TextBox rules + Enter to send
    function tab:ChatInput(name, placeholder, onSend)
        local h = Instance.new("Frame")
        h.Size = UDim2.new(1, 0, 0, 50)
        h.BackgroundColor3 = C.panel
        h.BorderSizePixel = 0
        h.ZIndex = 5
        h.Parent = page
        corner(h, R.control)
        local strk = stroke(h, C.border, 1)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -16, 0, 14)
        lbl.Position = UDim2.new(0, 12, 0, 5)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 10
        lbl.TextColor3 = C.muted
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextWrapped = true
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Text = string.upper(name)
        lbl.ZIndex = 5
        lbl.Parent = h
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -24, 0, 24)
        box.Position = UDim2.new(0, 12, 0, 22)
        box.BackgroundColor3 = C.track
        box.BackgroundTransparency = 0.3
        box.Font = Enum.Font.Gotham
        box.TextSize = 13
        box.TextColor3 = C.text
        box.PlaceholderColor3 = C.muted
        box.PlaceholderText = placeholder or ""
        box.Text = ""
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.ClearTextOnFocus = false
        box.ReturnTextOnFocusLost = false
        box.Active = true        -- Rule 5.4
        box.Selectable = true    -- Rule 5.4
        box.ZIndex = 15           -- Rule 5.4
        box.Parent = h
        corner(box, R.small)
        box.Focused:Connect(function() TweenService:Create(strk, T10, {Color = C.borderAcc, Thickness = 1.5}):Play() end)
        box.FocusLost:Connect(function(enter)
            TweenService:Create(strk, T10, {Color = C.border, Thickness = 1}):Play()
            if enter and box.Text ~= "" then
                if onSend then onSend(box.Text) end
                box.Text = ""
            end
        end)
        return box
    end

    -- Rule 5.5: Dropdown — catcher + list parented to ScreenGui, ZIndex=9+
    function tab:Dropdown(name, options, default, callback)
        local h = Instance.new("Frame")
        h.Size = UDim2.new(1, 0, 0, 38)
        h.BackgroundColor3 = C.panel
        h.BorderSizePixel = 0
        h.ZIndex = 5
        h.Parent = page
        corner(h, R.control)
        stroke(h, C.border, 1)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -30, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextColor3 = C.text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextWrapped = true
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Text = name .. " - " .. (default or options[1] or "")
        lbl.ZIndex = 5
        lbl.Parent = h
        local arrow = Instance.new("TextLabel")
        arrow.Size = UDim2.new(0, 18, 1, 0)
        arrow.Position = UDim2.new(1, -22, 0, 0)
        arrow.BackgroundTransparency = 1
        arrow.Font = Enum.Font.GothamBold
        arrow.TextSize = 12
        arrow.TextColor3 = C.muted
        arrow.Text = "v"
        arrow.ZIndex = 5
        arrow.Parent = h
        local obj = {Selected = default or options[1] or ""}
        local function openList()
            closePopup()
            arrow.Text = "^"
            local catcher = Instance.new("TextButton")
            catcher.Size = UDim2.new(1, 0, 1, 0)
            catcher.BackgroundTransparency = 1
            catcher.Text = ""
            catcher.AutoButtonColor = false
            catcher.Active = true
            catcher.ZIndex = 8
            catcher.Parent = screenGui  -- Rule 5.5: parented to ScreenGui
            local hPos = h.AbsolutePosition
            local hSize = h.AbsoluteSize
            local ITEM_H = 28
            local LIST_H = #options * (ITEM_H + 2) + 8
            local cam = workspace.CurrentCamera
            local vpH = cam and cam.ViewportSize.Y or 800
            local dd = (hPos.Y + hSize.Y + LIST_H + 6 <= vpH)
            local listY = dd and (hPos.Y + hSize.Y + 4) or (hPos.Y - LIST_H - 4)
            local list = Instance.new("Frame")
            list.Size = UDim2.new(0, hSize.X, 0, LIST_H)
            list.Position = UDim2.new(0, hPos.X, 0, listY)
            list.BackgroundColor3 = C.panel
            list.BorderSizePixel = 0
            list.ZIndex = 9  -- Rule 10: Popups ZIndex=9+
            list.Parent = screenGui  -- Rule 5.5: parented to ScreenGui
            corner(list, R.control)
            stroke(list, C.borderAcc, 1)
            local lL = Instance.new("UIListLayout")
            lL.Padding = UDim.new(0, 2)
            lL.Parent = list
            pad(list, 4, 4, 4, 4)
            for _, opt in ipairs(options) do
                local item = Instance.new("TextButton")
                item.Size = UDim2.new(1, 0, 0, ITEM_H)
                item.BackgroundColor3 = C.panelAlt
                item.Text = ""
                item.AutoButtonColor = false
                item.ZIndex = 10
                item.Parent = list
                corner(item, R.small)
                local iLbl = Instance.new("TextLabel")
                iLbl.Size = UDim2.new(1, -12, 1, 0)
                iLbl.Position = UDim2.new(0, 8, 0, 0)
                iLbl.BackgroundTransparency = 1
                iLbl.Font = Enum.Font.Gotham
                iLbl.TextSize = 12
                iLbl.TextColor3 = (opt == obj.Selected) and C.accent or C.text
                iLbl.TextXAlignment = Enum.TextXAlignment.Left
                iLbl.TextWrapped = true
                iLbl.TextTruncate = Enum.TextTruncate.AtEnd
                iLbl.Text = opt
                iLbl.ZIndex = 10
                iLbl.Parent = item
                item.MouseEnter:Connect(function() TweenService:Create(item, T10, {BackgroundColor3 = C.panelHov}):Play() end)
                item.MouseLeave:Connect(function() TweenService:Create(item, T10, {BackgroundColor3 = C.panelAlt}):Play() end)
                item.MouseButton1Click:Connect(function()
                    obj.Selected = opt
                    lbl.Text = name .. " - " .. opt
                    closePopup()
                    if callback then callback(opt) end
                end)
            end
            catcher.MouseButton1Click:Connect(closePopup)
            currentPopup = {catcher = catcher, popup = list}
        end
        h.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                openList()
            end
        end)
        function obj:Get() return obj.Selected end
        return obj
    end

    -- Rule 5.6: ColorPicker — popup parented to ScreenGui, Active=true
    function tab:ColorPicker(name, defaultColor, callback)
        local h = Instance.new("Frame")
        h.Size = UDim2.new(1, 0, 0, 38)
        h.BackgroundColor3 = C.panel
        h.BorderSizePixel = 0
        h.ZIndex = 5
        h.Parent = page
        corner(h, R.control)
        stroke(h, C.border, 1)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -70, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextColor3 = C.text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextWrapped = true
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Text = name
        lbl.ZIndex = 5
        lbl.Parent = h
        local swatch = Instance.new("TextButton")
        swatch.Size = UDim2.new(0, 52, 0, 28)
        swatch.Position = UDim2.new(1, -58, 0.5, -14)
        swatch.BackgroundColor3 = defaultColor or C.white
        swatch.Text = ""
        swatch.AutoButtonColor = false
        swatch.BorderSizePixel = 0
        swatch.ZIndex = 5
        swatch.Parent = h
        corner(swatch, R.small)
        stroke(swatch, C.border, 1.5)
        local obj = {Color = defaultColor or C.white}
        local function openPicker()
            closePopup()
            local r = math.floor(obj.Color.R * 255 + 0.5)
            local g = math.floor(obj.Color.G * 255 + 0.5)
            local b = math.floor(obj.Color.B * 255 + 0.5)
            local catcher = Instance.new("TextButton")
            catcher.Size = UDim2.new(1, 0, 1, 0)
            catcher.BackgroundColor3 = C.bg
            catcher.BackgroundTransparency = 0.4
            catcher.Text = ""
            catcher.AutoButtonColor = false
            catcher.Active = true
            catcher.ZIndex = 8
            catcher.Parent = screenGui  -- Rule 5.6: ScreenGui
            local sp = swatch.AbsolutePosition
            local cam = workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
            local px = math.clamp(sp.X - 230, 10, vp.X - 300)
            local py = math.clamp(sp.Y - 220, 10, vp.Y - 240)
            local panel = Instance.new("Frame")
            panel.Size = UDim2.new(0, 290, 0, 220)
            panel.Position = UDim2.new(0, px, 0, py)
            panel.BackgroundColor3 = C.panel
            panel.BorderSizePixel = 0
            panel.Active = true  -- Rule 5.6: blocks click-through
            panel.ZIndex = 9
            panel.Parent = screenGui  -- Rule 5.6: ScreenGui
            corner(panel, R.panel)
            stroke(panel, C.borderAcc, 1.5)
            local pTtl = Instance.new("TextLabel")
            pTtl.Size = UDim2.new(1, -16, 0, 18)
            pTtl.Position = UDim2.new(0, 10, 0, 10)
            pTtl.BackgroundTransparency = 1
            pTtl.Font = Enum.Font.GothamBold
            pTtl.TextSize = 12
            pTtl.TextColor3 = C.accent
            pTtl.TextXAlignment = Enum.TextXAlignment.Left
            pTtl.TextWrapped = true
            pTtl.TextTruncate = Enum.TextTruncate.AtEnd
            pTtl.Text = name
            pTtl.ZIndex = 9
            pTtl.Parent = panel
            local preview = Instance.new("Frame")
            preview.Size = UDim2.new(0, 44, 0, 44)
            preview.Position = UDim2.new(1, -54, 0, 10)
            preview.BackgroundColor3 = obj.Color
            preview.BorderSizePixel = 0
            preview.ZIndex = 9
            preview.Parent = panel
            corner(preview, R.small)
            stroke(preview, C.border, 1.5)
            local function updateColor()
                obj.Color = Color3.fromRGB(r, g, b)
                swatch.BackgroundColor3 = obj.Color
                preview.BackgroundColor3 = obj.Color
                if callback then callback(obj.Color) end
            end
            local function makeChannel(ch, yPos, getV, setV)
                local cl = Instance.new("TextLabel")
                cl.Size = UDim2.new(0, 14, 0, 18)
                cl.Position = UDim2.new(0, 10, 0, yPos)
                cl.BackgroundTransparency = 1
                cl.Font = Enum.Font.GothamBold
                cl.TextSize = 12
                cl.TextColor3 = C.text
                cl.Text = ch
                cl.ZIndex = 9
                cl.Parent = panel
                local tr = Instance.new("TextButton")
                tr.Size = UDim2.new(0, 190, 0, 14)
                tr.Position = UDim2.new(0, 30, 0, yPos + 2)
                tr.BackgroundColor3 = C.track
                tr.Text = ""
                tr.AutoButtonColor = false
                tr.ZIndex = 9
                tr.Parent = panel
                corner(tr, UDim.new(1, 0))
                local fl = Instance.new("Frame")
                fl.Size = UDim2.new(getV()/255, 0, 1, 0)
                fl.BackgroundColor3 = C.accent
                fl.BorderSizePixel = 0
                fl.ZIndex = 9
                fl.Parent = tr
                corner(fl, UDim.new(1, 0))
                local kb = Instance.new("Frame")
                kb.Size = UDim2.new(0, 16, 0, 16)
                kb.Position = UDim2.new(getV()/255, -8, 0.5, -8)
                kb.BackgroundColor3 = C.white
                kb.BorderSizePixel = 0
                kb.ZIndex = 10
                kb.Parent = tr
                corner(kb, UDim.new(1, 0))
                stroke(kb, C.accent, 1)
                local vl = Instance.new("TextLabel")
                vl.Size = UDim2.new(0, 30, 0, 18)
                vl.Position = UDim2.new(0, 230, 0, yPos)
                vl.BackgroundTransparency = 1
                vl.Font = Enum.Font.Code
                vl.TextSize = 11
                vl.TextColor3 = C.muted
                vl.TextXAlignment = Enum.TextXAlignment.Right
                vl.Text = tostring(getV())
                vl.ZIndex = 9
                vl.Parent = panel
                local dg = false
                local function sx(x)
                    local pct = math.clamp((x - tr.AbsolutePosition.X) / tr.AbsoluteSize.X, 0, 1)
                    local v = math.floor(pct * 255 + 0.5)
                    setV(v) fl.Size = UDim2.new(pct, 0, 1, 0)
                    kb.Position = UDim2.new(pct, -8, 0.5, -8)
                    vl.Text = tostring(v) updateColor()
                end
                tr.MouseButton1Down:Connect(function() dg = true sx(UserInputService:GetMouseLocation().X) end)
                UserInputService.InputChanged:Connect(function(inp)
                    if dg and inp.UserInputType == Enum.UserInputType.MouseMovement then sx(inp.Position.X) end
                end)
                UserInputService.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then dg = false end
                end)
            end
            makeChannel("R", 50, function() return r end, function(v) r = v end)
            makeChannel("G", 78, function() return g end, function(v) g = v end)
            makeChannel("B", 106, function() return b end, function(v) b = v end)
            local doneBtn = Instance.new("TextButton")
            doneBtn.Size = UDim2.new(0, 120, 0, 30)
            doneBtn.Position = UDim2.new(0.5, -60, 0, 175)
            doneBtn.BackgroundColor3 = C.accent
            doneBtn.Text = "Apply"
            doneBtn.Font = Enum.Font.GothamBold
            doneBtn.TextSize = 13
            doneBtn.TextColor3 = C.white
            doneBtn.BorderSizePixel = 0
            doneBtn.ZIndex = 10
            doneBtn.Parent = panel
            corner(doneBtn, R.small)
            local closed = false
            local function closePicker()
                if closed then return end closed = true
                pcall(function() catcher:Destroy() end)
                pcall(function() panel:Destroy() end)
            end
            doneBtn.MouseButton1Click:Connect(closePicker)
            catcher.MouseButton1Click:Connect(closePicker)
            currentPopup = {catcher = catcher, popup = panel}
        end
        swatch.MouseButton1Click:Connect(openPicker)
        function obj:Set(color) obj.Color = color swatch.BackgroundColor3 = color if callback then callback(color) end end
        return obj
    end

    function tab:Paragraph(title, body)
        local h = Instance.new("Frame")
        h.Size = UDim2.new(1, 0, 0, 0)
        h.BackgroundColor3 = C.panelAlt
        h.BorderSizePixel = 0
        h.AutomaticSize = Enum.AutomaticSize.Y
        h.ZIndex = 3
        h.Parent = page
        corner(h, R.control)
        stroke(h, C.border, 1)
        local ttl = Instance.new("TextLabel")
        ttl.Size = UDim2.new(1, -16, 0, 14)
        ttl.Position = UDim2.new(0, 8, 0, 6)
        ttl.BackgroundTransparency = 1
        ttl.Font = Enum.Font.GothamBold
        ttl.TextSize = 10
        ttl.TextColor3 = C.accent
        ttl.TextXAlignment = Enum.TextXAlignment.Left
        ttl.TextWrapped = true
        ttl.TextTruncate = Enum.TextTruncate.AtEnd
        ttl.Text = string.upper(title or "")
        ttl.ZIndex = 3
        ttl.Parent = h
        local cnt = Instance.new("TextLabel")
        cnt.Size = UDim2.new(1, -16, 0, 0)
        cnt.Position = UDim2.new(0, 8, 0, 22)
        cnt.BackgroundTransparency = 1
        cnt.Font = Enum.Font.Code
        cnt.TextSize = 11
        cnt.TextColor3 = C.textDim
        cnt.TextXAlignment = Enum.TextXAlignment.Left
        cnt.TextYAlignment = Enum.TextYAlignment.Top
        cnt.TextWrapped = true
        cnt.AutomaticSize = Enum.AutomaticSize.Y
        cnt.Text = body or ""
        cnt.ZIndex = 3
        cnt.Parent = h
        local spacer = Instance.new("Frame")
        spacer.Size = UDim2.new(1, 0, 0, 8)
        spacer.BackgroundTransparency = 1
        spacer.Parent = h
        local obj = {}
        function obj:Set(cfg)
            if cfg.Title then ttl.Text = string.upper(cfg.Title) end
            if cfg.Content then cnt.Text = cfg.Content end
        end
        return obj
    end

    return tab
end

-- ============================================================
-- 24. BUILD TABS
-- ============================================================
local FarmTab = CreateTab("Farm", "F")
FarmTab:Label("Mode & Speed")
FarmTab:Dropdown("Mode", {"Hybrid", "Legacy"}, "Hybrid", function(v) Config.FarmMode = v if Config.FarmEnabled then stopFarm() task.wait(0.1) startFarm() end end)
FarmTab:Dropdown("Speed", {"Infinity", "1e9", "1e15"}, "Infinity", function(v) Config.TrainSpeedValue = v end)
FarmTab:Slider("Workers", 1, 250, 25, "", function(v) Config.WorkerCount = v if Config.FarmEnabled and Config.FarmMode == "Hybrid" then killWorkers() local n = math.max(1, math.min(250, v * Config.FarmSpeedMul)) if Config.TurboActive then n = math.min(250, n * 2) end hybridState.currentWorkers = n spawnWorkers(n) end end)
FarmTab:Dropdown("Multiplier", {"0.5x", "1x", "2x"}, "1x", function(v) if v == "0.5x" then Config.FarmSpeedMul = 0.5 elseif v == "2x" then Config.FarmSpeedMul = 2 else Config.FarmSpeedMul = 1 end end)
FarmTab:Divider("options")
FarmTab:Toggle("Anti-Detect", false, function(t) Config.AntiDetect = t end)
FarmTab:Toggle("MAX PERFORMANCE", false, function(t) Config.MaxPerformance = t end)
local farmToggle = FarmTab:Toggle("START FARM", false, function(t) Config.FarmEnabled = t if t then startFarm() else stopFarm() end end)
FarmTab:Button("TURBO BOOST", function() setTurbo() end)
FarmTab:Divider("overnight")
FarmTab:Toggle("Overnight Mode", false, function(t) Config.OvernightEnabled = t if t then startOvernight() else stopOvernight() end end)
FarmTab:Divider("live stats")
local statsP = FarmTab:Paragraph("Power Tracker", "Start farm to see live stats...")
task.spawn(function()
    while task.wait(1) do
        local power = powerTracker.tick()
        local gains = powerTracker.avgGainsPerSec()
        local trend = powerTracker.trend()
        local ti = trend == "up" and "^" or (trend == "down" and "v" or "->")
        local st = powerTracker.sessionStart > 0 and math.floor(tick() - powerTracker.sessionStart) or 0
        pcall(function() statsP:Set({Content = "Power: " .. formatNumber(power) .. "  |  " .. ti .. " Gains/s: " .. formatNumber(gains) .. "  |  Session: " .. st .. "s  |  Workers: " .. activeWorkers}) end)
    end
end)

local MoveTab = CreateTab("Move", "M")
MoveTab:Label("Walk & Jump")
local ot = MoveTab:Toggle("Override Stats", false, function(t) Config.OverrideStats = t if t then applyMovement() else restoreMovement() end end)
local ws = MoveTab:Slider("WalkSpeed", 16, 1000, 16, " sp", function(v) Config.WalkSpeed = v applyMovement() end)
local js = MoveTab:Slider("JumpPower", 50, 1000, 50, " pw", function(v) Config.JumpPower = v applyMovement() end)
MoveTab:Button("Reset (16 / 50)", function() Config.WalkSpeed = 16 Config.JumpPower = 50 Config.OverrideStats = false ot:Set(false) ws:Set(16) js:Set(50) restoreMovement() notify("Movement", "Reset", 3, "info") end)
MoveTab:Divider("noclip")
MoveTab:Dropdown("Noclip Mode", {"V777", "Improved"}, "Improved", function(v) Config.NoclipMode = v if Config.NoclipEnabled then setNoclipMode(false) task.wait(0.05) setNoclipMode(true) end end)
MoveTab:Toggle("Noclip", false, function(t) setNoclipMode(t) end)

local IdTab = CreateTab("ID", "I")
IdTab:Label("Chat Identity")
IdTab:Dropdown("Title", {"GLOBAL", "SERVER ANNOUNCEMENT", "Head Admin", "Lead Dev", "None"}, "None", function(v) Config.CustomTag = (v == "None" or v == "") and "" or v end)
IdTab:Dropdown("Username", {"RezurXshin", "Jandel", "Administrator", "None"}, "None", function(v) Config.UserName = (v == "None" or v == "") and "" or v end)
IdTab:Input("Custom Title", "Enter title...", function(v) Config.CustomTag = v or "" end)
IdTab:Input("Custom Name", "Enter name...", function(v) Config.UserName = v or "" end)
IdTab:Divider("colors")
IdTab:ColorPicker("Tag Color", Config.TagColor, function(c) Config.TagColor = c end)
IdTab:ColorPicker("User Color", Config.UserColor, function(c) Config.UserColor = c end)
IdTab:ColorPicker("Message Color", Config.MessageColor, function(c) Config.MessageColor = c end)

local ChatTab = CreateTab("Chat", "C")
ChatTab:Label("Ghost Shout")
local chatBox = ChatTab:ChatInput("Message", "Type and press Enter...", function(msg) sendChatMessage(msg) notify("Sent", msg:sub(1, 40), 3, "success") end)
ChatTab:Button("Send (resend)", function() if chatBox.Text ~= "" then sendChatMessage(chatBox.Text) notify("Sent", chatBox.Text:sub(1, 40), 3, "success") end end)
ChatTab:Button("Clear", function() chatBox.Text = "" notify("Chat", "Cleared", 2, "info") end)

local LabTab = CreateTab("Lab", "L")
LabTab:Label("Experiments")
LabTab:Toggle("Anti-AFK", true, function(t) Config.AntiAfk = t end)
LabTab:Toggle("PVP Off", false, function(t) Config.PvpOff = t end)
LabTab:Divider("esp")
local function toggleESP(t)
    Config.EspEnabled = t
    if not t then clearEsp() return end
    espConn = RunService.RenderStepped:Connect(function()
        pcall(function()
            local cr = workspace:FindFirstChild("Creature")
            local ac = cr and cr:FindFirstChild("Activation") if not ac then return end
            local seen = {}
            for _, obj in ipairs(ac:GetChildren()) do
                for _, pm in ipairs(obj:GetChildren()) do
                    local h = pm:FindFirstChild("Head")
                    if h then
                        seen[h] = true
                        local e = espCache[h]
                        local pw = getPowerFor(pm.Name)
                        if not e then
                            local bb = Instance.new("BillboardGui") bb.Name="RT" bb.Adornee=h bb.Size=UDim2.new(0,100,0,30) bb.StudsOffset=Vector3.new(0,3,0) bb.AlwaysOnTop=true bb.Parent=h
                            local l = Instance.new("TextLabel") l.Parent=bb l.Size=UDim2.new(1,0,1,0) l.BackgroundTransparency=1 l.TextColor3=Color3.new(1,1,1) l.TextStrokeTransparency=0 l.TextScaled=true l.Text=formatNumber(pw)
                            espCache[h] = {gui=bb, label=l, lastValue=pw}
                        elseif e.lastValue ~= pw then e.label.Text = formatNumber(pw) e.lastValue = pw end
                    end
                end
            end
            for h, e in pairs(espCache) do if not seen[h] or not h.Parent then if e.gui then e.gui:Destroy() end espCache[h] = nil end end
        end)
    end)
end
LabTab:Toggle("ESP", false, toggleESP)
LabTab:Button("Clear ESP", function() clearEsp() notify("ESP", "Cleared", 3, "info") end)

local SysTab = CreateTab("Sys", "S")
SysTab:Label("Profile")
SysTab:Button("Save Profile", function()
    local p = {CustomTag=Config.CustomTag, UserName=Config.UserName, TagColor={Config.TagColor.R,Config.TagColor.G,Config.TagColor.B}, UserColor={Config.UserColor.R,Config.UserColor.G,Config.UserColor.B}, MessageColor={Config.MessageColor.R,Config.MessageColor.G,Config.MessageColor.B}, FarmMode=Config.FarmMode, FarmSpeedMul=Config.FarmSpeedMul, WorkerCount=Config.WorkerCount, MaxPerformance=Config.MaxPerformance, TrainSpeedValue=Config.TrainSpeedValue, AntiDetect=Config.AntiDetect, WalkSpeed=Config.WalkSpeed, JumpPower=Config.JumpPower, NoclipMode=Config.NoclipMode, AntiAfk=Config.AntiAfk}
    if writefile then writefile("DOMINUS_Profile.json", HttpService:JSONEncode(p)) notify("Saved", "Profile saved.", 3, "success") else notify("Error", "writefile not supported", 4, "error") end
end)
SysTab:Button("Load Profile", function()
    if not readfile then notify("Error", "readfile not supported", 4, "error") return end
    local ok, c = pcall(readfile, "DOMINUS_Profile.json")
    if not ok or not c then notify("Error", "No saved profile", 3, "warning") return end
    local ok2, p = pcall(function() return HttpService:JSONDecode(c) end)
    if not ok2 or type(p) ~= "table" then notify("Error", "Corrupted", 4, "error") return end
    Config.CustomTag=p.CustomTag or "" Config.UserName=p.UserName or ""
    if p.TagColor then Config.TagColor=Color3.new(p.TagColor[1],p.TagColor[2],p.TagColor[3]) end
    if p.UserColor then Config.UserColor=Color3.new(p.UserColor[1],p.UserColor[2],p.UserColor[3]) end
    if p.MessageColor then Config.MessageColor=Color3.new(p.MessageColor[1],p.MessageColor[2],p.MessageColor[3]) end
    Config.FarmMode=p.FarmMode or "Hybrid" Config.FarmSpeedMul=p.FarmSpeedMul or 1 Config.WorkerCount=p.WorkerCount or 25 Config.MaxPerformance=p.MaxPerformance or false Config.TrainSpeedValue=p.TrainSpeedValue or "Infinity" Config.AntiDetect=p.AntiDetect ~= nil and p.AntiDetect or false Config.WalkSpeed=p.WalkSpeed or 16 Config.JumpPower=p.JumpPower or 50 Config.NoclipMode=p.NoclipMode or "Improved" Config.AntiAfk=p.AntiAfk ~= nil and p.AntiAfk or true
    notify("Loaded", "Profile loaded.", 3, "info")
end)
SysTab:Divider("danger")
local dc = false
SysTab:Button("Destroy UI (confirm)", function()
    if dc then screenGui:Destroy() else dc = true notify("Confirm", "Click again within 3s", 3, "warning") task.delay(3, function() dc = false end) end
end)

local AboutTab = CreateTab("About", "A")
AboutTab:Label("About")
AboutTab:Paragraph("About", "DOMINUS UI\nMaximum Power Edition\n\nMade by RezurXshin\nCreator of RezurXLabs\n\nAll rights reserved to RezurXshin (Creator of RezurXLabs)\n\nEngine: Hybrid Farm + math.huge\nNoclip: V777 + Improved\nOvernight Mode\nTurbo Boost\nSave/Load Profiles\n\nPress K to toggle UI")
AboutTab:Divider("credits")
AboutTab:Paragraph("Credits", "Creator: RezurXshin\nStudio: RezurXLabs\n\nAll rights reserved.\n(c) 2026 RezurXshin.")

-- ============================================================
-- 25. KEYBOARD SHORTCUTS
-- ============================================================
UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    local k = inp.KeyCode
    if k == Enum.KeyCode.K then
        screenGui.Enabled = not screenGui.Enabled
    elseif k == Enum.KeyCode.F and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        Config.FarmEnabled = not Config.FarmEnabled
        if Config.FarmEnabled then startFarm() else stopFarm() end
        farmToggle:Set(Config.FarmEnabled)
        notify("Shortcut", "Farm: " .. (Config.FarmEnabled and "ON" or "OFF"), 2, "info")
    elseif k == Enum.KeyCode.N and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        Config.NoclipEnabled = not Config.NoclipEnabled
        setNoclipMode(Config.NoclipEnabled)
        notify("Shortcut", "Noclip: " .. (Config.NoclipEnabled and "ON" or "OFF"), 2, "info")
    elseif k == Enum.KeyCode.T and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        setTurbo()
    end
end)

-- ============================================================
-- 26. BOOT
-- ============================================================
notify("DOMINUS", "Loaded. Press K to toggle. Made by RezurXshin", 7, "success")
