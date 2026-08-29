-- ============================================================
-- [v5.7.0 AURORA] ICON ENGINE — images first, drawn vector fallback.
--
-- Resolution order for an icon value:
--   number          -> "rbxassetid://<n>"          (image)
--   "rbxassetid://…", "rbxasset://…", "rbxthumb://…",
--   "https://…", "http://…"                        (image; http URLs
--                      flow through the NetImage pipeline and fall back
--                      to a drawn glyph if the download fails)
--   registered name -> Library:RegisterIcon entry  (image or glyph)
--   builtin name    -> the vector glyph table G    (drawn)
--   anything else   -> nil (caller decides; setIcon draws a dot + warns)
--
-- Vector glyphs are tiny op-lists rendered with plain Frames at 1/24
-- scale, so the default icon set needs zero assets and zero requests:
--   {"b", x, y, w, h, rot}  filled bar/box (optionally rotated)
--   {"d", x, y, r}           filled dot
--   {"r", x, y, r, thick}    ring (stroke)
--   {"o", x, y, w, h, cr, rot} outlined rounded rect (stroke)
-- All coordinates live in a 24×24 box.
-- ============================================================
local function isHttpUrl(value)
        if type(value) ~= "string" then return false end
        return string.sub(value, 1, 8) == "https://" or string.sub(value, 1, 7) == "http://"
end

local G = {}
-- Core UI
G.dot   = { {"d",12,12,6} }
G.check = { {"b",7,13.5,6.5,2.6,45}, {"b",14,10.5,11,2.6,-45} }
G.cross = { {"b",12,12,13,2.6,45}, {"b",12,12,13,2.6,-45} }
G.info  = { {"d",12,6.5,3.4}, {"b",12,14.5,2.6,9} }
G.warn  = { {"b",12,9.5,2.6,9}, {"d",12,17.5,3.4} }
G.chevronDown = { {"b",8.5,10.5,7.5,2.6,45}, {"b",15.5,10.5,7.5,2.6,-45} }
G.chevronUp   = { {"b",8.5,13.5,7.5,2.6,-45}, {"b",15.5,13.5,7.5,2.6,45} }
G.chevronLeft = { {"b",13.5,8.5,7.5,2.6,135}, {"b",13.5,15.5,7.5,2.6,-135} }
G.chevronRight= { {"b",10.5,8.5,7.5,2.6,45}, {"b",10.5,15.5,7.5,2.6,-45} }
G.plus  = { {"b",12,12,12,2.6}, {"b",12,12,2.6,12} }
G.minus = { {"b",12,12,12,2.6} }
-- Actions
G.search= { {"r",10.5,10.5,9,2.4}, {"b",17.5,17.5,6.5,2.6,45} }
G.settings = { {"r",12,12,8,2.2}, {"d",12,12,4}, {"b",12,5,2.4,4}, {"b",12,19,2.4,4}, {"b",5,12,4,2.4}, {"b",19,12,4,2.4} }
G.save  = { {"o",12,13,12,11,2}, {"b",12,8,8,3}, {"b",12,16,6,4} }
G.copy  = { {"o",9.5,9.5,10,11,2}, {"o",14.5,14.5,10,11,2} }
G.edit  = { {"b",11,13,11,2.6,45}, {"d",6,18,3} }
G.trash = { {"o",12,14.5,11,13,2}, {"b",12,7,13,2.4}, {"b",12,4.5,5,2.2}, {"b",9.5,14,2,7}, {"b",14.5,14,2,7} }
G.refresh = { {"r",12,12,9,2.2}, {"b",19,8,5,2.4,-30}, {"b",5,16,5,2.4,150} }
-- Objects
G.user  = { {"d",12,8,7}, {"b",12,17.5,13,6} }
G.home  = { {"b",8.5,8,7.5,2.6,45}, {"b",15.5,8,7.5,2.6,-45}, {"o",12,15,11,9,2} }
G.folder= { {"o",12,13.5,15,10,2}, {"b",8,7.5,6,2.4} }
G.file  = { {"o",12,12,12,16,2}, {"b",15,8,4,4} }
G.key   = { {"r",8,12,7,2.4}, {"b",16.5,12,9,2.4}, {"b",18.5,15,2.4,4} }
G.lock  = { {"o",12,15.5,11,9,2}, {"r",12,9,8,2.4}, {"d",12,15.5,2.6} }
G.unlock= { {"o",12,15.5,11,9,2}, {"r",12,9,8,2.4}, {"b",16,9,2.4,5} }
G.bell  = { {"r",12,10.5,12,2.4}, {"b",12,16,13,2.4}, {"d",12,20,3} }
G.mail  = { {"o",12,12,16,11,2}, {"b",8,8,8,2.4,45}, {"b",16,8,8,2.4,-45} }
-- Media
G.play  = { {"b",9,12,2.6,12}, {"b",13.5,9.5,9,2.6,30}, {"b",13.5,14.5,9,2.6,-30} }
G.pause = { {"b",9,12,3,12}, {"b",15,12,3,12} }
G.stop  = { {"o",12,12,12,12,2} }
G.music = { {"d",9,16,5}, {"d",17,14,5}, {"b",12,10,2.4,12} }
-- Status
G.shield= { {"o",12,12,13,16,6}, {"b",9.5,12.5,4,2,45}, {"b",14,11,6.5,2,-45} }
G.chart = { {"b",7,15,3,7}, {"b",12,12.5,3,12}, {"b",17,10,3,17} }
G.globe = { {"r",12,12,14,2.2}, {"b",12,12,13,2.2}, {"o",12,12,7,14,99} }
-- Symbols
G.gem   = { {"o",12,12,11,11,3,45}, {"b",12,10,9,2.2} }
G.heart = { {"d",8.8,9.5,6.5}, {"d",15.2,9.5,6.5}, {"b",8.8,15,3.2,7,45}, {"b",15.2,15,3.2,7,-45} }
G.star  = { {"b",12,6,2.4,6}, {"b",8,9,8,2.4,-30}, {"b",16,9,8,2.4,30}, {"b",9,15,6,2.4,60}, {"b",15,15,6,2.4,-60} }
G.bolt  = { {"b",13.5,7,3,8,15}, {"b",12,12,7,2.4}, {"b",10.5,17,3,8,15} }
G.fire  = { {"d",12,8,5}, {"d",10,12,4}, {"d",14,12,4}, {"d",12,16,6} }
G.crown = { {"b",8,14,3,8}, {"b",12,10,3,12}, {"b",16,14,3,8}, {"b",12,18,10,3} }
G.diamond = { {"o",12,12,10,14,2,45} }

