-- Kierpocalyptic Homestead - territory system (Homesteads + Waystations + Safehouses)
--
-- Singleplayer analog to claim. Three territory types:
--   * Homestead   - primary residence. Pets can live here. Negative-need
--                   dampening at 0.6, pet happiness bonus, therapy +50%.
--   * Waystation  - loot store / profession workshop. Smaller dampening
--                   at 0.8, +20% craft XP via bonusFor("craft_xp").
--   * Safehouse   - delivery client. NPCs live here, Wilda visits to bring
--                   supplies. Full access (BWOPayScope + BWOIntrusionScope
--                   carve-outs key off this status). No bonus stats - the
--                   gameplay value is permission, not benefit.
--
-- Multiple of each allowed. Right-click anywhere while standing in a
-- building to add/remove the current building. One building can be one
-- type at a time.
--
-- Pet integration: pet can be "sent home" to any homestead via context
-- menu. Implementation is teleport-based because real long-distance
-- pathing on IsoAnimal across loaded/unloaded chunks is unreliable.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.HomeTerritory = "0.3.0"
KH.Home = KH.Home or {}

local TERRITORIES_KEY = "KH_Territories"     -- md.KH_Territories[buildingId] = "homestead" | "waystation"
local LEGACY_HOME_KEY = "KH_HomeBuildingId"  -- v0.1.0 singleton field, migrated

-- ---------- helpers ----------

local function buildingIdOfSquare(sq)
    if not sq then return nil end
    local building; pcall(function() building = sq:getBuilding() end)
    if not building then return nil end
    local def; pcall(function() def = building:getDef() end)
    if not def or not def.getIDString then return nil end
    local id; pcall(function() id = def:getIDString() end)
    return id
end

local function buildingIdOfPlayer(player)
    if not player then return nil end
    local b; pcall(function() b = player:getBuilding() end)
    if not b then return nil end
    local def; pcall(function() def = b:getDef() end)
    if not def or not def.getIDString then return nil end
    local id; pcall(function() id = def:getIDString() end)
    return id
end

local function territoriesOf(player)
    if not player or not player.getModData then return nil end
    local md = player:getModData()
    if not md[TERRITORIES_KEY] then
        md[TERRITORIES_KEY] = {}
        -- Migrate the v0.1.0 singleton home into the new map as a homestead
        if md[LEGACY_HOME_KEY] then
            md[TERRITORIES_KEY][md[LEGACY_HOME_KEY]] = "homestead"
        end
    end
    return md[TERRITORIES_KEY]
end

-- ---------- public API ----------

-- Mark the building containing sq as the given type. Type must be
-- "homestead" or "waystation". Pass type=nil to remove.
-- Stores the player's current square coords with the entry so teleporting
-- the pet home later doesn't depend on a vanilla-API-that-doesnt-exist to
-- find a square inside the building.
function KH.Home.markBuilding(player, sq, kind)
    local id = buildingIdOfSquare(sq)
    if not id then return false end
    local t = territoriesOf(player)
    if not t then return false end
    if kind == nil then
        t[id] = nil
    else
        -- Save player current square as the teleport anchor for this territory
        local pSq = player:getCurrentSquare()
        local x, y, z = nil, nil, nil
        if pSq then x, y, z = pSq:getX(), pSq:getY(), pSq:getZ() end
        t[id] = { kind = kind, x = x, y = y, z = z }
    end
    return true
end

-- Resolve an entry to just its kind, accepting either old-shape (string)
-- or new-shape (table) values for backward compat.
local function entryKind(entry)
    if type(entry) == "string" then return entry end
    if type(entry) == "table" then return entry.kind end
    return nil
end

function KH.Home.typeAt(player, sq)
    local id = buildingIdOfSquare(sq)
    if not id then return nil end
    local t = territoriesOf(player)
    return t and entryKind(t[id])
end

function KH.Home.currentType(player)
    local id = buildingIdOfPlayer(player)
    if not id then return nil end
    local t = territoriesOf(player)
    return t and entryKind(t[id])
end

function KH.Home.isAtHome(player)
    -- True if standing in ANY homestead or waystation.
    local kind = KH.Home.currentType(player)
    return kind ~= nil
end

function KH.Home.isAtHomestead(player)
    return KH.Home.currentType(player) == "homestead"
end

function KH.Home.isAtWaystation(player)
    return KH.Home.currentType(player) == "waystation"
end

function KH.Home.isAtSafehouse(player)
    return KH.Home.currentType(player) == "safehouse"
end

-- Building-centric checks. Used by BWO compat patches (BWOPayScope,
-- BWOIntrusionScope) which need to query a building's status without a
-- specific square. Returns true if the building has ANY player's territory
-- record of the given kind. In SP that's just the one player.
local function _buildingIsKind(building, kind)
    if not building then return false end
    local def; pcall(function() def = building:getDef() end)
    if not def or not def.getIDString then return false end
    local id; pcall(function() id = def:getIDString() end)
    if not id then return false end
    local p = getPlayer(); if not p then return false end
    local t = territoriesOf(p); if not t then return false end
    return entryKind(t[id]) == kind
end

function KH.Home.isHomestead(building) return _buildingIsKind(building, "homestead") end
function KH.Home.isWaystation(building) return _buildingIsKind(building, "waystation") end
function KH.Home.isSafehouse(building)  return _buildingIsKind(building, "safehouse")  end

-- Alias namespace so external compat patches can reference KH.HomeTerritory.*
-- This is what KH_BWOPayScope and KH_BWOIntrusionScope reference.
KH.HomeTerritory = KH.Home

