-- Kierpocalyptic Homestead - Filth (room cleanliness) moodlet
--
-- Per-minute tick. Scans the room the player is currently in (via
-- KH_FilthScan), computes blood+trash score, applies trait-modified mood
-- deltas, emits a thought line on threshold crossings.
--
-- Outdoors: zero effect (room=nil). Pairs with KH_DirtMoodlet (personal
-- cleanliness) for the compounding rule.

require "Filth/KH_FilthScan"
require "Needs/KH_NeedsCore"
require "Thoughts/KH_Thoughts"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.FilthMoodlet = "0.0.1"

-- Thresholds: score (blood + trash) cutoffs for tier transitions
local THRESHOLDS = { 1, 3, 8 }  -- tier 0=none, 1=mild, 2=filthy, 3=squalor

-- Per-tier per-minute deltas (BEFORE trait multipliers).
-- Stress is 0..1 scale; unhappiness/boredom are 0..100.
local DELTAS = {
    [0] = { stress = -0.001, unhappiness = -0.2,  stressFloor = 0.25, unhappinessFloor = 25 },  -- clean
    [1] = nil,                                                                                    -- neutral, no effect
    [2] = { stress =  0.003, unhappiness =  0.5,  stressCap = 0.85, unhappinessCap = 85 },       -- filthy
    [3] = { stress =  0.005, unhappiness =  0.8,  stressCap = 0.95, unhappinessCap = 95 },       -- squalor
}

local function tick()
    local player = getPlayer()
    if not player or player:isDead() then return end

    local result = KH.FilthScan.scoreRoom(player)
    KH.Needs.set(player, "KH_lastFilthScore", result.total)

    local tier = KH.Needs.tier(result.total, THRESHOLDS)
    -- Special case: tier 0 only counts as "clean" reward if the room is
    -- actually big enough to feel like a real room (>= 4 squares). Otherwise
    -- it's a tiny closet/hallway, no reward.
    if tier == 0 and result.room then
        local sqs = result.room.getSquares and result.room:getSquares()
        if sqs and sqs.size and sqs:size() < 4 then
            return  -- too small to count as "clean reward"
        end
    end

    local delta = DELTAS[tier]
    if delta and result.room then  -- never apply outdoors (room is nil)
        local penaltyMult, rewardMult = KH.Needs.cleanlinessModifiers(player)
        local mult = (tier == 0) and rewardMult or penaltyMult
        -- Compounding rule: if also personally dirty, scale penalty
        if tier >= 2 and KH.Needs.isCompoundedFilthDirt(player, 3, 30) then
            mult = mult * KH.Needs.COMPOUND_MULT
        end
        KH.Needs.applyMoodDelta(player, KH.Needs.scaledDelta(delta, mult))
    end

    -- Threshold crossing -> flavor line. The "becameClean" line includes
    -- variants like "Finally, a space I can inhabit" that read as a sigh of
    -- relief about HER space - inappropriate for a gas station counter she
    -- happened to wipe down. Gate the cleanliness-emotion lines to her own
    -- claimed property (Homestead / Waystation / Safehouse). Other tiers
    -- (becameFilthy, squalor) are universal observations about the room
    -- and still fire anywhere.
    local crossing = KH.Needs.checkCrossing(player, "filth_room", result.total, THRESHOLDS)
    if crossing then
        if crossin