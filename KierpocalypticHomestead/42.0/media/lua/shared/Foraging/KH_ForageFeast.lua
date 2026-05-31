-- Kierpocalyptic Homestead - Forage Feast forage bonuses
--
-- Registers KH:ForageFeast as a trait-type entry in the vanilla forage skill
-- system so it grants bonuses to "fresh fruits/vegetables/edible flora"
-- categories (per Kierstal's design).
--
-- Vanilla iterates forageSystem.skillDefs.trait at forage-roll time and looks
-- up the CharacterTrait via ResourceLocation.of(key). Our key matches the
-- registered trait id "KH:ForageFeast".

require "Foraging/forageSkills"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ForageFeast_Forage = "0.0.2"

local function register()
    if not forageSystem or not forageSystem.addSkillDef then return end
    forageSystem.addSkillDef({
        name             = "KH:ForageFeast",
        type             = "trait",
        visionBonus      = 0.4,
        weatherEffect    = 0,
        darknessEffect   = 0,
        specialisations  = {
            ["Berries"]         = 15,
            ["Fruits"]          = 15,
            ["Vegetables"]      = 15,
            ["Crops"]           = 10,
            ["WildPlants"]      = 10,
            ["WildHerbs"]       = 10,
            ["Mushrooms"]       = 10,
        },
    }, true)
    print("[KH] Forage Feast registered with forage system.")
end

Events.OnGameBoot.Add(register)
