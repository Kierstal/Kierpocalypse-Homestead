-- Kierpocalyptic Homestead - Homestead Residents registry (data model)
--
-- The SOURCE OF TRUTH for placed "residents." Residents are an
-- illusion-of-population feature: a dressed IsoMannequin body (handled by the
-- client-side KH_ResidentVisual adapter) projected from a record stored here in
-- the player's modData. The record is authoritative and chunk-independent; the
-- body is disposable and re-spawned from the record on reload.
--
-- See notes/HOMESTEAD_RESIDENTS_DESIGN.md for the full design.
--
-- Two modData stores under the player:
--   md.KH_Bunks[bunkId]      = { x, y, z, buildingId, residentId=nil }
--       A "set down" bedroll. The physical bedroll world-item carries the same
--       bunkId in its own modData so the reconciliation sweep can tell when the
--       player has picked it up. One resident per bunk.
--   md.KH_Residents[resId]   = { name, role, bunkId, pos={x,y,z,buildingId},
--                                supplies={food,maxFood}, gifts={}, hp,maxHp,
--                                alive, want={}, createdHour, lastConsumeHour }
--
-- On create we also mirror the resident into KH_NPCRegistry via
-- KH.recognizeNPC(id, "resident", name) so the existing village-layer
-- consumers (KH_Loner stress exemption, recognizedNPCCount activation) light up
-- with no changes to those modules.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.Residents = "0.1.0"
KH.Residents = KH.Residents or {}

local BUNKS_KEY     = "KH_Bunks"
local RESIDENTS_KEY = "KH_Residents"

-- Role list. `skill` and `themeTag` are consumed later by the Phase 2 wants /
-- reward system (small XP in `skill`, a role-themed item gift). Defined here so
-- the placement submenu and the reward system share one source of truth.
KH.Residents.ROLES = {
    { id = "cook",      label = "Cook",      skill = "Cooking",         themeTag = "food" },
    { id = "farmer",    label = "Farmer",    skill = "Farming",         themeTag = "seed" },
    { id = "forager",   label = "Forager",   skill = "PlantScavenging", themeTag = "forage" },
    { id = "carpenter", label = "Carpenter", skill = "Woodwork",        themeTag = "wood" },
    { id = "medic",     label = "Medic",     skill = "Doctor",          themeTag = "firstaid" },
    { id = "guard",     label = "Guard",     skill = "Aiming",          themeTag = "ammo" },
    { id = "tailor",    label = "Tailor",    skill = "Tailoring",       themeTag = "fabric" },
    { id = "fisher",    label = "Fisher",    skill = "Fishing",         themeTag = "fishing" },
}

function KH.Residents.roleById(id)
    for _, r in ipairs(KH.Residents.ROLES) do
        if r.id == id then return r end
    end
    return nil
end

-- ---------- modData accessors ----------

local function _md(player)
    if not player then player = getPlayer() end
    if not player or not player.getModData then return nil end
    local md
    pcall(function() md = player:getModData() end)
    return md
end

local function _bunks(player)
    local md = _md(player); if not md then return nil end
    if type(md[BUNKS_KEY]) ~= "table" then md[BUNKS_KEY] = {} end
    return md[BUNKS_KEY]
end

local function _residents(player)
    local md = _md(player); if not md then return nil end
    if type(md[RESIDENTS_KEY]) ~= "table" then md[RESIDENTS_KEY] = {} end
    return md[RESIDENTS_KEY]
end

