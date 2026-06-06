-- Kierpocalyptic Homestead - resident placement + lifecycle (client)
--
-- Wires the bedroll -> bunk -> resident flow onto the world context menu, and
-- runs the reconciliation sweep that keeps the registry honest against the
-- physical bedroll items in the world.
--
-- Flow (see notes/HOMESTEAD_RESIDENTS_DESIGN.md):
--   1. Craft a "Resident's Bedroll" item (KH.ResidentBedroll).
--   2. Stand inside a claimed Homestead, right-click a floor tile ->
--      "Set Down Resident Bedroll": consumes the item, drops a physical
--      bedroll on that tile, records a bunk.
--   3. Right-click any valid floor tile within 25 tiles of an unoccupied bunk
--      -> "Place Resident" -> pick a role -> type a name -> the resident is
--      created, its body spawned (KH_ResidentVisual), and a halo acknowledges.
--   4. Right-click a resident's tile -> "Dismiss Resident": removes them and
--      returns a bedroll item.
--   5. Reconciliation sweep (every 10 in-game minutes, loaded chunks only):
--      if a bunk's physical bedroll is gone (picked up), its resident is
--      dismissed; if a resident's chunk is loaded but its body is missing
--      (e.g. after reload), the body is re-spawned from the record.

require "Village/KH_Residents"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ResidentPlacement = "0.1.0"

local BEDROLL_TYPE = "KH.ResidentBedroll"
local PLACE_RANGE  = 25     -- tiles between a bunk and where a resident may stand
local BUNK_MD_KEY  = "KH_bunkId"

-- ---------- small helpers ----------

local function _halo(player, text)
    if HaloTextHelper and HaloTextHelper.addText and player then
        pcall(function() HaloTextHelper.addText(player, text) end)
    end
end

local function _buildingIdOfSquare(sq)
    if not sq then return nil end
    local b; pcall(function() b = sq:getBuilding() end)
    if not b then return nil end
    local def; pcall(function() def = b:getDef() end)
    if not def or not def.getIDString then return nil end
    local id; pcall(function() id = def:getIDString() end)
    return id
end

-- The clicked square, derived from the worldobjects list the context-menu hook
-- receives. An empty floor still carries its floor IsoObject, so [1] has a
-- square.
local function _clickedSquare(worldobjects)
    for _, o in ipairs(worldobjects) do
        local sq
        pcall(function() if o.getSquare then sq = o:getSquare() end end)
        if sq then return sq end
    end
    return nil
end

-- Is this a sane tile to stand a resident on / set a bedroll on? Walkable
-- floor, not solid, not a wall/object-blocked tile.
local function _isPlaceableFloor(sq)
    if not sq then return false end
    local floor
    pcall(function() floor = sq:getFloor() end)
    if not floor then return false end
    local solid = false
    pcall(function() solid = sq:isSolid() or sq:isSolidTrans() end)
    if solid then return false end
    return true
end

local function _hasBedroll(player)
    if not player then return false end
    local inv; pcall(function() inv = player:getInventory() end)
    if not inv then return false end
    local has = false
    pcall(function() has = inv:contains(BEDROLL_TYPE) end)
    return has
end

local function _removeOneBedroll(player)
    local inv; pcall(function() inv = player:getInventory() end)
    if not inv then return false end
    local items; pcall(function() items = inv:getItems() end)
    if not items then return false end
    for i = 0, items:size() - 1 do
        local it; pcall(function() it = items:get(i) end)
        if it and it.getFullType and it:getFullType() == BEDROLL_TYPE then
            pcall(function() inv:Remove(it) end)
            return true
        end
    end
    return false
end

local function _giveBedroll(player)
    local inv; pcall(function() inv = player:getInventory() end)
    if not inv then return end
    pcall(function() inv:AddItem(BEDROLL_TYPE) end)
end

-- Find the physical bedroll world-item carrying bunkId on a square. Returns the
-- IsoWorldInventoryObject (so the caller can remove it) or nil.
local function _bedrollObjectOnSquare(sq, bunkId)
    if not sq then return nil end
    local objs
    pcall(function() objs = sq:getWorldObjects() end)
    if not objs or not objs.size then return nil end
    for i = 0, objs:size() - 1 do
        local wo; pcall(function() wo = objs:get(i) end)
        local item
        if wo then pcall(function() if wo.getItem then item = wo:getItem() end end) end
        if item and item.getFullType and item:getFullType() == BEDROLL_TYPE then
            if bunkId == nil then return wo end
            local md; pcall(function() md = item:getModData() end)
            if md and md[BUNK_MD_KEY] == bunkId then return wo end
        end
    end
    return nil
end

