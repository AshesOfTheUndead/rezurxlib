--[[
    🔍 V1100 DIAGNOSTIC BOOT
    Run this FIRST. It will print exactly what's happening at each step
    to the developer console (F9 → "Client" log tab).
    This tells us WHY nothing loads.
]]

print("\n========================================")
print("[V1100-DBG] Diagnostic boot started")
print("========================================")

--==============================================================
-- STEP 1: Check if game is loaded
--==============================================================
print("[V1100-DBG] Step 1: Checking game:IsLoaded()...")
local loaded = game:IsLoaded()
print("[V1100-DBG] game:IsLoaded() = " .. tostring(loaded))
if not loaded then
    print("[V1100-DBG] Waiting for game to load...")
    local t0 = tick()
    repeat task.wait(0.1) until game:IsLoaded()
    print(string.format("[V1100-DBG] Game loaded after %.2fs", tick() - t0))
end

--==============================================================
-- STEP 2: Check services
--==============================================================
print("\n[V1100-DBG] Step 2: Checking services...")
local ok_p, Players = pcall(function() return game:GetService("Players") end)
print("[V1100-DBG] Players service: " .. (ok_p and "OK" or "FAIL: " .. tostring(Players)))

local ok_lp, localPlayer = pcall(function() return Players.LocalPlayer end)
print("[V1100-DBG] LocalPlayer: " .. (ok_lp and localPlayer.Name or "FAIL: " .. tostring(localPlayer)))

--==============================================================
-- STEP 3: Test HttpGet — can we even reach the internet?
--==============================================================
print("\n[V1100-DBG] Step 3: Testing HttpGet to sirius.menu...")
local ok_http, http_result = pcall(function()
    return game:HttpGet('https://sirius.menu/rayfield')
end)
print("[V1100-DBG] HttpGet success: " .. tostring(ok_http))
if not ok_http then
    print("[V1100-DBG] HttpGet error: " .. tostring(http_result))
    print("[V1100-DBG] >>> This means your executor can't reach the internet,")
    print("[V1100-DBG] >>> OR sirius.menu is down. Try a different host below.")

    -- Try alternate Rayfield hosts
    local alt_hosts = {
        "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
        "https://rayfield.sirius.menu/v2/source.lua",
    }
    for _, url in ipairs(alt_hosts) do
        print("[V1100-DBG] Trying: " .. url)
        local ok2, r2 = pcall(function() return game:HttpGet(url) end)
        print("[V1100-DBG]   → " .. (ok2 and "OK (" .. #r2 .. " bytes)" or "FAIL: " .. tostring(r2)))
        if ok2 then http_result = r2 break end
    end
else
    print(string.format("[V1100-DBG] Got %d bytes from sirius.menu", #http_result))
end

--==============================================================
-- STEP 4: Try to loadstring the Rayfield source
--==============================================================
if http_result then
    print("\n[V1100-DBG] Step 4: Loading Rayfield source via loadstring...")
    local ok_ls, load_fn = pcall(function() return loadstring(http_result) end)
    print("[V1100-DBG] loadstring success: " .. tostring(ok_ls))
    if not ok_ls then
        print("[V1100-DBG] loadstring error: " .. tostring(load_fn))
        print("[V1100-DBG] >>> The Rayfield source has a syntax error or your executor's")
        print("[V1100-DBG] >>> loadstring is restricted. Check your executor settings.")
        return
    end

    print("[V1100-DBG] Step 5: Calling load_fn() to bootstrap Rayfield...")
    local ok_call, rayfield = pcall(load_fn)
    print("[V1100-DBG] Bootstrap success: " .. tostring(ok_call))
    if not ok_call then
        print("[V1100-DBG] Bootstrap error: " .. tostring(rayfield))
        print("[V1100-DBG] >>> Rayfield's internal init failed. Could be a Roblox version")
        print("[V1100-DBG] >>> mismatch or missing dependency in your executor.")
        return
    end
    print("[V1100-DBG] Rayfield object type: " .. typeof(rayfield))
    print("[V1100-DBG] Rayfield has CreateWindow: " .. tostring(rayfield and rayfield.CreateWindow ~= nil))

    if not rayfield or not rayfield.CreateWindow then
        print("[V1100-DBG] >>> Rayfield loaded but missing CreateWindow method!")
        return
    end

    --==============================================================
    -- STEP 6: Try to create the window
    --==============================================================
    print("\n[V1100-DBG] Step 6: Creating window...")
    local ok_w, window = pcall(function()
        return rayfield:CreateWindow({
            Name = "V1100 Debug Test",
            LoadingTitle = "Testing...",
            LoadingSubtitle = "If you see this, Rayfield works",
            ConfigurationSaving = { Enabled = false },
        })
    end)
    print("[V1100-DBG] CreateWindow success: " .. tostring(ok_w))
    if not ok_w then
        print("[V1100-DBG] CreateWindow error: " .. tostring(window))
        return
    end

    print("[V1100-DBG] Creating test tab...")
    local ok_t, tab = pcall(function() return window:CreateTab("Test") end)
    print("[V1100-DBG] CreateTab success: " .. tostring(ok_t))
    if not ok_t then
        print("[V1100-DBG] CreateTab error: " .. tostring(tab))
        return
    end

    print("[V1100-DBG] Creating test button...")
    pcall(function()
        tab:CreateButton({
            Name = "If you see this button, Rayfield is 100% working",
            Callback = function() print("[V1100-DBG] Test button clicked!") end,
        })
    end)

    print("[V1100-DBG] Sending notify...")
    pcall(function()
        window:Notify or rayfield:Notify({ Title = "V1100 Debug", Content = "Rayfield is working!", Duration = 6 })
    end)

    print("\n========================================")
    print("[V1100-DBG] DIAGNOSTIC COMPLETE")
    print("[V1100-DBG] If you see a Rayfield window with a 'Test' tab,")
    print("[V1100-DBG] Rayfield is 100% functional and the problem is")
    print("[V1100-DBG] somewhere in the V1100 script logic.")
    print("[V1100-DBG] Copy everything above this line and send it to me.")
    print("========================================\n")
else
    print("\n========================================")
    print("[V1100-DBG] CANNOT PROCEED — no Rayfield source available")
    print("[V1100-DBG] >>> Your executor cannot fetch Rayfield.")
    print("[V1100-DBG] >>> Possible causes:")
    print("[V1100-DBG] >>>   1. Executor doesn't have HTTP enabled")
    print("[V1100-DBG] >>>   2. Executor's HTTP is blocked by firewall/proxy")
    print("[V1100-DBG] >>>   3. sirius.menu and GitHub are both unreachable")
    print("[V1100-DBG] >>>   4. Executor restricts loadstring()")
    print("[V1100-DBG] >>>")
    print("[V1100-DBG] >>> Fix: check your executor's settings — look for")
    print("[V1100-DBG] >>> 'HttpGet', 'loadstring', or 'HTTP' permissions")
    print("[V1100-DBG] >>> and make sure they're all enabled.")
    print("========================================\n")
end
