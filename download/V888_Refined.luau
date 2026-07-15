--[[
    👑WELCOME DEVELOPER👑 V888🔥: REFINED
    Improvements over V777:
      • FIX: math.huge replaced with finite 1e9 (network serializer hates Inf)
      • FIX: Chat remote cached + pcall + multi-format fallback + debug button
      • FIX: Dropdown callbacks handle both string AND table returns (v[1] bug)
      • FIX: CurrentOption now a valid string ("None") instead of {""}
      • FIX: ApplyMovement gated to only fire when stats actually drift
      • FIX: Noclip skips parts already non-colliding, restores on disable
      • FIX: ESP cleans up all RezurTag instances when toggled off
      • FIX: RespectFarm now targets the other player (not your own username)
      • PERF: Cached remote references, less per-frame work
      • SAFETY: pcall around every remote call
      • PRESERVED: Identity Matrix, Triple Colors, Chat Bypass, 15-line pump
]]

--==============================================================
-- SERVICES & PLAYER
--==============================================================
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

--==============================================================
-- RAYFIELD LOAD (with failure guard)
--==============================================================
local Rayfield
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)
    if not ok or not result then
        warn("[V888] Rayfield failed to load. Aborting script.")
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
    EspEnabled     = false,
    OverrideStats  = false,
    WalkSpeed      = 16,
    JumpPower      = 50,
    RespectFarm    = false,
    Noclip         = false,
    AntiSlow       = false,
    PvpOff         = false,
}

--==============================================================
-- HELPERS
--==============================================================

-- Rayfield dropdowns in newer versions pass a string, in older versions a table.
-- This handles both safely so v[1] never errors again.
local function dropValue(v: any): string
    if typeof(v) == "table" then
        return v[1] or ""
    end
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

-- Safe remote invokers (one failure no longer kills the whole pump)
local function safeInvoke(remote: RemoteEvent?, ...)
    if not remote then return end
    pcall(remote.InvokeServer, remote, ...)
end
local function safeFire(remote: RemoteEvent?, ...)
    if not remote then return end
    pcall(remote.FireServer, remote, ...)
end

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
-- math.huge breaks Roblox's network serializer. 1e9 is large enough to
-- trigger the pump but actually serializes cleanly to the server.
local TRAIN_SPEED = 1e9

local TrainRemotes = {
    ApplyAddFrenzyValue    = nil,
    TrainSpeedHasChanged   = nil,
    ApplyMobileTrain       = nil,
    ApplyStationaryTrain   = nil,
}

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
    if not TrainRemotes.ApplyAddFrenzyValue then initTrainRemotes() end
    local r = TrainRemotes
    if not r.ApplyAddFrenzyValue then return end
    -- 15-line RezurXshin pump (preserved structure, finite speed)
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
    -- Try the original table format first; if it errors, fall back to a plain string.
    -- A lot of games' chat remotes only accept one or the other.
    local ok1 = pcall(function() ChatRemote:InvokeServer({ Text = full }) end)
    if not ok1 then
        pcall(function() ChatRemote:InvokeServer(full) end)
    end
end

--==============================================================
-- UI
--==============================================================
local Window = Rayfield:CreateWindow({
    Name             = "👑WELCOME DEVELOPER👑 | V888🔥 REFINED",
    LoadingTitle     = "Initializing Elite Developer Protocol...",
    LoadingSubtitle  = "V888🔥 Refined Authority",
    ConfigurationSaving = { Enabled = false },
})

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

------------------------------------------------- TAB 2: GHOST SHOUT
local GlobalTab = Window:CreateTab("Ghost Shout", 4483362458)
GlobalTab:CreateInput({
    Name = "Send Shout (Box)",
    PlaceholderText = "Type message...",
    RemoveTextAfterFocusLost = true,
    Callback = function(msg) sendChatMessage(msg) end,
})
-- Debug button so you can verify the remote actually exists in this game
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
-- Plain-text fallback (no rich-text tags) — use if the game strips <font>
GlobalTab:CreateButton({
    Name = "Send Plain-Text Test Shout",
    Callback = function()
        if not ChatRemote then initChatRemote() end
        if not ChatRemote then return end
        pcall(function() ChatRemote:InvokeServer("V888 test ping") end)
    end,
})

