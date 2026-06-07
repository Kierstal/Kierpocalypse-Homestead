-- Kierpocalyptic Homestead - BWO vehicle-spawn NPE suppression
--
-- BWO (Bandits Week One) spawns vehicles via BWOCompatibility.AddVehicle.
-- The B42 path calls vanilla `addVehicle(btype, x, y, z)`, which triggers
-- the engine's BaseVehicle.addToWorld -> createPhysics -> randomizeContainers
-- chain. If randomizeContainers picks an item whose factory returns null
-- (renamed/removed item still referenced in a distribution table), the
-- engine NPEs inside `Item.InstanceItem` calling `setAlcoholPower` on the
-- null InventoryItem.
--
-- Observed during playtest 2026-05-27. KH_ItemSpawnDiag was re-enabled to
-- pinpoint the culprit item. Until the offending distribution entry is
-- fixed, this module pcall-wraps the addVehicle call so the spawn either
-- succeeds (vehicle exists, BWO immediately calls removeAllItems anyway)
-- or fails silently (returns nil; BWO already handles `if vehicle then`).
--
-- IMPORTANT BEHAVIOR NOTE:
-- BWO calls `container:removeAllItems()` on every part container
-- immediately after spawn (BWOVehicles.lua line 111). So the engine-rolled
-- loot is wiped within a frame of being created - the NPE is mid-creation
-- of items BWO doesn't even want. Failing the spawn entirely (returning
-- nil) is the safer outcome than returning a partially-initialized vehicle
-- whose internal state might be corrupted.
--
-- Personal-use scope: we patch BWO from KH (monkeypatch at OnGameStart)
-- so the fix survives BWO Workshop updates. If BWO publishes a real fix
-- upstream, delete this file.

require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.BanditsFixVehicleNPE = "0.0.1"

local function patch()
    if not KH.compat or not KH.compat.banditsweekone then
        if KH.DEBUG then
            print("[KH] BanditsFixVehicleNPE: Week One not detected, no patch needed")
        end
        return
    end

    -- BWOCompatibility is a global table set up in BWO's shared/BWOCompatibility.lua
    if not BWOCompatibility or not BWOCompatibility.AddVehicle then
        print("[KH] BanditsFixVehicleNPE: BWOCompatibility.AddVehicle not found - BWO load order issue?")
        return
    end

    local _orig = BWOCompatibility.AddVehicle
    local suppressed = 0
    BWOCompatibility.AddVehicle = function(btype, dir, square)
        local ok, vehicle = pcall(_orig, btype, dir, square)
        if not ok then
            suppressed = suppressed + 1
            -- Throttle the log: every spawn attempt is fine, every 10 we
            -- print a tally. Otherwise this would flood worse than the
            -- original NPE.
            if suppressed <= 3 or suppressed % 10 == 0 then
                print(string.format(
                    "[KH] BanditsFixVehicleNPE: suppressed engine error spawning %s (total=%d). Underlying item still needs fixing; check KH_ItemSpawnDiag output.",
                    tostring(btype), suppressed))
            end
            return nil
        end
        return vehicle
    end

    print("[KH] BanditsFixVehicleNPE: monkey-patched BWOCompatibility.AddVehicle for pcall safety")
end

-- OnGameStart fires after every mod has loaded its file-top globals, which
-- is the earliest point we can be sure BWOCompatibility exists.
Events.OnGameStart.Add(patch)
