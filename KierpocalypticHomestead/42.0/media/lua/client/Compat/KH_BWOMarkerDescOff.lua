-- Kierpocalyptic Homestead - hide BWO marker description labels
--
-- Kierstal's decision 2026-06-01: since the marker-inline patch is disabled
-- (texture-null spam unsolved), markers will stack. The labels under each
-- icon become unreadable when overlapping. Strip the desc field at marker
-- creation so only the icons stack, no garbled text.
--
-- The marker's render method has `if self.desc then draw label end`. We
-- can't make desc nil after construction because it's set in the marker's
-- constructor, but we CAN wrap BanditEventMarkerHandler.set to call the
-- original, then clear desc on the resulting marker.

require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.BWOMarkerDescOff = "0.0.1"

local function patch()
    if not KH.compat or not KH.compat.bandits then return end
    if not _G.BanditEventMarkerHandler or not BanditEventMarkerHandler.set then
        return
    end

    local _origSet = BanditEventMarkerHandler.set

    BanditEventMarkerHandler.set = function(eventID, icon, duration, posX, posY, color, desc)
        -- Pass nil for desc so the marker never gets a label. BWO's render
        -- code uses `if self.desc then drawTextCentre(...)` so nil = skip.
        local result = _origSet(eventID, icon, duration, posX, posY, color, nil)
        -- Belt and suspenders: clear any existing marker's desc after the
        -- fact too, in case _origSet's "if marker then" branch updates
        -- existing markers with desc data.
        local marker = BanditEventMarkerHandler.markers[eventID]
        if marker then marker.desc = nil end
        return result
    end

    print("[KH] BWOMarkerDescOff: BWO marker labels hidden (icons only).")
end

Events.OnGameStart.Add(patch)