-- Packs: "vector" is the builtin glyph table above; "custom" is filled by
-- Library:RegisterIcon. IconPackName points at the preferred pack and stays
-- "vector" unless a developer replaces it wholesale.
local IconPacks = { vector = G, custom = {} }
local IconPackName = "vector"
local IconWarned = {}

local function iconUriOf(value)
        if type(value) == "number" and value ~= 0 then
                return "rbxassetid://" .. value
        end
        if type(value) == "string" then
                local lower = string.lower(value)
                if string.sub(lower, 1, 13) == "rbxassetid://"
                        or string.sub(lower, 1, 11) == "rbxasset://"
                        or string.sub(lower, 1, 11) == "rbxthumb://"
                        or string.sub(lower, 1, 8) == "https://"
                        or string.sub(lower, 1, 7) == "http://" then
                        return value
                end
        end
        return nil
end

local function resolveIcon(value)
        local uri = iconUriOf(value)
        if uri then return { kind = "image", uri = uri, fallback = "dot" } end
        if type(value) == "string" then
                for _, packName in ipairs({ IconPackName, "custom", "vector" }) do
                        local pack = IconPacks[packName]
                        local entry = pack and pack[value]
                        if type(entry) == "string" then
                                return { kind = "image", uri = entry, fallback = value }
                        elseif type(entry) == "table" then
                                return { kind = "glyph", glyph = entry, name = value }
                        end
                end
        end
        return nil
end

