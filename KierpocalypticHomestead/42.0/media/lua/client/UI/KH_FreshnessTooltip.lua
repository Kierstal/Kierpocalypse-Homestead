-- Kierpocalyptic Homestead - food freshness timer overlay
--
-- Draws a color-coded freshness line below the vanilla tooltip showing
-- how long until the food transitions to the next state.
--
-- UNITS NOTE: item:getAge() / getOffAge() / getOffAgeMax() return values
-- in DAYS (game time). Earlier version mistakenly labeled them as hours,
-- so a 5-day-fresh-remaining item displayed "5.0h to stale". Auto-format
-- now picks the right unit (minutes / hours / days).
--
-- FRIDGE SCALING: vanilla slows aging by FridgeFactor (sandbox, default 3)
-- while an item is in a powered fridge, and halts it entirely in a powered
-- freezer. We detect the container type + power state and label/scale the
-- remaining time accordingly. A "5d to stale" eggplant in a powered fridge
-- actually has 15d at the slowed rate.

require "ISUI/ISToolTipInv"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.FreshnessTooltip = "0.0.2"

-- Format a duration given in DAYS (fractional ok). Picks minutes < 1h,
-- hours < 1 day, days otherwise.
local function formatDuration(d)
    if not d or d <= 0 then return "0h" end
    if d < (1 / 1440) then  -- less than 1 minute
        return "<1m"
    end
    if d < (1 / 24) then  -- less than 1 hour - show minutes
        return string.format("%dm", math.floor(d * 1440))
    end
    if d < 1 then  -- less than 1 day - show hours
        return string.format("%.1fh", d * 24)
    end
    if d < 99 then
        local whole = math.floor(d)
        local hrs   = (d - whole) * 24
        if hrs < 0.5 then
            return string.format("%dd", whole)
        end
        return string.format("%dd %dh", whole, math.floor(hrs + 0.5))
    end
    return string.format("%dd", math.floor(d))
end

local function getSpoilageData(item)
    if not item then return nil end
    local isFoodOk = false
    pcall(function() isFoodOk = instanceof(item, "Food") end)
    if not isFoodOk then return nil end
    local age, offAge, offAgeMax
    pcall(function()
        age       = item.getAge       and item:getAge()       or nil
        offAge    = item.getOffAge    and item:getOffAge()    or nil
        offAgeMax = item.getOffAgeMax and item:getOffAgeMax() or nil
    end)
    if not age or not offAge or not offAgeMax then return nil end
    if offAge <= 0 or offAgeMax <= 0 then return nil end
    return age, offAge, offAgeMax
end

-- Returns ("fridge"|"freezer"|nil) when the item is in a POWERED fridge
-- or freezer. Anything else returns nil and the tooltip uses normal aging.
local function getColdContainerKind(item)
    if not item or not item.getContainer then return nil end
    local container
    pcall(function() container = item:getContainer() end)
    if not container or not container.getType then return nil end
    local ctype
    pcall(function() ctype = container:getType() end)
    if ctype ~= "fridge" and ctype ~= "freezer" then return nil end
    -- Find the IsoObject this container belongs to and its square
    local parent, sq
    pcall(function() parent = container.getParent and container:getParent() end)
    if parent and parent.getSquare then pcall(function() sq = parent:getSquare() end) end
    if not sq or not sq.haveElectricity then return nil end
    local powered = false
    pcall(function() powered = sq:haveElectricity() end)
    if not powered then return nil end  -- unpowered fridge = no slowdown
    return ctype
end

local function getFridgeFactor()
    -- SandboxVars.FridgeFactor: default 3 in Apocalypse-likes
    if SandboxVars and SandboxVars.FridgeFactor then
        return SandboxVars.FridgeFactor
    end
    return 3
end

local _origRender = ISToolTipInv.render
function ISToolTipInv:render()
    _origRender(self)
    if ISContextMenu.instance and ISContextMenu.instance.visibleCheck then return end
    if not self.item then return end

    local age, offAge, offAgeMax = getSpoilageData(self.item)
    if not age then return end

    local coldKind = getColdContainerKind(self.item)
    local fridgeFactor = getFridgeFactor()

    local label, r, g, b
    local rawDaysToStale  = offAge - age
    local rawDaysToRotten = offAgeMax - age

    -- Apply fridge / freezer scaling for the displayed time only
    local effectiveDaysToStale  = rawDaysToStale
    local effectiveDaysToRotten = rawDaysToRotten
    local suffix = ""
    if coldKind == "freezer" then
        suffix = " (frozen)"
        effectiveDaysToStale  = effectiveDaysToStale  * 999
        effectiveDaysToRotten = effectiveDaysToRotten * 999
    elseif coldKind == "fridge" and fridgeFactor and fridgeFactor > 1 then
        suffix = string.format(" (chilled \xc3\x97%d)", math.floor(fridgeFactor))
        effectiveDaysToStale  = effectiveDaysToStale  * fridgeFactor
        effectiveDaysToRotten = effectiveDaysToRotten * fridgeFactor
    end

    if rawDaysToStale > 0 then
        label = "Fresh - " .. formatDuration(effectiveDaysToStale) .. " to stale" .. suffix
        r, g, b = 0.45, 0.95, 0.45
    elseif rawDaysToRotten > 0 then
        label = "Stale - " .. formatDuration(effectiveDaysToRotten) .. " to rotten" .. suffix
        r, g, b = 1.00, 0.72, 0.10
    else
        label = "Rotten"
        r, g, b = 0.95, 0.25, 0.25
    end

    -- Extend the tooltip below vanilla content so our row gets its own line
    local pad_x = 8
    local font = UIFont and UIFont.Small or nil
    local fontH = (getTextManager and font and getTextManager():getFontHeight(font)) or 12
    local extra = fontH + 6
    local oldHeight = self.height
    self:setHeight(oldHeight + extra)
    if self.backgroundColor then
        self:drawRect(0, oldHeight, self.width, extra,
            self.backgroundColor.a, self.backgroundColor.r,
            self.backgroundColor.g, self.backgroundColor.b)
    end
    if self.borderColor then
        self:drawRectBorder(0, 0, self.width, self.height,
            self.borderColor.a, self.borderColor.r,
            self.borderColor.g, self.borderColor.b)
    end
    self:drawText(label, pad_x, oldHeight + 3, r, g, b, 1.0, font)
end

print("[KH] Freshness timer tooltip overlay v" .. KH.modules.FreshnessTooltip .. " registered (days unit + fridge-aware)")
