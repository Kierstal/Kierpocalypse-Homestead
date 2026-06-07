-- Kierpocalyptic Homestead - register Kierpocalyptic Rising in the new-game mode list
--
-- The "list with Rising and the others" on the New Game screen comes from
-- NewGameScreen.defaultGameModeData (a lua table populated with GameMode enum
-- entries). Mod-shipped preset .lua files in media/lua/shared/Sandbox/ are
-- loadable from disk but don't auto-appear on the new-game mode picker.
--
-- Approach: append an entry to NewGameScreen.defaultGameModeData. The click
-- handler already calls getWorld():setPreset(self.selectedItem.data.mode) with
-- the mode string, which loads <mode>.lua from media/lua/shared/Sandbox/. So
-- our mode string "KierpocalypticRising" must match our preset filename.
--
-- We also still patch SandboxOptionsScreen:loadPresets so the preset can be
-- loaded from the Custom Sandbox preset list as well.

require "OptionScreens/NewGameScreen"
require "OptionScreens/SandboxOptions"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.RegisterPreset = "0.0.2"

local MODE_ID = "KierpocalypticRising"

local function buildEntry()
    return {
        mode  = MODE_ID,
        title = getText("Sandbox_KierpocalypticRising") or "Kierpocalyptic Rising",
        desc  = getText("Sandbox_KierpocalypticRising_Desc") or "",
        -- Reuse the vanilla Rising playstyle icon: 456x512 PNG, exactly the
        -- thumbnail format the New Game preset list expects. Our preset is a
        -- Rising variant, so it's thematically right. To swap in a custom
        -- image later, drop a 456x512 PNG into media/ui/ in this mod and
        -- point thumb at "media/ui/KH_Rising.png".
        thumb = "media/ui/playstyleIcons/Rising.png",
        video = nil,
    }
end

local function alreadyHasEntry(list)
    if not list then return false end
    for _, e in ipairs(list) do
        if e and e.mode == MODE_ID then return true end
    end
    return false
end

-- 1. Append to NewGameScreen.defaultGameModeData at load time
if NewGameScreen and NewGameScreen.defaultGameModeData then
    if not alreadyHasEntry(NewGameScreen.defaultGameModeData) then
        table.insert(NewGameScreen.defaultGameModeData, buildEntry())
        print("[KH] Appended Kierpocalyptic Rising to NewGameScreen mode list.")
    end
end

-- 2. Also handle the case where NewGameScreen instance is already created
--    (it caches gameModeData on the instance)
if NewGameScreen and NewGameScreen.instance and NewGameScreen.instance.gameModeData then
    if not alreadyHasEntry(NewGameScreen.instance.gameModeData) then
        table.insert(NewGameScreen.instance.gameModeData, buildEntry())
    end
end

-- 3. Keep the Custom Sandbox preset list hook as well (secondary path)
local function addOurPreset(screen)
    if not screen or not screen.addPresetToList then return end
    if screen.presets then
        for _, p in ipairs(screen.presets) do
            if p.name == MODE_ID then return end
        end
    end
    local label = getText("Sandbox_KierpocalypticRising") or "Kierpocalyptic Rising"
    pcall(function() screen:addPresetToList(MODE_ID, label, false) end)
end

if SandboxOptionsScreen and SandboxOptionsScreen.loadPresets then
    local original = SandboxOptionsScreen.loadPresets
    function SandboxOptionsScreen:loadPresets()
        original(self)
        addOurPreset(self)
    end
end
