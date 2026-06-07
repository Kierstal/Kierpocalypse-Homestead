-- Kierpocalyptic Homestead - Simple Lockpicking
--
-- Right-click a locked door while carrying a Screwdriver AND a Paperclip ->
-- "Pick Lock". A short action unlocks the door and consumes the paperclip
-- (the screwdriver is reusable). Works on map doors (IsoDoor) and player-built
-- doors (IsoThumpable doors); walls/windows are ignored.
--
-- Tool lookup uses getItemFromType with bare type names (the proven pattern from
-- KH_HygieneActions). Door-unlock methods are pcall-probed since the exact
-- setter varies; if the lock can't be cleared the action is a harmless no-op.

require "ISUI/ISWorldObjectContextMenu"
require "TimedActions/ISBaseTimedAction"
require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.Lockpick = "0.0.1"

local function _find(inv, bareType)
    if not inv then return nil end
    local it
    pcall(function() it = inv:getItemFromType(bareType) end)
    return it
end

local function _hasTools(player)
    local inv = player:getInventory()
    if not inv then return false end
    return _find(inv, "Screwdriver") ~= nil and _find(inv, "Paperclip") ~= nil
end

-- Return the object if it's a LOCKED door-like, else nil.
local function _lockedDoor(obj)
    if not obj then return nil end
    local isDoor  = instanceof(obj, "IsoDoor")
    local isThump = (not isDoor) and instanceof(obj, "IsoThumpable")
    if not isDoor and not isThump then return nil end
    if isThump then
        -- IsoThumpable covers walls too; only treat actual doors.
        local d = false
        pcall(function() if obj.isDoor then d = obj:isDoor() end end)
        if not d then return nil end
    end
    local locked = false
    pcall(function() if obj.isLockedByKey and obj:isLockedByKey() then locked = true end end)
    if not locked then
        pcall(function() if obj.isLocked and obj:isLocked() then locked = true end end)
    end
    return locked and obj or nil
end

-- ---------- timed action ----------

KH_PickLockAction = ISBaseTimedAction:derive("KH_PickLockAction")

function KH_PickLockAction:isValid()
    return self.door ~= nil and self.character ~= nil
end

function KH_PickLockAction:update()
    if self.door and self.door.getSquare and self.door:getSquare() then
        local sq = self.door:getSquare()
        self.character:faceLocation(sq:getX(), sq:getY())
    end
end

function KH_PickLockAction:start()
    self:setActionAnim("Loot")
end

function KH_PickLockAction:perform()
    local door = self.door
    if door then
        pcall(function() if door.setLockedByKey then door:setLockedByKey(false) end end)
        pcall(function() if door.setLocked     then door:setLocked(false)     end end)
    end
    -- Consume one paperclip; screwdriver survives.
    if self.character then
        local inv = self.character:getInventory()
        local clip = _find(inv, "Paperclip")
        if clip and inv then pcall(function() inv:Remove(clip) end) end
        if HaloTextHelper and HaloTextHelper.addText then
            pcall(function() HaloTextHelper.addText(self.character, "Lock picked") end)
        end
    end
    ISBaseTimedAction.perform(self)
end

function KH_PickLockAction:new(character, door)
    local o = ISBaseTimedAction.new(self, character)
    o.door       = door
    o.maxTime    = 120
    o.stopOnWalk = true
    o.stopOnRun  = true
    return o
end

-- ---------- context menu ----------

local function onPickClicked(worldobjects, playerArg, door)
    local ch = (type(playerArg) == "number") and getSpecificPlayer(playerArg)
               or (playerArg and playerArg.getInventory and playerArg) or getPlayer()
    if not ch or not door then return end
    local sq = door.getSquare and door:getSquare()
    if not sq then return end
    if luautils and luautils.walkAdj then
        if not luautils.walkAdj(ch, sq, true) then return end
    end
    ISTimedActionQueue.add(KH_PickLockAction:new(ch, door))
end

local function onFillContext(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    if not _hasTools(player) then return end
    local door = nil
    for _, o in ipairs(worldobjects) do
        local d = _lockedDoor(o)
        if d then door = d break end
    end
    if not door then return end
    local label = (getText and getText("ContextMenu_KH_PickLock"))
                  or "Pick Lock (screwdriver + paperclip)"
    local opt = context:addOption(label, worldobjects, onPickClicked, playerNum, door)
    if KH.UI and KH.UI.markOption then KH.UI.markOption(opt) end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContext)

print("[KH] Simple Lockpicking loaded (screwdriver + paperclip)")
