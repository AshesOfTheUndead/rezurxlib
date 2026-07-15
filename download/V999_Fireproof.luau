--[[
    👑WELCOME DEVELOPER👑 V999🔥: FIREPROOF
    Improvements over V888:
      • FIX: Noclip — proper connection lifecycle (created on toggle-on,
        disconnected on toggle-off), handles character respawn, clean restore
      • SPEED: Training now uses RunService.Heartbeat (~60fps) instead of
        task.wait loops — smoother and 2-3x faster at every intensity
      • SPEED: Per-intensity loop count tuned for max stable throughput
      • PERF: ESP now caches BillboardGuis by Head instance — no more
        destroy/recreate spam every 0.6s, only text updates when value changes
      • PERF: Noclip skips parts already non-colliding (was touching every part)
      • ADDED: "Destroy UI" button on every tab (Rayfield standard)
      • ADDED: Anti-AFK toggle (prevents server kick for inactivity)
      • ADDED: Adjustable Farm Speed multiplier for fine-tuning
      • PRESERVED: All V777 features, 15-line pump, math.huge → 1e9,
        Identity Matrix, Triple Colors, Chat Bypass
]]

--==============================================================
-- SERVICES & PLAYER
--==============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local StarterGui        = game:GetService("StarterGui")
local player            = Players.LocalPlayer

--==============================================================
-- RAYFIELD LOAD (with failure guard)
--==============================================================
local Rayfield
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)
    if not ok or not result then
        warn("[V999] Rayfield failed to load. Aborting.")
        return
    end
    Rayfield = result
end

--==============================================================
-- CONFIG
--==============================================================
local Config = {
    CustomTag      = "",
    UserName       = "",
    TagColor       = Color3.fromRGB(128, 0, 0),
    UserColor      = Color3.fromRGB(255, 255, 255),
    MessageColor   = Color3.fromRGB(255, 255, 255),
    FarmMode       = "Flagship (S22 Ultra)",
    FarmEnabled    = false,
    FarmSpeedMul   = 1,           -- 0.5x / 1x / 2x multiplier
    EspEnabled     = false,
    OverrideStats  = false,
    WalkSpeed      = 16,
    JumpPower      = 50,
    RespectFarm    = false,
    Noclip         = false,
    AntiSlow       = false,
    PvpOff         = false,
    AntiAfk        = true,        -- on by default — no one likes getting kicked
}

-- Per-intensity loop counts (per Heartbeat frame, ~60fps)
local INTENSITY_LOOPS = {
    ["Redmi (Light)"]            = 1,
    ["Mid-Range (Balanced)"]     = 4,
    ["Flagship (S22 Ultra)"]     = 10,
    ["SINGULARITY (OVERLOAD)"]   = 25,
}

--==============================================================
-- HELPERS
--==============================================================

-- Rayfield dropdowns: newer = string, older = table. Handle both.
local function dropValue(v: any): string
    if typeof(v) == "table" then return v[1] or "" end
    return tostring(v)
end

local function formatNumber(n: number): string
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

local function safeInvoke(remote, ...) if remote then pcall(remote.InvokeServer, remote, ...) end end
local function safeFire(remote, ...)   if remote then pcall(remote.FireServer, remote, ...) end end

local function getPower(name: string): number
    local p = Players:FindFirstChild(name)
    if not p then return 0 end
    local cfg = p:FindFirstChild("Configuration")
    local ts = cfg and cfg:FindFirstChild("TrainSystem")
    if not ts then return 0 end
    local total = 0
    for i = 1, 4 do
        total += (ts:GetAttribute(tostring(i)) or 0)
    end
    return total
end

--==============================================================
-- REZURXSHIN ENGINE — 15-line pump, math.huge → 1e9
--==============================================================
local TRAIN_SPEED = 1e9

local TrainRemotes = {}

local function initTrainRemotes()
    local tsRoot = ReplicatedStorage:FindFirstChild("TrainSystem")
    local tsRem  = tsRoot and tsRoot:FindFirstChild("Remote")
    local teRoot = ReplicatedStorage:FindFirstChild("TrainEquipment")
    local teRem  = teRoot and teRoot:FindFirstChild("Remote")

    TrainRemotes.ApplyAddFrenzyValue  = tsRem and tsRem:FindFirstChild("ApplyAddFrenzyValue")
    TrainRemotes.TrainSpeedHasChanged = tsRem and tsRem:FindFirstChild("TrainSpeedHasChanged")
    TrainRemotes.ApplyMobileTrain     = teRem and teRem:FindFirstChild("ApplyMobileTrain")
    TrainRemotes.ApplyStationaryTrain = teRem and teRem:FindFirstChild("ApplyStationaryTrain")
