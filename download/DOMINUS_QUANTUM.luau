-- ============================================================
-- DOMINUS ENGINE + ENHANCED UI (Quantum Edition)
-- Admin Panel v2.1 — RezurXLab
-- ============================================================
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local VirtualUser      = game:GetService("VirtualUser")
local HttpService      = game:GetService("HttpService")
local player           = Players.LocalPlayer

-- ============================================================
-- ENGINE CODE
-- ============================================================
local unpack = unpack or table.unpack

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

local notify
local applyMovement, restoreMovement
local executePump
local sendChatMessage
local initAllRemotes, healRemotesWithBackoff
local setTurbo
local startFarm, stopFarm
local startOvernight, stopOvernight
local setNoclipMode
local powerTracker

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
    AntiAfk = true, AntiDetect = false,  -- [FIX] no anti-cheat in this game → AntiDetect OFF for max speed
    AntiSlow = false,
    TurboActive = false, TurboUntil = 0, TurboCooldownUntil = 0,
}

local hybridState = {
    currentWorkers = 5, lastAdjust = 0,
    fpsHistory = {}, responseTimes = {},
    consecutiveFailures = 0, emergencyMode = false,
}

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

local TRAIN_SPEED = math.huge
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
    -- [FIX] No anti-cheat — skip shuffle for max speed
    for _, c in ipairs(calls) do
        if c.remote then
            if c.func == "Invoke" then
                pcall(c.remote.InvokeServer, c.remote, unpack(c.args))
            else
                pcall(c.remote.FireServer, c.remote, unpack(c.args))
            end
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
                task.wait(0.001)
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
        local trend = powerTracker.trend()
        local oldWorkers = hybridState.currentWorkers
        if avgFps < 15 then
            hybridState.emergencyMode = true
            hybridState.currentWorkers = 1
        elseif avgFps < 25 then
            hybridState.emergencyMode = false
            hybridState.currentWorkers = math.max(1, hybridState.currentWorkers - 1)
        elseif trend == "down" and hybridState.currentWorkers > 2 then
            hybridState.emergencyMode = false
            hybridState.currentWorkers = hybridState.currentWorkers - 1
        elseif trend == "up" and avgFps > 50 and hybridState.currentWorkers < 250 then
            hybridState.emergencyMode = false
            hybridState.currentWorkers = hybridState.currentWorkers + 1
        elseif trend == "flat" and avgFps > 50 and hybridState.currentWorkers < 100 then
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
    Config.TrainSpeedValue = "Infinity"
    Config.TurboActive = false
    Config.TurboUntil = 0
    Config.FarmEnabled = true
    startFarm()
    overnightPhase = "work"
    local cycleStart = tick()
    local lastFpsCheck = tick()
    local fpsLowStreak = 0
    overnightConn = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - lastFpsCheck >= 5 then
            lastFpsCheck = now
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
        if overnightPhase == "work" and now - cycleStart >= 300 then
            overnightPhase = "break"
            killWorkers()
            collectgarbage("collect")
            task.delay(30, function()
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
    Config.TrainSpeedValue = overnightOriginal.TrainSpeedValue or "Infinity"
    Config.TurboActive = false
    Config.FarmEnabled = false
    stopFarm()
    overnightPhase = "idle"
end

local TURBO_DUR = 10
local TURBO_CD = 5
setTurbo = function()
    if Config.OvernightEnabled then notify("Turbo", "Disabled in Overnight mode", 3, "warning") return end
    local now = tick()
    if Config.TurboActive then notify("Turbo", "Already active!", 3, "warning") return end
    if now < Config.TurboCooldownUntil then
        notify("Turbo Cooldown", "Wait " .. math.ceil(Config.TurboCooldownUntil - now) .. "s", 3, "warning")
        return
    end
    Config.TurboActive = true
    Config.TurboUntil = now + TURBO_DUR
    notify("TURBO", "2x farming for 10s!", 3, "success")
    if Config.FarmMode == "Hybrid" and Config.FarmEnabled then
        killWorkers()
        task.wait(0.05)
        spawnWorkers(math.min(250, hybridState.currentWorkers * 2))
    end
    task.spawn(function()
        while Config.TurboActive and tick() < Config.TurboUntil do task.wait(0.5) end
        Config.TurboActive = false
        Config.TurboCooldownUntil = tick() + TURBO_CD
        if Config.FarmMode == "Hybrid" and Config.FarmEnabled then
            killWorkers()
            task.wait(0.05)
            spawnWorkers(hybridState.currentWorkers)
        end
        notify("Turbo End", "Cooldown 5s", 3, "info")
    end)
end

local function buildChatMessage(msg)
    local tagPart, namePart = "", ""
    if Config.CustomTag ~= "" then
        tagPart = string.format('<font color="#%s"><b>[%s]</b></font> ', Config.TagColor:ToHex(), Config.CustomTag)
    end
    if Config.UserName ~= "" then
        namePart = string.format('<font color="#%s"><b>%s:</b></font> ', Config.UserColor:ToHex(), Config.UserName)
    end
    return tagPart .. namePart .. string.format('<font color="#%s"><b>%s</b></font>', Config.MessageColor:ToHex(), msg)
end
sendChatMessage = function(msg)
    if not Remotes.SendTextChatMessage then healRemotesWithBackoff() end
    if not Remotes.SendTextChatMessage or not msg or msg == "" then return end
    local full = buildChatMessage(msg)
    local ok1 = pcall(function() Remotes.SendTextChatMessage:InvokeServer({ Text = full }) end)
    if not ok1 then
        safeCall("chat-send", function() Remotes.SendTextChatMessage:InvokeServer(full) end)
    end
end

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

local noclipConn = nil
local noclipCharConn = nil
setNoclipMode = function(enabled)
    Config.NoclipEnabled = enabled
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if noclipCharConn then noclipCharConn:Disconnect() noclipCharConn = nil end
    if not enabled then return end
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
    if hum then
        hum.Died:Connect(function()
            if Config.FarmEnabled and Config.FarmMode == "Hybrid" then killWorkers() end
        end)
        if Config.OverrideStats then task.wait(0.2) applyMovement() end
        if Config.FarmEnabled and Config.FarmMode == "Hybrid" then
            task.wait(0.5)
            if Config.FarmEnabled then spawnWorkers(math.max(1, math.min(250, hybridState.currentWorkers))) end
        end
    end
end)
player.Idled:Connect(function()
    if not Config.AntiAfk then return end
    safeCall("anti-afk", function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end)
end)
task.spawn(function()
    while task.wait(0.5) do
        if Config.PvpOff then
            safeCall("pvp-off", function()
                local areaRoot = workspace:FindFirstChild("Area")
                local playerArea = areaRoot and areaRoot:FindFirstChild("PlayerArea")
                local s2 = playerArea and playerArea:FindFirstChild("S2")
                if s2 and Remotes.PlayerAreaIn then Remotes.PlayerAreaIn:InvokeServer(s2)
                elseif not Remotes.PlayerAreaIn then healRemotesWithBackoff() end
            end)
        end
    end
end)

-- ============================================================
-- END ENGINE CODE
-- ============================================================

-- ============================================================
-- ENHANCED UI (Admin Panel v2.1 with Quantum tab)
-- ============================================================
local T10 = TweenInfo.new(0.10, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local T15 = TweenInfo.new(0.15, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local T20 = TweenInfo.new(0.20, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local T35 = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local T50 = TweenInfo.new(0.50, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)

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
    black     = Color3.fromRGB(0,    0,   0),
}

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = (type(r) == "number") and UDim.new(0, r) or (r or UDim.new(0, 12))
    c.Parent = p
    return c
end
local function stroke(p, col, thick)
    local s = Instance.new("UIStroke")
    s.Color          = col or C.border
    s.Thickness      = thick or 1
    s.ApplyStrokeMode= Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end
local function pad(p, t, b, l, r)
    local u = Instance.new("UIPadding")
    u.PaddingTop    = UDim.new(0, t or 0)
    u.PaddingBottom = UDim.new(0, b or 0)
    u.PaddingLeft   = UDim.new(0, l or 0)
    u.PaddingRight  = UDim.new(0, r or 0)
    u.Parent = p
    return u
end
local function gradient(p, colorSeq, rot)
    local g = Instance.new("UIGradient")
    g.Color    = colorSeq
    g.Rotation = rot or 0
    g.Parent   = p
    return g
end

local function ripple(parent, posX, posY, col)
    local r = Instance.new("Frame")
    r.Size                   = UDim2.new(0, 0, 0, 0)
    r.Position               = UDim2.new(0, posX, 0, posY)
    r.AnchorPoint            = Vector2.new(0.5, 0.5)
    r.BackgroundColor3       = col or C.accent
    r.BackgroundTransparency = 0.55
    r.BorderSizePixel        = 0
    r.ZIndex                 = (parent:FindFirstAncestorWhichIsA("Frame") and 20) or 12
    r.Parent                 = parent
    corner(r, UDim.new(1, 0))
    local target = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 1.6
    local t = TweenService:Create(r, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, target, 0, target), BackgroundTransparency = 1})
    t:Play()
    t.Completed:Connect(function() r:Destroy() end)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name             = "RezurXLab_AdminPanel"
screenGui.ResetOnSpawn     = false
screenGui.IgnoreGuiInset   = true
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = player:WaitForChild("PlayerGui") end

local WIN_W, WIN_H   = 540, 480  -- [FIX] wider so all 8 tabs fit (was 460)
local HEADER_H       = 54
local TABBAR_H       = 32
local STATUSBAR_H    = 24
local CONTENT_TOP    = HEADER_H + TABBAR_H

local introBlock = Instance.new("Frame")
introBlock.Size                 = UDim2.new(1, 0, 1, 0)
introBlock.BackgroundColor3     = C.black
introBlock.BackgroundTransparency = 1
introBlock.BorderSizePixel      = 0
introBlock.ZIndex               = 50
introBlock.Parent               = screenGui

local shadow = Instance.new("Frame")
shadow.Name                 = "Shadow"
shadow.Size                 = UDim2.new(0, WIN_W + 36, 0, WIN_H + 36)
shadow.Position             = UDim2.new(0.5, -(WIN_W+36)/2, 0.4, -(WIN_H+36)/2)
shadow.BackgroundColor3     = Color3.new(0,0,0)
shadow.BackgroundTransparency = 0.52
shadow.BorderSizePixel      = 0
shadow.ZIndex               = 1
shadow.Parent               = screenGui
corner(shadow, 26)

local frame = Instance.new("Frame")
frame.Name             = "Window"
frame.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
frame.Position         = UDim2.new(0.5, -WIN_W/2, 0.4, -WIN_H/2)
frame.BackgroundColor3 = C.bg
frame.BorderSizePixel  = 0
frame.ClipsDescendants = true
frame.ZIndex           = 2
frame.Visible          = false  -- [FIX] start invisible — shown at entrance animation
frame.Parent           = screenGui
corner(frame, 18)
stroke(frame, C.border, 1.5)

