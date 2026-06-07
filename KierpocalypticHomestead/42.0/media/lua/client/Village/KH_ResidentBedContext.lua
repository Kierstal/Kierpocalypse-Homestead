-- Kierpocalyptic Homestead - Resident Bed Context Menus v0.0.1
--
-- Hooks OnFillWorldObjectContextMenu to add:
--
--   On vanilla beds and placed sleeping bags:
--     "Designate as Resident Bed"   (when not yet designated)
--     "Remove Resident Designation" (when designated)
--     "Place Resident Here"         (when designated + no resident placed yet)
--     "Remove Resident"             (when a mannequin is placed)
--     "Turn On Resident Features (Test)"  / "Turn Off..." (test mode toggle)
--
--   On any container object:
--     "Designate as Resident Pantry"   (when not yet designated)
--     "Remove Pantry Designation"      (when designated)
--
-- Mannequins are placed using vanilla ISMoveableSpriteProps:placeMoveable.
-- Female: Base.Mov_MannequinFemale / sprite location_shop_mall_01_66
-- Male:   Base.Mov_MannequinMale   / sprite location_shop_mall_01_69
--
-- After placement we tag the world object's modData with KH_ResidentUUID
-- so undesignation can find and remove it.

require "Moveables/ISMoveableSpriteProps"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ResidentBedContext = "0.0.1"

local _getPlayer = getPlayer  -- capture global before local shadows it

local MANNEQUIN_SPRITE_F = "location_shop_mall_01_66"
local MANNEQUIN_SPRITE_M = "location_shop_mall_01_69"
local MANNEQUIN_ITEM_F   = "Base.Mov_MannequinFemale"
local MANNEQUIN_ITEM_M   = "Base.Mov_MannequinMale"

-- ---- bed/sleeping-bag detection ----

-- Returns true if the world object is a vanilla bed (has BedType sprite property).
local function isVanillaBed(obj)
    if not obj then return false end
    local result = false
    pcall(function()
        local sp = obj:getSprite()
        if not sp then return end
        local props = sp:getProperties()
        if props and props:has("BedType") then result = true end
    end)
    return result
end

-- Returns true if the world object is a placed sleeping bag (IsoMoveable whose
-- sprite name starts with "SleepingBag_" or contains the word in the name).
local function isPlacedSleepingBag(obj)
    if not obj then return false end
    local result = false
    pcall(function()
        if not instanceof(obj, "IsoMoveable") then return end
        local sp = obj:getSprite()
        if not sp then return end
        local name = sp:getName() or ""
        -- Placed sleeping bags: sprite names like "furniture_bedding_01_N" when
        -- placed from Mov_SleepingBag_*. The item name is the reliable anchor.
        -- Check the item attached to the object.
        local item = obj:getItem()
        if item then
            local full = item:getFullType() or ""
            if string.find(string.lower(full), "sleepingbag", 1, true) then
                result = true
                return
            end
        end
        -- Fallback: sprite name heuristic.
        if string.find(string.lower(name), "sleepingbag", 1, true) then
            result = true
        end
    end)
    return result
end

local function isBedObject(obj)
    return isVanillaBed(obj) or isPlacedSleepingBag(obj)
end

-- ---- mannequin placement ----

-- Find a clear square to place a moveable near the given anchor square.
-- Tries the anchor itself first, then the 8 adjacent tiles (cardinal before diagonal).
-- Restricts to the same building as the anchor. Returns nil if nothing works.
local function findPlacementSquare(character, anchorSq, props, item)
    if not anchorSq then return nil end
    local cell = getCell()
    if not cell then return nil end

    local anchorBid
    pcall(function()
        local b = anchorSq:getBuilding()
        local def = b and b:getDef()
        anchorBid = def and def:getIDString()
    end)

    local candidates = {
        {0, 0},
        {0, -1}, {0, 1}, {-1, 0}, {1, 0},
        {-1, -1}, {1, -1}, {-1, 1}, {1, 1},
    }

    local ax, ay, az = anchorSq:getX(), anchorSq:getY(), anchorSq:getZ()
    for _, off in ipairs(candidates) do
        local sq = cell:getGridSquare(ax + off[1], ay + off[2], az)
        if sq then
            -- Optionally confirm same building when we have an anchor building.
            local sameBld = true
            if anchorBid then
                local bid
                pcall(function()
                    local b = sq:getBuilding()
                    local def = b and b:getDef()
                    bid = def and def:getIDString()
                end)
                sameBld = (bid == anchorBid)
            end

            if sameBld then
                local canPlace = false
                pcall(function() canPlace = props:canPlaceMoveableInternal(character, sq, item) end)
                if canPlace then return sq end
            end
        end
    end
    return nil
end

