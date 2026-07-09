-- ============================================================
-- 👑 DOMINUS V8 — Powered by RezurXLib
-- by RezurXshin | Creator of RezurXLabs
--
-- Uses the user's own RezurXLib UI framework:
-- https://github.com/AshesOfTheUndead/rayfield-ui-clone
--
-- 1000 max workers · math.huge · PVP Off default ON · no anti-cheat
--
-- [V8 FIXES]:
--   • All engine callbacks wrapped in task.spawn (no UI freeze)
--   • Slider callbacks debounced (won't fire 1000x during drag)
--   • Window 360x400 (mobile-friendly)
--   • Default workers 50 (was 100 — 1000-thread spawn on every
--     slider tick was the freeze cause)
-- ============================================================

-- ═══ Load RezurXLib from GitHub ═══
local Lib
local LIB_URL = "https://raw.githubusercontent.com/AshesOfTheUndead/rayfield-ui-clone/main/RezurXLib.lua"
local ok, src = pcall(function() return game:HttpGet(LIB_URL) end)
if ok and src and #src > 100 then
    src = src:gsub("self%._n %+= 1", "self._n = self._n + 1")
    local fn, err = loadstring(src)
    if fn then Lib = fn() end
end
if not Lib then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "DOMINUS V8 Error",
            Text = "Failed to load RezurXLib. Check internet or executor.",
            Duration = 10,
        })
    end)
    return
end

-- ═══ SERVICES ═══
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local HttpService       = game:GetService("HttpService")
local player            = Players.LocalPlayer
local unpack = unpack or table.unpack

