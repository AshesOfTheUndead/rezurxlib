--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  📜 DOMINUS DUMP | Full Game Code Extractor                   ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  Captures EVERY accessible script in the game:                ║
    ║    • Script, LocalScript, ModuleScript source code           ║
    ║    • All services (Workspace, ReplicatedStorage, etc.)       ║
    ║    • Decompiles locked scripts (if executor supports it)     ║
    ║    • Saves to file + copies to clipboard                     ║
    ║                                                               ║
    ║  NOTE: ServerScriptService & ServerStorage are NOT accessible ║
    ║  from the client (Roblox security). Only client-side scripts  ║
    ║  can be dumped. This is a Roblox limitation, not a bug.       ║
    ╚══════════════════════════════════════════════════════════════╝
]]

-- ============================================================
-- SERVICES
-- ============================================================
local game = game
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local StarterPlayer     = game:GetService("StarterPlayer")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local Lighting          = game:GetService("Lighting")
local ReplicatedFirst   = game:GetService("ReplicatedFirst")
local JointsService     = game:GetService("JointsService")
local RunService        = game:GetService("RunService")
local player            = Players.LocalPlayer

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    OUTPUT_FILE = "DOMINUS_Dump.txt",      -- file name for writefile
    COPY_TO_CLIPBOARD = true,               -- setclipboard (may exceed clipboard limit)
    SHOW_PROGRESS = true,                   -- notifications during dump
    INCLUDE_COREGUI = false,                -- CoreGui scripts (usually just Roblox default UI)
    INCLUDE_LIGHTING = false,               -- Lighting effects (usually no scripts)
    DECOMPILE_LOCKED = true,                -- try decompile() on locked scripts
    MAX_SCRIPT_SIZE = 500000,               -- skip scripts larger than 500KB (prevents lag)
}

-- ============================================================
-- HELPERS
-- ============================================================
local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "DOMINUS DUMP",
            Text = text or "",
            Duration = duration or 5,
        })
    end)
end

local function isScript(obj)
    return obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript")
end

-- Try multiple methods to get script source
local function getScriptSource(script)
    -- Method 1: Script.Source (works if not locked + executor allows it)
    local ok1, src = pcall(function() return script.Source end)
    if ok1 and src and #src > 0 then
        return src, "Source"
    end

    -- Method 2: decompile() (executor-specific — Synapse, Krnl, etc.)
    if CONFIG.DECOMPILE_LOCKED and decompile then
        local ok2, decompiled = pcall(decompile, script)
        if ok2 and decompiled and #decompiled > 0 then
            return decompiled, "Decompiled"
        end
    end

    -- Method 3: getscriptsource() (some executors)
    if CONFIG.DECOMPILE_LOCKED and getscriptsource then
        local ok3, src3 = pcall(getscriptsource, script)
        if ok3 and src3 and #src3 > 0 then
            return src3, "getscriptsource"
        end
    end

    -- Method 4: getsrc() (some executors)
    if CONFIG.DECOMPILE_LOCKED and getsrc then
        local ok4, src4 = pcall(getsrc, script)
        if ok4 and src4 and #src4 > 0 then
            return src4, "getsrc"
        end
    end

    return nil, "LOCKED"
end

-- ============================================================
-- DUMP LOGIC
-- ============================================================
local dumpOutput = {}
local stats = {
    total = 0,
    success = 0,
    locked = 0,
    skipped = 0,
    errors = 0,
    byType = { Script = 0, LocalScript = 0, ModuleScript = 0 },
    byMethod = { Source = 0, Decompiled = 0, getscriptsource = 0, getsrc = 0, LOCKED = 0 },
}

