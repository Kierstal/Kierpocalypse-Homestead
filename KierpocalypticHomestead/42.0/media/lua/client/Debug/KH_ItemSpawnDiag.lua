-- Kierpocalyptic Homestead - item-instantiation diagnostic
--
-- TEMPORARY DIAGNOSTIC. Hunts the item that causes the recurring
--   "Cannot invoke InventoryItem.setAlcoholPower(float) because item is null"
-- NPE during loot rolls. That error means a script Item exists but PZ's
-- InstanceItem() can't build an InventoryItem for it (unrecognized Type,
-- missing required field, etc.), so `item` stays null and the unconditional
-- setAlcoholPower call NPEs.
--
-- This script iterates every loaded script item once at game start, tries to
-- instance each, and prints the full type of any that fail. Run it, read the
-- console for "[KH][diag] FAILED TO INSTANCE: <fulltype>", and that's the
-- culprit. Then we fix/remove whatever distribution references it.
--
-- Remove this file once the offender is identified.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ItemSpawnDiag = "0.0.1"

-- DISABLED 2026-05-24: the scan ran clean (0/5093 items failed to instance),
-- confirming there is NO malformed item behind the old setAlcoholPower NPE -
-- that was the WhiskeyEmpty reference, already fixed (#130). Left the file in
-- place (can't delete from here) but short-circuited so it no longer scans
-- every launch. Flip DIAG_ENABLED back to true only if the NPE resurfaces.
--
-- RE-ENABLED 2026-05-27: the NPE is BACK during BWO vehicle spawn. Stack
-- shows InstanceItem(Item.java:1849) -> setAlcoholPower on null item, called
-- from BaseVehicle.randomizeContainers via ItemPickerJava.tryAddItemToContainer.
-- Either a new mod installed since 5/24 (AE / Meowboid / CyberDog / Saph /
-- BWO / BWO-Bandits / Sims stack) reintroduced a broken item, or BWO's own
-- distribution references something that doesn't resolve. Run once, capture
-- the FAILED TO INSTANCE line(s), then flip back to false.
--
-- DISABLED AGAIN 2026-05-27 evening: scan ran, identified 48 broken items
-- all in `newcontainersnc.` namespace - the UNOFFICIAL Fools New Containers
-- B42 mod (foolcontainers42). Two root causes:
--   1. Case-sensitive ClothingItem lookup in newcontainers_clothing_bags.txt
--      (lowercase prefix references like `container_NC*` not matching
--      uppercase XML filenames). FIXED 2026-05-27 by capitalizing prefixes.
--   2. Items in newcontainers_items.txt fail despite correct case +
--      matching XMLs. Root cause UNKNOWN as of disabling. See
--      notes/FOOL_CONTAINERS_PATCH.md for investigation status.
-- Flip back to true if a NEW item-instance NPE surfaces from a different mod.
local DIAG_ENABLED = false

local function runDiag()
    if not DIAG_ENABLED then return end
    if KH._itemDiagDone then return end
    KH._itemDiagDone = true

    local sm = getScriptManager()
    if not sm or not sm.getAllItems then
        print("[KH][diag] getScriptManager():getAllItems unavailable")
        return
    end

    local items
    local ok = pcall(function() items = sm:getAllItems() end)
    if not ok or not items or not items.size then
        print("[KH][diag] could not enumerate script items")
        return
    end

    local total = items:size()
    local failures = 0
    print(string.format("[KH][diag] Testing instantiation of %d script items...", total))

    for i = 0, total - 1 do
        local scriptItem = items:get(i)
        if scriptItem then
            local fullType
            pcall(function()
                fullType = scriptItem:getFullName()  -- e.g. "Base.Whiskey"
            end)
            if fullType then
                -- instanceItem() is the Lua global that builds an InventoryItem
                -- from a type string. If the script item is malformed it'll
                -- throw (caught by pcall) or return nil.
                local instOk, inst = pcall(function() return instanceItem(fullType) end)
                if not instOk then
                    failures = failures + 1
                    print(string.format("[KH][diag] FAILED TO INSTANCE (threw): %s -> %s",
                        fullType, tostring(inst)))
                elseif inst == nil then
                    failures = failures + 1
                    print(string.format("[KH][diag] FAILED TO INSTANCE (nil): %s", fullType))
                end
            end
        end
    end

    print(string.format("[KH][diag] Done. %d/%d items failed to instance.", failures, total))
end

-- Run shortly after game start so the script manager is fully populated.
Events.OnGameStart.Add(function()
    -- Defer one tick via a flag so all item scripts (including mod overrides)
    -- have merged.
    runDiag()
end)

print("[KH] ItemSpawnDiag loaded (will scan item instantiation on game start)")
