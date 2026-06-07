-- Kierpocalyptic Homestead - Resident Registry v0.0.1
--
-- Data layer for the resident bed system. Tracks:
--   * Designated beds    - vanilla beds or placed sleeping bags that house one resident
--   * Placed residents   - mannequin world objects coupled to a designated bed
--   * Pantry containers  - containers the food pass is allowed to pull from
--
-- All data lives on player modData so it persists with the save.
--
-- modData layout:
--   KH_ResidentBeds = {
--     [bedKey] = {
--       uuid     = "kh_res_<n>",    -- stable ID coupling bed to mannequin
--       testMode = false,            -- skip mannequin req; count for food pass anyway
--       sex      = "f" | "m" | nil, -- nil = no resident placed yet
--       name     = string | nil,
--       rx, ry, rz = number | nil,  -- mannequin world tile coords
--     }
--   }
--   KH_ResidentPantries = {
--     [containerKey] = true          -- set of designated pantry containers
--   }
--   KH_ResidentUIDCounter = number   -- monotonic counter for UUID generation
--
-- bedKey / containerKey = "x:y:z:spriteName"
-- For multi-tile beds, the anchor tile is used (first tile of sprite grid).

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ResidentRegistry = "0.0.1"
KH.Resident = KH.Resident or {}

local BED_KEY      = "KH_ResidentBeds"
local PANTRY_KEY   = "KH_ResidentPantries"
local UID_KEY      = "KH_ResidentUIDCounter"

-- ---- internal helpers ----

local function makeUUID(player)
    local md = player:getModData()
    local n = (md[UID_KEY] or 0) + 1
    md[UID_KEY] = n
    return "kh_res_" .. tostring(n)
end

local function bedsOf(player)
    if not player or not player.getModData then return nil end
    local md = player:getModData()
    if not md[BED_KEY] then md[BED_KEY] = {} end
    return md[BED_KEY]
end

local function pantriesOf(player)
    if not player or not player.getModData then return nil end
    local md = player:getModData()
    if not md[PANTRY_KEY] then md[PANTRY_KEY] = {} end
    return md[PANTRY_KEY]
end

-- Build a stable string key for a world object from its tile position + sprite.
-- For multi-tile beds, tries to use the anchor sprite's tile so the key is
-- consistent regardless of which tile the player right-clicked.
local function keyOf(obj)
    if not obj then return nil end
    local sq
    pcall(function() sq = obj:getSquare() end)
    if not sq then return nil end

    -- For objects with a sprite grid, walk to the anchor tile.
    pcall(function()
        local sp = obj:getSprite()
        if sp and sp.getSpriteGrid then
            local grid = sp:getSpriteGrid()
            if grid then
                local anchor = grid:getAnchorSprite()
                -- getSpriteGridMemberOffset gives (dx, dy) of THIS sprite rel. to anchor.
                -- We want the square that contains the anchor.
                local objects = sq:getObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local o = objects:get(i)
                        if o and o ~= obj then
                            local osp = o:getSprite()
                            if osp and osp == anchor then
                                local osq = o:getSquare()
                                if osq then sq = osq end
                                break
                            end
                        end
                    end
                end
            end
        end
    end)

    local spriteName = ""
    pcall(function()
        local sp = obj:getSprite()
        if sp and sp.getName then spriteName = sp:getName() or "" end
    end)
    return string.format("%d:%d:%d:%s", sq:getX(), sq:getY(), sq:getZ(), spriteName)
end

-- Same but takes explicit x,y,z,spriteName for container objects.
local function containerKey(obj)
    if not obj then return nil end
    -- IsoObject path
    local sq
    pcall(function() sq = obj:getSquare() end)
    if not sq then return nil end
    local spriteName = ""
    pcall(function()
        local sp = obj:getSprite()
        if sp and sp.getName then spriteName = sp:getName() or "" end
    end)
    return string.format("%d:%d:%d:%s", sq:getX(), sq:getY(), sq:getZ(), spriteName)
end

-- Parse x,y,z out of a key string.
local function parseCoordsFromKey(key)
    local x, y, z = string.match(key, "^(%d+):(%d+):(%d+):")
    if x then return tonumber(x), tonumber(y), tonumber(z) end
    return nil, nil, nil
end

-- Get the building ID string for a given IsoGridSquare. Returns nil if not in a building.
local function buildingIdOfSquare(sq)
    if not sq then return nil end
    local b, def, id
    pcall(function() b = sq:getBuilding() end)
    pcall(function() def = b and b:getDef() end)
    pcall(function() id = def and def:getIDString() end)
    return id
end

-- ---- Bed designation API ----

-- Returns true if the world object is a designated resident bed.
function KH.Resident.isDesignated(player, obj)
    local key = keyOf(obj)
    if not key then return false end
    local beds = bedsOf(player)
    return beds ~= nil and beds[key] ~= nil
end

-- Designate a bed/sleeping bag as a resident bed slot. Returns the new UUID on
-- success, false if the object cannot be keyed or is already designated.
function KH.Resident.designate(player, obj)
    local key = keyOf(obj)
    if not key then return false end
    local beds = bedsOf(player)
    if not beds then return false end
    if beds[key] then return beds[key].uuid end  -- already designated
    local uuid = makeUUID(player)
    beds[key] = { uuid = uuid, testMode = false }
    return uuid
end

