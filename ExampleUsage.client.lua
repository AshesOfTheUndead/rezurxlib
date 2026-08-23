-- ============================================================
-- ExampleUsage.client.lua — Admin Panel built on RezurXLib v4.0
--
-- Put RezurXLib as a ModuleScript (e.g. ReplicatedStorage) and
-- this as a LocalScript. Every callback below is a placeholder —
-- wire each one into YOUR OWN server-validated RemoteEvents.
-- Nothing here touches the game directly.
--
-- NEW IN v4.0 (demonstrated below):
--   • Icon support (window Icon, tab icons, element Icons)
--   • ConfigurationSaving (auto-save toggles/sliders to file)
--   • KeySystem (optional key gate — see the commented block)
--   • Glass + Glow visuals, cursor glow, stagger animations
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lib = require(ReplicatedStorage:WaitForChild("RezurXLib"))

local Window = Lib:CreateWindow({
	Name            = "Admin Panel",
	Subtitle        = "Management Console · RezurXlab",
	LoadingTitle    = "RezurX lab",
	LoadingEnabled  = true,
	Theme           = "Ember",            -- "Ember" | "Ocean" | "Crimson" | "Slate" | "Midnight" | ...
	ToggleUIKeybind = Enum.KeyCode.K,     -- hide/show the whole UI
	Icon            = 4483362458,         -- [v4] asset id in the header badge (or "rbxassetid://…", or emoji text)

	-- [v4] Auto-save flagged elements to the executor's filesystem.
	-- Values restore automatically on the next run. Safe no-op in Studio.
	ConfigurationSaving = {
		Enabled   = true,
		FolderName = "RezurXHub",       -- default: RezurXLib/Configurations
		FileName  = "AdminPanel",       -- default: game.PlaceId
		Autosave  = true,               -- save only when values actually changed
		SaveOnUnload = true,            -- flush when the window is destroyed
		Notify    = true,               -- toast after restoring a saved config
	},

	-- [v4] Optional key gate. Uncomment to lock the panel behind a key.
	-- KeySystem = true,
	-- KeySettings = {
	--     Title    = "RezurX Hub",
	--     Subtitle = "Key System",
	--     Note     = "Get a key from our Discord: discord.gg/example",
	--     FileName = "AdminPanelKey",     -- saved under RezurXLib/Keys/
	--     SaveKey  = true,                -- remember accepted keys
	--     GrabKeyFromSite = false,        -- or fetch the key from a raw URL
	--     Key      = { "HELLO-1234" },    -- one or more accepted keys
	--     MaxAttempts = 5,                -- 0 = unlimited
	--     OnExhausted = "Lock",           -- "Lock" | "Kick" | "None"
	-- },
})

-- ============================================================
-- OVERVIEW
-- ============================================================
local Overview = Window:CreateTab("Overview", "📊")

Overview:CreateSection("System Status")
local statusPara = Overview:CreateParagraph({
	Title = "Status",
	Content = "System ready.\nBoot sequence: OK\nActive: Yes",
})

Overview:CreateSection("Quick Actions")
Overview:CreateButton({
	Name = "Refresh",
	Callback = function()
		statusPara:Set({ Content = "Refreshed at " .. os.date("%X") })
		Window:Notify({ Title = "Refresh", Content = "Panel data refreshed.", Duration = 2, Type = "success" })
	end,
})
Overview:CreateButton({
	Name = "Primary Action",
	Variant = "Primary",                     -- accent-filled with sheen sweep on hover
	Icon = 4483362458,                       -- [v4] optional asset icon on the button
	Callback = function()
		Window:Notify({ Title = "Done", Content = "Primary action executed.", Duration = 2 })
	end,
})
Overview:CreateButton({
	Name = "Help",
	Callback = function()
		Window:Notify({ Title = "Help", Content = "Documentation placeholder.", Duration = 3 })
	end,
})

