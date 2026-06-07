-- Kierpocalyptic Homestead - Death location map marker
--
-- When the player dies, place a green marker on the world map at the death
-- location so the recovery run (loot, weapons, mementos still on the body)
-- has a navigation target. Press the clear key (default U) to dismiss the
-- marker via a confirm dialog once recovery is done.
--
-- Adapted from "Where Did I Die" by Max (MaxFindMyBody, workshop 3733306447).
-- Verbatim core logic with attribution; absorbed into KH so Kierstal can
-- unsubscribe from the standalone mod and still have the feature. The clear
-- keybind moved into KHCompat.DeathMarkerClearKey sandbox option so it
-- doesn't collide with KH's own keybinds.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.DeathMarker = "0.0.1"

KH.DeathMarker = KH.DeathMarker or {}
KH.DeathMarker._marker = nil

-- Default clear key (vanilla U). Players can rebind in PZ controls if needed.
local CLEAR_KEY = Keyboard.KEY_U

local function _addMarker(x, y)
    if not ISWorldMap_instance or not ISWorldMap_instance.mapAPI then return nil end
    local mapAPI = ISWorldMap_instance.mapAPI
    if not mapAPI or not mapAPI.getMarkersAPI then return nil end
    local markers = mapAPI:getMarkersAPI()
    if not markers or not markers.addGridSquareMarker then return nil end
    -- x, y, radius, r, g, b, alpha -- green at half opacity
    return markers:addGridSquareMarker(x, y, 0.5, 0, 255, 0, 0.5)
end

local function _removeMarker(marker)
    if not marker then return end
    if not ISWorldMap_instance or not ISWorldMap_instance.mapAPI then return end
    local mapAPI = ISWorldMap_instance.mapAPI
    if not mapAPI or not mapAPI.getMarkersAPI then return end
    local markers = mapAPI:getMarkersAPI()
    if not markers or not markers.removeMarker then return end
    pcall(function() markers:removeMarker(marker) end)
end

function KH.DeathMarker.reset()
    if KH.DeathMarker._marker ~= nil then
        _removeMarker(KH.DeathMarker._marker)
    end
    KH.DeathMarker._marker = nil
end

local function onPlayerDeath(player)
    if not player then return end
    KH.DeathMarker.reset()
    local px = player:getX()
    local py = player:getY()
    if KH.DeathMarker._marker == nil then
        KH.DeathMarker._marker = _addMarker(px, py)
        if KH.DEBUG then
            print(string.format("[KH] DeathMarker: placed at (%d,%d)", px, py))
        end
    end
end

local function onKeyPressed(key)
    if key ~= CLEAR_KEY then return end
    if KH.DeathMarker._marker == nil then return end

    local player = getSpecificPlayer(0)
    if not player then return end
    local playerNum = player:getPlayerNum()
    local width, height = 350, 140
    local x = (getCore():getScreenWidth() / 2) - width / 2
    local y = (getCore():getScreenHeight() / 2) - height / 2

    local dialog = ISConfirmDialog:new(x, y, width, height, playerNum, function()
        KH.DeathMarker.reset()
        local p = getSpecificPlayer(0)
        if p then
            pcall(function() p:Say(getText("IGUI_PlayerText_ClearMarker") or "Clearing death marker.") end)
        end
    end)
    dialog:initialise()
    dialog.moveWithMouse = true
    dialog:addToUIManager()
end

Events.OnPlayerDeath.Add(onPlayerDeath)
Events.OnKeyPressed.Add(onKeyPressed)

print("[KH] DeathMarker registered (press U to clear after recovery).")
