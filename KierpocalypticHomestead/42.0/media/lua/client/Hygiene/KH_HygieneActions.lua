-- Kierpocalyptic Homestead - junk-item hygiene actions
--
-- Lua-driven repurposing of vanilla "junk" items per the audit:
--   * Toothbrush + Toothpaste -> "Brush teeth" right-click action.
--     Reduces bath need by a small amount + small unhappiness relief +
--     emits hygiene/brushedTeeth thought line.
--     Toothpaste is a Drainable in spirit but vanilla ships it as plain
--     Normal with no Uses tracking. We deplete a single charge per use
--     by consuming the toothpaste only on every 8th brush (rough analog
--     of a full tube's worth of brushings). Toothbrush is reusable.
--
--   * Deodorant ("Hairgel"-style if vanilla deodorant doesn't exist by
--     name yet -- see TODO) -> apply: mask bath need (doesn't actually
--     clean, but suppresses thought-line emissions for 4 game hours).
--
-- Pattern: hook into ISInventoryPaneContextMenu.doInventoryItem to add
-- options when the relevant item is right-clicked in inventory.

require "TimedActions/ISBaseTimedAction"
require "Needs/KH_NeedsCore"
require "Thoughts/KH_Thoughts"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.HygieneActions = "0.0.1"

-- ----------------------------------------------------------------
-- Brush Teeth
-- ----------------------------------------------------------------

KH_BrushTeethAction = ISBaseTimedAction:derive("KH_BrushTeethAction")

function KH_BrushTeethAction:isValid()
    return self.character ~= nil
end

function KH_BrushTeethAction:start()
    self:setActionAnim("WashFace")
end

function KH_BrushTeethAction:perform()
    local p = self.character
    if not p then ISBaseTimedAction.perform(self); return end
    -- Effects
    local stats = p:getStats()
    if stats and CharacterStat and CharacterStat.UNHAPPINESS then
        local u = stats:get(CharacterStat.UNHAPPINESS) or 0
        stats:set(CharacterStat.UNHAPPINESS, math.max(0, u - 4))
    end
    -- Modest bath-need reduction (you're cleaner than before, not bathed)
    if KH.Bath and KH.Bath.get and KH.Bath.set then
        local cur = KH.Bath.get(p)
        KH.Bath.set(p, math.max(0, cur - 3))
    end
    -- Consume a paste charge -- track in player modData so we don't burn
    -- a full tube per brush. Tube lasts ~8 uses.
    local d = p:getModData()
    d.KH_toothpasteUses = (d.KH_toothpasteUses or 0) + 1
    if d.KH_toothpasteUses >= 8 then
        d.KH_toothpasteUses = 0
        local inv = p:getInventory()
        if inv and self.toothpaste then
            pcall(function() inv:Remove(self.toothpaste) end)
        end
    end
    KH.Thoughts.emit(p, "hygiene", "brushedTeeth")
    ISBaseTimedAction.perform(self)
end

function KH_BrushTeethAction:new(character, toothbrush, toothpaste)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.toothbrush = toothbrush
    o.toothpaste = toothpaste
    o.maxTime = 70
    o.stopOnWalk = true
    return o
end

-- ----------------------------------------------------------------
-- Apply Deodorant (mask bath-need thought lines for 4 hours)
-- ----------------------------------------------------------------

KH_ApplyDeodorantAction = ISBaseTimedAction:derive("KH_ApplyDeodorantAction")

function KH_ApplyDeodorantAction:isValid()
    return self.character ~= nil and self.deodorant ~= nil
end

function KH_ApplyDeodorantAction:start()
    self:setActionAnim("Loot")
end

function KH_ApplyDeodorantAction:perform()
    local p = self.character
    if p then
        local d = p:getModData()
        local nowH = getGameTime() and getGameTime():getWorldAgeHours() or 0
        d.KH_deodorantUntilHours = nowH + 4
        -- small unhappiness relief
        local stats = p:getStats()
        if stats and CharacterStat and CharacterStat.UNHAPPINESS then
            local u = stats:get(CharacterStat.UNHAPPINESS) or 0
            stats:set(CharacterStat.UNHAPPINESS, math.max(0, u - 2))
        end
        KH.Thoughts.emit(p, "hygiene", "deodorant")
    end
    -- Deodorant is a Drainable; reduce its uses by 1 if exposed
    if self.deodorant and self.deodorant.UseAndSync then
        pcall(function() self.deodorant:UseAndSync() end)
    end
    ISBaseTimedAction.perform(self)
end

function KH_ApplyDeodorantAction:new(character, deodorant)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.deodorant = deodorant
    o.maxTime = 40
    o.stopOnWalk = true
    return o
end

-- Public API for KH_BathNeed to consult deodorant mask
KH.Hygiene = KH.Hygiene or {}
function KH.Hygiene.isMasked(player)
    if not player then return false end
    local d = player:getModData()
    local nowH = getGameTime() and getGameTime():getWorldAgeHours() or 0
    return (d.KH_deodorantUntilHours or 0) > nowH
end

-- ----------------------------------------------------------------
-- Context-menu integration (inventory right-click)
-- ----------------------------------------------------------------

local function onBrushTeethClicked(worldobjects, playerArg, brush, paste)
    local character = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or (playerArg and playerArg.getInventory and playerArg) or getPlayer()
    if not character then return end
    ISTimedActionQueue.add(KH_BrushTeethAction:new(character, brush, paste))
end

local function onDeodorantClicked(worldobjects, playerArg, deodorant)
    local character = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or (playerArg and playerArg.getInventory and playerArg) or getPlayer()
    if not character then return end
    ISTimedActionQueue.add(KH_ApplyDeodorantAction:new(character, deodorant))
end

local function onFillInventoryContext(playerIndex, context, items)
    local character = getSpecificPlayer(playerIndex)
    if not character then return end
    local inv = character:getInventory()
    if not inv then return end
    -- Brush teeth requires both a toothbrush AND toothpaste in inventory
    local brush = nil
    local paste = nil
    for _, it in ipairs(items or {}) do
        local item = it
        if type(it) == "table" and it.items and it.items[1] then item = it.items[1] end
        if item and item.getType then
            local ft = item:getType()
            if ft == "Toothbrush" then brush = item end
            if ft == "Toothpaste" then paste = item end
        end
    end
    -- Fallback: search inventory directly
    if not brush then
        local ok, it = pcall(function() return inv:getItemFromType("Toothbrush") end)
        if ok then brush = it end
    end
    if not paste then
        local ok, it = pcall(function() return inv:getItemFromType("Toothpaste") end)
        if ok then paste = it end
    end
    if brush and paste then
        local label = (getText and getText("ContextMenu_KH_BrushTeeth")) or "Brush teeth"
        context:addOption(label, nil, onBrushTeethClicked, playerIndex, brush, paste)
    end

    -- Deodorant: search for any of the known deodorant item types
    local deodorant = nil
    for _, t in ipairs({ "Deodorant", "Hairspray", "Hairgel" }) do
        if not deodorant then
            local ok, it = pcall(function() return inv:getItemFromType(t) end)
            if ok and it then deodorant = it end
        end
    end
    if deodorant then
        local label = (getText and getText("ContextMenu_KH_ApplyDeodorant")) or "Apply deodorant"
        context:addOption(label, nil, onDeodorantClicked, playerIndex, deodorant)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryContext)

print("[KH] Hygiene actions (brush teeth, deodorant) registered")
