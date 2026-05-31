-- Kierpocalyptic Homestead - Cat's Eyes loot bonus
--
-- "Cat's Eyes" is the EN UI name for the trait whose internal id is
-- "nightvision" (CharacterTrait.NIGHT_VISION). Lore: enhanced perception.
-- The character notices small valuable things tucked into the back of
-- drawers, behind boxes, under shelves - things less observant looters
-- would walk past.
--
-- Bonus is THREE-pronged when this trait is active and a container fills:
--   1) QUALITY: existing items get a freshness/condition bump
--   2) AMOUNT:  per existing item, a chance to spawn ONE extra item from a
--              curated "perception finds" pool biased by room/container
--   3) RARITY: the perception pool is weighted toward useful-but-easily-
--              missed items (batteries, ammo, sewing kit bits, medicine,
--              spices, small tools), not bulk loot
--
-- v0.0.2 - replaced "spawn a duplicate" with the perception pool above.
-- v0.0.3 - keep the OnTick-deferred AddItem queue from v0.0.2's bugfix:
--          AddItem inside OnFillContainer NPEs the ItemPicker pipeline.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.CatsEyesLoot = "0.0.3"

local BONUS_PCT = 10  -- chance per existing item, out of 100

local function rollHit() return ZombRand(100) < BONUS_PCT end

local function hasCatsEyes(player)
    if not player or not player.hasTrait then return false end
    -- B42 IsoPlayer.hasTrait() ONLY accepts a CharacterTrait enum value.
    -- The String overload doesn't exist; calling it raises a Java
    -- RuntimeException that pcall can't catch (it's at the JNI boundary
    -- before Lua sees it), spamming the error log on every container fill.
    -- So only probe via the enum, and if the enum isn't loaded yet, return
    -- false defensively rather than risking a string call.
    if not (CharacterTrait and CharacterTrait.NIGHT_VISION) then return false end
    local ok, has = pcall(function() return player:hasTrait(CharacterTrait.NIGHT_VISION) end)
    return (ok and has) or false
end

-- -----------------------------------------------------------------
-- Perception loot pools. Each entry is a Base.* itemId. Pools mix in
-- some "rare-ish but useful" items at lower weight (just listed more
-- copies of common ones, fewer copies of rare ones, then ZombRand
-- across the whole list). All items verified against vanilla B42
-- scripts/generated/items/*.txt.
-- -----------------------------------------------------------------
-- All item IDs verified against B42 vanilla scripts/generated/items/*.txt
-- as of 42.18. If you reorder these, keep weights in mind: duplicates ==
-- higher pick probability under ZombRand. Common items appear 2-3 times,
-- rarer ones once.
local POOL_GENERAL = {
    -- Common-but-useful
    "Battery","Battery","Battery",
    "Nails","Nails","Screws","Screws",
    "RippedSheets","RippedSheets",
    "Tweezers","DuctTape",
    -- Less common
    "Lighter","Matches",
    "Needle","Thread","SewingKit",
    -- Rarer
    "Bandage","SheetRope",
}

local POOL_KITCHEN = {
    "Salt","Salt","Pepper","Pepper","Sugar","Sugar",
    "PepperHabanero","Peppermint",
    "KitchenKnife","KnifeParing",
    "Pan","Pot",
    -- Small-but-good food
    "TinnedSoup","TunaTin","CannedSardines",
    "CookiesChocolate","CookiesOatmeal","CookieJar",
    "Chocolate","CandyPackage","CandyCorn",
    "Coffee2","Teabag2",
    -- Practical
    "Bowl","Plate","Fork","Knife","Spoon",
    "Matches","Lighter",
}

local POOL_BATHROOM = {
    -- Small medical + hygiene
    "Pills","Pills","PillsAntiDep","PillsBeta","PillsSleepingTablets",
    "Bandage","Bandage","Bandaid","Antibiotics",
    "Soap2","Soap2","Toothbrush","Toothpaste","Razor",
    "Tweezers","CottonBalls","Disinfectant",
}

local POOL_BEDROOM = {
    "NecklaceLong_Gold","NecklaceLong_Silver",
    "Earring_LoopMed_Silver","Earring_LoopMed_Gold",
    "Pen","Pencil","Notebook","Photo",
    "Money","Money","CreditCard","MoneyBundle",
    "Lighter","CigarettePack",
    "Earbuds","WaterBottle",
    "Tissue","Tissue",
}

local POOL_GARAGE = {
    "Battery","Battery","Battery",
    "Screwdriver","Hammer","Pliers","Wrench",
    "Nails","Nails","Screws","Screws","Wire",
    "DuctTape","DuctTape",
    "LightBulb","LightBulb",
    "Glue",
    "Lighter","Matches",
}

local POOL_OFFICE = {
    "Pen","Pencil","Pencil","Notebook","Notebook",
    "Magazine","Newspaper",
    "Money","Money","CreditCard",
    "Stapler","Paperclip","Photo",
    "Disc_Retail",
}

local POOL_MEDICAL = {
    "Bandage","Bandage","Bandage",
    "Antibiotics","Antibiotics",
    "Pills","PillsAntiDep","PillsBeta","PillsSleepingTablets","PillsVitamins",
    "Disinfectant","Disinfectant",
    "SutureNeedle","SutureNeedleHolder","Tweezers","Scalpel",
    "CottonBalls","Splint",
}

local function pickPool(roomName, containerType)
    local r = string.lower(tostring(roomName or ""))
    local c = string.lower(tostring(containerType or ""))
    -- Specific room match wins
    if string.find(r, "kitchen", 1, true) or string.find(c, "fridge", 1, true) or string.find(c, "stove", 1, true) then
        return POOL_KITCHEN
    end
    if string.find(r, "bath", 1, true) then return POOL_BATHROOM end
    if string.find(r, "bedroom", 1, true) or string.find(r, "bed", 1, true) then return POOL_BEDROOM end
    if string.find(r, "garage", 1, true) or string.find(r, "shed", 1, true) or string.find(r, "tool", 1, true) then
        return POOL_GARAGE
    end
    if string.find(r, "office", 1, true) or string.find(r, "library", 1, true) or string.find(r, "school", 1, true) then
        return POOL_OFFICE
    end
    if string.find(r, "hospital", 1, true) or string.find(r, "medic", 1, true) or string.find(r, "pharm", 1, true) then
        return POOL_MEDICAL
    end
    return POOL_GENERAL
end

local function pickFromPool(pool)
    if not pool or #pool == 0 then return nil end
    return pool[ZombRand(#pool) + 1]
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

local function _fullId(itemId)
    if not itemId then return nil end
    if string.find(itemId, ".", 1, true) then return itemId end
    return "Base." .. itemId
end

local function onFillContainer(roomName, containerType, container)
    local ok, err = pcall(function()
        local player = getPlayer()
        if not player or player:isDead() then return end
        if not hasCatsEyes(player) then return end
        if not container or not container.getItems then return end

        local items = container:getItems()
        if not items or items:size() == 0 then return end

        local pool = pickPool(roomName, containerType)

        -- Snapshot existing items so we don't iterate while the underlying
        -- list could be re-entered by the ItemPicker.
        local snapshot = {}
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it then snapshot[#snapshot + 1] = it end
        end

        for _, it in ipairs(snapshot) do
            -- AMOUNT + RARITY: chance to drop a perception-pool find.
            if rollHit() then
                local pick = pickFromPool(pool)
                local fullId = _fullId(pick)
                if fullId then _enqueueAdd(container, fullId) end
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
