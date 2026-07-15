--[[
    👑WELCOME DEVELOPER👑 V1000🔥: SOVEREIGN
    - 100% CUSTOM GUI — no Rayfield, no external loaders, no dependencies
    - Cherry-picked from V777: game:IsLoaded() wait, compact Config, original 15-line pump
    - Cherry-picked from V999: math.huge → 1e9, pcall everywhere, fixed Noclip lifecycle,
      Heartbeat-based farm, cached ESP, Anti-AFK, dropdown string/table safety
    - New: Custom draggable window, smooth TweenService animations, K to toggle,
      minimize button, notification stack, RGB color picker, dropdown with animation
    - 7 tabs: Nexus Identity / Ghost Shout / Overdrive Farm / Spectral Scan /
              Physical Override / Dark Experiments / System
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
local TweenService      = game:GetService("TweenService")
local VirtualUser       = game:GetService("VirtualUser")
local CoreGui           = game:GetService("CoreGui")
local player            = Players.LocalPlayer

--==============================================================
-- THEME
--==============================================================
local Theme = {
    Bg           = Color3.fromRGB(18, 18, 22),
    TopBar       = Color3.fromRGB(28, 28, 34),
    Sidebar      = Color3.fromRGB(24, 24, 28),
    TabInactive  = Color3.fromRGB(35, 35, 42),
    TabHover     = Color3.fromRGB(48, 48, 56),
    TabActive    = Color3.fromRGB(128, 0, 0),
    Element      = Color3.fromRGB(32, 32, 38),
    ElementHov   = Color3.fromRGB(42, 42, 50),
    Accent       = Color3.fromRGB(180, 30, 30),
    AccentBright = Color3.fromRGB(220, 50, 50),
    Text         = Color3.fromRGB(255, 255, 255),
    TextDim      = Color3.fromRGB(170, 170, 180),
    Track        = Color3.fromRGB(50, 50, 60),
    TrackActive  = Color3.fromRGB(180, 30, 30),
    Success      = Color3.fromRGB(80, 200, 120),
    Danger       = Color3.fromRGB(220, 60, 60),
    Stroke       = Color3.fromRGB(0, 0, 0),
    StrokeLight  = Color3.fromRGB(50, 50, 60),
}

--==============================================================
-- CONFIG
--==============================================================
local Config = {
    CustomTag     = "",
    UserName      = "",
    TagColor      = Color3.fromRGB(128, 0, 0),
    UserColor     = Color3.fromRGB(255, 255, 255),
    MessageColor  = Color3.fromRGB(255, 255, 255),
    FarmMode      = "Flagship (S22 Ultra)",
    FarmEnabled   = false,
    FarmSpeedMul  = 1,
    EspEnabled    = false,
    OverrideStats = false,
    WalkSpeed     = 16,
    JumpPower     = 50,
    RespectFarm   = false,
    Noclip        = false,
    AntiSlow      = false,
    PvpOff        = false,
    AntiAfk       = true,
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

local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = radius or UDim2.new(0, 6, 0, 6)
    c.Parent = parent
    return c
end

local function makeStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = thickness or 1
    s.Parent = parent
    return s
end

--==============================================================
-- REZURXSHIN ENGINE (15-line pump, math.huge → 1e9)
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
    if not TrainRemotes.ApplyAddFrenzyValue then initTrainRemotes() end
    local r = TrainRemotes
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
-- CHAT (GHOST SHOUT)
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
    if not ChatRemote then initChatRemote() end
    if not ChatRemote or not msg or msg == "" then return end
    local full = buildChatMessage(msg)
    local ok1 = pcall(function() ChatRemote:InvokeServer({ Text = full }) end)
    if not ok1 then
        pcall(function() ChatRemote:InvokeServer(full) end)
    end
end

--==============================================================
-- CUSTOM UI LIBRARY
--==============================================================
local CustomUI = {}

function CustomUI:CreateWindow(config)
    local window = {}
    window.Tabs = {}
    window.ActiveTab = nil

    -- ScreenGui
    local sg = Instance.new("ScreenGui")
    sg.Name = "V1000_GUI"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = player:WaitForChild("PlayerGui") end
    window.ScreenGui = sg

    -- Main frame
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 620, 0, 420)
    main.Position = UDim2.new(0.5, -310, 0.5, -210)
    main.BackgroundColor3 = Theme.Bg
    main.BorderSizePixel = 0
    main.Parent = sg
    makeCorner(main, UDim2.new(0, 8, 0, 8))
    makeStroke(main, Theme.StrokeLight, 1)
    window.Main = main

    -- Top bar
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 36)
    topBar.BackgroundColor3 = Theme.TopBar
    topBar.BorderSizePixel = 0
    topBar.Parent = main
    makeCorner(topBar, UDim2.new(0, 8, 0, 8))
    window.TopBar = topBar

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -120, 1, 0)
    title.Position = UDim2.new(0, 14, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Theme.Text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = config.Name or "Custom UI"
    title.Parent = topBar

    -- Minimize button
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 30, 0, 28)
    minBtn.Position = UDim2.new(1, -70, 0, 4)
    minBtn.BackgroundColor3 = Theme.Element
    minBtn.Text = "—"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 16
    minBtn.TextColor3 = Theme.Text
    minBtn.Parent = topBar
    makeCorner(minBtn)

    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        local targetSize = minimized and UDim2.new(0, 620, 0, 36) or UDim2.new(0, 620, 0, 420)
        TweenService:Create(main, TweenInfo.new(0.2), {Size = targetSize}):Play()
        if window.Sidebar then window.Sidebar.Visible = not minimized end
        if window.Content then window.Content.Visible = not minimized end
    end)

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 28)
    closeBtn.Position = UDim2.new(1, -36, 0, 4)
    closeBtn.BackgroundColor3 = Theme.Danger
    closeBtn.Text = "X"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Theme.Text
    closeBtn.Parent = topBar
    makeCorner(closeBtn)
    closeBtn.MouseButton1Click:Connect(function() sg.Enabled = false end)

    -- Dragging
    local dragging, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    topBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                         or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                       startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 140, 1, -42)
    sidebar.Position = UDim2.new(0, 0, 0, 38)
    sidebar.BackgroundColor3 = Theme.Sidebar
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main
    window.Sidebar = sidebar

    local sbLayout = Instance.new("UIListLayout")
    sbLayout.Padding = UDim.new(0, 3)
    sbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sbLayout.Parent = sidebar

    local sbPad = Instance.new("UIPadding")
    sbPad.PaddingTop = UDim.new(0, 6)
    sbPad.Parent = sidebar

    -- Content area
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -150, 1, -46)
    content.Position = UDim2.new(0, 145, 0, 41)
    content.BackgroundTransparency = 1
    content.Parent = main
    window.Content = content

    -- Notification container
    local notifContainer = Instance.new("Frame")
    notifContainer.Size = UDim2.new(0, 280, 1, -20)
    notifContainer.Position = UDim2.new(1, -290, 0, 10)
    notifContainer.BackgroundTransparency = 1
    notifContainer.Parent = sg
    window.NotifContainer = notifContainer

    local nLayout = Instance.new("UIListLayout")
    nLayout.Padding = UDim.new(0, 6)
    nLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    nLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    nLayout.Parent = notifContainer

    --==============================================================
    -- WINDOW METHODS
    --==============================================================
    function window:CreateTab(name)
        local tab = {}

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 130, 0, 30)
        btn.BackgroundColor3 = Theme.TabInactive
        btn.Text = name
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 12
        btn.TextColor3 = Theme.TextDim
        btn.AutoButtonColor = false
        btn.Parent = sidebar
        makeCorner(btn, UDim2.new(0, 5, 0, 5))

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = Theme.Accent
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

        tab.Page = page
        tab.Btn = btn
        tab.Name = name

        btn.MouseEnter:Connect(function()
            if window.ActiveTab ~= tab then
                TweenService:Create(btn, TweenInfo.new(0.15),
                    {BackgroundColor3 = Theme.TabHover, TextColor3 = Theme.Text}):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if window.ActiveTab ~= tab then
                TweenService:Create(btn, TweenInfo.new(0.15),
                    {BackgroundColor3 = Theme.TabInactive, TextColor3 = Theme.TextDim}):Play()
            end
        end)
        btn.MouseButton1Click:Connect(function() window:SelectTab(tab) end)

        table.insert(window.Tabs, tab)
        if #window.Tabs == 1 then window:SelectTab(tab) end

        --==========================================================
        -- TAB METHODS — Element creation
        --==========================================================

        function tab:CreateLabel(text)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 22)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 13
            lbl.TextColor3 = Theme.AccentBright
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = text or ""
            lbl.Parent = page
            return lbl
        end

        function tab:CreateButton(cfg)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 36)
            btn.BackgroundColor3 = Theme.Element
            btn.Text = cfg.Name or "Button"
            btn.Font = Enum.Font.GothamMedium
            btn.TextSize = 13
            btn.TextColor3 = Theme.Text
            btn.AutoButtonColor = false
            btn.Parent = page
            makeCorner(btn)

            btn.MouseEnter:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.15),
                    {BackgroundColor3 = Theme.ElementHov}):Play()
            end)
            btn.MouseLeave:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.15),
                    {BackgroundColor3 = Theme.Element}):Play()
            end)
            btn.MouseButton1Click:Connect(function()
                if cfg.Callback then
                    local ok, err = pcall(cfg.Callback)
                    if not ok then warn("[V1000 Button] " .. tostring(err)) end
                end
            end)
            return btn
        end

        function tab:CreateToggle(cfg)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 36)
            holder.BackgroundColor3 = Theme.Element
            holder.Parent = page
            makeCorner(holder)

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -60, 1, 0)
            label.Position = UDim2.new(0, 12, 0, 0)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamMedium
            label.TextSize = 13
            label.TextColor3 = Theme.Text
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Text = cfg.Name or "Toggle"
            label.Parent = holder

            local switch = Instance.new("Frame")
            switch.Size = UDim2.new(0, 40, 0, 20)
            switch.Position = UDim2.new(1, -50, 0.5, -10)
            switch.BackgroundColor3 = Theme.Track
            switch.Parent = holder
            makeCorner(switch, UDim2.new(1, 0, 1, 0))

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 16, 0, 16)
            knob.Position = UDim2.new(0, 2, 0.5, -8)
            knob.BackgroundColor3 = Theme.Text
            knob.Parent = switch
            makeCorner(knob, UDim2.new(1, 0, 1, 0))

            local state = cfg.CurrentValue or false

            local function update()
                if state then
                    TweenService:Create(switch, TweenInfo.new(0.15),
                        {BackgroundColor3 = Theme.Accent}):Play()
                    TweenService:Create(knob, TweenInfo.new(0.15),
                        {Position = UDim2.new(1, -18, 0.5, -8)}):Play()
                else
                    TweenService:Create(switch, TweenInfo.new(0.15),
                        {BackgroundColor3 = Theme.Track}):Play()
                    TweenService:Create(knob, TweenInfo.new(0.15),
                        {Position = UDim2.new(0, 2, 0.5, -8)}):Play()
                end
            end
            update()

            local toggleObj = {}
            function toggleObj:Set(v)
                state = v
                update()
                if cfg.Callback then cfg.Callback(state) end
            end
            function toggleObj:Get() return state end

            holder.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                   or input.UserInputType == Enum.UserInputType.Touch then
                    state = not state
                    update()
                    if cfg.Callback then cfg.Callback(state) end
                end
            end)

            return toggleObj
        end

        function tab:CreateSlider(cfg)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 44)
            holder.BackgroundColor3 = Theme.Element
            holder.Parent = page
            makeCorner(holder)

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -80, 0, 18)
            label.Position = UDim2.new(0, 12, 0, 4)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamMedium
            label.TextSize = 13
            label.TextColor3 = Theme.Text
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Text = cfg.Name or "Slider"
            label.Parent = holder

            local valueLabel = Instance.new("TextLabel")
            valueLabel.Size = UDim2.new(0, 60, 0, 18)
            valueLabel.Position = UDim2.new(1, -70, 0, 4)
            valueLabel.BackgroundTransparency = 1
            valueLabel.Font = Enum.Font.GothamBold
            valueLabel.TextSize = 12
            valueLabel.TextColor3 = Theme.AccentBright
            valueLabel.TextXAlignment = Enum.TextXAlignment.Right
            valueLabel.Parent = holder

            local track = Instance.new("Frame")
            track.Size = UDim2.new(1, -24, 0, 6)
            track.Position = UDim2.new(0, 12, 0, 30)
            track.BackgroundColor3 = Theme.Track
            track.Parent = holder
            makeCorner(track, UDim2.new(1, 0, 1, 0))

            local fill = Instance.new("Frame")
            fill.Size = UDim2.new(0, 0, 1, 0)
            fill.BackgroundColor3 = Theme.Accent
            fill.Parent = track
            makeCorner(fill, UDim2.new(1, 0, 1, 0))

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 14, 0, 14)
            knob.Position = UDim2.new(0, -7, 0.5, -7)
            knob.BackgroundColor3 = Theme.Text
            knob.Parent = track
            makeCorner(knob, UDim2.new(1, 0, 1, 0))

            local minVal = cfg.Range and cfg.Range[1] or 0
            local maxVal = cfg.Range and cfg.Range[2] or 100
            local suffix = cfg.Suffix or ""
            local value = cfg.CurrentValue or minVal

            local function update()
                local pct = (value - minVal) / (maxVal - minVal)
                pct = math.clamp(pct, 0, 1)
                fill.Size = UDim2.new(pct, 0, 1, 0)
                knob.Position = UDim2.new(pct, -7, 0.5, -7)
                valueLabel.Text = string.format("%d%s", value, suffix)
            end
            update()

            local sliderObj = {}
            function sliderObj:Set(v)
                value = math.clamp(v, minVal, maxVal)
                update()
                if cfg.Callback then cfg.Callback(value) end
            end
            function sliderObj:Get() return value end

            local dragging = false
            local function setFromX(x)
                local rel = track.AbsolutePosition
                local size = track.AbsoluteSize.X
                local pct = math.clamp((x - rel.X) / size, 0, 1)
                value = math.floor(minVal + pct * (maxVal - minVal) + 0.5)
                update()
                if cfg.Callback then cfg.Callback(value) end
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

            return sliderObj
        end

        function tab:CreateInput(cfg)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 40)
            holder.BackgroundColor3 = Theme.Element
            holder.Parent = page
            makeCorner(holder)

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -16, 0, 14)
            label.Position = UDim2.new(0, 12, 0, 4)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamMedium
            label.TextSize = 11
            label.TextColor3 = Theme.TextDim
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Text = cfg.Name or "Input"
            label.Parent = holder

            local box = Instance.new("TextBox")
            box.Size = UDim2.new(1, -24, 0, 16)
            box.Position = UDim2.new(0, 12, 0, 20)
            box.BackgroundTransparency = 1
            box.Font = Enum.Font.Gotham
            box.TextSize = 13
            box.TextColor3 = Theme.Text
            box.PlaceholderColor3 = Theme.TextDim
            box.PlaceholderText = cfg.PlaceholderText or ""
            box.Text = ""
            box.TextXAlignment = Enum.TextXAlignment.Left
            box.ClearTextOnFocus = false
            box.Parent = holder

            box.FocusLost:Connect(function(enterPressed)
                if cfg.Callback then cfg.Callback(box.Text) end
                if cfg.RemoveTextAfterFocusLost then box.Text = "" end
            end)

            return box
        end

        function tab:CreateDropdown(cfg)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 36)
            holder.BackgroundColor3 = Theme.Element
            holder.Parent = page
            makeCorner(holder)
            holder.ZIndex = 2

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -30, 1, 0)
            label.Position = UDim2.new(0, 12, 0, 0)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamMedium
            label.TextSize = 13
            label.TextColor3 = Theme.Text
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Text = cfg.Name or "Dropdown"
            label.Parent = holder

            local arrow = Instance.new("TextLabel")
            arrow.Size = UDim2.new(0, 20, 1, 0)
            arrow.Position = UDim2.new(1, -24, 0, 0)
            arrow.BackgroundTransparency = 1
            arrow.Font = Enum.Font.GothamBold
            arrow.TextSize = 14
            arrow.TextColor3 = Theme.TextDim
            arrow.Text = "▼"
            arrow.Parent = holder

            local dropdownObj = { Selected = dropValue(cfg.CurrentOption) }
            local list = nil

            local function closeList()
                if list then list:Destroy() list = nil arrow.Text = "▼" end
            end

            local function openList()
                if list then closeList() return end
                arrow.Text = "▲"
                list = Instance.new("Frame")
                list.Size = UDim2.new(1, 0, 0, #cfg.Options * 28)
                list.Position = UDim2.new(0, 0, 1, 4)
                list.BackgroundColor3 = Theme.Element
                list.ZIndex = 10
                list.Parent = holder
                makeCorner(list)
                makeStroke(list, Theme.StrokeLight, 1)

                local lLayout = Instance.new("UIListLayout")
                lLayout.Padding = UDim.new(0, 2)
                lLayout.Parent = list

                for _, opt in ipairs(cfg.Options) do
                    local item = Instance.new("TextButton")
                    item.Size = UDim2.new(1, -8, 0, 26)
                    item.BackgroundColor3 = Theme.ElementHov
                    item.Text = opt
                    item.Font = Enum.Font.Gotham
                    item.TextSize = 12
                    item.TextColor3 = Theme.Text
                    item.TextXAlignment = Enum.TextXAlignment.Left
                    item.AutoButtonColor = false
                    item.Parent = list
                    makeCorner(item)

                    item.MouseEnter:Connect(function()
                        TweenService:Create(item, TweenInfo.new(0.1),
                            {BackgroundColor3 = Theme.Accent}):Play()
                    end)
                    item.MouseLeave:Connect(function()
                        TweenService:Create(item, TweenInfo.new(0.1),
                            {BackgroundColor3 = Theme.ElementHov}):Play()
                    end)
                    item.MouseButton1Click:Connect(function()
                        dropdownObj.Selected = opt
                        label.Text = (cfg.Name or "Dropdown") .. ": " .. opt
                        closeList()
                        if cfg.Callback then cfg.Callback(opt) end
                    end)
                end
            end

            holder.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                   or input.UserInputType == Enum.UserInputType.Touch then
                    openList()
                end
            end)

            -- Click-outside to close
            UserInputService.InputBegan:Connect(function(input)
                if list and input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local mpos = UserInputService:GetMouseLocation()
                    local listPos = list.AbsolutePosition
                    local listSize = list.AbsoluteSize
                    if mpos.X < listPos.X or mpos.X > listPos.X + listSize.X
                       or mpos.Y < listPos.Y or mpos.Y > listPos.Y + listSize.Y then
                        -- Check if click is on holder (the button)
                        local hpos = holder.AbsolutePosition
                        local hsize = holder.AbsoluteSize
                        if mpos.X < hpos.X or mpos.X > hpos.X + hsize.X
                           or mpos.Y < hpos.Y or mpos.Y > hpos.Y + hsize.Y then
                            closeList()
                        end
                    end
                end
            end)

            -- Initial label
            if dropdownObj.Selected and dropdownObj.Selected ~= "" then
                label.Text = (cfg.Name or "Dropdown") .. ": " .. dropdownObj.Selected
            end

            function dropdownObj:Get() return dropdownObj.Selected end
            return dropdownObj
        end

        function tab:CreateColorPicker(cfg)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 36)
            holder.BackgroundColor3 = Theme.Element
            holder.Parent = page
            makeCorner(holder)

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -60, 1, 0)
            label.Position = UDim2.new(0, 12, 0, 0)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamMedium
            label.TextSize = 13
            label.TextColor3 = Theme.Text
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Text = cfg.Name or "Color"
            label.Parent = holder

            local swatch = Instance.new("Frame")
            swatch.Size = UDim2.new(0, 40, 0, 22)
            swatch.Position = UDim2.new(1, -50, 0.5, -11)
            swatch.BackgroundColor3 = cfg.Color or Color3.new(1, 1, 1)
            swatch.Parent = holder
            makeCorner(swatch)
            makeStroke(swatch, Theme.Stroke, 1)

            local pickerObj = { Color = cfg.Color or Color3.new(1, 1, 1) }

            local function openPicker()
                local panel = Instance.new("Frame")
                panel.Size = UDim2.new(0, 200, 0, 130)
                panel.Position = UDim2.new(1, -210, 0, 40)
                panel.BackgroundColor3 = Theme.Element
                panel.ZIndex = 20
                panel.Parent = holder
                makeCorner(panel)
                makeStroke(panel, Theme.StrokeLight, 1)

                local r, g, b = pickerObj.Color.R * 255, pickerObj.Color.G * 255, pickerObj.Color.B * 255

                local function updateFromSliders()
                    pickerObj.Color = Color3.fromRGB(r, g, b)
                    swatch.BackgroundColor3 = pickerObj.Color
                    if cfg.Callback then cfg.Callback(pickerObj.Color) end
                end

                local function makeChannel(name, yPos, getValue, setValue)
                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(0, 16, 0, 16)
                    lbl.Position = UDim2.new(0, 8, 0, yPos)
                    lbl.BackgroundTransparency = 1
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 11
                    lbl.TextColor3 = Theme.Text
                    lbl.Text = name
                    lbl.Parent = panel

                    local tr = Instance.new("Frame")
                    tr.Size = UDim2.new(0, 130, 0, 6)
                    tr.Position = UDim2.new(0, 28, 0, yPos + 5)
                    tr.BackgroundColor3 = Theme.Track
                    tr.Parent = panel
                    makeCorner(tr, UDim2.new(1, 0, 1, 0))

                    local fl = Instance.new("Frame")
                    fl.Size = UDim2.new(getValue() / 255, 0, 1, 0)
                    fl.BackgroundColor3 = Theme.Accent
                    fl.Parent = tr
                    makeCorner(fl, UDim2.new(1, 0, 1, 0))

                    local kb = Instance.new("Frame")
                    kb.Size = UDim2.new(0, 10, 0, 10)
                    kb.Position = UDim2.new(getValue() / 255, -5, 0.5, -5)
                    kb.BackgroundColor3 = Theme.Text
                    kb.Parent = tr
                    makeCorner(kb, UDim2.new(1, 0, 1, 0))

                    local val = Instance.new("TextLabel")
                    val.Size = UDim2.new(0, 26, 0, 16)
                    val.Position = UDim2.new(0, 166, 0, yPos)
                    val.BackgroundTransparency = 1
                    val.Font = Enum.Font.Gotham
                    val.TextSize = 11
                    val.TextColor3 = Theme.TextDim
                    val.Text = tostring(math.floor(getValue()))
                    val.Parent = panel

                    local dragging = false
                    local function setFromX(x)
                        local rel = tr.AbsolutePosition.X
                        local sz = tr.AbsoluteSize.X
                        local pct = math.clamp((x - rel) / sz, 0, 1)
                        local v = math.floor(pct * 255 + 0.5)
                        setValue(v)
                        fl.Size = UDim2.new(pct, 0, 1, 0)
                        kb.Position = UDim2.new(pct, -5, 0.5, -5)
                        val.Text = tostring(v)
                        updateFromSliders()
                    end
                    tr.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            dragging = true setFromX(input.Position.X)
                        end
                    end)
                    tr.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
                    end)
                    UserInputService.InputChanged:Connect(function(input)
                        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                            setFromX(input.Position.X)
                        end
                    end)
                end

                makeChannel("R", 10, function() return r end, function(v) r = v end)
                makeChannel("G", 36, function() return g end, function(v) g = v end)
                makeChannel("B", 62, function() return b end, function(v) b = v end)

                -- Done button
                local done = Instance.new("TextButton")
                done.Size = UDim2.new(0, 80, 0, 24)
                done.Position = UDim2.new(0.5, -40, 0, 96)
                done.BackgroundColor3 = Theme.Accent
                done.Text = "Done"
                done.Font = Enum.Font.GothamBold
                done.TextSize = 12
                done.TextColor3 = Theme.Text
                done.Parent = panel
                makeCorner(done)
                done.MouseButton1Click:Connect(function() panel:Destroy() end)

                -- Click outside to close
                UserInputService.InputBegan:Connect(function(input, gp)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 and not gp then
                        local mpos = UserInputService:GetMouseLocation()
                        local ppos = panel.AbsolutePosition
                        local psize = panel.AbsoluteSize
                        if mpos.X < ppos.X or mpos.X > ppos.X + psize.X
                           or mpos.Y < ppos.Y or mpos.Y > ppos.Y + psize.Y then
                            panel:Destroy()
                        end
                    end
                end)
            end

            swatch.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    openPicker()
                end
            end)

            function pickerObj:Set(c)
                pickerObj.Color = c
                swatch.BackgroundColor3 = c
                if cfg.Callback then cfg.Callback(c) end
            end
            return pickerObj
        end

        return tab
    end

    function window:SelectTab(tab)
        if window.ActiveTab then
            window.ActiveTab.Page.Visible = false
            TweenService:Create(window.ActiveTab.Btn, TweenInfo.new(0.15), {
                BackgroundColor3 = Theme.TabInactive,
                TextColor3 = Theme.TextDim,
            }):Play()
        end
        window.ActiveTab = tab
        tab.Page.Visible = true
        TweenService:Create(tab.Btn, TweenInfo.new(0.15), {
            BackgroundColor3 = Theme.TabActive,
            TextColor3 = Theme.Text,
        }):Play()
    end

    function window:Notify(cfg)
        local notif = Instance.new("Frame")
        notif.Size = UDim2.new(1, 0, 0, 60)
        notif.BackgroundColor3 = Theme.Element
        notif.Parent = notifContainer
        makeCorner(notif)
        makeStroke(notif, Theme.Accent, 1)

        local ttl = Instance.new("TextLabel")
        ttl.Size = UDim2.new(1, -16, 0, 18)
        ttl.Position = UDim2.new(0, 8, 0, 6)
        ttl.BackgroundTransparency = 1
        ttl.Font = Enum.Font.GothamBold
        ttl.TextSize = 13
        ttl.TextColor3 = Theme.Text
        ttl.TextXAlignment = Enum.TextXAlignment.Left
        ttl.Text = cfg.Title or "Notification"
        ttl.Parent = notif

        local cnt = Instance.new("TextLabel")
        cnt.Size = UDim2.new(1, -16, 0, 30)
        cnt.Position = UDim2.new(0, 8, 0, 24)
        cnt.BackgroundTransparency = 1
        cnt.Font = Enum.Font.Gotham
        cnt.TextSize = 12
        cnt.TextColor3 = Theme.TextDim
        cnt.TextXAlignment = Enum.TextXAlignment.Left
        cnt.TextYAlignment = Enum.TextYAlignment.Top
        cnt.TextWrapped = true
        cnt.Text = cfg.Content or ""
        cnt.Parent = notif

        notif.Size = UDim2.new(1, 0, 0, 0)
        notif.BackgroundTransparency = 1
        TweenService:Create(notif, TweenInfo.new(0.2), {
            Size = UDim2.new(1, 0, 0, 60),
            BackgroundTransparency = 0,
        }):Play()

        task.delay(cfg.Duration or 5, function()
            local t = TweenService:Create(notif, TweenInfo.new(0.3), {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
            })
            t:Play()
            t.Completed:Connect(function() notif:Destroy() end)
        end)
    end

    function window:Destroy() sg:Destroy() end

    -- K toggles UI visibility
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.K then
            sg.Enabled = not sg.Enabled
        end
    end)

    return window
