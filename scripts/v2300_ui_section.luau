-- ============================================================
-- [NEW] ORION LIBRARY LOADER — with Rayfield fallback
-- Tries Orion first (cleaner look), falls back to Rayfield if Orion fails.
-- ============================================================
local UI_LIB = nil  -- "Orion" or "Rayfield"
local Window = nil

-- Orion hosts (try multiple in case one is down)
local ORION_HOSTS = {
    "https://raw.githubusercontent.com/dawid-scripts/Orion/main/source.lua",
    "https://github.com/dawid-scripts/Orion/raw/main/source.lua",
}

-- Rayfield hosts (fallback)
local RAYFIELD_HOSTS = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
}

local function tryLoad(hosts)
    for _, url in ipairs(hosts) do
        local okHttp, src = pcall(function() return game:HttpGet(url) end)
        if okHttp and src and #src > 100 then
            local okLoad, fn = pcall(function() return loadstring(src) end)
            if okLoad and fn then
                local okCall, lib = pcall(fn)
                if okCall and lib then return lib end
            end
        end
    end
    return nil
end

-- Try Orion first
local OrionLib = tryLoad(ORION_HOSTS)
if OrionLib and OrionLib.MakeWindow then
    UI_LIB = "Orion"
    warn("[V2300] Orion Library loaded")
else
    -- Fall back to Rayfield
    OrionLib = nil
    local Rayfield = tryLoad(RAYFIELD_HOSTS)
    if Rayfield and Rayfield.CreateWindow then
        UI_LIB = "Rayfield"
        OrionLib = Rayfield  -- use same variable name for unified API
        warn("[V2300] Rayfield loaded (Orion failed, falling back)")
    else
        -- Last resort: minimal native UI
        UI_LIB = "Native"
        warn("[V2300] All UI libraries failed — using native notifications only")
    end
end

-- Unified notify function
local function notify(title, content, duration)
    if UI_LIB == "Orion" then
        pcall(function()
            OrionLib:MakeNotification({
                Name = title or "V2300",
                Content = content or "",
                Image = "rbxassetid://4483362458",
                Time = duration or 5,
            })
        end)
    elseif UI_LIB == "Rayfield" then
        pcall(function()
            OrionLib:Notify({
                Title = title or "V2300",
                Content = content or "",
                Duration = duration or 5,
            })
        end)
    else
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = title or "V2300",
                Text = content or "",
                Duration = duration or 5,
            })
        end)
    end
end

-- Expose notify globally for the rest of the script
notify = notify

