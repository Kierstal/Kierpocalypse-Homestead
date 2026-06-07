-- Kierpocalyptic Homestead - Cat's Eyes loot bonus
--
-- "Cat's Eyes" is the EN UI name for the trait whose internal id is
-- "nightvision" (CharacterTrait.NIGHT_VISION). Lore: enhanced perception.
-- The character notices things tucked into the back of drawers, behind
-- boxes, under shelves - things less observant looters would walk past.
--
-- Per Kierstal's feedback 2026-05-30:
--   "The 'extra loot' bonus should be the same KIND of loot that already
--    shows up in that container, just more/better."
--
-- Bonus is two-pronged when this trait is active and a container fills:
--   1) QUALITY: existing items get a freshness/condition bump
--   2) AMOUNT:  per existing item, a chance to find ONE MORE of the same
--               kind already present in the container
--
-- Older versions used curated KH pools (kitchen/bathroom/garage/etc) which
-- could put nails in a fridge or jewelry in a tool shelf. The new approach
-- mirrors what's already there: a fridge full of food finds more food, a
-- tool shelf finds more tools, etc. No assumptions about room context.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.CatsEyesLoot = "0.1.0"

local BONUS_PCT = 10  -- chance per existing item, out of 100

local function rollHit() return ZombRand(100) < BONUS_PCT end

local function hasCatsEyes(player)
    if not player or not player.hasTrait then return false end
    -- B42 IsoPlayer.hasTrait() ONLY accepts a CharacterTrait enum value.
    -- The String overload doesn't exist; calling it raises a Java
    -- RuntimeException that pcall can't catch (it's at the JNI boundary
    -- before Lua sees it), spamming the error log on every container fill.
    if not (CharacterTrait and CharacterTrait.NIGHT_VISION) then return false end
    local ok, has = pcall(function() return player:hasTrait(CharacterTrait.NIGHT_VISION) end)
    return (ok and has) or false
end

local function freshenItem(item)
    if not item then return end
    if instanceof(item, "Food") then
        if item.setAge and item.getAge then
            pcall(function() item:setAge(item:getAge() * 0.5) end)
        end
    end
    if item.getCondition and item.getConditionMax and item.setCondition then
        pcall(function()
            local cur = item:getCondition()
            local max = item:getConditionMax()
            if cur < max then
                local bumped = cur + math.max(1, math.floor((max - cur) * 0.5))
                if bumped > max then bumped = max end
                item:setCondition(bumped)
            end
        end)
    end
end

-- Deferred AddItem queue. AddItem during OnFillContainer NPEs the
-- ItemPicker pipeline (callFrame is null because the caller frame hasn't
-- been set up for our reentrant call). Queue and drain on the next tick.
local _addQueue = {}
local function _enqueueAdd(container, fullType)
    if not container or not fullType then return end
    _addQueue[#_addQueue + 1] = { container = container, fullType = fullType }
end
local function _drainQueue()
    if #_addQueue == 0 then return end
    local batch = _addQueue
    _addQueue = {}
    for i = 1, #batch do
        local e = batch[i]
        if e and e.container and e.fullType then
            pcall(function()
                if e.container.AddItem then e.container:AddItem(e.fullType) end
            end)
        end
    end
end
Events.OnTick.Add(_drainQueue)

local function onFillContainer(roomName, containerType, container)
    local ok, err = pcall(function()
        local player = getPlayer()
        if not player or player:isDead() then return end
        if not hasCatsEyes(player) then return end
        if not container or not container.getItems then return end

        local items = container:getItems()
        if not items or items:size() == 0 then
            -- Empty container, nothing to mirror. Skip - if there's nothing
            -- there normally, perception can't make something appear.
            return
        end

        -- Snapshot existing items so we don't iterate while the underlying
        -- list could be re-entered by the ItemPicker.
        local snapshot = {}
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it then snapshot[#snapshot + 1] = it end
        end

        for _, it in ipairs(snapshot) do
            -- AMOUNT: chance to find one more of the same kind. We pick a
            -- random existing item from the snapshot rather than always
            -- duplicating THIS one, so a container with one banana and ten
            -- nails doesn't bias every roll to bananas - it reflects the
            -- container's actual contents proportionally.
            if rollHit() then
                local mirror = snapshot[ZombRand(#snapshot) + 1]
                local fullType
                pcall(function() fullType = mirror and mirror:getFullType() end)
                if fullType then _enqueueAdd(container, fullType) end
            end
            -- QUALITY: freshen the existing item in-place. This is safe
            -- to do synchronously - we're not allocating, just mutating.
            if rollHit() then
                freshenItem(it)
            end
        end
    end)
    if not ok then
        print("[KH] CatsEyesLoot onFillContainer error (suppressed): " .. tostring(err))
    end
end

Events.OnFillContainer.Add(onFillContainer)
