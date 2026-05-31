-- Kierpocalyptic Homestead - Force-open a vending machine
--
-- Companion to KH_VendingMoney.lua. Coins-and-courtesy is the
-- pre-apocalypse path; this is the apocalyptic path:
--
--   Right-click a vending machine -> "Force open vending"
--   Requires: a crowbar in primary/secondary hand OR any blunt weapon
--             with reasonable door damage.
--   Effect:  ~100-tick timed action, plays a metal-bash sound, emits a
--            world-sound (zombie attractor radius ~25), marks the
--            container's modData KH_forcedOpen=true so the money-gate
--            in KH_VendingMoney lets transfers through without coins.
--            30% chance to break a random item inside (sets its
--            condition to 0 or removes it if non-condition).
--
-- Identification: prefer container.type (vendingpop/vendingsnack), fall
-- back to sprite property CustomName ("Soda Machine", "Snack Machine").
-- The container-type path is what vanilla shipped; the property path is
-- a defensive catch for B42 sprite-prop-keyed checks.

require "TimedActions/ISBaseTimedAction"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.VendingForceOpen = "0.0.1"

local FORCE_TICKS_BASE = 100
local NOISE_RADIUS = 25
local NOISE_VOLUME = 18
local BREAK_ITEM_CHANCE = 30  -- percent

local VENDING_CONTAINER_TYPES = {
    vendingpop   = true,
    vendingsnack = true,
    vendingGt    = true,
    vending      = true,
}

local VENDING_CUSTOM_NAMES = {
    ["soda machine"]    = true,
    ["snack machine"]   = true,
    ["popcorn machine"] = true,  -- popcorn machines also count for KH spirit
    ["vending machine"] = true,
}

-- ---- Identification ----------------------------------------------

local function spriteCustomName(obj)
    if not obj then return nil end
    local sprite = obj.getSprite and obj:getSprite()
    if not sprite or not sprite.getProperties then return nil end
    local ok, props = pcall(function() return sprite:getProperties() end)
    if not ok or not props then return nil end
    local cn = nil
    pcall(function()
        if props.Val then cn = props:Val("CustomName") end
        if not cn and props.getString then cn = props:getString("CustomName") end
    end)
    return cn and tostring(cn) or nil
end

local function isVendingObject(obj)
    if not obj then return false end
    -- Container-type path (most reliable for vanilla)
    if obj.getContainer then
        local c = obj:getContainer()
        if c and c.getType then
            local t = c:getType()
            if t and VENDING_CONTAINER_TYPES[t] then return true end
        end
    end
    -- Multi-container objects (B42 split machines)
    if obj.getContainerCount then
        local n = 0
        pcall(function() n = obj:getContainerCount() or 0 end)
        for i = 0, n - 1 do
            local c = obj.getContainerByIndex and obj:getContainerByIndex(i)
            if c and c.getType then
                local t = c:getType()
                if t and VENDING_CONTAINER_TYPES[t] then return true end
            end
        end
    end
    -- Sprite property fallback
    local cn = spriteCustomName(obj)
    if cn and VENDING_CUSTOM_NAMES[string.lower(cn)] then return true end
    return false
end

local function getVendingContainers(obj)
    local out = {}
    if not obj then return out end
    if obj.getContainer then
        local c = obj:getContainer()
        if c then table.insert(out, c) end
    end
    if obj.getContainerCount then
        local n = 0
        pcall(function() n = obj:getContainerCount() or 0 end)
        for i = 0, n - 1 do
            local c = obj.getContainerByIndex and obj:getContainerByIndex(i)
            if c then table.insert(out, c) end
        end
    end
    return out
end

-- ---- Tool check --------------------------------------------------

local function findForceTool(character)
    if not character or not character.getInventory then return nil, nil end
    -- Prefer crowbar (clean prying)
    local prim = character.getPrimaryHandItem and character:getPrimaryHandItem()
    if prim and prim.getType and prim:getType() == "Crowbar" then return prim, "crowbar" end
    local sec = character.getSecondaryHandItem and character:getSecondaryHandItem()
    if sec and sec.getType and sec:getType() == "Crowbar" then return sec, "crowbar" end
    local inv = character:getInventory()
    if inv and inv.getItemFromType then
        local ok, it = pcall(function() return inv:getItemFromType("Crowbar") end)
        if ok and it then return it, "crowbar" end
    end
    -- Fall back: any blunt weapon with DoorDamage. Check primary first.
    local function hasDoorDamage(it)
        if not it or not it.getDoorDamage then return false end
        local dd = 0
        pcall(function() dd = it:getDoorDamage() or 0 end)
        return dd >= 2
    end
    if hasDoorDamage(prim) then return prim, "blunt" end
    if hasDoorDamage(sec) then return sec, "blunt" end
    return nil, nil
