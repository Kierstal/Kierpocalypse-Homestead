-- Kierpocalyptic Homestead - BWO Pay scope tightening
--
-- BWO's BWOPlayer.Pay fires on inventory transfer when BWORooms.TakeIntention
-- returns shouldPay=true. The decision is room-based. Two problems with the
-- shipped logic:
--
--   1. The "Garbage / Trash / Bin always free" branch sits AFTER the
--      Restaurant / Shop branches in an if/elseif chain. Garbage in a
--      restaurant gets charged because the Restaurant branch fires first.
--      Kierstal's playtest: $10 charged for looting a restaurant garbage can.
--
--   2. Restaurants charge for ANYTHING taken, including back-of-house
--      kitchen equipment (fridge, stove, oven, microwave). Kierstal's
--      framing: "It didn't feel right to go into the restaurant's kitchen
--      and just start buying ingredients directly from their counters."
--
-- KH's vendor-only interpretation: payment should only trigger for
-- vendor-style containers (displays, shelves, refrigerated cases visible to
-- customers), and items placed on the world (lemon pie on a bakery counter).
-- Back-of-house kitchen equipment is staff-only and shouldn't transact.
-- Garbage is always free, no matter where.
--
-- This monkey-patches BWORooms.TakeIntention at OnGameStart to:
--   - Short-circuit garbage/trash/bin to always-free regardless of room
--   - In Restaurant rooms, short-circuit back-of-house equipment to free
--   - Otherwise call BWO's original logic
--
-- BWO's original behavior for actual vendor containers (shop shelves,
-- display cases) is preserved untouched - we only carve out exclusions.

require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.BWOPayScope = "0.0.1"

-- Container customNames that are always free regardless of room context.
-- These are the "this is trash, not merchandise" set.
local ALWAYS_FREE_NAMES = {
    ["Trash"]    = true,
    ["Garbage"]  = true,
    ["Bin"]      = true,
    ["Litterbox"] = true,  -- pet hygiene, not merchandise
    ["Dumpster"] = true,
}

-- Container customNames that are kitchen back-of-house equipment. In a
-- Restaurant room these are staff-only and shouldn't charge. In other room
-- contexts (someone's home kitchen, a shop's break room), they're already
-- handled correctly by BWO's other branches so this list only matters when
-- the surrounding room is Restaurant.
local KITCHEN_BACK_OF_HOUSE = {
    ["Fridge"]      = true,
    ["Freezer"]     = true,
    ["Stove"]       = true,
    ["Oven"]        = true,
    ["Microwave"]   = true,
    ["Counter"]     = true,
    ["Cupboard"]    = true,
    ["Shelf"]       = true,
    ["Sink"]        = true,
    ["Dishwasher"]  = true,
}

local function patch()
    if not KH.compat or not KH.compat.banditsweekone then
        if KH.DEBUG then
            print("[KH] BWOPayScope: Week One not detected, no patch needed")
        end
        return
    end

    if not BWORooms or not BWORooms.TakeIntention then
        print("[KH] BWOPayScope: BWORooms.TakeIntention not found - BWO load order issue?")
        return
    end

    local _origTakeIntention = BWORooms.TakeIntention

    -- Helper: is the room inside a building Wilda has committed to as a Safehouse
    -- (via KH_HomeTerritory)? If yes, the whole building is full-access for her -
    -- she's stocking the family's pantry, not stealing from strangers. Fridge,
    -- cabinets, anything goes.
    local function _isInSafehouse(room)
        if not room then return false end
        if not KH.HomeTerritory then return false end
        local building = room:getBuilding()
        if not building then return false end
        -- KH_HomeTerritory exposes isSafehouse(building) once Safehouse type
        -- ships. Pcall-wrapped in case the API isn't there yet during the
        -- transition period.
        local ok, result = pcall(function()
            if KH.HomeTerritory.isSafehouse then
                return KH.HomeTerritory.isSafehouse(building)
            end
            return false
        end)
        return ok and result == true
    end

    BWORooms.TakeIntention = function(room, customName)
        -- Carve-out 0: Safehouse buildings are Wilda's delivery clients. She's
        -- there to feed them - the fridge and pantry should not trigger any
        -- theft / payment reaction. Full access throughout the building.
        if _isInSafehouse(room) then
            return true, false  -- canTake=true, shouldPay=false
        end

        -- Carve-out 1: always-free names (garbage, litterbox, dumpster).
        -- Catches the restaurant-garbage bug regardless of room context.
        if customName and ALWAYS_FREE_NAMES[customName] then
            return true, false  -- canTake=true, shouldPay=false
        end

        -- Carve-out 2: in Restaurant rooms, back-of-house kitchen equipment
        -- is staff-only. Don't charge for taking ingredients off the line.
        -- BWO's original would treat the whole restaurant as a shop.
        if customName and KITCHEN_BACK_OF_HOUSE[customName] then
            local ok, isRestaurant = pcall(function()
                return BWORooms.IsRestaurant and BWORooms.IsRestaurant(room)
            end)
            if ok and isRestaurant then
                -- Back-of-house: stealing from a kitchen line is shoplifting,
                -- not a vendor transaction. Return not-canTake+not-shouldPay
                -- so BWO's caller treats it as theft (witness activates) -
                -- which is correct for back-of-house, the cooks aren't selling.
                -- If Kierstal wants this to instead be silently free, change
                -- the first return to true.
                return false, false
            end
        end

        -- Otherwise defer to BWO's original logic. Vendor displays, shops,
        -- residential rules, machines etc. are all unchanged.
        return _origTakeIntention(room, customName)
    end

    print("[KH] BWOPayScope: BWORooms.TakeIntention patched - garbage always free, "
          .. "restaurant back-of-house = theft (not transaction).")
end

Events.OnGameStart.Add(patch)
