-- Kierpocalyptic Homestead - Trash pickup
--
-- Right-click context menu adds "Take Trash" on any IsoObject whose sprite
-- name matches trash_<digits>. Walks player adjacent, plays a loot anim,
-- removes the object, gives a randomized vanilla item from the trash loot
-- pool.
--
-- LOOT MAPPING: per-sprite overrides at top of file. Most sprites default to
-- a generic household-trash pool. To pin a specific sprite to a specific item
-- (after looking at it in-game / TileZed), add an entry to LOOT_OVERRIDES.

require "ISUI/ISWorldObjectContextMenu"
require "TimedActions/ISBaseTimedAction"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.TrashPickup = "0.0.6"

-- Match anywhere in the sprite name. Covers both atlases:
--   d_trash_1_*   (decals, scrap-able trash piles, "d_" prefix)
--   trash_01_*    (IsMoveAble FloorRug trash -- tin cans, bottles, etc.)
local TRASH_PATTERN = "trash_%d"
local PICKUP_TICKS  = 60
local DEBUG = true  -- prints seen sprite names on right-click. Turn off when stable.

-- We pull loot from vanilla's ProceduralDistributions tables - the same
-- ones that fill in-world trash containers. This gives 1..N items per
-- pickup using vanilla weights and roll counts, instead of our previous
-- single-item-from-tiny-pool. The default bin is "BinGeneric" (residential
-- household trash). Per-sprite overrides below can specify alternative
-- vanilla bin names for trash sprites that obviously aren't generic
-- (bathroom trash -> "BinBathroom", restaurant -> "BinCrepe", etc.).

local DEFAULT_BIN = "BinGeneric"

-- Per-sprite vanilla-bin overrides. Add entries as you identify sprites.
-- The string must match a key in ProceduralDistributions.list[...].
-- Example:  ["d_trash_01_5"] = "BinBathroom"
local SPRITE_TO_BIN = {
    -- (Empty for now - fill in after identifying sprites in-game)
}

-- Roll-count multiplier. Vanilla bin "rolls" is usually 4; we keep that
-- but you can dial pickup yield up/down here without touching vanilla.
local ROLL_MULTIPLIER = 1.0

-- Probability that a single roll yields nothing. Vanilla containers always
-- attempt a pick per roll; we leave a "empty roll" chance so picking up
-- trash isn't always a win.
local EMPTY_ROLL_CHANCE = 0.20  -- 20%

local function getSpriteName(obj)
    if not obj or not obj.getSprite then return nil end
    local sprite = obj:getSprite()
    if not sprite or not sprite.getName then return nil end
    return sprite:getName()
end

local function isTrashObject(obj)
    local name = getSpriteName(obj)
    if not name then return false end
    return string.find(string.lower(name), TRASH_PATTERN) ~= nil
end

-- Vanilla bin items array is a flat {type1, weight1, type2, weight2, ...}.
-- Returns a randomly-picked item type string, or nil.
local function pickFromVanillaBin(binName)
    if not (ProceduralDistributions and ProceduralDistributions.list) then return nil end
    local dist = ProceduralDistributions.list[binName]
    if not dist or not dist.items then return nil end
    local items = dist.items
    -- items is flat: idx 1 = type, idx 2 = weight, idx 3 = type, idx 4 = weight...
    local total = 0
    for i = 2, #items, 2 do
        local w = tonumber(items[i]) or 0
        total = total + w
    end
    if total <= 0 then return nil end
    local roll = ZombRand(math.floor(total * 1000)) / 1000  -- support fractional weights
    local cum = 0
    for i = 2, #items, 2 do
        cum = cum + (tonumber(items[i]) or 0)
        if roll < cum then
            local typeName = items[i - 1]
            -- Vanilla uses module-less names like "Newspaper"; we need "Base.Newspaper"
            -- AddItem accepts both forms in B42 but prefer fully-qualified.
            if typeName and not typeName:find("%.") then
                return "Base." .. typeName
            end
            return typeName
        end
    end
    return nil
end

-- Pick a list of item ids for one trash-pickup action, mimicking vanilla
-- container fill: roll the bin's `rolls` count plus one junk roll.
local function lootForSprite(spriteName)
    local binName = SPRITE_TO_BIN[spriteName or ""] or DEFAULT_BIN
    local results = {}
    if not (ProceduralDistributions and ProceduralDistributions.list) then return results end
    local dist = ProceduralDistributions.list[binName]
    if not dist then return results end

    local rolls = math.max(1, math.floor((dist.rolls or 1) * ROLL_MULTIPLIER))
    for r = 1, rolls do
        if ZombRand(100) >= (EMPTY_ROLL_CHANCE * 100) then
            local id = pickFromVanillaBin(binName)
            if id then table.insert(results, id) end
        end
    end

    -- Junk table: one extra roll if present
    if dist.junk and dist.junk.items then
        local junk = dist.junk
        local jitems = junk.items
        local jtotal = 0
        for i = 2, #jitems, 2 do jtotal = jtotal + (tonumber(jitems[i]) or 0) end
        if jtotal > 0 then
            local roll = ZombRand(math.floor(jtotal * 1000)) / 1000
            local cum = 0
            for i = 2, #jitems, 2 do
                cum = cum + (tonumber(jitems[i]) or 0)
                if roll < cum then
                    local t = jitems[i - 1]
                    if t and not t:find("%.") then t = "Base." .. t end
                    if t then table.insert(results, t) end
                    break
                end
            end
        end
    end

    return results
