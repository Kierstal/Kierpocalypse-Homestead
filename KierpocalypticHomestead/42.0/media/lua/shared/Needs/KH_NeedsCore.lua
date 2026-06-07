-- Kierpocalyptic Homestead - shared Needs / Moodlet helpers
--
-- Used by KH_FilthMoodlet, KH_DirtMoodlet, KH_BathNeed, KH_ToiletNeed.
-- All four share the same shape: tick -> score -> apply trait-modified
-- mood deltas -> emit thought line on threshold crossing.
--
-- Need values are 0..100 floats persisted in player:getModData()[key].
-- Mood deltas route through existing vanilla Stats:
--   stats:get(CharacterStat.STRESS) / :set(CharacterStat.STRESS, x)  (0..1 float)
--   stats:get(CharacterStat.BOREDOM) / :set    (0..100)
--   stats:get(CharacterStat.UNHAPPINESS) / :set  (0..100)  [B42: lives on Stats, not Body]
--
-- Threshold crossing helpers compare a current value against a sorted
-- list of cutoffs to detect rising/falling transitions between named tiers.

require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.NeedsCore = "0.0.1"
KH.Needs = KH.Needs or {}

-- ------------------------------------------------------------------
-- modData accessors
-- ------------------------------------------------------------------

-- Get or set a need float (0..100) in player modData.
function KH.Needs.get(player, key)
    if not player or not key then return 0 end
    local d = player:getModData()
    return tonumber(d[key]) or 0
end

function KH.Needs.set(player, key, value)
    if not player or not key then return end
    local d = player:getModData()
    if value < 0 then value = 0 end
    if value > 100 then value = 100 end
    d[key] = value
end

function KH.Needs.add(player, key, delta)
    local cur = KH.Needs.get(player, key)
    KH.Needs.set(player, key, cur + (delta or 0))
end

-- ------------------------------------------------------------------
-- Trait-modifier helper
-- ------------------------------------------------------------------

-- Returns a {penaltyMult, rewardMult} table based on KH:NeatFreak / KH:Slob.
-- penaltyMult applies when score is HIGH (filthy, dirty, urgent toilet).
-- rewardMult applies when score is LOW (clean, fresh).
-- Default 1.0/1.0 for neither trait.
function KH.Needs.cleanlinessModifiers(player)
    if not player then return 1.0, 1.0 end
    if KH.hasTrait and KH.hasTrait(player, "KH:NeatFreak") then
        return 1.75, 1.75
    elseif KH.hasTrait and KH.hasTrait(player, "KH:Slob") then
        return 0.4, 0.0  -- slob feels minimal penalty, gets no clean reward
    end
    return 1.0, 1.0
end

-- ------------------------------------------------------------------
-- Threshold crossing
-- ------------------------------------------------------------------

-- Given a value and sorted list of cutoffs [c1, c2, c3], returns the
-- index of the highest cutoff <= value, or 0 if below all of them.
-- Example: value=37, cutoffs={20,50,80} -> returns 1 (in [20..50)).
function KH.Needs.tier(value, cutoffs)
    local tier = 0
    for i, c in ipairs(cutoffs) do
        if value >= c then tier = i else break end
    end
    return tier
end

-- Track last tier in modData. Returns nil if no transition, or
-- {oldTier, newTier, direction = "up"/"down"} if crossed.
function KH.Needs.checkCrossing(player, key, value, cutoffs)
    if not player or not key then return nil end
    local d = player:getModData()
    local lastKey = "KH_lastTier_" .. key
    local newTier = KH.Needs.tier(value, cutoffs)
    local oldTier = d[lastKey] or 0
    d[lastKey] = newTier
    if newTier ~= oldTier then
        return { oldTier = oldTier, newTier = newTier,
                 direction = (newTier > oldTier) and "up" or "down" }
    end
    return nil
end

-- ------------------------------------------------------------------
-- Mood delta application
-- ------------------------------------------------------------------

