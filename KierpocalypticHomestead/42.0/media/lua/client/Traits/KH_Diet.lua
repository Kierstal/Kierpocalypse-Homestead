-- Kierpocalyptic Homestead - Vegetarian / Vegan
--
-- Shared food-type detection feeds both:
--   Vegetarian: still eats it, but takes a -happiness hit per portion.
--   Vegan:      eat action is blocked entirely at ISEatFoodAction:start.
--
-- B42 FoodType values verified against scripts/generated/items/*.txt.
-- Animal-derived: Bacon, Beef, Cheese, DogFood, CatFood, Egg, Fish, Game,
-- Insect, Meat, Milk, Poultry, Roe, Sausage, Seafood, Venison.
-- (DogFood/CatFood contain animal protein in real life and lore.)

require "TimedActions/ISEatFoodAction"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.Diet = "0.0.1"

local ANIMAL_FOOD_TYPES = {
    Bacon=true, Beef=true, Cheese=true, DogFood=true, CatFood=true,
    Egg=true, Fish=true, Game=true, Insect=true, Meat=true, Milk=true,
    Poultry=true, Roe=true, Sausage=true, Seafood=true, Venison=true,
}

local VEGETARIAN_HAPPY_PENALTY = 15   -- adds to unhappiness per eat

-- Halo lines randomized per eat for vegetarians. Picked at random; keeps
-- the trait from being repetitive when the player has to eat animal
-- products to survive.
local VEGETARIAN_LINES = {
    "Ugh, gross.",
    "Best I can do in the apocalypse.",
}

local VEGAN_BLOCK_LINE = "I won't eat meat."

local function _isAnimalDerived(item)
    if not item then return false end
    local ft
    pcall(function() ft = item.getFoodType and item:getFoodType() end)
    if ft and ANIMAL_FOOD_TYPES[tostring(ft)] then return true end
    -- Fallback: check the item type string for known animal-product item ids
    -- that might not have FoodType set (rare in vanilla but defensive).
    local t
    pcall(function() t = item.getType and item:getType() end)
    if t then
        local s = tostring(t)
        if s == "Egg" or s:find("^Egg") then return true end
        if s == "Bacon" or s == "Steak" or s == "Sausage" then return true end
    end
    return false
end

-- ---- Vegan: block the eat action outright -----------------------------
-- Wrap start(). PZ's ISEatFoodAction calls start() once when the action
-- begins; we abort via forceComplete with a halo warning. We don't replace
-- isValid because it can be called repeatedly and we want the bad-text
-- feedback to fire exactly once per attempt.
local _origStart = ISEatFoodAction.start
function ISEatFoodAction:start(...)
    local result
    local blocked = false
    pcall(function()
        local char = self.character
        if char and KH.hasTrait(char, "KH:Vegan") and _isAnimalDerived(self.item) then
            blocked = true
            if HaloTextHelper and HaloTextHelper.addBadText then
                HaloTextHelper.addBadText(char, VEGAN_BLOCK_LINE)
            end
            -- Abort the action immediately
            if self.forceComplete then self:forceComplete()
            elseif self.forceStop then self:forceStop() end
        end
    end)
    if not blocked and _origStart then
        result = _origStart(self, ...)
    end
    return result
end

-- ---- Vegetarian: penalty on completing an animal-product eat ----------
-- B42 has no Events.OnEat. Wrap ISEatFoodAction:perform() so vanilla
-- consumption still runs, then apply the unhappiness penalty + halo.
-- (Vegan's start() block runs FIRST and aborts the action entirely, so
-- this path doesn't trigger for vegans even if the player has both traits
-- somehow - which the mutex pair prevents anyway.)
local _diet_origPerform = ISEatFoodAction.perform
function ISEatFoodAction:perform(...)
    pcall(function()
        local p = self.character
        local item = self.item
        if p and item
           and KH.hasTrait(p, "KH:Vegetarian")
           and _isAnimalDerived(item)
        then
            local stats = p:getStats()
            if stats and stats.set then
                pcall(function()
                    local u = (stats:get(CharacterStat.UNHAPPINESS) or 0) + VEGETARIAN_HAPPY_PENALTY
                    if u > 100 then u = 100 end
                    stats:set(CharacterStat.UNHAPPINESS, u)
                end)
            end
            if HaloTextHelper and HaloTextHelper.addBadText then
                local line = VEGETARIAN_LINES[ZombRand(#VEGETARIAN_LINES) + 1]
                pcall(function() HaloTextHelper.addBadText(p, line) end)
            end
        end
    end)
    if _diet_origPerform then return _diet_origPerform(self, ...) end
end

print("[KH] Diet (Vegetarian/Vegan) trait behavior loaded")
