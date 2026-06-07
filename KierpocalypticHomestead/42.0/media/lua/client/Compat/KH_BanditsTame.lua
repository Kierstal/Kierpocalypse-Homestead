-- Kierpocalyptic Homestead - Bandits + Bandits Week One taming
--
-- Both NPC mods spawn far too aggressively for Kierstal's "homestead
-- with occasional pressure" feel. Default Bandits has SpawnMultiplier
-- 1.00 and lets bandits destroy doors, smash windows, sabotage crops,
-- steal from containers, and accuracy 3/5. Default Week One has every
-- aerial / disaster event ON (Boeing crash, strafing, bombing, gas,
-- arson) and full population multipliers.
--
-- This module:
--   * Detects Bandits and/or Week One via KH.compat flags.
--   * Reads the player's KHCompat.TameBandits / TameBanditsWeekOne
--     toggles from sandbox-options.txt. Defaults TRUE (taming on).
--   * On `OnGameStart` (fires for new games AND continues), writes the
--     KH-tamed values into the live sandbox options.
--
-- The override targets BOTH the option object AND the SandboxVars
-- global table -- some Bandits internals read one, some read the other.
-- We set both for safety.
--
-- Reversible via the sandbox toggle: turning KHCompat.TameBandits OFF
-- on a continued save and then continuing will NOT undo prior writes
-- (PZ persists sandbox values per-save). The toggle is read once per
-- launch -- if the player wants vanilla bandits back they have to
-- re-toggle and start a new game, OR open the in-game Bandits options
-- menu and manually reset.

require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.BanditsTame = "0.0.1"

-- ----------------------------------------------------------------
-- Tamed defaults
-- ----------------------------------------------------------------
-- Bandits (Bandits2 / Workshop 3268487204), version 42.18.
-- Defaults from media/sandbox-options.txt; KH values picked for "few,
-- meaningful, not constant-pressure" feel. See BANDITS_TAMING.md.

local BANDITS_TAME = {
    -- Spawn / size
    { name = "Bandits.General_SpawnMultiplier", value = 0.30 },  -- default 1.00
    { name = "Bandits.General_SizeMultiplier",  value = 0.40 },  -- default 1.00
    -- Behavior dial-downs (less constant pressure on the homestead)
    { name = "Bandits.General_DestroyDoor",      value = false },  -- default true
    { name = "Bandits.General_SmashWindow",      value = false },  -- default true
    { name = "Bandits.General_RemoveBarricade",  value = false },  -- default true
    { name = "Bandits.General_DestroyThumpable", value = false },  -- default true
    { name = "Bandits.General_SabotageVehicles", value = false },  -- default true
    { name = "Bandits.General_Theft",            value = false },  -- default true
    { name = "Bandits.General_SabotageCrops",    value = false },  -- default true; critical for homestead
    { name = "Bandits.General_GeneratorCutoff",  value = false },  -- default true
    { name = "Bandits.General_BuildRoadblock",   value = false },  -- default true
    -- Combat softening
    { name = "Bandits.General_OverallAccuracy",  value = 2 },     -- default 3 (1-5 scale; 2=poor shot)
    -- Keep these vanilla (they encourage non-combat resolutions)
    -- Surrender, BleedOut, Infection, LimitedEndurance, RunAway,
    -- SneakAtNight, CarryTorches, Speak, Captions, ArrivalIcon
    -- all remain default true.
}