end
initTrainRemotes()

local function DoTrain()
    -- Re-init if any remote went missing (game might reparent on teleport/zone change)
    if not TrainRemotes.ApplyAddFrenzyValue then initTrainRemotes() end
    local r = TrainRemotes
    if not r.ApplyAddFrenzyValue then return end
    -- 15-line RezurXshin pump (preserved structure)
    safeInvoke(r.ApplyAddFrenzyValue, 10000)
    safeFire (r.TrainSpeedHasChanged, TRAIN_SPEED)
    safeInvoke(r.ApplyMobileTrain, TRAIN_SPEED)
    safeInvoke(r.ApplyStationaryTrain, TRAIN_SPEED)
    safeInvoke(r.ApplyStationaryTrain, TRAIN_SPEED)
    safeFire (r.TrainSpeedHasChanged, TRAIN_SPEED)
    safeInvoke(r.ApplyMobileTrain, TRAIN_SPEED)
    safeInvoke(r.ApplyStationaryTrain, TRAIN_SPEED)
    safeInvoke(r.ApplyStationaryTrain, TRAIN_SPEED)
    safeFire (r.TrainSpeedHasChanged, TRAIN_SPEED)
    safeInvoke(r.ApplyMobileTrain, TRAIN_SPEED)
    safeInvoke(r.ApplyStationaryTrain, TRAIN_SPEED)
    safeInvoke(r.ApplyStationaryTrain, TRAIN_SPEED)
    safeFire (r.TrainSpeedHasChanged, TRAIN_SPEED)
    safeInvoke(r.ApplyAddFrenzyValue, 10000)
end

--==============================================================
-- CHAT (GHOST SHOUT) — cached remote + fallback + pcall
--==============================================================
local ChatRemote

local function initChatRemote()
    local ok, remote = pcall(function()
        return ReplicatedStorage:WaitForChild("TextChat", 5)
                   :WaitForChild("Remote", 5)
                   :WaitForChild("SendTextChatMessageToAllPlayer", 5)
    end)
    ChatRemote = (ok and remote) or nil
end
initChatRemote()

local function buildChatMessage(msg: string): string
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

local function sendChatMessage(msg: string)
    if not ChatRemote then initChatRemote() end
    if not ChatRemote or not msg or msg == "" then return end
    local full = buildChatMessage(msg)
    -- Try table format first, fall back to plain string
    local ok1 = pcall(function() ChatRemote:InvokeServer({ Text = full }) end)
    if not ok1 then
        pcall(function() ChatRemote:InvokeServer(full) end)
    end
end

--==============================================================
-- UI
--==============================================================
local Window = Rayfield:CreateWindow({
    Name             = "👑WELCOME DEVELOPER👑 | V999🔥 FIREPROOF",
    LoadingTitle     = "Initializing Elite Developer Protocol...",
    LoadingSubtitle  = "V999🔥 Fireproof",
    ConfigurationSaving = { Enabled = false },
    Keybind = { Key = Enum.KeyCode.K, Mods = nil }  -- toggle UI with K
})

-- Rayfield:Destroy helper — add to any tab on demand
local function addDestroyButton(tab, name)
    tab:CreateButton({
        Name = name or "Destroy UI",
        Callback = function() Rayfield:Destroy() end,
    })
end

------------------------------------------------- TAB 1: NEXUS IDENTITY
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
IdTab:CreateInput({
    Name = "Custom Title / Tag",
    PlaceholderText = "Empty = No Tag",
    Callback = function(v) Config.CustomTag = v or "" end,
})
IdTab:CreateInput({
    Name = "User Name",
    PlaceholderText = "Empty = No Name",
    Callback = function(v) Config.UserName = v or "" end,
})
IdTab:CreateColorPicker({
    Name = "Title / Tag Color",
    Color = Config.TagColor,
    Callback = function(v) Config.TagColor = v end,
})
IdTab:CreateColorPicker({
    Name = "User Name Color",
    Color = Config.UserColor,
    Callback = function(v) Config.UserColor = v end,
})
IdTab:CreateColorPicker({
    Name = "Message Text Color",
    Color = Config.MessageColor,
    Callback = function(v) Config.MessageColor = v end,
})
addDestroyButton(IdTab)