-- Remove a bed designation. Also removes the coupled mannequin from the world.
-- Returns true on success.
function KH.Resident.undesignate(player, obj)
    local key = keyOf(obj)
    if not key then return false end
    local beds = bedsOf(player)
    if not beds or not beds[key] then return false end
    local entry = beds[key]
    if entry.rx then
        KH.Resident.removeMannequin(entry)
    end
    beds[key] = nil
    return true
end

-- Return the entry table for a designated bed, or nil.
function KH.Resident.getEntry(player, obj)
    local key = keyOf(obj)
    if not key then return nil end
    local beds = bedsOf(player)
    return beds and beds[key]
end

-- ---- Test-mode toggle ----

function KH.Resident.setTestMode(player, obj, enabled)
    local entry = KH.Resident.getEntry(player, obj)
    if not entry then return false end
    entry.testMode = enabled == true
    return true
end

function KH.Resident.getTestMode(player, obj)
    local entry = KH.Resident.getEntry(player, obj)
    return entry ~= nil and entry.testMode == true
end

-- ---- Resident (mannequin) placement API ----

-- Record mannequin placement data on the bed entry.
-- Called after ISMoveableSpriteProps places the object.
function KH.Resident.recordPlacement(player, obj, sex, name, rx, ry, rz)
    local entry = KH.Resident.getEntry(player, obj)
    if not entry then return false end
    entry.sex  = sex
    entry.name = name or "Resident"
    entry.rx, entry.ry, entry.rz = rx, ry, rz
    return true
end

-- Remove the mannequin world object for a given entry. Clears placement fields.
function KH.Resident.removeMannequin(entry)
    if not entry or not entry.rx then return end
    local cell = getCell()
    if not cell then return end
    local sq = cell:getGridSquare(entry.rx, entry.ry, entry.rz or 0)
    if not sq then
        -- Square not loaded; just clear the data.
        entry.rx, entry.ry, entry.rz, entry.sex, entry.name = nil, nil, nil, nil, nil
        return
    end
    local objects = sq:getWorldObjects()
    if objects then
        for i = objects:size(), 1, -1 do
            local o = objects:get(i - 1)
            if o then
                local md
                pcall(function() md = o:getModData() end)
                if md and md.KH_ResidentUUID == entry.uuid then
                    pcall(function() sq:transmitRemoveItemFromSquare(o) end)
                    pcall(function() sq:removeFromSquare(o) end)
                    break
                end
            end
        end
    end
    entry.rx, entry.ry, entry.rz, entry.sex, entry.name = nil, nil, nil, nil, nil
end

-- ---- Active resident counting ----

-- A resident slot is "active" (counts for food) when:
--   * testMode is ON, OR
--   * a mannequin has been placed (entry.rx is non-nil)
function KH.Resident.isActive(entry)
    if not entry then return false end
    return entry.testMode == true or entry.rx ~= nil
end

-- Count active residents whose bed (or mannequin) is inside the given building ID.
-- Checks bed tile coords for testMode entries, mannequin coords for placed ones.
function KH.Resident.countActiveInBuildingId(player, buildingId)
    if not buildingId then return 0 end
    local beds = bedsOf(player)
    if not beds then return 0 end
    local cell = getCell()
    local count = 0

    for key, entry in pairs(beds) do
        if entry and entry.uuid and KH.Resident.isActive(entry) then
            -- For placed mannequins, check mannequin tile.
            -- For testMode, check bed tile (parsed from key).
            local cx, cy, cz
            if entry.rx then
                cx, cy, cz = entry.rx, entry.ry, entry.rz
            else
                cx, cy, cz = parseCoordsFromKey(key)
            end
            if cx and cell then
                local sq = cell:getGridSquare(cx, cy, cz or 0)
                local bid = buildingIdOfSquare(sq)
                if bid == buildingId then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- ---- Pantry container API ----

-- Designate or un-designate a container world object as a resident pantry.
function KH.Resident.setPantry(player, containerObj, isDesignated)
    local key = containerKey(containerObj)
    if not key then return false end
    local pantries = pantriesOf(player)
    if not pantries then return false end
    if isDesignated then
        pantries[key] = true
    else
        pantries[key] = nil
    end
    return true
end

function KH.Resident.isPantry(player, containerObj)
    local key = containerKey(containerObj)
    if not key then return false end
    local pantries = pantriesOf(player)
    return pantries ~= nil and pantries[key] == true
end

-- Return list of live IsoObjects that are designated pantries in a given building.
-- Skips entries whose chunk isn't loaded (returns nil sq gracefully).
function KH.Resident.getPantriesInBuildingId(player, buildingId)
    local pantries = pantriesOf(player)
    if not pantries then return {} end
    local cell = getCell()
    local out = {}
    for key, _ in pairs(pantries) do
        local px, py, pz = parseCoordsFromKey(key)
        if px and cell then
            local sq = cell:getGridSquare(px, py, pz or 0)
            if sq then
                local bid = buildingIdOfSquare(sq)
                if bid == buildingId then
                    -- Find the container object on this square whose key matches.
                    local objects = sq:getObjects()
                    if objects then
                        for i = 0, objects:size() - 1 do
                            local o = objects:get(i)
                            if o then
                                local k = containerKey(o)
                                if k == key then
                                    local cont
                                    pcall(function() cont = o:getContainer() end)
                                    if cont then
                                        table.insert(out, { obj = o, container = cont })
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return out
end

print("[KH] ResidentRegistry v0.0.1 loaded.")