local glowStrip = Instance.new("Frame")
glowStrip.Size             = UDim2.new(1, 0, 0, 3)
glowStrip.Position         = UDim2.new(0, 0, 0, HEADER_H - 3)
glowStrip.BackgroundColor3 = C.accent
glowStrip.BorderSizePixel  = 0
glowStrip.ZIndex           = 3
glowStrip.Parent           = frame
gradient(glowStrip, ColorSequence.new{
    ColorSequenceKeypoint.new(0.0, C.accentDim),
    ColorSequenceKeypoint.new(0.5, C.accentHi),
    ColorSequenceKeypoint.new(1.0, C.accentDim),
})

-- HEADER
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, HEADER_H)
header.BackgroundColor3 = C.panel
header.BorderSizePixel  = 0
header.ZIndex           = 4
header.Parent           = frame
corner(header, 18)
local hFix = Instance.new("Frame")
hFix.Size             = UDim2.new(1, 0, 0.5, 0)
hFix.Position         = UDim2.new(0, 0, 0.5, 0)
hFix.BackgroundColor3 = C.panel
hFix.BorderSizePixel  = 0
hFix.Parent           = header
local accentLine = Instance.new("Frame")
accentLine.Size             = UDim2.new(1, 0, 0, 2)
accentLine.Position         = UDim2.new(0, 0, 1, -2)
accentLine.BackgroundColor3 = C.accent
accentLine.BorderSizePixel  = 0
accentLine.Parent           = header

local logo = Instance.new("TextLabel")
logo.RichText            = true
logo.Text                = '<font color="#E2E2F0">Rezur</font><b><font color="#FF7A1C">X</font></b><font color="#E2E2F0">Lab</font>'
logo.Size                = UDim2.new(0, 220, 0, 26)
logo.Position            = UDim2.new(0, 14, 0, 7)
logo.BackgroundTransparency = 1
logo.Font                = Enum.Font.GothamBlack
logo.TextSize            = 22
logo.TextXAlignment      = Enum.TextXAlignment.Left
logo.Parent              = header

local subLbl = Instance.new("TextLabel")
subLbl.Text             = "DOMINUS Engine · Admin Panel"
subLbl.Size             = UDim2.new(0, 280, 0, 13)
subLbl.Position         = UDim2.new(0, 15, 0, 37)
subLbl.BackgroundTransparency = 1
subLbl.Font             = Enum.Font.GothamMedium
subLbl.TextSize         = 11
subLbl.TextColor3       = C.muted
subLbl.TextXAlignment   = Enum.TextXAlignment.Left
subLbl.Parent           = header

local fpsFrame = Instance.new("Frame")
fpsFrame.Size             = UDim2.new(0, 72, 0, 26)
fpsFrame.Position         = UDim2.new(0, 300, 0.5, -13)  -- [FIX] moved right for wider window
fpsFrame.BackgroundColor3 = C.panelAlt
fpsFrame.BorderSizePixel  = 0
fpsFrame.Parent           = header
corner(fpsFrame, 8)
stroke(fpsFrame, C.border, 1)
local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size               = UDim2.new(1, 0, 1, 0)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Font               = Enum.Font.Code
fpsLabel.TextSize           = 12
fpsLabel.TextColor3         = C.green
fpsLabel.Text               = "60 FPS"
fpsLabel.Parent             = fpsFrame

-- DRAG (placed before minimize to keep references)
local dragging, dragStart, startPos
header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = inp.Position
        startPos  = frame.Position
        TweenService:Create(shadow, T15, {BackgroundTransparency = 0.65}):Play()
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch) then
        local d  = inp.Position - dragStart
        local np = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                             startPos.Y.Scale, startPos.Y.Offset + d.Y)
        frame.Position  = np
        shadow.Position = UDim2.new(np.X.Scale, np.X.Offset - 18,
                                    np.Y.Scale, np.Y.Offset - 18)
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            TweenService:Create(shadow, T15, {BackgroundTransparency = 0.52}):Play()
        end
        dragging = false
    end
end)

-- TAB BAR
local tabBar = Instance.new("ScrollingFrame")  -- [FIX] was Frame — now scrollable so tabs never get clipped
tabBar.Size             = UDim2.new(1, 0, 0, TABBAR_H)
tabBar.Position         = UDim2.new(0, 0, 0, HEADER_H)
tabBar.BackgroundColor3 = C.panelAlt
tabBar.BorderSizePixel  = 0
tabBar.ZIndex           = 3
tabBar.ScrollBarThickness = 0
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
tabBar.CanvasSize       = UDim2.new(0, 0, 0, 0)
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
tabBar.Parent           = frame
stroke(tabBar, C.border, 0.5)

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding       = UDim.new(0, 1)  -- [FIX] was 2 — tighter spacing so more tabs fit
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
tabLayout.SortOrder           = Enum.SortOrder.LayoutOrder
tabLayout.Parent              = tabBar
pad(tabBar, 0, 0, 4, 4)

-- CONTENT AREA
local content = Instance.new("Frame")
content.Size               = UDim2.new(1, 0, 1, -(HEADER_H + TABBAR_H + STATUSBAR_H))
content.Position           = UDim2.new(0, 0, 0, CONTENT_TOP)
content.BackgroundTransparency = 1
content.Parent             = frame

-- STATUS BAR
local statusBar = Instance.new("Frame")
statusBar.Size             = UDim2.new(1, 0, 0, STATUSBAR_H)
statusBar.Position         = UDim2.new(0, 0, 1, -STATUSBAR_H)
statusBar.BackgroundColor3 = C.panel
statusBar.BorderSizePixel  = 0
statusBar.ZIndex           = 4
statusBar.Parent           = frame
corner(statusBar, 18)
local sbFix = Instance.new("Frame")
sbFix.Size             = UDim2.new(1, 0, 0.5, 0)
sbFix.Position         = UDim2.new(0, 0, 0, 0)
sbFix.BackgroundColor3 = C.panel
sbFix.BorderSizePixel  = 0
sbFix.ZIndex           = 4
sbFix.Parent           = statusBar
local sbTopLine = Instance.new("Frame")
sbTopLine.Size             = UDim2.new(1, 0, 0, 1)
sbTopLine.BackgroundColor3 = C.border
sbTopLine.BorderSizePixel  = 0
sbTopLine.ZIndex           = 5
sbTopLine.Parent           = statusBar

local sDot = Instance.new("Frame")
sDot.Size             = UDim2.new(0, 7, 0, 7)
sDot.Position         = UDim2.new(0, 10, 0.5, -3)
sDot.BackgroundColor3 = C.green
sDot.BorderSizePixel  = 0
sDot.Parent           = statusBar
corner(sDot, 4)
task.spawn(function()
    while true do
        TweenService:Create(sDot, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {BackgroundColor3 = C.greenDim}):Play()
        task.wait(0.7)
        TweenService:Create(sDot, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {BackgroundColor3 = C.green}):Play()
        task.wait(0.7)
    end
end)

local sTxt = Instance.new("TextLabel")
sTxt.Size               = UDim2.new(0, 110, 1, 0)
sTxt.Position           = UDim2.new(0, 22, 0, 0)
sTxt.BackgroundTransparency = 1
sTxt.Font               = Enum.Font.Code
sTxt.TextSize           = 10
sTxt.TextColor3         = C.muted
sTxt.TextXAlignment     = Enum.TextXAlignment.Left
sTxt.Text               = "READY"
sTxt.Parent             = statusBar
local sBootTime = os.clock()
task.spawn(function()
    while true do
        local e = os.clock() - sBootTime
        sTxt.Text = string.format("UP  %02d:%02d", math.floor(e/60), math.floor(e%60))
        task.wait(1)
    end
end)

local sVer = Instance.new("TextLabel")
sVer.Size               = UDim2.new(0, 230, 1, 0)
sVer.Position           = UDim2.new(1, -234, 0, 0)
sVer.BackgroundTransparency = 1
sVer.Font               = Enum.Font.Code
sVer.TextSize           = 10
sVer.TextColor3         = C.muted
sVer.TextXAlignment     = Enum.TextXAlignment.Right
sVer.Text               = "RezurXLab DOMINUS v2.1  ·  Quantum"
sVer.Parent             = statusBar

-- ============================================================
-- MINIMIZE BUTTON — created AFTER tabBar, content, statusBar are defined
-- ============================================================
local minBtn = Instance.new("TextButton")
minBtn.Text             = "—"
minBtn.Size             = UDim2.new(0, 30, 0, 28)
minBtn.Position         = UDim2.new(1, -74, 0.5, -14)
minBtn.BackgroundColor3 = C.panelAlt
minBtn.TextColor3       = C.muted
minBtn.TextSize         = 15
minBtn.Font             = Enum.Font.GothamBold
minBtn.BorderSizePixel  = 0
minBtn.AutoButtonColor  = false
minBtn.Parent           = header
corner(minBtn, 8)
stroke(minBtn, C.border, 1)
minBtn.MouseEnter:Connect(function()
    TweenService:Create(minBtn, T10, {BackgroundColor3 = C.panelHov, TextColor3 = C.text}):Play()
end)
minBtn.MouseLeave:Connect(function()
    TweenService:Create(minBtn, T10, {BackgroundColor3 = C.panelAlt, TextColor3 = C.muted}):Play()
end)
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    local wH  = minimized and HEADER_H or WIN_H
    local shH = minimized and (HEADER_H + 36) or (WIN_H + 36)
    tabBar.Visible     = not minimized
    content.Visible    = not minimized
    statusBar.Visible  = not minimized
    TweenService:Create(frame,  T35, {Size = UDim2.new(0, WIN_W, 0, wH)}):Play()
    TweenService:Create(shadow, T35, {Size = UDim2.new(0, WIN_W+36, 0, shH)}):Play()
    minBtn.Text = minimized and "+" or "—"
end)

