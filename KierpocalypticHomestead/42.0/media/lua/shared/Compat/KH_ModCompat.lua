-- Kierpocalyptic Homestead - centralized mod compatibility detection
--
-- Single source of truth for "what other mods are loaded right now."
-- Populates KH.compat with a flag per mod KH cares about, and exposes
-- KH.shouldDefer() so individual modules don't each re-implement the
-- "is mod X loaded AND is the player's defer-toggle on" check.
--
-- DETECTION TIMING:
-- Scans at file-load time (not OnGameBoot), so other KH modules can read
-- KH.compat in their own top-level code without a load-order dependency.
-- OnGameBoot is only used to print the result once for log readability.
--
-- DEFENSIVE STYLE:
-- pcall-wraps every engine call. Mirrors the inline pattern from
-- KH_ClimateColors.lua so behavior is predictable across the codebase.
-- An unparseable mods list returns silently with all flags false rather
-- than crashing boot.
--
-- ADDING A NEW DETECTED MOD:
-- 1. Add the flag to KH.compat's defaults table.
-- 2. Add an ID_TO_FLAG entry mapping the mod.info `id=` to the flag.
-- 3. (Optional) add a sandbox toggle in media/sandbox-options.txt and
--    use KH.shouldDefer(flag, "KHCompat.OptName") at the call site.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ModCompat = "0.1.0"

KH.compat = KH.compat or {
    -- Hygiene / lifestyle layer
    lifestyle        = false,  -- Lifestyle: Hobbies

    -- Cooking
    saph             = false,  -- Sapph's Cooking

    -- Climate
    heregoesthesun   = false,  -- Here Goes the Sun

    -- Pets / animals stack (Freylith ecosystem)
    animalessentials = false,  -- AnimalEssentials framework
    meowboid         = false,  -- Pawject Meowboid (cats)
    cyberdog         = false,  -- CyberDoggie animal template

    -- NPCs (integration deferred to a later phase)
    bandits          = false,  -- Bandits (Bandits2)
    banditsweekone   = false,  -- Bandits Week One

    -- Containers
    foolcontainers   = false,  -- UNOFFICIAL Fools New Containers B42

    -- Sims cosmetic trio (low compat burden, themed-integration only)
    simsmap          = false,  -- The Sims Zomboid (map)
    simsmenu         = false,  -- SimsMenuAndLogo
    simsplumbob      = false,  -- Sims Plumbob

    -- SSR quest framework + NPC extensions (the village layer)
    ssr_core         = false,  -- SSR: Core (utility libs, SSRTimer, SyncClient)
    ssr_quests       = false,  -- SSR: Quest System (framework, dialogue, characters)
    ssr_e1           = false,  -- SSR FurnitureFolks (sprite NPCs)
    ssr_e2           = false,  -- SSR Mannequin NPCs (full character-model NPCs)
    ssr_e3           = false,  -- SSR Trade Plugin (merchant mechanics)
}

-- Maps mod.info `id=` values to KH.compat flag names. Centralizing the
-- mapping makes adding new detected mods a one-line edit.
local ID_TO_FLAG = {
    ["LifestyleHobbies"] = "lifestyle",
    ["SapphCooking_B42"] = "saph",
    ["HereGoesTheSun"]   = "heregoesthesun",
    ["Animal_Essentials"]= "animalessentials",
    ["KITTYOWO"]         = "meowboid",
    ["CYBERDOGTEMPLATE"] = "cyberdog",
    ["Bandits2"]         = "bandits",
    ["BanditsWeekOne"]   = "banditsweekone",
    ["foolcontainers42"] = "foolcontainers",
    ["The Sims Zomboid"] = "simsmap",
    ["SimsMenuAndLogo"]  = "simsmenu",
    ["simsPlumbob"]      = "simsplumbob",
    ["ssr-core"]         = "ssr_core",
    ["ssr-quests"]       = "ssr_quests",
    ["ssr-quests-e1"]    = "ssr_e1",
    ["ssr-quests-e2"]    = "ssr_e2",
    ["ssr-quests-e3"]    = "ssr_e3",
}

-- Defensive scan of getActivatedMods(). Returns silently with all flags
-- unchanged if the engine call fails. Same shape as the KH_ClimateColors
-- inline check.
local function scanLoadedMods()
    local ok, list = pcall(function() return getActivatedMods() end)
    if not ok or not list or not list.size then return end
    for i = 0, list:size() - 1 do
        local id
        pcall(function() id = list:get(i) end)
        if id then
            local flag = ID_TO_FLAG[tostring(id)]
            if flag then
                KH.compat[flag] = true
            end
        end
    end
end

-- Run immediately so other modules can branch on KH.compat at file-load.
scanLoadedMods()

-- Helper: should THIS KH feature step aside?
-- Returns true when the named mod is loaded AND the sandbox toggle is on.
-- Returns false when the mod is absent OR the player turned the toggle off.
-- pcall-protected: a sandbox call that fails (e.g. options not yet built
-- at very early boot) is treated as "defer" - the safer choice since the
-- mod IS present.
function KH.shouldDefer(modFlag, sandboxOptName)
    if not KH.compat[modFlag] then return false end
    if not sandboxOptName then return true end  -- no toggle specified -> always defer when mod present
    local ok, opt = pcall(function()
        return getSandboxOptions():getOptionByName(sandboxOptName)
    end)
    if not ok or not opt then return true end
    local val
    pcall(function() val = opt:getValue() end)
    if val == nil then return true end
    return val == true
end

-- Deferred until OnGameBoot just for a clean, ordered log line.
local function logResults()
    if not KH.DEBUG then return end
    local active = {}
    for flag, on in pairs(KH.compat) do
        if on then active[#active + 1] = flag end
    end
    if #active == 0 then
        print("[KH] ModCompat: no tracked compat mods detected")
        return
    end
    table.sort(active)
    print("[KH] ModCompat: detected " .. table.concat(active, ", "))
end

Events.OnGameBoot.Add(logResults)