local function addLine(text)
    dumpOutput[#dumpOutput + 1] = text
end

local function addSeparator(char)
    addLine(string.rep(char or "=", 80))
end

local function dumpScript(script, path)
    stats.total = stats.total + 1
    stats.byType[script.ClassName] = (stats.byType[script.ClassName] or 0) + 1

    if #path > 0 and CONFIG.MAX_SCRIPT_SIZE > 0 then
        -- We don't know size until we try to get source, so just proceed
    end

    local src, method = getScriptSource(script)

    addSeparator("-")
    addLine("📁 " .. path)
    addLine("🏷️  Type: " .. script.ClassName)
    addLine("🔧 Method: " .. method)
    addLine("📏 Size: " .. (src and #src or 0) .. " chars")
    addLine("")

    if src then
        stats.success = stats.success + 1
        stats.byMethod[method] = (stats.byMethod[method] or 0) + 1
        addLine("-- SOURCE START --")
        addLine(src)
        addLine("-- SOURCE END --")
    else
        stats.locked = stats.locked + 1
        stats.byMethod.LOCKED = (stats.byMethod.LOCKED or 0) + 1
        addLine("❌ LOCKED — Could not extract source (server-side or encrypted)")
    end
    addLine("")
end

local function dumpService(service, serviceName)
    local count = 0
    for _, obj in ipairs(service:GetDescendants()) do
        if isScript(obj) then
            local path = serviceName .. obj:GetFullName():sub(#serviceName + 1)
            dumpScript(obj, path)
            count = count + 1
            if CONFIG.SHOW_PROGRESS and count % 20 == 0 then
                notify("📜 Dumping...", serviceName .. ": " .. count .. " scripts", 2)
            end
        end
    end
    return count
end

-- ============================================================
-- MAIN DUMP
-- ============================================================
local function runDump()
    notify("📜 DOMINUS DUMP", "Starting full game dump...", 3)
    task.wait(0.5)

    -- Header
    addSeparator("=")
    addLine("👑 DOMINUS DUMP — Full Game Code Extractor")
    addLine("📅 " .. os.date("%Y-%m-%d %H:%M:%S"))
    addLine("🎮 Game: " .. game.Name .. " (PlaceId: " .. tostring(game.PlaceId) .. ")")
    addLine("👤 Player: " .. player.Name)
    addSeparator("=")
    addLine("")

    -- Dump each accessible service
    local servicesToDump = {
        { ReplicatedStorage, "ReplicatedStorage" },
        { Workspace, "Workspace" },
        { StarterGui, "StarterGui" },
        { StarterPlayer, "StarterPlayer" },
        { ReplicatedFirst, "ReplicatedFirst" },
        { Lighting, "Lighting" },
    }

    -- Try ServerScriptService & ServerStorage (will only get names, not source — client can't access)
    local sss = game:GetService("ServerScriptService")
    local sStorage = game:GetService("ServerStorage")
    -- These will return empty on client due to FilteringEnabled, but try anyway

    for _, entry in ipairs(servicesToDump) do
        local service, name = entry[1], entry[2]
        addSeparator("=")
        addLine("📂 SERVICE: " .. name)
        addSeparator("=")
        local count = dumpService(service, name)
        addLine("")
        addLine("📊 " .. name .. ": " .. count .. " scripts found")
        addLine("")
    end

    -- Try ServerScriptService (client-side — will be empty but try)
    if sss then
        addSeparator("=")
        addLine("📂 SERVICE: ServerScriptService (⚠️ client-side — usually empty)")
        addSeparator("=")
        local count = dumpService(sss, "ServerScriptService")
        addLine("📊 ServerScriptService: " .. count .. " scripts (client-visible only)")
        addLine("")
    end

    -- Try ServerStorage
    if sStorage then
        addSeparator("=")
        addLine("📂 SERVICE: ServerStorage (⚠️ client-side — usually empty)")
        addSeparator("=")
        local count = dumpService(sStorage, "ServerStorage")
        addLine("📊 ServerStorage: " .. count .. " scripts (client-visible only)")
        addLine("")
    end

    -- CoreGui (optional)
    if CONFIG.INCLUDE_COREGUI then
        addSeparator("=")
        addLine("📂 SERVICE: CoreGui (Roblox default UI)")
        addSeparator("=")
        dumpService(CoreGui, "CoreGui")
    end

    -- Statistics
    addSeparator("=")
    addLine("📊 DUMP STATISTICS")
    addSeparator("=")
    addLine("✅ Total scripts found: " .. stats.total)
    addLine("✅ Successfully extracted: " .. stats.success)
    addLine("❌ Locked/inaccessible: " .. stats.locked)
    addLine("")
    addLine("📋 By Type:")
    for k, v in pairs(stats.byType) do
        addLine("   " .. k .. ": " .. v)
    end
    addLine("")
    addLine("🔧 By Extraction Method:")
    for k, v in pairs(stats.byMethod) do
        addLine("   " .. k .. ": " .. v)
    end
    addLine("")
    addSeparator("=")
    addLine("✅ DUMP COMPLETE")
    addSeparator("=")

    -- Combine output
    local finalOutput = table.concat(dumpOutput, "\n")
    local outputSize = #finalOutput

    -- Save to file
    local fileSaved = false
    if writefile then
        local ok = pcall(writefile, CONFIG.OUTPUT_FILE, finalOutput)
        if ok then
            fileSaved = true
            notify("📜 Dump Saved", "File: " .. CONFIG.OUTPUT_FILE .. " (" .. math.floor(outputSize / 1024) .. "KB)", 8)
        end
    end

    -- Copy to clipboard
    local clipboardCopied = false
    if CONFIG.COPY_TO_CLIPBOARD and setclipboard then
        -- Clipboard has size limits on some executors, try anyway
        local ok = pcall(setclipboard, finalOutput)
        if ok then
            clipboardCopied = true
        end
    end

    -- Final notification
    local msg = "Scripts: " .. stats.success .. "/" .. stats.total .. "\n"
    msg = msg .. "Size: " .. math.floor(outputSize / 1024) .. "KB\n"
    msg = msg .. "File: " .. (fileSaved and "✅ " .. CONFIG.OUTPUT_FILE or "❌ writefile unavailable")
    if CONFIG.COPY_TO_CLIPBOARD then
        msg = msg .. "\nClipboard: " .. (clipboardCopied and "✅ Copied" or "❌ Failed/too large")
    end
    notify("📜 Dump Complete", msg, 10)

    -- Print stats to console (F9 → Client log)
    print("\n" .. string.rep("=", 60))
    print("📜 DOMINUS DUMP COMPLETE")
    print(string.rep("=", 60))
    print("Total scripts: " .. stats.total)
    print("Extracted: " .. stats.success)
    print("Locked: " .. stats.locked)
    print("Output size: " .. math.floor(outputSize / 1024) .. "KB")
    print("File saved: " .. tostring(fileSaved))
    print("Clipboard: " .. tostring(clipboardCopied))
    print(string.rep("=", 60) .. "\n")

    return finalOutput
end

-- ============================================================
-- BUILD UI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DOMINUS_Dump"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then
    screenGui.Parent = player:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 400, 0, 280)
frame.Position = UDim2.new(0.5, -200, 0.5, -140)
frame.BackgroundColor3 = Color3.fromRGB(13, 13, 18)
frame.BorderSizePixel = 0
frame.Parent = screenGui
local fc = Instance.new("UICorner") fc.CornerRadius = UDim2.new(0, 16, 0, 16) fc.Parent = frame
local fs = Instance.new("UIStroke") fs.Color = Color3.fromRGB(255, 130, 35) fs.Thickness = 2 fs.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 40)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(255, 130, 35)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "📜 DOMINUS DUMP"
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -20, 0, 20)
subtitle.Position = UDim2.new(0, 10, 0, 45)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextColor3 = Color3.fromRGB(150, 150, 175)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = "Full Game Code Extractor | by RezurXshin"
subtitle.Parent = frame

-- Progress label
local progressLabel = Instance.new("TextLabel")
progressLabel.Size = UDim2.new(1, -20, 0, 24)
progressLabel.Position = UDim2.new(0, 10, 0, 80)
progressLabel.BackgroundTransparency = 1
progressLabel.Font = Enum.Font.GothamMedium
progressLabel.TextSize = 13
progressLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.Text = "Ready to dump. Click below."
progressLabel.Parent = frame

-- Dump button
local dumpBtn = Instance.new("TextButton")
dumpBtn.Size = UDim2.new(1, -20, 0, 44)
dumpBtn.Position = UDim2.new(0, 10, 0, 115)
dumpBtn.BackgroundColor3 = Color3.fromRGB(255, 130, 35)
dumpBtn.Text = "🚀 DUMP ENTIRE GAME"
dumpBtn.Font = Enum.Font.GothamBold
dumpBtn.TextSize = 16
dumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dumpBtn.BorderSizePixel = 0
dumpBtn.Parent = frame
local dbc = Instance.new("UICorner") dbc.CornerRadius = UDim2.new(0, 10, 0, 10) dbc.Parent = dumpBtn

-- Copy button
local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(1, -20, 0, 36)
copyBtn.Position = UDim2.new(0, 10, 0, 170)
copyBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 54)
copyBtn.Text = "📋 Copy Last Dump to Clipboard"
copyBtn.Font = Enum.Font.GothamMedium
copyBtn.TextSize = 13
copyBtn.TextColor3 = Color3.fromRGB(240, 240, 250)
copyBtn.BorderSizePixel = 0
copyBtn.Parent = frame
local cbc = Instance.new("UICorner") cbc.CornerRadius = UDim2.new(0, 8, 0, 8) cbc.Parent = copyBtn

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 80, 0, 30)
closeBtn.Position = UDim2.new(0.5, -40, 0, 220)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 75, 75)
closeBtn.Text = "✕ Close"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.BorderSizePixel = 0
closeBtn.Parent = frame
local clc = Instance.new("UICorner") clc.Parent = closeBtn

