-- Kierpocalyptic Homestead - Use Toilet timed action
--
-- New ISBaseTimedAction. Wired via OnFillWorldObjectContextMenu when the
-- player right-clicks a toilet world object (sprite name matches "toilet").
--
-- Reuses the "Rest" sit-on-furniture pattern from ISRestAction where the
-- engine allows. If furnitureHasSittingData(toilet) returns false at
-- runtime, falls back to a non-sitting timed action that just plays the
-- Rest body anim without spatial anchoring (intentional graceful
-- degradation -- see TOILET_BATH_SCOPE.md).

require "TimedActions/ISBaseTimedAction"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.UseToiletAction = "0.0.2"

local PERFORM_TICKS = 80

KH_UseToiletAction = ISBaseTimedAction:derive("KH_UseToiletAction")

function KH_UseToiletAction:isValid()
    return self.toilet and self.toilet.getSquare and self.toilet:getSquare() ~= nil
end

function KH_UseToiletAction:update()
    if self.toilet and self.toilet.getSquare and self.toilet:getSquare() then
        local sq = self.toilet:getSquare()
        self.character:faceLocation(sq:getX(), sq:getY())
    end
end

function KH_UseToiletAction:start()
    -- Try the sit-on-furniture engine path. If the toilet object lacks
    -- sitting data, we still play the Rest animation but without anchoring.
    local hasSitting = false
    if self.character.furnitureHasSittingData then
        local ok, res = pcall(function() return self.character:furnitureHasSittingData(self.toilet) end)
        if ok then hasSitting = res end
    end
    if hasSitting and self.toilet.setSatChair then
        pcall(function()
            self.toilet:setSatChair(true)
            self.character:setSitOnFurnitureObject(self.toilet)
            self.character:reportEvent("EventSitOnFurniture")
        end)
        self.satOnFurniture = true
    end
    -- Play the rest anim regardless
    self:setActionAnim("Rest")
end

function KH_UseToiletAction:stop()
    if self.satOnFurniture and self.toilet and self.toilet.setSatChair then
        pcall(function() self.toilet:setSatChair(false) end)
        if self.character and self.character.setSitOnFurnitureObject then
            pcall(function() self.character:setSitOnFurnitureObject(nil) end)
        end
    end
    ISBaseTimedAction.stop(self)
end

function KH_UseToiletAction:perform()
    if self.satOnFurniture and self.toilet and self.toilet.setSatChair then
        pcall(function() self.toilet:setSatChair(false) end)
        if self.character and self.character.setSitOnFurnitureObject then
            pcall(function() self.character:setSitOnFurnitureObject(nil) end)
        end
    end
    if self.character and KH.Toilet and KH.Toilet.relieve then
        KH.Toilet.relieve(self.character, false)
    end
    ISBaseTimedAction.perform(self)
end

function KH_UseToiletAction:new(character, toilet)
    local o = ISBaseTimedAction.new(self, character)
    o.toilet = toilet
    o.maxTime = PERFORM_TICKS
    o.stopOnWalk = true
    o.stopOnRun = true
    o.satOnFurniture = false
    return o
end

-- ------------------------------------------------------------------
-- Context-menu wiring
-- ------------------------------------------------------------------

-- B42 toilets live under fixtures_bathroom_* atlases. Sprite names do NOT
-- contain "toilet" -- the identifying field is the sprite property
-- CustomName. IMPORTANT (2026-05-24): the CustomName is NOT a bare "Toilet"
-- -- the in-game object reads as "White Toilet", so the value carries a
-- color/material prefix (e.g. "White Toilet", "Wooden Toilet"). The old
-- exact `== "toilet"` match never fired. We now substring-match "toilet"
-- across CustomName, GroupName+CustomName, and the sprite name.

-- Pull a property string by key, trying both accessor shapes PZ exposes.
local function _propStr(props, key)
    if not props then return nil end
    local v = nil
    pcall(function()
        if props.Val then v = props:Val(key) end
        if (v == nil or v == "") and props.getString then v = props:getString(key) end
    end)
    if v == nil or v == "" then return nil end
    return tostring(v)
end

-- Vanilla B42 toilet sprite indices in fixtures_bathroom_01 atlas. Index
-- runs 0..N; toilets cluster at specific positions. This list is best-effort
-- - if a user reports a missed toilet, add the index from the trash-debug
-- output to KH.DEBUG diagnostics. Known toilet indices as of 42.18:
local FIXTURES_BATHROOM_TOILET_INDICES = {
    [0]=true, [1]=true, [2]=true, [3]=true,
    [8]=true, [9]=true, [10]=true, [11]=true,
    [16]=true, [17]=true, [18]=true, [19]=true,
    [24]=true, [25]=true, [26]=true, [27]=true,
    [48]=true, [49]=true, [50]=true, [51]=true,
}

