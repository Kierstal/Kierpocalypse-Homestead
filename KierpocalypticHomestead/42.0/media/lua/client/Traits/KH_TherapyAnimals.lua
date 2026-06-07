-- Kierpocalyptic Homestead - Therapy Animals
--
-- While any animal is within SCAN_RADIUS, stress, unhappiness, and boredom
-- drift down toward the floor (CAP_FRACTION of max). One animal is enough;
-- multiple do not stack.

require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.TherapyAnimals = "0.0.1"

local SCAN_RADIUS    = 5
local STRESS_DELTA   = -0.003
local UNHAPPY_DELTA  = -0.4
local BOREDOM_DELTA  = -0.4
local CAP_FRACTION   = 0.5

local function findAnimalNearby(player, radius)
    local cell = getCell()
    if not cell then return false end
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())

    for dx = -radius, radius do
        for dy = -radius, radius do
            local sq = cell:getGridSquare(px + dx, py + dy, pz)
            if sq then
                local movables = sq:getMovingObjects()
                if movables then
                    local n = movables:size()
                    for i = 0, n - 1 do
                        local obj = movables:get(i)
                        if obj and instanceof(obj, "IsoAnimal") then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function tick()
    local player = getPlayer()
    if not player or player:isDead() then return end
    if not KH.hasTrait(player, "KH:TherapyAnimals") then return end
    if not findAnimalNearby(player, SCAN_RADIUS) then return end

    local stats = player:getStats()
    local body  = player:getBodyDamage()

    if stats then
        local stress = stats:get(CharacterStat.STRESS)
        if stress > CAP_FRACTION then
            local s = stress + STRESS_DELTA
            if s < CAP_FRACTION then s = CAP_FRACTION end
            stats:set(CharacterStat.STRESS, s)
        end
        local boredom = stats:get(CharacterStat.BOREDOM)
        local boredomCap = 100 * CAP_FRACTION
        if boredom > boredomCap then
            local b = boredom + BOREDOM_DELTA
            if b < boredomCap then b = boredomCap end
            stats:set(CharacterStat.BOREDOM, b)
        end
    end

    if body then
        local unhappy = stats:get(CharacterStat.UNHAPPINESS)
        local unhappyCap = 100 * CAP_FRACTION
        if unhappy > unhappyCap then
            local u = unhappy + UNHAPPY_DELTA
            if u < unhappyCap then u = unhappyCap end
            stats:set(CharacterStat.UNHAPPINESS, u)
        end
    end
end

Events.EveryOneMinute.Add(tick)
