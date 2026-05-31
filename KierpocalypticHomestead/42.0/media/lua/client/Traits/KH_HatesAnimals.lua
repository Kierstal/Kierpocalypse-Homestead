-- Kierpocalyptic Homestead - Hates Animals
--
-- Mirror of TherapyAnimals. While any animal is within SCAN_RADIUS, stress
-- and unhappiness creep UP toward an upper bound. One animal is enough;
-- multiple don't stack worse.

require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.HatesAnimals = "0.0.1"

local SCAN_RADIUS    = 5
local STRESS_DELTA   = 0.003
local UNHAPPY_DELTA  = 0.4
local CAP_FRACTION   = 0.6  -- creep up to 60% but no further from this source

local function _findAnimalNearby(player, radius)
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

Events.EveryOneMinute.Add(function()
    local p = getPlayer()
    if not p or p:isDead() then return end
    if not KH.hasTrait(p, "KH:HatesAnimals") then return end
    if not _findAnimalNearby(p, SCAN_RADIUS) then return end

    local stats = p:getStats()
    if stats and stats.set then
        pcall(function()
            local stress = stats:get(CharacterStat.STRESS) or 0
            if stress < CAP_FRACTION then
                local s = stress + STRESS_DELTA
                if s > CAP_FRACTION then s = CAP_FRACTION end
                stats:set(CharacterStat.STRESS, s)
            end
        end)
        pcall(function()
            local unhappy = stats:get(CharacterStat.UNHAPPINESS) or 0
            local cap = 100 * CAP_FRACTION
            if unhappy < cap then
                local u = unhappy + UNHAPPY_DELTA
                if u > cap then u = cap end
                stats:set(CharacterStat.UNHAPPINESS, u)
            end
        end)
    end
end)

print("[KH] HatesAnimals trait behavior loaded")
