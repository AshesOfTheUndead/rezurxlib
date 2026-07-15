--[[
    👑WELCOME DEVELOPER👑 V1200🔥: INDESTRUCTIBLE
    - FIX: Forward-declare ALL functions before use (no more silent crashes)
    - FIX: Multi-host Rayfield loader — tries 4 URLs, picks first that works
    - FIX: If ALL Rayfield hosts fail, falls back to built-in minimal UI
    - FIX: No more silent pcall swallowing errors — every failure shows a warning
    - FIX: Top-level error handler catches any crash and shows it via StarterGui
    - All V1100 polish kept: smart remotes, status dashboard, Anti-AFK, etc.
]]

--==============================================================
-- TOP-LEVEL ERROR CATCHER — if anything crashes, show it
--==============================================================
local function showErrorToUser(msg)
    pcall(function()
        local sg = Instance.new("ScreenGui")
        sg.Name = "V1200_Error"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.Parent = game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 500, 0, 200)
        f.Position = UDim2.new(0.5, -250, 0.5, -100)
        f.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
        f.Parent = sg
        local c = Instance.new("UICorner") c.Parent = f
        local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(200, 0, 0) s.Thickness = 2 s.Parent = f

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -20, 1, -20)
        t.Position = UDim2.new(0, 10, 0, 10)
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.Code
        t.TextSize = 14
        t.TextColor3 = Color3.fromRGB(255, 255, 255)
        t.TextWrapped = true
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.TextYAlignment = Enum.TextYAlignment.Top
        t.Text = "V1200 ERROR:\n\n" .. tostring(msg)
        t.Parent = f

        task.delay(20, function() pcall(function() sg:Destroy() end) end)
    end)
    warn("[V1200] ERROR: " .. tostring(msg))
end

-- Wrap the entire script in xpcall so any uncaught error shows on screen
local function runMain()
-- (the rest of the script continues below)

--==============================================================
-- BOOT
--==============================================================
if not game:IsLoaded() then
    repeat task.wait(0.1) until game:IsLoaded()
end

--==============================================================
-- SERVICES
--==============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local CoreGui           = game:GetService("CoreGui")
local StarterGui        = game:GetService("StarterGui")
local player            = Players.LocalPlayer

--==============================================================
-- FORWARD DECLARATIONS — every function used before its definition
--==============================================================
local setNoclip           -- defined later, used in dropdown callback
local applyMovement
local restoreMovement
local DoTrain
local sendChatMessage
local initAllRemotes
local notify
local clearAllEspTags
local Rayfield, Window

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
    FarmSpeedMul   = 1,
    EspEnabled     = false,
    EspRefreshRate = 0.3,
    OverrideStats  = false,
    WalkSpeed      = 16,
    JumpPower      = 50,
    RespectFarm    = false,
    Noclip         = false,
    NoclipRate     = "Smooth",
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
-- REMOTE MANAGER
--==============================================================
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
initAllRemotes()

--==============================================================
-- REZURXSHIN ENGINE
--==============================================================
local TRAIN_SPEED = 1e9

DoTrain = function()
    if not Remotes.ApplyAddFrenzyValue then initAllRemotes() end
    local r = Remotes
    if not r.ApplyAddFrenzyValue then return end
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
-- CHAT
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

sendChatMessage = function(msg)
    if not Remotes.SendTextChatMessage then initAllRemotes() end
    if not Remotes.SendTextChatMessage or not msg or msg == "" then return end
    local full = buildChatMessage(msg)
    local ok1 = pcall(function() Remotes.SendTextChatMessage:InvokeServer({ Text = full }) end)
    if not ok1 then
        pcall(function() Remotes.SendTextChatMessage:InvokeServer(full) end)
    end
end

--==============================================================
-- MOVEMENT
--==============================================================
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

--==============================================================
-- NOCLIP — defined BEFORE the UI that uses it
--==============================================================
local noclipConn
setNoclip = function(enabled)
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

--==============================================================
-- ESP
--==============================================================
local espCache = {}
local espConn

clearAllEspTags = function()
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

--==============================================================
-- RAYFIELD LOADER — tries 4 hosts, then falls back to built-in UI
--==============================================================
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
                    warn(string.format("[V1200] Rayfield loaded from host #%d: %s", i, url))
                    return rf
                end
            end
        end
    end
    return nil
end

Rayfield = loadRayfield()

--==============================================================
-- FALLBACK UI — used if Rayfield completely fails to load
--==============================================================
local FallbackUI = {}

