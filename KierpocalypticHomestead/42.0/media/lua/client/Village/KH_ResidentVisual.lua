-- Kierpocalyptic Homestead - resident body (visual adapter)
--
-- ==========================================================================
-- !! UNVERIFIED API SURFACE - the ONE part of the resident system that needs
-- an in-game verification pass. !!
--
-- Everything else in the resident feature (registry, bedroll, placement flow,
-- reconciliation, halos) is built on vanilla API we're confident about and
-- works regardless of what happens in this file. This module is deliberately
-- the only place that touches IsoMannequin, so when we confirm the exact B42
-- spawn/dress signatures the fix is one file.
--
-- The B42 IsoMannequin construction signature could not be confirmed from
-- remote docs (JavaDocs block scraping). The spawn below is a BEST-EFFORT
-- probe wrapped so that failure is silent + logged: if it doesn't work, the
-- resident still exists in the registry (name/role/supplies/panel all
-- function) - it just has no visible body yet. Check console.txt for the
-- "[KH] ResidentVisual" lines after placing a resident; paste them back and
-- we finalize the real call.
--
-- TODO(verify): confirm against B42 -
--   * IsoMannequin constructor (cell/square/sprite vs cell/x/y/z)
--   * how to set gender / skin / pose / facing direction
--   * how to dress it (wear clothing item vs apply a mannequin "outfit" script)
-- ==========================================================================

require "Village/KH_Residents"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ResidentVisual = "0.1.0"
KH.ResidentVisual = KH.ResidentVisual or {}

-- Master switch. If the probe throws hard, we flip this off for the session so
-- we don't spam errors every reconcile tick.
KH.ResidentVisual.ENABLED = true

-- Marker key stamped on the mannequin's modData so we can find "our" body again
-- (despawn, reconcile) without confusing it with map-placed mannequins.
local MD_KEY = "KH_residentId"

-- Scan a square for a KH resident mannequin matching resId (or any, if resId
-- nil). Returns the IsoObject or nil. Defensive against partial APIs.
local function _findBodyOnSquare(sq, resId)
    if not sq then return nil end
    local objs
    pcall(function() objs = sq:getObjects() end)
    if not objs or not objs.size then return nil end
    for i = 0, objs:size() - 1 do
        local o
        pcall(function() o = objs:get(i) end)
        if o and instanceof(o, "IsoMannequin") then
            local md
            pcall(function() md = o:getModData() end)
            if md and (resId == nil or md[MD_KEY] == resId) then
                return o
            end
        end
    end
    return nil
end

KH.ResidentVisual.findBody = _findBodyOnSquare

-- Is there already a body for this resident at its recorded square?
function KH.ResidentVisual.hasBody(record)
    if not record or not record.pos then return false end
    local cell = getCell(); if not cell then return false end
    local sq = cell:getGridSquare(record.pos.x, record.pos.y, record.pos.z or 0)
    if not sq then return false end  -- chunk not loaded -> can't tell, treat as no body
    return _findBodyOnSquare(sq, nil) ~= nil
end

-- BEST-EFFORT spawn. Returns the body object or nil. Heavily guarded.
function KH.ResidentVisual.spawn(resId, record)
    if not KH.ResidentVisual.ENABLED then return nil end
    if not record or not record.pos then return nil end
    local cell = getCell(); if not cell then return nil end
    local x, y, z = record.pos.x, record.pos.y, record.pos.z or 0
    local sq = cell:getGridSquare(x, y, z)
    if not sq then
        if KH.DEBUG then print("[KH] ResidentVisual: chunk not loaded for " .. tostring(record.name) .. ", deferring body spawn") end
        return nil
    end

    -- Don't double-spawn.
    local existing = _findBodyOnSquare(sq, resId)
    if existing then return existing end

    local body
    -- Probe form 1: (cell, square, sprite)
    pcall(function() body = IsoMannequin.new(cell, sq, nil) end)
    -- Probe form 2: (cell, x, y, z)
    if not body then pcall(function() body = IsoMannequin.new(cell, x, y, z) end) end

    if not body then
        print("[KH] ResidentVisual: IsoMannequin spawn UNVERIFIED/failed for '" ..
              tostring(record.name) .. "' at " .. x .. "," .. y .. "," .. z ..
              " - resident exists without a body. See HOMESTEAD_RESIDENTS_DESIGN.md.")
        -- A hard nil here is fine; one failed probe shouldn't disable forever,
        -- but if IsoMannequin itself is missing, stop trying this session.
        if not IsoMannequin then KH.ResidentVisual.ENABLED = false end
        return nil
    end

    -- Place + register the body in the world. addToWorld is the IsoObject
    -- convention (same lesson as KH_DebugSpawnPet's IsoAnimal:addToWorld()).
    pcall(function() body:setSquare(sq) end)
    pcall(function() sq:AddTileObject(body) end)
    pcall(function() body:addToWorld() end)

    -- Stamp identity so we can find it again.
    pcall(function()
        local md = body:getModData()
        if md then md[MD_KEY] = resId end
    end)

    -- Best-effort cosmetics. All optional; failures are non-fatal.
    pcall(function() if body.setForname then body:setForname(record.name) end end)
    pcall(function() if body.setName    then body:setName(record.name)    end end)

    print("[KH] ResidentVisual: spawned body for '" .. tostring(record.name) ..
          "' (verify it renders + is dressed; tweak this module if not).")
    return body
end

-- Remove a resident's body from the world (dismiss / death). Best-effort.
function KH.ResidentVisual.despawn(resId, record)
    if not record or not record.pos then return end
    local cell = getCell(); if not cell then return end
    local sq = cell:getGridSquare(record.pos.x, record.pos.y, record.pos.z or 0)
    if not sq then return end  -- chunk not loaded; body (if any) leaves with chunk
    local body = _findBodyOnSquare(sq, resId)
    if not body then return end
    pcall(function() sq:transmitRemoveItemFromSquare(body) end)
    pcall(function() body:removeFromWorld() end)
    pcall(function() body:removeFromSquare() end)
    if KH.DEBUG then print("[KH] ResidentVisual: despawned body for " .. tostring(record.name)) end
end

print("[KH] ResidentVisual adapter v" .. KH.modules.ResidentVisual .. " loaded (mannequin spawn UNVERIFIED - see header).")
