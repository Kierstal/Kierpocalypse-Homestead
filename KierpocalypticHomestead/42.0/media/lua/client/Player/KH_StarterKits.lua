-- Kierpocalyptic Homestead - per-profession starter kits
--
-- On new game, grants thematic items based on the player's chosen
-- profession. All items are vanilla, verified to exist in B42 scripts.
--
-- v0.1.2 - PZ profession IDs in B42 are lowercase (farmer, carpenter,
-- electrician, etc.). Previously we stored PascalCase keys (Farmer,
-- Carpenter, ...) which never matched because `prof:getName()` returns
-- the lowercase id. All keys are now lowercase. The lookup also tries
-- the raw profName first as a courtesy in case any modded profession
-- registers a PascalCase id.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.StarterKits = "0.1.2"

local KITS = {
    -- Public safety / military
    policeoff          = { "Hat_Police", "Vest_BulletPolice", "Notebook", "Pen" },
    fireoff            = { "Hat_Fireman", "Lighter", "Whistle" },
    securityguard      = { "Hat_Police", "Whistle", "Notebook" },
    veteran            = { "Hat_BalaclavaFull", "Map" },

    -- Trades / construction
    constructionworker = { "Hat_HardHat", "Hammer", "Toolbox" },
    carpenter          = { "Hat_HardHat", "Hammer", "Saw", "Toolbox_Wooden" },
    electrician        = { "Screwdriver", "Pliers", "Toolbox" },
    engineer           = { "Screwdriver", "Pliers", "Notebook", "Pencil" },
    mechanics          = { "Wrench", "Pliers", "Toolbox_Mechanic" },
    metalworker        = { "Hammer", "Pliers", "Toolbox" },
    smither            = { "Hammer", "Pliers" },
    blacksmith         = { "Hammer", "Pliers" },
    repairman          = { "Toolbox", "Screwdriver", "Pliers" },

    -- Outdoors
    -- Park Ranger v0.1.3 (2026-05-29): Map + Whistle + Hiking Bag (vanilla
    -- ranger basics) plus Crowbar (blunt defense + KH_PryAction utility -
    -- matches Fear of Blood / Reluctant Fighter by avoiding edged blood-coded
    -- melee), plus Pen + Pencil + Notebook + SheetPaper for field log
    -- keeping AND the procedural First Impressions notes mechanic (the Pencil
    -- and Sheet specifically enable KH_FirstImpressions on Day 0; she can
    -- collect more Sheets in the world later).
    parkranger         = { "Map", "Whistle", "Bag_BigHikingBag", "Crowbar",
                           "Pen", "Pencil", "Notebook", "SheetPaper" },
    rancher            = { "Leash", "WaterDish", "Bag_FannyPackBack" },
    farmer             = { "Toolbox_Farming", "Apron_Black" },
    fisherman          = { "FishingRod", "Toolbox_Fishing" },
    lumberjack         = { "Hat_HardHat", "Saw" },
    hunter             = { "Bag_BigHikingBag", "Map", "KnifeButterfly" },

    -- Service / food
    burgerflipper      = { "Apron_Black", "Pan" },
    chef               = { "Apron_Black", "Pan", "KnifeButterfly", "Salt", "Sugar" },
    cook               = { "Apron_Black", "Pan", "KnifeParing" },
    fastfoodcook       = { "Apron_Black", "Pan" },
    waiter             = { "Apron_Black", "Pen", "Pencil" },
    cashier            = { "Pen", "Notebook" },
    shopclerk          = { "Pen", "Notebook" },
    salesperson        = { "Pen", "Notebook" },
    customerservice    = { "Pen", "Notebook" },

    -- Medical
    nurse              = { "Stethoscope", "Pen", "Notebook" },
    doctor             = { "Stethoscope", "Pen", "Notebook" },

    -- Office / academic
    officeworker       = { "Pen", "Pencil", "Notebook" },
    itworker           = { "Pen", "Pencil", "Notebook", "Screwdriver" },
    secretary          = { "Pen", "Pencil", "Notebook" },
    bookkeeper         = { "Pen", "Pencil", "Notebook" },
    accountant         = { "Pen", "Pencil", "Notebook" },
    teacher            = { "Pen", "Pencil", "Notebook", "Bag_Schoolbag" },

    -- Criminal / fringe
    burglar            = { "Screwdriver", "Pliers", "Hat_BalaclavaFull" },
    drugdealer         = { "CigarettePack", "Lighter", "Money",
                           -- Plus two random pills from a fun pool (resolved at grant time)
                           "@RandomPill", "@RandomPill" },

    -- Misc service
    truckdriver        = { "Map", "Wrench", "CigarettePack" },
    janitor            = { "Brush", "Mop", "Bag_FannyPackFront" },
    fitnessinstructor  = { "Whistle", "Bag_FannyPackFront" },

    -- Tailor
    tailor             = { "Scissors", "Pen", "Notebook" },

    -- Unemployed / custom: nothing extra (keep vanilla baseball bat)
    unemployed         = nil,
}

local function grantStarterKit()
    local p = getPlayer()
    if not p or not p:getDescriptor() then return end
    local prof = p:getDescriptor():getCharacterProfession()
    if not prof or not prof.getName then return end
    local profName
    pcall(function() profName = prof:getName() end)
    if not profName then return end

    -- B42 profession IDs are lowercase. Try lowercase first (the common
    -- path), then raw profName as a fallback in case a mod registers a
    -- PascalCase id.
    local kit = KITS[string.lower(profName)] or KITS[profName]
    if not kit then
        print("[KH] StarterKits: no kit registered for profession '" .. profName .. "' (tried '" .. string.lower(profName) .. "')")
        return
    end

    local inv = p:getInventory(); if not inv then return end
    -- Token resolvers - tokens like "@RandomPill" expand to a random pick
    local RANDOM_PILLS = { "Pills", "PillsAntiDep", "PillsBeta", "PillsSleepingTablets" }
    local function resolveToken(tok)
        if tok == "@RandomPill" then
            return RANDOM_PILLS[ZombRand(#RANDOM_PILLS) + 1]
        end
        return tok
    end
    local granted = {}
    for _, raw in ipairs(kit) do
        local itemId = resolveToken(raw)
        local fullId = string.find(itemId, "%.") and itemId or ("Base." .. itemId)
        local ok = pcall(function() inv:AddItem(fullId) end)
        if ok then table.insert(granted, itemId) end
    end
    if #granted > 0 then
        print(string.format("[KH] StarterKits: gave %s %d items: %s",
            profName, #granted, table.concat(granted, ", ")))
    end
end

Events.OnNewGame.Add(grantStarterKit)
print("[KH] StarterKits registered for OnNewGame.")
