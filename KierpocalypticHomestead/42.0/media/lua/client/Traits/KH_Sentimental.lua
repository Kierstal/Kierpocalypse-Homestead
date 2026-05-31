-- Kierpocalyptic Homestead - Sentimental
--
-- Design:
--  - The FIRST Photo and the FIRST BusinessCard the player picks up become
--    "mementos" (one of each). Subsequent photos/cards are just regular
--    items.
--  - When a memento is tagged, fire a halo line to make the moment feel
--    intentional ("I want to keep this").
--  - If a mementoed item leaves the player's inventory in a way other than
--    "transferred into a container they own", apply stress + unhappiness
--    for several in-game hours.
--
-- We tag mementos two ways:
--  1) Item modData: amd.KH_Memento = true  (stays on the item across saves)
--  2) Player modData: md.KH_PhotoMemento = onlineID / md.KH_CardMemento = onlineID
--     (so we can detect "the memento item left my inventory")
--
-- Loss detection: every minute, if a tagged ID is no longer in the player's
-- inventory recursively, set a "missing since" timestamp on player modData.
-- While missing, apply the grief drip. If the memento returns (player picks
-- it back up), clear the missing flag and stop the drip.

require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.Sentimental = "0.0.1"

local STRESS_DELTA_PER_MIN  = 0.002
local UNHAPPY_DELTA_PER_MIN = 0.3
local GRIEF_DURATION_HOURS  = 4.0  -- how long missing-memento drip persists

local function _itemId(item)
    if not item or not item.getID then return nil end
    local id; pcall(function() id = item:getID() end)
    return id
end

local function _isPhoto(itemType)
    if not itemType then return false end
    local t = tostring(itemType)
    if t:sub(1,5) == "Base." then t = t:sub(6) end
    -- Photo, Photo_Racy, Photo_Secret, Photo_VeryOld - all Photo-prefixed
    return t == "Photo" or t:find("^Photo_") ~= nil
end

local function _isBusinessCard(itemType)
    if not itemType then return false end
    local t = tostring(itemType)
    if t:sub(1,5) == "Base." then t = t:sub(6) end
    return t:find("^BusinessCard") ~= nil
end

local function _halo(p, line)
    if not p or not line then return end
    if HaloTextHelper and HaloTextHelper.addText then
        pcall(function() HaloTextHelper.addText(p, line) end)
    end
end

-- Hook item pickup. PZ fires OnItemAddedToInventory or similar; we use the
-- inventory transfer chain. The most reliable hook is the timed action
-- ISInventoryTransferAction:complete - but we'd be patching deep. Simpler:
-- check on a 1-min tick whether the player has an untagged photo/card and
-- the player doesn't yet have a memento of that kind. Tag it.

-- Tag an item as a memento: set modData flag, append " (memento)" to its
-- display name via setCustomName + setName so it's visible in inventory
-- and tooltips. Vanilla name is preserved-ish in that PZ stores the script
-- displayName separately; we override the per-instance name.
local function _tagMemento(it, amd)
    amd.KH_Memento = true
    pcall(function()
        local original
        if it.getName then original = it:getName() end
        if not original or original == "" then return end
        if it.setCustomName then it:setCustomName(true) end
        if it.setName then it:setName(original .. " (memento)") end
    end)
end

local function _scanAndTagFirstMementos(p, st)
    local inv = p:getInventory()
    if not inv then return end
    -- already have both? skip
    if st.KH_PhotoMemento and st.KH_CardMemento then return end
    local items = inv:getItems()
    if not items then return end
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it then
            local t; pcall(function() t = it.getType and it:getType() end)
            local amd; pcall(function() amd = it.getModData and it:getModData() end)
            if amd and not amd.KH_Memento then
                if not st.KH_PhotoMemento and _isPhoto(t) then
                    _tagMemento(it, amd)
                    st.KH_PhotoMemento = _itemId(it)
                    _halo(p, "I'll hold onto this one.")
                elseif not st.KH_CardMemento and _isBusinessCard(t) then
                    _tagMemento(it, amd)
                    st.KH_CardMemento = _itemId(it)
                    _halo(p, "Funny. This used to mean something.")
                end
            end
        end
    end
end

-- Check whether a memento ID is still in the player's inventory recursively
local function _hasItemInInventory(inv, targetId)
    if not inv or not targetId then return false end
    local found = false
    pcall(function()
        if inv.containsID then found = inv:containsID(targetId) end
    end)
    return found
end

local function _checkMissing(p, st)
    local inv = p:getInventory()
    if not inv then return end
    local now = getGameTime():getWorldAgeHours()

    local function checkOne(idKey, missingKey)
        local id = st[idKey]
        if not id then return end
        if _hasItemInInventory(inv, id) then
            -- present - clear any missing flag and the grief timer
            if st[missingKey] then
                st[missingKey] = nil
            end
        else
            -- missing - set timestamp if not already
            if not st[missingKey] then
                st[missingKey] = now
                _halo(p, "...where did it go?")
            end
        end
    end
    checkOne("KH_PhotoMemento", "KH_PhotoMissingSince")
    checkOne("KH_CardMemento", "KH_CardMissingSince")
end

local function _applyGriefDrip(p, st)
    local now = getGameTime():getWorldAgeHours()
    local grieving = false
    if st.KH_PhotoMissingSince and now - st.KH_PhotoMissingSince < GRIEF_DURATION_HOURS then
        grieving = true
    end
    if st.KH_CardMissingSince and now - st.KH_CardMissingSince < GRIEF_DURATION_HOURS then
        grieving = true
    end
    if not grieving then return end

    local stats = p:getStats()
    if stats and stats.set then
        pcall(function()
            local s = (stats:get(CharacterStat.STRESS) or 0) + STRESS_DELTA_PER_MIN
            if s > 1 then s = 1 end
            stats:set(CharacterStat.STRESS, s)
        end)
        pcall(function()
            local u = (stats:get(CharacterStat.UNHAPPINESS) or 0) + UNHAPPY_DELTA_PER_MIN
            if u > 100 then u = 100 end
            stats:set(CharacterStat.UNHAPPINESS, u)
        end)
    end
end

-- Tagging + missing-check runs hourly (cheap, no need for per-minute):
-- you're unlikely to pick up a memento item AND lose it in the same hour
-- under normal play. But the grief drip needs to apply per-minute while
-- a memento is missing - we split the loops.
Events.EveryHours.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    if not KH.hasTrait(p, "KH:Sentimental") then return end
    local st = p:getModData()
    pcall(function() _scanAndTagFirstMementos(p, st) end)
    pcall(function() _checkMissing(p, st) end)
end)

-- Grief drip - only fires when a memento has been flagged missing by the
-- hourly check. Skips entirely otherwise, so it's cheap.
Events.EveryOneMinute.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    if not KH.hasTrait(p, "KH:Sentimental") then return end
    local st = p:getModData()
    if not st.KH_PhotoMissingSince and not st.KH_CardMissingSince then return end
    pcall(function() _applyGriefDrip(p, st) end)
end)

print("[KH] Sentimental trait behavior loaded (first-photo + first-card mementos)")
