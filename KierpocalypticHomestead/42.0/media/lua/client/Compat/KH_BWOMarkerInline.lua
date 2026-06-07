-- Kierpocalyptic Homestead - BWO event-marker inline placement
--
-- DISABLED 2026-05-30. The marker-slot injection appeared to correlate with
-- an explosion of render errors in BanditEventMarkers.lua:192 (null texture
-- on draw - "Cannot invoke Texture.getWidth() because tex is null"). Source
-- of the null texture is unclear; the patch only modifies marker placement,
-- not texture loading. But the marker module is in the recent-change set
-- and these errors weren't there before, so neutering it as the most likely
-- variable while we investigate.
--
-- Tradeoff: markers will overlap again (BWO's original buggy stacking
-- behavior), but 900-error-per-game spam is worse than UI clutter.
--
-- To re-enable: change `local DISABLED = true` to false. Original behavior
-- description preserved below for reference.
--
-- Bandits' BanditEventMarkerHandler.set creates HUD icons (Home, Hostile
-- Defenders, Bombing zone, etc.) at the top of the screen. The default
-- placement uses player modData["BanditEventMarkerPlacement"] which is a
-- single saved (x, y) point - so every new marker spawns at the same
-- location, stacking on top of each other.

require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.BWOMarkerInline = "0.0.2-disabled"

local DISABLED = true

local function patch()
    if DISABLED then
        print("[KH] BWOMarkerInline: DISABLED pending texture-null investigation. Markers will stack as in vanilla BWO.")
        return
    end
    if not KH.compat or not KH.compat.bandits then
        if KH.DEBUG then
            print("[KH] BWOMarkerInline: Bandits not detected, no patch needed")
        end
        return
    end

    if not _G.BanditEventMarkerHandler or not BanditEventMarkerHandler.set then
        print("[KH] BWOMarkerInline: BanditEventMarkerHandler.set not found - Bandits load order issue?")
        return
    end

    if not _G.BanditEventMarker or not BanditEventMarker.iconSize then
        print("[KH] BWOMarkerInline: BanditEventMarker.iconSize not found")
        return
    end

    local _origSet = BanditEventMarkerHandler.set

    BanditEventMarkerHandler.set = function(eventID, icon, duration, posX, posY, color, desc)
        -- Only intervene when creating a new marker (no existing one for this
        -- eventID) and duration is positive (a real marker, not a removal).
        local existing = BanditEventMarkerHandler.markers[eventID]
        if not existing and duration and duration > 0 then
            local player = getSpecificPlayer(0)
            if player then
                local iconSize = BanditEventMarker.iconSize or 96
                local screenW
                pcall(function() screenW = getCore():getScreenWidth() end)
                screenW = screenW or 1920

                -- Collect screenX of all currently-active markers.
                local taken = {}
                for _, marker in pairs(BanditEventMarkerHandler.markers) do
                    if marker and marker.screenX then
                        taken[marker.screenX] = true
                    end
                end

                -- Default starting position (BWO's original center-top).
                local startX = math.floor(screenW / 2 - iconSize / 2)
                local startY = math.floor(iconSize / 2)

                -- Find the first unoccupied slot stepping right by iconSize.
                -- 10-slot cap is generous; if there are already 10 active
                -- markers we let it overlap rather than spilling off-screen.
                local pickX = startX
                for i = 0, 10 do
                    local testX = startX + (i * iconSize)
                    if not taken[testX] then
                        pickX = testX
                        break
                    end
                end

                -- Inject the chosen slot into player modData so BWO's set()
                -- function uses it as the oldX/oldY. After BWO creates the
                -- marker, we don't reset modData - the drag-behavior of
                -- BWO updates modData when the player moves a marker, and
                -- that should keep working.
                local md = player:getModData()
                md.BanditEventMarkerPlacement = { pickX, startY }
            end
        end

        return _origSet(eventID, icon, duration, posX, posY, color, desc)
    end

    print("[KH] BWOMarkerInline: BanditEventMarkerHandler.set patched - markers now inline horizontally instead of stacked.")
end

Events.OnGameStart.Add(patch)
