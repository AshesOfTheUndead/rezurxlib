--[[
    👑WELCOME DEVELOPER👑 V1100🔥: POLISHED RAYFIELD
    - Back to Rayfield (proven, reliable UI library)
    - Polished EVERYTHING: better organization, smoother loops, more debug tools
    - All V999/V1000 improvements kept: Heartbeat farm, fixed Noclip lifecycle,
      cached ESP, Anti-AFK, math.huge → 1e9, pcall everywhere
    - New: Status dashboard tab showing live remote health, player count, FPS
    - New: Per-feature debug buttons so you can isolate what's broken
    - New: Smart re-init — if a remote goes missing, auto re-scan instead of fail
    - New: Configurable ESP refresh rate (faster or slower scan)
    - New: Configurable Noclip update rate (smooth vs aggressive)
]]

--==============================================================
-- BOOT
--==============================================================
repeat task.wait() until game:IsLoaded()

--==============================================================
-- SERVICES
--==============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local Stats             = game:GetService("Stats")
local player            = Players.LocalPlayer

--==============================================================
-- RAYFIELD LOAD (with retry)
--==============================================================
local Rayfield
do
    local attempts = 0
    while not Rayfield and attempts < 3 do
        attempts += 1
        local ok, result = pcall(function()
            return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
        end)
        if ok and result then Rayfield = result break end
        warn(string.format("[V1100] Rayfield load attempt %d failed: %s", attempts, tostring(result)))
        task.wait(2)
    end
    if not Rayfield then
        warn("[V1100] Rayfield failed to load after 3 attempts. Aborting.")
        return
    end
end

--==============================================================
-- CONFIG
--==============================================================
local Config = {
    -- Identity
    CustomTag      = "",
    UserName       = "",
    TagColor       = Color3.fromRGB(128, 0, 0),
    UserColor      = Color3.fromRGB(255, 255, 255),
    MessageColor   = Color3.fromRGB(255, 255, 255),
    -- Farm
    FarmMode       = "Flagship (S22 Ultra)",
    FarmEnabled    = false,
    FarmSpeedMul   = 1,
    -- ESP
    EspEnabled     = false,
    EspRefreshRate = 0.3,        -- seconds between full re-scans (text updates are instant)
    -- Movement
    OverrideStats  = false,
    WalkSpeed      = 16,
    JumpPower      = 50,
    -- Combat
    RespectFarm    = false,
    -- Experimental
    Noclip         = false,
    NoclipRate     = "Smooth",  -- "Smooth" (Stepped) or "Aggressive" (Heartbeat)
    AntiSlow       = false,
    PvpOff         = false,
    AntiAfk        = true,
}

local INTENSITY_LOOPS = {
    ["Redmi (Light)"]          = 1,
    ["Mid-Range (Balanced)"]   = 4,
    ["Flagship (S22 Ultra)"]   = 10,
    ["SINGULARITY (OVERLOAD)"] = 25,
}

--==============================================================
-- HELPERS
--==============================================================
local function dropValue(v)
    if typeof(v) == "table" then return v[1] or "" end
    return tostring(v)
end

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

local function safeInvoke(remote, ...) if remote then pcall(remote.InvokeServer, remote, ...) end end
local function safeFire(remote, ...)   if remote then pcall(remote.FireServer, remote, ...) end end

local function getPower(name)
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
-- REMOTE MANAGER — smart re-init system
--==============================================================
local Remotes = {
    -- Train
    ApplyAddFrenzyValue    = nil,
    TrainSpeedHasChanged   = nil,
    ApplyMobileTrain       = nil,
    ApplyStationaryTrain   = nil,
    -- Chat
    SendTextChatMessage    = nil,
    -- Ability
    ApplyCastAbility       = nil,
    -- Area
    PlayerAreaIn           = nil,
}

