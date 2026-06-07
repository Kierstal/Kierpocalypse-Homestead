-- Kierpocalyptic Homestead - hide the "Tile Report" / "Room Report" debug
-- options from the world right-click menu.
--
-- B42 (unstable) surfaces "Tile Report" and "Room Report" on the world context
-- menu. We remove them DURING the fill phase (an OnFillWorldObjectContextMenu
-- handler), i.e. before the menu computes its height - so no blank rows are
-- left behind. (An earlier version stripped them AFTER the menu was sized via a
-- createMenu wrap, which left empty lines at the bottom; this avoids that.)
--
-- Registered at mod load, so it runs after vanilla's handler that adds the
-- debug options. Fail-safe: removes nothing if the names aren't present, and
-- never touches sizing.

require "ISUI/ISWorldObjectContextMenu"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.HideDebugMenu = "0.0.2"

-- Substrings matched case-insensitively against each option's display name.
local HIDE_FRAGMENTS = { "tile report", "room report" }

local function _shouldHide(name)
    if not name then return false end
    local lower = string.lower(tostring(name))
    for _, frag in ipairs(HIDE_FRAGMENTS) do
        if string.find(lower, frag, 1, true) then return true end
    end
    return false
end

local function onFillContext(playerNum, context, worldobjects, test)
    if not context or not context.options then return end
    local kept = {}
    for _, opt in ipairs(context.options) do
        if not _shouldHide(opt and opt.name) then
            kept[#kept + 1] = opt
        end
    end
    -- Only rewrite if we actually removed something (and re-id survivors so
    -- positional/mouse-over lookups stay consistent).
    if #kept ~= #context.options then
        for i, opt in ipairs(kept) do
            if opt then opt.id = i end
        end
        context.options = kept
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContext)

print("[KH] HideDebugMenu v0.0.2: Tile/Room Report removed during fill (no blank rows)")
