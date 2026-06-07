-- Kierpocalyptic Homestead - Vending machines require money to loot.
--
-- Pre-apocalypse path: pay Base.Money per item taken. Without money,
-- the inventory-transfer action is blocked at isValid time.
-- Post-apocalypse path: KH_VendingForceOpen.lua sets KH_forcedOpen=true
-- on the container's modData. Forced-open vending machines transfer
-- freely (no money consumed), since you've already paid in zombie-attractor
-- noise + tool wear + random item breakage.
--
-- Detection: vanilla container types vendingpop / vendingsnack. We also
-- keep "vendingGt" and a defensive "vending" catch-all in case sprite
-- packs route to other variants.

require "TimedActions/ISInventoryTransferAction"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.VendingMoney = "0.0.2"

local VENDING_TYPES = {
    vendingpop   = true,
    vendingsnack = true,
    vendingGt    = true,
    vending      = true,  -- defensive catch-all
}

local function isVendingContainer(container)
    if not container or not container.getType then return false end
    local t = container:getType()
    return t and VENDING_TYPES[t] == true
end

local function isForcedOpen(container)
    if not container or not container.getModData then return false end
    local ok, md = pcall(function() return container:getModData() end)
    if not ok or not md then return false end
    return md.KH_forcedOpen == true
end

local function findMoneyItem(character)
    if not character or not character:getInventory() then return nil end
    return character:getInventory():FindAndReturn("Money")
end

-- Pre-emptive block: if action sources from a vending machine that is
-- NOT forced open AND the player has no money, the action is invalid.
local original_isValid = ISInventoryTransferAction.isValid
function ISInventoryTransferAction:isValid()
    if not original_isValid(self) then return false end
    if isVendingContainer(self.srcContainer) and not isForcedOpen(self.srcContainer) then
        if not findMoneyItem(self.character) then return false end
    end
    return true
end

-- Consume 1 Money on successful perform (only if NOT forced open).
local original_perform = ISInventoryTransferAction.perform
function ISInventoryTransferAction:perform()
    if isVendingContainer(self.srcContainer) and not isForcedOpen(self.srcContainer) then
        local money = findMoneyItem(self.character)
        if money then
            self.character:getInventory():Remove(money)
        end
    end
    original_perform(self)
end

print("[KH] Vending money-gate v" .. KH.modules.VendingMoney .. " active (forced-open containers bypass)")