-- Nearest unoccupied bunk within PLACE_RANGE of sq, in the same building.
-- Returns bunkId or nil.
local function _nearestEmptyBunk(player, sq)
    if not sq then return nil end
    local sx, sy, sz = sq:getX(), sq:getY(), sq:getZ()
    local bldId = _buildingIdOfSquare(sq)
    local best, bestD = nil, nil
    KH.Residents.forEachBunk(player, function(id, bunk)
        if bunk.residentId then return end
        if (bunk.z or 0) ~= sz then return end
        if bldId and bunk.buildingId and bunk.buildingId ~= bldId then return end
        local dx, dy = bunk.x - sx, bunk.y - sy
        local d2 = dx * dx + dy * dy
        if d2 <= PLACE_RANGE * PLACE_RANGE and (bestD == nil or d2 < bestD) then
            best, bestD = id, d2
        end
    end)
    return best
end

-- Resident whose body stands on this square (for the Dismiss option).
local function _residentAtSquare(player, sq)
    if not sq then return nil end
    local sx, sy, sz = sq:getX(), sq:getY(), sq:getZ()
    local found = nil
    KH.Residents.forEach(player, function(id, rec)
        if found then return end
        local p = rec.pos
        if p and p.x == sx and p.y == sy and (p.z or 0) == sz then found = id end
    end)
    return found
end

-- ---------- actions ----------

local function _onPlaceBedroll(player, sq)
    if not player or not sq then return end
    if not _removeOneBedroll(player) then
        _halo(player, "No bedroll to set down.")
        return
    end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local bldId = _buildingIdOfSquare(sq)
    local bunkId = KH.Residents.addBunk(player, x, y, z, bldId)
    -- Drop a physical bedroll on the tile, stamped with the bunkId, so picking
    -- it up later is detectable by the reconciliation sweep.
    pcall(function()
        local item = instanceItem(BEDROLL_TYPE)
        if item then
            local md = item:getModData(); if md then md[BUNK_MD_KEY] = bunkId end
            sq:AddWorldInventoryItem(item, 0.5, 0.5, 0.0)
        end
    end)
    _halo(player, "Bedroll set down. Right-click a nearby floor to place a resident.")
    if KH.DEBUG then print("[KH] ResidentPlacement: bunk " .. tostring(bunkId) .. " at " .. x .. "," .. y .. "," .. z) end
end

-- ISTextBox OK callback: target=player, param1=data{ x,y,z,buildingId,bunkId,role }
local function _onResidentNamed(player, button, data)
    if not button or button.internal ~= "OK" then return end
    if not player or not data then return end
    local name
    pcall(function() name = button.parent.entry:getText() end)
    if not name or name == "" then name = (data.role and data.role.label) or "Resident" end

    -- Guard: the bunk must still exist and be unoccupied.
    local bunk = KH.Residents.getBunk(player, data.bunkId)
    if not bunk or bunk.residentId then
        _halo(player, "That bedroll is no longer available.")
        return
    end

    local resId = KH.Residents.create(player, {
        name = name, role = data.role and data.role.id or "forager",
        x = data.x, y = data.y, z = data.z, buildingId = data.buildingId,
        bunkId = data.bunkId,
    })
    if not resId then return end

    -- Spawn the visible body (best-effort; resident exists either way).
    if KH.ResidentVisual and KH.ResidentVisual.spawn then
        local rec = KH.Residents.get(player, resId)
        pcall(function() KH.ResidentVisual.spawn(resId, rec) end)
    end

    _halo(player, name .. " is settling in.")
    if KH.Thoughts and KH.Thoughts.emit then
        pcall(function() KH.Thoughts.emit(player, "village", "resident_arrived") end)
    end
end

local function _onChooseRole(player, sq, bunkId, role)
    if not player or not sq then return end
    -- Capture coords now (squares can go stale between menu and callback).
    local data = {
        x = sq:getX(), y = sq:getY(), z = sq:getZ(),
        buildingId = _buildingIdOfSquare(sq),
        bunkId = bunkId, role = role,
    }
    local playerNum = player:getPlayerNum() or 0
    local modal = ISTextBox:new(0, 0, 320, 180,
        "Name your " .. (role and role.label or "resident") .. ":",
        "", player, _onResidentNamed, playerNum, data)
    modal:initialise()
    modal:addToUIManager()
end

local function _onDismiss(player, resId)
    if not player or not resId then return end
    local rec = KH.Residents.get(player, resId)
    if not rec then return end
    local name = rec.name or "The resident"
    local bunkId = rec.bunkId

    if KH.ResidentVisual and KH.ResidentVisual.despawn then
        pcall(function() KH.ResidentVisual.despawn(resId, rec) end)
    end
    KH.Residents.remove(player, resId)

    -- Remove the physical bedroll for that bunk and hand the item back.
    if bunkId then
        local bunk = KH.Residents.getBunk(player, bunkId)
        if bunk then
            local cell = getCell()
            local bsq = cell and cell:getGridSquare(bunk.x, bunk.y, bunk.z or 0)
            local wo = bsq and _bedrollObjectOnSquare(bsq, bunkId)
            if wo and bsq then pcall(function() bsq:transmitRemoveItemFromSquare(wo) end) end
            KH.Residents.removeBunk(player, bunkId)
        end
    end
    _giveBedroll(player)
    _halo(player, name .. " has moved on. (Bedroll recovered.)")
