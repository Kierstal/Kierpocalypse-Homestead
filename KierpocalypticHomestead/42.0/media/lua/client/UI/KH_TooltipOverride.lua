-- Kierpocalyptic Homestead - apply comprehensive descriptions on game boot.
--
-- Looks up each trait and profession from KH.Descriptions and rewrites its
-- description on the registered CharacterTraitDefinition / CharacterProfessionDefinition.
-- Any vanilla item not listed in KH.Descriptions keeps its vanilla text.

require "Tooltips/KH_Descriptions"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.TooltipOverride = "0.0.1"

local function applyTraitDesc(id, text)
    local trait
    if CharacterTrait and CharacterTrait.get and ResourceLocation and ResourceLocation.of then
        local ok, t = pcall(function() return CharacterTrait.get(ResourceLocation.of(id)) end)
        if ok then trait = t end
    end
    if not trait then return false end
    local def = CharacterTraitDefinition and CharacterTraitDefinition.getCharacterTraitDefinition
                and CharacterTraitDefinition.getCharacterTraitDefinition(trait)
    if not def or not def.setDescription then return false end
    def:setDescription(text)
    return true
end

local function applyProfessionDesc(id, text)
    local prof
    if CharacterProfession and CharacterProfession.get and ResourceLocation and ResourceLocation.of then
        local ok, p = pcall(function() return CharacterProfession.get(ResourceLocation.of(id)) end)
        if ok then prof = p end
    end
    if not prof then return false end
    local def = CharacterProfessionDefinition and CharacterProfessionDefinition.getCharacterProfessionDefinition
                and CharacterProfessionDefinition.getCharacterProfessionDefinition(prof)
    if not def or not def.setDescription then return false end
    def:setDescription(text)
    return true
end

local function applyAll()
    if not (KH and KH.Descriptions) then return end
    local appliedT, missedT, appliedP, missedP = 0, 0, 0, 0
    for id, text in pairs(KH.Descriptions.traits or {}) do
        if applyTraitDesc(id, text) then appliedT = appliedT + 1 else missedT = missedT + 1 end
    end
    for id, text in pairs(KH.Descriptions.professions or {}) do
        if applyProfessionDesc(id, text) then appliedP = appliedP + 1 else missedP = missedP + 1 end
    end
    print(string.format("[KH] Tooltips: %d/%d traits, %d/%d professions applied. (%d trait misses, %d prof misses likely indicate missing items in B42 or alternate ids)",
        appliedT, appliedT+missedT, appliedP, appliedP+missedP, missedT, missedP))
end

Events.OnGameBoot.Add(applyAll)
