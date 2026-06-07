-- Kierpocalyptic Homestead - Tinnitus
--
-- Gunshots and explosions aggravate persistent ear-ringing. After a loud
-- event within hearing range, the player accumulates a "ringing severity"
-- value that decays over an hour. While severity > 0, periodic stress and
-- unhappiness drip applies.
--
-- We don't have a clean OnGunshot event in B42, but we can sniff for loud
-- WorldSounds emitted near the player (the same mechanism vanilla uses to
-- attract zombies). Loud sounds have radius >= 30 typically. The sound
-- system runs on the server, so detection is best-effort via a periodic
-- scan of recent sounds.
--
-- Simpler approach: Events.OnPlayerAimingPerk fires when a player fires a
-- gun and gets aiming XP, but that's only when SHOOTING, not "hearing".
-- Cleanest: hook OnWeaponSwing for guns (the player firing) AND a periodic
-- check of nearby vehicles/zombies for gunshots-in-progress via WorldSound
-- list if PZ exposes one. As a minimum we cover the player's own gunfire,
-- which is by far the most common loud event.

require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.Tinnitus = "0.0.1"

local RINGING_DURATION_HOURS = 1.0
local STRESS_DELTA_PER_MIN   = 0.003
local UNHAPPY_DELTA_PER_MIN  = 0.4

-- Player's own gunshots: B42 has Events.OnPlayerAttackFinished which fires
-- with (playerObj, weapon) on every completed attack. We filter to ranged
-- weapons via weapon:isRanged() so melee swings don't aggravate tinnitus.
-- (Events.OnPlayerAimingPerk doesn't exist in B42; this is the correct hook.)
Events.OnPlayerAttackFinished.Add(function(character, weapon)
    if not character or not weapon then return end
    if not KH.hasTrait(character, "KH:Tinnitus") then return end
    local ranged = false
    pcall(function() ranged = weapon.isRanged and weapon:isRanged() end)
    if not ranged then return end
    local md = character:getModData()
    md.KH_tinnitusUntilHour = getGameTime():getWorldAgeHours() + RINGING_DURATION_HOURS
end)

-- Thunder: KH_ThoughtTriggers already hooks OnThunderEvent. We piggyback by
-- checking the climate manager's last-strike position relative to the player
-- on a 1-min tick. Cheap.
local function thunderingNearPlayer(p)
    local ts; pcall(function() ts = getClimateManager() and getClimateManager():getThunderStorm() end)
    if not ts then return false end
    local active
    pcall(function() active = ts:isActive() or ts:getClouds() and ts:getClouds() > 0.75 end)
    if not active then return false end
    -- crude: assume any active thunderstorm is "near enough" given we're
    -- outdoors-friendly; refine later if needed
    return true
end

-- Periodic tick: apply withdrawal-style drip while ringing is active.
Events.EveryOneMinute.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    if not KH.hasTrait(p, "KH:Tinnitus") then return end
    local md = p:getModData()
    local now = getGameTime():getWorldAgeHours()
    if not md.KH_tinnitusUntilHour or now > md.KH_tinnitusUntilHour then
        return  -- not currently ringing
    end
    local stats = p:getStats()
    if stats and stats.set then
        pcall(function()
            local s = (stats:get(CharacterStat.STRESS) or 0) + STRESS_DELTA_PER_MIN
            if s > 1 then s = 1 end
            stats:set(CharacterStat.STRESS, s)
        end)
        pcall(function()
            local u = (stats:get(CharacterStat.UNHAPPINESS) or 0) + UNHAPPY_DELTA_PER_MIN
            if u > 100 then u = 100 end
            stats:set(CharacterStat.UNHAPPINESS, u)
        end)
    end
end)

-- Per-strike: extend the ringing duration when thunder cracks. KH_Thoughts
-- module already hooks the per-strike event; we add a separate hook here so
-- tinnitus isn't dependent on thoughts being installed.
if Events.OnThunderEvent and Events.OnThunderEvent.Add then
    Events.OnThunderEvent.Add(function()
        local p = getPlayer(); if not p or p:isDead() then return end
        if not KH.hasTrait(p, "KH:Tinnitus") then return end
        local md = p:getModData()
        md.KH_tinnitusUntilHour = getGameTime():getWorldAgeHours() + RINGING_DURATION_HOURS
    end)
end

print("[KH] Tinnitus trait behavior loaded (gunfire + thunder aggravate)")