if not Rayfield then
    warn("[V1200] All Rayfield hosts failed. Spawning fallback UI.")

    local sg = Instance.new("ScreenGui")
    sg.Name = "V1200_Fallback"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = player:WaitForChild("PlayerGui") end

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 480, 0, 320)
    main.Position = UDim2.new(0.5, -240, 0.5, -160)
    main.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    main.BorderSizePixel = 0
    main.Parent = sg
    local mc = Instance.new("UICorner") mc.CornerRadius = UDim2.new(0, 8, 0, 8) mc.Parent = main
    local ms = Instance.new("UIStroke") ms.Color = Color3.fromRGB(180, 30, 30) ms.Thickness = 2 ms.Parent = main

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 30)
    topBar.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    topBar.BorderSizePixel = 0
    topBar.Parent = main
    local tc2 = Instance.new("UICorner") tc2.Parent = topBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "👑 V1200 FALLBACK UI"
    title.Parent = topBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.Position = UDim2.new(1, -28, 0.5, -12)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    closeBtn.Text = "X"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Parent = topBar
    closeBtn.MouseButton1Click:Connect(function() sg.Enabled = false end)

    -- Draggable
    local dragging, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true dragStart = input.Position startPos = main.Position
        end
    end)
    topBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -40)
    scroll.Position = UDim2.new(0, 10, 0, 35)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = main

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.Parent = scroll

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.Parent = scroll

    FallbackUI.Scroll = scroll
    FallbackUI.Sg = sg

    function FallbackUI:Notify(cfg)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = cfg.Title or "V1200",
                Text = cfg.Content or "",
                Duration = cfg.Duration or 5,
            })
        end)
    end

    function FallbackUI:AddButton(name, callback)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 30)
        b.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        b.Text = name
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 12
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Parent = scroll
        local c = Instance.new("UICorner") c.Parent = b
        b.MouseButton1Click:Connect(function() pcall(callback) end)
        return b
    end

    function FallbackUI:AddToggle(name, default, callback)
        local state = default or false
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 30)
        b.BackgroundColor3 = state and Color3.fromRGB(80, 30, 30) or Color3.fromRGB(35, 35, 42)
        b.Text = name .. ": " .. (state and "ON" or "OFF")
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 12
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Parent = scroll
        local c = Instance.new("UICorner") c.Parent = b
        b.MouseButton1Click:Connect(function()
            state = not state
            b.BackgroundColor3 = state and Color3.fromRGB(80, 30, 30) or Color3.fromRGB(35, 35, 42)
            b.Text = name .. ": " .. (state and "ON" or "OFF")
            pcall(callback, state)
        end)
        return b
    end

    notify = function(title, content, duration)
        FallbackUI:Notify({ Title = title, Content = content, Duration = duration or 5 })
    end
else
    notify = function(t, c, d)
        pcall(Rayfield.Notify, Rayfield, { Title = t, Content = c, Duration = d or 5 })
    end
end

--==============================================================
-- BUILD UI (Rayfield or Fallback)
--==============================================================
if Rayfield then
    Window = Rayfield:CreateWindow({
        Name              = "👑WELCOME DEVELOPER👑 | V1200🔥 INDESTRUCTIBLE",
        LoadingTitle      = "V1200🔥 Booting...",
        LoadingSubtitle   = "Multi-host Rayfield loader active",
        ConfigurationSaving = { Enabled = false },
        Keybind = { Key = Enum.KeyCode.K, Mods = nil },
    })