-- For pets: at-home only counts homesteads (pets don't live at waystations)
function KH.Home.isPetAtHomestead(player, animal)
    if not animal then return false end
    local sq; pcall(function() sq = animal.getSquare and animal:getSquare() end)
    local id = buildingIdOfSquare(sq)
    if not id then return false end
    local t = territoriesOf(player)
    return entryKind(t and t[id]) == "homestead"
end

-- Returns list of {id=, kind=, x=, y=, z=} entries
function KH.Home.listAll(player)
    local out = {}
    local t = territoriesOf(player)
    if not t then return out end
    for id, entry in pairs(t) do
        if type(entry) == "table" then
            table.insert(out, { id = id, kind = entry.kind, x = entry.x, y = entry.y, z = entry.z })
        else
            table.insert(out, { id = id, kind = entry })  -- old-shape backward compat
        end
    end
    return out
end

-- Find a square inside a claimed territory by looking up the saved coords.
-- Coords were captured at claim time (player's current square). If the chunk
-- isn't loaded right now, getGridSquare returns nil and we report no anchor.
-- Takes the PLAYER so we can read their modData; targetId is the building id.
function KH.Home.findSquareForBuildingId(player, targetId)
    if not player or not targetId then return nil end
    local t = territoriesOf(player)
    if not t then return nil end
    local entry = t[targetId]
    if type(entry) ~= "table" or not entry.x then return nil end
    local cell = getCell()
    if not cell then return nil end
    local sq = cell:getGridSquare(entry.x, entry.y, entry.z or 0)
    return sq  -- nil if chunk not loaded
end

-- ---------- bonus multipliers ----------
--   "negative_need"  -> dampener for stress/boredom/unhappy rises
--   "pet_happiness"  -> small pet happy boost (homestead only)
--   "therapy_animal" -> TherapyAnimals stat reduction multiplier
--   "pluvio"         -> Pluviophile/phobe rain stress multiplier
--   "comic_read"     -> ComicNerd reading multiplier
--   "craft_xp"       -> crafting XP multiplier (waystation specialty)
local HOMESTEAD = {
    negative_need = 0.6, pet_happiness = 1.0,
    therapy_animal = 1.5, pluvio = 0.7, comic_read = 1.3, craft_xp = 1.0,
}
local WAYSTATION = {
    negative_need = 0.8, pet_happiness = 1.0,
    therapy_animal = 1.0, pluvio = 1.0, comic_read = 1.0, craft_xp = 1.2,
}
-- Safehouses are someone ELSE's home (NPC residents). Wilda doesn't get
-- comfort bonuses there - the value of registering one is permission
-- (BWOPayScope + BWOIntrusionScope carve-outs) and the daily food check
-- targeting the building, not stats for her.
local SAFEHOUSE = {
    negative_need = 1.0, pet_happiness = 1.0,
    therapy_animal = 1.0, pluvio = 1.0, comic_read = 1.0, craft_xp = 1.0,
}
function KH.Home.bonusFor(player, category)
    local kind = KH.Home.currentType(player)
    if kind == "homestead" then return HOMESTEAD[category] or 1.0 end
    if kind == "waystation" then return WAYSTATION[category] or 1.0 end
    if kind == "safehouse" then return SAFEHOUSE[category] or 1.0 end
    return 1.0
end

-- ---------- Context menu ----------

local function onMark(worldobjects, playerArg, kind)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    if not p then return end
    local sq = p:getCurrentSquare(); if not sq then return end
    if KH.Home.markBuilding(p, sq, kind) and HaloTextHelper and HaloTextHelper.addText then
        local label
        if     kind == "homestead"  then label = "Marked as Homestead"
        elseif kind == "waystation" then label = "Marked as Waystation"
        elseif kind == "safehouse"  then label = "Marked as Safehouse"
        else                              label = "Territory cleared"
        end
        pcall(function() HaloTextHelper.addText(p, label) end)
    end
end

-- Right-click while standing in a building -> a "Homestead Territory" submenu
-- to mark the current building as homestead / waystation / safehouse, or clear
-- it. One type per building; the current type is omitted from the menu.
-- (Reconstructed 2026-06-06: the shipped file was truncated mid-string here.)
local function onFillContext(playerNum, context, worldobjects, test)
    if test then return end
    local p = getSpecificPlayer(playerNum)
    if not p then return end
    local sq = p:getCurrentSquare()
    if not sq then return end
    local bld
    pcall(function() bld = sq:getBuilding() end)
    if not bld then return end  -- only meaningful inside a building

    local current = KH.Home.currentType(p)

    local before = (context.options and #context.options) or 0
    local root = context:addOption("Homestead Territory", worldobjects, nil)
    if KH.UI and KH.UI.markOption then KH.UI.markOption(root) end
    local sub = context:getNew(context)
    context:addSubMenu(root, sub)

    if current ~= "homestead" then
        sub:addOption("Mark as Homestead",  worldobjects, onMark, playerNum, "homestead")
    end
    if current ~= "waystation" then
        sub:addOption("Mark as Waystation", worldobjects, onMark, playerNum, "waystation")
    end
    if current ~= "safehouse" then
        sub:addOption("Mark as Safehouse",  worldobjects, onMark, playerNum, "safehouse")
    end
    if current ~= nil then
        sub:addOption("Clear Territory",    worldobjects, onMark, playerNum, nil)
    end

    local after = (context.options and #context.options) or 0
    if KH.UI and KH.UI.moveLastAddedToTop then
        KH.UI.moveLastAddedToTop(context, after - before)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContext)

print("[KH] Home territory system loaded (v" .. KH.modules.HomeTerritory .. ")")