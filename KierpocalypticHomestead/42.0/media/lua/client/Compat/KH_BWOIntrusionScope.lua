-- Kierpocalyptic Homestead - BWO intrusion scope adjustments
--
-- BWO's BWORooms.IsIntrusion(room) flags the player as an intruder when in
-- a residential building unless it's a party / shop / restaurant / medical
-- / church / empty room. NPCs then react to intruders with possible
-- hostility - the "Inhabitant" program rolls 50% chance to go hostile when
-- intrusion is detected, leading to frying-pan chases.
--
-- This doesn't fit Kierstal's character. Her Wilda is going door to door
-- checking on people, bringing supplies. The intrusion mechanic treats
-- her welfare visits as burglary attempts.
--
-- KH adds two carve-outs to BWORooms.IsIntrusion:
--
--   1. KH Safehouses (buildings she's committed to as delivery clients) are
--      never intrusion. Consistent with the BWOPayScope rule that lets her
--      open their fridge to stock food.
--
--   2. If she's playing as Park Ranger AND the sandbox option is on
--      (KHCompat.ParkRangerNoIntrusion default true), residential buildings
--      don't flag as intrusion for her. The framing: she's a public-service
--      worker doing welfare checks - residents recognize the uniform and
--      don't treat her as a threat.
--
-- BWO's other exceptions (party, medical, shop, restaurant, church) all
-- stay - those weren't broken to begin with.

require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.BWOIntrusionScope = "0.0.1"

-- Helper: is the room inside a building registered as a KH Safehouse?
-- Returns false defensively when KH_HomeTerritory hasn't shipped Safehouse
-- support yet (dormant until that arrives).
local function _isInSafehouse(room)
    if not room then return false end
    if not KH.HomeTerritory then return false end
    local building = room:getBuilding()
    if not building then return false end
    local ok, result = pcall(function()
        if KH.HomeTerritory.isSafehouse then
            return KH.HomeTerritory.isSafehouse(building)
        end
        return false
    end)
    return ok and result == true
end

-- Park Ranger profession check using the same API path KH_StarterKits uses.
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

-- Sandbox toggle for the Park Ranger exemption. Defaults to true (the toggle
-- being unset or unreadable returns true, matching the SpawnLocations default
-- pattern we settled on).
local function _parkRangerExemptionEnabled()
    local ok, opt = pcall(function()
        return getSandboxOptions():getOptionByName("KHCompat.ParkRangerNoIntrusion")
    end)
    if not ok or not opt then return true end
    local val
    pcall(function() val = opt:getValue() end)
    if val == nil then return true end
    return val == true
end

local function patch()
    if not KH.compat or not KH.compat.banditsweekone then
        if KH.DEBUG then
            print("[KH] BWOIntrusionScope: Week One not detected, no patch needed")
        end
        return
    end

    if not BWORooms or not BWORooms.IsIntrusion then
        print("[KH] BWOIntrusionScope: BWORooms.IsIntrusion not found - BWO load order issue?")
        return
    end

    local _origIsIntrusion = BWORooms.IsIntrusion

    BWORooms.IsIntrusion = function(room)
        -- Carve-out 1: Safehouses. She's there to help, not intrude.
        if _isInSafehouse(room) then
            return false
        end

        -- Carve-out 2: Park Ranger welfare-check framing. Residents see the
        -- uniform and don't treat her as a threat. Only applies when sandbox
        -- toggle is on (default true).
        local player = getSpecificPlayer(0)
        if player and _isParkRanger(player) and _parkRangerExemptionEnabled() then
            return false
        end

        -- Everything else: defer to BWO's original logic. Shops, restaurants,
        -- medical buildings etc. were already non-intrusion. Other residential
        -- buildings without a KH relationship stay intrusion.
        return _origIsIntrusion(room)
    end

    print("[KH] BWOIntrusionScope: BWORooms.IsIntrusion patched - Safehouses + Park Ranger welfare checks no longer flag as intrusion.")
end

Events.OnGameStart.Add(patch)
