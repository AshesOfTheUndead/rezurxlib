-- ============================================================
-- RezurXLib Example.client.lua — v5.3.1
--
-- A tight worked example covering the full surface in <150 lines.
-- Drop this in a LocalScript under StarterPlayerScripts and put
-- RezurXLib.lua as a ModuleScript named "RezurXLib" under
-- ReplicatedStorage — OR run it in an executor with the loadstring
-- loader shown at the bottom.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Loader (pick one) ─────────────────────────────────────────
-- (a) Studio / ModuleScript:
local RezurXLib = require(ReplicatedStorage:WaitForChild("RezurXLib"))

-- (b) Executor:
-- local ok, src = pcall(function() return game:HttpGet(
--     "https://raw.githubusercontent.com/AshesOfTheUndead/rezurxlib/main/RezurXLib.lua"
-- ) end)
-- local RezurXLib = ok and loadstring(src)()
-- if not RezurXLib then return end
-- ──────────────────────────────────────────────────────────────

-- Optional: register a custom theme by name before any window uses it.
RezurXLib:RegisterTheme("Violet", {
    accent    = Color3.fromRGB(136, 105, 244),
    accentHi  = Color3.fromRGB(193, 174, 255),
    accentDim = Color3.fromRGB(88, 66, 170),
    secondary = Color3.fromRGB(244, 105, 192),
})

local Window = RezurXLib:CreateWindow({
    Name             = "Example Panel",
    Subtitle         = "v5.3.1 demo",
    LoadingTitle     = "EXAMPLE",
    LoadingEnabled   = true,
    Theme            = "Lava",                 -- Lava / Cyberpunk / Obsidian / Emerald / Quiet / Violet (above)
    ToggleUIKeybind  = Enum.KeyCode.K,
    Size             = { 520, 560 },
    Icon             = "rbxassetid://4483362458",   -- number id / URI / emoji
    Activity         = "running",             -- "running" | "paused" — header beacon
    QuickPause       = function(paused)       -- called from minimized pill
        print("[Example] quick pause:", paused)
    end,
    Sounds           = true,                 -- tactile click table
    BackdropBlur     = true,                 -- frost the world behind the window
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "RezurXExample",
        FileName   = "Panel",
    },
})

-- ── Tabs ──────────────────────────────────────────────────────
local Main = Window:CreateTab("Main", "🏠")
local Settings = Window:CreateTab("Settings", "⚙")
Window:CreateSettingsPanel()                  -- built-in: themes, motion, sounds

-- ── Section + components ──────────────────────────────────────
Main:CreateSection("Actions")
Main:CreateButton({
    Name     = "Run Task",
    Variant  = "Primary",
    Icon     = "rbxassetid://6031094678",
    Callback = function()
        Window:Notify({ Title = "Done", Content = "Task complete.", Duration = 4 })
    end,
})
Main:CreateToggle({
    Name         = "Auto-resume",
    CurrentValue = true,
    Flag         = "AutoResume",   -- auto-saved via ConfigurationSaving
    Callback     = function(on) print("[Example] auto-resume:", on) end,
})
Main:CreateSlider({
    Name      = "Workers",
    Range     = { 1, 200 },
    Increment = 1,
    CurrentValue = 25,
    Suffix    = " threads",
    Flag      = "Workers",
    Callback  = function(v) print("[Example] workers:", v) end,
})

Main:CreateSection("Selection")
Main:CreateDropdown({
    Name           = "Mode",
    Options        = { "Balanced", "Aggressive", "Stealth" },
    CurrentOption  = "Balanced",
    Searchable     = true,
    Flag           = "Mode",
    Callback       = function(opt) print("[Example] mode:", opt) end,
})
Main:CreateKeybind({
    Name           = "Panic key",
    CurrentKeybind = Enum.KeyCode.P,
    Callback       = function() print("[Example] panic!") end,
})
Main:CreateColorPicker({
    Name    = "Accent",
    Color   = Color3.fromRGB(255, 90, 90),
    Presets = { Color3.fromRGB(90, 200, 255), Color3.fromRGB(90, 255, 150) },
    Flag    = "Accent",
    Callback = function(c) print("[Example] accent:", c) end,
})

-- ── Live telemetry ────────────────────────────────────────────
Main:CreateSection("Telemetry")
local Grid = Main:AddStatGrid({ Columns = 2 })
local rateChip = Grid:AddChip({ Icon = "⚡", Label = "Rate", Value = "0/s" })
Grid:AddChip({ Icon = "📊", Label = "Workers", Value = "25" })
task.spawn(function()
    while true do
        task.wait(0.5)
        Grid:UpdateChip(rateChip, { Value = tostring(math.random(20, 80)) .. "/s" })
    end
end)

-- ── Settings tab ──────────────────────────────────────────────
Settings:CreateLabel("Tune the engine", nil, true)
Settings:CreateInput({
    Name           = "Owner tag",
    CurrentValue   = Players.LocalPlayer.Name,
    PlaceholderText = "Display name…",
    Flag           = "Owner",
})
Settings:CreateAccordion({
    Title = "Advanced",
    DefaultExpanded = false,
}):CreateToggle({
    Name         = "Debug logging",
    CurrentValue = false,
    Flag         = "Debug",
})
Settings:CreateButton({
    Name     = "Reset configuration",
    Variant  = "Secondary",
    Callback = function()
        Window:ShowModal({
            Title         = "Reset configuration?",
            Content       = "Restores all flags to their defaults.",
            ConfirmText   = "Reset",
            CancelText    = "Cancel",
            ConfirmCallback = function()
                for flag, _ in pairs(RezurXLib.Flags) do
                    local obj = RezurXLib.Flags[flag]
                    if obj and obj.Reset then pcall(obj.Reset, obj) end
                end
            end,
        })
    end,
})

-- ── Restore on next run ───────────────────────────────────────
Window:LoadConfiguration()

print("[Example] RezurXLib v" .. RezurXLib.Version .. " ready. Press K to toggle.")