-- ============================================================
-- BUILD UI
-- ============================================================
if UI_LIB == "Orion" then
    -- ============================================================
    -- ORION UI BUILD
    -- ============================================================
    Window = OrionLib:MakeWindow({
        Name = "RezurXLab V2300 | Orion",
        HidePremium = false,
        SaveConfig = false,
        ConfigFolder = "RezurXLab"
    })

    -- ── TAB 1: FARM ──
    local FarmTab = Window:MakeTab({ Name = "Farm", Icon = "rbxassetid://4483362458", PremiumOnly = false })
    FarmTab:AddSection({ Name = "Hybrid Apex Engine" })
    FarmTab:AddDropdown({
        Name = "Mode",
        Default = "Hybrid (recommended)",
        Options = {"Hybrid (recommended)", "Legacy"},
        Callback = function(v)
            Config.FarmMode = v:find("Hybrid") and "Hybrid" or "Legacy"
            if Config.FarmEnabled then
                stopFarm()
                task.wait(0.1)
                startFarm()
            end
        end
    })
    FarmTab:AddDropdown({
        Name = "Speed Value",
        Default = "Infinity (math.huge)",
        Options = {"Infinity (math.huge)", "1e9 (safe)", "1e15 (very large)", "1e18 (extreme)", "1e30 (max finite)"},
        Callback = function(v) Config.TrainSpeedValue = v end
    })
    FarmTab:AddSlider({
        Name = "Workers",
        Min = 1, Max = 20, Default = 5, Increment = 1,
        Callback = function(v)
            Config.WorkerCount = v
            if Config.FarmEnabled and Config.FarmMode == "Hybrid" then
                killWorkers()
                local n = math.max(1, math.min(20, v * Config.FarmSpeedMul))
                if Config.TurboActive then n = math.min(20, n * 2) end
                hybridState.currentWorkers = n
                spawnWorkers(n)
            end
        end
    })
    FarmTab:AddDropdown({
        Name = "Speed Multiplier",
        Default = "1x",
        Options = {"0.5x", "1x", "2x"},
        Callback = function(v)
            if v == "0.5x" then Config.FarmSpeedMul = 0.5
            elseif v == "2x" then Config.FarmSpeedMul = 2
            else Config.FarmSpeedMul = 1 end
        end
    })
    FarmTab:AddToggle({
        Name = "Anti-Detect",
        Default = true,
        Callback = function(t) Config.AntiDetect = t end
    })
    FarmTab:AddToggle({
        Name = "START FARM",
        Default = false,
        Callback = function(t)
            Config.FarmEnabled = t
            if t then startFarm() else stopFarm() end
        end
    })
    FarmTab:AddButton({
        Name = "TURBO BOOST (2x / 10s)",
        Callback = function() setTurbo() end
    })
    FarmTab:AddSection({ Name = "Overnight Mode" })
    FarmTab:AddToggle({
        Name = "Overnight (5min on / 30s off)",
        Default = false,
        Callback = function(t)
            Config.OvernightEnabled = t
            if t then startOvernight() else stopOvernight() end
        end
    })
    FarmTab:AddSection({ Name = "Live Stats" })
    local statsParagraph = FarmTab:AddParagraph({ Name = "Power Tracker", Content = "Start farm to begin..." })

    -- ── TAB 2: MOVEMENT ──
    local MoveTab = Window:MakeTab({ Name = "Movement", Icon = "rbxassetid://4483362458", PremiumOnly = false })
    MoveTab:AddSection({ Name = "Walk / Jump" })
    local overrideToggle = MoveTab:AddToggle({
        Name = "Override Stats",
        Default = false,
        Callback = function(t)
            Config.OverrideStats = t
            if t then applyMovement() else restoreMovement() end
        end
    })
    local walkSlider = MoveTab:AddSlider({
        Name = "WalkSpeed",
        Min = 16, Max = 1000, Default = 16, Increment = 1,
        Callback = function(v) Config.WalkSpeed = v; applyMovement() end
    })
    local jumpSlider = MoveTab:AddSlider({
        Name = "JumpPower",
        Min = 50, Max = 1000, Default = 50, Increment = 1,
        Callback = function(v) Config.JumpPower = v; applyMovement() end
    })
    MoveTab:AddButton({
        Name = "Reset (16 / 50)",
        Callback = function()
            Config.WalkSpeed = 16
            Config.JumpPower = 50
            Config.OverrideStats = false
            -- Orion toggles/sliders don't have Set, so just restore movement
            restoreMovement()
            notify("Movement", "Reset to 16/50. Toggle Override OFF manually.", 4)
        end
    })
    MoveTab:AddSection({ Name = "Noclip" })
    MoveTab:AddDropdown({
        Name = "Mode",
        Default = "Improved",
        Options = {"V777 (Simple)", "Improved"},
        Callback = function(v)
            Config.NoclipMode = v:find("V777") and "V777" or "Improved"
            if Config.NoclipEnabled then
                setNoclipMode(false)
                task.wait(0.05)
                setNoclipMode(true)
            end
        end
    })
    MoveTab:AddToggle({
        Name = "Noclip",
        Default = false,
        Callback = function(t) setNoclipMode(t) end
    })

    -- ── TAB 3: IDENTITY ──
    local IdTab = Window:MakeTab({ Name = "Identity", Icon = "rbxassetid://4483362458", PremiumOnly = false })
    IdTab:AddSection({ Name = "Chat Identity Setup" })
    IdTab:AddDropdown({
        Name = "Title",
        Default = "None",
        Options = {"GLOBAL", "SERVER ANNOUNCEMENT", "👑Head Administrator👑", "👑Head Executive Lead Developer👑", "None"},
        Callback = function(v) Config.CustomTag = (v == "None" or v == "") and "" or v end
    })
    IdTab:AddDropdown({
        Name = "Username",
        Default = "None",
        Options = {"RezurXshin☑️", "Jandel", "Administrator", "None"},
        Callback = function(v) Config.UserName = (v == "None" or v == "") and "" or v end
    })
    IdTab:AddTextBox({
        Name = "Custom Title",
        Default = "",
        TextDisappear = false,
        Callback = function(v) Config.CustomTag = v or "" end
    })
    IdTab:AddTextBox({
        Name = "Custom Name",
        Default = "",
        TextDisappear = false,
        Callback = function(v) Config.UserName = v or "" end
    })
    IdTab:AddColorPicker({
        Name = "Title / Tag Color",
        Default = Config.TagColor,
        Callback = function(v) Config.TagColor = v end
    })
    IdTab:AddColorPicker({
        Name = "User Name Color",
        Default = Config.UserColor,
        Callback = function(v) Config.UserColor = v end
    })
    IdTab:AddColorPicker({
        Name = "Message Text Color",
        Default = Config.MessageColor,
        Callback = function(v) Config.MessageColor = v end
    })

    -- ── TAB 4: CHAT ──
    local ChatTab = Window:MakeTab({ Name = "Chat", Icon = "rbxassetid://4483362458", PremiumOnly = false })
    ChatTab:AddSection({ Name = "Ghost Shout" })
    ChatTab:AddTextBox({
        Name = "Message (type then click Send)",
        Default = "",
        TextDisappear = false,
        Callback = function(v)
            -- Orion TextBox fires on Enter or focus lost
            if v and v ~= "" then
                sendChatMessage(v)
                notify("Shout Sent", v:sub(1, 40), 3)
            end
        end
    })
    ChatTab:AddButton({
        Name = "Send Plain-Text Test",
        Callback = function()
            if not Remotes.SendTextChatMessage then healRemotesWithBackoff() end
            if not Remotes.SendTextChatMessage then notify("Chat", "Remote not found", 4) return end
            local ok = pcall(function() Remotes.SendTextChatMessage:InvokeServer("V2300 test ping") end)
            notify("Test", ok and "Sent" or "Failed", 3)
        end
    })
    ChatTab:AddButton({
        Name = "Re-scan Chat Remote",
        Callback = function()
            healRemotesWithBackoff()
            notify("Chat", Remotes.SendTextChatMessage and "Found" or "Missing", 4)
        end
    })

    -- ── TAB 5: LAB ──
    local LabTab = Window:MakeTab({ Name = "Lab", Icon = "rbxassetid://4483362458", PremiumOnly = false })
    LabTab:AddSection({ Name = "Experimental Tools" })
    LabTab:AddToggle({
        Name = "Anti-AFK",
        Default = true,
        Callback = function(t) Config.AntiAfk = t end
    })
    LabTab:AddToggle({
        Name = "PVP Off",
        Default = false,
        Callback = function(t) Config.PvpOff = t end
    })
    LabTab:AddSection({ Name = "Spectral Scan (ESP)" })
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
        for i = 1, 4 do
            total = total + (ts:GetAttribute(tostring(i)) or 0)
        end
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
    LabTab:AddToggle({
        Name = "ESP (Power Scan)",
        Default = false,
        Callback = function(t)
            Config.EspEnabled = t
            if not t then clearAllEspTags() return end
            espConn = RunService.RenderStepped:Connect(function()
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
        end
    })
    LabTab:AddButton({
        Name = "Clear All ESP Tags",
        Callback = function() clearAllEspTags() notify("ESP", "All tags cleared", 3) end
    })

    -- ── TAB 6: SYSTEM ──
    local SysTab = Window:MakeTab({ Name = "System", Icon = "rbxassetid://4483362458", PremiumOnly = false })
    SysTab:AddSection({ Name = "Remote Status" })
    SysTab:AddButton({
        Name = "Show Remote Status",
        Callback = function()
            healRemotesWithBackoff()
            notify("Remotes",
                "Frenzy:" .. (Remotes.ApplyAddFrenzyValue and "Y" or "N") ..
                " Speed:" .. (Remotes.TrainSpeedHasChanged and "Y" or "N") ..
                " Mobile:" .. (Remotes.ApplyMobileTrain and "Y" or "N") ..
                " Stationary:" .. (Remotes.ApplyStationaryTrain and "Y" or "N") ..
                " Chat:" .. (Remotes.SendTextChatMessage and "Y" or "N"), 10)
        end
    })
    SysTab:AddButton({
        Name = "Re-init All Remotes",
        Callback = function() healRemotesWithBackoff() notify("Remotes", "Re-scanned", 3) end
    })
    SysTab:AddSection({ Name = "Error Log (last 100)" })
    SysTab:AddButton({
        Name = "Show Last 10 Errors",
        Callback = function()
            local n = #ERR_LOG
            if n == 0 then notify("Errors", "No errors logged", 4) return end
            local lines = {}
            for i = math.max(1, n - 9), n do
                local e = ERR_LOG[i]
                if e then table.insert(lines, string.format("%s [%s] %s", e.timeStr, e.source, e.msg:sub(1, 60))) end
            end
            notify("Errors (" .. n .. " total)", table.concat(lines, "\n"), 12)
        end
    })
    SysTab:AddButton({
        Name = "Clear Error Log",
        Callback = function() table.clear(ERR_LOG) notify("Errors", "Cleared", 3) end
    })
    SysTab:AddSection({ Name = "UI" })
    SysTab:AddButton({
        Name = "Destroy UI",
        Callback = function() pcall(function() OrionLib:Destroy() end) end
    })

    -- Live stats updater
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
            pcall(function() statsParagraph:Set({ Content = content }) end)
        end
    end)

    -- FPS counter (Orion doesn't have a built-in FPS display, so skip it)
    -- K toggles UI
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.K then
            pcall(function() OrionLib:Toggle() end)
        end
    end)

    OrionLib:Init()

