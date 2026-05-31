-- Kierpocalyptic Homestead - trait registration v3
--
-- Mod traits must use a non-default namespace. PZ's RegistryReset rejects
-- "base:..." for register() calls because allowDefaultNamespace=false.
-- We use the "KH:" namespace - short, distinctive, ours.
--
-- Behavior files reference traits by their full namespaced id (e.g.
-- "KH:Pluviophile") via KH.hasTrait, which prefers the cached CharacterTrait
-- instance over string lookup.

require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.TraitRegistry = "0.0.3"

KH.registeredTraits = KH.registeredTraits or {}

local NAMESPACE = "KH"

-- Trait spec table. `pair` is the short-name partner for mutual exclusion.
local TRAITS = {
    {short = "Pluviophile",    nameKey = "UI_trait_KH_Pluviophile",     cost = 2,  descKey = "UI_trait_KH_PluviophileDesc",     pair = "Pluviophobe"},
    {short = "Pluviophobe",    nameKey = "UI_trait_KH_Pluviophobe",     cost = -2, descKey = "UI_trait_KH_PluviophobeDesc",     pair = "Pluviophile"},
    {short = "ComicNerd",      nameKey = "UI_trait_KH_ComicNerd",       cost = 2,  descKey = "UI_trait_KH_ComicNerdDesc"},
    {short = "TherapyAnimals", nameKey = "UI_trait_KH_TherapyAnimals",  cost = 4,  descKey = "UI_trait_KH_TherapyAnimalsDesc"},
    {short = "ForageFeast",    nameKey = "UI_trait_KH_ForageFeast",     cost = 3,  descKey = "UI_trait_KH_ForageFeastDesc"},
    -- Cleanliness pair (unified): affects both KH filth (room-level) and
    -- KH dirt (personal) systems, plus the bath need. Costs +4/-3 per the
    -- locked toilet/bath scope. Mutex pair.
    {short = "NeatFreak",      nameKey = "UI_trait_KH_NeatFreak",       cost = 4,  descKey = "UI_trait_KH_NeatFreakDesc",       pair = "Slob"},
    {short = "Slob",           nameKey = "UI_trait_KH_Slob",            cost = -3, descKey = "UI_trait_KH_SlobDesc",            pair = "NeatFreak"},
    -- Bladder pair: shifts toilet need rise rate.
    {short = "ToughBladder",   nameKey = "UI_trait_KH_ToughBladder",    cost = 2,  descKey = "UI_trait_KH_ToughBladderDesc",    pair = "WeakBladder"},
    {short = "WeakBladder",    nameKey = "UI_trait_KH_WeakBladder",     cost = -2, descKey = "UI_trait_KH_WeakBladderDesc",     pair = "ToughBladder"},
    -- "Outdoorsy" intentionally NOT registered here - vanilla has trait id
    -- "outdoorsman" already (UI label "Outdoorsy"). KH_BathNeed and KH_ToiletNeed
    -- check for vanilla "outdoorsman" so the existing vanilla trait covers it.
    --
    -- New niche negatives (May 2026): each bites in a specific situation
    -- rather than dragging constantly. Designed for players who load up on
    -- positives and want meaningful negatives that don't punish baseline
    -- play. See respective KH_*.lua files for behavior.
    {short = "CaffeineDependent", nameKey = "UI_trait_KH_CaffeineDependent", cost = -4, descKey = "UI_trait_KH_CaffeineDependentDesc"},
    {short = "ColdHands",         nameKey = "UI_trait_KH_ColdHands",         cost = -5, descKey = "UI_trait_KH_ColdHandsDesc"},
    {short = "Tinnitus",          nameKey = "UI_trait_KH_Tinnitus",          cost = -4, descKey = "UI_trait_KH_TinnitusDesc"},
    {short = "EasilyStartled",    nameKey = "UI_trait_KH_EasilyStartled",    cost = -5, descKey = "UI_trait_KH_EasilyStartledDesc"},
    {short = "Sentimental",       nameKey = "UI_trait_KH_Sentimental",       cost = -3, descKey = "UI_trait_KH_SentimentalDesc"},
    {short = "HighMaintenance",   nameKey = "UI_trait_KH_HighMaintenance",   cost = -4, descKey = "UI_trait_KH_HighMaintenanceDesc"},
    -- Social pair (MP-aware): Loner is mostly dormant in SP because there's
    -- never another player nearby. NeedsAttention bites in SP because the
    -- "no one around" condition is always true - that's reflected in cost.
    {short = "Loner",             nameKey = "UI_trait_KH_Loner",             cost = -2, descKey = "UI_trait_KH_LonerDesc",             pair = "NeedsAttention"},
    {short = "NeedsAttention",    nameKey = "UI_trait_KH_NeedsAttention",    cost = -4, descKey = "UI_trait_KH_NeedsAttentionDesc",    pair = "Loner"},
    -- Mirror of TherapyAnimals.
    {short = "HatesAnimals",      nameKey = "UI_trait_KH_HatesAnimals",      cost = -3, descKey = "UI_trait_KH_HatesAnimalsDesc",      pair = "TherapyAnimals"},
    -- Dietary pair: Vegetarian = happiness penalty, Vegan = blocks the eat
    -- action outright. Both check the same animal-derived FoodType set.
    {short = "Vegetarian",        nameKey = "UI_trait_KH_Vegetarian",        cost = -2, descKey = "UI_trait_KH_VegetarianDesc",        pair = "Vegan"},
    {short = "Vegan",             nameKey = "UI_trait_KH_Vegan",             cost = -4, descKey = "UI_trait_KH_VeganDesc",             pair = "Vegetarian"},
}