end

--==============================================================
-- BUILD UI
--==============================================================
local Window = CustomUI:CreateWindow({
    Name = "👑WELCOME DEVELOPER👑 | V1000🔥 SOVEREIGN",
})

------------------------------------------------- TAB 1: NEXUS IDENTITY
local IdTab = Window:CreateTab("Nexus Identity")
IdTab:CreateLabel("IDENTITY MATRIX")
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
    Name = "Destroy UI",
    Callback = function() Window:Destroy() end,
})

------------------------------------------------- TAB 2: GHOST SHOUT
local GlobalTab = Window:CreateTab("Ghost Shout")
GlobalTab:CreateLabel("CHAT BYPASS")
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
        Window:Notify({
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
        pcall(function() ChatRemote:InvokeServer("V1000 test ping") end)
    end,
})
GlobalTab:CreateButton({
    Name = "Destroy UI",
    Callback = function() Window:Destroy() end,
})

------------------------------------------------- TAB 3: OVERDRIVE FARM
local FarmTab = Window:CreateTab("Overdrive Farm")
FarmTab:CreateLabel("REZURXSHIN ENGINE")
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
FarmTab:CreateButton({
    Name = "Destroy UI",
    Callback = function() Window:Destroy() end,
})

------------------------------------------------- TAB 4: SPECTRAL SCAN
local VisTab = Window:CreateTab("Spectral Scan")
VisTab:CreateLabel("POWER ESP")

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
        espConn = RunService.Heartbeat:Connect(function()
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
        end)
    end,
})
VisTab:CreateButton({
    Name = "Destroy UI",
    Callback = function() Window:Destroy() end,
})

