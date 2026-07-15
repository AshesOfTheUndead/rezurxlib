--[[
    👑WELCOME DEVELOPER👑 V777🔥: THE FINAL FIX
    - FIX: Added 'Increment' to sliders to stop the arithmetic (div) nil error.
]]

repeat task.wait() until game:IsLoaded()

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Config = {
    CustomTag = "",
    UserName = "",
    TagColor = Color3.fromRGB(128, 0, 0),
    UserColor = Color3.fromRGB(255, 255, 255),
    MessageColor = Color3.fromRGB(255, 255, 255),
    FarmMode = "Flagship (S22 Ultra)",
    FarmEnabled = false,
    EspEnabled = false,
    OverrideStats = false,
    WalkSpeed = 16,
    JumpPower = 50,
    RespectFarm = false,
    Noclip = false,
    AntiSlow = false,
    PvpOff = false
}

-- REZURXSHIN ENGINE (STRICT 15-LINE)
local function DoTrain()
    local TrainSpeed = math.huge
    RS:WaitForChild("TrainSystem"):WaitForChild("Remote"):WaitForChild("ApplyAddFrenzyValue"):InvokeServer(10000)
    RS:WaitForChild("TrainSystem"):WaitForChild("Remote"):WaitForChild("TrainSpeedHasChanged"):FireServer(TrainSpeed)
    RS:WaitForChild("TrainEquipment"):WaitForChild("Remote"):WaitForChild("ApplyMobileTrain"):InvokeServer(TrainSpeed)
    RS:WaitForChild("TrainEquipment"):WaitForChild("Remote"):WaitForChild("ApplyStationaryTrain"):InvokeServer(TrainSpeed)
    RS:WaitForChild("TrainEquipment"):WaitForChild("Remote"):WaitForChild("ApplyStationaryTrain"):InvokeServer(TrainSpeed)
    RS:WaitForChild("TrainSystem"):WaitForChild("Remote"):WaitForChild("TrainSpeedHasChanged"):FireServer(TrainSpeed)
    RS:WaitForChild("TrainEquipment"):WaitForChild("Remote"):WaitForChild("ApplyMobileTrain"):InvokeServer(TrainSpeed)
    RS:WaitForChild("TrainEquipment"):WaitForChild("Remote"):WaitForChild("ApplyStationaryTrain"):InvokeServer(TrainSpeed)
    RS:WaitForChild("TrainEquipment"):WaitForChild("Remote"):WaitForChild("ApplyStationaryTrain"):InvokeServer(TrainSpeed)
    RS:WaitForChild("TrainSystem"):WaitForChild("Remote"):WaitForChild("TrainSpeedHasChanged"):FireServer(TrainSpeed)
    RS:WaitForChild("TrainEquipment"):WaitForChild("Remote"):WaitForChild("ApplyMobileTrain"):InvokeServer(TrainSpeed)
    RS:WaitForChild("TrainEquipment"):WaitForChild("Remote"):WaitForChild("ApplyStationaryTrain"):InvokeServer(TrainSpeed)
    RS:WaitForChild("TrainEquipment"):WaitForChild("Remote"):WaitForStationaryTrain"):InvokeServer(TrainSpeed)
    RS:WaitForChild("TrainSystem"):WaitForChild("Remote"):WaitForChild("TrainSpeedHasChanged"):FireServer(TrainSpeed)
    RS:WaitForChild("TrainSystem"):WaitForChild("Remote"):WaitForChild("ApplyAddFrenzyValue"):InvokeServer(10000)
end

local function formatNumber(n)
    local s = {{1e33,"De"}, {1e30,"No"}, {1e27,"Oc"}, {1e24,"Sp"}, {1e21,"Sx"}, {1e18,"Qi"}, {1e15,"Qa"}, {1e12,"T"}, {1e9,"B"}, {1e6,"M"}, {1e3,"K"}}
    for _, v in ipairs(s) do if n >= v[1] then return string.format("%.2f%s", n / v[1], v[2]) end end
    return tostring(n)
end

local function getPower(name)
    local p = Players:FindFirstChild(name)
    local ts = p and p:FindFirstChild("Configuration") and p.Configuration:FindFirstChild("TrainSystem")
    if not ts then return 0 end
    local total = 0
    for i = 1, 4 do total += (ts:GetAttribute(tostring(i)) or 0) end
    return total
end

local Window = Rayfield:CreateWindow({
   Name = "V777🔥 STABLE",
   LoadingTitle = "Initializing...",
   LoadingSubtitle = "V777🔥 Absolute Authority",
   ConfigurationSaving = { Enabled = false }
})

local IdTab = Window:CreateTab("Nexus Identity", 4483362458)
IdTab:CreateDropdown({Name = "Quick-Access Titles", Options = {"GLOBAL", "SERVER ANNOUNCEMENT", "None"}, CurrentOption = {""}, Callback = function(v) Config.CustomTag = (v[1] == "None" and "" or v[1]) end})
IdTab:CreateDropdown({Name = "Quick-Access Usernames", Options = {"RezurXshin☑️", "None"}, CurrentOption = {""}, Callback = function(v) Config.UserName = (v[1] == "None" and "" or v[1]) end})