-- CLOSE BUTTON (with fade-out animation)
local closeBtn = Instance.new("TextButton")
closeBtn.Text             = "✕"
closeBtn.Size             = UDim2.new(0, 30, 0, 28)
closeBtn.Position         = UDim2.new(1, -38, 0.5, -14)
closeBtn.BackgroundColor3 = C.red
closeBtn.TextColor3       = C.white
closeBtn.TextSize         = 12
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.BorderSizePixel  = 0
closeBtn.AutoButtonColor  = false
closeBtn.Parent           = header
corner(closeBtn, 8)
closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, T10, {BackgroundColor3 = Color3.fromRGB(238,68,68)}):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, T10, {BackgroundColor3 = C.red}):Play()
end)
closeBtn.MouseButton1Click:Connect(function()
    local outT = TweenService:Create(frame, T20, {BackgroundTransparency = 1})
    TweenService:Create(shadow, T20, {BackgroundTransparency = 1})
    for _, d in ipairs(frame:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            TweenService:Create(d, T20, {TextTransparency = 1}):Play()
        elseif d:IsA("Frame") or d:IsA("ScrollingFrame") then
            pcall(function() TweenService:Create(d, T20, {BackgroundTransparency = 1}):Play() end)
        elseif d:IsA("UIStroke") then
            TweenService:Create(d, T20, {Transparency = 1}):Play()
        end
    end
    outT:Play()
    outT.Completed:Connect(function()
        screenGui.Enabled = not screenGui.Enabled
        task.wait(0.05)
        frame.BackgroundTransparency = 0
        shadow.BackgroundTransparency = 0.52
        for _, d in ipairs(frame:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                d.TextTransparency = 0
            elseif d:IsA("UIStroke") then
                d.Transparency = 0
            end
        end
    end)
end)

-- ============================================================
-- POPUP MANAGER
-- ============================================================
local currentPopup = nil
local function closeCurrentPopup()
    if currentPopup then
        pcall(function() currentPopup.catcher:Destroy() end)
        pcall(function() currentPopup.popup:Destroy() end)
        pcall(function()
            if currentPopup.arrow then currentPopup.arrow.Text = "▾" end
        end)
        currentPopup = nil
    end
end

-- ============================================================
-- NOTIFICATION SYSTEM
-- ============================================================
local notifContainer = Instance.new("Frame")
notifContainer.Size               = UDim2.new(0, 300, 1, -20)
notifContainer.Position           = UDim2.new(1, -308, 0, 10)
notifContainer.BackgroundTransparency = 1
notifContainer.Active             = false
notifContainer.ZIndex             = 6
notifContainer.Parent             = screenGui
local nLayout = Instance.new("UIListLayout")
nLayout.Padding             = UDim.new(0, 6)
nLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
nLayout.VerticalAlignment   = Enum.VerticalAlignment.Bottom
nLayout.Parent              = notifContainer

local NTYPES = {
    info    = {icon = "ℹ",  color = C.accent },
    success = {icon = "✓",  color = C.green  },
    warning = {icon = "⚠",  color = C.yellow },
    error   = {icon = "✕",  color = C.red    },
}

notify = function(title, body, duration, ntype)
    ntype    = ntype or "info"
    duration = duration or 5
    local cfg = NTYPES[ntype] or NTYPES.info
    local col = cfg.color

    local n = Instance.new("Frame")
    n.Size                   = UDim2.new(1, 30, 0, 0)
    n.Position               = UDim2.new(0, 30, 0, 0)
    n.BackgroundColor3       = C.panel
    n.BackgroundTransparency = 1
    n.ClipsDescendants       = true
    n.ZIndex                 = 6
    n.Parent                 = notifContainer
    corner(n, 12)
    stroke(n, C.border, 1)

    local strip = Instance.new("Frame")
    strip.Size             = UDim2.new(0, 3, 1, 0)
    strip.BackgroundColor3 = col
    strip.BorderSizePixel  = 0
    strip.ZIndex           = 6
    strip.Parent           = n
    corner(strip, 2)

    local iconF = Instance.new("Frame")
    iconF.Size                   = UDim2.new(0, 26, 0, 26)
    iconF.Position               = UDim2.new(0, 10, 0, 11)
    iconF.BackgroundColor3       = col
    iconF.BackgroundTransparency = 0.82
    iconF.BorderSizePixel        = 0
    iconF.ZIndex                 = 6
    iconF.Parent                 = n
    corner(iconF, 6)
    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size               = UDim2.new(1, 0, 1, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Font               = Enum.Font.GothamBold
    iconLbl.TextSize           = 13
    iconLbl.TextColor3         = col
    iconLbl.Text               = cfg.icon
    iconLbl.ZIndex             = 6
    iconLbl.Parent             = iconF

    local ttl = Instance.new("TextLabel")
    ttl.Size               = UDim2.new(1, -50, 0, 17)
    ttl.Position           = UDim2.new(0, 44, 0, 9)
    ttl.BackgroundTransparency = 1
    ttl.Font               = Enum.Font.GothamBold
    ttl.TextSize           = 13
    ttl.TextColor3         = col
    ttl.TextXAlignment     = Enum.TextXAlignment.Left
    ttl.Text               = title or ""
    ttl.ZIndex             = 6
    ttl.Parent             = n

    local cnt = Instance.new("TextLabel")
    cnt.Size               = UDim2.new(1, -50, 0, 32)
    cnt.Position           = UDim2.new(0, 44, 0, 27)
    cnt.BackgroundTransparency = 1
    cnt.Font               = Enum.Font.Gotham
    cnt.TextSize           = 12
    cnt.TextColor3         = C.textDim
    cnt.TextXAlignment     = Enum.TextXAlignment.Left
    cnt.TextYAlignment     = Enum.TextYAlignment.Top
    cnt.TextWrapped        = true
    cnt.Text               = body or ""
    cnt.ZIndex             = 6
    cnt.Parent             = n

    local prog = Instance.new("Frame")
    prog.Size             = UDim2.new(1, 0, 0, 2)
    prog.Position         = UDim2.new(0, 0, 1, -2)
    prog.BackgroundColor3 = col
    prog.BackgroundTransparency = 0.45
    prog.BorderSizePixel  = 0
    prog.ZIndex           = 6
    prog.Parent           = n

    TweenService:Create(n, T20, {BackgroundTransparency = 0.05}):Play()
    TweenService:Create(n, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 0, 68),
        Position = UDim2.new(0, 0, 0, 0),
    }):Play()

    task.delay(0.25, function()
        TweenService:Create(prog, TweenInfo.new(duration, Enum.EasingStyle.Linear),
            {Size = UDim2.new(0, 0, 0, 2)}):Play()
    end)
    task.delay(duration, function()
        local t = TweenService:Create(n, T20, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1})
        t:Play()
        t.Completed:Connect(function() n:Destroy() end)
    end)
    return n
end

-- FPS counter
local fpsAvg = 60
RunService.Heartbeat:Connect(function(dt)
    fpsAvg = fpsAvg * 0.88 + (1 / math.max(dt, 0.001)) * 0.12
    local avg = math.floor(fpsAvg + 0.5)
    fpsLabel.Text      = avg .. " FPS"
    fpsLabel.TextColor3 = avg >= 55 and C.green or avg >= 30 and C.yellow or C.red
end)

-- ============================================================
-- TAB SYSTEM
-- ============================================================
local Tabs     = {}
local ActiveTab = nil