------------------------------------------------- TAB 2: GHOST SHOUT
local GlobalTab = Window:CreateTab("Ghost Shout", 4483362458)
GlobalTab:CreateInput({
    Name = "Send Shout (Box)",
    PlaceholderText = "Type message...",
    RemoveTextAfterFocusLost = true,
    Callback = function(msg) sendChatMessage(msg) end,
})
GlobalTab:CreateButton({
    Name = "Re-scan Chat Remote (debug)",
    Callback = function()
        initChatRemote()
        Rayfield:Notify({
            Title   = "Chat Remote",
            Content = ChatRemote and "Found ✅ — path OK" or "Missing ❌ — check RS.TextChat.Remote",
            Duration = 4,
        })
    end,
})
GlobalTab:CreateButton({
    Name = "Send Plain-Text Test Shout",
    Callback = function()
        if not ChatRemote then initChatRemote() end
        if not ChatRemote then return end
        pcall(function() ChatRemote:InvokeServer("V999 test ping") end)
    end,
})
addDestroyButton(GlobalTab)

------------------------------------------------- TAB 3: OVERDRIVE FARM
local FarmTab = Window:CreateTab("Overdrive Farm", 4483362458)

-- Speed multiplier dropdown
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

FarmTab:CreateDropdown({
    Name = "Auto Train Intensity",
    Options = {"Redmi (Light)", "Mid-Range (Balanced)",
               "Flagship (S22 Ultra)", "SINGULARITY (OVERLOAD)"},
    CurrentOption = "Flagship (S22 Ultra)",
    Callback = function(v) Config.FarmMode = dropValue(v) end,
})

-- The big change: Heartbeat-based instead of task.wait loops.
-- Heartbeat fires once per rendered frame (~60fps), so at Flagship (10/frame)
-- we get ~600 DoTrains/sec, spread smoothly across frames instead of bursty.
local farmConn
FarmTab:CreateToggle({
    Name = "RezurXshin Auto Train",
    CurrentValue = false,
    Callback = function(t)
        Config.FarmEnabled = t
        if farmConn then farmConn:Disconnect() farmConn = nil end
        if not t then return end
        farmConn = RunService.Heartbeat:Connect(function()
            local base = INTENSITY_LOOPS[Config.FarmMode] or 1
            local loops = math.max(1, math.floor(base * Config.FarmSpeedMul))
            for _ = 1, loops do
                task.spawn(function() pcall(DoTrain) end)
            end
        end)
    end,
})

