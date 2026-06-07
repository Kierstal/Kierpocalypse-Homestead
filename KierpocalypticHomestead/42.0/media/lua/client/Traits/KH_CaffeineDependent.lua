-- Kierpocalyptic Homestead - Caffeine Dependent
--
-- If the player has KH:CaffeineDependent, track time since last caffeinated
-- consumption. After 36 in-game hours without, withdrawal sets in: small
-- stress + unhappiness drip until next caffeine hit. A single cup of coffee
-- or tea (any vanilla coffee/tea item) resets the timer.

require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.CaffeineDependent = "0.0.1"

local WITHDRAWAL_AFTER_HOURS = 36
local STRESS_DELTA_PER_MIN   = 0.0015
local UNHAPPY_DELTA_PER_MIN  = 0.15

-- vanilla caffeinated items (verified against B42 scripts/generated/items/).
-- Coffee grounds, brewed coffee, tea, caffeinated soda, AND caffeine pills.
-- In B42 the item id "PillsVitamins" is the actual caffeine-pills item
-- (Icon = PillsCaffeine, fatigueChange = -4, Tooltip = Tooltip_Vitamins);
-- the internal name is a misnomer kept for save compatibility.
local function isCaffeinated(itemType)
    if not itemType then return false end
    local t = tostring(itemType)
    -- Strip Base. prefix if present
    if t:sub(1, 5) == "Base." then t = t:sub(6) end
    if t == "Coffee2" or t == "Coffee" then return true end
    if t:find("^Teabag") then return true end          -- Teabag, Teabag2
    if t:find("^TeaCup") then return true end
    if t == "CoffeePot" or t == "Coffee_Brewed" then return true end
    if t:find("^Pop") then return true end             -- caffeinated sodas
    if t == "PillsVitamins" then return true end       -- the caffeine-pills item
    return false
end

-- B42 has no Events.OnEat. Hook ISEatFoodAction:perform() directly - it's
-- called once per completed eat action with self.character and self.item
-- available. We wrap so vanilla logic still runs.
require "TimedActions/ISEatFoodAction"

local _ced_origPerform = ISEatFoodAction.perform
function ISEatFoodAction:perform(...)
    pcall(function()
        local p = self.character
        local item = self.item
        if p and item and KH.hasTrait(p, "KH:CaffeineDependent") then
            local t; pcall(function() t = item.getType and item:getType() end)
            if isCaffeinated(t) then
                local md = p:getModData()
                md.KH_lastCaffeineHour = getGameTime():getWorldAgeHours()
            end
        end
    end)
    if _ced_origPerform then return _ced_origPerform(self, ...) end
end

-- Periodic check: if more than WITHDRAWAL_AFTER_HOURS since last caffeine,
-- apply withdrawal stress + unhappiness.
Events.EveryOneMinute.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    if not KH.hasTrait(p, "KH:CaffeineDependent") then return end
    local md = p:getModData()
    -- New char never had caffeine: backdate so withdrawal doesn't fire on
    -- day 1. Use current time, but mark as 0 hours so the threshold is real.
    if not md.KH_lastCaffeineHour then
        md.KH_lastCaffeineHour = getGameTime():getWorldAgeHours()
        return
    end
    local hoursSince = getGameTime():getWorldAgeHours() - md.KH_lastCaffeineHour
    if hoursSince < WITHDRAWAL_AFTER_HOURS then return end
    -- Scale severity: at threshold = 1x, at 2x threshold = 2x, capped at 3x.
    local sev = math.min(3.0, hoursSince / WITHDRAWAL_AFTER_HOURS)
    local stats = p:getStats()
    if stats and stats.set then
        pcall(function()
            local s = (stats:get(CharacterStat.STRESS) or 0) + STRESS_DELTA_PER_MIN * sev
            if s > 1 then s = 1 end
            stats:set(CharacterStat.STRESS, s)
        end)
        pcall(function()
            local u = (stats:get(CharacterStat.UNHAPPINESS) or 0) + UNHAPPY_DELTA_PER_MIN * sev
            if u > 100 then u = 100 end
            stats:set(CharacterStat.UNHAPPINESS, u)
        end)
    end
end)

print("[KH] CaffeineDependent trait behavior loaded")