local function fullId(short) return NAMESPACE .. ":" .. short end

local function registerCharacterTrait(short)
    local id = fullId(short)
    if KH.registeredTraits[id] then return KH.registeredTraits[id] end
    if not (CharacterTrait and CharacterTrait.register) then
        print("[KH] CharacterTrait.register unavailable")
        return nil
    end
    local ok, trait = pcall(function() return CharacterTrait.register(id) end)
    if ok and trait then
        KH.registeredTraits[id] = trait
        return trait
    end
    print("[KH] CharacterTrait.register failed for " .. id .. ": " .. tostring(trait))
    return nil
end

local function addDef(trait, nameKey, cost, descKey)
    local ok, def = pcall(function()
        return CharacterTraitDefinition.addCharacterTraitDefinition(
            trait, nameKey, cost, descKey, false  -- isProfession=false
        )
    end)
    if ok and def then return def end
    print("[KH] addCharacterTraitDefinition failed: " .. tostring(def))
    return nil
end

local function registerOne(spec)
    local trait = registerCharacterTrait(spec.short)
    if not trait then return end
    local def = addDef(trait, spec.nameKey, spec.cost, spec.descKey)
    if not def then return end
    print("[KH] Registered trait: " .. fullId(spec.short))
end

local function setMutualPair(shortA, shortB)
    local a = KH.registeredTraits[fullId(shortA)]
    local b = KH.registeredTraits[fullId(shortB)]
    if not (a and b) then return end
    if not (CharacterTraitDefinition and CharacterTraitDefinition.setMutualExclusive) then return end
    local ok, err = pcall(function() CharacterTraitDefinition.setMutualExclusive(a, b) end)
    if not ok then
        print("[KH] setMutualExclusive failed for " .. shortA .. " <-> " .. shortB .. ": " .. tostring(err))
    end
end

local function registerAll()
    for _, spec in ipairs(TRAITS) do
        registerOne(spec)
    end
    -- Wire mutual-exclusion pairs after all registrations succeed
    for _, spec in ipairs(TRAITS) do
        if spec.pair then setMutualPair(spec.short, spec.pair) end
    end
end

Events.OnGameBoot.Add(registerAll)