local function initAllRemotes()
    pcall(function()
        -- TrainSystem remotes
        local tsRoot = ReplicatedStorage:FindFirstChild("TrainSystem")
        local tsRem  = tsRoot and tsRoot:FindFirstChild("Remote")
        if tsRem then
            Remotes.ApplyAddFrenzyValue  = tsRem:FindFirstChild("ApplyAddFrenzyValue")
            Remotes.TrainSpeedHasChanged = tsRem:FindFirstChild("TrainSpeedHasChanged")
        end
        -- TrainEquipment remotes
        local teRoot = ReplicatedStorage:FindFirstChild("TrainEquipment")
        local teRem  = teRoot and teRoot:FindFirstChild("Remote")
        if teRem then
            Remotes.ApplyMobileTrain     = teRem:FindFirstChild("ApplyMobileTrain")
            Remotes.ApplyStationaryTrain = teRem:FindFirstChild("ApplyStationaryTrain")
        end
        -- Chat remote
        local tc = ReplicatedStorage:FindFirstChild("TextChat")
        local tcRem = tc and tc:FindFirstChild("Remote")
        if tcRem then
            Remotes.SendTextChatMessage = tcRem:FindFirstChild("SendTextChatMessageToAllPlayer")
        end
        -- Ability remote
        local ab = ReplicatedStorage:FindFirstChild("Ability")
        local abRem = ab and ab:FindFirstChild("Remote")
        if abRem then
            Remotes.ApplyCastAbility = abRem:FindFirstChild("ApplyCastAbility")
        end
        -- Area remote
        local ar = ReplicatedStorage:FindFirstChild("Area")
        local arRem = ar and ar:FindFirstChild("Remote")
        if arRem then
            Remotes.PlayerAreaIn = arRem:FindFirstChild("PlayerAreaIn")
        end
    end)
end
initAllRemotes()

--==============================================================
-- REZURXSHIN ENGINE (15-line pump, math.huge → 1e9)
--==============================================================
local TRAIN_SPEED = 1e9

local function DoTrain()
    -- Smart re-init if any train remote went missing
    if not Remotes.ApplyAddFrenzyValue then initAllRemotes() end
    local r = Remotes
    if not r.ApplyAddFrenzyValue then return end
    -- 15-line RezurXshin pump (preserved)
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
-- CHAT (GHOST SHOUT)
--==============================================================
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

local function sendChatMessage(msg)
    if not Remotes.SendTextChatMessage then initAllRemotes() end
    if not Remotes.SendTextChatMessage or not msg or msg == "" then return end
    local full = buildChatMessage(msg)
    -- Try table format, fall back to plain string
    local ok1 = pcall(function() Remotes.SendTextChatMessage:InvokeServer({ Text = full }) end)
    if not ok1 then
        pcall(function() Remotes.SendTextChatMessage:InvokeServer(full) end)
    end
end

--==============================================================
-- UI CONSTRUCTION
--==============================================================
local Window = Rayfield:CreateWindow({
    Name              = "👑WELCOME DEVELOPER👑 | V1100🔥 POLISHED",
    LoadingTitle      = "Initializing Elite Developer Protocol...",
    LoadingSubtitle   = "V1100🔥 Polished Authority",
    ConfigurationSaving = { Enabled = false },
    Keybind = { Key = Enum.KeyCode.K, Mods = nil },
})

local function notify(title, content, duration)
    pcall(Rayfield.Notify, Rayfield, {
        Title = title, Content = content, Duration = duration or 5,
    })
end

--==============================================================
-- TAB 1: NEXUS IDENTITY
--==============================================================
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
IdTab:CreateButton({
    Name = "Preview Current Identity",
    Callback = function()
        local tag = Config.CustomTag ~= "" and ("[" .. Config.CustomTag .. "] ") or ""
        local usr = Config.UserName ~= "" and Config.UserName or "(default name)"
        notify("Identity Preview", tag .. usr .. " — message color set", 4)
    end,
})

--==============================================================
-- TAB 2: GHOST SHOUT
--==============================================================
local GlobalTab = Window:CreateTab("Ghost Shout", 4483362458)

GlobalTab:CreateInput({
    Name = "Send Shout (Box)",
    PlaceholderText = "Type message...",
    RemoveTextAfterFocusLost = true,
    Callback = function(msg) sendChatMessage(msg) end,
})
GlobalTab:CreateButton({
    Name = "Re-scan Chat Remote",
    Callback = function()
        initAllRemotes()
        notify("Chat Remote Status",
            Remotes.SendTextChatMessage and "Found ✅ — ready to send" or "Missing ❌ — check RS.TextChat.Remote",
            4)
    end,
})
GlobalTab:CreateButton({
    Name = "Send Plain-Text Test Shout",
    Callback = function()
        if not Remotes.SendTextChatMessage then initAllRemotes() end
        if not Remotes.SendTextChatMessage then
            notify("Chat Error", "Remote not found. Click Re-scan first.", 4)
            return
        end
        local ok = pcall(function() Remotes.SendTextChatMessage:InvokeServer("V1100 test ping") end)
        notify("Test Shout", ok and "Sent ✅" or "Failed ❌", 3)
    end,
})
GlobalTab:CreateButton({
    Name = "Send Full Rich-Text Test Shout",
    Callback = function()
        sendChatMessage("V1100 rich-text test")
        notify("Test Shout", "Rich-text attempt sent (check chat).", 3)
    end,
})

