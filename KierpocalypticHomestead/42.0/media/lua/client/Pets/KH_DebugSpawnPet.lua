-- Kierpocalyptic Homestead - DEBUG: force-spawn a raccoon at game start
--
-- Flip DEBUG_ENABLED to false to disable. When true, spawns one raccoonsow
-- (grey breed) on a tile adjacent to the player the first frame after world
-- load. Useful for testing the Pet system without scavenging.

-- Now gated on the global KH.DEBUG flag (set in KH_Init.lua). When debug
-- mode is on, spawn a small test menagerie on the first frame after world
-- load: a raccoon (adoptable -> pet), a chicken (small animal test), and
-- a cow calf (large-baby grows-into-pet test path).

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.DebugSpawnPet = "0.0.4"

-- Wildlife only - matches KH_ADOPTABLE_WILD in KH_Pet.lua. Livestock
-- (chickens, cows, pigs, sheep) are intentionally NOT in scope for the
-- pet system: livestock is livestock. Test set covers three adoptable
-- species at different sizes: large mammal (raccoon), rodent (rat),
-- lagomorph (rabbit doe).
local SPAWN_LIST = {
    { type = "raccoonsow",   breed = "grey"     },
    { type = "rat",          breed = "grey"     },
    { type = "rabdoe",       breed = "cottontail" },
}

-- Hard off-switch for the test-menagerie spawn, INDEPENDENT of KH.DEBUG.
-- KH.DEBUG still gates diagnostic prints elsewhere, but Kierstal is past
-- needing a random raccoon/rat/rabbit dumped next to her every world load
-- (and the "skip if already has a pet" guard misses when a pet wanders off
-- or dies and clears petId). Flip back to true only when actively testing
-- the adopt flow from scratch.
local SPAWN_ENABLED = false

local function debugEnabled()
    return SPAWN_ENABLED and (KH and KH.DEBUG) and true or false
end

local function spawnAt(cell, sq, animalType, breed)
    local ok, animal = pcall(function()
        return IsoAnimal.new(cell, sq:getX(), sq:getY(), sq:getZ(), animalType, breed)
    end)
    if not (ok and animal) then return false end
    -- CRITICAL: IsoAnimal.new() constructs the Java object but does NOT
    -- register it to the world's animal list. Without addToWorld() the
    -- animal is visible but invisible to native systems, and ISPickupAnimal
    -- will CTD the JVM on removeFromWorld(). Vanilla debug spawn and the
    -- trap path both call addToWorld() after construction.
    pcall(function() animal:addToWorld() end)
    print(string.format("[KH][debug] Spawned %s (%s) at %d,%d,%d",
        animalType, breed, sq:getX(), sq:getY(), sq:getZ()))
    return true
end

local function findAdjacentSquare(cell, pSq, used)
    local offsets = {
        {1, 0}, {-1, 0}, {0, 1}, {0, -1},
        {2, 0}, {-2, 0}, {0, 2}, {0, -2},
        {1, 1}, {-1, -1}, {1, -1}, {-1, 1},
    }
    for _, off in ipairs(offsets) do
        local key = off[1] .. "," .. off[2]
        if not used[key] then
            local sq = cell:getGridSquare(pSq:getX() + off[1], pSq:getY() + off[2], pSq:getZ())
            if sq then
                used[key] = true
                return sq
            end
        end
    end
    return nil
end

-- True if the player already owns a KH pet (any saved petId in modData).
-- Reads modData directly so we don't need to touch the KH_Pet module's
-- local petState helper.
local function playerAlreadyHasPet(p)
    if not p or not p.getModData then return false end
    local md = p:getModData()
    local state = md and md.KH_Pet
    return state and state.petId and true or false
end

local function trySpawn()
    if not debugEnabled() then return end
    local p = getPlayer(); if not p then return end
    -- Don't spawn the debug animal on returning loads if the player has
    -- already adopted a pet. The previous world has a pet rabbit/raccoon/
    -- rat already in the save - we'd be cluttering, not helping.
    if playerAlreadyHasPet(p) then
        print("[KH][debug] Skipping spawn - player already has an adopted pet.")
        return
    end
    local cell = getCell(); if not cell then return end
    local pSq = p:getCurrentSquare(); if not pSq then return end
    -- Pick ONE random animal from SPAWN_LIST so each new world has a
    -- surprise. Was "spawn all three" -- felt like a zoo.
    local spec = SPAWN_LIST[ZombRand(#SPAWN_LIST) + 1]
    if not spec then return end
    local sq = findAdjacentSquare(cell, pSq, {})
    if sq then spawnAt(cell, sq, spec.type, spec.breed) end
end

local spawned = false
local function spawnHook()
    if spawned then return end
    spawned = true
    Events.OnTick.Remove(spawnHook)
    trySpawn()
end
Events.OnGameStart.Add(function()
    if debugEnabled() then
        Events.OnTick.Add(spawnHook)
    end
end)

print("[KH] DebugSpawnPet registered (KH.DEBUG gated, random pick)")
