-- ============================================================
-- LIBRARY-LEVEL API
-- ============================================================
function Library:Notify(cfg)
        if Library._lastWindow then
                return Library._lastWindow:Notify(cfg)
        end
        warn("[RezurXLib] Notify called before any window exists.")
end

function Library:ModifyTheme(theme)
        for _, w in ipairs(Library._windows) do
                w:ModifyTheme(theme)
        end
end

-- Registers an immutable-by-convention palette name. Missing tokens inherit
-- from Quiet, so a custom theme can override only the colours it owns.
function Library:RegisterTheme(name, palette)
        if type(name) ~= "string" or name == "" or type(palette) ~= "table" then
                warn("[RezurXLib] RegisterTheme expects a non-empty name and a palette table.")
                return nil
        end
        local merged = cloneTheme(Themes.Quiet)
        for key, value in pairs(palette) do
                if ThemeTokenSet[key] and typeof(value) == "Color3" then
                        merged[key] = value
                else
                        warn("[RezurXLib] Ignoring invalid theme token: " .. tostring(key))
                end
        end
        -- [v5.5.1] Complete the palette: a custom theme without `secondary`
        -- would leave C.secondary nil at CreateWindow and crash every
        -- C.secondary gradient keypoint ("bad ColorSequence keypoint").
        if typeof(merged.secondary) ~= "Color3" then
                merged.secondary = typeof(merged.accentHi) == "Color3" and merged.accentHi or merged.accent
        end
        Themes[name] = merged
        return cloneTheme(merged)
end

function Library:GetTheme(name)
        local palette = Themes[name]
        return palette and cloneTheme(palette) or nil
end

-- A tiny local image registry avoids repeated asset-id plumbing. It performs
-- no preload, request, or network operation; it only remembers identifiers
-- supplied by the developer in this client session.
Library.ImageCache = {}
function Library:RegisterImage(key, image)
        if type(key) ~= "string" or key == "" then
                warn("[RezurXLib] RegisterImage expects a non-empty string key.")
                return nil
        end
        local resolved = type(image) == "number" and ("rbxassetid://" .. image) or tostring(image or "")
        self.ImageCache[key] = resolved
        return resolved
end

function Library:ResolveImage(image)
        if type(image) == "number" then return "rbxassetid://" .. image end
        if type(image) == "string" then return self.ImageCache[image] or image end
        return ""
end

function Library:ClearImageCache(key)
        if key == nil then
                table.clear(self.ImageCache)
        else
                self.ImageCache[key] = nil
        end
end

function Library:GetThemeNames()
        local names = {}
        for name in pairs(Themes) do table.insert(names, name) end
        table.sort(names)
        return names
end

function Library:SetReducedMotion(nextValue)
        self.Options.ReducedMotion = nextValue == true
        for _, window in ipairs(self._windows) do
                window:SetReducedMotion(self.Options.ReducedMotion)
        end
        return self.Options.ReducedMotion
end

function Library:Destroy()
        -- [FIX v4.0] Iterate BACKWARDS (or over a snapshot): w:Destroy()
        -- removes each window from _windows mid-ipairs, which used to skip
        -- every second window and leak its connections + ScreenGui.
        for i = #Library._windows, 1, -1 do
                local w = Library._windows[i]
                pcall(function() w:Destroy() end)
        end
        table.clear(Library._windows)
        Library._lastWindow = nil
end
-- ============================================================
-- LIBRARY-LEVEL UTILITIES
-- ============================================================
function Library:DeepCopy(orig)
        local copy
        if type(orig) == "table" then
                copy = {}
                for k, v in next, orig, nil do copy[self:DeepCopy(k)] = self:DeepCopy(v) end
                setmetatable(copy, self:DeepCopy(getmetatable(orig)))
        else copy = orig end
        return copy
end

function Library:Serialize(data)
        local ok, result = pcall(function() return HttpService:JSONEncode(data) end)
        if ok then return result else warn("[RezurXLib] Serialize: " .. tostring(result)) return nil end
end