-- Apply per-tick mood deltas with floor/ceiling caps.
-- spec: { stress=number, unhappiness=number, boredom=number,
--         stressFloor=0..1, unhappinessFloor=0..100, boredomFloor=0..100,
--         stressCap=0..1, unhappinessCap=0..100, boredomCap=0..100 }
-- Floors are the value the delta can't push BELOW.
-- Caps are the value the delta can't push ABOVE.
function KH.Needs.applyMoodDelta(player, spec)
    if not player or not spec then return end
    -- Home territory dampens negative rises (KH.Home.bonusFor returns 0.6 at
    -- home, 1.0 elsewhere). Positive deltas (decreases) unchanged.
    if KH and KH.Home and KH.Home.isAtHome and KH.Home.isAtHome(player) then
        local mult = KH.Home.bonusFor(player, "negative_need") or 1.0
        if spec.stress      and spec.stress > 0      then spec.stress = spec.stress * mult end
        if spec.boredom     and spec.boredom > 0     then spec.boredom = spec.boredom * mult end
        if spec.unhappiness and spec.unhappiness > 0 then spec.unhappiness = spec.unhappiness * mult end
    end
    local stats = player:getStats()
    local body = player:getBodyDamage()

    if stats and spec.stress then
        local v = stats:get(CharacterStat.STRESS) or 0
        local n = v + spec.stress
        if spec.stress > 0 and spec.stressCap and n > spec.stressCap then n = spec.stressCap end
        if spec.stress < 0 and spec.stressFloor and n < spec.stressFloor then n = spec.stressFloor end
        if n < 0 then n = 0 elseif n > 1 then n = 1 end
        stats:set(CharacterStat.STRESS, n)
    end

    if stats and spec.boredom then
        local v = stats:get(CharacterStat.BOREDOM) or 0
        local n = v + spec.boredom
        if spec.boredom > 0 and spec.boredomCap and n > spec.boredomCap then n = spec.boredomCap end
        if spec.boredom < 0 and spec.boredomFloor and n < spec.boredomFloor then n = spec.boredomFloor end
        if n < 0 then n = 0 elseif n > 100 then n = 100 end
        stats:set(CharacterStat.BOREDOM, n)
    end

    if stats and spec.unhappiness then
        local v = stats:get(CharacterStat.UNHAPPINESS) or 0
        local n = v + spec.unhappiness
        if spec.unhappiness > 0 and spec.unhappinessCap and n > spec.unhappinessCap then n = spec.unhappinessCap end
        if spec.unhappiness < 0 and spec.unhappinessFloor and n < spec.unhappinessFloor then n = spec.unhappinessFloor end
        if n < 0 then n = 0 elseif n > 100 then n = 100 end
        stats:set(CharacterStat.UNHAPPINESS, n)
    end
end

-- Convenience: scale a base spec by trait multiplier.
function KH.Needs.scaledDelta(baseSpec, mult)
    local out = {}
    for k, v in pairs(baseSpec) do
        if type(v) == "number" and (k == "stress" or k == "boredom" or k == "unhappiness") then
            out[k] = v * (mult or 1.0)
        else
            out[k] = v
        end
    end
    return out
end

-- ------------------------------------------------------------------
-- Compounding rule (used by Filth + Dirt moodlets)
-- ------------------------------------------------------------------

-- If both filthScore and personalDirtScore are >= their respective "high"
-- thresholds, multiply both penalties by KH_COMPOUND_MULT (1.4).
-- Modules call this to decide whether to scale their own per-tick deltas.
KH.Needs.COMPOUND_MULT = 1.4

function KH.Needs.isCompoundedFilthDirt(player, filthHigh, dirtHigh)
    if not player then return false end
    local fs = KH.Needs.get(player, "KH_lastFilthScore") or 0
    local ds = KH.Needs.get(player, "KH_lastDirtScore") or 0
    return fs >= (filthHigh or 3) and ds >= (dirtHigh or 30)
end

print("[KH] NeedsCore v" .. KH.modules.NeedsCore .. " loaded")
