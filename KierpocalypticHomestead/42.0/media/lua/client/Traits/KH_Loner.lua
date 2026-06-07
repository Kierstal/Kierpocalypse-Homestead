-- Kierpocalyptic Homestead - Loner
--
-- Stress rises when STRANGERS are within range. Strangers are:
--   - other IsoPlayers (MP context, stacks per additional nearby player)
--   - BWO bandit NPCs that the player has NOT recognized via KH_NPCRegistry
--
-- Recognized NPCs (residents, clients, friends) do NOT contribute to Loner
-- stress. Kierstal's vision: she's a Loner with strangers, but her chosen
-- people are her people. The trait models selective sociality, not misanthropy.
--
-- ACTIVATION GATE: the bandit-scan branch only fires when the player has at
-- least one recognized NPC. Before that (no one recruited / acknowledged),
-- Loner stays in its original MP-only mode and is effectively dormant in SP.
-- This way the trait "turns on" the moment it becomes mechanically meaningful,
-- and doesn't ambush a fresh playthrough that hasn't met anyone yet.
--
-- v0.0.2 (2026-05-29): added bandit-scan via KH_NPCRegistry. Recognition is
-- empty until recruitment ships, so behavior is unchanged for current saves.

require "Core/KH_Util"
require "Core/KH_NPCRegistry"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.Loner = "0.0.2"

local SCAN_RADIUS         = 15  -- tiles
local STRESS_PER_PLAYER   = 0.0015  -- per minute, per nearby stranger
local UNHAPPY_PER_PLAYER  = 0.20    -- per minute, per nearby stranger

-- ---------- MP scan (original behavior) ----------

local function _countOtherPlayersNearby(p)
    if not p then return 0 end
    local players
    pcall(function() players = getOnlinePlayers() end)
    if not players or not players.size then return 0 end
    local px, py, pz = p:getX(), p:getY(), p:getZ()
    local count = 0
    for i = 0, players:size() - 1 do
        local other = players:get(i)
        if other and other ~= p and not other:isDead() then
            local ox, oy, oz = other:getX(), other:getY(), other:getZ()
            if oz == pz then
                local d2 = (ox - px)^2 + (oy - py)^2
                if d2 <= SCAN_RADIUS * SCAN_RADIUS then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- ---------- SP scan: unrecognized bandits ----------

-- Best-effort identity extraction. Bandits zombies carry mod data that includes
-- a stable id; fall back to getOnlineID if mod-data lookup fails. Either way,
-- we coerce to a string so the registry can index it.
local function _identifyNPC(zombie)
    if not zombie then return nil end
    local id
    pcall(function()
        local md = zombie:getModData()
        if md and md.id then id = md.id end
    end)
    if not id then
        pcall(function() id = zombie:getOnlineID() end)
    end
    if id then return tostring(id) end
    return nil
end

-- Returns true if the zombie object is a BWO bandit (not a regular zombie).
-- Defensive: returns false if Bandits mod isn't loaded.
local function _isBandit(zombie)
    if not zombie then return false end
    if not _G.Bandit then return false end
    -- Bandit.IsBandit is the canonical check; pcall in case the API shape
    -- changes in a future Bandits update.
    local ok, result = pcall(function() return Bandit.IsBandit(zombie) end)
    if ok and result then return true end
    -- Fallback: bandit mod data tag.
    local hasMD = false
    pcall(function()
        local md = zombie:getModData()
        if md and (md.clan or md.bandit) then hasMD = true end
    end)
    return hasMD
end

local function _countNearbyUnrecognizedBandits(p)
    -- Activation gate: only scan once the player is in the village system.
    if KH.recognizedNPCCount() == 0 then return 0 end

    local cell = getCell()
    if not cell then return 0 end
    local px = math.floor(p:getX())
    local py = math.floor(p:getY())
    local pz = math.floor(p:getZ())

    local count = 0
    for dx = -SCAN_RADIUS, SCAN_RADIUS do
        for dy = -SCAN_RADIUS, SCAN_RADIUS do
            local sq = cell:getGridSquare(px + dx, py + dy, pz)
            if sq then
                local movables = sq:getMovingObjects()
                if movables then
                    local n = movables:size()
                    for i = 0, n - 1 do
                        local obj = movables:get(i)
                        if obj and instanceof(obj, "IsoZombie") and _isBandit(obj) then
                            local id = _identifyNPC(obj)
                            if id and not KH.isRecognizedNPC(id) then
                                count = count + 1
                            end
                        end
                    end
                end
            end
        end
    end
    return count
end

-- ---------- Tick ----------

Events.EveryOneMinute.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    if not KH.hasTrait(p, "KH:Loner") then return end

    -- Combine MP players + unrecognized bandits. In SP without recruitment,
    -- both return 0 and the tick is a no-op.
    local nearby = _countOtherPlayersNearby(p) + _countNearbyUnrecognizedBandits(p)
    if nearby <= 0 then return end

    local stats = p:getStats()
    if stats and stats.set then
        pcall(function()
            local s = (stats:get(CharacterStat.STRESS) or 0) + STRESS_PER_PLAYER * nearby
            if s > 1 then s = 1 end
            stats:set(CharacterStat.STRESS, s)
        end)
        pcall(function()
            local u = (stats:get(CharacterStat.UNHAPPINESS) or 0) + UNHAPPY_PER_PLAYER * nearby
            if u > 100 then u = 100 end
            stats:set(CharacterStat.UNHAPPINESS, u)
        end)
    end
end)

print("[KH] Loner trait behavior v0.0.2 loaded (MP players + unrecognized bandits, gated on recognition).")
