-- Kierpocalyptic Homestead - NPC recognition registry
--
-- Central source of truth for which NPCs the player has acknowledged.
-- Three relationship kinds:
--
--   "resident" - NPC invited to live in player's homestead. Recruited.
--                Converted from BWO bandit to SSR FurnitureFolk on arrival home.
--   "client"   - NPC stays in their own building. Player delivers food/supplies.
--                Their building is flagged as a delivery target.
--   "friend"   - NPC acknowledged but no commitment. Neutral, won't trigger Loner
--                stress when nearby. Useful for shopkeepers or one-off helpers.
--
-- The registry is persisted in the player's modData, so it survives save/load.
-- Multi-player aware: each player has their own registry. Single-player uses
-- player 0 implicitly.
--
-- Consumed by:
--   - KH_Loner (excludes recognized NPCs from stress scan)
--   - Future recruitment module (adds residents/clients on dialogue commit)
--   - Future hunger/feeding module (daily food check only on recognized targets)
--
-- Identifier ("id") is a stable string that the calling system can map back to
-- an entity. For Bandits NPCs, getOnlineID is the best candidate; SSR
-- FurnitureFolks have a character file name; merchant NPCs may have other tags.
-- The registry doesn't care about the format - it just keys by tostring(id).

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.NPCRegistry = "0.0.1"

local KEY = "KH_recognizedNPCs"

-- Lazily fetch the recognized-NPCs table from the player's mod data.
local function _registry(player)
    if not player then player = getPlayer() end
    if not player then return nil end
    local md
    pcall(function() md = player:getModData() end)
    if not md then return nil end
    if type(md[KEY]) ~= "table" then md[KEY] = {} end
    return md[KEY]
end

-- Get current world-age hours (best-effort; pcall guards against early-boot calls
-- before GameTime is initialized).
local function _now()
    local t = 0
    pcall(function()
        local gt = getGameTime()
        if gt and gt.getWorldAgeHours then t = gt:getWorldAgeHours() end
    end)
    return t
end

-- Mark an NPC as recognized. id should be a stable identifier.
-- kind: "resident" | "client" | "friend" (defaults to "friend").
-- displayName is optional and helps later UI / dialogue.
-- Returns true on success, false on failure.
function KH.recognizeNPC(id, kind, displayName, player)
    if not id then return false end
    local reg = _registry(player)
    if not reg then return false end
    local k = tostring(id)
    reg[k] = {
        kind = kind or "friend",
        displayName = displayName or tostring(id),
        since = _now(),
    }
    return true
end

-- Test whether an NPC is recognized. Returns the entry table on yes, nil on no.
function KH.isRecognizedNPC(id, player)
    if not id then return nil end
    local reg = _registry(player)
    if not reg then return nil end
    return reg[tostring(id)]
end

-- Forget an NPC (departure, death, fallout). Returns true if there was an entry
-- to remove.
function KH.forgetNPC(id, player)
    if not id then return false end
    local reg = _registry(player)
    if not reg then return false end
    local k = tostring(id)
    if reg[k] then
        reg[k] = nil
        return true
    end
    return false
end

-- Count recognized NPCs, optionally filtered by kind.
-- Used by KH_Loner to gate activation (no recognized NPCs = trait stays dormant).
function KH.recognizedNPCCount(kind, player)
    local reg = _registry(player)
    if not reg then return 0 end
    local n = 0
    for _, entry in pairs(reg) do
        if (not kind) or (entry.kind == kind) then
            n = n + 1
        end
    end
    return n
end

-- Iterate recognized NPCs. callback(id, entry) is called for each. Used by the
-- daily food-scan and any UI that lists "your people".
function KH.forEachRecognizedNPC(callback, player)
    if type(callback) ~= "function" then return end
    local reg = _registry(player)
    if not reg then return end
    for id, entry in pairs(reg) do
        callback(id, entry)
    end
end

print("[KH] NPCRegistry v0.0.1 loaded.")