------------------------------------------------- TAB 3: OVERDRIVE FARM
local FarmTab = Window:CreateTab("Overdrive Farm", 4483362458)
FarmTab:CreateDropdown({
    Name = "Auto Train Intensity",
    Options = {"Redmi (Light)", "Mid-Range (Balanced)",
               "Flagship (S22 Ultra)", "SINGULARITY (OVERLOAD)"},
    CurrentOption = "Flagship (S22 Ultra)",
    Callback = function(v) Config.FarmMode = dropValue(v) end,
})
FarmTab:CreateToggle({
    Name = "RezurXshin Auto Train",
    CurrentValue = false,
    Callback = function(t)
        Config.FarmEnabled = t
        if not t then return end
        task.spawn(function()
            while Config.FarmEnabled do
                local loops = 1
                if Config.FarmMode:find("Mid")  then loops = 5
                elseif Config.FarmMode:find("Flag") then loops = 15
                elseif Config.FarmMode:find("SING") then loops = 50 end
                for _ = 1, loops do
                    task.spawn(function() pcall(DoTrain) end)
                end
                task.wait(0.05)  -- was 0.01 — slightly higher for stability
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
                                -- FIX: pass the TARGET name, not your own
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

------------------------------------------------- TAB 4: SPECTRAL SCAN
local VisTab = Window:CreateTab("Spectral Scan", 4483362458)

local function clearAllEspTags()
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "RezurTag" then obj:Destroy() end
        end
    end)
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
        task.spawn(function()
            while Config.EspEnabled do
                pcall(function()
                    local creature   = workspace:FindFirstChild("Creature")
                    local activation = creature and creature:FindFirstChild("Activation")
                    if not activation then return end
                    for _, obj in ipairs(activation:GetChildren()) do
                        for _, pMod in ipairs(obj:GetChildren()) do
                            local h = pMod:FindFirstChild("Head")
                            if h then
                                local old = h:FindFirstChild("RezurTag")
                                if old then old:Destroy() end
                                local bb = Instance.new("BillboardGui")
                                bb.Name          = "RezurTag"
                                bb.Parent        = h
                                bb.Size          = UDim2.new(0, 100, 0, 30)
                                bb.StudsOffset   = Vector3.new(0, 3, 0)
                                bb.AlwaysOnTop   = true
                                local l = Instance.new("TextLabel")
                                l.Parent                  = bb
                                l.Size                    = UDim2.new(1, 0, 1, 0)
                                l.BackgroundTransparency  = 1
                                l.TextColor3              = Color3.new(1, 1, 1)
                                l.TextStrokeTransparency  = 0
                                l.TextScaled              = true
                                l.Text                    = formatNumber(getPower(pMod.Name))
                            end
                        end
                    end
                end)
                task.wait(0.6)
            end
        end)
    end,
})

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
    Callback = function(v)
        Config.WalkSpeed = v
        applyMovement()
    end,
})
LocalTab:CreateSlider({
    Name = "JumpPower",
    Range = {50, 1000},
    Increment = 1,
    CurrentValue = 50,
    Suffix = " Power",
    Callback = function(v)
        Config.JumpPower = v
        applyMovement()
    end,
})

-- Heartbeat re-apply ONLY when OverrideStats is on AND values have drifted
-- (server scripts often reset WalkSpeed every few frames)
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
ExpTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Callback = function(t)
        Config.Noclip = t
        if not t then
            -- restore collisions on body parts (keep HRP non-collide, that's normal)
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
    end,
})

--==============================================================
-- CORE LOOP
--==============================================================

-- Noclip: skip parts already non-colliding (was touching EVERY part EVERY frame)
RunService.Stepped:Connect(function()
    if not Config.Noclip then return end
    local char = player.Character
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") and v.CanCollide then
            v.CanCollide = false
        end
    end
end)

-- PvpOff area spam (now with nil-safety)
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

Rayfield:Notify({
    Title   = "👑WELCOME DEVELOPER👑",
    Content = "V888🔥 Refined loaded. Chat + math.huge + dropdowns fixed.",
    Duration = 5,
})
