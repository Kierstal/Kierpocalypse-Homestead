-- Kierpocalyptic Homestead - Break Branches
--
-- Right-click any IsoTree -> "Break Branches". Walks player adjacent, plays
-- a loot animation, gives 1-3 random items from a tree-debris pool, and
-- starts a per-tree cooldown stored in the tree's modData.
--
-- Loot is a weighted pool of vanilla items that logically come off a tree:
-- Twigs (most common), WoodenStick2 (sticks), TreeBranch2 (big branch, rarer),
-- Sapling (rare), Acorn (if tree's sprite hints "oak"), MapleSyrup (if "maple").
--
-- Cooldown: 12 in-game hours per individual tree. The cooldown lives in the
-- tree's modData so it persists across reloads.

require "ISUI/ISWorldObjectContextMenu"
require "TimedActions/ISBaseTimedAction"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.BreakBranches = "0.0.1"

local COOLDOWN_HOURS = 12
local ACTION_TICKS   = 80

-- Generic tree-debris pool. Weight = relative likelihood. nil = nothing this roll.
local DEFAULT_POOL = {
    {id = "Base.Twigs",         weight = 12},
    {id = "Base.WoodenStick2",  weight = 8},
    {id = "Base.TreeBranch2",   weight = 3},
    {id = "Base.Sapling",       weight = 1},
    {id = nil,                  weight = 3},  -- sometimes you just bruise your hand
}

-- Sprite hint -> bonus item. Pulls one item if the tree's sprite name contains
-- the substring (case-insensitive). Independent of the main pool roll.
local SPRITE_BONUS = {
    {needle = "oak",     id = "Base.Acorn",      weight = 5 },
    {needle = "maple",   id = "Base.MapleSyrup", weight = 1 },
    -- Additions she can fill in over time:
    -- {needle = "pine",    id = "Base.PineCone",   weight = 4 },  -- doesn't exist in vanilla yet
}

local function nowHours()
    local gt = getGameTime()
    if not gt then return 0 end
    return gt:getWorldAgeHours() or 0
end

local function getSpriteName(obj)
    if not obj or not obj.getSprite then return "" end
    local s = obj:getSprite()
    if not s or not s.getName then return "" end
    return s:getName() or ""
end

local function getCooldownLeft(treeObj)
    local md = treeObj.getModData and treeObj:getModData()
    if not md then return 0 end
    local last = md.KH_lastBranchBreak or -1e9
    local left = (last + COOLDOWN_HOURS) - nowHours()
    if left < 0 then left = 0 end
    return left
end

local function setBroken(treeObj)
    local md = treeObj.getModData and treeObj:getModData()
    if md then md.KH_lastBranchBreak = nowHours() end
end

local function pickFromPool(pool)
    if not pool or #pool == 0 then return nil end
    local total = 0
    for _, e in ipairs(pool) do total = total + (e.weight or 1) end
    if total <= 0 then return nil end
    local roll = ZombRand(total)
    local cum = 0
    for _, e in ipairs(pool) do
        cum = cum + (e.weight or 1)
        if roll < cum then return e.id end
    end
    return nil
end

local function rollSpriteBonus(spriteName)
    local lower = string.lower(spriteName or "")
    for _, b in ipairs(SPRITE_BONUS) do
        if string.find(lower, b.needle, 1, true) then
            if ZombRand(b.weight + 4) < b.weight then  -- rough weight-as-chance
                return b.id
            end
        end
    end
    return nil
end

-------------------------------------------------------------------
-- Timed action
-------------------------------------------------------------------
local KH_BreakBranchesAction = ISBaseTimedAction:derive("KH_BreakBranchesAction")

function KH_BreakBranchesAction:isValid()
    if not self.treeObj then return false end
    if not (self.treeObj.getSquare and self.treeObj:getSquare()) then return false end
    if getCooldownLeft(self.treeObj) > 0 then return false end
    return true
end

function KH_BreakBranchesAction:update()
    if self.treeObj and self.treeObj.getSquare and self.treeObj:getSquare() then
        local sq = self.treeObj:getSquare()
        self.character:faceLocation(sq:getX(), sq:getY())
    end
end

function KH_BreakBranchesAction:start()
    if self.setActionAnim then self:setActionAnim("Loot") end
end

function KH_BreakBranchesAction:perform()
    local tree = self.treeObj
    local spriteName = getSpriteName(tree)

    -- 1-3 main rolls
    local rolls = 1 + ZombRand(3)  -- 1, 2, or 3
    local inv = self.character and self.character:getInventory()
    if inv then
        for _ = 1, rolls do
            local id = pickFromPool(DEFAULT_POOL)
            if id then pcall(function() inv:AddItem(id) end) end
        end
        -- Sprite-specific bonus (chance per matching tree)
        local bonusId = rollSpriteBonus(spriteName)
        if bonusId then pcall(function() inv:AddItem(bonusId) end) end
    end

    setBroken(tree)
    ISBaseTimedAction.perform(self)
end

function KH_BreakBranchesAction:new(character, treeObj)
    local o = ISBaseTimedAction.new(self, character)
    o.treeObj    = treeObj
    o.maxTime    = ACTION_TICKS
    o.stopOnWalk = true
    o.stopOnRun  = true
    return o
end

-------------------------------------------------------------------
-- Context menu wiring
-------------------------------------------------------------------
local function onBreakBranchesClicked(worldobjects, playerArg, treeObj)
    local character
    if type(playerArg) == "number" then character = getSpecificPlayer(playerArg)
    elseif playerArg and playerArg.getInventory then character = playerArg
    else character = getPlayer() end
    if not character or not treeObj then return end
    local sq = treeObj.getSquare and treeObj:getSquare()
    if not sq then return end
    if luautils and luautils.walkAdj then
        if not luautils.walkAdj(character, sq, true) then return end
    end
    ISTimedActionQueue.add(KH_BreakBranchesAction:new(character, treeObj))
end

local function onFillContextMenu(playerArg, context, worldobjects, test)
    if test then return end
    if not worldobjects then return end

    -- In B42 trees are NOT in worldobjects directly. They live as a separate
    -- property on each IsoGridSquare, accessed via square:getTree(). So we
    -- collect unique squares from worldobjects and query getTree() on each.
    local seenSquares = {}
    local seenTrees = {}

    -- Also catch case where IsoTree IS in worldobjects (some maps/mods do this)
    for _, obj in ipairs(worldobjects) do
        if obj then
            -- Direct IsoTree
            if not seenTrees[obj] and instanceof(obj, "IsoTree") then
                seenTrees[obj] = true
            end
            -- Square lookup
            local sq = obj.getSquare and obj:getSquare()
            if sq and not seenSquares[sq] then
                seenSquares[sq] = true
                local tree = sq.getTree and sq:getTree()
                if tree and not seenTrees[tree] then
                    seenTrees[tree] = true
                end
            end
        end
    end

    for tree, _ in pairs(seenTrees) do
        local cd = getCooldownLeft(tree)
        local label
        if cd > 0 then
            local hours = math.ceil(cd)
            label = string.format("%s (recovering, %dh)",
                getText("ContextMenu_KH_BreakBranches") or "Break Branches", hours)
            local opt = context:addOption(label, worldobjects, function() end)
            if opt and opt.notAvailable ~= nil then opt.notAvailable = true end
        else
            label = getText("ContextMenu_KH_BreakBranches") or "Break Branches"
            context:addOption(label, worldobjects, onBreakBranchesClicked, playerArg, tree)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)
