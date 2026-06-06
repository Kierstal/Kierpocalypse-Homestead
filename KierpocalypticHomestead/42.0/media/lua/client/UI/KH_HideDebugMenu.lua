-- Kierpocalyptic Homestead - hide the "Tile Report" / "Room Report" debug
-- options from the world right-click menu.
--
-- B42 (unstable) surfaces "Tile Report" and "Room Report" on the world context
-- menu. Kierstal never uses them and they break immersion. We wrap the vanilla
-- world-context-menu builder and strip those entries AFTER every other
-- vanilla/mod handler has populated the menu, so ordering doesn't matter.
--
-- Fail-safe: the original menu is always returned untouched on any error; if the
-- option names ever change, nothing is removed (the debug entries simply remain)
-- rather than breaking the menu.

require "ISUI/ISWorldObjectContextMenu"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.HideDebugMenu = "0.0.1"

-- Substrings matched case-insensitively against each option's display name.
-- Substring (not exact) so a localized/prefixed variant still hits.
local HIDE_FRAGMENTS = { "tile report", "room report" }

local function _shouldHide(name)
    if not name then return false end
    local lower = string.lower(tostring(name))
    for _, frag in ipairs(HIDE_FRAGMENTS) do
        if string.find(lower, frag, 1, true) then return true end
    end
    return false
end

-- Remove matching options from a context and re-id the survivors so internal
-- index lookups (mouse-over, etc.) stay consistent. Mirrors the re-id approach
-- in KH.UI.moveLastAddedToTop.
local function _scrub(context)
    if not context or not context.options then return end
    local kept = {}
    for _, opt in ipairs(context.options) do
        if not _shouldHide(opt and opt.name) then
            kept[#kept + 1] = opt
        end
    end
    for i, opt in ipairs(kept) do
        if opt then opt.id = i end
    end
    context.options = kept
end

-- Wrap the world-context-menu builder. createMenu runs every fill handler and
-- returns the populated context; we strip the debug entries before it renders.
if ISWorldObjectContextMenu and ISWorldObjectContextMenu.createMenu
   and not ISWorldObjectContextMenu._kh_hideDebug then
    local _orig = ISWorldObjectContextMenu.createMenu
    function ISWorldObjectContextMenu.createMenu(...)
        local context = _orig(...)
        pcall(function() _scrub(context) end)
        return context
    end
    ISWorldObjectContextMenu._kh_hideDebug = true
    print("[KH] HideDebugMenu: Tile/Room Report stripped from world context menu")
end
