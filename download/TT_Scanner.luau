--[[
    🔍 TRAIN TO FIGHT — REMOTE & STRUCTURE SCANNER
    Run this once in-game. Open F9 → "Client" log tab to read the output.
    Copy everything that starts with "[SCAN]" and paste it back to me.
    Then I can rewrite V888 with the ACTUAL remote paths.
]]

local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local function isRemote(obj)
    return obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
        or obj:IsA("UnreliableRemoteEvent") or obj:IsA("ModuleScript")
end

--==============================================================
-- 1. DUMP ALL REMOTES UNDER ReplicatedStorage
--==============================================================
print("\n========== [SCAN] ReplicatedStorage Remotes ==========")
local remoteCount = 0
for _, obj in ipairs(RS:GetDescendants()) do
    if isRemote(obj) then
        remoteCount += 1
        local path = obj:GetFullName()
        local t = obj.ClassName
        print(string.format("[SCAN] (%s) %s", t, path))
    end
end
print(string.format("[SCAN] Total remotes/modules found in RS: %d", remoteCount))

--==============================================================
-- 2. TOP-LEVEL ReplicatedStorage CHILDREN
--==============================================================
print("\n========== [SCAN] ReplicatedStorage top-level ==========")
for _, obj in ipairs(RS:GetChildren()) do
    print(string.format("[SCAN] %s [%s]", obj.Name, obj.ClassName))
end

--==============================================================
-- 3. CHECK SPECIFIC PATHS THE OLD SCRIPT USED
--==============================================================
print("\n========== [SCAN] Checking old script paths ==========")
local checkPaths = {
    {"TrainSystem"},
    {"TrainSystem", "Remote"},
    {"TrainSystem", "Remote", "ApplyAddFrenzyValue"},
    {"TrainSystem", "Remote", "TrainSpeedHasChanged"},
    {"TrainEquipment"},
    {"TrainEquipment", "Remote", "ApplyMobileTrain"},
    {"TrainEquipment", "Remote", "ApplyStationaryTrain"},
    {"TextChat"},
    {"TextChat", "Remote"},
    {"TextChat", "Remote", "SendTextChatMessageToAllPlayer"},
    {"Ability"},
    {"Ability", "Remote", "ApplyCastAbility"},
    {"Area"},
    {"Area", "Remote", "PlayerAreaIn"},
    {"Remotes"},            -- confirmed pattern from leaks
    {"Remotes", "Input"},   -- confirmed pattern from leaks
}
for _, path in ipairs(checkPaths) do
    local current = RS
    local ok = true
    for _, name in ipairs(path) do
        local next = current:FindFirstChild(name)
        if not next then ok = false break end
        current = next
    end
    local status = ok and ("✅ EXISTS — " .. current.ClassName) or "❌ MISSING"
    print(string.format("[SCAN] RS.%s → %s", table.concat(path, "."), status))
end

--==============================================================
-- 4. WORKSPACE TOP-LEVEL (looking for "Creature", "Area", etc.)
--==============================================================
print("\n========== [SCAN] Workspace top-level ==========")
for _, obj in ipairs(Workspace:GetChildren()) do
    print(string.format("[SCAN] Workspace.%s [%s]", obj.Name, obj.ClassName))
end

print("\n========== [SCAN] Looking for 'Creature' anywhere in Workspace ==========")
local foundCreature = false
for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj.Name:lower():find("creature") or obj.Name:lower():find("mob")
       or obj.Name:lower():find("enemy") or obj.Name:lower():find("npc") then
        foundCreature = true
        print(string.format("[SCAN] Match: %s [%s]", obj:GetFullName(), obj.ClassName))
        if foundCreature then break end  -- just first match
    end
end
if not foundCreature then
    print("[SCAN] No 'Creature' / 'Mob' / 'Enemy' / 'NPC' found in Workspace.")
end

--==============================================================
-- 5. CHAT SERVICE CHECK
--==============================================================
print("\n========== [SCAN] Chat service ==========")
local TCS = game:GetService("TextChatService")
print(string.format("[SCAN] TextChatService.CreateDefaultTextChannels = %s",
    tostring(TCS.CreateDefaultTextChannels)))
for _, obj in ipairs(TCS:GetChildren()) do
    print(string.format("[SCAN] TextChatService.%s [%s]", obj.Name, obj.ClassName))
end

-- Check for legacy chat remotes too
local legacyChat = game:GetService("Chat")
print(string.format("[SCAN] Legacy Chat service exists: %s", tostring(legacyChat ~= nil)))

--==============================================================
-- 6. PLAYER CHARACTER STRUCTURE (so we know what stats to override)
--==============================================================
print("\n========== [SCAN] Player character structure ==========")
local lp = Players.LocalPlayer
local char = lp.Character
if char then
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        print(string.format("[SCAN] Humanoid.WalkSpeed = %s", tostring(hum.WalkSpeed)))
        print(string.format("[SCAN] Humanoid.JumpPower = %s", tostring(hum.JumpPower)))
        print(string.format("[SCAN] Humanoid.UseJumpPower = %s", tostring(hum.UseJumpPower)))
        print(string.format("[SCAN] Humanoid.JumpHeight = %s", tostring(hum.JumpHeight)))
    end
    -- List any stat attributes or value objects on the character
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("NumberValue") or obj:IsA("IntValue") or obj:IsA("StringValue")
           or obj:IsA("BoolValue") then
            print(string.format("[SCAN] Character.%s [%s] = %s",
                obj.Name, obj.ClassName, tostring(obj.Value)))
        end
    end
    -- Attributes
    local attrs = char:GetAttributes()
    local n = 0
    for k, v in pairs(attrs) do
        n += 1
        print(string.format("[SCAN] Character attr %s = %s", k, tostring(v)))
    end
    if n == 0 then print("[SCAN] (no attributes on character)") end
else
    print("[SCAN] No character — spawn first then re-run.")
end

--==============================================================
-- 7. PLAYER LEADERSTATS (often where Muscle/Strength/Respect live)
--==============================================================
print("\n========== [SCAN] leaderstats ==========")
if lp:FindFirstChild("leaderstats") then
    for _, obj in ipairs(lp.leaderstats:GetChildren()) do
        print(string.format("[SCAN] leaderstats.%s [%s] = %s",
            obj.Name, obj.ClassName, tostring(obj.Value)))
    end
else
    print("[SCAN] No leaderstats folder.")
end

print("\n========== [SCAN] DONE — copy everything above and send it back ==========")
print("[SCAN] (Player name: " .. lp.Name .. " | Display: " .. (lp.DisplayName or "?") .. ")")
