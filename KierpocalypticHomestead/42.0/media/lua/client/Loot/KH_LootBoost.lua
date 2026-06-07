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

-- Values bumped 2026-05-30 toward "pre-apocalypse Week One: homes are full
-- of stuff because people are still alive and living their lives." The
-- previous values were tuned for vanilla post-apocalypse pacing. With BWO
-- VOriginal's day 0-7 framing, residential containers should feel stocked.
local VALUES = {
    FoodLootNew         = 2.5,  -- was 1.5; full pantries
    CannedFoodLootNew   = 2.5,  -- was 1.5; full cupboards
    LiteratureLootNew   = 1.5,  -- was 1.2
    SkillBookLoot       = 0.8,  -- unchanged (these are rare regardless)
    RecipeResourceLoot  = 1.0,
    MedicalLootNew      = 1.5,  -- was 1.2; medicine cabinets actually have stuff
    SurvivalGearsLootNew= 2.0,
    WeaponLootNew       = 0.4,  -- unchanged - she avoids combat
    RangedWeaponLootNew = 0.4,
    AmmoLootNew         = 0.4,
    MechanicsLootNew    = 1.5,  -- was 1.0
    OtherLootNew        = 2.0,  -- was 1.5
    ClothingLootNew     = 2.5,  -- was 1.5; closets are stocked
    ContainerLootNew    = 2.5,  -- was 1.2; THE big one for "homes feel full"
    KeyLootNew          = 1.0,
    MediaLootNew        = 2.0,
    MementoLootNew      = 2.0,  -- was 1.5; family stuff
    CookwareLootNew     = 2.5,  -- was 2.0
    MaterialLootNew     = 3.0,
    FarmingLootNew      = 2.5,  -- was 2.0
    ToolLootNew         = 2.5,  -- was 2.0
    RollsMultiplier     = 2.0,  -- was 1.5; more attempts per container
    RareLootFactor      = 0.7,
    NormalLootFactor    = 2.0,  -- was 1.5
    CommonLootFactor    = 3.5,  -- was 2.5
    AbundantLootFactor  = 5.0,  -- was 4.0
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
