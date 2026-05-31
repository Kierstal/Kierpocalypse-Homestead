-- Kierpocalyptic Homestead - extend Rip Clothing to non-Clothing items
--
-- Vanilla canRipItem() has two paths:
--   1. item has FabricType + is Clothing instance -> rippable
--   2. ClothingRecipesDefinitions[item:getType()] exists -> rippable
--
-- BathTowel, DishCloth, BathTowelWet etc. are ItemType=base:drainable, not
-- clothing. They never match path 1. We hook into path 2 by registering
-- them in ClothingRecipesDefinitions with a material yield.

require "Definitions/ClothingRecipesDefinitions"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.RipOverrides = "0.0.1"

local function injectOverrides()
    if not ClothingRecipesDefinitions then return end

    -- Plain rippable towels - yields Ripped Sheets like cotton
    local towels = {
        "BathTowel", "BathTowelWet",
        "DishCloth", "DishTowel",
        "Pillow", "PillowCase", "Sheet",
    }
    for _, name in ipairs(towels) do
        if not ClothingRecipesDefinitions[name] then
            ClothingRecipesDefinitions[name] = {
                materials = "Base.RippedSheets:2",
            }
        end
    end
    print("[KH] RipOverrides: extended ClothingRecipesDefinitions with " .. tostring(#towels) .. " items")
end

-- Run after vanilla definitions load
Events.OnGameBoot.Add(injectOverrides)