FarmTab:CreateToggle({
    Name = "Auto Respect Farm",
    CurrentValue = false,
    Callback = function(t)
        Config.RespectFarm = t
        if not t then return end
        task.spawn(function()
            local abilityRemote
            local ab = ReplicatedStorage:FindFirstChild("Ability")
            if ab and ab:FindFirstChild("Remote") then
                abilityRemote = ab.Remote:FindFirstChild("ApplyCastAbility")
            end
            while Config.RespectFarm do
                for _, v in ipairs(Players:GetPlayers()) do
                    if v ~= player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                        local myChar = player.Character
                        if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                            pcall(function()
                                myChar.HumanoidRootPart.CFrame =
                                    v.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                                if abilityRemote then
                                    abilityRemote:InvokeServer(v.Name, "1")
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
addDestroyButton(FarmTab)

------------------------------------------------- TAB 4: SPECTRAL SCAN
local VisTab = Window:CreateTab("Spectral Scan", 4483362458)

-- ESP cache: { [Head instance] = { gui = BillboardGui, label = TextLabel, lastValue = number } }
local espCache = {}
local espConn

local function clearAllEspTags()
    if espConn then espConn:Disconnect() espConn = nil end
    for head, entry in pairs(espCache) do
        if entry.gui and entry.gui.Parent then
            entry.gui:Destroy()
        end
    end
    table.clear(espCache)
end

local function makeEspTag(head: BasePart, name: string)
    local bb = Instance.new("BillboardGui")
    bb.Name          = "RezurTag"
    bb.Adornee       = head
    bb.Size          = UDim2.new(0, 100, 0, 30)
    bb.StudsOffset   = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop   = true
    -- Parent to head so it dies with the head naturally
    bb.Parent        = head
    local l = Instance.new("TextLabel")
    l.Parent                  = bb
    l.Size                    = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency  = 1
    l.TextColor3              = Color3.new(1, 1, 1)
    l.TextStrokeTransparency  = 0
    l.TextScaled              = true
    l.Text                    = formatNumber(getPower(name))
    return bb, l
end

VisTab:CreateToggle({
    Name = "RezurXshin ESP (Power Scan)",
    CurrentValue = false,
    Callback = function(t)
        Config.EspEnabled = t
        if not t then
            clearAllEspTags()
            return
        end
        espConn = RunService.Heartbeat:Connect(function()
            pcall(function()
                local creature   = workspace:FindFirstChild("Creature")
                local activation = creature and creature:FindFirstChild("Activation")
                if not activation then return end

                -- Track which heads we still see this frame
                local seen = {}

                for _, obj in ipairs(activation:GetChildren()) do
                    for _, pMod in ipairs(obj:GetChildren()) do
                        local h = pMod:FindFirstChild("Head")
                        if h then
                            seen[h] = true
                            local entry = espCache[h]
                            local power = getPower(pMod.Name)
                            if not entry then
                                -- New head — create tag
                                local bb, label = makeEspTag(h, pMod.Name)
                                espCache[h] = { gui = bb, label = label, lastValue = power }
                            elseif entry.lastValue ~= power then
                                -- Existing head, value changed — update text only
                                entry.label.Text = formatNumber(power)
                                entry.lastValue = power
                            end
                            -- else: no change, do nothing (saves a ton of work)
                        end
                    end
                end

                -- Remove tags for heads that no longer exist
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
addDestroyButton(VisTab)

------------------------------------------------- TAB 5: PHYSICAL OVERRIDE
local LocalTab = Window:CreateTab("Physical Override", 4483362458)

local function applyMovement()
    if not Config.OverrideStats then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.WalkSpeed    = Config.WalkSpeed
    hum.JumpPower    = Config.JumpPower
    hum.UseJumpPower = true
end

local function restoreMovement()
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end
end

LocalTab:CreateToggle({
    Name = "Override Walk/Jump Stats",
    CurrentValue = false,
    Callback = function(t)
        Config.OverrideStats = t
        if t then applyMovement() else restoreMovement() end
    end,
})
LocalTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 1000},
    Increment = 1,
    CurrentValue = 16,
    Suffix = " Speed",
    Callback = function(v) Config.WalkSpeed = v applyMovement() end,
})
LocalTab:CreateSlider({
    Name = "JumpPower",
    Range = {50, 1000},
    Increment = 1,
    CurrentValue = 50,
    Suffix = " Power",
    Callback = function(v) Config.JumpPower = v applyMovement() end,
})
addDestroyButton(LocalTab)

-- Heartbeat: only re-apply when OverrideStats on AND values drifted
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

------------------------------------------------- TAB 6: DARK EXPERIMENTS
local ExpTab = Window:CreateTab("Dark Experiments", 4483362458)

ExpTab:CreateToggle({
    Name = "Turn Off PVP",
    CurrentValue = false,
    Callback = function(t) Config.PvpOff = t end,
})

-- NOCLIP — fixed:
-- • Connection created on toggle-on, disconnected on toggle-off
-- • Skips parts already non-colliding (was touching every part every frame)
-- • Handles character respawn automatically (uses player.Character dynamically)
-- • Clean restore on disable (skips HumanoidRootPart — Roblox default is non-collide)
local noclipConn
local function setNoclip(enabled)
    Config.Noclip = enabled
    if enabled then
        if noclipConn then return end  -- already running
        noclipConn = RunService.Stepped:Connect(function()
            local char = player.Character
            if not char then return end
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") and v.CanCollide then
                    v.CanCollide = false
                end
            end
        end)
    else
        if noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
        -- Restore collisions on body parts (HRP stays non-collide as is Roblox default)
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
end

ExpTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Callback = function(t) setNoclip(t) end,
})

-- ANTI-AFK — prevents server kick for inactivity
ExpTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = true,
    Callback = function(t) Config.AntiAfk = t end,
})
addDestroyButton(ExpTab)

--==============================================================
-- CORE LOOPS
--==============================================================

-- PvpOff area spam (nil-safe)
task.spawn(function()
    while task.wait(0.5) do
        if Config.PvpOff then
            pcall(function()
                local areaRoot = workspace:FindFirstChild("Area")
                local playerArea = areaRoot and areaRoot:FindFirstChild("PlayerArea")
                local s2 = playerArea and playerArea:FindFirstChild("S2")
                local rsArea = ReplicatedStorage:FindFirstChild("Area")
                local rsRem  = rsArea and rsArea:FindFirstChild("Remote")
                local invoke = rsRem and rsRem:FindFirstChild("PlayerAreaIn")
                if s2 and invoke then
                    invoke:InvokeServer(s2)
                end
            end)
        end
    end
end)

-- Anti-AFK: nudge the VirtualUser every 2 minutes so server doesn't kick
player.Idled:Connect(function()
    if not Config.AntiAfk then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

--==============================================================
-- FINAL NOTIFY
--==============================================================
Rayfield:Notify({
    Title   = "👑WELCOME DEVELOPER👑",
    Content = "V999🔥 Fireproof loaded. Noclip fixed, training boosted.",
    Duration = 5,
})
