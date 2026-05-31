-- Kierpocalyptic Homestead - Kill Zombies (KH) toggle
--
-- Right-click on your own character -> "Kill Zombies (KH): ON/OFF". When ON,
-- every 10 in-game minutes all IsoZombies in the loaded cell are removed.
-- Toggle is persisted in the player's modData so it survives reload.
--
-- This is a DEBUG / sandbox-style convenience, not a balanced gameplay feature.
-- Mirrors the vanilla debug-menu OnRemoveAllZombies pattern - only operates
-- on the loaded cell around the player, so traveling spawns more zombies in
-- new chunks which the next tick will clear.

require "ISUI/ISWorldObjectContextMenu"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.KillZombiesToggle = "0.0.1"

local MODDATA_KEY = "KH_KillZombiesOn"

local function getToggleState(player)
    if not player then return false end
    local md = player:getModData()
    return md and md[MODDATA_KEY] == true
end

local function setToggleState(player, on)
    if not player then return end
    local md = player:getModData()
    if md then md[MODDATA_KEY] = on and true or false end
end

local function removeAllZombiesInCell()
    if not getCell or not getCell() then return 0 end
    local objs = getCell():getObjectListForLua()
    if not objs then return 0 end
    local n = 0
    for i = objs:size(), 1, -1 do
        local obj = objs:get(i - 1)
        if obj and instanceof(obj, "IsoZombie") then
            -- Skip our companion (and any other friendly setUseless NPC)
            local skip = false
            if KH and KH._companionHandle and obj == KH._companionHandle then skip = true end
            if not skip and obj.isUseless and obj:isUseless() then skip = true end
            if not skip then
                pcall(function() obj:removeFromWorld() end)
                pcall(function() obj:removeFromSquare() end)
                n = n + 1
            end
        end
    end
    return n
end

-- Tick: every 10 in-game minutes, run the killer if any local player has the
-- toggle on. Operates on a per-cell basis; multiple players share the cell.
local function onEveryTenMinutes()
    local player = getPlayer()
    if not player then return end
    if not getToggleState(player) then return end
    local n = removeAllZombiesInCell()
    if n > 0 then
        print(string.format("[KH] Kill Zombies (KH): removed %d zombie(s) in loaded cell.", n))
    end
end

Events.EveryTenMinutes.Add(onEveryTenMinutes)

-- Click handler
local function onToggleClicked(worldobjects, playerArg)
    local character
    if type(playerArg) == "number" then character = getSpecificPlayer(playerArg)
    elseif playerArg and playerArg.getInventory then character = playerArg
    else character = getPlayer() end
    if not character then return end
    local now = getToggleState(character)
    setToggleState(character, not now)
    local newState = not now
    -- Immediate sweep on toggle-on so the player sees an effect right away
    if newState then
        local n = removeAllZombiesInCell()
        if n > 0 then
            print(string.format("[KH] Kill Zombies (KH) -> ON. Initial sweep removed %d zombie(s).", n))
        else
            print("[KH] Kill Zombies (KH) -> ON. No zombies in loaded cell currently.")
        end
    else
        print("[KH] Kill Zombies (KH) -> OFF.")
    end
end

-- Context-menu hook. Floor / world right-click - always show the toggle.
-- (Previously gated on "right-click on self" but worldobjects doesn't reliably
-- include the player object, so it never appeared.)
local function onFillContextMenu(playerArg, context, worldobjects, test)
    if test then return end
    local character
    if type(playerArg) == "number" then character = getSpecificPlayer(playerArg)
    elseif playerArg and playerArg.getInventory then character = playerArg
    else character = getPlayer() end
    if not character then return end

    local on = getToggleState(character)
    local label = on
        and (getText("ContextMenu_KH_KillZombies_On") or "Kill Zombies (KH): ON")
        or  (getText("ContextMenu_KH_KillZombies_Off") or "Kill Zombies (KH): OFF")
    context:addOption(label, worldobjects, onToggleClicked, playerArg)
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)
print("[KH] KillZombiesToggle registered.")