--==============================================================
-- TAB 3: OVERDRIVE FARM
--==============================================================
local FarmTab = Window:CreateTab("Overdrive Farm", 4483362458)

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

-- Heartbeat-based farm — smooth and fast
local farmConn
FarmTab:CreateToggle({
    Name = "RezurXshin Auto Train (Heartbeat)",
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
            while Config.RespectFarm do
                for _, v in ipairs(Players:GetPlayers()) do
                    if v ~= player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                        local myChar = player.Character
                        if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                            pcall(function()
                                myChar.HumanoidRootPart.CFrame =
                                    v.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                                if Remotes.ApplyCastAbility then
                                    Remotes.ApplyCastAbility:InvokeServer(v.Name, "1")
                                else
                                    initAllRemotes()
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

FarmTab:CreateButton({
    Name = "Force Re-scan Train Remotes",
    Callback = function()
        initAllRemotes()
        local status = string.format("Frenzy: %s | SpeedChange: %s | MobileTrain: %s | StationaryTrain: %s",
            Remotes.ApplyAddFrenzyValue and "✅" or "❌",
            Remotes.TrainSpeedHasChanged and "✅" or "❌",
            Remotes.ApplyMobileTrain and "✅" or "❌",
            Remotes.ApplyStationaryTrain and "✅" or "❌")
        notify("Train Remotes", status, 6)
    end,
})

--==============================================================
-- TAB 4: SPECTRAL SCAN
--==============================================================
local VisTab = Window:CreateTab("Spectral Scan", 4483362458)

VisTab:CreateDropdown({
    Name = "ESP Refresh Rate",
    Options = {"Fast (0.1s)", "Normal (0.3s)", "Slow (0.6s)"},
    CurrentOption = "Normal (0.3s)",
    Callback = function(v)
        local val = dropValue(v)
        if val:find("Fast") then Config.EspRefreshRate = 0.1
        elseif val:find("Slow") then Config.EspRefreshRate = 0.6
        else Config.EspRefreshRate = 0.3 end
    end,
})

local espCache = {}
local espConn

local function clearAllEspTags()
    if espConn then espConn:Disconnect() espConn = nil end
    for head, entry in pairs(espCache) do
        if entry.gui and entry.gui.Parent then entry.gui:Destroy() end
    end
    table.clear(espCache)
end

local function makeEspTag(head, name)
    local bb = Instance.new("BillboardGui")
    bb.Name          = "RezurTag"
    bb.Adornee       = head
    bb.Size          = UDim2.new(0, 100, 0, 30)
    bb.StudsOffset   = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop   = true
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
        if not t then clearAllEspTags() return end
        task.spawn(function()
            while Config.EspEnabled do
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
                                local power = getPower(pMod.Name)
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
                    -- Remove stale tags
                    for head, entry in pairs(espCache) do
                        if not seen[head] or not head.Parent then
                            if entry.gui then entry.gui:Destroy() end
                            espCache[head] = nil
                        end
                    end
                end)
                task.wait(Config.EspRefreshRate)
            end
        end)
    end,
})

VisTab:CreateButton({
    Name = "Force Clear All ESP Tags",
    Callback = function() clearAllEspTags() notify("ESP", "All tags cleared.", 3) end,
})

--==============================================================
-- TAB 5: PHYSICAL OVERRIDE
--==============================================================
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
LocalTab:CreateButton({
    Name = "Reset to Default (16 / 50)",
    Callback = function()
        Config.WalkSpeed = 16
        Config.JumpPower = 50
        restoreMovement()
        notify("Movement", "Reset to default 16/50.", 3)
    end,
})

-- Heartbeat re-apply only when OverrideStats on AND values drifted
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

--==============================================================
-- TAB 6: DARK EXPERIMENTS
--==============================================================
local ExpTab = Window:CreateTab("Dark Experiments", 4483362458)

ExpTab:CreateToggle({
    Name = "Turn Off PVP",
    CurrentValue = false,
    Callback = function(t) Config.PvpOff = t end,
})

