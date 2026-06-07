-- Kierpocalyptic Homestead - Resident Food Pass v0.0.1
--
-- Fires at 06:00, 12:00, and 18:00 game-time each day.
-- Midnight is skipped - people don't eat at midnight.
--
-- For each claimed Homestead and Safehouse territory:
--   1. Count active residents in that building.
--   2. Pull food from designated pantry containers, rot-first.
--   3. Each resident needs ~33 hunger points per pass (~100/day across 3 passes).
--   4. If the pantry runs dry mid-pass, log the shortfall and emit a halo warning.
--
-- "Rot-first" = items whose (DaysTotallyRotten - currentGameDay) is lowest
-- get consumed before fresher items. Fresh-cooked food is saved for last.
--
-- Food eligibility: cooked meals, canned food (opened or no-opener required),
-- bread, jars, ready-to-eat packaged foods. Raw meat and uncooked grains excluded.
-- Items with HungerChange >= 0 (not filling) are also excluded.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.FoodPass = "0.0.1"

local HUNGER_PER_PASS = 33        -- ~100 hunger/day across 3 passes
local MEAL_HOURS = { [6]=true, [12]=true, [18]=true }

-- Tags/types that are explicitly not ready-to-eat without prep.
-- We check item type name substrings (lowercase).
local RAW_BLACKLIST = {
    "rawmeat", "rawfish", "rawrabbit", "rawchicken",
    "rawvenison", "rawpork", "rawbeef",
    "uncooked", "flour", "rice", "rawpasta",
    "seed", "acorn",
}

local function isBlacklisted(item)
    local t = string.lower(item:getType() or "")
    for _, pat in ipairs(RAW_BLACKLIST) do
        if string.find(t, pat, 1, true) then return true end
    end
    return false
end

-- Returns true if an item counts as edible-without-prep for residents.
local function isEdible(item)
    if not item then return false end
    -- Must reduce hunger (negative HungerChange = fills hunger in PZ terms).
    local hunger = item:getHunger()
    if not hunger or hunger >= 0 then return false end
    -- Exclude non-food.
    if not item:isFood() then return false end
    -- Exclude blacklisted raw items.
    if isBlacklisted(item) then return false end
    -- Exclude items flagged as needing cooking (IsCookable and not cooked).
    local cookable = false
    pcall(function()
        cookable = item:isCookable() and not item:isCooked()
    end)
    if cookable then return false end
    return true
end

-- Returns the "urgency" value used for rot-first sorting.
-- Lower = more urgent (eat this first).
-- Items with no expiry sort last (large positive value).
local function urgency(item)
    local gd = getGameTime():getWorldAgeHours() / 24.0
    local rotten
    pcall(function() rotten = item:getDaysTotallyRotten() end)
    if not rotten or rotten <= 0 then return 9999 end
    return rotten - gd
end

-- Collect all edible items from the given containers, sorted rot-first.
local function collectFood(pantryList)
    local items = {}
    for _, entry in ipairs(pantryList) do
        local cont = entry.container
        if cont then
            local itemList = cont:getItems()
            if itemList then
                for i = 0, itemList:size() - 1 do
                    local it = itemList:get(i)
                    if isEdible(it) then
                        table.insert(items, it)
                    end
                end
            end
        end
    end
    -- Sort rot-first (ascending urgency).
    table.sort(items, function(a, b)
        return urgency(a) < urgency(b)
    end)
    return items
end