end

local KH_TakeTrashAction = ISBaseTimedAction:derive("KH_TakeTrashAction")

function KH_TakeTrashAction:isValid()
    if not self.trashObj then return false end
    if not self.trashObj.getSquare or not self.trashObj:getSquare() then return false end
    return true
end

function KH_TakeTrashAction:update()
    if self.trashObj and self.trashObj.getSquare and self.trashObj:getSquare() then
        local sq = self.trashObj:getSquare()
        self.character:faceLocation(sq:getX(), sq:getY())
    end
end

function KH_TakeTrashAction:start()
    if self.setActionAnim then self:setActionAnim("Loot") end
end

function KH_TakeTrashAction:perform()
    local obj = self.trashObj
    local spriteName = getSpriteName(obj)
    if obj then
        local sq = obj.getSquare and obj:getSquare()
        -- Try every removal path available. trash_01_* sprites are
        -- IsMoveAble FloorRug objects which don't always honor
        -- RemoveTileObject; the cell-level removeFromSquare is what
        -- actually clears them.
        if sq and sq.RemoveTileObject then pcall(function() sq:RemoveTileObject(obj) end) end
        if sq and sq.transmitRemoveItemFromSquare then pcall(function() sq:transmitRemoveItemFromSquare(obj) end) end
        if obj.removeFromSquare then pcall(function() obj:removeFromSquare() end) end
        if obj.removeFromWorld  then pcall(function() obj:removeFromWorld()  end) end
    end
    -- Pull a list of items from the vanilla bin distribution. Empty list
    -- means "this pile yielded nothing" - leaves the player without a
    -- guaranteed-win every time they pick up trash.
    local lootIds = lootForSprite(spriteName or "") or {}
    if self.character and self.character:getInventory() then
        for _, id in ipairs(lootIds) do
            -- Defensive: AddItem can return nil if the type isn't loaded;
            -- pcall so a single bad id doesn't blow up the whole pickup.
            pcall(function() self.character:getInventory():AddItem(id) end)
        end
    end
    -- BWO earn integration: BWO's "where can I earn?" NPCs explicitly tell the
    -- player "pick up trash and they'll pay you." That mechanism only fires
    -- when the engine recognizes the foraging action - manual trash pickup
    -- via KH_TrashPickup bypasses it. So we wire the earn-on-pickup here for
    -- Park Ranger specifically (matching BWO's per-profession earning that
    -- only pays out for ranger-class welfare work).
    if _G.BWOPlayer and _G.BWOPlayer.Earn and self.character then
        local prof
        pcall(function()
            local desc = self.character:getDescriptor()
            if desc then
                local p = desc:getCharacterProfession()
                if p then prof = p:getName() end
            end
        end)
        if prof and tostring(prof):lower() == "parkranger" then
            -- $5 per pickup. Smaller than the $25 forage payout because trash
            -- is faster and more abundant - balanced for a slow drip rather
            -- than the foraging windfall.
            pcall(function() BWOPlayer.Earn(self.character, 5) end)
        end
    end
    ISBaseTimedAction.perform(self)
end

function KH_TakeTrashAction:new(character, trashObj)
    local o = ISBaseTimedAction.new(self, character)
    o.trashObj   = trashObj
    o.maxTime    = PICKUP_TICKS
    o.stopOnWalk = true
    o.stopOnRun  = true
    return o
end

local function onTakeTrashClicked(worldobjects, playerArg, trashObj)
    local character
    if type(playerArg) == "number" then character = getSpecificPlayer(playerArg)
    elseif playerArg and playerArg.getInventory then character = playerArg
    else character = getPlayer() end
    if not character or not trashObj then return end
    local sq = trashObj.getSquare and trashObj:getSquare()
    if not sq then return end
    if luautils and luautils.walkAdj then
        if not luautils.walkAdj(character, sq, true) then return end
    end
    ISTimedActionQueue.add(KH_TakeTrashAction:new(character, trashObj))
end

local function onFillContextMenu(playerArg, context, worldobjects, test)
    if test then return end
    if not worldobjects then return end
    local _kh_before = (context and context.options and #context.options) or 0
    if DEBUG then
        local names = {}
        for _, obj in ipairs(worldobjects) do
            local n = getSpriteName(obj)
            if n then table.insert(names, n) end
        end
        if #names > 0 then
            print("[KH][trash-debug] right-click saw sprites: " .. table.concat(names, ", "))
        end
    end
    local seen = {}
    for _, obj in ipairs(worldobjects) do
        if obj and isTrashObject(obj) and not seen[obj] then
            seen[obj] = true
            local label = getText("ContextMenu_KH_TakeTrash") or "Take Trash"
            KH.UI.markOption(context:addOption(label, worldobjects, onTakeTrashClicked, playerArg, obj))
        end
    end
    local _kh_after = (context and context.options and #context.options) or 0
    if KH and KH.UI and KH.UI.moveLastAddedToTop then
        KH.UI.moveLastAddedToTop(context, _kh_after - _kh_before)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)
