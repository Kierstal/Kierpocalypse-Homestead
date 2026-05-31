-- Kierpocalyptic Homestead - High Maintenance
--
-- The character cares about her surroundings, but only at HER place. When
-- she's at her claimed homestead, the homestead's level of decoration moves
-- her mood:
--   - Bare homestead (< 5 player-placed items): mood drip (stress + unhappy)
--   - Modest homestead (5-14 items): neutral
--   - Decorated homestead (15+): mood relief (-stress, -unhappy toward 50%)
--
-- "Player-placed" is detected via the KH_Placed modData flag we already set
-- on items when they're dropped via PZ's Place Item action (see KH_Pet.lua's
-- rummage system for the original tagger). Vanilla furniture in a claimed
-- house doesn't count - this rewards the player's own decoration choices.
--
-- The scan iterates floor objects within the homestead's building bounds.
-- We cache the count for an hour to keep tick cost low.

require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.HighMaintenance = "0.0.1"

local CACHE_TTL_HOURS  = 1.0
local BARE_THRESHOLD   = 5    -- below this = bare, mood penalty
local NICE_THRESHOLD   = 15   -- at or above = decorated, mood bonus

local STRESS_DELTA_PENALTY  = 0.003
local UNHAPPY_DELTA_PENALTY = 0.4
local STRESS_DELTA_BONUS    = -0.002
local UNHAPPY_DELTA_BONUS   = -0.3

-- Iterate the IsoBuilding the player is currently in. Returns nil if not
-- in a building or no homestead claim.
local function _currentHomesteadBuilding(p)
    local sq = p:getCurrentSquare(); if not sq then return nil end
    local kind
    pcall(function() kind = KH.Home and KH.Home.typeAt and KH.Home.typeAt(p, sq) end)
    if kind ~= "homestead" then return nil end
    local room = sq:getRoom(); if not room then return nil end
    local def = room.getBuilding and room:getBuilding()
    return def
end

-- Count items in the building that have KH_Placed = true on their modData.
-- We iterate building rooms -> squares -> objects -> world-inventory items.
-- This is O(rooms * squares * objects) but only runs hourly per cache_ttl.
local function _countPlacedInBuilding(building)
    if not building then return 0 end
    local total = 0
    local rooms; pcall(function() rooms = building:getRooms() end)
    if not rooms or not rooms.size then return 0 end
    for r = 0, rooms:size() - 1 do
        local room = rooms:get(r)
        local squares; pcall(function() squares = room and room:getSquares() end)
        if squares and squares.size then
            for s = 0, squares:size() - 1 do
                local sq = squares:get(s)
                local objs; pcall(function() objs = sq and sq:getObjects() end)
                if objs and objs.size then
                    for i = 0, objs:size() - 1 do
                        local o = objs:get(i)
                        if o and instanceof(o, "IsoWorldInventoryObject") then
                            local it; pcall(function() it = o:getItem() end)
                            if it then
                                local md; pcall(function() md = it:getModData() end)
                                if md and md.KH_Placed then
                                    total = total + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return total
end

-- Get cached count (or recompute if stale). Cache lives on player modData
-- so it survives between map cells but doesn't need world-global state.
local function _getCachedCount(p, building)
    local now = getGameTime():getWorldAgeHours()
    local md = p:getModData()
    md.KH_HMCache = md.KH_HMCache or {}
    -- Cache key by building IDString so re-entering a different homestead
    -- doesn't reuse a stale value.
    local key
    pcall(function() key = building and building.getDef and building:getDef() and building:getDef():getIDString() end)
    if not key then return _countPlacedInBuilding(building), now end
    local entry = md.KH_HMCache[tostring(key)]
    if entry and entry.t and (now - entry.t) < CACHE_TTL_HOURS then
        return entry.n, entry.t
    end
    local n = _countPlacedInBuilding(building)
    md.KH_HMCache[tostring(key)] = { n = n, t = now }
    return n, now
end

Events.EveryOneMinute.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    if not KH.hasTrait(p, "KH:HighMaintenance") then return end
    local building = _currentHomesteadBuilding(p)
    if not building then return end  -- outside homestead = no effect

    local count = _getCachedCount(p, building)
    local stress, unhappy
    if count < BARE_THRESHOLD then
        stress  = STRESS_DELTA_PENALTY
        unhappy = UNHAPPY_DELTA_PENALTY
    elseif count >= NICE_THRESHOLD then
        stress  = STRESS_DELTA_BONUS
        unhappy = UNHAPPY_DELTA_BONUS
    else
        return  -- modest: neutral, do nothing
    end

    local stats = p:getStats()
    if stats and stats.set then
        pcall(function()
            local s = (stats:get(CharacterStat.STRESS) or 0) + stress
            if s < 0 then s = 0 end
            if s > 1 then s = 1 end
            stats:set(CharacterStat.STRESS, s)
        end)
        pcall(function()
            -- For the bonus path, only relieve unhappiness down to 50, not 0
            local cur = stats:get(CharacterStat.UNHAPPINESS) or 0
            local nxt = cur + unhappy
            if unhappy < 0 and nxt < 50 then nxt = 50 end
            if nxt > 100 then nxt = 100 end
            if nxt < 0 then nxt = 0 end
            stats:set(CharacterStat.UNHAPPINESS, nxt)
        end)
    end
end)

print("[KH] HighMaintenance trait behavior loaded (homestead-decoration sensitive)")