-- Bandits Week One (BanditsWeekOne / Workshop 3403180543), version 42.18.
local WEEKONE_TAME = {
    -- Population multipliers (0-4 scale, default 1)
    { name = "BanditsWeekOne.InhabitantsPopMultiplier", value = 0.50 },
    { name = "BanditsWeekOne.StreetsPopMultiplier",     value = 0.30 },
    { name = "BanditsWeekOne.ArmyPopMultiplier",        value = 0.30 },
    { name = "BanditsWeekOne.BanditsPopMultiplier",     value = 0.30 },
    -- Firearm chance (0-100%, defaults 7 / 3)
    { name = "BanditsWeekOne.InhabitantsPistolChance",  value = 3 },
    { name = "BanditsWeekOne.StreetsPistolChance",      value = 1 },
    -- Patrol vehicles
    { name = "BanditsWeekOne.VehiclesMax",              value = 2 },  -- default 4
    -- Service cooldowns (minutes; defaults shown)
    { name = "BanditsWeekOne.PoliceCooldown",   value = 120 },  -- default 30  -> 4x
    { name = "BanditsWeekOne.SWATCooldown",     value = 480 },  -- default 120 -> 4x
    { name = "BanditsWeekOne.MedicsCooldown",   value = 180 },  -- default 45  -> 4x
    { name = "BanditsWeekOne.HazmatCooldown",   value = 180 },  -- default 50  -> ~3.5x
    { name = "BanditsWeekOne.FiremanCooldown",  value = 120 },  -- default 25  -> ~5x
    -- Disaster events (defaults all TRUE; KH wants quieter sky)
    { name = "BanditsWeekOne.EventFinalSolution", value = false },
    { name = "BanditsWeekOne.EventBoeing",        value = false },
    { name = "BanditsWeekOne.EventStrafe",        value = false },
    { name = "BanditsWeekOne.EventBombing",       value = false },
    { name = "BanditsWeekOne.EventGas",           value = false },
    { name = "BanditsWeekOne.EventArson",         value = false },
}

-- ----------------------------------------------------------------
-- Apply
-- ----------------------------------------------------------------

local function setOptionValue(name, value)
    -- Two-channel write:
    --  1. Option object (SandboxOption:setValue) - what the in-game
    --     mod-options menu and serialization read.
    --  2. SandboxVars.<Namespace>.<Field> - what most mod code reads
    --     at runtime. The option object writes are supposed to keep
    --     this in sync, but Week One reads SandboxVars directly in
    --     places, so we mirror to be safe.
    local opt
    local ok = pcall(function()
        opt = getSandboxOptions():getOptionByName(name)
    end)
    if ok and opt then
        pcall(function() opt:setValue(value) end)
    end
    -- Mirror to SandboxVars table
    local dot = string.find(name, "%.")
    if dot then
        local ns = string.sub(name, 1, dot - 1)
        local field = string.sub(name, dot + 1)
        if SandboxVars then
            SandboxVars[ns] = SandboxVars[ns] or {}
            SandboxVars[ns][field] = value
        end
    end
end

local function applyPreset(preset, label)
    local count = 0
    for _, entry in ipairs(preset) do
        setOptionValue(entry.name, entry.value)
        count = count + 1
    end
    print(string.format("[KH] BanditsTame: applied %d %s overrides", count, label))
end

local function tameNow()
    -- Only apply when the relevant mod is detected. Otherwise the option
    -- names won't resolve and the writes are harmless no-ops, but we
    -- skip the print noise.
    if KH.compat and KH.compat.bandits then
        if KH.shouldDefer("bandits", "KHCompat.TameBandits") then
            applyPreset(BANDITS_TAME, "Bandits")
        else
            print("[KH] BanditsTame: Bandits detected but taming toggled OFF")
        end
    end
    if KH.compat and KH.compat.banditsweekone then
        if KH.shouldDefer("banditsweekone", "KHCompat.TameBanditsWeekOne") then
            applyPreset(WEEKONE_TAME, "BanditsWeekOne")
        else
            print("[KH] BanditsTame: Week One detected but taming toggled OFF")
        end
    end
    if (not KH.compat or (not KH.compat.bandits and not KH.compat.banditsweekone)) and KH.DEBUG then
        print("[KH] BanditsTame: no Bandits / Week One detected, nothing to do")
    end
end

-- Fire once at game start. OnGameStart runs after sandbox options are
-- loaded but before the world fully ticks, which is the right window
-- to write defaults.
Events.OnGameStart.Add(tameNow)
