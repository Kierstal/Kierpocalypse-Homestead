-- Kierpocalyptic Homestead - Crowbar pry action
--
-- Adds "Pry Open (Crowbar)" / "Pry Latch (Crowbar)" context-menu options
-- on locked doors and closed windows when the player has a crowbar in
-- primary or secondary hand.
--
-- - Locked door: 80% chance to unlock + light condition damage to crowbar.
--                If roll fails, condition damage still applies (you made
--                progress, no result this attempt).
-- - Closed window with locked latch: smashes the latch and opens. Always
--                succeeds (windows don't have a "locked" boolean like
--                doors; if it's closed, prying just opens it.)
--
-- Action time scales with Carpentry skill + Strength.

require "TimedActions/ISBaseTimedAction"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.PryAction = "0.0.1"

local BASE_TICKS = 120
local UNLOCK_CHANCE = 80  -- percent

local function findCrowbar(character)
    if not character or not character.getInventory then return nil end
    -- Primary hand
    local prim = character.getPrimaryHandItem and character:getPrimaryHandItem()
    if prim and prim.getType and prim:getType() == "Crowbar" then return prim end
    -- Secondary hand
    local sec = character.getSecondaryHandItem and character:getSecondaryHandItem()
    if sec and sec.getType and sec:getType() == "Crowbar" then return sec end
    -- Inventory fallback
    local inv = character:getInventory()
    if inv and inv.getItemFromType then
        local ok, it = pcall(function() return inv:getItemFromType("Crowbar") end)
        if ok and it then return it end
    end
    return nil
end

local function calcActionTime(character)
    local time = BASE_TICKS
    if Perks and Perks.Woodwork and character.getPerkLevel then
        local carp = character:getPerkLevel(Perks.Woodwork) or 0
        time = time - (carp * 4)
    end
    if Perks and Perks.Strength and character.getPerkLevel then
        local str = character:getPerkLevel(Perks.Strength) or 0
        time = time - (str * 3)
    end
    if time < 30 then time = 30 end
    return time
end

KH_PryAction = ISBaseTimedAction:derive("KH_PryAction")

function KH_PryAction:isValid()
    if not self.target then return false end
    if not findCrowbar(self.character) then return false end
    if self.targetType == "door" then
        return self.target.IsDoor or instanceof(self.target, "IsoDoor") or instanceof(self.target, "IsoThumpable")
    elseif self.targetType == "window" then
        return self.target.IsWindow or instanceof(self.target, "IsoWindow")
    end
    return false
end

function KH_PryAction:update()
    if self.target and self.target.getSquare and self.target:getSquare() then
        local sq = self.target:getSquare()
        self.character:faceLocation(sq:getX(), sq:getY())
    end
end

function KH_PryAction:start()
    self:setActionAnim("Loot")
end

function KH_PryAction:perform()
    local crowbar = findCrowbar(self.character)
    if crowbar then
        -- Condition damage: ~1 in 8 chance of -1 condition per pry
        if crowbar.setCondition and crowbar.getCondition then
            if ZombRand(8) == 0 then
                local c = crowbar:getCondition() or 0
                if c > 0 then
                    pcall(function() crowbar:setCondition(c - 1) end)
                end
            end
        end
    end
    if self.targetType == "door" and self.target then
        -- Roll for success FIRST. Only unlock on success - otherwise the door
        -- stays locked and the player can retry. Earlier version unlocked
        -- unconditionally, which made the pry option disappear after one
        -- attempt because isLockedDoor returned false.
        if ZombRand(100) < UNLOCK_CHANCE then
            if self.target.setLocked then
                pcall(function() self.target:setLocked(false) end)
            end
            if self.target.ToggleDoor then
                pcall(function() self.target:ToggleDoor(self.character) end)
            end
        end
        -- Failed roll: condition damage already applied above. Door stays
        -- locked. Player can attempt again.
    elseif self.targetType == "window" and self.target then
        if self.target.smashWindow then
            pcall(function() self.target:smashWindow() end)
        end
        if self.target.setIsLocked then
            pcall(function() self.target:setIsLocked(false) end)
        end
        if self.target.ToggleWindow then
            pcall(function() self.target:ToggleWindow(self.character) end)
        elseif self.target.openWindow then
            pcall(function() self.target:openWindow(self.character) end)
        end
    end
    ISBaseTimedAction.perform(self)
end

function KH_PryAction:new(character, target, targetType)
    local o = ISBaseTimedAction.new(self, character)
    o.target = target
    o.targetType = targetType
    o.maxTime = calcActionTime(character)
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

-- ---- Context menu wiring ----

local function isLockedDoor(obj)
    if not obj then return false end
    if not (instanceof(obj, "IsoDoor") or instanceof(obj, "IsoThumpable")) then return false end
    if obj.isLocked and obj:isLocked() then return true end
    return false
end

local function isClosedWindow(obj)
    if not obj then return false end
    if not instanceof(obj, "IsoWindow") then return false end
    if obj.IsOpen and obj:IsOpen() then return false end
    -- Closed window, prying makes sense
    return true
end

local function onPryDoorClicked(worldobjects, playerArg, target)
    local character = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or (playerArg and playerArg.getInventory and playerArg) or getPlayer()
    if not character or not target then return end
    local sq = target.getSquare and target:getSquare()
    if sq and luautils and luautils.walkAdj then
        if not luautils.walkAdj(character, sq, true) then return end
    end
    ISTimedActionQueue.add(KH_PryAction:new(character, target, "door"))
end

local function onPryWindowClicked(worldobjects, playerArg, target)
    local character = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or (playerArg and playerArg.getInventory and playerArg) or getPlayer()
    if not character or not target then return end
    local sq = target.getSquare and target:getSquare()
    if sq and luautils and luautils.walkAdj then
        if not luautils.walkAdj(character, sq, true) then return end
    end
    ISTimedActionQueue.add(KH_PryAction:new(character, target, "window"))
end

local function onFillContext(playerArg, context, worldobjects, test)
    if test then return end
    if not worldobjects then return end
    local character = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    if not character then return end
    if not findCrowbar(character) then return end
    local seenDoor, seenWindow = false, false
    for _, obj in ipairs(worldobjects) do
        if obj and not seenDoor and isLockedDoor(obj) then
            seenDoor = true
            local label = (getText and getText("ContextMenu_KH_PryDoor")) or "Pry Open (Crowbar)"
            context:addOption(label, worldobjects, onPryDoorClicked, playerArg, obj)
        elseif obj and not seenWindow and isClosedWindow(obj) then
            seenWindow = true
            local label = (getText and getText("ContextMenu_KH_PryWindow")) or "Pry Latch (Crowbar)"
            context:addOption(label, worldobjects, onPryWindowClicked, playerArg, obj)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContext)

print("[KH] Crowbar pry action + context menu registered")
