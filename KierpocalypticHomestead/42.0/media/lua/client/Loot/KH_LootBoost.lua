-- Kierpocalyptic Homestead - day-1 loot boost
--
-- Pushes loot multipliers up at game start. Lore: Rising takes place on day 1
-- of the outbreak; people who fled didn't pack heavy/non-essential things,
-- and people who died at home left everything.
--
-- Note: PZ loot is rolled when a chunk is first loaded. Chunks ALREADY loaded
-- in your save keep whatever loot they were generated with. These overrides
-- only affect chunks loaded for the first time AFTER this point, plus future
-- new worlds (where these values are baked into the preset too).

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.LootBoost = "0.0.1"

local VALUES = {
    FoodLootNew = 1.5, LiteratureLootNew = 1.2, SkillBookLoot = 0.8,
    RecipeResourceLoot = 1.0, MedicalLootNew = 1.2, SurvivalGearsLootNew = 2.0,
    CannedFoodLootNew = 1.5, WeaponLootNew = 0.4, RangedWeaponLootNew = 0.4,
    AmmoLootNew = 0.4, MechanicsLootNew = 1.0, OtherLootNew = 1.5,
    ClothingLootNew = 1.5, ContainerLootNew = 1.2, KeyLootNew = 1.0,
    MediaLootNew = 2.0, MementoLootNew = 1.5, CookwareLootNew = 2.0,
    MaterialLootNew = 3.0, FarmingLootNew = 2.0, ToolLootNew = 2.0,
    RollsMultiplier = 1.5,
    RareLootFactor = 0.7, NormalLootFactor = 1.5, CommonLootFactor = 2.5,
    AbundantLootFactor = 4.0,
}

Events.OnGameStart.Add(function()
    if not SandboxVars then return end
    local count = 0
    for k, v in pairs(VALUES) do
        if SandboxVars[k] ~= nil then
            SandboxVars[k] = v
            count = count + 1
        end
    end
    print(string.format("[KH] Loot boost: %d sandbox vars overridden for future chunk loads.", count))
end)
