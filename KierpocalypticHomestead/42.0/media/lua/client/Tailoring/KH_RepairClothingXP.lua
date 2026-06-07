-- Kierpocalyptic Homestead - Repair Clothing XP boost
--
-- Vanilla ISRepairClothing:complete() awards Perks.Tailoring:2 per patch.
-- Patching is the most natural early-game tailoring action and the reward
-- is comically small. We add a +3 bonus on the back of the vanilla call
-- so the effective reward is 5 XP per patch (without replacing vanilla).
--
-- Same for ISRemovePatch which awards 2 XP on patch removal. We bump
-- removal by +1 (total 3) since removing is less "skill expression" than
-- placing the patch.
--
-- Wrapping rather than replacing keeps us forward-compatible: if a future
-- B42 patch changes the vanilla XP value, our bonus stacks on top instead
-- of locking us to a stale number.

require "TimedActions/ISRepairClothing"
require "TimedActions/ISRemovePatch"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.RepairClothingXP = "0.0.1"

local KH_REPAIR_BONUS = 3
local KH_REMOVE_BONUS = 1

-- Wrap ISRepairClothing:complete -- vanilla adds 2 XP at the end; we add 3 more.
local _orig_repair_complete = ISRepairClothing.complete
function ISRepairClothing:complete()
    local result = _orig_repair_complete(self)
    if result and self.character and Perks and Perks.Tailoring then
        local ok = pcall(function()
            addXp(self.character, Perks.Tailoring, KH_REPAIR_BONUS)
        end)
        if not ok then
            print("[KH] RepairClothingXP: addXp failed (bonus on patch place)")
        end
    end
    return result
end

-- Wrap ISRemovePatch:complete -- vanilla awards 2 XP. +1 bonus -> 3 total.
local _orig_remove_complete = ISRemovePatch.complete
function ISRemovePatch:complete()
    local result = _orig_remove_complete(self)
    if result and self.character and Perks and Perks.Tailoring then
        local ok = pcall(function()
            addXp(self.character, Perks.Tailoring, KH_REMOVE_BONUS)
        end)
        if not ok then
            print("[KH] RepairClothingXP: addXp failed (bonus on patch remove)")
        end
    end
    return result
end

print("[KH] Repair Clothing XP bonuses hooked: repair +" .. KH_REPAIR_BONUS .. ", remove +" .. KH_REMOVE_BONUS)
