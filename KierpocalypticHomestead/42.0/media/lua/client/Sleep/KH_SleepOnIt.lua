-- Kierpocalyptic Homestead - Sleep On It
--
-- While the player is ASLEEP, gently shed negative *mood* moodlets: Stress,
-- Boredom, Unhappiness, Panic. Basic survival needs (hunger, thirst, fatigue,
-- etc.) are deliberately untouched - sleeping shouldn't feed you. We only ever
-- *reduce* these while asleep; how fast they rebuild once awake is unchanged.
--
-- Uses the same CharacterStat get/set accessors as KH_NeedsCore, and the same
-- isAsleep() poll as KH_SleepInFilth. Panic is referenced defensively in case
-- the field name differs in a given build (a nil stat is simply skipped).

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.SleepOnIt = "0.0.1"

-- Per in-game-minute reductions while asleep. EveryOneMinute fires for each
-- simulated minute, and sleep fast-forwards time, so these add up over a night.
-- Gentle on purpose ("lose some"), and floored at 0. Tune to taste.
local RATES = {
    stress      = 0.0025,  -- STRESS is 0..1
    boredom     = 0.45,    -- 0..100
    unhappiness = 0.30,    -- 0..100
    panic       = 1.5,     -- 0..100 (drains fast; vanilla also decays it awake)
}

-- Subtract `amt` from a stat, floored at 0. Skips silently if the stat doesn't
-- exist (CharacterStat.PANIC nil) or the engine call fails.
local function reduce(stats, stat, amt)
    if stat == nil or not amt then return end
    local ok, v = pcall(function() return stats:get(stat) end)
    if not ok or v == nil then return end
    local n = v - amt
    if n < 0 then n = 0 end
    pcall(function() stats:set(stat, n) end)
end

local function tick()
    local p = getPlayer()
    if not p or p:isDead() then return end
    local asleep = false
    pcall(function() asleep = p:isAsleep() end)
    if not asleep then return end
    local stats = p:getStats()
    if not stats then return end
    reduce(stats, CharacterStat.STRESS,      RATES.stress)
    reduce(stats, CharacterStat.BOREDOM,     RATES.boredom)
    reduce(stats, CharacterStat.UNHAPPINESS, RATES.unhappiness)
    reduce(stats, CharacterStat.PANIC,       RATES.panic)
end

Events.EveryOneMinute.Add(tick)

print("[KH] Sleep On It loaded (sheds Stress/Boredom/Unhappiness/Panic while asleep)")