end

-- ---------- context menu hook ----------

local function onFillContext(playerNum, context, worldobjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local sq = _clickedSquare(worldobjects)
    if not sq then return end

    -- Everything here is homestead-gated: residents only belong in a claimed
    -- Homestead. (KH.Home.isAtHomestead checks the player's current building.)
    if not (KH.Home and KH.Home.isAtHomestead and KH.Home.isAtHomestead(player)) then
        return
    end

    local before = (context.options and #context.options) or 0

    -- Dismiss takes priority if the clicked tile holds a resident.
    local resHere = _residentAtSquare(player, sq)
    if resHere then
        KH.UI.markOption(context:addOption(getText("ContextMenu_KH_DismissResident"), player, _onDismiss, resHere))
    end

    if _isPlaceableFloor(sq) then
        -- Set down a bedroll (needs one in inventory).
        if _hasBedroll(player) then
            KH.UI.markOption(context:addOption(getText("ContextMenu_KH_PlaceBedroll"), player, _onPlaceBedroll, sq))
        end
        -- Place a resident (needs an empty bunk within range).
        local bunkId = _nearestEmptyBunk(player, sq)
        if bunkId then
            local parent = context:addOption(getText("ContextMenu_KH_PlaceResident"), worldobjects, nil)
            KH.UI.markOption(parent)
            local sub = context:getNew(context)
            context:addSubMenu(parent, sub)
            for _, role in ipairs(KH.Residents.ROLES) do
                sub:addOption(role.label, player, _onChooseRole, sq, bunkId, role)
            end
        end
    end

    -- Keep KH options grouped at the top, matching the rest of the mod.
    local after = (context.options and #context.options) or 0
    if KH.UI and KH.UI.moveLastAddedToTop then
        KH.UI.moveLastAddedToTop(context, after - before)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContext)

-- ---------- reconciliation sweep ----------
-- PZ has no reliable "moveable/world-item removed" event, so we reconcile on a
-- timer over LOADED chunks only. Unloaded chunks are skipped (we can't tell, so
-- we leave them alone - the registry record stays intact for when they reload).

local function reconcile()
    local player = getPlayer()
    if not player then return end
    local cell = getCell()
    if not cell then return end

    -- Pass 1: bunks whose physical bedroll has been picked up -> dismiss their
    -- resident (if any) and drop the bunk.
    local toDrop = {}
    KH.Residents.forEachBunk(player, function(bunkId, bunk)
        local sq = cell:getGridSquare(bunk.x, bunk.y, bunk.z or 0)
        if not sq then return end                      -- chunk not loaded: skip
        if _bedrollObjectOnSquare(sq, bunkId) then return end  -- still there: fine
        toDrop[#toDrop + 1] = bunkId                   -- bedroll gone -> picked up
    end)
    for _, bunkId in ipairs(toDrop) do
        local bunk = KH.Residents.getBunk(player, bunkId)
        if bunk and bunk.residentId then
            local resId = bunk.residentId
            local rec = KH.Residents.get(player, resId)
            if rec and KH.ResidentVisual and KH.ResidentVisual.despawn then
                pcall(function() KH.ResidentVisual.despawn(resId, rec) end)
            end
            KH.Residents.remove(player, resId)
            if KH.DEBUG then print("[KH] ResidentPlacement: bedroll picked up, dismissed " .. tostring(rec and rec.name)) end
        end
        KH.Residents.removeBunk(player, bunkId)
    end

    -- Pass 2: residents whose chunk is loaded but whose body is missing
    -- (e.g. after a reload) -> re-spawn the body from the record.
    KH.Residents.forEach(player, function(resId, rec)
        if not rec.alive then return end
        if not (KH.ResidentVisual and KH.ResidentVisual.spawn) then return end
        if KH.ResidentVisual.hasBody(rec) then return end
        local p = rec.pos
        local sq = p and cell:getGridSquare(p.x, p.y, p.z or 0)
        if not sq then return end                      -- chunk not loaded: skip
        pcall(function() KH.ResidentVisual.spawn(resId, rec) end)
    end)
end

Events.EveryTenMinutes.Add(reconcile)

print("[KH] ResidentPlacement v" .. KH.modules.ResidentPlacement .. " loaded.")
