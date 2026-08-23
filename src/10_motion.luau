-- ============================================================
-- SPRING SOLVER (v5.0.0) — the motion engine core.
-- Stiffness/damping integration on RunService delta (NEVER wall-clock:
-- executor tick()/os.clock() can disagree with render time). Springs
-- are interruptible and velocity-preserving: retargeting mid-flight
-- continues from the current velocity instead of restarting — grab a
-- toggle mid-animation and it keeps its momentum.
--
-- Hard budget: at most MAX_SPRINGS concurrent. Overflow requests snap
-- straight to their end state, so an entrance cascade can never hitch
-- a 30 FPS host.
-- ============================================================
local MAX_SPRINGS = 12
local Spring = { active = {}, count = 0, _conn = nil }

local function springStep(dt)
        -- Clamp dt for stability (tab-out / hitch protection).
        if dt <= 0 then return end
        if dt > 1 / 20 then dt = 1 / 20 end
        local active = Spring.active
        for i = #active, 1, -1 do
                local h = active[i]
                -- Destroy-race guard: a spring never writes to a dead instance.
                if not h.alive or h.instance == nil or h.instance.Parent == nil then
                        table.remove(active, i)
                        Spring.count = #active
                else
                        local force = h.stiffness * (h.target - h.value) - h.damping * h.velocity
                        h.velocity = h.velocity + force * dt
                        h.value = h.value + h.velocity * dt
                        if math.abs(h.target - h.value) < 0.35 and math.abs(h.velocity) < 3 then
                                h.value = h.target
                                h.velocity = 0
                                table.remove(active, i)
                                Spring.count = #active
                                h.alive = false
                                pcall(h.apply, h.value, true)
                                if h.done then pcall(h.done) end
                        else
                                pcall(h.apply, h.value, false)
                        end
                end
        end
        if #active == 0 and Spring._conn then
                Spring._conn:Disconnect()
                Spring._conn = nil
        end
end

local function springEnsureHeartbeat()
        if not Spring._conn then
                Spring._conn = RunService.Heartbeat:Connect(function(dt)
                        springStep(dt)
                end)
        end
end

--- Create (or retarget) a spring on a single scalar.
--- Retargeting an existing handle preserves velocity — interruption is
--- the feature, not a bug: flick between tabs and the indicator keeps
--- gliding with its momentum.
--- @param handle table|nil existing handle to retarget
--- @param instance Instance instance written to (Parent-checked each step)
--- @param target number end value
--- @param opts table { stiffness=170, damping=22, apply=function(value, finished) }
--- @return table handle
local function springTo(handle, instance, target, opts)
        opts = opts or {}
        if handle and handle.alive and handle.instance == instance then
                handle.target = target
                return handle
        end
        local h = handle or {}
        h.instance = instance
        h.target = target
        h.stiffness = opts.stiffness or 170
        h.damping = opts.damping or 22
        h.apply = opts.apply
        h.done = opts.done
        h.velocity = (handle and handle.velocity) or 0
        h.value = (handle and handle.value ~= nil) and handle.value or (opts.from or target)
        h.alive = true
        -- Motion budget: over the cap, snap to the end state immediately.
        if Spring.count >= MAX_SPRINGS then
                h.value = target
                h.alive = false
                if h.apply then pcall(h.apply, target, true) end
                if h.done then pcall(h.done) end
                return h
        end
        if h.value ~= target then
                table.insert(Spring.active, h)
                Spring.count = #Spring.active
                springEnsureHeartbeat()
        else
                h.alive = false
                if h.apply then pcall(h.apply, target, true) end
                if h.done then pcall(h.done) end
        end
        return h
end

--- Snap a spring to its target immediately (viewport resizes, teardown).
local function springCancel(handle, snapToEnd)
        if not handle then return end
        if handle.alive then
                handle.alive = false
                for i, h in ipairs(Spring.active) do
                        if h == handle then table.remove(Spring.active, i) break end
                end
                Spring.count = #Spring.active
                if snapToEnd and handle.apply then
                        pcall(handle.apply, handle.target, true)
                end
        end
end

--- Kill every spring writing to a given instance (window teardown).
local function springsForgetInstance(instance)
        for i = #Spring.active, 1, -1 do
                local h = Spring.active[i]
                if h.instance == instance then
                        h.alive = false
                        table.remove(Spring.active, i)
                end
        end
        Spring.count = #Spring.active
end

-- Integer snap helper: every resting Offset that carries a UICorner is a
-- whole pixel (fractional offsets = half-pixel corners = "not perfectly
-- round" at any zoom).
local function snapPx(v)
        return math.floor(v + 0.5)
end

