-- Kierpocalyptic Homestead - Easily Startled
--
-- Sudden loud events cause a brief panic spike + endurance drop. Triggers:
--  - Thunder cracks (OnThunderEvent)
--  - Player firing a firearm (OnPlayerAimingPerk fires per shot)
--
-- The penalty is a one-shot bump on each event, NOT a continuous drip. This
-- makes the trait bite in active moments (gunfights, storms) without
-- punishing calm play.

require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.EasilyStartled = "0.0.1"

local PANIC_BUMP        = 10   -- adds to current PANIC stat (0-100)
local STRESS_BUMP       = 0.10 -- adds to current STRESS (0-1)
local ENDURANCE_BUMP    = -0.05  -- subtracts from ENDURANCE (0-1)

local function startle(p)
    if not p or p:isDead() then return end
    local stats = p:getStats()
    if not stats or not stats.set then return end
    pcall(function()
        local pan = (stats:get(CharacterStat.PANIC) or 0) + PANIC_BUMP
        if pan > 100 then pan = 100 end
        stats:set(CharacterStat.PANIC, pan)
    end)
    pcall(function()
        local s = (stats:get(CharacterStat.STRESS) or 0) + STRESS_BUMP
        if s > 1 then s = 1 end
        stats:set(CharacterStat.STRESS, s)
    end)
    pcall(function()
        local e = (stats:get(CharacterStat.ENDURANCE) or 1) + ENDURANCE_BUMP
        if e < 0 then e = 0 end
        stats:set(CharacterStat.ENDURANCE, e)
    end)
end

-- Thunder cracks
if Events.OnThunderEvent and Events.OnThunderEvent.Add then
    Events.OnThunderEvent.Add(function()
        local p = getPlayer()
        if not p or not KH.hasTrait(p, "KH:EasilyStartled") then return end
        -- Only startle when player is outside or near a window (we can't
        -- easily check window-proximity, so just gate on outside for now -
        -- it's a reasonable approximation since indoor thunder is muffled).
        local outside = true
        if p.isInARoom then outside = not p:isInARoom() end
        if outside then startle(p) end
    end)
end

-- Player firing a firearm: B42's Events.OnPlayerAttackFinished fires with
-- (playerObj, weapon). Filter to ranged weapons so melee swings don't
-- trigger the startle. (Events.OnPlayerAimingPerk doesn't exist in B42.)
Events.OnPlayerAttackFinished.Add(function(character, weapon)
    if not character or not weapon then return end
    if not KH.hasTrait(character, "KH:EasilyStartled") then return end
    local ranged = false
    pcall(function() ranged = weapon.isRanged and weapon:isRanged() end)
    if not ranged then return end
    startle(character)
end)

print("[KH] EasilyStartled trait behavior loaded (thunder + gunshots startle)")