-- Draw a vector glyph op-list into `container` at the requested pixel size.
-- The op coordinates are authored in a 24×24 box, so everything scales by
-- size / 24. Bars carry their own rotation; rings and outlines get a UIStroke.
local function buildGlyphInto(container, glyph, color, size)
        local scale = size / 24
        for _, op in ipairs(glyph) do
                local kind, x, y, a, b = op[1], op[2], op[3], op[4], op[5]
                local f = Instance.new("Frame")
                f.AnchorPoint = Vector2.new(0.5, 0.5)
                f.Position = UDim2.new(0, x * scale, 0, y * scale)
                f.BorderSizePixel = 0
                f.BackgroundColor3 = color
                f.ZIndex = container.ZIndex + 1
                f.Parent = container
                if kind == "b" then
                        f.Size = UDim2.new(0, a * scale, 0, b * scale)
                        f.Rotation = op[6] or 0
                        corner(f, UDim.new(0, math.max(1.75, math.min(a, b) * scale / 2)))
                elseif kind == "d" then
                        f.Size = UDim2.new(0, a * scale, 0, a * scale)
                        corner(f, UDim.new(1, 0))
                elseif kind == "r" then
                        f.Size = UDim2.new(0, a * scale, 0, a * scale)
                        f.BackgroundTransparency = 1
                        corner(f, UDim.new(1, 0))
                        stroke(f, color, math.max(1.75, (b or 2.2) * scale))
                elseif kind == "o" then
                        f.Size = UDim2.new(0, a * scale, 0, b * scale)
                        f.Rotation = op[7] or 0
                        f.BackgroundTransparency = 1
                        local cr = op[6] or 2
                        corner(f, cr > 12 and UDim.new(0.5, 0) or UDim.new(0, cr * scale))
                        stroke(f, color, math.max(1.75, 2 * scale))
                end
        end
end

-- Paint the RESOLVED icon into `container`, replacing whatever it held.
-- HTTP images get the glyph fallback immediately (plus a breathing pulse
-- while loading) and swap to the real asset once the NetImage pipeline
-- resolves it; a failed download settles the fallback in place.
local function paintIcon(container, resolved, color, size)
        for _, ch in ipairs(container:GetChildren()) do ch:Destroy() end
        container.Size = UDim2.fromOffset(size, size)
        if resolved.kind == "image" and isHttpUrl(resolved.uri) then
                buildGlyphInto(container, G[resolved.fallback] or G.dot, color, size)
                local breath = Instance.new("UIScale")
                breath.Scale = 1
                breath.Parent = container
                local tw = TweenService:Create(breath,
                        TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                        { Scale = 0.8 })
                tw:Play()
                Library:ResolveNetImage(resolved.uri, function(uri)
                        if not container.Parent then return end
                        tw:Cancel()
                        for _, ch in ipairs(container:GetChildren()) do ch:Destroy() end
                        local img = Instance.new("ImageLabel")
                        img.Size = UDim2.fromScale(1, 1)
                        img.BackgroundTransparency = 1
                        img.Image = uri
                        img.ImageColor3 = color
                        img.ZIndex = container.ZIndex + 1
                        img.Parent = container
                end, function()
                        if not container.Parent then return end
                        tw:Cancel()
                        breath.Scale = 1
                end)
                return
        end
        if resolved.kind == "image" then
                local img = Instance.new("ImageLabel")
                img.Name = "IconImage"
                img.Size = UDim2.fromScale(1, 1)
                img.BackgroundTransparency = 1
                img.Image = resolved.uri
                img.ImageColor3 = color
                img.ZIndex = container.ZIndex + 1
                img.Parent = container
                -- Asset images can silently fail to load (deleted asset,
                -- wrong id, marketplace restrictions). Preload with a grace
                -- period, then fall back to the drawn glyph so the row never
                -- renders an empty slot.
                local fallbackName = resolved.fallback
                task.spawn(function()
                        pcall(function() ContentProvider:PreloadAsync({ img }) end)
                        if img.Parent and not img.IsLoaded then
                                task.wait(1.5)
                                if img.Parent and not img.IsLoaded then
                                        img:Destroy()
                                        buildGlyphInto(container, G[fallbackName] or G.dot, color, size)
                                end
                        end
                end)
        else
                buildGlyphInto(container, resolved.glyph, color, size)
        end
end

