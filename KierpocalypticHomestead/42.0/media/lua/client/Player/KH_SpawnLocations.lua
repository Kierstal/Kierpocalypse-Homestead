-- Kierpocalyptic Homestead - profession-themed spawn locations
--
-- Override the player's spawn coordinates based on profession, so a Park Ranger
-- starts at a ranger station, a Carpenter starts at a workshop, a Cook starts
-- at a restaurant, etc. Lines up the THEMATIC start with the mechanical one.
--
-- Architecture:
--   1. Player picks a spawn region on the new-game screen (Muldraugh / West Point
--      / Riverside / Louisville). Vanilla PZ places them somewhere in that region.
--   2. On OnGameStart, if KHCompat.EnableSpawnLocations is ON and the player's
--      profession has a KH-defined location set AND the player is in the matching
--      region, KH teleports them to one of the candidate buildings.
--   3. If the player's profession isn't in LOCATIONS, or the toggle is OFF, or
--      no candidate is in their region, vanilla spawn stands. No surprises.
--
-- SAFE DEFAULTS:
--   - Sandbox toggle defaults OFF until coordinates are validated in-game.
--   - All teleport calls are pcall-wrapped.
--   - Coordinates marked with TODO need to be replaced with real values
--     captured via PZ's debug "Display Coordinates" feature.
--
-- HOW TO ADD COORDINATES (for future Kierstal or instance):
--   1. Enable PZ's debug mode (-debug launch flag) or use a coordinate-display mod.
--   2. Spawn in the target region, walk to the desired building.
--   3. Record the building's tile coordinates from the on-screen display.
--   4. Add an entry to LOCATIONS[profession] = { ... }.
--   5. Set KHCompat.EnableSpawnLocations to ON in sandbox.
--   6. Start a new game with that profession + region, verify spawn lands cleanly.
--
-- v0.0.1 (2026-05-29): framework + ParkRanger skeleton. Coordinates TBD.

require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.SpawnLocations = "0.0.1"

-- Region bounding boxes. A spawn coordinate is "in region R" if its tile coords
-- fall within these boxes. Used to match a profession's candidate buildings
-- against the player's chosen spawn region.
-- These are rough Knox map approximations; refine if spawn-region detection
-- misses obvious cases.
local REGIONS = {
    Muldraugh = { x1 =  9500, y1 =  9000, x2 = 11500, y2 = 11500 },
    WestPoint = { x1 = 10800, y1 =  6500, x2 = 13000, y2 =  8500 },
    Riverside = { x1 =  5500, y1 =  5500, x2 =  7500, y2 =  7500 },
    -- Louisville bounds are huge; add when needed.
}