-- Is the player currently in a bathroom-named room? Used as a gate for the
-- sprite-name fallback below so we don't surface "Use Toilet" on every
-- bathroom-coded fixture that happens to be elsewhere.
local function _inBathroomRoom()
    local p = getPlayer(); if not p then return false end
    local sq = p:getCurrentSquare(); if not sq then return false end
    local room = sq:getRoom(); if not room then return false end
    local def = room.getRoomDef and room:getRoomDef()
    local name = def and def.getName and def:getName() or ""
    name = string.lower(tostring(name))
    return string.find(name, "bath", 1, true) ~= nil
        or string.find(name, "restroom", 1, true) ~= nil
        or string.find(name, "toilet", 1, true) ~= nil
end

-- Return the toilet's CustomName-ish label if obj looks like a toilet, else nil.
-- (Returning the label, not just a bool, lets the diagnostic report what it saw.)
local function toiletLabel(obj)
    if not obj then return nil end
    local sprite = obj.getSprite and obj:getSprite()
    if not sprite then return nil end
    local cn, gn
    if sprite.getProperties then
        local ok, props = pcall(function() return sprite:getProperties() end)
        if ok and props then
            cn = _propStr(props, "CustomName")
            gn = _propStr(props, "GroupName")
        end
    end
    -- Primary: CustomName has "toilet" (e.g. "White Toilet").
    if cn and string.find(string.lower(cn), "toilet") then return cn end
    if gn and string.find(string.lower(gn), "toilet") then return (gn .. " " .. (cn or "")) end

    -- Sprite-name fallback for modded / odd naming.
    local name = sprite.getName and sprite:getName()
    if name and string.find(string.lower(name), "toilet") then return name end

    -- Vanilla B42 fallback: some toilets in fixtures_bathroom_01 don't have
    -- CustomName set. Detect by atlas + index, AND require the player to be
    -- in a bathroom-typed room (so we don't surface "Use Toilet" on a hotel
    -- counter or museum exhibit using the same sprite). Pattern: the suffix
    -- after the last underscore is the index.
    if name then
        local lname = string.lower(tostring(name))
        if string.find(lname, "fixtures_bathroom_01_", 1, true) then
            local idx = tonumber(string.match(lname, "_(%d+)$"))
            if idx and FIXTURES_BATHROOM_TOILET_INDICES[idx] and _inBathroomRoom() then
                return "Bathroom Toilet"  -- generic label since CustomName is missing
            end
        end
    end
    return nil
end

local function isToiletObject(obj)
    return toiletLabel(obj) ~= nil
end

local function onUseToiletClicked(worldobjects, playerArg, toiletObj)
    local character
    if type(playerArg) == "number" then character = getSpecificPlayer(playerArg)
    elseif playerArg and playerArg.getInventory then character = playerArg
    else character = getPlayer() end
    if not character or not toiletObj then return end
    local sq = toiletObj.getSquare and toiletObj:getSquare()
    if not sq then return end
    if luautils and luautils.walkAdj then
        if not luautils.walkAdj(character, sq, true) then return end
    end
    ISTimedActionQueue.add(KH_UseToiletAction:new(character, toiletObj))
end

local function onFillContext(playerArg, context, worldobjects, test)
    if test then return end
    if not worldobjects then return end
    local seen = {}
    local sawToilet = false
    local spriteNames = {}  -- for the no-toilet-found diagnostic below
    for _, obj in ipairs(worldobjects) do
        local sn = obj and obj.getSprite and obj:getSprite() and obj:getSprite().getName and obj:getSprite():getName() or "?"
        -- Capture CustomName too so the diagnostic shows what the detector
        -- actually had to work with (this is the field "White Toilet" lives in).
        local cn = "?"
        pcall(function()
            local sp = obj and obj.getSprite and obj:getSprite()
            local props = sp and sp.getProperties and sp:getProperties()
            if props then
                if props.Val then cn = props:Val("CustomName") end
                if (cn == nil or cn == "") and props.getString then cn = props:getString("CustomName") end
            end
        end)
        spriteNames[#spriteNames + 1] = tostring(sn) .. "[CustomName=" .. tostring(cn) .. "]"
        if obj and isToiletObject(obj) and not seen[obj] then
            sawToilet = true
            seen[obj] = true
            local label = (getText and getText("ContextMenu_KH_UseToilet")) or "Use Toilet"
            context:addOption(label, worldobjects, onUseToiletClicked, playerArg, obj)
            break  -- one option per right-click is enough
        end
    end
    -- Diagnostic: if KH.DEBUG is on and we did NOT detect a toilet, dump the
    -- sprite names that WERE under the cursor. If Kierstal right-clicks a
    -- toilet and still gets no option, this names the sprite so we can teach
    -- isToiletObject() to recognize it. (Only fires when nothing matched, so
    -- it won't spam on every furniture right-click.)
    if not sawToilet and KH and KH.DEBUG and #spriteNames > 0 then
        print("[KH][toilet-debug] no toilet detected. sprites under cursor: " ..
            table.concat(spriteNames, ", "))
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContext)

print("[KH] Use Toilet action + context menu registered")