-- [v5.7] Center anchor so rotations/pops spin in place. makeIcon is the
-- constructor (fresh container); setIcon repaints an existing container.
local function makeIcon(parent, value, size, color, opts)
        opts = opts or {}
        local container = Instance.new("Frame")
        container.Name = "Icon"
        container.AnchorPoint = Vector2.new(0.5, 0.5)
        container.Size = UDim2.fromOffset(size, size)
        container.BackgroundTransparency = 1
        container.ZIndex = opts.z or 2
        container.Parent = parent
        local resolved = resolveIcon(value) or { kind = "glyph", glyph = G.dot, name = "dot" }
        paintIcon(container, resolved, color or Color3.new(1, 1, 1), size)
        return container
end

local function setIcon(container, value, size, color)
        local resolved = resolveIcon(value)
        if not resolved then
                if type(value) == "string" and value ~= "" and not IconWarned[value] then
                        IconWarned[value] = true
                        warn("[RezurXLib] Unknown icon '" .. value .. "' — drew a dot. Register it with Library:RegisterIcon.")
                end
                resolved = { kind = "glyph", glyph = G.dot, name = "dot" }
        end
        paintIcon(container, resolved, color, size)
        return container
end

-- Recolor every drawable inside an icon container (image tint, glyph
-- frames, ring strokes) without rebuilding it.
local function recolorIcon(container, color)
        for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("ImageLabel") then d.ImageColor3 = color
                elseif d:IsA("UIStroke") then d.Color = color
                elseif d:IsA("Frame") then d.BackgroundColor3 = color end
        end
end

-- Rotate an icon container (dropdown/accordion chevrons) on the supplied
-- curve, or snap it when no tween info is given.
local function iconRotation(container, deg, info)
        if info then Tween(container, info, { Rotation = deg })
        else container.Rotation = deg end
end

--- Register (or replace, or with nil remove) a named icon.
--- `value` may be an image identifier (number id / asset URI / http URL)
--- or a hand-authored glyph op-list (see the format comment above).
function Library:RegisterIcon(name, value)
        if type(name) ~= "string" or name == "" then
                warn("[RezurXLib] RegisterIcon expects a non-empty string name.")
                return false
        end
        if value == nil then
                IconPacks.custom[name] = nil
                return true
        end
        if type(value) == "number" or type(value) == "string" then
                local uri = iconUriOf(value)
                if not uri then
                        warn("[RezurXLib] RegisterIcon: '" .. tostring(value) .. "' is not an asset id or URI.")
                        return false
                end
                IconPacks.custom[name] = uri
                return true
        end
        if type(value) == "table" then
                IconPacks.custom[name] = value
                return true
        end
        warn("[RezurXLib] RegisterIcon: unsupported value type " .. type(value))
        return false
end

-- ============================================================
-- [v5.7.0 AURORA] NET IMAGE PIPELINE — downloads developer-supplied
-- http(s) image URLs to RezurXLib/NetCache on the executor filesystem
-- and resolves them through getcustomasset(). Explicit opt-in by
-- design: the library never downloads anything unless a developer
-- passes a URL as an icon/backdrop value. Results memoized in memory;
-- concurrent requests for the same URL coalesce into one download.
-- Non-executor environments fail fast and callers render their glyph
-- fallback instead.
-- ============================================================
local NetImage = { Memory = {}, Pending = {} }
local NET_FOLDER = "RezurXLib/NetCache"

local function netRequestFn()
        if type(request) == "function" then return request end
        if type(httprequest) == "function" then return httprequest end
        if type(http) == "table" and type(http.request) == "function" then return http.request end
        if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
        if type(fluxus) == "table" and type(fluxus.request) == "function" then return fluxus.request end
        return nil
end

local function netCustomAsset(path)
        if type(getcustomasset) == "function" then
                local ok, uri = pcall(getcustomasset, path)
                if ok and type(uri) == "string" then return uri end
        end
        return nil
end

local function urlHash(url)
        local h = 5381
        for i = 1, #url do
                h = (h * 33 + string.byte(url, i)) % 2147483647
        end
        return string.format("%08x", h)
end

local function urlExt(url)
        local clean = string.match(url, "^%a+://[^?#]*") or url
        local ext = string.match(clean, "%.(%a+)$")
        if ext and #ext > 0 and #ext <= 5 then return string.lower(ext) end
        return "png"
end