function Library:Deserialize(jsonStr)
        if type(jsonStr) ~= "string" then return nil end
        local ok, result = pcall(function() return HttpService:JSONDecode(jsonStr) end)
        if ok then return result else warn("[RezurXLib] Deserialize: " .. tostring(result)) return nil end
end

function Library:SaveConfiguration()
        local config = {}
        for flag, obj in pairs(self.Flags) do
                if obj.CurrentValue ~= nil then config[flag] = obj.CurrentValue
                elseif obj.CurrentKeybind ~= nil then config[flag] = keyName(obj.CurrentKeybind)
                elseif obj.Color ~= nil then local c = obj.Color config[flag] = { R=c.R, G=c.G, B=c.B }
                elseif obj.CurrentOption ~= nil then config[flag] = obj.CurrentOption end
        end
        return config
end

function Library:LoadConfiguration(config)
        if type(config) ~= "table" then warn("[RezurXLib] LoadConfiguration expects table") return end
        for flag, value in pairs(config) do
                local obj = self.Flags[flag]
                if obj and obj.Set then
                        pcall(function()
                                if type(value) == "table" and value.R then obj:Set(Color3.new(value.R, value.G, value.B))
                                elseif type(value) == "string" and value:match("^%u[%u%d]+$") then
                                        local ok, kc = pcall(function() return Enum.KeyCode[value] end)
                                        if ok and kc then obj:Set(kc) end
                                else obj:Set(value) end
                        end)
                end
        end
end

function Library:HasFlag(flag) return self.Flags[flag] ~= nil end

function Library:GetFlag(flag)
        local obj = self.Flags[flag]
        if obj then
                if obj.CurrentValue ~= nil then return obj.CurrentValue
                elseif obj.Color ~= nil then return obj.Color
                elseif obj.CurrentKeybind ~= nil then return obj.CurrentKeybind
                elseif obj.CurrentOption ~= nil then return obj.CurrentOption end
        end
        return nil
end

function Library:ColorLighten(color, amount)
        amount = amount or 0.2
        local h, s, v = color:ToHSV()
        return Color3.fromHSV(h, s, math.min(v + amount, 1))
end

function Library:ColorDarken(color, amount)
        amount = amount or 0.2
        local h, s, v = color:ToHSV()
        return Color3.fromHSV(h, s, math.max(v - amount, 0))
end

function Library:GetStats()
        local flagCount = 0
        for _ in pairs(self.Flags) do flagCount = flagCount + 1 end
        return { Version = self.Version, WindowCount = #self._windows, FlagCount = flagCount,
                Themes = self:GetThemeNames() }
end

