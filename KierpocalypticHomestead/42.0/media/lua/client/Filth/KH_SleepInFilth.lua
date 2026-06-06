-- Kierpocalyptic Homestead - sleep-in-filth wake bump
--
-- On player wake, if the sleep room scored at or above the filthy threshold
-- OR personal dirt was high, fire a one-shot stress + unhappiness + bath
-- need spike, plus a flavor thought line.
--
-- We detect wake by polling player:isAsleep() per minute and watching for
-- the transition from asleep to awake. (B42's OnPlayerGetUp event may or
-- may not exist by that name; poll is foolproof.)

require "Filth/KH_FilthScan"
require "Dirt/KH_DirtScore"
require "Needs/KH_NeedsCore"
require "Thoughts/KH_Thoughts"
require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.SleepInFilth = "0.0.1"

local LAST_ASLEEP_KEY = "KH_lastWasAsleep"

local function onTick()
    local p = getPlayer()
    if not p or p:isDead() then return end
    -- Lifestyle: Hobbies owns hygiene when present + toggle on -> stay dormant.
    if KH.deferHygiene and KH.deferHygiene() then return end
    local d = p:getModData()
    local nowAsleep = (p.isAsleep and p:isAsleep()) and true or false
    local wasAsleep = d[LAST_ASLEEP_KEY] and true or false
    d[LAST_ASLEEP_KEY] = nowAsleep
    if wasAsleep and not nowAsleep then
        -- Just woke up. Check filth + dirt scores.
        local filth = KH.FilthScan.scoreRoom(p)
        local dirt = KH.DirtScore.compute(p)
        local roomFilthy = filth.total >= 3
        local personDirty = dirt.total >= 30
        if roomFilthy or personDirty then
            -- Apply one-shot bumps
            local stats = p:getStats()
            local body = p:getBodyDamage()
            if stats then
                local s = stats:get(CharacterStat.STRESS) or 0
                stats:set(CharacterStat.STRESS, math.min(0.9, s + 0.08))
            end
            if body then
                local u = stats:get(CharacterStat.UNHAPPINESS) or 0
                stats:set(CharacterStat.UNHAPPINESS, math.min(95, u + 8))
            end
            if KH.Bath and KH.Bath.bump then KH.Bath.bump(p, 10) end
            KH.Thoughts.emitForce(p, "filthSleep")
        end
    end
end

Events.EveryOneMinute.Add(onTick)

print("[KH] Sleep-in-filth wake bump hooked")