-- Place a mannequin near the given bed square. Tags it with the resident UUID.
-- Returns the actual placement square on success, nil on failure.
local function placeMannequin(character, bedSq, sex, uuid)
    local spriteName = (sex == "m") and MANNEQUIN_SPRITE_M or MANNEQUIN_SPRITE_F
    local itemType   = (sex == "m") and MANNEQUIN_ITEM_M   or MANNEQUIN_ITEM_F

    local placedSq = nil
    pcall(function()
        local sprite = getSprite(spriteName)
        if not sprite then return end

        local props = ISMoveableSpriteProps.new(sprite)
        if not props then return end

        local item = instanceItem(itemType)
        if not item then return end

        local sq = findPlacementSquare(character, bedSq, props, item)
        if not sq then return end

        props:placeMoveableInternal(sq, item, spriteName)

        -- Tag the newly placed object with our UUID so we can find it for removal.
        local objects = sq:getWorldObjects()
        if objects then
            for i = objects:size(), 1, -1 do
                local o = objects:get(i - 1)
                if o and instanceof(o, "IsoMoveable") then
                    local osp = o:getSprite()
                    if osp and osp:getName() == spriteName then
                        local md = o:getModData()
                        if md and not md.KH_ResidentUUID then
                            md.KH_ResidentUUID = uuid
                            placedSq = sq
                            break
                        end
                    end
                end
            end
        end
    end)
    return placedSq
end

-- ---- context menu callbacks ----

local function getPlayer(playerArg)
    if type(playerArg) == "number" then return getSpecificPlayer(playerArg) end
    if playerArg and playerArg.getInventory then return playerArg end
    return _getPlayer()
end

-- Designate bed
local function onDesignateBed(worldobjects, playerArg, bedObj)
    local p = getPlayer(playerArg)
    if not p then return end
    local uuid = KH.Resident.designate(p, bedObj)
    if uuid and HaloTextHelper and HaloTextHelper.addText then
        pcall(function() HaloTextHelper.addText(p, "Resident bed designated.") end)
    end
end

-- Remove designation
local function onUndesignateBed(worldobjects, playerArg, bedObj)
    local p = getPlayer(playerArg)
    if not p then return end
    if KH.Resident.undesignate(p, bedObj) then
        if HaloTextHelper and HaloTextHelper.addText then
            pcall(function() HaloTextHelper.addText(p, "Resident bed removed.") end)
        end
    end
end

-- Place resident (find a clear adjacent tile near the bed, place mannequin there)
local function doPlaceResident(worldobjects, playerArg, bedObj, sex)
    local p = getPlayer(playerArg)
    if not p then return end
    local entry = KH.Resident.getEntry(p, bedObj)
    if not entry then return end

    local bedSq
    pcall(function() bedSq = bedObj:getSquare() end)
    if not bedSq then return end

    local placedSq = placeMannequin(p, bedSq, sex, entry.uuid)
    if placedSq then
        local resName = nil
        if KH.NameGen and KH.NameGen.random then
            resName = KH.NameGen.random(sex)
        end
        KH.Resident.recordPlacement(p, bedObj, sex, resName, placedSq:getX(), placedSq:getY(), placedSq:getZ())
        if HaloTextHelper and HaloTextHelper.addText then
            local displayName = resName or "Resident"
            pcall(function() HaloTextHelper.addText(p, displayName .. " placed.") end)
        end
    else
        if HaloTextHelper and HaloTextHelper.addText then
            pcall(function() HaloTextHelper.addText(p, "Can't place resident here.") end)
        end
    end
end

local function onPlaceResidentFemale(worldobjects, playerArg, bedObj)
    doPlaceResident(worldobjects, playerArg, bedObj, "f")
end

local function onPlaceResidentMale(worldobjects, playerArg, bedObj)
    doPlaceResident(worldobjects, playerArg, bedObj, "m")
end

-- Remove resident mannequin
local function onRemoveResident(worldobjects, playerArg, bedObj)
    local p = getPlayer(playerArg)
    if not p then return end
    local entry = KH.Resident.getEntry(p, bedObj)
    if not entry then return end
    KH.Resident.removeMannequin(entry)
    if HaloTextHelper and HaloTextHelper.addText then
        pcall(function() HaloTextHelper.addText(p, "Resident removed.") end)
    end
end

-- Test mode toggle
local function onToggleTestMode(worldobjects, playerArg, bedObj, enable)
    local p = getPlayer(playerArg)
    if not p then return end
    KH.Resident.setTestMode(p, bedObj, enable)
    if HaloTextHelper and HaloTextHelper.addText then
        local msg = enable and "Resident features ON (test)." or "Resident features OFF."
        pcall(function() HaloTextHelper.addText(p, msg) end)
    end
end