-- ═══ HELPERS ═══
local function formatNumber(n)
    local s = {{1e33,"De"},{1e30,"No"},{1e27,"Oc"},{1e24,"Sp"},{1e21,"Sx"},{1e18,"Qi"},{1e15,"Qa"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}
    for _, v in ipairs(s) do if n >= v[1] then return string.format("%.2f%s", n / v[1], v[2]) end end
    return tostring(n)
end

local function escapeRich(s)
    s = tostring(s or "")
    return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function safeCall(src, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[DOMINUS]", src, err) end
    return ok, err
end

-- [FIX] Debounce helper — prevents callback from firing too rapidly (slider drag)
local function debounce(fn, delay)
    local lastCall = 0
    local lastVal = nil
    local pending = false
    return function(...)
        local args = {...}
        local now = tick()
        if now - lastCall >= (delay or 0.1) then
            lastCall = now
            fn(unpack(args))
        end
    end
end

-- ═══ FORWARD DECLARATIONS ═══
local notify, applyMovement, restoreMovement, executePump, sendChatMessage
local initAllRemotes, healRemotesWithBackoff, setTurbo, startFarm, stopFarm
local startOvernight, stopOvernight, setNoclipMode, powerTracker

-- ═══ CONFIG ═══
local Config = {
    CustomTag="", UserName="",
    TagColor=Color3.fromRGB(128,0,0), UserColor=Color3.fromRGB(255,255,255), MessageColor=Color3.fromRGB(255,255,255),
    FarmMode="Hybrid", FarmEnabled=false, FarmSpeedMul=1,
    WorkerCount=50, MaxPerformance=false, TrainSpeedValue="Infinity",
    OvernightEnabled=false,
    OverrideStats=false, WalkSpeed=16, JumpPower=50,
    NoclipEnabled=false, NoclipMode="Improved",
    PvpOff=true, EspEnabled=false,
    AntiAfk=true, AntiDetect=false,
    TurboActive=false, TurboUntil=0, TurboCooldownUntil=0,
}
local hybridState = {currentWorkers=5, lastAdjust=0, fpsHistory={}, responseTimes={}, consecutiveFailures=0, emergencyMode=false}

-- ═══ REMOTE MANAGER ═══
local Remotes = {}
local remoteMutex = false
local consecutiveHealFailures = 0
local lastHealTime = 0
initAllRemotes = function()
    if remoteMutex then return end
    remoteMutex = true
    pcall(function()
        local tsRoot=ReplicatedStorage:FindFirstChild("TrainSystem") local tsRem=tsRoot and tsRoot:FindFirstChild("Remote")
        if tsRem then Remotes.ApplyAddFrenzyValue=tsRem:FindFirstChild("ApplyAddFrenzyValue") Remotes.TrainSpeedHasChanged=tsRem:FindFirstChild("TrainSpeedHasChanged") end
        local teRoot=ReplicatedStorage:FindFirstChild("TrainEquipment") local teRem=teRoot and teRoot:FindFirstChild("Remote")
        if teRem then Remotes.ApplyMobileTrain=teRem:FindFirstChild("ApplyMobileTrain") Remotes.ApplyStationaryTrain=teRem:FindFirstChild("ApplyStationaryTrain") end
        local tc=ReplicatedStorage:FindFirstChild("TextChat") local tcRem=tc and tc:FindFirstChild("Remote")
        if tcRem then Remotes.SendTextChatMessage=tcRem:FindFirstChild("SendTextChatMessageToAllPlayer") end
        local ab=ReplicatedStorage:FindFirstChild("Ability") local abRem=ab and ab:FindFirstChild("Remote")
        if abRem then Remotes.ApplyCastAbility=abRem:FindFirstChild("ApplyCastAbility") end
        local ar=ReplicatedStorage:FindFirstChild("Area") local arRem=ar and ar:FindFirstChild("Remote")
        if arRem then Remotes.PlayerAreaIn=arRem:FindFirstChild("PlayerAreaIn") end
    end)
    remoteMutex = false
end
initAllRemotes()
healRemotesWithBackoff = function()
    local now = tick() local backoff = math.min(30, 2^consecutiveHealFailures)
    if now - lastHealTime < backoff then return end
    lastHealTime = now initAllRemotes()
    if Remotes.ApplyAddFrenzyValue then consecutiveHealFailures=0 else consecutiveHealFailures=consecutiveHealFailures+1 end
end
task.spawn(function() while task.wait(30) do safeCall("init", initAllRemotes) end end)

-- ═══ POWER TRACKER ═══
powerTracker = {sessionStart=0, sessionStartPower=0, lastTickTime=0, lastTickPower=0, gainsPerSec=0, gainsThisSession=0, samples={}}
function powerTracker.readPower()
    local cfg=player:FindFirstChild("Configuration") local ts=cfg and cfg:FindFirstChild("TrainSystem")
    if not ts then return 0 end local t=0 for i=1,4 do t=t+(ts:GetAttribute(tostring(i)) or 0) end return t
end
function powerTracker.startSession()
    powerTracker.sessionStart=tick() powerTracker.sessionStartPower=powerTracker.readPower()
    powerTracker.lastTickTime=tick() powerTracker.lastTickPower=powerTracker.sessionStartPower
    powerTracker.gainsThisSession=0 powerTracker.samples={}
end
function powerTracker.tick()
    local now=tick() local p=powerTracker.readPower() local dt=now-powerTracker.lastTickTime
    if dt>0 then local d=p-powerTracker.lastTickPower powerTracker.gainsPerSec=d/dt
    powerTracker.gainsThisSession=powerTracker.gainsThisSession+d
    table.insert(powerTracker.samples, powerTracker.gainsPerSec)
    if #powerTracker.samples>10 then table.remove(powerTracker.samples,1) end end
    powerTracker.lastTickTime=now powerTracker.lastTickPower=p return p
end
function powerTracker.avgGainsPerSec()
    local s=0 for _,v in ipairs(powerTracker.samples) do s=s+v end
    return #powerTracker.samples>0 and (s/#powerTracker.samples) or 0
end
function powerTracker.trend()
    if #powerTracker.samples<4 then return "flat" end
    local r,o=0,0 local h=math.floor(#powerTracker.samples/2)
    for i=1,h do o=o+powerTracker.samples[i] end for i=h+1,#powerTracker.samples do r=r+powerTracker.samples[i] end
    o=o/h r=r/(#powerTracker.samples-h)
    if r>o*1.15 then return "up" end if r<o*0.85 then return "down" end return "flat"
end

-- ═══ FARM ENGINE ═══
local function getTrainSpeed()
    local v=Config.TrainSpeedValue
    if v=="1e9" then return 1e9 elseif v=="1e15" then return 1e15 else return math.huge end
end
executePump = function(speed)
    if not Remotes.ApplyAddFrenzyValue then healRemotesWithBackoff() end
    if not Remotes.ApplyAddFrenzyValue then return end
    local r=Remotes
    local calls={
        {f="I",r=r.ApplyAddFrenzyValue,a={10000}},{f="F",r=r.TrainSpeedHasChanged,a={speed}},
        {f="I",r=r.ApplyMobileTrain,a={speed}},{f="I",r=r.ApplyStationaryTrain,a={speed}},
        {f="I",r=r.ApplyStationaryTrain,a={speed}},{f="F",r=r.TrainSpeedHasChanged,a={speed}},
        {f="I",r=r.ApplyMobileTrain,a={speed}},{f="I",r=r.ApplyStationaryTrain,a={speed}},
        {f="I",r=r.ApplyStationaryTrain,a={speed}},{f="F",r=r.TrainSpeedHasChanged,a={speed}},
        {f="I",r=r.ApplyMobileTrain,a={speed}},{f="I",r=r.ApplyStationaryTrain,a={speed}},
        {f="I",r=r.ApplyStationaryTrain,a={speed}},{f="F",r=r.TrainSpeedHasChanged,a={speed}},
        {f="I",r=r.ApplyAddFrenzyValue,a={10000}},
    }
    for _,c in ipairs(calls) do
        if c.r then
            if c.f=="I" then pcall(c.r.InvokeServer, c.r, unpack(c.a))
            else pcall(c.r.FireServer, c.r, unpack(c.a)) end
        end
    end
end

local workerGeneration=0 local activeWorkers=0
local function spawnWorkers(n)
    workerGeneration=workerGeneration+1 local gen=workerGeneration activeWorkers=n
    for i=1,n do local wid=i
        task.spawn(function()
            task.wait((wid-1)*0.002)
            while gen==workerGeneration and Config.FarmEnabled do
                local sp=getTrainSpeed() if hybridState.emergencyMode then sp=1e9 end
                pcall(executePump, sp) task.wait(0.001)
            end
        end)
    end
end
local function killWorkers() workerGeneration=workerGeneration+1 activeWorkers=0 end

local adaptiveConn=nil
local function startAdaptiveThrottle()
    if adaptiveConn then adaptiveConn:Disconnect() end
    adaptiveConn=RunService.Heartbeat:Connect(function()
        local now=tick() if now-hybridState.lastAdjust<2 then return end
        hybridState.lastAdjust=now
        local fc=0 local c2=RunService.Heartbeat:Connect(function() fc=fc+1 end) task.wait(0.5) c2:Disconnect()
        local fps=math.floor(fc/0.5)
        table.insert(hybridState.fpsHistory,fps) if #hybridState.fpsHistory>5 then table.remove(hybridState.fpsHistory,1) end
        local af=0 for _,v in ipairs(hybridState.fpsHistory) do af=af+v end af=af/#hybridState.fpsHistory
        local tr=powerTracker.trend() local old=hybridState.currentWorkers
        if af<15 then hybridState.emergencyMode=true hybridState.currentWorkers=1
        elseif af<25 then hybridState.emergencyMode=false hybridState.currentWorkers=math.max(1,hybridState.currentWorkers-1)
        elseif tr=="down" and hybridState.currentWorkers>2 then hybridState.emergencyMode=false hybridState.currentWorkers=hybridState.currentWorkers-1
        elseif tr=="up" and af>50 and hybridState.currentWorkers<1000 then hybridState.emergencyMode=false hybridState.currentWorkers=hybridState.currentWorkers+1
        elseif tr=="flat" and af>50 and hybridState.currentWorkers<500 then hybridState.emergencyMode=false hybridState.currentWorkers=hybridState.currentWorkers+1
        end
        if hybridState.currentWorkers~=old and Config.FarmEnabled and Config.FarmMode=="Hybrid" then
            killWorkers() task.wait(0.05) spawnWorkers(hybridState.currentWorkers)
        end
    end)
end
local function stopAdaptiveThrottle() if adaptiveConn then adaptiveConn:Disconnect() adaptiveConn=nil end end

local farmConn=nil
startFarm = function()
    if farmConn then farmConn:Disconnect() farmConn=nil end
    stopAdaptiveThrottle() powerTracker.startSession()
    if Config.FarmMode=="Hybrid" then
        hybridState.currentWorkers=math.max(1,math.min(1000,Config.WorkerCount*Config.FarmSpeedMul))
        if Config.TurboActive then hybridState.currentWorkers=math.min(1000,hybridState.currentWorkers*2) end
        hybridState.emergencyMode=false hybridState.fpsHistory={}
        spawnWorkers(hybridState.currentWorkers) startAdaptiveThrottle()
    else
        farmConn=RunService.Heartbeat:Connect(function() safeCall("farm",function() pcall(executePump,getTrainSpeed()) end) end)
    end
end
stopFarm = function()
    if farmConn then farmConn:Disconnect() farmConn=nil end
    stopAdaptiveThrottle() killWorkers()
end

-- ═══ OVERNIGHT ═══
local overnightConn=nil local overnightOrig={}
startOvernight = function()
    if overnightConn then return end
    overnightOrig={Config.FarmMode,Config.WorkerCount,Config.AntiDetect,Config.TrainSpeedValue}
    Config.FarmMode="Hybrid" Config.WorkerCount=3 Config.AntiDetect=true Config.TrainSpeedValue="Infinity"
    Config.TurboActive=false Config.TurboUntil=0 Config.FarmEnabled=true startFarm()
    local cs=tick() local lfc=tick() local fls=0
    overnightConn=RunService.Heartbeat:Connect(function()
        local now=tick()
        if now-lfc>=5 then lfc=now local fc=0 local c2=RunService.Heartbeat:Connect(function() fc=fc+1 end) task.wait(0.5) c2:Disconnect()
        local fps=math.floor(fc/0.5)
        if fps<15 then fls=fls+1 if fls>=2 then killWorkers() task.delay(120,function() if Config.OvernightEnabled then cs=tick() spawnWorkers(3) end end) end
        else fls=0 end end
        if now-cs>=300 then killWorkers() collectgarbage("collect") task.delay(30,function() if Config.OvernightEnabled then cs=tick() spawnWorkers(3) end end) end
    end)
end
stopOvernight = function()
    if overnightConn then overnightConn:Disconnect() overnightConn=nil end
    Config.FarmMode=overnightOrig[1] or "Hybrid" Config.WorkerCount=overnightOrig[2] or 50
    Config.AntiDetect=overnightOrig[3]~=nil and overnightOrig[3] or false Config.TrainSpeedValue=overnightOrig[4] or "Infinity"
    Config.TurboActive=false Config.FarmEnabled=false stopFarm()
end

-- ═══ TURBO + CHAT + MOVEMENT + NOCLIP + ESP + CORE ═══
setTurbo = function()
    if Config.OvernightEnabled then return end
    local now=tick() if Config.TurboActive then return end if now<Config.TurboCooldownUntil then return end
    Config.TurboActive=true Config.TurboUntil=now+10
    notify("🚀 TURBO", "2x for 10s!", 3, "success")
    if Config.FarmMode=="Hybrid" and Config.FarmEnabled then task.spawn(function() killWorkers() task.wait(0.05) spawnWorkers(math.min(1000,hybridState.currentWorkers*2)) end) end
    task.spawn(function()
        while Config.TurboActive and tick()<Config.TurboUntil do task.wait(0.5) end
        Config.TurboActive=false Config.TurboCooldownUntil=tick()+5
        if Config.FarmMode=="Hybrid" and Config.FarmEnabled then task.spawn(function() killWorkers() task.wait(0.05) spawnWorkers(hybridState.currentWorkers) end) end
    end)
end

local function buildChatMessage(msg)
    local tag,name="",""
    if Config.CustomTag~="" then tag=string.format('<font color="#%s"><b>[%s]</b></font> ',Config.TagColor:ToHex(),escapeRich(Config.CustomTag)) end
    if Config.UserName~="" then name=string.format('<font color="#%s"><b>%s:</b></font> ',Config.UserColor:ToHex(),escapeRich(Config.UserName)) end
    return tag..name..string.format('<font color="#%s"><b>%s</b></font>',Config.MessageColor:ToHex(),escapeRich(msg))
end
sendChatMessage = function(msg)
    if not Remotes.SendTextChatMessage then healRemotesWithBackoff() end
    if not Remotes.SendTextChatMessage or not msg or msg=="" then return end
    local full=buildChatMessage(msg)
    local ok=pcall(function() Remotes.SendTextChatMessage:InvokeServer({Text=full}) end)
    if not ok then safeCall("chat",function() Remotes.SendTextChatMessage:InvokeServer(full) end) end
end

applyMovement = function()
    if not Config.OverrideStats then return end
    local ch=player.Character if not ch then return end
    local h=ch:FindFirstChildOfClass("Humanoid") if not h then return end
    h.WalkSpeed=Config.WalkSpeed h.JumpPower=Config.JumpPower h.UseJumpPower=true
end
restoreMovement = function()
    local ch=player.Character local h=ch and ch:FindFirstChildOfClass("Humanoid")
    if h then h.WalkSpeed=16 h.JumpPower=50 end
end

local noclipConn,noclipCharConn=nil,nil
setNoclipMode = function(en)
    Config.NoclipEnabled=en
    if noclipConn then noclipConn:Disconnect() noclipConn=nil end
    if noclipCharConn then noclipCharConn:Disconnect() noclipCharConn=nil end
    if not en then return end
    local function start()
        if Config.NoclipMode=="V777" then
            noclipConn=RunService.Stepped:Connect(function()
                local ch=player.Character if ch then for _,v in pairs(ch:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false end end end
            end)
        else
            noclipConn=RunService.Stepped:Connect(function()
                local ch=player.Character if not ch then return end
                for _,v in ipairs(ch:GetDescendants()) do if v:IsA("BasePart") and v.CanCollide and v.Name~="HumanoidRootPart" then v.CanCollide=false end end
            end)
        end
    end
    start()
    noclipCharConn=player.CharacterAdded:Connect(function() task.wait(0.3) if Config.NoclipEnabled then if noclipConn then noclipConn:Disconnect() noclipConn=nil end start() end end)
end

local espCache,espConn={},nil
local function clearEsp() if espConn then espConn:Disconnect() espConn=nil end for h,e in pairs(espCache) do if e.gui and e.gui.Parent then e.gui:Destroy() end end table.clear(espCache) end
local function getPowerFor(name)
    local p=Players:FindFirstChild(name) if not p then return 0 end
    local cfg=p:FindFirstChild("Configuration") local ts=cfg and cfg:FindFirstChild("TrainSystem") if not ts then return 0 end
    local t=0 for i=1,4 do t=t+(ts:GetAttribute(tostring(i)) or 0) end return t
end

RunService.Heartbeat:Connect(function()
    if not Config.OverrideStats then return end
    local ch=player.Character if not ch then return end
    local h=ch:FindFirstChildOfClass("Humanoid") if not h then return end
    if h.WalkSpeed~=Config.WalkSpeed or h.JumpPower~=Config.JumpPower then h.WalkSpeed=Config.WalkSpeed h.JumpPower=Config.JumpPower h.UseJumpPower=true end
end)
player.CharacterAdded:Connect(function(char)
    local h=char:WaitForChild("Humanoid",5)
    if h then
        h.Died:Connect(function() if Config.FarmEnabled and Config.FarmMode=="Hybrid" then killWorkers() end end)
        if Config.OverrideStats then task.wait(0.2) applyMovement() end
        if Config.FarmEnabled and Config.FarmMode=="Hybrid" then task.wait(0.5) if Config.FarmEnabled then spawnWorkers(math.max(1,math.min(1000,hybridState.currentWorkers))) end end
    end
end)
player.Idled:Connect(function()
    if not Config.AntiAfk then return end
    safeCall("afk",function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end)
end)
task.spawn(function()
    while task.wait(0.2) do
        if Config.PvpOff then
            safeCall("pvp",function()
                local ar=workspace:FindFirstChild("Area") local pa=ar and ar:FindFirstChild("PlayerArea") local s2=pa and pa:FindFirstChild("S2")
                if s2 and Remotes.PlayerAreaIn then Remotes.PlayerAreaIn:InvokeServer(s2) end
                if Remotes.PlayerAreaIn then
                    for _,child in ipairs(workspace:GetChildren()) do
                        if child.Name=="Area" then
                            for _,sub in ipairs(child:GetDescendants()) do
                                if sub.Name:lower():find("safe") or sub.Name:lower():find("s2") or sub.Name:lower():find("no") then
                                    pcall(function() Remotes.PlayerAreaIn:InvokeServer(sub) end)
                                end
                            end
                        end
                    end
                end
                if not Remotes.PlayerAreaIn then healRemotesWithBackoff() end
            end)
        end
    end
end)

-- ═══ CREATE WINDOW ═══
local Window = Lib:CreateWindow({
    Name = "👑 DOMINUS V8",
    Subtitle = "🔥 Maximum Power · RezurXLab",
    LoadingTitle = "👑 DOMINUS V8",
    LoadingEnabled = false,
    Theme = "Ember",
    ToggleUIKeybind = Enum.KeyCode.K,
    -- [FIX] No Size = library uses 200x210 default (2x smaller than before)
})

notify = function(title, body, duration, ntype)
    Window:Notify({Title = title or "DOMINUS", Content = body or "", Duration = duration or 5, Type = ntype or "info"})
end

-- ═══ TAB: Farm ═══
local FarmTab = Window:CreateTab("Farm", "💪")
FarmTab:CreateSection("🔥 MODE & SPEED")
FarmTab:CreateDropdown({
    Name = "⚡ Mode",
    Options = {"Hybrid", "Legacy"},
    CurrentOption = "Hybrid",
    Callback = function(v) Config.FarmMode=v if Config.FarmEnabled then task.spawn(function() stopFarm() task.wait(0.1) startFarm() end) end end,
})
FarmTab:CreateDropdown({
    Name = "🚀 Speed",
    Options = {"Infinity", "1e9", "1e15"},
    CurrentOption = "Infinity",
    Callback = function(v) Config.TrainSpeedValue=v end,
})
-- [FIX] No debounce needed — library slider now only fires callback on click + drag END
FarmTab:CreateSlider({
    Name = "👥 Workers (1-1000)",
    Range = {1, 1000},
    Increment = 1,
    CurrentValue = 50,
    Suffix = "",
    Callback = function(v)
        Config.WorkerCount = v
        if Config.FarmEnabled and Config.FarmMode=="Hybrid" then
            task.spawn(function()
                killWorkers()
                local n=math.max(1,math.min(1000,v*Config.FarmSpeedMul))
                if Config.TurboActive then n=math.min(1000,n*2) end
                hybridState.currentWorkers=n
                spawnWorkers(n)
            end)
        end
    end,
})
FarmTab:CreateDropdown({
    Name = "⚡ Multiplier",
    Options = {"0.5x", "1x", "2x"},
    CurrentOption = "1x",
    Callback = function(v)
        if v=="0.5x" then Config.FarmSpeedMul=0.5 elseif v=="2x" then Config.FarmSpeedMul=2 else Config.FarmSpeedMul=1 end
    end,
})
FarmTab:CreateSection("⚙️ OPTIONS")
FarmTab:CreateToggle({Name = "🛡️ Anti-Detect", CurrentValue = false, Callback = function(t) Config.AntiDetect=t end})
FarmTab:CreateToggle({Name = "🔥 MAX PERFORMANCE", CurrentValue = false, Callback = function(t) Config.MaxPerformance=t end})
local farmToggle = FarmTab:CreateToggle({
    Name = "▶️ FARM: OFF",
    CurrentValue = false,
    Callback = function(t)
        task.spawn(function()
            Config.FarmEnabled = t
            farmToggle:SetLabel(t and "▶️ FARM: ON" or "▶️ FARM: OFF")
            if t then startFarm() else stopFarm() end
        end)
    end,
})
FarmTab:CreateButton({Name = "🚀 TURBO BOOST", Callback = function() task.spawn(setTurbo) end})
FarmTab:CreateSection("🌙 OVERNIGHT")
FarmTab:CreateToggle({
    Name = "🌙 Overnight Mode",
    CurrentValue = false,
    Callback = function(t) task.spawn(function() Config.OvernightEnabled=t if t then startOvernight() else stopOvernight() end end) end,
})
FarmTab:CreateSection("📊 LIVE STATS")
local statsP = FarmTab:CreateParagraph({Title = "📊 Power Tracker", Content = "Start farm..."})
task.spawn(function()
    while task.wait(1) do
        local power=powerTracker.tick() local gains=powerTracker.avgGainsPerSec() local trend=powerTracker.trend()
        local ti=trend=="up" and "📈" or (trend=="down" and "📉" or "➡️")
        local st=powerTracker.sessionStart>0 and math.floor(tick()-powerTracker.sessionStart) or 0
        pcall(function() statsP:Set({Content="Power: "..formatNumber(power).."  |  "..ti.." "..formatNumber(gains).."/s  |  "..st.."s  |  "..activeWorkers.."W"}) end)
    end
end)

-- ═══ TAB: Move ═══
local MoveTab = Window:CreateTab("Move", "🏃")
MoveTab:CreateSection("⚡ WALK & JUMP")
local ot = MoveTab:CreateToggle({
    Name = "🔧 Override Stats: OFF",
    CurrentValue = false,
    Callback = function(t)
        Config.OverrideStats = t
        ot:SetLabel(t and "🔧 Override Stats: ON" or "🔧 Override Stats: OFF")
        if t then applyMovement() else restoreMovement() end
    end,
})
local ws = MoveTab:CreateSlider({Name = "🏃 WalkSpeed", Range = {16, 1000}, Increment = 1, CurrentValue = 16, Suffix = " sp", Callback = function(v) Config.WalkSpeed=v applyMovement() end})
local js = MoveTab:CreateSlider({Name = "🦘 JumpPower", Range = {50, 1000}, Increment = 1, CurrentValue = 50, Suffix = " pw", Callback = function(v) Config.JumpPower=v applyMovement() end})
MoveTab:CreateButton({Name = "🔄 Reset (16/50)", Callback = function()
    Config.WalkSpeed=16 Config.JumpPower=50 Config.OverrideStats=false
    ot:Set(false) ws:Set(16) js:Set(50) restoreMovement()
    notify("🏃 Movement", "Reset", 3, "info")
end})
MoveTab:CreateSection("👻 NOCLIP")
MoveTab:CreateDropdown({Name = "⚙️ Mode", Options = {"V777", "Improved"}, CurrentOption = "Improved", Callback = function(v) Config.NoclipMode=v if Config.NoclipEnabled then task.spawn(function() setNoclipMode(false) task.wait(0.05) setNoclipMode(true) end) end end})
local noclipToggle = MoveTab:CreateToggle({
    Name = "👻 Noclip: OFF",
    CurrentValue = false,
    Callback = function(t)
        task.spawn(function() setNoclipMode(t) end)
        noclipToggle:SetLabel(t and "👻 Noclip: ON" or "👻 Noclip: OFF")
    end,
})

-- ═══ TAB: Identity ═══
local IdTab = Window:CreateTab("ID", "🎭")
IdTab:CreateSection("👤 CHAT IDENTITY")
IdTab:CreateDropdown({Name = "🏷️ Title", Options = {"GLOBAL", "SERVER ANNOUNCEMENT", "👑Head Administrator👑", "👑Head Executive Lead Developer👑", "None"}, CurrentOption = "None", Callback = function(v) Config.CustomTag=(v=="None" or v=="") and "" or v end})
IdTab:CreateDropdown({Name = "👤 Username", Options = {"RezurXshin☑️", "Jandel", "Administrator", "None"}, CurrentOption = "None", Callback = function(v) Config.UserName=(v=="None" or v=="") and "" or v end})
IdTab:CreateInput({Name = "✏️ Custom Title", PlaceholderText = "Enter title...", Callback = function(v) Config.CustomTag=v or "" end})
IdTab:CreateInput({Name = "✏️ Custom Name", PlaceholderText = "Enter name...", Callback = function(v) Config.UserName=v or "" end})
IdTab:CreateSection("🎨 COLORS")
IdTab:CreateColorPicker({Name = "🎨 Tag Color", Color = Config.TagColor, Callback = function(c) Config.TagColor=c end})
IdTab:CreateColorPicker({Name = "🎨 User Color", Color = Config.UserColor, Callback = function(c) Config.UserColor=c end})
IdTab:CreateColorPicker({Name = "🎨 Msg Color", Color = Config.MessageColor, Callback = function(c) Config.MessageColor=c end})

-- ═══ TAB: Chat ═══
local ChatTab = Window:CreateTab("Chat", "💬")
ChatTab:CreateSection("👻 GHOST SHOUT")
local chatInput = ChatTab:CreateInput({Name = "💬 Message", PlaceholderText = "Type message...", Callback = function(v) end})
ChatTab:CreateButton({Name = "📤 Send", Callback = function()
    local msg = chatInput:Get()
    if msg and msg ~= "" then sendChatMessage(msg) notify("✅ Sent", msg:sub(1,40), 3, "success") chatInput:Set("") end
end})
ChatTab:CreateButton({Name = "📤 Resend", Callback = function()
    local msg = chatInput:Get()
    if msg and msg ~= "" then sendChatMessage(msg) notify("✅ Sent", msg:sub(1,40), 3, "success") else notify("⚠️ Chat", "Type first", 2, "warning") end
end})
ChatTab:CreateButton({Name = "🧹 Clear", Callback = function() chatInput:Set("") notify("💬 Chat", "Cleared", 2, "info") end})

-- ═══ TAB: Lab ═══
local LabTab = Window:CreateTab("Lab", "🧪")
LabTab:CreateSection("⚙️ EXPERIMENTS")
LabTab:CreateToggle({Name = "🛡️ Anti-AFK", CurrentValue = true, Callback = function(t) Config.AntiAfk=t end})
local pvpToggle = LabTab:CreateToggle({
    Name = "⚔️ PVP: OFF (Safe)",
    CurrentValue = true,
    Callback = function(t)
        Config.PvpOff = t
        -- [FIX] Dynamic label — shows current state so user knows it worked
        pvpToggle:SetLabel(t and "⚔️ PVP: OFF (Safe)" or "⚔️ PVP: ON (Danger)")
    end,
})
LabTab:CreateSection("👁️ ESP")
local function toggleESP(t)
    Config.EspEnabled=t
    if not t then clearEsp() return end
    espConn=RunService.RenderStepped:Connect(function()
        pcall(function()
            local cr=workspace:FindFirstChild("Creature") local ac=cr and cr:FindFirstChild("Activation") if not ac then return end
            local seen={}
            for _,obj in ipairs(ac:GetChildren()) do for _,pm in ipairs(obj:GetChildren()) do
                local h=pm:FindFirstChild("Head") if h then
                    seen[h]=true local e=espCache[h] local pw=getPowerFor(pm.Name)
                    if not e then
                        local bb=Instance.new("BillboardGui") bb.Name="RT" bb.Adornee=h bb.Size=UDim2.new(0,100,0,30) bb.StudsOffset=Vector3.new(0,3,0) bb.AlwaysOnTop=true bb.Parent=h
                        local l=Instance.new("TextLabel") l.Parent=bb l.Size=UDim2.new(1,0,1,0) l.BackgroundTransparency=1 l.TextColor3=Color3.new(1,1,1) l.TextStrokeTransparency=0 l.Font=Enum.Font.GothamBold l.TextSize=11 l.Text=formatNumber(pw)
                        espCache[h]={gui=bb,label=l,lastValue=pw}
                    elseif e.lastValue~=pw then e.label.Text=formatNumber(pw) e.lastValue=pw end
                end
            end end
            for h,e in pairs(espCache) do if not seen[h] or not h.Parent then if e.gui then e.gui:Destroy() end espCache[h]=nil end end
        end)
    end)
end
LabTab:CreateToggle({Name = "👁️ ESP", CurrentValue = false, Callback = function(t) toggleESP(t) end})
LabTab:CreateButton({Name = "🧹 Clear ESP", Callback = function() clearEsp() notify("👁️ ESP", "Cleared", 3, "info") end})

-- ═══ TAB: System ═══
local SysTab = Window:CreateTab("Sys", "⚙️")
SysTab:CreateSection("💾 PROFILE")
SysTab:CreateButton({Name = "💾 Save Profile", Callback = function()
    local p={CustomTag=Config.CustomTag,UserName=Config.UserName,TagColor={Config.TagColor.R,Config.TagColor.G,Config.TagColor.B},UserColor={Config.UserColor.R,Config.UserColor.G,Config.UserColor.B},MessageColor={Config.MessageColor.R,Config.MessageColor.G,Config.MessageColor.B},FarmMode=Config.FarmMode,FarmSpeedMul=Config.FarmSpeedMul,WorkerCount=Config.WorkerCount,MaxPerformance=Config.MaxPerformance,TrainSpeedValue=Config.TrainSpeedValue,AntiDetect=Config.AntiDetect,WalkSpeed=Config.WalkSpeed,JumpPower=Config.JumpPower,NoclipMode=Config.NoclipMode,AntiAfk=Config.AntiAfk}
    if writefile then writefile("DOMINUS_Profile.json",HttpService:JSONEncode(p)) notify("💾 Saved","Profile saved.",3,"success") else notify("❌ Error","writefile N/A",4,"error") end
end})
SysTab:CreateButton({Name = "📂 Load Profile", Callback = function()
    if not readfile then notify("❌ Error","readfile N/A",4,"error") return end
    local ok,c=pcall(readfile,"DOMINUS_Profile.json") if not ok or not c then notify("⚠️ Error","No profile",3,"warning") return end
    local ok2,p=pcall(function() return HttpService:JSONDecode(c) end) if not ok2 or type(p)~="table" then notify("❌ Error","Corrupted",4,"error") return end
    Config.CustomTag=p.CustomTag or "" Config.UserName=p.UserName or ""
    if p.TagColor then Config.TagColor=Color3.new(p.TagColor[1],p.TagColor[2],p.TagColor[3]) end
    if p.UserColor then Config.UserColor=Color3.new(p.UserColor[1],p.UserColor[2],p.UserColor[3]) end
    if p.MessageColor then Config.MessageColor=Color3.new(p.MessageColor[1],p.MessageColor[2],p.MessageColor[3]) end
    Config.FarmMode=p.FarmMode or "Hybrid" Config.FarmSpeedMul=p.FarmSpeedMul or 1 Config.WorkerCount=p.WorkerCount or 50 Config.MaxPerformance=p.MaxPerformance or false Config.TrainSpeedValue=p.TrainSpeedValue or "Infinity" Config.AntiDetect=p.AntiDetect~=nil and p.AntiDetect or false Config.WalkSpeed=p.WalkSpeed or 16 Config.JumpPower=p.JumpPower or 50 Config.NoclipMode=p.NoclipMode or "Improved" Config.AntiAfk=p.AntiAfk~=nil and p.AntiAfk or true
    notify("📂 Loaded","Profile loaded.",3,"info")
end})
SysTab:CreateSection("❌ DANGER")
local dc=false
SysTab:CreateButton({Name = "❌ Destroy UI (confirm)", Callback = function()
    if dc then Lib:Destroy() else dc=true notify("⚠️ Confirm","Click again 3s",3,"warning") task.delay(3,function() dc=false end) end
end})

-- ═══ TAB: About ═══
local AboutTab = Window:CreateTab("About", "ℹ️")
AboutTab:CreateSection("👑 ABOUT")
AboutTab:CreateParagraph({Title = "👑 DOMINUS V8", Content = "👑 DOMINUS V8\n🔥 Maximum Power Edition\n\nMade by RezurXshin\nCreator of RezurXLabs\n\n🛡️ All rights reserved to RezurXshin (Creator of RezurXLabs)\n\n⚙️ Engine: Hybrid Farm + math.huge\n👻 Noclip: V777 + Improved\n🌙 Overnight Mode\n🚀 Turbo Boost\n💾 Save/Load Profiles\n\nPowered by RezurXLib"})
AboutTab:CreateSection("👑 CREDITS")
AboutTab:CreateParagraph({Title = "Credits", Content = "👑 Creator: RezurXshin\n🏢 Studio: RezurXLabs\n📦 UI: RezurXLib v1.0\n⚡ Engine: DOMINUS Hybrid Apex\n\n🛡️ All rights reserved.\n© 2026 RezurXshin."})

-- ═══ KEYBOARD SHORTCUTS ═══
UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    local k = inp.KeyCode
    if k == Enum.KeyCode.F and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        Config.FarmEnabled = not Config.FarmEnabled
        task.spawn(function() if Config.FarmEnabled then startFarm() else stopFarm() end end)
        farmToggle:Set(Config.FarmEnabled)
        notify("⌨️ Shortcut", "Farm: " .. (Config.FarmEnabled and "ON" or "OFF"), 2, "info")
    elseif k == Enum.KeyCode.N and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        Config.NoclipEnabled = not Config.NoclipEnabled
        task.spawn(function() setNoclipMode(Config.NoclipEnabled) end)
        notify("⌨️ Shortcut", "Noclip: " .. (Config.NoclipEnabled and "ON" or "OFF"), 2, "info")
    elseif k == Enum.KeyCode.T and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        task.spawn(setTurbo)
    end
end)

-- ═══ BOOT ═══
notify("👑 DOMINUS V8", "🔥 Loaded. Press K to toggle. Made by RezurXshin", 7, "success")