local function netImageResolve(url, asset)
        NetImage.Memory[url] = asset
        local pending = NetImage.Pending[url]
        NetImage.Pending[url] = nil
        if pending then
                for _, cb in ipairs(pending) do
                        local ok = cb.ok
                        if ok then task.spawn(ok, asset) end
                end
        end
end

local function netImageReject(url, why)
        local pending = NetImage.Pending[url]
        NetImage.Pending[url] = nil
        if pending then
                for _, cb in ipairs(pending) do
                        local fail = cb.fail
                        if fail then task.spawn(fail, why) end
                end
        end
end

--- Resolve an http(s) image URL into a loadable asset URI (executor only).
--- onSuccess receives the customasset URI; onFailure receives a short
--- reason string. Same-URL callers share one download.
function Library:ResolveNetImage(url, onSuccess, onFailure)
        if type(url) ~= "string" or not isHttpUrl(url) then
                if onFailure then onFailure("not an http(s) url") end
                return
        end
        local cached = NetImage.Memory[url]
        if cached then
                if onSuccess then onSuccess(cached) end
                return
        end
        local req = netRequestFn()
        if not req or not FS.available or type(getcustomasset) ~= "function" then
                -- Studio / plain clients have no http+fs bridge: fail fast so
                -- the caller can render its drawn fallback.
                if onFailure then onFailure("net images require an executor") end
                return
        end
        if NetImage.Pending[url] then
                table.insert(NetImage.Pending[url], { ok = onSuccess, fail = onFailure })
                return
        end
        NetImage.Pending[url] = { { ok = onSuccess, fail = onFailure } }
        task.spawn(function()
                local path = NET_FOLDER .. "/" .. urlHash(url) .. "." .. urlExt(url)
                if FS.exists(path) then
                        local asset = netCustomAsset(path)
                        if asset then netImageResolve(url, asset) return end
                end
                local ok, response = pcall(req, { Url = url, Method = "GET" })
                local body = ok and type(response) == "table" and response.Body
                if ok and type(response) == "string" then body = response end
                if not body or body == "" then
                        netImageReject(url, "download failed")
                        return
                end
                FS.ensureFolder(NET_FOLDER)
                if not FS.write(path, body) then
                        netImageReject(url, "cache write failed")
                        return
                end
                local asset = netCustomAsset(path)
                if asset then
                        netImageResolve(url, asset)
                else
                        netImageReject(url, "getcustomasset failed")
                end
        end)
end

-- ============================================================
-- [v5.7.0 AURORA] BACKDROP ENGINE — a decorative layer INSIDE the
-- window frame, behind all content. Four modes:
--   "theme"    plain window background (nothing extra rendered)
--   "image"    developer-supplied image (asset URI or net URL) + dim
--   "gradient" two-color gradient (ColorA -> ColorB, rotatable)
--   "aurora"   two soft accent blobs drifting on long sine loops with
--              a sparse field of accent motes
-- The controller is returned to CreateWindow; drag calls :parallax(),
-- release calls :settle(), and tab switches may :pulse() the blobs.
-- Every animated loop is registered on the window Janitor and respects
-- reduced motion. [v5.7] motes are scoped per window (they used to be a
-- stray file-level local, so two windows fought over one mote table).
-- ============================================================
local SOFT_ASSET = "rbxassetid://1316045217"

