-- Kierpocalyptic Homestead - Pluviophile / Pluviophobe
--
-- Periodic stress and unhappiness changes during rain. Direction depends on
-- the trait the character has. Magnitude doubles when player is outside.

require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.Pluvio = "0.0.1"

local STRESS_DELTA       = 0.005
local UNHAPPY_DELTA      = 0.5
local OUTDOORS_MULT      = 2.0
local MIN_RAIN_INTENSITY = 0.10

local function getRainIntensity()
    local cm = getClimateManager()
    if not cm then return 0 end
    if cm.getPrecipitationIntensity then
        return cm:getPrecipitationIntensity() or 0
    end
    return 0
end

local function isOutdoors(player)
    if player.isInARoom then return not player:isInARoom() end
    return true
end

local function tick()
    local player = getPlayer()
    if not player or player:isDead() then return end

    local intensity = getRainIntensity()
    if intensity < MIN_RAIN_INTENSITY then return end

    local hasPhile = KH.hasTrait(player, "KH:Pluviophile")
    local hasPhobe = KH.hasTrait(player, "KH:Pluviophobe")
    if not hasPhile and not hasPhobe then return end

    local sign = hasPhile and -1 or 1
    local mult = isOutdoors(player) and OUTDOORS_MULT or 1.0

    local stressChange  = sign * STRESS_DELTA  * mult * intensity
    local unhappyChange = sign * UNHAPPY_DELTA * mult * intensity

    local stats = player:getStats()
    local body  = player:getBodyDamage()
    if stats and stats.getStress and stats.setStress then
        local s = stats:get(CharacterStat.STRESS) + stressChange
        if s < 0 then s = 0 end
        if s > 1 then s = 1 end
        stats:set(CharacterStat.STRESS, s)
    end
    if stats and stats.set then
        local u = stats:get(CharacterStat.UNHAPPINESS) + unhappyChange
        if u < 0 then u = 0 end
        if u > 100 then u = 100 end
        stats:set(CharacterStat.UNHAPPINESS, u)
    end
end

Events.EveryOneMinute.Add(tick)
