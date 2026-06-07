-- Kierpocalyptic Homestead - Crops go to seed instead of rotting
--
-- Vanilla: when nbOfGrow exceeds prop.fullGrown, the plant rots and is dead.
--   - rottenThis() sets state="rotten" and calls deadPlant() (locks it from harvest)
--   - isAlive() returns false for "rotten" state
--   - canHarvest() returns isAlive() and hasVegetable, so a rotten plant is unharvestable
--
-- Override: rotten plants stay in the ground as "bolted" - still harvestable,
-- but harvesting yields extra seeds and no vegetables. Visual still uses the
-- vanilla rotten sprite (per Kierstal: "we can use the Rotten state for the
-- bolted/seeded behavior instead").

require "Farming/SPlantGlobalObject"
require "Farming/SFarmingSystem"
require "Farming/farming_vegetableconf"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.BoltToSeed = "0.0.1"

-- Yield multiplier for bolted seed harvest (3x normal seed-per-vegetable)
local BOLTED_SEED_YIELD_MULT = 3
local BOLTED_SEED_MIN = 3

-- 1. rottenThis: keep harvestable as bolted, skip deadPlant
local original_rottenThis = SPlantGlobalObject.rottenThis
function SPlantGlobalObject:rottenThis()
    self.state = "rotten"
    self.bolted = true
    self.hasVegetable = true   -- canHarvest gates on this
    self.hasSeed = true
    if farming_vegetableconf and farming_vegetableconf.getSpriteName then
        self:setSpriteName(farming_vegetableconf.getSpriteName(self))
    end
    if farming_vegetableconf and farming_vegetableconf.getObjectName then
        self:setObjectName(farming_vegetableconf.getObjectName(self))
    end
    self:saveData()
    -- Intentionally NOT calling deadPlant() - that's what kills it in vanilla
end

-- 2. isAlive: consider bolted+rotten plants alive (so canHarvest passes)
local original_isAlive = SPlantGlobalObject.isAlive
function SPlantGlobalObject:isAlive()
    if self.state == "rotten" and self.bolted then return true end
    return original_isAlive(self)
end

-- 3. harvest: bolted plants yield seeds in place of vegetables
local original_harvest = SFarmingSystem.harvest
function SFarmingSystem:harvest(luaObject, player)
    if luaObject and luaObject.bolted and player then
        local props = farming_vegetableconf.props[luaObject.typeOfSeed]
        -- Prefer seedTypes[1] over seedName: vanilla Flax sets
        -- seedName="Base.Flax" (produce as planting input) but the real seed
        -- is in seedTypes ("Base.FlaxSeed"). Most crops have both pointing
        -- at the seed item directly, but a few use the produce-as-seed
        -- pattern and we want bolted harvest to give actual seeds.
        local seedItem = props and props.seedName
        if props and props.seedTypes and props.seedTypes[1] then
            seedItem = props.seedTypes[1]
        end
        if seedItem then
            local skill = player:getPerkLevel(Perks.Farming) or 0
            -- Use the same per-yield calc as vanilla, scaled
            local nVeg = 1
            if getVegetablesNumber and props.minVeg and props.maxVeg then
                nVeg = getVegetablesNumber(
                    props.minVeg, props.maxVeg,
                    props.minVegAutorized or props.minVeg,
                    props.maxVegAutorized or props.maxVeg,
                    luaObject, skill
                ) or 1
            end
            local seedPerVeg = props.seedPerVeg or 0.5
            local n = math.floor(nVeg * seedPerVeg * BOLTED_SEED_YIELD_MULT)
            if n < BOLTED_SEED_MIN then n = BOLTED_SEED_MIN end
            local items = player:getInventory():AddItems(seedItem, n)
            if sendAddItemsToContainer then
                sendAddItemsToContainer(player:getInventory(), items)
            end
        end
        -- Plant is done after seed harvest
        luaObject.hasVegetable = false
        luaObject.hasSeed = false
        luaObject.bolted = false
        luaObject:harvestThis()
        return
    end
    return original_harvest(self, luaObject, player)
end
