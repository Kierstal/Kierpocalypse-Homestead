-- Kierpocalyptic Homestead - ambient cold storage
--
-- When a container's tile has no electricity AND the ambient temperature
-- is at/below a cold threshold, treat that container like a fridge for
-- food-aging purposes. Compensates by rewinding item:setAge() after every
-- game-minute tick so the net aging rate is slowed.
--
-- Uses square:haveElectricity() which honors generators - if a generator
-- is powering a square, vanilla's existing fridge slowdown applies there
-- and we skip it entirely (no double-stacking with vanilla refrigerators).
--
-- Tiers:
--   ambient <= COLD_TEMP_C    : 1/FRIDGE_FACTOR speed   (fridge-equivalent)
--   ambient <= FROZEN_TEMP_C  : 1/FREEZER_FACTOR speed  (near-freezer)
--
-- Limitations of v0.0.1:
--   - Only scans player Z-layer (4-tile XY radius). Items elsewhere age normally.
--   - Doesn't set isFrozen() state, so frozen-vs-thawed recipe gates are unaffected.
--   - Skips player-carried inventory entirely (you don't refrigerate via pocket).

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ColdStorage = "0.0.1"

local SCAN_RADIUS    = 4
local COLD_TEMP_C    = 5      -- ambient <= this -> fridge-equivalent
local FROZEN_TEMP_C  = -5     -- ambient <= this -> near-freezer
local FRIDGE_FACTOR  = 3      -- ages at 1/3 speed when cold
local FREEZER_FACTOR = 20     -- ages at 1/20 speed when sub-zero

-- Compensation per game-minute in HOURS.
-- Normal aging this minute = 1/60 hour. We want net (1/factor)/60.
-- Subtract (1 - 1/factor) * 1/60 from the item's age each tick.
local function compensationHours(factor)
    return ((factor - 1) / factor) / 60
end
local COLD_COMP   = compensationHours(FRIDGE_FACTOR)
local FROZEN_COMP = compensationHours(FREEZER_FACTOR)

local function getAmbientTemp()
    local cm = getClimateManager()
    if not cm or not cm.getTemperature then return nil end
    local t = nil
    pcall(function() t = cm:getTemperature() end)
    return t
end

local function squareUnpowered(sq)
    if not sq then return false end
    local has = false
    pcall(function() has = sq:haveElectricity() end)
    return not has
end

local function compensateContainer(container, comp)
    if not container or not container.getItems then return end
    local items
    pcall(function() items = container:getItems() end)
    if not items or not items.size then return end
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and instanceof(it, "Food") then
            local age, offMax
            pcall(function()
                age = it:getAge()
                offMax = it:getOffAgeMax()
            end)
            -- Skip items that don't spoil (offMax<=0) or already rotten (age>=offMax).
            if age and offMax and offMax > 0 and age < offMax then
                local newAge = age - comp
                if newAge < 0 then newAge = 0 end
                pcall(function() it:setAge(newAge) end)
            end
        end
    end
end

local function processSquare(sq, comp)
    if not sq then return end
    if not squareUnpowered(sq) then return end
    local objs
    pcall(function() objs = sq:getObjects() end)
    if not objs or not objs.size then return end
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        local c
        pcall(function() c = obj.getContainer and obj:getContainer() end)
        if c then
            compensateContainer(c, comp)
        end
    end
end

local function tick()
    local p = getPlayer()
    if not p or p:isDead() then return end

    local temp = getAmbientTemp()
    if not temp or temp > COLD_TEMP_C then return end

    local comp = (temp <= FROZEN_TEMP_C) and FROZEN_COMP or COLD_COMP

    local cell = getCell()
    if not cell then return end
    local px = math.floor(p:getX())
    local py = math.floor(p:getY())
    local pz = math.floor(p:getZ())

    for dy = -SCAN_RADIUS, SCAN_RADIUS do
        for dx = -SCAN_RADIUS, SCAN_RADIUS do
            local sq = cell:getGridSquare(px + dx, py + dy, pz)
            if sq then
                pcall(function() processSquare(sq, comp) end)
            end
        end
    end
end

Events.EveryOneMinute.Add(tick)

print(string.format(
    "[KH] ColdStorage v%s loaded (cold=%dC->1/%d speed, frozen=%dC->1/%d speed)",
    KH.modules.ColdStorage, COLD_TEMP_C, FRIDGE_FACTOR, FROZEN_TEMP_C, FREEZER_FACTOR))
