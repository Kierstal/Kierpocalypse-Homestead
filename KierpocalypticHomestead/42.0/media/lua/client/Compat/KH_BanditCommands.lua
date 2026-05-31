-- Kierpocalyptic Homestead - right-click commands for Bandit NPCs
--
-- Bandits ships a right-click submenu under the bandit's name with "Join Me!"
-- (if Looter program) or "Leave Me!" (if Companion/CompanionGuard program).
-- Kierstal's playtest: she saw the bandit's name in the menu but no options
-- under it - either the bandit was in a program her current view filtered
-- out, or the submenu UI was empty for some reason.
--
-- KH adds its own command set as an explicit submenu so the commands are
-- always visible and unambiguous:
--   - Stay Here       (sets ForceStationary true; bandit roots in place)
--   - Follow Me       (clears ForceStationary; if in Companion program, follows)
--   - Guard This Spot (switches program to CompanionGuard)
--   - Come With Me    (switches program to Companion - recruits a Looter)
--   - Stand Down      (switches program to Looter - releases a Companion)
--
-- Backed by Bandit.ForceStationary / BanditMenu.SwitchProgram - BWO's own
-- API surface, so behaviors are identical to what BWO's chat keywords
-- would do. Just exposed through a context menu instead of typed chat.

require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.BanditCommands = "0.0.1"

-- Bandit detection. Defensive: returns false if Bandits not loaded.
-- API-existence preflight: never invoke Bandit.IsBandit when it doesn't
-- exist - same noise pattern as ThoughtTriggers had. Cache once at module
-- load and check the local before calling.
local _BanditAPI = _G.Bandit
local _BanditIsBandit = _BanditAPI and _BanditAPI.IsBandit
local function _isBandit(zombie)
    if not zombie or not _BanditIsBandit then return false end
    local result = false
    pcall(function() result = _BanditIsBandit(zombie) end)
    return result == true
end

-- Get the bandit's display name. Bandits stores it in their brain/modData.
local function _displayName(zombie)
    if not zombie then return "the bandit" end
    local name
    pcall(function()
        local md = zombie:getModData()
        if md and md.brain and md.brain.fullname then
            name = md.brain.fullname
        end
    end)
    if not name then
        pcall(function()
            local desc = zombie:getDescriptor()
            if desc then name = desc:getForename() end
        end)
    end
    return name or "the bandit"
end

-- Get the bandit's current program name ("Looter", "Companion", "CompanionGuard").
local function _programName(zombie)
    if not zombie then return nil end
    local name
    pcall(function()
        local md = zombie:getModData()
        if md and md.brain and md.brain.program then
            name = md.brain.program.name
        end
    end)
    return name
end

-- ---------- Command callbacks ----------

local function _stayHere(player, zombie)
    if not zombie or not _G.Bandit then return end
    pcall(function() Bandit.ForceStationary(zombie, true) end)
    if KH.DEBUG then print("[KH] BanditCommands: Stay Here -> " .. _displayName(zombie)) end
end

local function _followMe(player, zombie)
    if not zombie or not _G.Bandit then return end
    pcall(function() Bandit.ForceStationary(zombie, false) end)
    if KH.DEBUG then print("[KH] BanditCommands: Follow Me -> " .. _displayName(zombie)) end
end

local function _guardSpot(player, zombie)
    if not zombie or not _G.BanditMenu then return end
    pcall(function() BanditMenu.SwitchProgram(player, zombie, "CompanionGuard") end)
    if KH.DEBUG then print("[KH] BanditCommands: Guard Spot -> " .. _displayName(zombie)) end
end

local function _comeWithMe(player, zombie)
    if not zombie or not _G.BanditMenu then return end
    pcall(function() BanditMenu.SwitchProgram(player, zombie, "Companion") end)
    if KH.DEBUG then print("[KH] BanditCommands: Come With Me -> " .. _displayName(zombie)) end
end

local function _standDown(player, zombie)
    if not zombie or not _G.BanditMenu then return end
    pcall(function() BanditMenu.SwitchProgram(player, zombie, "Looter") end)
    if KH.DEBUG then print("[KH] BanditCommands: Stand Down -> " .. _displayName(zombie)) end
end

-- ---------- Context menu hook ----------

local function _findBanditOnSquare(square)
    if not square then return nil end
    local movables = square:getMovingObjects()
    if not movables then return nil end
    for i = 0, movables:size() - 1 do
        local obj = movables:get(i)
        if obj and instanceof(obj, "IsoZombie") and _isBandit(obj) then
            return obj
        end
    end
    return nil
end

local function _onFillContext(playerID, context, worldobjects, test)
    if not KH.compat or not KH.compat.bandits then return end
    if not _G.BanditCompatibility then return end

    -- Find the clicked square via BWO's helper - same way BanditMenu does it.
    local square
    pcall(function() square = BanditCompatibility.GetClickedSquare() end)
    if not square then return end

    local bandit = _findBanditOnSquare(square)
    if not bandit then return end

    local player = getSpecificPlayer(playerID)
    if not player then return end

    local name = _displayName(bandit)
    local program = _programName(bandit)

    -- KH submenu under "<Name> (KH commands)" - makes it clear these are
    -- KH-added commands not Bandits' own menu options.
    local root = context:addOption(name .. " (KH)", worldobjects, nil)
    local menu = context:getNew(context)
    context:addSubMenu(root, menu)

    -- Movement commands always available.
    menu:addOption("Stay Here",  player, _stayHere, bandit)
    menu:addOption("Follow Me",  player, _followMe, bandit)

    -- Program-dependent options. Looter -> can recruit. Companion -> can guard/release.
    if program == "Looter" then
        menu:addOption("Come With Me", player, _comeWithMe, bandit)
    elseif program == "Companion" then
        menu:addOption("Guard This Spot", player, _guardSpot, bandit)
        menu:addOption("Stand Down",      player, _standDown, bandit)
    elseif program == "CompanionGuard" then
        menu:addOption("Come With Me",    player, _comeWithMe, bandit)
        menu:addOption("Stand Down",      player, _standDown, bandit)
    else
        -- Unknown program - still allow the recruit option as a fal