-- Make draggable
local dragging, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)
game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Last dump storage
local lastDump = nil

-- Dump button action
local dumping = false
dumpBtn.MouseButton1Click:Connect(function()
    if dumping then return end
    dumping = true
    dumpBtn.Text = "⏳ Dumping..."
    dumpBtn.BackgroundColor3 = Color3.fromRGB(204, 100, 28)
    progressLabel.Text = "Scanning all services..."

    -- Run dump in background
    task.spawn(function()
        lastDump = runDump()
        dumping = false
        dumpBtn.Text = "🚀 DUMP ENTIRE GAME"
        dumpBtn.BackgroundColor3 = Color3.fromRGB(255, 130, 35)
        progressLabel.Text = "✅ Done! Check file or clipboard."
    end)
end)

-- Copy button action
copyBtn.MouseButton1Click:Connect(function()
    if not lastDump then
        notify("📜 Dump", "No dump yet. Click DUMP first.", 3)
        return
    end
    if setclipboard then
        local ok = pcall(setclipboard, lastDump)
        if ok then
            notify("📋 Clipboard", "Copied (" .. math.floor(#lastDump / 1024) .. "KB)", 4)
        else
            notify("📋 Clipboard", "Failed — output too large. Use file instead.", 4)
        end
    else
        notify("📋 Clipboard", "setclipboard not supported", 4)
    end
end)

-- Close button
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- K toggles UI
game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.K then
        screenGui.Enabled = not screenGui.Enabled
    end
end)

notify("📜 DOMINUS DUMP", "Loaded! Press DUMP to extract all game code. K to toggle UI.", 6)