local function CreateTab(name, icon)
    local tab = {}

    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 70, 1, -4)  -- [FIX] default 70px (was 0 = invisible)
    btn.BackgroundColor3 = C.panelAlt
    btn.BackgroundTransparency = 0  -- [FIX] was 0.55 (blended into tab bar)
    btn.AutoButtonColor  = false
    btn.BorderSizePixel  = 0
    btn.Text             = ""
    btn.ClipsDescendants = true
    btn.Parent           = tabBar
    corner(btn, 4)
    stroke(btn, C.borderAcc, 1)  -- [FIX] orange outline on every tab

    local contentHolder = Instance.new("TextLabel")
    contentHolder.Size               = UDim2.new(1, 0, 1, 0)
    contentHolder.BackgroundTransparency = 1
    contentHolder.Font               = Enum.Font.GothamBold
    contentHolder.TextSize           = 11  -- [FIX] was 12 — slightly smaller for narrower tabs
    contentHolder.TextColor3         = C.textDim
    contentHolder.Text               = (icon or "") .. " " .. name
    contentHolder.Parent             = btn

    local underline = Instance.new("Frame")
    underline.Size             = UDim2.new(0, 0, 0, 2)
    underline.Position         = UDim2.new(0.5, 0, 1, -2)
    underline.AnchorPoint      = Vector2.new(0.5, 0)
    underline.BackgroundColor3 = C.accent
    underline.BorderSizePixel  = 0
    underline.Visible          = false
    underline.Parent           = btn

    local page = Instance.new("ScrollingFrame")
    page.Size                   = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness     = 3
    page.ScrollBarImageColor3   = C.accent
    page.ScrollBarImageTransparency = 0.40
    page.CanvasSize             = UDim2.new(0, 0, 0, 0)
    page.Visible                = false
    page.Parent                 = content

    local pLayout = Instance.new("UIListLayout")
    pLayout.Padding = UDim.new(0, 6)
    pLayout.Parent  = page
    pad(page, 10, 10, 9, 10)

    pLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, pLayout.AbsoluteContentSize.Y + 20)
    end)

    tab.Page      = page
    tab.Btn       = btn
    tab.Name      = name
    tab.underline = underline
    tab.iconLbl   = contentHolder

    local function updateBtnSize()
        local textBounds = contentHolder.TextBounds
        local w = math.max(50, textBounds.X + 16)  -- [FIX] minimum 50px + tighter padding
        btn.Size = UDim2.new(0, w, 1, -4)
    end
    contentHolder:GetPropertyChangedSignal("Text"):Connect(updateBtnSize)
    contentHolder:GetPropertyChangedSignal("TextBounds"):Connect(updateBtnSize)
    updateBtnSize()

    local function setActive()
        if ActiveTab and ActiveTab ~= tab then
            ActiveTab.Page.Visible = false
            ActiveTab.underline.Visible = false
            ActiveTab.underline.Size = UDim2.new(0, 0, 0, 2)
            TweenService:Create(ActiveTab.Btn, T20, {BackgroundColor3 = C.panelAlt, BackgroundTransparency = 0.55}):Play()
            TweenService:Create(ActiveTab.iconLbl, T20, {TextColor3 = C.textDim}):Play()
        end
        ActiveTab = tab
        tab.Page.Visible = true
        tab.underline.Visible = true
        tab.underline.Size = UDim2.new(0, 0, 0, 2)
        TweenService:Create(tab.underline, T20, {Size = UDim2.new(1, -16, 0, 2)}):Play()
        TweenService:Create(btn, T20, {BackgroundColor3 = C.accentDark, BackgroundTransparency = 0.2}):Play()
        TweenService:Create(contentHolder, T20, {TextColor3 = C.accent}):Play()
    end

    btn.MouseEnter:Connect(function()
        if ActiveTab ~= tab then
            TweenService:Create(btn, T10, {BackgroundColor3 = C.panelHov, BackgroundTransparency = 0.3}):Play()
            TweenService:Create(contentHolder, T10, {TextColor3 = C.text}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if ActiveTab ~= tab then
            TweenService:Create(btn, T10, {BackgroundColor3 = C.panelAlt, BackgroundTransparency = 0.55}):Play()
            TweenService:Create(contentHolder, T10, {TextColor3 = C.textDim}):Play()
        end
    end)
    btn.MouseButton1Click:Connect(setActive)

    table.insert(Tabs, tab)
    if #Tabs == 1 then setActive() end

    -- ============================================================
    -- COMPONENT METHODS
    -- ============================================================
    function tab:Label(text)
        local l = Instance.new("TextLabel")
        l.Size               = UDim2.new(1, 0, 0, 18)
        l.BackgroundTransparency = 1
        l.Font               = Enum.Font.GothamBold
        l.TextSize           = 10
        l.TextColor3         = C.accent
        l.TextXAlignment     = Enum.TextXAlignment.Left
        l.Text               = string.upper(text)
        l.Parent             = page
        return l
    end

    function tab:Divider(text)
        local holder = Instance.new("Frame")
        holder.Size               = UDim2.new(1, 0, 0, 20)
        holder.BackgroundTransparency = 1
        holder.Parent             = page
        if text and text ~= "" then
            local lbl = Instance.new("TextLabel")
            lbl.Size               = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font               = Enum.Font.GothamBold
            lbl.TextSize           = 10
            lbl.TextColor3         = C.muted
            lbl.TextXAlignment     = Enum.TextXAlignment.Left
            lbl.Text               = "──  " .. string.upper(text)
            lbl.Parent             = holder
        else
            local line = Instance.new("Frame")
            line.Size             = UDim2.new(1, 0, 0, 1)
            line.Position         = UDim2.new(0, 0, 0.5, 0)
            line.BackgroundColor3 = C.border
            line.BorderSizePixel  = 0
            line.Parent           = holder
        end
        return holder
    end

    function tab:Keybind(action, key)
        local holder = Instance.new("Frame")
        holder.Size             = UDim2.new(1, 0, 0, 38)
        holder.BackgroundColor3 = C.panel
        holder.BorderSizePixel  = 0
        holder.Parent           = page
        corner(holder, 10)
        stroke(holder, C.border, 1)

        local lbl = Instance.new("TextLabel")
        lbl.Size               = UDim2.new(1, -88, 1, 0)
        lbl.Position           = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font               = Enum.Font.Gotham
        lbl.TextSize           = 13
        lbl.TextColor3         = C.textDim
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.Text               = action
        lbl.Parent             = holder

        local pill = Instance.new("Frame")
        pill.Size             = UDim2.new(0, 72, 0, 24)
        pill.Position         = UDim2.new(1, -80, 0.5, -12)
        pill.BackgroundColor3 = C.accentDark
        pill.BorderSizePixel  = 0
        pill.Parent           = holder
        corner(pill, 6)
        stroke(pill, C.accentDim, 1)
        local keyLbl = Instance.new("TextLabel")
        keyLbl.Size               = UDim2.new(1, 0, 1, 0)
        keyLbl.BackgroundTransparency = 1
        keyLbl.Font               = Enum.Font.GothamBold
        keyLbl.TextSize           = 11
        keyLbl.TextColor3         = C.accent
        keyLbl.Text               = key
        keyLbl.Parent             = pill
        return holder
    end

    function tab:Button(name, callback)
        local b = Instance.new("TextButton")
        b.Size             = UDim2.new(1, 0, 0, 42)
        b.BackgroundColor3 = C.panel
        b.Text             = ""
        b.AutoButtonColor  = false
        b.BorderSizePixel  = 0
        b.ClipsDescendants = true
        b.Parent           = page
        corner(b, 10)
        stroke(b, C.border, 1)

        local lbl = Instance.new("TextLabel")
        lbl.Size               = UDim2.new(1, -32, 1, 0)
        lbl.Position           = UDim2.new(0, 14, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font               = Enum.Font.GothamMedium
        lbl.TextSize           = 13
        lbl.TextColor3         = C.text
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.Text               = name
        lbl.Parent             = b

        local arr = Instance.new("TextLabel")
        arr.Size               = UDim2.new(0, 18, 1, 0)
        arr.Position           = UDim2.new(1, -22, 0, 0)
        arr.BackgroundTransparency = 1
        arr.Font               = Enum.Font.GothamBold
        arr.TextSize           = 14
        arr.TextColor3         = C.muted
        arr.Text               = "›"
        arr.Parent             = b

        b.MouseEnter:Connect(function()
            TweenService:Create(b,   T10, {BackgroundColor3 = C.panelHov}):Play()
            TweenService:Create(arr, T10, {TextColor3 = C.accent, Position = UDim2.new(1, -18, 0, 0)}):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b,   T10, {BackgroundColor3 = C.panel}):Play()
            TweenService:Create(arr, T10, {TextColor3 = C.muted, Position = UDim2.new(1, -22, 0, 0)}):Play()
        end)
        b.MouseButton1Click:Connect(function(x, y)
            ripple(b, b.AbsoluteSize.X - 30, b.AbsoluteSize.Y / 2, C.accent)
            TweenService:Create(b,   T10, {BackgroundColor3 = C.accentDim}):Play()
            TweenService:Create(lbl, T10, {TextColor3 = C.white}):Play()
            task.delay(0.13, function()
                TweenService:Create(b,   T10, {BackgroundColor3 = C.panelHov}):Play()
                TweenService:Create(lbl, T10, {TextColor3 = C.text}):Play()
            end)
            if callback then task.spawn(pcall, callback) end
        end)
        return b
    end

    function tab:Toggle(name, default, callback)
        local state = default == true
        local holder = Instance.new("Frame")
        holder.Size             = UDim2.new(1, 0, 0, 42)
        holder.BackgroundColor3 = C.panel
        holder.BorderSizePixel  = 0
        holder.Parent           = page
        corner(holder, 10)
        local hStroke = stroke(holder, C.border, 1)

        local lbl = Instance.new("TextLabel")
        lbl.Size               = UDim2.new(1, -68, 1, 0)
        lbl.Position           = UDim2.new(0, 14, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font               = Enum.Font.GothamMedium
        lbl.TextSize           = 13
        lbl.TextColor3         = C.text
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.Text               = name
        lbl.Parent             = holder

        local sw = Instance.new("Frame")
        sw.Size             = UDim2.new(0, 42, 0, 22)
        sw.Position         = UDim2.new(1, -52, 0.5, -11)
        sw.BackgroundColor3 = state and C.accent or C.track
        sw.BorderSizePixel  = 0
        sw.Parent           = holder
        corner(sw, UDim.new(1, 0))

        local knob = Instance.new("Frame")
        knob.Size             = UDim2.new(0, 18, 0, 18)
        knob.Position         = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        knob.BackgroundColor3 = C.white
        knob.BorderSizePixel  = 0
        knob.Parent           = sw
        corner(knob, UDim.new(1, 0))

        local obj = {}
        local function apply(v)
            state = v
            TweenService:Create(sw,   T20, {BackgroundColor3 = state and C.accent or C.track}):Play()
            TweenService:Create(hStroke, T20, {Color = state and C.accentDim or C.border}):Play()
            TweenService:Create(knob, T50, {
                Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
            }):Play()
            if callback then callback(state) end
        end
        function obj:Set(v) apply(v) end
        function obj:Get() return state end
        holder.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                apply(not state)
            end
        end)
        return obj
    end

    function tab:Slider(name, minVal, maxVal, default, suffix, callback)
        local holder = Instance.new("Frame")
        holder.Size             = UDim2.new(1, 0, 0, 52)
        holder.BackgroundColor3 = C.panel
        holder.BorderSizePixel  = 0
        holder.Parent           = page
        corner(holder, 10)
        stroke(holder, C.border, 1)

        local lbl = Instance.new("TextLabel")
        lbl.Size               = UDim2.new(1, -80, 0, 18)
        lbl.Position           = UDim2.new(0, 14, 0, 6)
        lbl.BackgroundTransparency = 1
        lbl.Font               = Enum.Font.GothamMedium
        lbl.TextSize           = 13
        lbl.TextColor3         = C.text
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.Text               = name
        lbl.Parent             = holder

        local valLbl = Instance.new("TextLabel")
        valLbl.Size               = UDim2.new(0, 64, 0, 18)
        valLbl.Position           = UDim2.new(1, -72, 0, 6)
        valLbl.BackgroundTransparency = 1
        valLbl.Font               = Enum.Font.GothamBold
        valLbl.TextSize           = 13
        valLbl.TextColor3         = C.accent
        valLbl.TextXAlignment     = Enum.TextXAlignment.Right
        valLbl.Text               = tostring(default) .. (suffix or "")
        valLbl.Parent             = holder

        local track = Instance.new("Frame")
        track.Size             = UDim2.new(1, -28, 0, 6)
        track.Position         = UDim2.new(0, 14, 0, 36)
        track.BackgroundColor3 = C.track
        track.BorderSizePixel  = 0
        track.Parent           = holder
        corner(track, UDim.new(1, 0))

        local fill = Instance.new("Frame")
        fill.Size             = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = C.accent
        fill.BorderSizePixel  = 0
        fill.Parent           = track
        corner(fill, UDim.new(1, 0))
        gradient(fill, ColorSequence.new{
            ColorSequenceKeypoint.new(0, C.accentDim),
            ColorSequenceKeypoint.new(1, C.accentHi),
        })

        local knob = Instance.new("Frame")
        knob.Size             = UDim2.new(0, 16, 0, 16)
        knob.Position         = UDim2.new(0, -8, 0.5, -8)
        knob.BackgroundColor3 = C.white
        knob.BorderSizePixel  = 0
        knob.Parent           = track
        corner(knob, UDim.new(1, 0))
        stroke(knob, C.accent, 1.5)

        local value = default
        local function update(animated)
            local pct = math.clamp((value - minVal) / (maxVal - minVal), 0, 1)
            if animated then
                TweenService:Create(fill, T10, {Size = UDim2.new(pct, 0, 1, 0)}):Play()
                TweenService:Create(knob, T10, {Position = UDim2.new(pct, -8, 0.5, -8)}):Play()
            else
                fill.Size     = UDim2.new(pct, 0, 1, 0)
                knob.Position = UDim2.new(pct, -8, 0.5, -8)
            end
            valLbl.Text   = tostring(value) .. (suffix or "")
        end
        update(false)

        local obj = {}
        function obj:Set(v)
            value = math.clamp(v, minVal, maxVal)
            update(true)
            if callback then callback(value) end
        end
        function obj:Get() return value end

        local sdrag = false
        local function setFromX(x)
            local pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            value = math.floor(minVal + pct * (maxVal - minVal) + 0.5)
            update(false)
            if callback then callback(value) end
        end
        track.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                sdrag = true
                TweenService:Create(knob, T10, {Size = UDim2.new(0, 20, 0, 20)}):Play()
                setFromX(inp.Position.X)
            end
        end)
        track.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                sdrag = false
                TweenService:Create(knob, T10, {Size = UDim2.new(0, 16, 0, 16)}):Play()
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if sdrag and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
                setFromX(inp.Position.X)
            end
        end)
        return obj
    end

    function tab:Input(name, placeholder, callback)
        local holder = Instance.new("Frame")
        holder.Size             = UDim2.new(1, 0, 0, 48)
        holder.BackgroundColor3 = C.panel
        holder.BorderSizePixel  = 0
        holder.Parent           = page
        corner(holder, 10)
        local strk = stroke(holder, C.border, 1)

        local lbl = Instance.new("TextLabel")
        lbl.Size               = UDim2.new(1, -16, 0, 14)
        lbl.Position           = UDim2.new(0, 14, 0, 6)
        lbl.BackgroundTransparency = 1
        lbl.Font               = Enum.Font.GothamMedium
        lbl.TextSize           = 10
        lbl.TextColor3         = C.muted
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.Text               = string.upper(name)
        lbl.Parent             = holder

        local box = Instance.new("TextBox")
        box.Size               = UDim2.new(1, -28, 0, 20)
        box.Position           = UDim2.new(0, 14, 0, 24)
        box.BackgroundTransparency = 1
        box.Font               = Enum.Font.Gotham
        box.TextSize           = 13
        box.TextColor3         = C.text
        box.PlaceholderColor3  = C.muted
        box.PlaceholderText    = placeholder or ""
        box.Text               = ""
        box.TextXAlignment     = Enum.TextXAlignment.Left
        box.ClearTextOnFocus   = false
        box.Parent             = holder

        box.Focused:Connect(function()
            TweenService:Create(strk, T10, {Color = C.borderAcc, Thickness = 1.5}):Play()
            TweenService:Create(lbl, T10, {TextColor3 = C.accent}):Play()
        end)
        box.FocusLost:Connect(function()
            TweenService:Create(strk, T10, {Color = C.border, Thickness = 1}):Play()
            TweenService:Create(lbl, T10, {TextColor3 = C.muted}):Play()
            if callback then callback(box.Text) end
        end)
        return box
    end

    function tab:NameTitleRow(nameLabel, namePlaceholder, titles, defaultTitle, onNameChange, onTitleChange)
        local holder = Instance.new("Frame")
        holder.Size             = UDim2.new(1, 0, 0, 48)
        holder.BackgroundColor3 = C.panel
        holder.BorderSizePixel  = 0
        holder.Parent           = page
        corner(holder, 10)
        local strk = stroke(holder, C.border, 1)

        local lbl = Instance.new("TextLabel")
        lbl.Size               = UDim2.new(1, -16, 0, 14)
        lbl.Position           = UDim2.new(0, 14, 0, 6)
        lbl.BackgroundTransparency = 1
        lbl.Font               = Enum.Font.GothamMedium
        lbl.TextSize           = 10
        lbl.TextColor3         = C.muted
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.Text               = string.upper(nameLabel)
        lbl.Parent             = holder

        local TITLE_W = 108
        local box = Instance.new("TextBox")
        box.Size               = UDim2.new(1, -(TITLE_W + 40), 0, 20)
        box.Position           = UDim2.new(0, 14, 0, 24)
        box.BackgroundTransparency = 1
        box.Font               = Enum.Font.Gotham
        box.TextSize           = 13
        box.TextColor3         = C.text
        box.PlaceholderColor3  = C.muted
        box.PlaceholderText    = namePlaceholder or ""
        box.Text               = ""
        box.TextXAlignment     = Enum.TextXAlignment.Left
        box.ClearTextOnFocus   = false
        box.ZIndex             = 7
        box.Parent             = holder

        box.Focused:Connect(function()
            TweenService:Create(strk, T10, {Color = C.borderAcc, Thickness = 1.5}):Play()
            TweenService:Create(lbl, T10, {TextColor3 = C.accent}):Play()
        end)
        box.FocusLost:Connect(function()
            TweenService:Create(strk, T10, {Color = C.border, Thickness = 1}):Play()
            TweenService:Create(lbl, T10, {TextColor3 = C.muted}):Play()
            if onNameChange then onNameChange(box.Text) end
        end)

        titles = titles or {"Member", "Moderator", "Admin", "Owner"}
        local obj = {SelectedTitle = defaultTitle or titles[1]}

        local badge = Instance.new("TextButton")
        badge.Size             = UDim2.new(0, TITLE_W, 0, 26)
        badge.Position         = UDim2.new(1, -(TITLE_W + 12), 0.5, -13)
        badge.BackgroundColor3 = C.accentDark
        badge.Text             = ""
        badge.AutoButtonColor  = false
        badge.BorderSizePixel  = 0
        badge.ZIndex           = 7
        badge.Parent           = holder
        corner(badge, 7)
        local badgeStroke = stroke(badge, C.accentDim, 1)

        local badgeLbl = Instance.new("TextLabel")
        badgeLbl.Size               = UDim2.new(1, -22, 1, 0)
        badgeLbl.Position           = UDim2.new(0, 8, 0, 0)
        badgeLbl.BackgroundTransparency = 1
        badgeLbl.Font               = Enum.Font.GothamBold
        badgeLbl.TextSize           = 11
        badgeLbl.TextColor3         = C.accent
        badgeLbl.TextXAlignment     = Enum.TextXAlignment.Left
        badgeLbl.TextTruncate       = Enum.TextTruncate.AtEnd
        badgeLbl.Text               = obj.SelectedTitle
        badgeLbl.ZIndex             = 7
        badgeLbl.Parent             = badge

        local badgeArrow = Instance.new("TextLabel")
        badgeArrow.Size               = UDim2.new(0, 16, 1, 0)
        badgeArrow.Position           = UDim2.new(1, -18, 0, 0)
        badgeArrow.BackgroundTransparency = 1
        badgeArrow.Font               = Enum.Font.GothamBold
        badgeArrow.TextSize           = 10
        badgeArrow.TextColor3         = C.accent
        badgeArrow.Text               = "▾"
        badgeArrow.ZIndex             = 7
        badgeArrow.Parent             = badge

        badge.MouseEnter:Connect(function()
            TweenService:Create(badge, T10, {BackgroundColor3 = C.accentDim}):Play()
        end)
        badge.MouseLeave:Connect(function()
            TweenService:Create(badge, T10, {BackgroundColor3 = C.accentDark}):Play()
        end)

        local function openTitleList()
            closeCurrentPopup()
            badgeArrow.Text = "▴"
            local catcher = Instance.new("TextButton")
            catcher.Size               = UDim2.new(1, 0, 1, 0)
            catcher.BackgroundTransparency = 1
            catcher.Text               = ""
            catcher.AutoButtonColor    = false
            catcher.Active             = true
            catcher.ZIndex             = 8
            catcher.Parent             = screenGui

            local bPos  = badge.AbsolutePosition
            local bSize = badge.AbsoluteSize
            local ITEM_H = 28
            local LIST_H = #titles * (ITEM_H + 2) + 10
            local cam  = workspace.CurrentCamera
            local vpH  = cam and cam.ViewportSize.Y or 800
            local dropDown = (bPos.Y + bSize.Y + LIST_H + 6 <= vpH)
            local listY = dropDown and (bPos.Y + bSize.Y + 4) or (bPos.Y - LIST_H - 4)

            local list = Instance.new("Frame")
            list.Size             = UDim2.new(0, math.max(bSize.X, 120), 0, LIST_H)
            list.Position         = UDim2.new(0, bPos.X - math.max(0, math.max(bSize.X,120) - bSize.X), 0, listY)
            list.BackgroundColor3 = C.panel
            list.BorderSizePixel  = 0
            list.ZIndex           = 9
            list.Parent           = screenGui
            corner(list, 10)
            stroke(list, C.borderAcc, 1)

            local lL = Instance.new("UIListLayout")
            lL.Padding = UDim.new(0, 2)
            lL.Parent  = list
            pad(list, 4, 4, 4, 4)

            for _, t in ipairs(titles) do
                local item = Instance.new("TextButton")
                item.Size             = UDim2.new(1, 0, 0, ITEM_H)
                item.BackgroundColor3 = C.panelAlt
                item.Text             = ""
                item.AutoButtonColor  = false
                item.ZIndex           = 10
                item.Parent           = list
                corner(item, 6)

                local iLbl = Instance.new("TextLabel")
                iLbl.Size               = UDim2.new(1, -16, 1, 0)
                iLbl.Position           = UDim2.new(0, 8, 0, 0)
                iLbl.BackgroundTransparency = 1
                iLbl.Font               = Enum.Font.GothamMedium
                iLbl.TextSize           = 12
                iLbl.TextColor3         = (t == obj.SelectedTitle) and C.accent or C.text
                iLbl.TextXAlignment     = Enum.TextXAlignment.Left
                iLbl.Text               = t
                iLbl.ZIndex             = 10
                iLbl.Parent             = item

                item.MouseEnter:Connect(function()
                    TweenService:Create(item, T10, {BackgroundColor3 = C.panelHov}):Play()
                end)
                item.MouseLeave:Connect(function()
                    TweenService:Create(item, T10, {BackgroundColor3 = C.panelAlt}):Play()
                end)
                item.MouseButton1Click:Connect(function()
                    obj.SelectedTitle = t
                    badgeLbl.Text = t
                    closeCurrentPopup()
                    if onTitleChange then onTitleChange(t) end
                end)
            end
            catcher.MouseButton1Click:Connect(closeCurrentPopup)
            currentPopup = {catcher = catcher, popup = list, arrow = badgeArrow}
        end

        badge.MouseButton1Click:Connect(openTitleList)

        function obj:GetName() return box.Text end
        function obj:GetTitle() return obj.SelectedTitle end
        return obj
    end

    function tab:ChatInput(name, placeholder, onSend)
        local holder = Instance.new("Frame")
        holder.Size             = UDim2.new(1, 0, 0, 54)
        holder.BackgroundColor3 = C.panel
        holder.BorderSizePixel  = 0
        holder.Parent           = page
        corner(holder, 10)
        local strk = stroke(holder, C.border, 1)

        local lbl = Instance.new("TextLabel")
        lbl.Size               = UDim2.new(1, -16, 0, 14)
        lbl.Position           = UDim2.new(0, 14, 0, 5)
        lbl.BackgroundTransparency = 1
        lbl.Font               = Enum.Font.GothamMedium
        lbl.TextSize           = 10
        lbl.TextColor3         = C.muted
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.Text               = string.upper(name)
        lbl.Parent             = holder

        local box = Instance.new("TextBox")
        box.Size               = UDim2.new(1, -28, 0, 26)
        box.Position           = UDim2.new(0, 14, 0, 24)
        box.BackgroundColor3   = C.track
        box.BackgroundTransparency = 0.30
        box.Font               = Enum.Font.Gotham
        box.TextSize           = 13
        box.TextColor3         = C.text
        box.PlaceholderColor3  = C.muted
        box.PlaceholderText    = placeholder or "Type here, press Enter to send..."
        box.Text               = ""
        box.TextXAlignment     = Enum.TextXAlignment.Left
        box.ClearTextOnFocus   = false
        box.ReturnTextOnFocusLost = false
        box.ZIndex             = 7
        box.Active             = true
        box.Selectable         = true
        box.Parent             = holder
        corner(box, 6)

        box.Focused:Connect(function()
            TweenService:Create(strk, T10, {Color = C.borderAcc, Thickness = 1.5}):Play()
        end)
        box.FocusLost:Connect(function(enterPressed)
            TweenService:Create(strk, T10, {Color = C.border, Thickness = 1}):Play()
            if enterPressed and box.Text ~= "" then
                if onSend then onSend(box.Text) end
                box.Text = ""
            end
        end)
        return box
    end

    function tab:Dropdown(name, options, default, callback)
        local holder = Instance.new("Frame")
        holder.Size             = UDim2.new(1, 0, 0, 42)
        holder.BackgroundColor3 = C.panel
        holder.BorderSizePixel  = 0
        holder.Parent           = page
        corner(holder, 10)
        stroke(holder, C.border, 1)

        local lbl = Instance.new("TextLabel")
        lbl.Size               = UDim2.new(1, -38, 1, 0)
        lbl.Position           = UDim2.new(0, 14, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font               = Enum.Font.GothamMedium
        lbl.TextSize           = 13
        lbl.TextColor3         = C.text
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.Text               = name .. "  ·  " .. (default or options[1] or "")
        lbl.Parent             = holder

        local arrow = Instance.new("TextLabel")
        arrow.Size               = UDim2.new(0, 22, 1, 0)
        arrow.Position           = UDim2.new(1, -26, 0, 0)
        arrow.BackgroundTransparency = 1
        arrow.Font               = Enum.Font.GothamBold
        arrow.TextSize           = 12
        arrow.TextColor3         = C.muted
        arrow.Text               = "▾"
        arrow.Parent             = holder

        local obj = {Selected = default or options[1] or ""}

        local function openList()
            closeCurrentPopup()
            arrow.Text = "▴"
            TweenService:Create(arrow, T15, {Rotation = 180}):Play()
            local catcher = Instance.new("TextButton")
            catcher.Size               = UDim2.new(1, 0, 1, 0)
            catcher.BackgroundTransparency = 1
            catcher.Text               = ""
            catcher.AutoButtonColor    = false
            catcher.Active             = true
            catcher.ZIndex             = 8
            catcher.Parent             = screenGui

            local hPos  = holder.AbsolutePosition
            local hSize = holder.AbsoluteSize
            local ITEM_H = 30
            local LIST_H = #options * (ITEM_H + 2) + 10
            local cam  = workspace.CurrentCamera
            local vpH  = cam and cam.ViewportSize.Y or 800
            local dropDown = (hPos.Y + hSize.Y + LIST_H + 6 <= vpH)
            local listY = dropDown and (hPos.Y + hSize.Y + 4) or (hPos.Y - LIST_H - 4)

            local list = Instance.new("Frame")
            list.Size             = UDim2.new(0, hSize.X, 0, 0)
            list.Position         = UDim2.new(0, hPos.X, 0, dropDown and (hPos.Y + hSize.Y + 4) or (hPos.Y))
            list.BackgroundColor3 = C.panel
            list.BackgroundTransparency = 0.15
            list.BorderSizePixel  = 0
            list.ClipsDescendants = true
            list.ZIndex           = 9
            list.Parent           = screenGui
            corner(list, 10)
            stroke(list, C.borderAcc, 1)

            TweenService:Create(list, T15, {
                Size = UDim2.new(0, hSize.X, 0, LIST_H),
                Position = UDim2.new(0, hPos.X, 0, listY),
                BackgroundTransparency = 0,
            }):Play()

            local lL = Instance.new("UIListLayout")
            lL.Padding = UDim.new(0, 2)
            lL.Parent  = list
            pad(list, 4, 4, 4, 4)

            for _, opt in ipairs(options) do
                local item = Instance.new("TextButton")
                item.Size             = UDim2.new(1, 0, 0, ITEM_H)
                item.BackgroundColor3 = C.panelAlt
                item.Text             = ""
                item.AutoButtonColor  = false
                item.ZIndex           = 10
                item.Parent           = list
                corner(item, 7)

                local iLbl = Instance.new("TextLabel")
                iLbl.Size               = UDim2.new(1, -30, 1, 0)
                iLbl.Position           = UDim2.new(0, 10, 0, 0)
                iLbl.BackgroundTransparency = 1
                iLbl.Font               = Enum.Font.Gotham
                iLbl.TextSize           = 13
                iLbl.TextColor3         = (opt == obj.Selected) and C.accent or C.text
                iLbl.TextXAlignment     = Enum.TextXAlignment.Left
                iLbl.Text               = opt
                iLbl.ZIndex             = 10
                iLbl.Parent             = item

                if opt == obj.Selected then
                    local check = Instance.new("TextLabel")
                    check.Size               = UDim2.new(0, 18, 1, 0)
                    check.Position           = UDim2.new(1, -22, 0, 0)
                    check.BackgroundTransparency = 1
                    check.Font               = Enum.Font.GothamBold
                    check.TextSize           = 13
                    check.TextColor3         = C.accent
                    check.Text               = "✓"
                    check.ZIndex             = 10
                    check.Parent             = item
                end

                item.MouseEnter:Connect(function()
                    TweenService:Create(item, T10, {BackgroundColor3 = C.panelHov}):Play()
                end)
                item.MouseLeave:Connect(function()
                    TweenService:Create(item, T10, {BackgroundColor3 = C.panelAlt}):Play()
                end)
                item.MouseButton1Click:Connect(function()
                    obj.Selected = opt
                    lbl.Text = name .. "  ·  " .. opt
                    closeCurrentPopup()
                    if callback then callback(opt) end
                end)
            end
            catcher.MouseButton1Click:Connect(closeCurrentPopup)
            currentPopup = {catcher = catcher, popup = list, arrow = arrow}
        end

        holder.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                openList()
            end
        end)
        function obj:Get() return obj.Selected end
        return obj
    end

    function tab:ColorPicker(name, defaultColor, callback)
        local holder = Instance.new("Frame")
        holder.Size             = UDim2.new(1, 0, 0, 42)
        holder.BackgroundColor3 = C.panel
        holder.BorderSizePixel  = 0
        holder.Parent           = page
        corner(holder, 10)
        stroke(holder, C.border, 1)

        local lbl = Instance.new("TextLabel")
        lbl.Size               = UDim2.new(1, -78, 1, 0)
        lbl.Position           = UDim2.new(0, 14, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font               = Enum.Font.GothamMedium
        lbl.TextSize           = 13
        lbl.TextColor3         = C.text
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.Text               = name
        lbl.Parent             = holder

        local swatch = Instance.new("TextButton")
        swatch.Size             = UDim2.new(0, 58, 0, 30)
        swatch.Position         = UDim2.new(1, -66, 0.5, -15)
        swatch.BackgroundColor3 = defaultColor or C.white
        swatch.Text             = ""
        swatch.AutoButtonColor  = false
        swatch.BorderSizePixel  = 0
        swatch.Parent           = holder
        corner(swatch, 8)
        stroke(swatch, C.border, 1.5)

        swatch.MouseEnter:Connect(function()
            TweenService:Create(swatch, T10, {Size = UDim2.new(0, 62, 0, 32)}):Play()
        end)
        swatch.MouseLeave:Connect(function()
            TweenService:Create(swatch, T10, {Size = UDim2.new(0, 58, 0, 30)}):Play()
        end)

        local obj = {Color = defaultColor or C.white}

        local function openPicker()
            closeCurrentPopup()
            local r = math.floor(obj.Color.R * 255 + 0.5)
            local g = math.floor(obj.Color.G * 255 + 0.5)
            local b = math.floor(obj.Color.B * 255 + 0.5)

            local catcher = Instance.new("TextButton")
            catcher.Size               = UDim2.new(1, 0, 1, 0)
            catcher.BackgroundColor3   = C.black
            catcher.BackgroundTransparency = 1
            catcher.Text               = ""
            catcher.AutoButtonColor    = false
            catcher.ZIndex             = 8
            catcher.Parent             = screenGui
            TweenService:Create(catcher, T15, {BackgroundTransparency = 0.5}):Play()

            local sp  = swatch.AbsolutePosition
            local cam = workspace.CurrentCamera
            local vp  = cam and cam.ViewportSize or Vector2.new(1920, 1080)
            local px  = math.clamp(sp.X - 240, 10, vp.X - 310)
            local py  = math.clamp(sp.Y - 225, 10, vp.Y - 245)

            local panel = Instance.new("Frame")
            panel.Size             = UDim2.new(0, 302, 0, 0)
            panel.Position         = UDim2.new(0, px, 0, py + 12)
            panel.BackgroundColor3 = C.panel
            panel.BackgroundTransparency = 1
            panel.BorderSizePixel  = 0
            panel.ClipsDescendants = true
            panel.Active           = true
            panel.ZIndex           = 9
            panel.Parent           = screenGui
            corner(panel, 14)
            stroke(panel, C.borderAcc, 1.5)
            TweenService:Create(panel, T20, {
                Size = UDim2.new(0, 302, 0, 238),
                Position = UDim2.new(0, px, 0, py),
                BackgroundTransparency = 0,
            }):Play()

            local pTtl = Instance.new("TextLabel")
            pTtl.Size               = UDim2.new(1, -72, 0, 20)
            pTtl.Position           = UDim2.new(0, 14, 0, 12)
            pTtl.BackgroundTransparency = 1
            pTtl.Font               = Enum.Font.GothamBold
            pTtl.TextSize           = 13
            pTtl.TextColor3         = C.accent
            pTtl.TextXAlignment     = Enum.TextXAlignment.Left
            pTtl.Text               = name
            pTtl.ZIndex             = 9
            pTtl.Parent             = panel

            local preview = Instance.new("Frame")
            preview.Size             = UDim2.new(0, 48, 0, 48)
            preview.Position         = UDim2.new(1, -60, 0, 12)
            preview.BackgroundColor3 = obj.Color
            preview.BorderSizePixel  = 0
            preview.ZIndex           = 9
            preview.Parent           = panel
            corner(preview, 10)
            stroke(preview, C.border, 1.5)

            local hexLbl = Instance.new("TextLabel")
            hexLbl.Size               = UDim2.new(0, 120, 0, 20)
            hexLbl.Position           = UDim2.new(0, 14, 0, 150)
            hexLbl.BackgroundTransparency = 1
            hexLbl.Font               = Enum.Font.Code
            hexLbl.TextSize           = 12
            hexLbl.TextColor3         = C.muted
            hexLbl.TextXAlignment     = Enum.TextXAlignment.Left
            hexLbl.ZIndex             = 9
            hexLbl.Parent             = panel

            local function refreshHex()
                hexLbl.Text = string.format("#%02X%02X%02X", r, g, b)
            end
            local function updateColor()
                obj.Color = Color3.fromRGB(r, g, b)
                swatch.BackgroundColor3  = obj.Color
                preview.BackgroundColor3 = obj.Color
                refreshHex()
                if callback then callback(obj.Color) end
            end

            local function makeChannel(ch, yPos, getV, setV)
                local cl = Instance.new("TextLabel")
                cl.Size               = UDim2.new(0, 14, 0, 20)
                cl.Position           = UDim2.new(0, 14, 0, yPos)
                cl.BackgroundTransparency = 1
                cl.Font               = Enum.Font.GothamBold
                cl.TextSize           = 13
                cl.TextColor3         = C.text
                cl.Text               = ch
                cl.ZIndex             = 9
                cl.Parent             = panel

                local tr = Instance.new("TextButton")
                tr.Size             = UDim2.new(0, 200, 0, 14)
                tr.Position         = UDim2.new(0, 34, 0, yPos + 3)
                tr.BackgroundColor3 = C.track
                tr.Text             = ""
                tr.AutoButtonColor  = false
                tr.ZIndex           = 9
                tr.Parent           = panel
                corner(tr, UDim.new(1, 0))

                local fl = Instance.new("Frame")
                fl.Size             = UDim2.new(getV()/255, 0, 1, 0)
                fl.BackgroundColor3 = C.accent
                fl.BorderSizePixel  = 0
                fl.ZIndex           = 9
                fl.Parent           = tr
                corner(fl, UDim.new(1, 0))

                local kb = Instance.new("Frame")
                kb.Size             = UDim2.new(0, 18, 0, 18)
                kb.Position         = UDim2.new(getV()/255, -9, 0.5, -9)
                kb.BackgroundColor3 = C.white
                kb.BorderSizePixel  = 0
                kb.ZIndex           = 10
                kb.Parent           = tr
                corner(kb, UDim.new(1, 0))
                stroke(kb, C.accent, 1)

                local vl = Instance.new("TextLabel")
                vl.Size               = UDim2.new(0, 36, 0, 20)
                vl.Position           = UDim2.new(0, 242, 0, yPos)
                vl.BackgroundTransparency = 1
                vl.Font               = Enum.Font.Code
                vl.TextSize           = 12
                vl.TextColor3         = C.muted
                vl.TextXAlignment     = Enum.TextXAlignment.Right
                vl.Text               = tostring(getV())
                vl.ZIndex             = 9
                vl.Parent             = panel

                local dg = false
                local function sx(x)
                    local pct = math.clamp((x - tr.AbsolutePosition.X) / tr.AbsoluteSize.X, 0, 1)
                    local v   = math.floor(pct * 255 + 0.5)
                    setV(v)
                    fl.Size     = UDim2.new(pct, 0, 1, 0)
                    kb.Position = UDim2.new(pct, -9, 0.5, -9)
                    vl.Text     = tostring(v)
                    updateColor()
                end
                tr.MouseButton1Down:Connect(function()
                    dg = true
                    sx(UserInputService:GetMouseLocation().X)
                end)
                UserInputService.InputChanged:Connect(function(inp)
                    if dg and inp.UserInputType == Enum.UserInputType.MouseMovement then
                        sx(inp.Position.X)
                    end
                end)
                UserInputService.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then dg = false end
                end)
            end

            makeChannel("R", 54,  function() return r end, function(v) r = v end)
            makeChannel("G", 84,  function() return g end, function(v) g = v end)
            makeChannel("B", 114, function() return b end, function(v) b = v end)
            refreshHex()

            local doneBtn = Instance.new("TextButton")
            doneBtn.Size             = UDim2.new(0, 122, 0, 32)
            doneBtn.Position         = UDim2.new(1, -136, 0, 194)
            doneBtn.BackgroundColor3 = C.accent
            doneBtn.Text             = "Apply"
            doneBtn.Font             = Enum.Font.GothamBold
            doneBtn.TextSize         = 13
            doneBtn.TextColor3       = C.white
            doneBtn.BorderSizePixel  = 0
            doneBtn.AutoButtonColor  = false
            doneBtn.ZIndex           = 10
            doneBtn.Parent           = panel
            corner(doneBtn, 8)
            doneBtn.MouseEnter:Connect(function()
                TweenService:Create(doneBtn, T10, {BackgroundColor3 = C.accentHi}):Play()
            end)
            doneBtn.MouseLeave:Connect(function()
                TweenService:Create(doneBtn, T10, {BackgroundColor3 = C.accent}):Play()
            end)

            local closed = false
            local function closePicker()
                if closed then return end
                closed = true
                pcall(function() catcher:Destroy() end)
                pcall(function() panel:Destroy() end)
                currentPopup = nil
            end
            doneBtn.MouseButton1Click:Connect(closePicker)
            catcher.MouseButton1Click:Connect(closePicker)
            currentPopup = {catcher = catcher, popup = panel, arrow = nil}
        end

        swatch.MouseButton1Click:Connect(openPicker)
        function obj:Set(color)
            obj.Color               = color
            swatch.BackgroundColor3 = color
            if callback then callback(color) end
        end
        return obj
    end

    function tab:Paragraph(title, body)
        local holder = Instance.new("Frame")
        holder.Size             = UDim2.new(1, 0, 0, 0)
        holder.BackgroundColor3 = C.panelAlt
        holder.BorderSizePixel  = 0
        holder.AutomaticSize    = Enum.AutomaticSize.Y
        holder.Parent           = page
        corner(holder, 10)
        stroke(holder, C.border, 1)

        local ttl = Instance.new("TextLabel")
        ttl.Size               = UDim2.new(1, -20, 0, 16)
        ttl.Position           = UDim2.new(0, 10, 0, 8)
        ttl.BackgroundTransparency = 1
        ttl.Font               = Enum.Font.GothamBold
        ttl.TextSize           = 10
        ttl.TextColor3         = C.accent
        ttl.TextXAlignment     = Enum.TextXAlignment.Left
        ttl.Text               = string.upper(title or "")
        ttl.Parent             = holder

        local cnt = Instance.new("TextLabel")
        cnt.Size               = UDim2.new(1, -20, 0, 0)
        cnt.Position           = UDim2.new(0, 10, 0, 26)
        cnt.BackgroundTransparency = 1
        cnt.Font               = Enum.Font.Code
        cnt.TextSize           = 12
        cnt.TextColor3         = C.textDim
        cnt.TextXAlignment     = Enum.TextXAlignment.Left
        cnt.TextYAlignment     = Enum.TextYAlignment.Top
        cnt.TextWrapped        = true
        cnt.AutomaticSize      = Enum.AutomaticSize.Y
        cnt.Text               = body or ""
        cnt.Parent             = holder

        local obj = {}
        function obj:Set(cfg)
            if cfg.Title   then ttl.Text = string.upper(cfg.Title) end
            if cfg.Content then cnt.Text = cfg.Content end
        end
        return obj
    end

    function tab:StatRow(stats)
        local holder = Instance.new("Frame")
        holder.Size             = UDim2.new(1, 0, 0, 60)
        holder.BackgroundTransparency = 1
        holder.Parent           = page

        local lay = Instance.new("UIListLayout")
        lay.FillDirection = Enum.FillDirection.Horizontal
        lay.Padding        = UDim.new(0, 6)
        lay.Parent         = holder

        local cardW = (1 / #stats)
        for _, s in ipairs(stats) do
            local card = Instance.new("Frame")
            card.Size             = UDim2.new(cardW, -5, 1, 0)
            card.BackgroundColor3 = C.panel
            card.BorderSizePixel  = 0
            card.Parent           = holder
            corner(card, 10)
            stroke(card, C.border, 1)

            local valL = Instance.new("TextLabel")
            valL.Size               = UDim2.new(1, -12, 0, 24)
            valL.Position           = UDim2.new(0, 6, 0, 8)
            valL.BackgroundTransparency = 1
            valL.Font               = Enum.Font.GothamBlack
            valL.TextSize           = 18
            valL.TextColor3         = s.color or C.accent
            valL.TextXAlignment     = Enum.TextXAlignment.Left
            valL.Text               = tostring(s.value)
            valL.Parent             = card

            local capL = Instance.new("TextLabel")
            capL.Size               = UDim2.new(1, -12, 0, 14)
            capL.Position           = UDim2.new(0, 6, 0, 34)
            capL.BackgroundTransparency = 1
            capL.Font               = Enum.Font.GothamMedium
            capL.TextSize           = 10
            capL.TextColor3         = C.muted
            capL.TextXAlignment     = Enum.TextXAlignment.Left
            capL.Text               = string.upper(s.label or "")
            capL.Parent             = card
        end
        return holder
    end

    return tab
end

-- ============================================================
-- BUILD TABS (Overview removed, Quantum added)
-- ============================================================

-- FARM
local FarmTab = CreateTab("Farm", "💪")
FarmTab:Label("Mode & Speed")
FarmTab:Dropdown("Mode", {"Hybrid", "Legacy"}, "Hybrid", function(v)
    Config.FarmMode = v
    if Config.FarmEnabled then stopFarm() task.wait(0.1) startFarm() end
end)
FarmTab:Dropdown("Speed", {"Infinity", "1e9", "1e15"}, "Infinity", function(v)
    Config.TrainSpeedValue = v
end)
FarmTab:Slider("Workers", 1, 250, 25, "", function(v)
    Config.WorkerCount = v
    if Config.FarmEnabled and Config.FarmMode == "Hybrid" then
        killWorkers()
        local n = math.max(1, math.min(250, v * Config.FarmSpeedMul))
        if Config.TurboActive then n = math.min(250, n * 2) end
        hybridState.currentWorkers = n
        spawnWorkers(n)
    end
end)
FarmTab:Dropdown("Multiplier", {"0.5x", "1x", "2x"}, "1x", function(v)
    if v == "0.5x" then Config.FarmSpeedMul = 0.5
    elseif v == "2x" then Config.FarmSpeedMul = 2
    else Config.FarmSpeedMul = 1 end
end)
FarmTab:Divider("options")
FarmTab:Toggle("Anti-Detect", true, function(t) Config.AntiDetect = t end)
FarmTab:Toggle("MAX PERFORMANCE", false, function(t) Config.MaxPerformance = t end)
local farmToggle = FarmTab:Toggle("START FARM", false, function(t)
    Config.FarmEnabled = t
    if t then startFarm() else stopFarm() end
end)
FarmTab:Button("TURBO BOOST", function() setTurbo() end)
FarmTab:Divider("overnight")
FarmTab:Toggle("Overnight Mode", false, function(t)
    Config.OvernightEnabled = t
    if t then startOvernight() else stopOvernight() end
end)
FarmTab:Divider("live stats")
local statsP = FarmTab:Paragraph("Power Tracker", "Start farm to see live stats…")
task.spawn(function()
    while task.wait(1) do
        local power = powerTracker.tick()
        local gains = powerTracker.avgGainsPerSec()
        local trend = powerTracker.trend()
        local trendIcon = trend == "up" and "^" or (trend == "down" and "v" or "->")
        local sessionTime = powerTracker.sessionStart > 0 and math.floor(tick() - powerTracker.sessionStart) or 0
        local turbo = Config.TurboActive and "T " or ""
        local overnight = Config.OvernightEnabled and "O " or ""
        local emergency = hybridState.emergencyMode and "! " or ""
        local content = overnight .. turbo .. emergency .. "Power: " .. formatNumber(power) .. "  |  " .. trendIcon .. " Gains/s: " .. formatNumber(gains) .. "  |  Session: " .. sessionTime .. "s  |  Workers: " .. activeWorkers
        pcall(function()
            statsP:Set({Content = content})
        end)
    end
end)

-- MOVEMENT
local MoveTab = CreateTab("Move", "🏃")
MoveTab:Label("Walk & Jump")
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
MoveTab:Button("Reset to Default  (16 / 50)", function()
    Config.WalkSpeed = 16
    Config.JumpPower = 50
    Config.OverrideStats = false
    restoreMovement()
    notify("Movement", "Reset to 16/50", 3, "info")
end)
MoveTab:Divider("noclip")
MoveTab:Dropdown("Noclip Mode", {"V777", "Improved"}, "Improved", function(v)
    Config.NoclipMode = v
    if Config.NoclipEnabled then
        setNoclipMode(false)
        task.wait(0.05)
        setNoclipMode(true)
    end
end)
MoveTab:Toggle("Noclip", false, function(t) setNoclipMode(t) end)

-- IDENTITY
local IdTab = CreateTab("Identity", "🎭")
IdTab:Label("Chat Identity")
IdTab:Dropdown("Title", {"GLOBAL", "SERVER ANNOUNCEMENT", "👑Head Administrator👑", "👑Head Executive Lead Developer👑", "None"}, "None", function(v)
    Config.CustomTag = (v == "None" or v == "") and "" or v
end)
IdTab:Dropdown("Username", {"RezurXshin☑️", "Jandel", "Administrator", "None"}, "None", function(v)
    Config.UserName = (v == "None" or v == "") and "" or v
end)
IdTab:Input("Custom Title", "Enter title…", function(v) Config.CustomTag = v or "" end)
IdTab:Input("Custom Name", "Enter name…", function(v) Config.UserName = v or "" end)
IdTab:Divider("colors")
IdTab:ColorPicker("Tag Color", Config.TagColor, function(c) Config.TagColor = c end)
IdTab:ColorPicker("User Color", Config.UserColor, function(c) Config.UserColor = c end)
IdTab:ColorPicker("Message Color", Config.MessageColor, function(c) Config.MessageColor = c end)

-- CHAT
local ChatTab = CreateTab("Chat", "💬")
ChatTab:Label("Ghost Shout")
local chatBox = ChatTab:ChatInput("Message", "Type and press Enter…", function(msg)
    sendChatMessage(msg)
    notify("Message Sent", msg, 3, "info")
end)
ChatTab:Button("Send", function()
    if chatBox.Text ~= "" then
        sendChatMessage(chatBox.Text)
        notify("Shout Sent", chatBox.Text:sub(1, 40), 3, "success")
    end
end)
ChatTab:Button("Clear", function()
    chatBox.Text = ""
    notify("Chat", "Cleared", 2, "info")
end)

-- LAB
local LabTab = CreateTab("Lab", "🧪")
LabTab:Label("Experiments")
LabTab:Toggle("Anti-AFK", true, function(t) Config.AntiAfk = t end)
LabTab:Divider("esp")
local function toggleESP(t)
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
                            espCache[h] = {gui = bb, label = label, lastValue = power}
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
LabTab:Toggle("ESP", false, toggleESP)
LabTab:Button("Clear ESP", function()
    clearAllEspTags()
    notify("ESP", "All tags cleared", 3, "info")
end)

-- SYSTEM
local SysTab = CreateTab("System", "⚙")
SysTab:Label("Profile")
SysTab:Button("Save Profile", function()
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
        writefile("DOMINUS_Profile.json", json)
        notify("Saved", "Profile saved.", 3, "success")
    else
        notify("Error", "writefile not supported", 4, "error")
    end
end)
SysTab:Button("Load Profile", function()
    if not readfile then notify("Error", "readfile not supported", 4, "error") return end
    local ok, content = pcall(readfile, "DOMINUS_Profile.json")
    if not ok or not content then notify("Error", "No saved profile found", 3, "warning") return end
    local ok2, profile = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok2 or type(profile) ~= "table" then notify("Error", "Profile corrupted", 4, "error") return end
    Config.CustomTag = profile.CustomTag or ""
    Config.UserName = profile.UserName or ""
    if profile.TagColor then Config.TagColor = Color3.new(profile.TagColor[1], profile.TagColor[2], profile.TagColor[3]) end
    if profile.UserColor then Config.UserColor = Color3.new(profile.UserColor[1], profile.UserColor[2], profile.UserColor[3]) end
    if profile.MessageColor then Config.MessageColor = Color3.new(profile.MessageColor[1], profile.MessageColor[2], profile.MessageColor[3]) end
    Config.FarmMode = profile.FarmMode or "Hybrid"
    Config.FarmSpeedMul = profile.FarmSpeedMul or 1
    Config.WorkerCount = profile.WorkerCount or 15
    Config.MaxPerformance = profile.MaxPerformance or false
    Config.TrainSpeedValue = profile.TrainSpeedValue or "Infinity"
    Config.AntiDetect = profile.AntiDetect ~= nil and profile.AntiDetect or true
    Config.WalkSpeed = profile.WalkSpeed or 16
    Config.JumpPower = profile.JumpPower or 50
    Config.NoclipMode = profile.NoclipMode or "Improved"
    Config.AntiAfk = profile.AntiAfk ~= nil and profile.AntiAfk or true
    notify("Loaded", "Profile loaded.", 3, "info")
end)
SysTab:Divider("hotkeys")
SysTab:Keybind("Toggle UI",      "K")
SysTab:Keybind("Farm On/Off",    "Ctrl + F")
SysTab:Keybind("Noclip On/Off",  "Ctrl + N")
SysTab:Keybind("Turbo Boost",    "Ctrl + T")
SysTab:Divider("danger zone")
local destroyConfirmed = false
SysTab:Button("Destroy UI  (confirm first)", function()
    if destroyConfirmed then
        screenGui:Destroy()
    else
        destroyConfirmed = true
        notify("Confirm Destroy", "Click again within 3s to confirm.", 3, "warning")
        task.delay(3, function() destroyConfirmed = false end)
    end
end)

-- ABOUT
local AboutTab = CreateTab("About", "ℹ")
AboutTab:Divider("about")
AboutTab:Label("👑 RezurXLab DOMINUS")
AboutTab:Paragraph("About", "👑 DOMINUS UI v2.1\n🔥 Quantum Edition\n\nMade by RezurXshin\nCreator of RezurXLabs\n\n🛡️ All rights reserved to RezurXshin (Creator of RezurXLabs)\n\n⚙️ Engine: Hybrid Farm + math.huge\n👻 Noclip: V777 + Improved\n🌙 Overnight Mode\n🚀 Turbo Boost\n💾 Save/Load Profiles\n⌨️ Keyboard Shortcuts\n\nPress K to toggle UI")
AboutTab:Divider("credits")
AboutTab:Label("👑 Credits")
AboutTab:Paragraph("Credits", "👑 Creator: RezurXshin\n🏢 Studio: RezurXLabs\n📦 UI: DOMINUS Custom v2.1\n⚡ Engine: Hybrid Apex V2\n\n🛡️ All rights reserved.\n© 2026 RezurXshin. Do not redistribute without permission.")
AboutTab:Divider("shortcuts")
AboutTab:Keybind("Toggle UI",      "K")
AboutTab:Keybind("Farm On/Off",    "Ctrl + F")
AboutTab:Keybind("Noclip On/Off",  "Ctrl + N")
AboutTab:Keybind("Turbo Boost",    "Ctrl + T")

-- NEW TAB: QUANTUM (was Dark Experiments)
local QuantumTab = CreateTab("Quantum", "⚡")
QuantumTab:Label("⚡ Quantum Controls")
QuantumTab:Toggle("PVP Off", false, function(t) Config.PvpOff = t end)
QuantumTab:Toggle("Noclip", false, function(t) setNoclipMode(t) end)
QuantumTab:Toggle("Anti-Slow", false, function(t) Config.AntiSlow = t end)
QuantumTab:Divider("")
QuantumTab:Paragraph("Info", "⚡ Quantum toggles are live.\n• PVP Off – disables PVP interactions\n• Noclip – walk through objects\n• Anti-Slow – prevents slow debuffs (placeholder)")

-- ============================================================
-- KEYBOARD SHORTCUTS (engine)
-- ============================================================
UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    local k = inp.KeyCode
    if k == Enum.KeyCode.K then
        screenGui.Enabled = not screenGui.Enabled
    elseif k == Enum.KeyCode.F and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        Config.FarmEnabled = not Config.FarmEnabled
        if Config.FarmEnabled then startFarm() else stopFarm() end
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
-- ENTRANCE ANIMATION
-- ============================================================
frame.Visible = true  -- [FIX] make visible before animation
frame.Size  = UDim2.new(0, WIN_W * 0.9, 0, WIN_H * 0.9)
frame.Position = UDim2.new(0.5, -(WIN_W*0.9)/2, 0.4, -(WIN_H*0.9)/2)
shadow.Visible = true
shadow.BackgroundTransparency = 1
frame.BackgroundTransparency = 0

for _, d in ipairs(frame:GetDescendants()) do
    if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
        d.TextTransparency = 1
    end
end

TweenService:Create(frame, T35, {
    Size = UDim2.new(0, WIN_W, 0, WIN_H),
    Position = UDim2.new(0.5, -WIN_W/2, 0.4, -WIN_H/2),
}):Play()
TweenService:Create(shadow, T35, {BackgroundTransparency = 0.52}):Play()
task.delay(0.15, function()
    for _, d in ipairs(frame:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            TweenService:Create(d, T20, {TextTransparency = 0}):Play()
        end
    end
end)
introBlock:Destroy()

-- ============================================================
-- BOOT NOTIFICATION
-- ============================================================
task.delay(0.5, function()
    notify("👑 DOMINUS QUANTUM", "🔥 Quantum Edition loaded. Press K to toggle. Made by RezurXshin", 7, "success")
end)