-- Consume up to `needed` hunger points from the item list.
-- Removes fully-consumed items from their containers; adjusts Use counts on
-- partial items. Returns the amount of hunger actually covered.
local function consumeFood(items, needed)
    local covered = 0
    for _, item in ipairs(items) do
        if covered >= needed then break end
        -- HungerChange is negative (e.g. -50 means the item reduces hunger by 50).
        local perItem = math.abs(item:getHunger())
        if perItem > 0 then
            local cont
            pcall(function() cont = item:getContainer() end)
            if cont then
                local remaining = needed - covered

                if perItem <= remaining then
                    -- Consume the whole item.
                    covered = covered + perItem
                    pcall(function() cont:Remove(item) end)
                else
                    -- Consume a fraction. PZ doesn't expose a fractional eat API for
                    -- world items, so we reduce the item's Use count proportionally.
                    -- Use (0..1 float) represents how much of the item is left.
                    local fraction = remaining / perItem
                    local currentUse
                    pcall(function() currentUse = item:getCurrentUses() end)
                    if currentUse and currentUse > 0 then
                        -- Integer-use items (e.g. PeanutButter uses=6).
                        local usesToConsume = math.max(1, math.floor(currentUse * fraction + 0.5))
                        local newUses = currentUse - usesToConsume
                        if newUses <= 0 then
                            covered = covered + perItem
                            pcall(function() cont:Remove(item) end)
                        else
                            pcall(function() item:setCurrentUses(newUses) end)
                            covered = covered + perItem * (usesToConsume / currentUse)
                        end
                    else
                        -- Single-portion item: consume it and take the surplus.
                        covered = covered + perItem
                        pcall(function() cont:Remove(item) end)
                    end
                end
            end
        end
    end
    return covered
end

-- Emit a halo warning to the player about a hungry building.
local function warnHungry(player, shortfall, buildingId)
    if not (HaloTextHelper and HaloTextHelper.addText) then return end
    local msg = string.format("Residents are hungry! Pantry ran short by %d.", math.ceil(shortfall))
    pcall(function() HaloTextHelper.addText(player, msg) end)
    if KH and KH.DEBUG then
        print(string.format("[KH][FoodPass] Building %s: shortfall %.1f hunger", buildingId, shortfall))
    end
end

-- ---- main pass ----

local function runFoodPass()
    local player = getPlayer()
    if not player then return end

    local territories = KH.Home and KH.Home.listAll and KH.Home.listAll(player)
    if not territories then return end

    for _, terr in ipairs(territories) do
        -- Only Homesteads and Safehouses have residents.
        if terr.kind == "homestead" or terr.kind == "safehouse" then
            local buildingId = terr.id
            local resCount = KH.Resident.countActiveInBuildingId(player, buildingId)
            if resCount > 0 then
                local pantries = KH.Resident.getPantriesInBuildingId(player, buildingId)
                if #pantries == 0 then
                    -- No pantry designated. Warn but don't crash.
                    if KH and KH.DEBUG then
                        print(string.format("[KH][FoodPass] Building %s has %d residents but no pantry.", buildingId, resCount))
                    end
                else
                    local needed  = resCount * HUNGER_PER_PASS
                    local food    = collectFood(pantries)
                    local covered = consumeFood(food, needed)

                    local shortfall = needed - covered
                    if shortfall > 1 then
                        warnHungry(player, shortfall, buildingId)
                    elseif KH and KH.DEBUG then
                        print(string.format("[KH][FoodPass] Building %s: fed %d residents (%.1f hunger covered).",
                            buildingId, resCount, covered))
                    end
                end
            end
        end
    end
end

-- ---- hourly hook ----

local _lastPassHour = -1

local function onEveryOneHour()
    local gt = getGameTime()
    if not gt then return end
    local hour = gt:getHour()
    -- Guard against firing twice if the event somehow fires at the same hour.
    if hour == _lastPassHour then return end
    if MEAL_HOURS[hour] then
        _lastPassHour = hour
        runFoodPass()
    end
end

Events.EveryOneMinute.Add(function()
    -- We hook EveryOneMinute and check the hour ourselves rather than
    -- EveryOneHour, because EveryOneHour can miss the exact hour boundary
    -- on some PZ versions. This is lightweight - runFoodPass only fires 3x/day.
    local gt = getGameTime()
    if not gt then return end
    local hour = gt:getHour()
    if hour ~= _lastPassHour and MEAL_HOURS[hour] then
        _lastPassHour = hour
        runFoodPass()
    end
end)

print("[KH] FoodPass v0.0.1 registered (meals at 6am, noon, 6pm).")