-- Machine-readable API metadata enables an in-game help tab without a
-- network request, generated docs page, or a separate dependency.
function Library:GetDocs()
        return {
                Version = self.Version,
                Components = {
                        { Name = "CreateSection", Params = "text", Returns = ":Set", Description = "Uppercase section label." },
                        { Name = "CreateDivider", Params = "text", Returns = "object", Description = "Optional-caption rule." },
                        { Name = "CreateSpacer", Params = "pixels", Returns = "object", Description = "Fixed vertical gap." },
                        { Name = "CreateLabel", Params = "Text, Color, Bold, TextSize, Align", Returns = ":Set, :SetColor", Description = "Static text line." },
                        { Name = "CreateParagraph", Params = "Title, Content", Returns = "object", Description = "Wrapped title and description." },
                        { Name = "CreateImage", Params = "Image, Height, ScaleType, CornerRadius, Tooltip", Returns = "object", Description = "Image or icon content." },
                        { Name = "CreateButton", Params = "Name, Variant, Callback, Tooltip", Returns = "object", Description = "Animated primary or secondary action button." },
                        { Name = "CreateMultiButton", Params = "Buttons, Tooltip", Returns = "object", Description = "Shared-row actions." },
                        { Name = "CreateToggle", Params = "Name, CurrentValue, Callback, Flag", Returns = ":Set, :Get, :Reset", Description = "Animated boolean switch." },
                        { Name = "CreateSlider", Params = "Name, Range, CurrentValue, Increment, Suffix, Callback, Flag", Returns = ":Set, :Get, :Reset", Description = "Pointer and touch slider." },
                        { Name = "CreateInput", Params = "Name, CurrentValue, PlaceholderText, Callback, Flag", Returns = ":Set, :Get, :Reset", Description = "Single-line input." },
                        { Name = "CreateDropdown", Params = "Name, Options, CurrentOption, MultipleOptions, Searchable, Tooltip, Callback, Flag", Returns = ":Set, :Get, :Refresh, :Reset", Description = "Scale-aware single or multi-select with fuzzy search." },
                        { Name = "CreateKeybind", Params = "Name, CurrentKeybind, HoldToInteract, Callback, ChangedCallback, Flag", Returns = ":Set, :Get, :Reset", Description = "Keyboard binding capture with rebind callback." },
                        { Name = "CreateColorPicker", Params = "Name, Color, Presets, Callback, Flag", Returns = ":Set, :Get, :Reset", Description = "Live HSV picker and preset swatches." },
                        { Name = "CreateAccordion", Params = "Title, DefaultExpanded, Tooltip", Returns = "object", Description = "Collapsible content container." },
                        { Name = "CreateBindable", Params = "Name, Keybind, Enabled, Callback, Flag", Returns = ":SetEnabled, :SetKeybind", Description = "Enableable shortcut." },
                        { Name = "CreateNotice", Params = "Title, Content, Type, Height, Tooltip", Returns = ":Set, :SetType", Description = "Durable inline callout." },
                        { Name = "CreateProgress", Params = "Title, Value, Min, Max, Suffix, Callback, Flag", Returns = ":Set, :Get, :Reset", Description = "Live progress meter." },
                        { Name = "CreateSpinner", Params = "Title, Detail, Running, Tooltip, Flag", Returns = ":Start, :Stop, :Set, :Get", Description = "On-demand loading indicator." },
                        { Name = "CreateCarousel", Params = "Items, CurrentIndex, Callback, Tooltip, Flag", Returns = ":Next, :Previous, :SetItems, :Get", Description = "Compact rotating content." },
                        { Name = "CreateContextMenu", Params = "Name, ButtonText, Items, Tooltip, Flag", Returns = ":Open, :Close, :SetItems", Description = "On-demand action menu." },
                        { Name = "CreateStatus", Params = "Title, Text, State, Detail, Value, Flag", Returns = ":Set, :Get", Description = "Status indicator." },
                        { Name = "CreateGraph", Params = "Name, Max, Bars, Height, Suffix, Sample, RefreshRate, Tooltip, Flag", Returns = ":Push, :Reset, :SetMax, :Get", Description = "[v4.4] Live sparkline graph: push values (or auto-sample) and watch the trend scroll." },
                        { Name = "AddStatGrid", Params = "Columns, UpdateRate, ChipHeight, Flag, Tooltip", Returns = ":AddChip, :UpdateChip, :RemoveChip, :GetChipCount", Description = "[v5.2] Universal telemetry grid: auto-wrapping metric chips (Icon/Label/Value) with live UpdateChip calls or Sample auto-polling." },
                        { Name = "CreateCodeBlock", Params = "Title, Content, CopyCallback, Height", Returns = ":Set, :Get", Description = "Monospace copyable content." },
                        { Name = "CreateTable", Params = "Title, Columns, Rows, OnRowActivated, Height", Returns = ":SetRows, :GetRows", Description = "Compact data grid." },
                        { Name = "CreateTextArea", Params = "Title, Text, Placeholder, Callback, Flag", Returns = ":Set, :Get, :Reset", Description = "Multi-line input." },
                },
                Window = {
                        { Name = "CreateTab", Params = "name, optional icon (emoji text or asset id/URI)", Returns = "Tab (:SetTitle, :SetIcon)", Description = "Tab with a measured, horizontally scrolling rail; icons may be emoji text or image assets." },
                        { Name = "SaveConfiguration", Params = "", Returns = "table", Description = "With ConfigurationSaving enabled: write this window's flagged values to disk (JSON)." },
                        { Name = "LoadConfiguration", Params = "", Returns = "appliedCount", Description = "With ConfigurationSaving enabled: read and replay saved values onto elements." },
                        { Name = "SetBrandText", Params = "text (up to four UTF-8 characters)", Returns = "applied text", Description = "Sets the compact header badge; emoji and symbols are preserved." },
                        { Name = "GetBrandText", Params = "", Returns = "text", Description = "Gets the current compact header badge text." },
                        { Name = "SetRestoreText", Params = "text (up to four UTF-8 characters)", Returns = "applied text", Description = "Sets the floating restore button shown after Close." },
                        { Name = "GetRestoreText", Params = "", Returns = "text", Description = "Gets the current floating restore button text." },
                        { Name = "Notify", Params = "Title, Content, Duration, Type, Actions", Returns = "toast" },
                        { Name = "ShowModal", Params = "Title, Content, ConfirmText, CancelText, ConfirmCallback, CancelCallback", Returns = ":Confirm, :Cancel, :Close", Description = "Confirmation dialog." },
                        { Name = "ModifyTheme", Params = "name or palette", Returns = "palette" },
                        { Name = "CreateSettingsPanel", Params = "Name, Icon", Returns = "Tab" },
                        { Name = "SetToggleKeybind", Params = "Enum.KeyCode or key name", Returns = "Enum.KeyCode" },
                        { Name = "OpenCommandPalette", Params = "", Returns = "overlay" },
                },
                Library = {
                        { Name = "CreateWindow", Params = "Name/Title, Theme (incl. Lava/Cyberpunk/Obsidian/Emerald), CustomTheme, Size, Host, Parent, Accessibility, Icon, KeySystem, KeySettings, ConfigurationSaving, Sounds, BackdropBlur, Density, DisplayOrder, ShadowImage, Activity, QuickPause", Returns = "Window" },
                        { Name = "RegisterTheme", Params = "name, palette", Returns = "palette" },
                        { Name = "RegisterImage", Params = "key, imageId", Returns = "string" },
                        { Name = "SaveConfiguration", Params = "", Returns = "table" },
                        { Name = "LoadConfiguration", Params = "table", Returns = "nil" },
                        { Name = "GetDocs", Params = "", Returns = "table" },
                        { Name = "SetReducedMotion", Params = "boolean", Returns = "boolean" },
                },
                New = {
                        { Name = "Icon Support", Params = "Window Icon / tab icon / element Icon: number asset id, rbxassetid:// URI, or emoji text", Returns = "", Description = "Rayfield-style asset icons on the topbar badge, tabs, and every core element — with emoji fallback, no remote icon atlas required." },
                        { Name = "ConfigurationSaving", Params = "Enabled, FolderName, FileName, Autosave, SaveOnUnload, Notify", Returns = "", Description = "Auto-saves flagged elements to JSON on the executor filesystem. Signature-diffed writes (no rewrite storms), per-window isolation, load-replay on boot, flush on destroy." },
                        { Name = "KeySystem", Params = "KeySettings = Title, Subtitle, Note, FileName, SaveKey, GrabKeyFromSite, Key, MaxAttempts, OnExhausted", Returns = "", Description = "Styled key gate shown before the window. Exact-match validation, elastic shake on wrong keys, saved-key skip, optional HTTP key fetch, Lock/Kick/None on exhaustion." },
                        { Name = "Glass + Glow visuals", Params = "AnimatedAccents = true (opt-in ambient loops)", Returns = "", Description = "Layered depth shadows with a subtle accent rim, spring entrance, staggered tab-open settles, and drag-lift depth. Ambient pulse loops are opt-in." },
                },
        }
end

-- [v5.0.0] Test/inspection hook: live spring count (used by the headless
-- suite to verify the motion budget). Not part of the public API contract.
Library._springCount = function()
        return Spring.count
end

if type(_G) == "table" then
        _G.RezurXLib = Library
end

return Library