elseif UI_LIB == "Rayfield" then
    -- ============================================================
    -- RAYFIELD UI BUILD (fallback)
    -- ============================================================
    Window = OrionLib:CreateWindow({
        Name = "RezurXLab V2300 | Rayfield",
        LoadingTitle = "V2300 Booting...",
        LoadingSubtitle = "Rayfield fallback active",
        ConfigurationSaving = { Enabled = false },
        Keybind = { Key = Enum.KeyCode.K, Mods = nil },
    })

    -- Farm tab
    local FarmTab = Window:CreateTab("Farm", 4483362458)
    FarmTab:CreateDropdown({
        Name = "Mode",
        Options = {"Hybrid (recommended)", "Legacy"},
        CurrentOption = "Hybrid (recommended)",
        Callback = function(v)
            local val = dropValue(v)
            Config.FarmMode = val:find("Hybrid") and "Hybrid" or "Legacy"
            if Config.FarmEnabled then stopFarm() task.wait(0.1) startFarm() end
        end
    })
    FarmTab:CreateDropdown({
        Name = "Speed Value",
        Options = {"Infinity (math.huge)", "1e9 (safe)", "1e15 (very large)", "1e18 (extreme)", "1e30 (max finite)"},
        CurrentOption = "Infinity (math.huge)",
        Callback = function(v) Config.TrainSpeedValue = dropValue(v) end
    })
    FarmTab:CreateSlider({
        Name = "Workers", Range = {1, 20}, Increment = 1, CurrentValue = 5, Suffix = "",
        Callback = function(v)
            Config.WorkerCount = v
            if Config.FarmEnabled and Config.FarmMode == "Hybrid" then
                killWorkers()
                local n = math.max(1, math.min(20, v * Config.FarmSpeedMul))
                if Config.TurboActive then n = math.min(20, n * 2) end
                hybridState.currentWorkers = n
                spawnWorkers(n)
            end
        end
    })
    FarmTab:CreateDropdown({
        Name = "Speed Multiplier",
        Options = {"0.5x", "1x", "2x"}, CurrentOption = "1x",
        Callback = function(v)
            local val = dropValue(v)
            if val == "0.5x" then Config.FarmSpeedMul = 0.5
            elseif val == "2x" then Config.FarmSpeedMul = 2
            else Config.FarmSpeedMul = 1 end
        end
    })
    FarmTab:CreateToggle({ Name = "Anti-Detect", CurrentValue = true, Callback = function(t) Config.AntiDetect = t end })
    FarmTab:CreateToggle({
        Name = "START FARM", CurrentValue = false,
        Callback = function(t) Config.FarmEnabled = t; if t then startFarm() else stopFarm() end end
    })
    FarmTab:CreateButton({ Name = "TURBO BOOST (2x / 10s)", Callback = function() setTurbo() end })
    FarmTab:CreateToggle({
        Name = "Overnight (5min on / 30s off)", CurrentValue = false,
        Callback = function(t) Config.OvernightEnabled = t; if t then startOvernight() else stopOvernight() end end
    })
    local statsParagraph
    pcall(function()
        statsParagraph = FarmTab:CreateParagraph({ Title = "Power Tracker", Content = "Start farm to begin..." })
    end)

    -- Movement tab
    local MoveTab = Window:CreateTab("Movement", 4483362458)
    MoveTab:CreateToggle({ Name = "Override Stats", CurrentValue = false,
        Callback = function(t) Config.OverrideStats = t; if t then applyMovement() else restoreMovement() end end })
    MoveTab:CreateSlider({ Name = "WalkSpeed", Range = {16, 1000}, Increment = 1, CurrentValue = 16, Suffix = " sp",
        Callback = function(v) Config.WalkSpeed = v; applyMovement() end })
    MoveTab:CreateSlider({ Name = "JumpPower", Range = {50, 1000}, Increment = 1, CurrentValue = 50, Suffix = " pw",
        Callback = function(v) Config.JumpPower = v; applyMovement() end })
    MoveTab:CreateButton({ Name = "Reset (16 / 50)", Callback = function()
        Config.WalkSpeed = 16; Config.JumpPower = 50; Config.OverrideStats = false
        restoreMovement()
        notify("Movement", "Reset to 16/50. Toggle Override OFF manually.", 4)
    end })
    MoveTab:CreateDropdown({ Name = "Noclip Mode", Options = {"V777 (Simple)", "Improved"}, CurrentOption = "Improved",
        Callback = function(v)
            local val = dropValue(v)
            Config.NoclipMode = val:find("V777") and "V777" or "Improved"
            if Config.NoclipEnabled then setNoclipMode(false) task.wait(0.05) setNoclipMode(true) end
        end })
    MoveTab:CreateToggle({ Name = "Noclip", CurrentValue = false, Callback = function(t) setNoclipMode(t) end })

    -- Identity tab
    local IdTab = Window:CreateTab("Identity", 4483362458)
    IdTab:CreateDropdown({ Name = "Title", Options = {"GLOBAL", "SERVER ANNOUNCEMENT", "👑Head Administrator👑", "👑Head Executive Lead Developer👑", "None"}, CurrentOption = "None",
        Callback = function(v) Config.CustomTag = (dropValue(v) == "None" or dropValue(v) == "") and "" or dropValue(v) end })
    IdTab:CreateDropdown({ Name = "Username", Options = {"RezurXshin☑️", "Jandel", "Administrator", "None"}, CurrentOption = "None",
        Callback = function(v) Config.UserName = (dropValue(v) == "None" or dropValue(v) == "") and "" or dropValue(v) end })
    IdTab:CreateInput({ Name = "Custom Title", PlaceholderText = "Empty = no tag", Callback = function(v) Config.CustomTag = v or "" end })
    IdTab:CreateInput({ Name = "Custom Name", PlaceholderText = "Empty = no name", Callback = function(v) Config.UserName = v or "" end })
    IdTab:CreateColorPicker({ Name = "Title / Tag Color", Color = Config.TagColor, Callback = function(v) Config.TagColor = v end })
    IdTab:CreateColorPicker({ Name = "User Name Color", Color = Config.UserColor, Callback = function(v) Config.UserColor = v end })
    IdTab:CreateColorPicker({ Name = "Message Text Color", Color = Config.MessageColor, Callback = function(v) Config.MessageColor = v end })

    -- Chat tab
    local ChatTab = Window:CreateTab("Chat", 4483362458)
    ChatTab:CreateInput({ Name = "Send Shout (type then press Enter)", PlaceholderText = "Type message...",
        RemoveTextAfterFocusLost = true, Callback = function(msg) sendChatMessage(msg) notify("Shout Sent", msg:sub(1, 40), 3) end })
    ChatTab:CreateButton({ Name = "Send Plain-Text Test", Callback = function()
        if not Remotes.SendTextChatMessage then healRemotesWithBackoff() end
        if not Remotes.SendTextChatMessage then notify("Chat", "Remote not found", 4) return end
        local ok = pcall(function() Remotes.SendTextChatMessage:InvokeServer("V2300 test ping") end)
        notify("Test", ok and "Sent" or "Failed", 3)
    end })
    ChatTab:CreateButton({ Name = "Re-scan Chat Remote", Callback = function()
        healRemotesWithBackoff()
        notify("Chat", Remotes.SendTextChatMessage and "Found" or "Missing", 4)
    end })

    -- Lab tab
    local LabTab = Window:CreateTab("Lab", 4483362458)
    LabTab:CreateToggle({ Name = "Anti-AFK", CurrentValue = true, Callback = function(t) Config.AntiAfk = t end })
    LabTab:CreateToggle({ Name = "PVP Off", CurrentValue = false, Callback = function(t) Config.PvpOff = t end })
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
    LabTab:CreateToggle({ Name = "ESP (Power Scan)", CurrentValue = false, Callback = function(t)
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
    end })
    LabTab:CreateButton({ Name = "Clear All ESP Tags", Callback = function() clearAllEspTags() notify("ESP", "All tags cleared", 3) end })

    -- System tab
    local SysTab = Window:CreateTab("System", 4483362458)
    SysTab:CreateButton({ Name = "Show Remote Status", Callback = function()
        healRemotesWithBackoff()
        notify("Remotes",
            "Frenzy:" .. (Remotes.ApplyAddFrenzyValue and "Y" or "N") ..
            " Speed:" .. (Remotes.TrainSpeedHasChanged and "Y" or "N") ..
            " Mobile:" .. (Remotes.ApplyMobileTrain and "Y" or "N") ..
            " Stationary:" .. (Remotes.ApplyStationaryTrain and "Y" or "N") ..
            " Chat:" .. (Remotes.SendTextChatMessage and "Y" or "N"), 10)
    end })
    SysTab:CreateButton({ Name = "Re-init All Remotes", Callback = function() healRemotesWithBackoff() notify("Remotes", "Re-scanned", 3) end })
    SysTab:CreateButton({ Name = "Show Last 10 Errors", Callback = function()
        local n = #ERR_LOG
        if n == 0 then notify("Errors", "No errors logged", 4) return end
        local lines = {}
        for i = math.max(1, n - 9), n do
            local e = ERR_LOG[i]
            if e then table.insert(lines, string.format("%s [%s] %s", e.timeStr, e.source, e.msg:sub(1, 60))) end
        end
        notify("Errors (" .. n .. " total)", table.concat(lines, "\n"), 12)
    end })
    SysTab:CreateButton({ Name = "Clear Error Log", Callback = function() table.clear(ERR_LOG) notify("Errors", "Cleared", 3) end })
    SysTab:CreateButton({ Name = "Destroy UI", Callback = function() pcall(function() OrionLib:Destroy() end) end })

    -- Live stats updater
    task.spawn(function()
        while task.wait(1) do
            if statsParagraph then
                local power = powerTracker.tick()
                local gains = powerTracker.avgGainsPerSec()
                local trend = powerTracker.trend()
                local trendIcon = trend == "up" and "↑" or (trend == "down" and "↓" or "→")
                local sessionTime = powerTracker.sessionStart > 0 and math.floor(tick() - powerTracker.sessionStart) or 0
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
                pcall(function() statsParagraph:Set({ Content = content }) end)
            end
        end
    end)

else
    -- ============================================================
    -- NATIVE FALLBACK — no UI library, just notifications + basic toggles via chat
    -- ============================================================
    notify("V2300 Fallback", "All UI libraries failed. Using native notifications. Features still active via config.", 10)
    -- Auto-start nothing; user can't control via UI. Just keep error logging alive.
end