local GlobalTab = Window:CreateTab("Ghost Shout", 4483362458)
GlobalTab:CreateInput({Name = "Send Shout (Box)", PlaceholderText = "Type message...", RemoveTextAfterFocusLost = true, Callback = function(msg)
    local r = RS:WaitForChild("TextChat"):WaitForChild("Remote"):WaitForChild("SendTextChatMessageToAllPlayer")
    local tagPart = Config.CustomTag ~= "" and string.format('<font color="#%s"><b>[%s]</b></font> ', Config.TagColor:ToHex(), Config.CustomTag) or ""
    local namePart = Config.UserName ~= "" and string.format('<font color="#%s"><b>%s:</b></font> ', Config.UserColor:ToHex(), Config.UserName) or ""
    r:InvokeServer({["Text"] = tagPart .. namePart .. string.format('<font color="#%s"><b>%s</b></font>', Config.MessageColor:ToHex(), msg)})
end})

local FarmTab = Window:CreateTab("Overdrive Farm", 4483362458)
FarmTab:CreateDropdown({Name = "Auto Train Intensity", Options = {"Redmi (Light)", "Flagship (S22 Ultra)"}, CurrentOption = {"Flagship (S22 Ultra)"}, Callback = function(v) Config.FarmMode = v[1] end})
FarmTab:CreateToggle({Name = "RezurXshin Auto Train", CurrentValue = false, Callback = function(t)
    Config.FarmEnabled = t
    task.spawn(function()
        while Config.FarmEnabled do
            local loops = 1
            if Config.FarmMode:find("Mid") then loops = 5
            elseif Config.FarmMode:find("Flag") then loops = 15
            elseif Config.FarmMode:find("SING") then loops = 50 end
            for i = 1, loops do task.spawn(pcall, DoTrain) end
            task.wait(0.01)
        end
    end)
end})
FarmTab:CreateToggle({Name = "Auto Respect Farm", CurrentValue = false, Callback = function(t)
    Config.RespectFarm = t
    task.spawn(function()
        while Config.RespectFarm do
            for _, v in pairs(Players:GetPlayers()) do
                if v ~= player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                    pcall(function()
                        player.Character.HumanoidRootPart.CFrame = v.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                        RS.Ability.Remote.ApplyCastAbility:InvokeServer(player.Character.Parent.Name, "1")
                    end)
                end
                task.wait(0.1)
            end
            task.wait(0.5)
        end
    end)
end})

local VisTab = Window:CreateTab("Spectral Scan", 4483362458)
VisTab:CreateToggle({Name = "RezurXshin ESP (Power Scan)", CurrentValue = false, Callback = function(t)
    Config.EspEnabled = t
    task.spawn(function()
        while Config.EspEnabled do
            pcall(function()
                for _, obj in pairs(workspace.Creature.Activation:GetChildren()) do
                    for _, pMod in pairs(obj:GetChildren()) do
                        local h = pMod:FindFirstChild("Head")
                        if h then
                            local old = h:FindFirstChild("RezurTag")
                            if old then old:Destroy() end
                            local bb = Instance.new("BillboardGui", h)
                            bb.Name = "RezurTag"
                            local l = Instance.new("TextLabel", bb)
                            l.Text = formatNumber(getPower(pMod.Name))
                        end
                    end
                end
            end)
            task.wait(0.6)
        end
    end)
end})

local LocalTab = Window:CreateTab("Physical Override", 4483362458)
local function ApplyMovement()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    if Config.OverrideStats then
        hum.WalkSpeed = Config.WalkSpeed
        hum.JumpPower = Config.JumpPower
        hum.UseJumpPower = true
    else
        hum.WalkSpeed = 16
        hum.JumpPower = 50
        hum.UseJumpPower = true
    end
end

LocalTab:CreateToggle({Name = "Override Walk/Jump Stats", CurrentValue = false, Callback = function(t)
    Config.OverrideStats = t
    ApplyMovement()
end})
LocalTab:CreateSlider({Name = "WalkSpeed", Range = {16, 1000}, Increment = 1, CurrentValue = 16, Suffix = " Speed", Callback = function(v)
    Config.WalkSpeed = v
    ApplyMovement()
end})

local ExpTab = Window:CreateTab("Dark Experiments", 4483362458)
ExpTab:CreateToggle({Name = "Turn Off PVP", CurrentValue = false, Callback = function(t) Config.PvpOff = t end})
ExpTab:CreateToggle({Name = "Noclip", CurrentValue = false, Callback = function(t) Config.Noclip = t end})

RunService.Heartbeat:Connect(ApplyMovement)

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    ApplyMovement()
end)

RunService.Stepped:Connect(function()
    if player.Character and Config.Noclip then
        for _, v in pairs(player.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if Config.PvpOff then
            pcall(function() RS.Area.Remote.PlayerAreaIn:InvokeServer(workspace.Area.PlayerArea.S2) end)
        end
    end
end)

Rayfield:Notify({Title = "V777", Content = "Protocol Established.", Duration = 5})
