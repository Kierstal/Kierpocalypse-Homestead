-- Kierpocalyptic Homestead - Forage Feast eating bonus
--
-- When the Forage Feast trait is held and the player eats a fresh
-- forageable food (fruit, vegetable, mushroom, wild plant, wild herb,
-- berry), grants a one-time mood bump on completion of the eat action.

require "TimedActions/ISEatFoodAction"
require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ForageFeast_Eat = "0.0.2"

local FRESH_TAGS = {
    "base:fruit", "base:berry", "base:vegetables", "base:vegetable",
    "base:mushroom", "base:wildherb", "base:wildplant", "base:herbaltea",
}

local FRESH_TYPE_PATTERNS = {
    "berry", "fruit", "vegetable", "mushroom",
}

local UNHAPPY_BONUS = -8   -- happiness goes UP, so unhappiness goes DOWN
local BOREDOM_BONUS = -4

-- B42: hasTag(String) throws "No implementation found" - the engine wants
-- an ItemTag Java instance, not a free string. None of {berry, fruit, vegetable,
-- mushroom} are real ItemTag constants anyway. The right detection is via
-- Food:getFoodType() which returns a canonical string ("Fruits"/"Vegetables"/
-- "Berries"/"Mushrooms"). Type-name substring is a fallback for foraged items
-- whose getFoodType doesn't categorize them cleanly.
local FRESH_FOODTYPES = {
    ["fruits"] = true, ["vegetables"] = true, ["berries"] = true, ["mushrooms"] = true,
    -- Vanilla also sets these in some variants:
    ["fruit"] = true,  ["vegetable"] = true,
}

local function isFresh(item)
    if not item then return false end
    -- FoodType check (works only for Food items; pcall guards anything weird)
    if instanceof(item, "Food") and item.getFoodType then
        local ft = nil
        pcall(function() ft = item:getFoodType() end)
        if ft then
            local lower = string.lower(tostring(ft))
            if FRESH_FOODTYPES[lower] then return true end
        end
    end
    -- Fallback: type-name substring match (catches foraged items with weird
    -- categorization)
    if item.getType then
        local typ = string.lower(tostring(item:getType() or ""))
        for _, p in ipairs(FRESH_TYPE_PATTERNS) do
            if string.find(typ, p, 1, true) then return true end
        end
    end
    return false
end

local original_complete = ISEatFoodAction.complete
function ISEatFoodAction:complete()
    local result = original_complete(self)
    if self.character and self.item
       and KH.hasTrait and KH.hasTrait(self.character, "KH:ForageFeast")
       and isFresh(self.item) then
        local body = self.character:getBodyDamage()
        local stats = self.character:getStats()
        if stats and stats.set then
            local u = stats:get(CharacterStat.UNHAPPINESS) + UNHAPPY_BONUS
            if u < 0 then u = 0 end
            stats:set(CharacterStat.UNHAPPINESS, u)
        end
        if stats and stats.set then
            local b = stats:get(CharacterStat.BOREDOM) + BOREDOM_BONUS
            if b < 0 then b = 0 end
            stats:set(CharacterStat.BOREDOM, b)
        end
    end
    return result
end