local function createBackdrop(frame, C, reducedMotion, janitor, onTheme, registerPulse)
        local state = {
                mode = "theme", image = nil, dim = 0.45,
                colorA = C.headerA, colorB = C.bg, rotation = 90, pan = false,
        }
        local layer = Instance.new("Frame")
        layer.Name = "Backdrop"
        layer.Size = UDim2.new(1, 24, 1, 24)
        layer.Position = UDim2.new(0, -12, 0, -12)
        layer.BackgroundTransparency = 1
        layer.ClipsDescendants = true
        layer.ZIndex = 1
        layer.Parent = frame
        corner(layer, R.outer)
        local base = Instance.new("Frame")
        base.Size = UDim2.new(1, 0, 1, 0)
        base.BackgroundColor3 = C.bg
        base.BackgroundTransparency = 1
        base.BorderSizePixel = 0
        base.ZIndex = 1
        base.Parent = layer
        local img = Instance.new("ImageLabel")
        img.Name = "BackdropImage"
        img.Size = UDim2.new(1, 0, 1, 0)
        img.BackgroundTransparency = 1
        img.ScaleType = Enum.ScaleType.Crop
        img.Image = ""
        img.ImageTransparency = 1
        img.ZIndex = 2
        img.Parent = layer
        local grad = Instance.new("Frame")
        grad.Size = UDim2.new(1, 0, 1, 0)
        grad.BackgroundColor3 = C.white
        grad.BackgroundTransparency = 1
        grad.BorderSizePixel = 0
        grad.ZIndex = 2
        grad.Parent = layer
        local gradSeq = gradient(grad, ColorSequence.new{
                ColorSequenceKeypoint.new(0, state.colorA),
                ColorSequenceKeypoint.new(1, state.colorB),
        }, state.rotation)
        local blobA = Instance.new("ImageLabel")
        blobA.Size = UDim2.new(0, 340, 0, 340)
        blobA.Position = UDim2.new(0, -90, 0, -100)
        blobA.BackgroundTransparency = 1
        blobA.Image = SOFT_ASSET
        blobA.ImageColor3 = C.accent
        blobA.ImageTransparency = 1
        blobA.ZIndex = 3
        blobA.Parent = layer
        local blobB = Instance.new("ImageLabel")
        blobB.Size = UDim2.new(0, 300, 0, 300)
        blobB.Position = UDim2.new(1, -240, 1, -220)
        blobB.BackgroundTransparency = 1
        blobB.Image = SOFT_ASSET
        blobB.ImageColor3 = C.accentDim
        blobB.ImageTransparency = 1
        blobB.ZIndex = 3
        blobB.Parent = layer
        local tint = Instance.new("Frame")
        tint.Size = UDim2.new(1, 0, 1, 0)
        tint.BackgroundColor3 = C.black
        tint.BackgroundTransparency = 1
        tint.BorderSizePixel = 0
        tint.ZIndex = 4
        tint.Parent = layer

        local loops = {}
        local motes = nil
        local function stopLoops()
                for _, tw in ipairs(loops) do pcall(function() tw:Cancel() end) end
                loops = {}
        end
        janitor:Add(stopLoops)

        local function startLoops()
                stopLoops()
                if reducedMotion then return end
                if state.mode == "aurora" then
                        table.insert(loops, Tween(blobA,
                                TweenInfo.new(11, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                                { Position = UDim2.new(0, 30, 0, 40), Rotation = 25 }))
                        table.insert(loops, Tween(blobB,
                                TweenInfo.new(14, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                                { Position = UDim2.new(1, -300, 1, -280), Rotation = -20 }))
                        if not motes then
                                motes = {}
                                for i = 1, 10 do
                                        local d = i % 3 == 0 and 3 or 2
                                        local m = Instance.new("Frame")
                                        m.Size = UDim2.new(0, d, 0, d)
                                        m.Position = UDim2.new(math.random(0, 100) / 100, 0, math.random(10, 90) / 100, 0)
                                        m.BackgroundColor3 = C.accentHi
                                        m.BackgroundTransparency = 0.78
                                        m.BorderSizePixel = 0
                                        m.ZIndex = 3
                                        m.Parent = layer
                                        corner(m, UDim.new(1, 0))
                                        table.insert(motes, m)
                                end
                                onTheme(function()
                                        for _, m in ipairs(motes) do m.BackgroundColor3 = C.accentHi end
                                end)
                        end
                        for _, m in ipairs(motes) do
                                m.Visible = true
                                table.insert(loops, Tween(m,
                                        TweenInfo.new(math.random(60, 110) / 10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                                        {
                                                Position = m.Position + UDim2.new(0, math.random(-30, 30), 0, math.random(-24, -10)),
                                                BackgroundTransparency = 0.92,
                                        }))
                        end
                elseif motes then
                        for _, m in ipairs(motes) do m.Visible = false end
                end
                if state.mode == "image" and state.pan and state.image then
                        table.insert(loops, Tween(img,
                                TweenInfo.new(16, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                                { Position = UDim2.new(0, -18, 0, -12), Size = UDim2.new(1.06, 0, 1.06, 0) }))
                end
        end

        local function surfaces(reveal)
                local m = state.mode
                base.Visible = m ~= "theme"
                grad.Visible = m == "gradient"
                img.Visible = m == "image" and state.image ~= nil
                tint.Visible = m == "image"
                blobA.Visible = m == "aurora"
                blobB.Visible = m == "aurora"
                gradSeq.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0, state.colorA),
                        ColorSequenceKeypoint.new(1, state.colorB),
                }
                gradSeq.Rotation = state.rotation
                if img.Visible then img.Image = state.image end
                local targets = {}
                if base.Visible then targets[base] = { BackgroundTransparency = 0 } end
                if grad.Visible then targets[grad] = { BackgroundTransparency = 0 } end
                if img.Visible then targets[img] = { ImageTransparency = 0 } end
                if tint.Visible then targets[tint] = { BackgroundTransparency = 1 - state.dim } end
                if blobA.Visible then targets[blobA] = { ImageTransparency = 0.78 } end
                if blobB.Visible then targets[blobB] = { ImageTransparency = 0.85 } end
                for inst, props in pairs(targets) do
                        if reveal and not reducedMotion then
                                Tween(inst, T40, props)
                        else
                                for prop, value in pairs(props) do inst[prop] = value end
                        end
                end
                startLoops()
        end

        local ctl = {}
        function ctl:set(bcfg)
                bcfg = bcfg or {}
                if type(bcfg.Mode) == "string" then
                        state.mode = string.lower(bcfg.Mode)
                        if state.mode ~= "theme" and state.mode ~= "image"
                                and state.mode ~= "gradient" and state.mode ~= "aurora" then
                                state.mode = "theme"
                        end
                end
                if bcfg.Mode == nil and type(bcfg.Image) == "string" and bcfg.Image ~= "" then
                        state.mode = "image"
                end
                if bcfg.Image ~= nil then
                        local uri = iconUriOf(bcfg.Image)
                                or (tonumber(bcfg.Image) and "rbxassetid://" .. tonumber(bcfg.Image))
                        if isHttpUrl(uri) then
                                state.image = nil
                                Library:ResolveNetImage(uri, function(asset)
                                        state.image = asset
                                        surfaces(false)
                                end, function() state.image = nil end)
                        else
                                state.image = uri
                        end
                end
                if type(bcfg.Dim) == "number" then state.dim = math.clamp(bcfg.Dim, 0, 1) end
                if typeof(bcfg.ColorA) == "Color3" then state.colorA = bcfg.ColorA end
                if typeof(bcfg.ColorB) == "Color3" then state.colorB = bcfg.ColorB end
                if type(bcfg.Rotation) == "number" then state.rotation = bcfg.Rotation end
                if bcfg.Pan ~= nil then state.pan = bcfg.Pan == true end
                surfaces(false)
                return state
        end
        function ctl:reveal() surfaces(true) end
        function ctl:parallax(dx, dy)
                if reducedMotion then return end
                if state.mode == "theme" then return end
                local x = math.clamp(-dx * 0.015, -10, 10)
                local y = math.clamp(-dy * 0.015, -10, 10)
                layer.Position = UDim2.new(0, -12 + x, 0, -12 + y)
        end
        function ctl:settle()
                Tween(layer, MT.settle, { Position = UDim2.new(0, -12, 0, -12) })
        end
        function ctl:get()
                local copy = {}
                for k, v in pairs(state) do copy[k] = v end
                return copy
        end
        onTheme(function()
                base.BackgroundColor3 = C.bg
                blobA.ImageColor3 = C.accent
                blobB.ImageColor3 = C.accentDim
        end)
        function ctl:pulse()
                if reducedMotion then return end
                local rests = { [blobA] = 0.78, [blobB] = 0.85 }
                for blob, rest in pairs(rests) do
                        if blob.Visible then
                                Tween(blob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                        { ImageTransparency = rest - 0.2 })
                                task.delay(0.18, function()
                                        if blob.Parent then
                                                Tween(blob, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                                        { ImageTransparency = rest })
                                        end
                                end)
                        end
                end
        end
        if type(registerPulse) == "function" then
                registerPulse(function() ctl:pulse() end)
        end
        return ctl
end