------------------------------------------------- TAB 5: PHYSICAL OVERRIDE
local LocalTab = Window:CreateTab("Physical Override")
LocalTab:CreateLabel("MOVEMENT STATS")

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
    CurrentValue = 16,
    Suffix = " Speed",
    Callback = function(v) Config.WalkSpeed = v applyMovement() end,
})
LocalTab:CreateSlider({
    Name = "JumpPower",
    Range = {50, 1000},
    CurrentValue = 50,
    Suffix = " Power",
    Callback = function(v) Config.JumpPower = v applyMovement() end,
})
LocalTab:CreateButton({
    Name = "Destroy UI",
    Callback = function() Window:Destroy() end,
})

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
local ExpTab = Window:CreateTab("Dark Experiments")
ExpTab:CreateLabel("UNSTABLE / EXPERIMENTAL")

ExpTab:CreateToggle({
    Name = "Turn Off PVP",
    CurrentValue = false,
    Callback = function(t) Config.PvpOff = t end,
})

local noclipConn
local function setNoclip(enabled)
    Config.Noclip = enabled
    if enabled then
        if noclipConn then return end
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
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
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
ExpTab:CreateButton({
    Name = "Destroy UI",
    Callback = function() Window:Destroy() end,
})

------------------------------------------------- TAB 7: SYSTEM
local SysTab = Window:CreateTab("System")
SysTab:CreateLabel("SYSTEM CONTROL")
SysTab:CreateButton({
    Name = "Hide UI (Press K to toggle)",
    Callback = function() Window.ScreenGui.Enabled = false end,
})
SysTab:CreateButton({
    Name = "Force Re-scan All Remotes",
    Callback = function()
        initTrainRemotes()
        initChatRemote()
        Window:Notify({
            Title   = "Re-scan Complete",
            Content = "Train remotes: " .. (TrainRemotes.ApplyAddFrenzyValue and "✅" or "❌")
                   .. " | Chat remote: " .. (ChatRemote and "✅" or "❌"),
            Duration = 5,
        })
    end,
})
SysTab:CreateButton({
    Name = "Destroy UI",
    Callback = function() Window:Destroy() end,
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
                local rsArea = ReplicatedStorage:FindFirstChild("Area")
                local rsRem  = rsArea and rsArea:FindFirstChild("Remote")
                local invoke = rsRem and rsRem:FindFirstChild("PlayerAreaIn")
                if s2 and invoke then invoke:InvokeServer(s2) end
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
Window:Notify({
    Title   = "👑WELCOME DEVELOPER👑",
    Content = "V1000🔥 SOVEREIGN loaded. Custom GUI active. Press K to toggle.",
    Duration = 6,
})