-- World-age hours, best-effort (matches KH_NPCRegistry's _now()).
local function _now()
    local t = 0
    pcall(function()
        local gt = getGameTime()
        if gt and gt.getWorldAgeHours then t = gt:getWorldAgeHours() end
    end)
    return t
end

-- Stable-ish unique id. Timestamp + random keeps collisions effectively nil for
-- a single-player save placing residents by hand.
local function _newId(prefix)
    local ms = 0
    pcall(function() ms = getTimestampMs() end)
    return prefix .. tostring(ms) .. "_" .. tostring(ZombRand(1000000))
end

-- ---------- Bunks ----------

-- Record a set-down bedroll. Returns the new bunkId (also stamp this onto the
-- physical bedroll world-item's modData so reconciliation can find it).
function KH.Residents.addBunk(player, x, y, z, buildingId)
    local b = _bunks(player); if not b then return nil end
    local id = _newId("KHbunk_")
    b[id] = { x = x, y = y, z = z, buildingId = buildingId, residentId = nil }
    return id
end

function KH.Residents.getBunk(player, bunkId)
    local b = _bunks(player); if not b then return nil end
    return b[bunkId]
end

function KH.Residents.removeBunk(player, bunkId)
    local b = _bunks(player); if not b then return end
    b[bunkId] = nil
end

-- Iterate bunks: callback(bunkId, bunk).
function KH.Residents.forEachBunk(player, callback)
    if type(callback) ~= "function" then return end
    local b = _bunks(player); if not b then return end
    for id, bunk in pairs(b) do callback(id, bunk) end
end

-- ---------- Residents ----------

-- Create a resident record bound to a bunk. Returns residentId or nil.
-- NOTE: this writes the record and mirrors it into KH_NPCRegistry. Spawning the
-- visible body is the caller's job (client-side KH.ResidentVisual.spawn), so
-- this stays free of any client-only UI/world dependency.
function KH.Residents.create(player, opts)
    opts = opts or {}
    local r = _residents(player); if not r then return nil end
    local id = _newId("KHres_")
    local now = _now()
    r[id] = {
        name      = opts.name or "Resident",
        role      = opts.role or "forager",
        bunkId    = opts.bunkId,
        pos       = { x = opts.x, y = opts.y, z = opts.z, buildingId = opts.buildingId },
        supplies  = { food = 0, maxFood = 12 },   -- topped up via Phase 2 "give"
        gifts     = {},
        hp        = 100, maxHp = 100,
        alive     = true,
        want      = nil,                            -- rolled by Phase 2 panel
        createdHour     = now,
        lastConsumeHour = now,
    }
    -- Bind the bunk both ways.
    if opts.bunkId then
        local bunk = KH.Residents.getBunk(player, opts.bunkId)
        if bunk then bunk.residentId = id end
    end
    -- Mirror into the recognition registry so Loner/village-activation see them.
    if KH.recognizeNPC then
        pcall(function() KH.recognizeNPC(id, "resident", r[id].name, player) end)
    end
    return id
end

function KH.Residents.get(player, resId)
    local r = _residents(player); if not r then return nil end
    return r[resId]
end

-- Remove a resident record. Unbinds its bunk (does NOT delete the bunk - the
-- bedroll may still be on the ground). Caller despawns the body.
function KH.Residents.remove(player, resId)
    local r = _residents(player); if not r then return false end
    local rec = r[resId]
    if not rec then return false end
    if rec.bunkId then
        local bunk = KH.Residents.getBunk(player, rec.bunkId)
        if bunk and bunk.residentId == resId then bunk.residentId = nil end
    end
    r[resId] = nil
    if KH.forgetNPC then pcall(function() KH.forgetNPC(resId, player) end) end
    return true
end

-- Iterate residents: callback(resId, record).
function KH.Residents.forEach(player, callback)
    if type(callback) ~= "function" then return end
    local r = _residents(player); if not r then return end
    for id, rec in pairs(r) do callback(id, rec) end
end

function KH.Residents.count(player)
    local r = _residents(player); if not r then return 0 end
    local n = 0
    for _ in pairs(r) do n = n + 1 end
    return n
end

KH.Residents._now = _now  -- exported for the consumption/want systems (Phase 2)

print("[KH] Residents registry v" .. KH.modules.Residents .. " loaded.")
