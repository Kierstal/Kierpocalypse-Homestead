-- Kierpocalyptic Homestead - Personal dirt/blood moodlet
--
-- Per-minute tick. Reads HumanVisual dirt+blood + clothing dirtiness via
-- KH_DirtScore.compute, applies trait-modified mood deltas, emits a
-- thought line on threshold crossings.
--
-- Pairs with KH_FilthMoodlet via the compounding rule.

require "Dirt/KH_DirtScore"
require "Needs/KH_NeedsCore"
require "Thoughts/KH_Thoughts"
require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.DirtMoodlet = "0.0.1"

-- Score 0..100 thresholds
local THRESHOLDS = { 15, 35, 65 }  -- tier 1=grubby, 2=dirty, 3=reeking

local DELTAS = {
    [0] = nil,  -- clean, no effect (don't double-reward; filth moodlet handles room clean)
    [1] = { stress = 0.001, unhappiness = 0.2, stressCap = 0.7, unhappinessCap = 70 },  -- grubby
    [2] = { stress = 0.003, unhappiness = 0.4, stressCap = 0.85, unhappinessCap = 85 },  -- dirty
    [3] = { stress = 0.005, unhappiness = 0.7, stressCap = 0.95, unhappinessCap = 95 },  -- reeking
}

local function tick()
    local player = getPlayer()
    if not player or player:isDead() then return end
    -- Lifestyle: Hobbies owns hygiene when present + toggle on -> stay dormant.
    if KH.deferHygiene and KH.deferHygiene() then return end

    local score = KH.DirtScore.compute(player)
    KH.Needs.set(player, "KH_lastDirtScore", score.total)

    local tier = KH.Needs.tier(score.total, THRESHOLDS)
    local delta = DELTAS[tier]
    if delta then
        local penaltyMult = KH.Needs.cleanlinessModifiers(player)
        local mult = penaltyMult
        if tier >= 2 and KH.Needs.isCompoundedFilthDirt(player, 3, 30) then
            mult = mult * KH.Needs.COMPOUND_MULT
        end
        KH.Needs.applyMoodDelta(player, KH.Needs.scaledDelta(delta, mult))
    end

    -- Threshold transitions
    local crossing = KH.Needs.checkCrossing(player, "personal_dirt", score.total, THRESHOLDS)
    if crossing then
        if crossing.direction == "up" and crossing.newTier >= 2 then
            KH.Thoughts.emit(player, "dirtiness", "becameDirty")
        elseif crossing.direction == "down" and crossing.newTier == 0 then
            KH.Thoughts.emit(player, "dirtiness", "becameClean")
        elseif crossing.newTier == 3 then
            KH.Thoughts.emit(player, "dirtiness", "reeking")
        end
    end
end

Events.EveryOneMinute.Add(tick)

print("[KH] Dirt moodlet hooked")