ExpTab:CreateDropdown({
    Name = "Noclip Update Rate",
    Options = {"Smooth (Stepped)", "Aggressive (Heartbeat)"},
    CurrentOption = "Smooth (Stepped)",
    Callback = function(v)
        Config.NoclipRate = dropValue(v):find("Smooth") and "Smooth" or "Aggressive"
        -- If noclip is currently on, restart with new rate
        if Config.Noclip then
            setNoclip(false)
            task.wait(0.05)
            setNoclip(true)
        end
    end,
})

-- Noclip — proper lifecycle, smart update rate
local noclipConn
function setNoclip(enabled)
    Config.Noclip = enabled
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if enabled then
        local signal = Config.NoclipRate == "Aggressive" and RunService.Heartbeat or RunService.Stepped
        noclipConn = signal:Connect(function()
            local char = player.Character
            if not char then return end
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") and v.CanCollide then
                    v.CanCollide = false
                end
            end
        end)
    else
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

ExpTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = true,
    Callback = function(t) Config.AntiAfk = t end,
})

--==============================================================
-- TAB 7: STATUS DASHBOARD
--==============================================================
local StatusTab = Window:CreateTab("Status Dashboard", 4483362458)

StatusTab:CreateButton({
    Name = "Show Full Remote Status",
    Callback = function()
        initAllRemotes()
        local report = string.format(
            "TRAIN:\n  Frenzy: %s\n  SpeedChange: %s\n  MobileTrain: %s\n  StationaryTrain: %s\n\n" ..
            "CHAT:\n  SendTextChat: %s\n\n" ..
            "COMBAT:\n  ApplyCastAbility: %s\n\n" ..
            "AREA:\n  PlayerAreaIn: %s",
            Remotes.ApplyAddFrenzyValue and "✅" or "❌",
            Remotes.TrainSpeedHasChanged and "✅" or "❌",
            Remotes.ApplyMobileTrain and "✅" or "❌",
            Remotes.ApplyStationaryTrain and "✅" or "❌",
            Remotes.SendTextChatMessage and "✅" or "❌",
            Remotes.ApplyCastAbility and "✅" or "❌",
            Remotes.PlayerAreaIn and "✅" or "❌"
        )
        notify("Remote Status", report, 12)
    end,
})

-- Live FPS + player count display (defensive — falls back if CreateParagraph missing)
local liveLabel
local ok = pcall(function()
    liveLabel = StatusTab:CreateParagraph({ Title = "Live Stats", Content = "Loading..." })
end)
if not ok or not liveLabel then
    -- Fallback: use a regular label
    liveLabel = StatusTab:CreateLabel("Live Stats: Loading...")
end

task.spawn(function()
    while task.wait(1) do
        local fps = math.floor(1 / RunService.Heartbeat:Wait())
        local players = #Players:GetPlayers()
        local trainActive = Config.FarmEnabled and "ON" or "OFF"
        local espActive = Config.EspEnabled and "ON" or "OFF"
        local noclipActive = Config.Noclip and "ON" or "OFF"
        local content = string.format(
            "FPS: %d | Players: %d | Train: %s (%s @ %sx) | ESP: %s | Noclip: %s (%s) | AntiAfk: %s",
            fps, players,
            trainActive, Config.FarmMode, Config.FarmSpeedMul,
            espActive,
            noclipActive, Config.NoclipRate,
            Config.AntiAfk and "ON" or "OFF"
        )
        pcall(function()
            if liveLabel.Set then
                liveLabel:Set({ Content = content })
            elseif liveLabel.set then
                liveLabel:set({ Content = content })
            end
        end)
    end
end)

StatusTab:CreateButton({
    Name = "Force Re-init ALL Remotes",
    Callback = function()
        initAllRemotes()
        notify("Remotes", "All remotes re-scanned.", 3)
    end,
})

StatusTab:CreateButton({
    Name = "Destroy UI",
    Callback = function() Rayfield:Destroy() end,
})

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
                if s2 and Remotes.PlayerAreaIn then
                    Remotes.PlayerAreaIn:InvokeServer(s2)
                elseif not Remotes.PlayerAreaIn then
                    initAllRemotes()
                end
            end)
        end
    end
end)

-- Anti-AFK
player.Idled:Connect(function()
    if not Config.AntiAfk then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

--==============================================================
-- BOOT NOTIFY
--==============================================================
notify("👑WELCOME DEVELOPER👑", "V1100🔥 Polished loaded. Press K to toggle UI.", 6)
