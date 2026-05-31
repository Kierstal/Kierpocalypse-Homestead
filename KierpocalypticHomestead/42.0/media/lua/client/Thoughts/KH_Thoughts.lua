-- Kierpocalyptic Homestead - thought dispatcher (v0.0.3 - queue-based)
--
-- Public API (unchanged):
--   KH.Thoughts.emit(player, category, key)       -- respects per-category cooldown
--   KH.Thoughts.emitForce(player, category, key)  -- still sets cooldown but ignores it on entry
--
-- Behavior change vs v0.0.2:
--   * Cooldown is now PER-CATEGORY, not global. Two different categories
--     can fire back-to-back; a single category still won't repeat for 30 min.
--   * When emissions land while a halo line is already on-screen, we
--     QUEUE them and drain one every HALO_GAP_SECONDS, instead of dropping.
--   * Queue depth is capped (KH_QUEUE_MAX). Overflow drops with a print warn.
--   * Drain runs on Events.OnTick (every frame); a realSeconds gate keeps actual work to once per HALO_GAP_SECONDS.
--
-- Halo text display duration in PZ is ~4 seconds (engine-side, not exposed
-- in Lua). We pace the queue at 4.5s per line so it visibly clears between
-- displays instead of stacking on top of each other.

require "Thoughts/KH_ThoughtLines"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.Thoughts = "0.0.3"
KH.Thoughts = KH.Thoughts or {}

-- Per-(category,key) cooldown. Repeat-rate floor for any individual line
-- so the player isn't getting the same thought hammered at them. Default
-- is 24 game-hours - a thought repeats no more often than once per day.
local COOLDOWN_MINUTES = 1440

-- Exceptions: high-priority repeating concerns where the player benefits
-- from more frequent reminders. Keys here are the composite
-- "category/key" used by emit (or just "category" for keyless emits).
-- Values are minutes.
local COOLDOWN_OVERRIDES = {
    ["moodle_Hungry"]      = 240,   -- 4 hr - hunger is ongoing, want reminders
    ["moodle_Thirsty"]     = 240,   -- 4 hr - same
    ["moodle_Bleeding"]    = 60,    -- 1 hr - bleeding kills you, nag often
    -- Lane-3 needs variants too
    ["needs/hungry"]       = 240,
    ["needs/veryHungry"]   = 180,
    ["needs/starving"]     = 120,
    ["needs/thirsty"]      = 240,
    ["needs/veryThirsty"]  = 180,
    ["needs/parched"]      = 120,
}
local function getEffectiveCooldown(cooldownKey)
    return COOLDOWN_OVERRIDES[cooldownKey] or COOLDOWN_MINUTES
end
local MODDATA_COOLDOWN_KEY = "KH_thoughtCooldownsByCategory"
-- Display tuning. Each emit produces ONE pulse. PZ's engine fades halo
-- text after ~3 seconds. HALO_GAP_SECONDS is the minimum time between
-- one line clearing and the next pushing through, so the player sees
-- each thought distinctly. Per user request: straight 3 sec per line.
local HALO_GAP_SECONDS = 3.0
local KH_QUEUE_MAX = 6

-- Runtime queue (NOT persisted: short-lived UI state, fine to lose on save/load).
local queue = {}              -- list of { player, line, ts }
local lastDrainEpochSeconds = 0

-- ------------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------------

local function worldMinutes()
    local gt = getGameTime()
    if not gt then return 0 end
    return math.floor((gt:getWorldAgeHours() or 0) * 60)
end

local function realSeconds()
    -- getTimeStamp returns ms since epoch (or game start, varies);
    -- we only care about deltas so it's fine either way.
    if getTimestampMs then return (getTimestampMs() or 0) / 1000.0 end
    if Calendar and Calendar.getInstance and Calendar.getInstance() and Calendar.getInstance().getTimeInMillis then
        local ok, ms = pcall(function() return Calendar.getInstance():getTimeInMillis() end)
        if ok and ms then return ms / 1000.0 end
    end
    return os and os.clock() or 0
end

-- Returns a set { id = true } of owned vanilla traits + current profession id.
-- (Unchanged from v0.0.2.)
local function getOwnedIds(player)
    local result = {}
    if not player then return result end
    if player.getDescriptor and player:getDescriptor() then
        local prof = player:getDescriptor():getCharacterProfession()
        if prof and prof.getName then
            local pname = prof:getName()
            if pname then result[pname] = true end
        end
    end
    if player.getCharacterTraits then
        local ct = player:getCharacterTraits()
        local list = ct and ct.getKnownTraits and ct:getKnownTraits() or nil
        if list and list.size then
            for i = 0, list:size() - 1 do
                local t = list:get(i)
                if t then
                    local name = nil
                    if t.getName then
                        local ok = pcall(function() name = t:getName() end)
                        if not ok then name = nil end
                    end
                    if not name then name = tostring(t) end
                    if name then result[name] = true end
                end
            end
        end
    end
    return result