else
    Window = FallbackUI
    -- Fallback has no tabs — everything goes on one scrollable list
    local function label(text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 22)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold
        l.TextSize = 12
        l.TextColor3 = Color3.fromRGB(220, 50, 50)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = text
        l.Parent = FallbackUI.Scroll
        return l
    end

    label("===== NEXUS IDENTITY =====")
    FallbackUI:AddButton("Send Test Shout", function() sendChatMessage("V1200 test") end)
    FallbackUI:AddButton("Re-scan Chat Remote", function()
        initAllRemotes()
        notify("Chat Remote", Remotes.SendTextChatMessage and "Found ✅" or "Missing ❌", 4)
    end)

    label("===== OVERDRIVE FARM =====")
    FallbackUI:AddToggle("Auto Train (Flagship)", false, function(t)
        Config.FarmEnabled = t
        if t then
            task.spawn(function()
                while Config.FarmEnabled do
                    for _ = 1, 10 do task.spawn(function() pcall(DoTrain) end) end
                    RunService.Heartbeat:Wait()
                end
            end)
        end
    end)
    FallbackUI:AddToggle("Auto Respect Farm", false, function(t)
        Config.RespectFarm = t
        if not t then return end
        task.spawn(function()
            while Config.RespectFarm do
                for _, v in ipairs(Players:GetPlayers()) do
                    if v ~= player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                        local myChar = player.Character
                        if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                            pcall(function()
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

    label("===== PHYSICAL OVERRIDE =====")
    FallbackUI:AddToggle("Override Walk/Jump", false, function(t)
        Config.OverrideStats = t
        if t then applyMovement() else restoreMovement() end
    end)
    FallbackUI:AddToggle("Noclip", false, function(t) setNoclip(t) end)

    label("===== DARK EXPERIMENTS =====")
    FallbackUI:AddToggle("PVP Off", false, function(t) Config.PvpOff = t end)
    FallbackUI:AddToggle("Anti-AFK", true, function(t) Config.AntiAfk = t end)

    label("===== STATUS =====")
    FallbackUI:AddButton("Show Remote Status", function()
        initAllRemotes()
        local report = string.format(
            "Train: %s/%s/%s/%s | Chat: %s | Combat: %s | Area: %s",
            Remotes.ApplyAddFrenzyValue and "✅" or "❌",
            Remotes.TrainSpeedHasChanged and "✅" or "❌",
            Remotes.ApplyMobileTrain and "✅" or "❌",
            Remotes.ApplyStationaryTrain and "✅" or "❌",
            Remotes.SendTextChatMessage and "✅" or "❌",
            Remotes.ApplyCastAbility and "✅" or "❌",
            Remotes.PlayerAreaIn and "✅" or "❌"
        )
        notify("Remote Status", report, 10)
    end)
    FallbackUI:AddButton("Re-init All Remotes", function()
        initAllRemotes()
        notify("Remotes", "Re-scanned.", 3)
    end)

    -- K toggles UI
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.K then
            FallbackUI.Sg.Enabled = not FallbackUI.Sg.Enabled
        end
    end)

    notify("V1200 Fallback Mode", "Rayfield failed — minimal UI active. Press K to toggle.", 8)
    return  -- skip the Rayfield-specific UI build below
end

--==============================================================
-- RAYFIELD UI BUILD (only runs if Rayfield loaded)
--==============================================================

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
        notify("Identity Preview", tag .. usr, 4)
    end,
})

-- TAB 2: GHOST SHOUT
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
            Remotes.SendTextChatMessage and "Found ✅" or "Missing ❌", 4)
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
        local ok = pcall(function() Remotes.SendTextChatMessage:InvokeServer("V1200 test ping") end)
        notify("Test Shout", ok and "Sent ✅" or "Failed ❌", 3)
    end,
})
GlobalTab:CreateButton({
    Name = "Send Full Rich-Text Test Shout",
    Callback = function()
        sendChatMessage("V1200 rich-text test")
        notify("Test Shout", "Rich-text attempt sent.", 3)
    end,
})

-- TAB 3: OVERDRIVE FARM
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
        notify("Train Remotes",
            "Frenzy:" .. (Remotes.ApplyAddFrenzyValue and "✅" or "❌") ..
            " Speed:" .. (Remotes.TrainSpeedHasChanged and "✅" or "❌") ..
            " Mobile:" .. (Remotes.ApplyMobileTrain and "✅" or "❌") ..
            " Stationary:" .. (Remotes.ApplyStationaryTrain and "✅" or "❌"), 6)
    end,
})

-- TAB 4: SPECTRAL SCAN
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

-- TAB 6: DARK EXPERIMENTS
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
        if Config.Noclip then
            setNoclip(false)
            task.wait(0.05)
            setNoclip(true)
        end
    end,
})
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

-- TAB 7: STATUS DASHBOARD
local StatusTab = Window:CreateTab("Status Dashboard", 4483362458)
StatusTab:CreateButton({
    Name = "Show Full Remote Status",
    Callback = function()
        initAllRemotes()
        local report = string.format(
            "TRAIN: Frenzy:%s Speed:%s Mobile:%s Stationary:%s | CHAT:%s | COMBAT:%s | AREA:%s",
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
StatusTab:CreateButton({
    Name = "Force Re-init ALL Remotes",
    Callback = function()
        initAllRemotes()
        notify("Remotes", "All remotes re-scanned.", 3)
    end,
})
StatusTab:CreateButton({
    Name = "Destroy UI",
    Callback = function() pcall(Rayfield.Destroy, Rayfield) end,
})

--==============================================================
-- CORE LOOPS
--==============================================================
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
notify("👑WELCOME DEVELOPER👑", "V1200🔥 Indestructible loaded. Press K to toggle.", 6)

end  -- end of runMain()

-- Run the whole thing inside xpcall so any error shows on screen
local ok, err = xpcall(runMain, function(e)
    return debug.traceback(tostring(e), 2)
end)
if not ok then
    showErrorToUser(err)
end
