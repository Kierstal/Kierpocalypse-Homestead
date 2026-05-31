-- Kierpocalyptic Homestead - Needs Attention
--
-- The opposite of Loner. Stress rises when alone, relief when at least one
-- other player is within range. DOES NOT stack - one nearby player is enough
-- to fully suppress the rising stress.
--
-- In single player there are never other players, so the trait constantly
-- applies the alone-penalty. That's why its cost is higher (-4 vs Loner's -2).

require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.NeedsAttention = "0.0.1"

local SCAN_RADIUS    = 15  -- tiles
-- Cadence: every 10 minutes (per user request). The deltas below are sized
-- so the cumulative effect per game-hour matches the previous per-minute
-- balance: alone = ~0.12 stress/hour rise, ~15 unhappy/hour rise. With
-- ticks 10 min apart, that's 6 ticks/hour at the listed magnitudes.
local STRESS_ALONE   = 0.020    -- per 10 min when no one's around
local UNHAPPY_ALONE  = 2.5      -- per 10 min when no one's around
local STRESS_RELIEF  = -0.015   -- per 10 min when at least one player nearby
local UNHAPPY_RELIEF = -2.0     -- per 10 min when at least one player nearby

local function _hasOtherPlayerNearby(p)
    if not p then return false end
    local players
    pcall(function() players = getOnlinePlayers() end)
    if not players or not players.size then return false end
    local px, py, pz = p:getX(), p:getY(), p:getZ()
    for i = 0, players:size() - 1 do
        local other = players:get(i)
        if other and other ~= p and not other:isDead() then
            local ox, oy, oz = other:getX(), other:getY(), other:getZ()
            if oz == pz then
                local d2 = (ox - px)^2 + (oy - py)^2
                if d2 <= SCAN_RADIUS * SCAN_RADIUS then return true end
            end
        end
    end
    return false
end

Events.EveryTenMinutes.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    if not KH.hasTrait(p, "KH:NeedsAttention") then return end
    local nearby = _hasOtherPlayerNearby(p)
    local stressDelta  = nearby and STRESS_RELIEF  or STRESS_ALONE
    local unhappyDelta = nearby and UNHAPPY_RELIEF or UNHAPPY_ALONE

    local stats = p:getStats()
    if stats and stats.set then
        pcall(function()
            local s = (stats:get(CharacterStat.STRESS) or 0) + stressDelta
            if s < 0 then s = 0 end
            if s > 1 then s = 1 end
            stats:set(CharacterStat.STRESS, s)
        end)
        pcall(function()
            local u = (stats:get(CharacterStat.UNHAPPINESS) or 0) + unhappyDelta
            if u < 0 then u = 0 end
            if u > 100 then u = 100 end
            stats:set(CharacterStat.UNHAPPINESS, u)
        end)
    end
end)

print("[KH] NeedsAttention trait behavior loaded (companion-seeking)")