end

local KH_TRAIT_SHORTS = { "Pluviophile", "Pluviophobe", "ComicNerd", "TherapyAnimals", "ForageFeast", "NeatFreak", "Slob" }

local function hasKHTrait(player, short)
    if KH and KH.hasTrait then return KH.hasTrait(player, "KH:" .. short) end
    return false
end

local function pickPool(player, lineGroup)
    if not lineGroup then return nil end
    for _, short in ipairs(KH_TRAIT_SHORTS) do
        if lineGroup[short] and hasKHTrait(player, short) then
            return lineGroup[short]
        end
    end
    local owned = getOwnedIds(player)
    for key, pool in pairs(lineGroup) do
        if key ~= "default" and owned[key] then return pool end
    end
    return lineGroup.default
end

local function pickLine(pool)
    if not pool or #pool == 0 then return nil end
    return pool[ZombRand(#pool) + 1]
end

-- ------------------------------------------------------------------
-- Per-category cooldown (persisted in player modData)
-- ------------------------------------------------------------------

local function getCooldownTable(player)
    local d = player and player:getModData()
    if not d then return nil end
    d[MODDATA_COOLDOWN_KEY] = d[MODDATA_COOLDOWN_KEY] or {}
    return d[MODDATA_COOLDOWN_KEY]
end

local function isOnCooldown(player, category)
    local tbl = getCooldownTable(player)
    if not tbl then return false end
    local cd = getEffectiveCooldown(category)
    local last = tbl[category] or -cd * 2
    return (worldMinutes() - last) < cd
end

local function setCooldown(player, category)
    local tbl = getCooldownTable(player)
    if not tbl then return end
    tbl[category] = worldMinutes()
end

-- ------------------------------------------------------------------
-- Queue + drain
-- ------------------------------------------------------------------

local function enqueue(player, line)
    if #queue >= KH_QUEUE_MAX then
        print("[KH] Thoughts queue full (" .. KH_QUEUE_MAX .. "), dropping line: " .. tostring(line))
        return false
    end
    table.insert(queue, { player = player, line = line })
    return true
end

local function showLine(player, line)
    if not line or not player then return end
    if HaloTextHelper and HaloTextHelper.addText then
        HaloTextHelper.addText(player, line)
    elseif HaloTextHelper and HaloTextHelper.addGoodText then
        HaloTextHelper.addGoodText(player, line)
    end
end

local function drain()
    if #queue == 0 then return end
    local now = realSeconds()
    if (now - lastDrainEpochSeconds) < HALO_GAP_SECONDS then return end
    local head = table.remove(queue, 1)
    if head and head.player and head.line then
        showLine(head.player, head.line)
        lastDrainEpochSeconds = now
    end
end

-- OnTick fires every frame; drain has its own realSeconds delta gate so this is fine.
Events.OnTick.Add(drain)

-- ------------------------------------------------------------------
-- Public API
-- ------------------------------------------------------------------

function KH.Thoughts.emit(player, category, key)
    if not player or not category then return false end
    if not KH.ThoughtLines or not KH.ThoughtLines[category] then return false end
    local lineGroup = key and KH.ThoughtLines[category][key] or KH.ThoughtLines[category]
    if not lineGroup then return false end
    -- per-category cooldown: composite key so "filth/becameFilthy" doesn't
    -- block "filth/becameClean" 30 minutes later if they want different cooldowns
    -- (default: dedupe at the category level which is usually right).
    local cooldownKey = key and (category .. "/" .. tostring(key)) or category
    if isOnCooldown(player, cooldownKey) then return false end
    local line = pickLine(pickPool(player, lineGroup))
    if not line then return false end
    if not enqueue(player, line) then return false end
    setCooldown(player, cooldownKey)
    return true
end

function KH.Thoughts.emitForce(player, category, key)
    if not player or not category then return false end
    if not KH.ThoughtLines or not KH.ThoughtLines[category] then return false end
    local lineGroup = key and KH.ThoughtLines[category][key] or KH.ThoughtLines[category]
    if not lineGroup then return false end
    local cooldownKey = key and (category .. "/" .. tostring(key)) or category
    local line = pickLine(pickPool(player, lineGroup))
    if not line then return false end
    if not enqueue(player, line) then return false end
    setCooldown(player, cooldownKey)
    return true
end

print("[KH] Thoughts dispatcher v" .. KH.modules.Thoughts .. " loaded (per-category cooldown + queue depth " .. KH_QUEUE_MAX .. ")")
