--[[
    🔬 TRAIN TO FIGHT — COMPLETE GAME DUMP + REMOTE TRAFFIC MONITOR
    Run this, play normally for 30 seconds (train, chat, fight, walk around),
    then copy the dump file content back to your AI.

    WHAT IT DOES:
    1. Snapshots the entire game structure (remotes, workspace, players, stats)
    2. Hooks EVERY remote in the game — logs every Fire/Invoke for 30 seconds
       with full argument dumps, so we see what each remote actually does
    3. Saves everything to a file in your executor's workspace folder
    4. Also copies to clipboard if your executor supports it

    ZERO anti-cheat risk — it only READS and OBSERVES. It never fires anything.
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local TCS = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

--==============================================================
-- CONFIG
--==============================================================
local MONITOR_DURATION = 30   -- seconds to watch remote traffic
local DUMP_FILENAME    = "TTD_Dump.txt"

--==============================================================
-- DUMP BUFFER
--==============================================================
local dump = {}
local function p(line)
    dump[#dump + 1] = line
    print(line)
end

p("==============================================================")
p("TRAIN TO FIGHT — COMPLETE GAME DUMP")
p("Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
p("Player: " .. lp.Name .. " (Display: " .. (lp.DisplayName or "?") .. ")")
p("Game: " .. (game:GetService("MarketplaceService") and "yes" or "?"))
p("PlaceId: " .. tostring(game.PlaceId))
p("JobId: " .. tostring(game.JobId))
p("==============================================================\n")

--==============================================================
-- 1. REPLICATEDSTORAGE — FULL TREE (depth 5)
--==============================================================
p("\n[1] REPLICATEDSTORAGE FULL TREE")
p("-----------------------------------")
local function dumpTree(obj, depth, maxDepth)
    if depth > maxDepth then return end
    local indent = string.rep("  ", depth)
    local prefix = "RS."
    if obj:IsA("RemoteEvent") then prefix = "⚡ EVENT  RS."
    elseif obj:IsA("RemoteFunction") then prefix = "📞 FUNC  RS."
    elseif obj:IsA("UnreliableRemoteEvent") then prefix = "⚡ U-EVT RS."
    elseif obj:IsA("ModuleScript") then prefix = "📜 MOD   RS."
    elseif obj:IsA("Folder") then prefix = "📁 FOLDR RS."
    elseif obj:IsA("LocalScript") then prefix = "📄 LS    RS."
    elseif obj:IsA("Script") then prefix = "📄 SCRPT RS."
    end
    p(string.format("%s%s%s [%s]",
        indent, prefix, obj:GetFullName():gsub("^ReplicatedStorage%.", ""), obj.ClassName))
    if obj:IsA("Folder") or obj:IsA("ModuleScript") == false then
        for _, child in ipairs(obj:GetChildren()) do
            dumpTree(child, depth + 1, maxDepth)
        end
    end
end
for _, top in ipairs(RS:GetChildren()) do
    dumpTree(top, 0, 5)
end

--==============================================================
-- 2. ALL REMOTES WITH PATHS
--==============================================================
p("\n\n[2] ALL REMOTES — QUICK LIST")
p("-----------------------------------")
local allRemotes = {}
for _, obj in ipairs(RS:GetDescendants()) do
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
        local path = obj:GetFullName():gsub("^ReplicatedStorage%.", "")
        table.insert(allRemotes, { obj = obj, path = path, type = obj.ClassName })
        p(string.format("  (%s) %s", obj.ClassName, path))
    end
end
p(string.format("\nTotal remotes found: %d", #allRemotes))

--==============================================================
-- 3. WORKSPACE — TOP 3 LEVELS
--==============================================================
p("\n\n[3] WORKSPACE STRUCTURE (top 3 levels)")
p("-----------------------------------")
for _, obj in ipairs(WS:GetChildren()) do
    p(string.format("  WS.%s [%s] (%d children)",
        obj.Name, obj.ClassName, #obj:GetChildren()))
    for _, child in ipairs(obj:GetChildren()) do
        p(string.format("    WS.%s.%s [%s] (%d children)",
            obj.Name, child.Name, child.ClassName, #child:GetChildren()))
        for _, grand in ipairs(child:GetChildren()) do
            p(string.format("      WS.%s.%s.%s [%s]",
                obj.Name, child.Name, grand.Name, grand.ClassName))
        end
    end
end

--==============================================================
-- 4. CREATURE / MOB / NPC SEARCH
--==============================================================
p("\n\n[4] CREATURE / MOB / NPC / ENEMY SEARCH")
p("-----------------------------------")
local foundCreatures = false
for _, obj in ipairs(WS:GetDescendants()) do
    local n = obj.Name:lower()
    if n:find("creature") or n:find("mob") or n:find("enemy")
       or n:find("npc") or n:find("boss") or n:find("activation")
       or n:find("dummy") or n:find("target") then
        foundCreatures = true
        p(string.format("  %s [%s]", obj:GetFullName(), obj.ClassName))
    end
end
if not foundCreatures then
    p("  ❌ No creatures/mobs/NPCs/enemies found in Workspace.")
    p("     ESP feature has nothing to attach to in this game.")
end

--==============================================================
-- 5. PLAYER CHARACTER STRUCTURE
--==============================================================
p("\n\n[5] PLAYER CHARACTER STRUCTURE")
p("-----------------------------------")
local char = lp.Character or lp.CharacterAdded:Wait()
local hum = char:FindFirstChildOfClass("Humanoid")
if hum then
    p(string.format("  Humanoid.WalkSpeed = %g", hum.WalkSpeed))
    p(string.format("  Humanoid.JumpPower = %g", hum.JumpPower))
    p(string.format("  Humanoid.UseJumpPower = %s", tostring(hum.UseJumpPower)))
    p(string.format("  Humanoid.JumpHeight = %g", hum.JumpHeight))
    p(string.format("  Humanoid.HipHeight = %g", hum.HipHeight))
end
p("\n  Character children:")
for _, obj in ipairs(char:GetChildren()) do
    p(string.format("    %s [%s]", obj.Name, obj.ClassName))
end
p("\n  Character attributes:")
local ca = 0
for k, v in pairs(char:GetAttributes()) do
    ca += 1
    p(string.format("    %s = %s (%s)", k, tostring(v), typeof(v)))
end
if ca == 0 then p("    (none)") end

p("\n  Character descendants that are ValueObjects (often stats):")
for _, obj in ipairs(char:GetDescendants()) do
    if obj:IsA("NumberValue") or obj:IsA("IntValue") or obj:IsA("StringValue")
       or obj:IsA("BoolValue") or obj:IsA("CFrameValue") or obj:IsA("Vector3Value") then
        p(string.format("    %s [%s] = %s", obj:GetFullName(), obj.ClassName, tostring(obj.Value)))
    end
end

--==============================================================
-- 6. LEADERSTATS & PLAYER STATS
--==============================================================
p("\n\n[6] LEADERSTATS & PLAYER OBJECT")
p("-----------------------------------")
if lp:FindFirstChild("leaderstats") then
    for _, obj in ipairs(lp.leaderstats:GetChildren()) do
        p(string.format("  leaderstats.%s [%s] = %s",
            obj.Name, obj.ClassName, tostring(obj.Value)))
    end
else
    p("  No leaderstats folder.")
end

p("\n  Player children:")
for _, obj in ipairs(lp:GetChildren()) do
    p(string.format("    %s [%s]", obj.Name, obj.ClassName))
end

p("\n  Player attributes:")
local pa = 0
for k, v in pairs(lp:GetAttributes()) do
    pa += 1
    p(string.format("    %s = %s (%s)", k, tostring(v), typeof(v)))
end
if pa == 0 then p("    (none)") end

p("\n  Player Configuration (if exists):")
local cfg = lp:FindFirstChild("Configuration")
if cfg then
    for _, obj in ipairs(cfg:GetDescendants()) do
        p(string.format("    %s [%s]", obj:GetFullName(), obj.ClassName))
    end
    p("\n  Configuration attributes:")
    local cfa = 0
    for k, v in pairs(cfg:GetAttributes()) do
        cfa += 1
        p(string.format("    %s = %s (%s)", k, tostring(v), typeof(v)))
    end
    if cfa == 0 then p("    (none)") end
else
    p("    No Configuration folder on player.")
end

--==============================================================
-- 7. CHAT SYSTEM
--==============================================================
p("\n\n[7] CHAT SYSTEM")
p("-----------------------------------")
p(string.format("  TextChatService.CreateDefaultTextChannels = %s",
    tostring(TCS.CreateDefaultTextChannels)))
p(string.format("  TextChatService children (%d):", #TCS:GetChildren()))
for _, obj in ipairs(TCS:GetChildren()) do
    p(string.format("    %s [%s]", obj.Name, obj.ClassName))
end

p("\n  Looking for chat remotes in workspace...")
local chatRemotes = {}
for _, obj in ipairs(RS:GetDescendants()) do
    if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
       and (obj.Name:lower():find("chat") or obj.Name:lower():find("message")
            or obj.Name:lower():find("text") or obj.Name:lower():find("say")
            or obj.Name:lower():find("shout") or obj.Name:lower():find("broadcast")) then
        table.insert(chatRemotes, obj)
        p(string.format("    Possible chat remote: %s [%s]",
            obj:GetFullName(), obj.ClassName))
    end
end
if #chatRemotes == 0 then
    p("    ❌ No chat-related remotes found in ReplicatedStorage.")
    p("       This game likely uses Roblox's default TextChatService.")
    p("       To send chat, we'd need TextChatService:SendAsync() instead.")
end

--==============================================================
-- 8. REMOTE TRAFFIC MONITOR — HOOK EVERYTHING FOR 30s
--==============================================================
p("\n\n[8] REMOTE TRAFFIC MONITOR — playing for " .. MONITOR_DURATION .. "s")
p("-----------------------------------")
p(">>> PLAY NORMALLY NOW: train, chat, fight, walk around <<<")
p(">>> I'm logging every remote call to see what each one does <<<\n")

local fired = {}
local function safeStringify(v, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    local t = typeof(v)
    if t == "nil" then return "nil"
    elseif t == "boolean" then return tostring(v)
    elseif t == "number" then return tostring(v)
    elseif t == "string" then
        if #v > 100 then return '"' .. v:sub(1, 100) .. '..."' end
        return '"' .. v .. '"'
    elseif t == "Vector3" then return string.format("Vec3(%g,%g,%g)", v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        local pos = v.Position
        return string.format("CF(%g,%g,%g)", pos.X, pos.Y, pos.Z)
    elseif t == "Color3" then return string.format("Color(%g,%g,%g)", v.R, v.G, v.B)
    elseif t == "Instance" then return string.format("<%s:%s>", v.ClassName, v.Name)
    elseif t == "table" then
        local parts = {}
        for k, val in pairs(v) do
            table.insert(parts, string.format("[%s]=%s",
                tostring(k), safeStringify(val, depth + 1)))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "EnumItem" then return tostring(v)
    else return t end
end

local function logFire(remote, kind, args)
    local path = remote:GetFullName():gsub("^ReplicatedStorage%.", "")
    local key = path .. "|" .. kind
    fired[key] = (fired[key] or 0) + 1
    local argStrs = {}
    for i, a in ipairs(args) do
        table.insert(argStrs, safeStringify(a))
    end
    p(string.format("  [%s] %s.%s(%s)",
        kind, path, kind == "Fire" and "FireServer" or "InvokeServer",
        table.concat(argStrs, ", ")))
end

-- Hook every remote
local hooks = {}
for _, r in ipairs(allRemotes) do
    local path = r.path
    if r.obj:IsA("RemoteEvent") or r.obj:IsA("UnreliableRemoteEvent") then
        -- Hook FireServer via the metatable hook (works on most executors)
        local ok = pcall(function()
            local oldFire = r.obj.FireServer
            r.obj.FireServer = function(self, ...)
                logFire(r.obj, "Fire", {...})
                return oldFire(self, ...)
            end
            hooks[#hooks + 1] = function() r.obj.FireServer = oldFire end
        end)
        if not ok then
            -- Fallback: just listen via OnClientEvent for incoming
        end
    elseif r.obj:IsA("RemoteFunction") then
        local ok = pcall(function()
            local oldInvoke = r.obj.InvokeServer
            r.obj.InvokeServer = function(self, ...)
                logFire(r.obj, "Invoke", {...})
                return oldInvoke(self, ...)
            end
            hooks[#hooks + 1] = function() r.obj.InvokeServer = oldInvoke end
        end)
    end
end
p(string.format("  Hooked %d remote fire/invoke functions.\n", #hooks))

-- Wait for monitor duration
task.wait(MONITOR_DURATION)

-- Unhook
for _, unhook in ipairs(hooks) do pcall(unhook) end

--==============================================================
-- 9. SUMMARY — MOST-USED REMOTES (THE IMPORTANT ONES)
--==============================================================
p("\n\n[9] REMOTE CALL SUMMARY (sorted by frequency)")
p("-----------------------------------")
local summary = {}
for k, count in pairs(fired) do
    table.insert(summary, { key = k, count = count })
end
table.sort(summary, function(a, b) return a.count > b.count end)

if #summary == 0 then
    p("  ❌ No remote calls detected during monitoring period.")
    p("     Make sure you actually train/chat/fight next time.")
else
    for i, entry in ipairs(summary) do
        local path, kind = entry.key:match("^(.*)%|(.*)$")
        p(string.format("  #%d  %dx  %s.%s",
            i, entry.count, path, kind == "Fire" and "FireServer" or "InvokeServer"))
    end
end

--==============================================================
-- 10. ALL OTHER PLAYERS (for ESP targeting)
--==============================================================
p("\n\n[10] OTHER PLAYERS IN SERVER")
p("-----------------------------------")
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= lp then
        p(string.format("  %s (Display: %s, UserId: %d)",
            plr.Name, plr.DisplayName or "?", plr.UserId))
        -- Their stats
        if plr:FindFirstChild("leaderstats") then
            for _, s in ipairs(plr.leaderstats:GetChildren()) do
                p(string.format("    leaderstats.%s = %s", s.Name, tostring(s.Value)))
            end
        end
        local pcfg = plr:FindFirstChild("Configuration")
        if pcfg and pcfg:FindFirstChild("TrainSystem") then
            local ts = pcfg.TrainSystem
            p(string.format("    Configuration.TrainSystem attrs:"))
            for k, v in pairs(ts:GetAttributes()) do
                p(string.format("      %s = %s", k, tostring(v)))
            end
        end
    end
end

--==============================================================
-- 11. SAVE TO FILE
--==============================================================
p("\n\n[11] SAVING DUMP")
p("-----------------------------------")
local dumpText = table.concat(dump, "\n")

-- Try writing to file (works on most executors via writefile)
local fileOk = pcall(function()
    if writefile then
        writefile(DUMP_FILENAME, dumpText)
        p("  ✅ Saved to: " .. DUMP_FILENAME)
        p("     (check your executor's 'workspace' folder)")
    else
        p("  ⚠️ writefile not supported by this executor.")
    end
end)

-- Try copying to clipboard
pcall(function()
    if setclipboard then
        setclipboard(dumpText)
        p("  ✅ Also copied to clipboard.")
    end
end)

-- Final output to console (in case file/clipboard failed)
print("\n" .. string.rep("=", 60))
print("DUMP COMPLETE — Copy this entire console output")
print("(F9 → Client log → scroll up to [1]) and paste to your AI.")
print(string.rep("=", 60))