Overview:CreateSection("Appearance [v4]")
Overview:CreateToggle({
	Name = "Animated accents",
	CurrentValue = true,
	Flag = "cfgAnimated",                    -- [v4] auto-saved via ConfigurationSaving
	Callback = function(value)
		print("Animated accents:", value)
	end,
})
Overview:CreateSlider({
	Name = "Glow intensity",
	Range = { 0, 100 },
	CurrentValue = 70,
	Increment = 5,
	Suffix = "%",
	Flag = "cfgGlow",
	Callback = function(value)
		print("Glow:", value)
	end,
})

-- ============================================================
-- PLAYERS — plain moderation UI. Hook the callbacks into your
-- own RemoteEvents; validate everything server-side.
-- ============================================================
local PlayersTab = Window:CreateTab("Players", "👥")

PlayersTab:CreateSection("Player Lookup")
local targetInput = PlayersTab:CreateInput({
	Name = "Player Name",
	CurrentValue = "",
	PlaceholderText = "Type an exact username…",
	ClearTextOnFocus = false,
	Callback = function(text)
		print("Lookup target:", text)
	end,
})

PlayersTab:CreateSection("Moderation")
PlayersTab:CreateToggle({
	Name = "Auto-confirm actions",
	CurrentValue = false,
	Flag = "modAutoConfirm",
	Callback = function(on)
		print("Auto-confirm:", on)
	end,
})
PlayersTab:CreateDropdown({
	Name = "Reason",
	Options = { "Spam", "Exploiting", "Bullying", "Other" },
	CurrentOption = "Spam",
	Searchable = true,                       -- works on mobile keyboards too (v4)
	Flag = "modReason",
	Callback = function(option)
		print("Reason:", option)
	end,
})
PlayersTab:CreateButton({
	Name = "Apply Moderation",
	Callback = function()
		Window:ShowModal({
			Title = "Confirm",
			Content = "Apply moderation to " .. (targetInput and "the selected player" or "nobody") .. "?",
			ConfirmText = "Apply",
			CancelText = "Cancel",
			ConfirmCallback = function()
				Window:Notify({ Title = "Moderation", Content = "Request sent (wire to your RemoteEvent).", Type = "success" })
			end,
		})
	end,
})

-- ============================================================
-- VISUALS — color/keybind showcase
-- ============================================================
local VisualsTab = Window:CreateTab("Visuals", "🎨")

VisualsTab:CreateSection("Theme")
VisualsTab:CreateColorPicker({
	Name = "Team color",
	Color = Color3.fromRGB(255, 122, 28),
	Presets = {
		Color3.fromRGB(255, 122, 28), Color3.fromRGB(46, 170, 240),
		Color3.fromRGB(48, 215, 92),  Color3.fromRGB(235, 64, 82),
	},
	Flag = "visTeamColor",
	Callback = function(color)
		print("Team color:", color)
	end,
})
VisualsTab:CreateKeybind({
	Name = "Quick toggle",
	CurrentKeybind = Enum.KeyCode.T,
	HoldToInteract = false,
	Flag = "visQuickKey",
	Callback = function()
		print("Quick action fired")
	end,
})

VisualsTab:CreateSection("Indicators")
local progress = VisualsTab:CreateProgress({ Title = "Upload", Value = 0, Suffix = "%" })
VisualsTab:CreateButton({
	Name = "Start upload",
	Callback = function()
		task.spawn(function()
			for i = 0, 100, 10 do
				progress:Set(i)
				task.wait(0.05)
			end
			Window:Notify({ Title = "Upload", Content = "Complete.", Type = "success" })
		end)
	end,
})
VisualsTab:CreateCarousel({
	Items = {
		{ Title = "Aurora", Content = "Glass + Glow is the v4 default look." },
		{ Title = "Depth",  Content = "Layered shadows and ambient accent glow." },
		{ Title = "Motion", Content = "Staggered tab entrances and sheen sweeps." },
	},
	Callback = function(item)
		print("Slide:", item.Title)
	end,
})

-- ============================================================
-- SETTINGS — library-provided panel (themes, motion, keybind)
-- ============================================================
Window:CreateSettingsPanel("Settings", "⚙")

-- Manual config control (also automatic via ConfigurationSaving above)
Window:SaveConfiguration()

print("[Example] RezurXLib v" .. Lib.Version .. " admin panel ready.")
