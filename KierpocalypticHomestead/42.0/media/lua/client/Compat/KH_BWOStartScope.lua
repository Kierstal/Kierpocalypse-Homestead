-- Kierpocalyptic Homestead - BWO start-of-game scope adjustments
--
-- BWOEvents.Start (the schedule entry that fires at day 0) does several
-- things at new-game time:
--   1. Registers the player's building as "home"
--   2. Generates a home key
--   3. Gives 25-85 starting Money items
--   4. Adds profession items (for Park Ranger: Base.Bag_SurvivorBag)
--   5. If SandboxVars.BanditsWeekOne.StartBabe is true: spawns a random
--      "Babe" companion next to the player, permanent + loyal
--   6. If SandboxVars.BanditsWeekOne.StartRide is true: spawns a vehicle
--      in a nearby vehicle zone with the key in the player's inventory
--
-- Kierstal wants:
--   - NO Babe companion at spawn (she finds people in the world herself)
--   - NO Bag_SurvivorBag (her KH starter kit already includes Big Hiking Bag,
--     two bags is one too many)
--   - YES home registration, home key, starting cash, and starting vehicle
--
-- This module:
--   - Sets SandboxVars.BanditsWeekOne.StartBabe to false at OnGameStart
--     (before the schedule fires Start)
--   - On Park Ranger profession, removes Bag_SurvivorBag from inventory
--     after BWO has placed it (delayed cleanup, since Start runs after our
--     OnGameStart hook)

require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.BWOStartScope = "0.0.1"

local function setStartBabeOff()
    if not KH.compat or not KH.compat.banditsweekone then return end

    -- Two-channel write matching KH_BanditsTame's pattern.
    local ok, opt = pcall(function()
        return getSandboxOptions():getOptionByName("BanditsWeekOne.StartBabe")
    end)
    if ok and opt then
        pcall(function() opt:setValue(false) end)
    end
    if SandboxVars then
        SandboxVars.BanditsWeekOne = SandboxVars.BanditsWeekOne or {}
        SandboxVars.BanditsWeekOne.StartBabe = false
    end
    print("[KH] BWOStartScope: SandboxVars.BanditsWeekOne.StartBabe = false (no companion at spawn)")
end

-- Park Ranger profession check helper. Uses the same API path as KH_StarterKits
-- (which is known-working): getDescriptor():getCharacterProfession():getName().
-- Earlier version used desc:getProfession() which doesn't exist on B42 Descriptor
-- and produced "Object tried to call nil" stack-trace noise.
local function _isParkRanger(player)
    if not player then return false end
    local desc
    pcall(function() desc = player:getDescriptor() end)
    if not desc then return false end
    local prof
    pcall(function() prof = desc:getCharacterProfession() end)
    if not prof then return false end
    local profName
    pcall(function() profName = prof:getName() end)
    if not profName then return false end
    return tostring(profName):lower() == "parkranger"
end

-- Remove a specific item type from a player's main inventory. Returns true if
-- something was removed. Used to peel BWO's extra bag without disturbing the
-- rest of the player's starting items.
local function _removeFirstOfType(player, fullType)
    if not player then return false end
    local inv = player:getInventory()
    if not inv then return false end
    local items = inv:getItems()
    if not items then return false end
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it:getFullType() == fullType then
            inv:Remove(it)
            return true
        end
    end
    return false
end

-- BWOEvents.Start fires from BWOScheduler.CheckEvents which ticks every minute.
-- We want to clean up the SurvivorBag after BWO has placed it but before the
-- player notices it. Hook OnPlayerUpdate with a flag, scan for the bag every
-- few ticks until we find and remove it, then disengage.
local _cleanupRanger = false
local _cleanupTries  = 0
local _cleanupDone   = false

local function rangerBagCleanup()
    if _cleanupDone then return end
    if not _cleanupRanger then return end

    -- Throttle: only check every ~30 ticks (rough order, OnPlayerUpdate fires
    -- many times per second).
    _cleanupTries = _cleanupTries + 1
    if _cleanupTries % 30 ~= 0 then return end

    local player = getPlayer()
    if not player then return end

    if _removeFirstOfType(player, "Base.Bag_SurvivorBag") then
        print("[KH] BWOStartScope: removed BWO's Bag_SurvivorBag (Park Ranger already has Big Hiking Bag from KH starter kit)")
        _cleanupDone = true
        return
    end

    -- Give up after a reasonable number of tries (rough 30-second window).
    if _cleanupTries > 1800 then
        _cleanupDone = true
        if KH.DEBUG then
            print("[KH] BWOStartScope: SurvivorBag cleanup timed out (bag not found or already removed)")
        end
    end
end

local function onGameStart()
    setStartBabeOff()

    local player = getPlayer()
    if player and _isParkRanger(player) then
        _cleanupRanger = true
        Events.OnPlayerUpdate.Add(rangerBagCleanup)
        if KH.DEBUG then
            print("[KH] BWOStartScope: armed Park Ranger SurvivorBag cleanup")
        end
    end
end

Events.OnGameStart.Add(onGameStart)
