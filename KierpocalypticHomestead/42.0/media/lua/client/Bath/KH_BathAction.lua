-- Kierpocalyptic Homestead - Bath/Shower/Sponge fallback action
--
-- KH ships KH_BathNeed (tracking) but not a KH bath ACTION - bathing was
-- supposed to be Lifestyle: Hobbies' job. With Bandits loaded, Lifestyle's
-- bath/shower context menu silently breaks. The need rises, the user has
-- nothing to do about it.
--
-- This module provides a fallback. When BOTH Lifestyle AND Bandits are
-- loaded (the known-bad combination), KH adds its own "Wash Up" right-click
-- option on bathtub / shower / sink sprites in bathroom rooms. The action
-- resets KH's bath need + reduces the dirt stat.
--
-- When only Lifestyle is loaded (working case), KH does nothing - Lifestyle
-- owns the action. When neither is loaded, KH owns the action fully.
--
-- Sprite detection follows the same pattern as KH_UseToiletAction: vanilla
-- B42 fixtures often have CustomName unset, so we fall back to sprite-name
-- substring match + room-type gate.

require "TimedActions/ISBaseTimedAction"
require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.BathAction = "0.0.1"

local PERFORM_TICKS = 250  -- bathing is slower than washing hands

-- ------------------------------------------------------------------
-- Activation gate: only run when Lifestyle would have failed
-- ------------------------------------------------------------------

local function _shouldProvideFallback()
    if not KH.compat then return false end
    -- The known-bad combination: both Lifestyle and Bandits loaded.
    -- Lifestyle's hygiene action breaks; KH catches the gap.
    if KH.compat.lifestyle and KH.compat.banditsweekone then
        return true
    end
    -- Lifestyle not loaded: KH would own this anyway. (Right now KH_BathNeed
    -- doesn't ship a primary action - this fallback IS the action for that
    -- case too.)
    if not KH.compat.lifestyle then
        return true
    end
    -- Lifestyle loaded without Bandits: working case, KH defers.
    return false
end

-- ------------------------------------------------------------------
-- The timed action
-- ------------------------------------------------------------------

KH_BathAction = ISBaseTimedAction:derive("KH_BathAction")

function KH_BathAction:isValid()
    return self.fixture and self.fixture.getSquare and self.fixture:getSquare() ~= nil
end

function KH_BathAction:update()
    if self.fixture and self.fixture.getSquare and self.fixture:getSquare() then
        local sq = self.fixture:getSquare()
        self.character:faceLocation(sq:getX(), sq:getY())
    end
end

function KH_BathAction:start()
    self:setActionAnim("WashFace")  -- vanilla animation closest to bathing
end

function KH_BathAction:perform()
    local p = self.character
    if p then
        -- Reset KH bath need.
        if KH.Bath and KH.Bath.set then
            pcall(function() KH.Bath.set(p, 0) end)
        end
        -- Reset dirt stat too (vanilla approximation of being washed).
        if p.getBodyDamage then
            local bd = p:getBodyDamage()
            if bd and bd.getBodyParts then
                local parts = bd:getBodyParts()
                if parts then
                    for i = 0, parts:size() - 1 do
                        local part = parts:get(i)
                        if part and part.setBleeding then
                            pcall(function() part:setDirtyness(0) end)
                        end
                    end
                end
            end
        end
        -- Modest unhappiness relief.
        local stats = p:getStats()
        if stats and CharacterStat and CharacterStat.UNHAPPINESS then
            local u = stats:get(CharacterStat.UNHAPPINESS) or 0
            stats:set(CharacterStat.UNHAPPINESS, math.max(0, u - 6))
        end
        -- Thought emit.
        if KH.Thoughts and KH.Thoughts.emit then
            KH.Thoughts.emit(p, "bath", "washed")
        end
    end
    ISBaseTimedAction.perform(self)
end

function KH_BathAction:new(character, fixture)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.fixture = fixture
    o.maxTime = PERFORM_TICKS
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

-- ------------------------------------------------------------------
-- Sprite + room detection (same pattern as KH_UseToiletAction)
-- ------------------------------------------------------------------

-- Vanilla B42 bath/shower fixture sprite name fragments.
local BATH_SPRITE_FRAGMENTS = {
    "bathtub", "bath_tub", "shower", "sink",
    "fixtures_bathroom_01",   -- generic atlas (filter by room below)
    "fixtures_kitchen_01_sink",
}

local function _inBathroomRoom()
    local p = getPlayer(); if not p then return false end
    local sq = p:getCurrentSquare(); if not sq then return false end
    local room = sq:getRoom(); if not room then return false end
    local def = room.getRoomDef and room:getRoomDef()
    local name = def and def.getName and def:getName() or ""
    name = string.lower(tostring(name))
    return string.find(name, "bath", 1, true) ~= nil
        or string.find(name, "restroom", 1, true) ~= nil
        or string.find(name, "shower", 1, true) ~= nil
end

local function _propStr(props, key)
    if not props then return nil end
    local v = nil
    pcall(function()
        if props.Val then v = props:Val(key) end
        if (v == nil or v == "") and props.getString then v = props:getString(key) end
    end)
    if v == nil or v == "" then return nil end
    return tostring(v)
end

local function isBathFixture(obj)
    if not obj then return false end
    local sprite = obj.getSprite and obj:getSprite()
    if not sprite then return false end
    -- Try CustomName/GroupName first.
    local cn
    if sprite.getProperties then
        local ok, props = pcall(function() return sprite:getProperties() end)
        if ok and props then
            cn = _propStr(props, "CustomName")
        end
    end
    if cn then
        local lcn = string.lower(cn)
        if string.find(lcn, "bath", 1, true) or string.find(lcn, "shower", 1, true)
           or string.find(lcn, "tub", 1, true) then
            return true
        end
    end
    -- Sprite-name fragment match, gated by bathroom-room context.
    local name = sprite.getName and sprite:getName()
    if not name then return false end
    local lname = string.lower(name)
    for _, frag in ipairs(BATH_SPRITE_FRAGMENTS) do
        if string.find(lname, frag, 1, true) then
            if _inBathroomRoom() then return true end
        end
    end
    return false
end

-- ------------------------------------------------------------------
-- Context menu wiring
-- ------------------------------------------------------------------

local function onWashUpClicked(worldobjects, playerArg, fixture)
    local character
    if type(playerArg) == "number" then character = getSpecificPlayer(playerArg)
    elseif playerArg and playerArg.getInventory then character = playerArg
    else character = getPlayer() end
    if not character or not fixture then return end
    local sq = fixture.getSquare and fixture:getSquare()
    if not sq then return end
    if luautils and luautils.walkAdj then
        if not luautils.walkAdj(character, sq, true) then return end
    end
    ISTimedActionQueue.add(KH_BathAction:new(character, fixture))
end

local function onFillContext(playerArg, context, worldobjects, test)
    if test then return end
    if not worldobjects then return end
    if not _shouldProvideFallback() then return end  -- Lifestyle owns it
    local seen = {}
    for _, obj in ipairs(worldobjects) do
        if obj and isBathFixture(obj) and not seen[obj] then
            seen[obj] = true
            local label = (getText and getText("ContextMenu_KH_WashUp")) or "Wash Up"
            context:addOption(label, worldobjects, onWashUpClicked, playerArg, obj)
            break  -- one option per click is enough
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContext)

print("[KH] BathAction registered (fallback when Lifestyle is missing or broken by Bandits)")