end

-- ---- Action ------------------------------------------------------

KH_VendingForceOpenAction = ISBaseTimedAction:derive("KH_VendingForceOpenAction")

function KH_VendingForceOpenAction:isValid()
    if not self.target or not self.target.getSquare or not self.target:getSquare() then return false end
    local tool = findForceTool(self.character)
    return tool ~= nil
end

function KH_VendingForceOpenAction:update()
    if self.target and self.target.getSquare and self.target:getSquare() then
        local sq = self.target:getSquare()
        self.character:faceLocation(sq:getX(), sq:getY())
    end
end

function KH_VendingForceOpenAction:start()
    self:setActionAnim("Loot")
    -- Bash sound while working
    if self.character.getEmitter then
        pcall(function() self.sound = self.character:getEmitter():playSound("Hammering") end)
    end
end

function KH_VendingForceOpenAction:stop()
    if self.sound and self.character.getEmitter then
        pcall(function()
            if self.character:getEmitter():isPlaying(self.sound) then
                self.character:stopOrTriggerSound(self.sound)
            end
        end)
    end
    ISBaseTimedAction.stop(self)
end

function KH_VendingForceOpenAction:perform()
    local p = self.character
    -- Stop the bash sound
    if self.sound and p.getEmitter then
        pcall(function()
            if p:getEmitter():isPlaying(self.sound) then
                p:stopOrTriggerSound(self.sound)
            end
        end)
    end
    -- World sound to attract zombies. addWorldSound(source, radius, volume)
    local sq = self.target.getSquare and self.target:getSquare()
    if sq and addSound then
        pcall(function() addSound(p, sq:getX(), sq:getY(), sq:getZ(), NOISE_RADIUS, NOISE_VOLUME) end)
    end
    -- Damage the prying tool a bit
    local tool = findForceTool(p)
    if tool and tool.setCondition and tool.getCondition then
        if ZombRand(4) == 0 then
            local c = tool:getCondition() or 0
            if c > 0 then pcall(function() tool:setCondition(c - 1) end) end
        end
    end
    -- Mark every vending container on this object as "forced open"
    local containers = getVendingContainers(self.target)
    for _, c in ipairs(containers) do
        local md = c.getModData and c:getModData()
        if md then md.KH_forcedOpen = true end
    end
    -- 30% chance: break a random item in one of the containers (set
    -- condition to 0 if the item has condition; otherwise remove it).
    if ZombRand(100) < BREAK_ITEM_CHANCE then
        for _, c in ipairs(containers) do
            local items = c.getItems and c:getItems()
            if items and items.size and items:size() > 0 then
                local idx = ZombRand(items:size())
                local victim = items:get(idx)
                if victim then
                    if victim.setCondition and victim.getConditionMax and (victim:getConditionMax() or 0) > 0 then
                        pcall(function() victim:setCondition(0) end)
                    else
                        pcall(function() c:Remove(victim) end)
                    end
                    break
                end
            end
        end
    end
    -- Open the loot panel by triggering vanilla container-click
    -- (best-effort; player can right-click again themselves either way)
    ISBaseTimedAction.perform(self)
end

function KH_VendingForceOpenAction:new(character, target)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.target = target
    -- Carpentry / Strength scale the action time
    local time = FORCE_TICKS_BASE
    if Perks and Perks.Strength and character.getPerkLevel then
        local str = character:getPerkLevel(Perks.Strength) or 0
        time = time - (str * 4)
    end
    if time < 40 then time = 40 end
    o.maxTime = time
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

-- ---- Context-menu wiring -----------------------------------------

local function onForceOpenClicked(worldobjects, playerArg, target)
    local character = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or (playerArg and playerArg.getInventory and playerArg) or getPlayer()
    if not character or not target then return end
    local sq = target.getSquare and target:getSquare()
    if sq and luautils and luautils.walkAdj then
        if not luautils.walkAdj(character, sq, true) then return end
    end
    ISTimedActionQueue.add(KH_VendingForceOpenAction:new(character, target))
end

local function onFillContext(playerArg, context, worldobjects, test)
    if test then return end
    if not worldobjects then return end
    local character = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    if not character then return end
    local tool, kind = findForceTool(character)
    if not tool then return end  -- no tool, no option
    local seen = {}
    for _, obj in ipairs(worldobjects) do
        if obj and isVendingObject(obj) and not seen[obj] then
            seen[obj] = true
            local label = (getText and getText("ContextMenu_KH_ForceOpenVending")) or "Force open vending"
            context:addOption(label, worldobjects, onForceOpenClicked, playerArg, obj)
            break
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContext)

print("[KH] Vending force-open action registered")