-- Pantry designation
local function onDesignatePantry(worldobjects, playerArg, containerObj)
    local p = getPlayer(playerArg)
    if not p then return end
    KH.Resident.setPantry(p, containerObj, true)
    if HaloTextHelper and HaloTextHelper.addText then
        pcall(function() HaloTextHelper.addText(p, "Pantry designated.") end)
    end
end

local function onRemovePantry(worldobjects, playerArg, containerObj)
    local p = getPlayer(playerArg)
    if not p then return end
    KH.Resident.setPantry(p, containerObj, false)
    if HaloTextHelper and HaloTextHelper.addText then
        pcall(function() HaloTextHelper.addText(p, "Pantry designation removed.") end)
    end
end

-- Returns true if obj has an accessible container.
local function _objHasContainer(obj)
    if not obj then return false end
    local ok, cont = pcall(function() return obj:getContainer() end)
    return ok and cont ~= nil
end

-- ---- tile-targeted "Place Resident Here" ----

-- Returns the building ID string for the given square, nil if not in a building.
local function _buildingIdOfSq(sq)
    if not sq then return nil end
    local id
    pcall(function()
        local b = sq:getBuilding()
        local def = b and b:getDef()
        id = def and def:getIDString()
    end)
    return id
end

-- Returns a list of { key, entry, label } for designated bed slots in buildingId
-- that have no mannequin placed yet (entry.rx == nil).
local function getUnoccupiedSlotsInBuilding(player, buildingId)
    if not buildingId then return {} end
    local beds = player:getModData()["KH_ResidentBeds"]
    if not beds then return {} end
    local cell = getCell()
    if not cell then return {} end
    local out = {}
    for key, entry in pairs(beds) do
        if entry and entry.uuid and entry.rx == nil then
            local cx, cy, cz = string.match(key, "^(%d+):(%d+):(%d+):")
            cx = tonumber(cx); cy = tonumber(cy); cz = tonumber(cz)
            if cx then
                local sq = cell:getGridSquare(cx, cy, cz or 0)
                local bid = _buildingIdOfSq(sq)
                if bid == buildingId then
                    local num = string.match(entry.uuid, "(%d+)$") or entry.uuid
                    table.insert(out, { key = key, entry = entry, label = "Slot " .. num })
                end
            end
        end
    end
    return out
end

-- Callback: place mannequin for the given bed slot on an explicit target square.
local function onPlaceResidentHere(worldobjects, playerArg, bedKey, targetSq, sex)
    local p = getPlayer(playerArg)
    if not p then return end
    local beds = p:getModData()["KH_ResidentBeds"]
    if not beds or not beds[bedKey] then return end
    local entry = beds[bedKey]

    local spriteName = (sex == "m") and MANNEQUIN_SPRITE_M or MANNEQUIN_SPRITE_F
    local itemType   = (sex == "m") and MANNEQUIN_ITEM_M   or MANNEQUIN_ITEM_F

    local placed = false
    pcall(function()
        local sprite = getSprite(spriteName)
        if not sprite then return end
        local props = ISMoveableSpriteProps.new(sprite)
        if not props then return end
        local item = instanceItem(itemType)
        if not item then return end

        local canPlace = false
        pcall(function() canPlace = props:canPlaceMoveableInternal(p, targetSq, item) end)
        if not canPlace then return end

        props:placeMoveableInternal(targetSq, item, spriteName)

        local objects = targetSq:getWorldObjects()
        if objects then
            for i = objects:size(), 1, -1 do
                local o = objects:get(i - 1)
                if o and instanceof(o, "IsoMoveable") then
                    local osp = o:getSprite()
                    if osp and osp:getName() == spriteName then
                        local md = o:getModData()
                        if md and not md.KH_ResidentUUID then
                            md.KH_ResidentUUID = entry.uuid
                            placed = true
                            break
                        end
                    end
                end
            end
        end
    end)

    if placed then
        entry.sex  = sex
        if not entry.name or entry.name == "Resident" then
            if KH.NameGen and KH.NameGen.random then
                entry.name = KH.NameGen.random(sex)
            else
                entry.name = "Resident"
            end
        end
        entry.rx   = targetSq:getX()
        entry.ry   = targetSq:getY()
        entry.rz   = targetSq:getZ()
        if HaloTextHelper and HaloTextHelper.addText then
            pcall(function() HaloTextHelper.addText(p, entry.name .. " placed.") end)
        end
    else
        if HaloTextHelper and HaloTextHelper.addText then
            pcall(function() HaloTextHelper.addText(p, "Tile is blocked - try a clear floor tile.") end)
        end
    end
end

-- ---- main context menu hook ----