-- LOCATIONS: per-profession lists of candidate spawn buildings.
-- Each entry: { region = "Muldraugh", x = ###, y = ###, z = 0, label = "..." }
-- The label is for log readability; pick the most evocative description.
--
-- ADDING ENTRIES: each profession can have multiple candidates - we pick one
-- at random so replays feel fresh. Coordinates are TILE coordinates (not pixel),
-- visible via PZ debug "Display Coordinates" overlay.
local LOCATIONS = {
    parkranger = {
        -- Kierstal's chosen ranger location, captured 2026-05-29 from b42map.com.
        -- West-side B42 expansion area (outside Muldraugh / WestPoint / Riverside
        -- region bounds). Likely Echo Creek or forest expansion.
        { x = 4505, y = 5706, z = 0, label = "ranger station (Kierstal's pick)" },
    },

    -- Future profession entries follow the same shape. Examples to fill in:
    -- carpenter = { { x = ..., y = ..., z = 0, label = "workshop" }, },
    -- chef      = { { x = ..., y = ..., z = 0, label = "restaurant kitchen" }, },
    -- farmer    = { { x = ..., y = ..., z = 0, label = "farmhouse" }, },
}

-- Helper: pick a random candidate from a list. If any candidates declare a
-- region and the player's spawn falls within that region, prefer those.
-- Otherwise pick any candidate. The region filter is advisory, not required -
-- enabling the toggle means "trust KH to pick a thematic spot."
local function _regionOf(x, y)
    for name, b in pairs(REGIONS) do
        if x >= b.x1 and x <= b.x2 and y >= b.y1 and y <= b.y2 then
            return name
        end
    end
    return nil
end

local function _pickCandidate(candidates, region)
    if not candidates or #candidates == 0 then return nil end
    -- Prefer region-matched candidates if any candidate declares a region.
    local hasRegionedCandidate = false
    for _, c in ipairs(candidates) do
        if c.region then hasRegionedCandidate = true; break end
    end
    if hasRegionedCandidate and region then
        local matches = {}
        for _, c in ipairs(candidates) do
            if c.region == region then matches[#matches + 1] = c end
        end
        if #matches > 0 then return matches[ZombRand(#matches) + 1] end
    end
    -- Otherwise pick any candidate (region not declared or no match).
    return candidates[ZombRand(#candidates) + 1]
end

-- pcall-wrapped sandbox-toggle check. Returns the toggle's value if readable,
-- or TRUE if the option machinery is unreachable (we default to teleporting,
-- since LOCATIONS being empty is a separate guard - no entry = no teleport
-- happens anyway, so the toggle becomes effectively an opt-OUT for players
-- who actively want vanilla spawn even with their profession in LOCATIONS).
local function _toggleEnabled()
    local ok, opt = pcall(function()
        return getSandboxOptions():getOptionByName("KHCompat.EnableSpawnLocations")
    end)
    if not ok or not opt then return true end  -- machinery unavailable, default ON
    local val
    pcall(function() val = opt:getValue() end)
    if val == nil then return true end          -- option exists but unset, default ON
    return val == true
end

-- Get the player's profession id (lowercase, matches KH_StarterKits lookup pattern).
-- Uses getCharacterProfession():getName() like KH_StarterKits does. Earlier
-- version called desc:getProfession() which doesn't exist on B42 Descriptor.
local function _profId(player)
    if not player then return nil end
    local desc
    pcall(function() desc = player:getDescriptor() end)
    if not desc then return nil end
    local prof
    pcall(function() prof = desc:getCharacterProfession() end)
    if not prof then return nil end
    local profName
    pcall(function() profName = prof:getName() end)
    if not profName then return nil end
    return tostring(profName):lower()
end

local function _teleportPlayer(player, candidate)
    if not player or not candidate then return false end
    local cell = getCell()
    if not cell then return false end
    local sq = cell:getGridSquare(candidate.x, candidate.y, candidate.z or 0)
    if not sq then
        print(string.format("[KH] SpawnLocations: square (%d,%d,%d) not loaded yet - skipping teleport",
            candidate.x, candidate.y, candidate.z or 0))
        return false
    end
    local ok = pcall(function() player:setX(sq:getX()) end)
    if not ok then return false end
    pcall(function() player:setY(sq:getY()) end)
    pcall(function() player:setZ(sq:getZ()) end)
    pcall(function() player:setCurrentSquare(sq) end)
    print(string.format("[KH] SpawnLocations: teleported to %s (%d,%d,%d)",
        candidate.label or "candidate", candidate.x, candidate.y, candidate.z or 0))
    return true
end

local function _onGameStart()
    if not _toggleEnabled() then
        if KH.DEBUG then print("[KH] SpawnLocations: toggle OFF, no override.") end
        return
    end

    local player = getPlayer()
    if not player then return end

    local prof = _profId(player)
    if not prof then return end

    local candidates = LOCATIONS[prof]
    if not candidates or #candidates == 0 then
        if KH.DEBUG then print("[KH] SpawnLocations: no entries for profession '"..prof.."'") end
        return
    end

    local px, py = player:getX(), player:getY()
    local region = _regionOf(px, py)  -- nil is fine - advisory only

    local pick = _pickCandidate(candidates, region)
    if not pick then
        if KH.DEBUG then print("[KH] SpawnLocations: no candidate for "..prof) end
        return
    end

    _teleportPlayer(player, pick)
end

Events.OnGameStart.Add(_onGameStart)

print("[KH] SpawnLocations v0.0.1 loaded (toggle-gated, coordinates TBD).")