local function onFillContext(playerArg, context, worldobjects, test)
    if test then return end
    if not worldobjects then return end

    local p = getPlayer(playerArg)
    if not p then return end

    -- Resident beds can only be designated on Homestead or Safehouse lots.
    local currentKind = KH.Home and KH.Home.currentType and KH.Home.currentType(p)
    local inResidentLot = (currentKind == "homestead" or currentKind == "safehouse")

    local sawBed       = false
    local sawContainer = false

    for _, obj in ipairs(worldobjects) do
        if obj then

            -- ---- BED OPTIONS (Homestead/Safehouse only) ----
            if not sawBed and inResidentLot and isBedObject(obj) then
                sawBed = true
                local designated = KH.Resident.isDesignated(p, obj)
                local entry = designated and KH.Resident.getEntry(p, obj)
                local hasResident = entry and entry.rx ~= nil
                local testOn = entry and entry.testMode == true

                local bedLabel = "Resident Bed"
                if entry and entry.name and entry.name ~= "Resident" then
                    bedLabel = entry.name .. "'s Bed"
                end
                local rootOpt = context:addOption(bedLabel, worldobjects, nil)
                local sub = ISContextMenu:getNew(context)
                context:addSubMenu(rootOpt, sub)

                if not designated then
                    sub:addOption("Designate as Resident Bed", worldobjects,
                        onDesignateBed, playerArg, obj)
                else
                    -- Place / remove resident
                    if not hasResident then
                        local placeOpt = sub:addOption("Place Resident", worldobjects, nil)
                        local placeSub = ISContextMenu:getNew(sub)
                        sub:addSubMenu(placeOpt, placeSub)
                        placeSub:addOption("Female", worldobjects, onPlaceResidentFemale, playerArg, obj)
                        placeSub:addOption("Male",   worldobjects, onPlaceResidentMale,   playerArg, obj)
                    else
                        sub:addOption("Remove Resident", worldobjects, onRemoveResident, playerArg, obj)
                    end

                    -- Test mode toggle
                    if not hasResident then
                        if testOn then
                            sub:addOption("Turn Off Resident Features (Test)", worldobjects,
                                onToggleTestMode, playerArg, obj, false)
                        else
                            sub:addOption("Turn On Resident Features (Test)", worldobjects,
                                onToggleTestMode, playerArg, obj, true)
                        end
                    end

                    -- Remove designation
                    sub:addOption("Remove Resident Designation", worldobjects,
                        onUndesignateBed, playerArg, obj)
                end
            end

            -- ---- PANTRY OPTIONS (Homestead/Safehouse only) ----
            if not sawContainer and inResidentLot and _objHasContainer(obj) then
                sawContainer = true
                local isPantry = KH.Resident.isPantry(p, obj)
                if isPantry then
                    context:addOption("Remove Pantry Designation", worldobjects,
                        onRemovePantry, playerArg, obj)
                else
                    context:addOption("Designate as Resident Pantry", worldobjects,
                        onDesignatePantry, playerArg, obj)
                end
            end

            if sawBed and sawContainer then break end
        end
    end

    -- ---- PLACE RESIDENT HERE (any tile in homestead/safehouse) ----
    -- Shows when there are unoccupied designated bed slots in this building,
    -- letting the player choose exactly where to stand the mannequin.
    if inResidentLot then
        local targetSq = nil
        for _, obj in ipairs(worldobjects) do
            if obj then
                pcall(function() targetSq = obj:getSquare() end)
                if targetSq then break end
            end
        end
        if not targetSq then
            pcall(function() targetSq = p:getCurrentSquare() end)
        end

        if targetSq then
            local targetBid = _buildingIdOfSq(targetSq)
            if targetBid then
                local slots = getUnoccupiedSlotsInBuilding(p, targetBid)
                if #slots > 0 then
                    local rootOpt = context:addOption("Place Resident Here", worldobjects, nil)
                    local rootSub = ISContextMenu:getNew(context)
                    context:addSubMenu(rootOpt, rootSub)

                    if #slots == 1 then
                        -- Only one unoccupied slot: go straight to sex selection.
                        rootSub:addOption("Female", worldobjects,
                            onPlaceResidentHere, playerArg, slots[1].key, targetSq, "f")
                        rootSub:addOption("Male", worldobjects,
                            onPlaceResidentHere, playerArg, slots[1].key, targetSq, "m")
                    else
                        -- Multiple slots: one sub-menu per slot.
                        for _, slot in ipairs(slots) do
                            local slotOpt = rootSub:addOption(slot.label, worldobjects, nil)
                            local slotSub = ISContextMenu:getNew(rootSub)
                            rootSub:addSubMenu(slotOpt, slotSub)
                            slotSub:addOption("Female", worldobjects,
                                onPlaceResidentHere, playerArg, slot.key, targetSq, "f")
                            slotSub:addOption("Male", worldobjects,
                                onPlaceResidentHere, playerArg, slot.key, targetSq, "m")
                        end
                    end
                end
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContext)

print("[KH] ResidentBedContext v0.0.1 registered.")
