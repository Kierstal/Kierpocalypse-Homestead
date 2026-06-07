-- Kierpocalyptic Homestead - comprehensive trait & profession descriptions
--
-- Vanilla tooltips often only mention 1-2 effects when traits and professions
-- have many. This file is the source of truth for the full effect lists.
-- KH_TooltipOverride.lua reads this and applies via setDescription() on
-- OnGameBoot.
--
-- Conventions:
--   <br>          - line break in the tooltip
--   [KH] prefix   - effect added or modified by Kierpocalyptic Homestead
--
-- Add traits to this file as you encounter them. Items not listed keep
-- their vanilla descriptions.

KH = KH or {}
KH.Descriptions = {
    traits = {},
    professions = {},
}

-- Vanilla traits ===========================================================
KH.Descriptions.traits["AdrenalineJunkie"] = "When panicked, movement speed increases by ~10%, knockback resistance improves, and critical strike chance is boosted.<br>The benefits scale with panic level; outweighs the usual panic penalties at high panic."

KH.Descriptions.traits["AllThumbs"] = "Inventory transfers and reloading take ~30% longer.<br>Aim takes longer to settle.<br>Climbing fences takes ~3x as long."

KH.Descriptions.traits["Asthmatic"] = "Endurance drains ~30% faster.<br>Endurance recovers slightly slower."

KH.Descriptions.traits["Athletic"] = "Starts with Fitness 9 and Strength 6.<br>Higher max running speed.<br>Faster combat-stamina recovery."

KH.Descriptions.traits["Brave"] = "Resistant to panic from zombies, corpses, and combat.<br>Smaller stress and unhappiness penalties from gore and confined spaces."

KH.Descriptions.traits["Burglar"] = "+2 Long Blade.<br>+1 Sneaking.<br>Hotwires cars without damaging the engine.<br>Climbs through windows quickly."

KH.Descriptions.traits["Claustrophobic"] = "Stress and unhappiness rise gradually while indoors or in confined spaces."

KH.Descriptions.traits["Clumsy"] = "Footsteps are louder; zombies hear you from further.<br>Climbing penalties."

KH.Descriptions.traits["Cook"] = "+2 Cooking, +1 Butchering.<br>Granted recipes: Cake Batter, Pie Dough, Breaddough, Baguette Dough, Biscuits, multiple Cookie Doughs (chocolate chip, oatmeal, shortbread, sugar), Pizza, Fried Onion Rings, Fried Shrimp, Cabbage Rolls, jar prep, Guacamole.<br>Forage: +5% Animals, Berries, Mushrooms, JunkFood, WildPlants, WildHerbs (+3% MedicinalPlants).<br>Vision +0.2 while foraging."

KH.Descriptions.traits["Cowardly"] = "Panic from zombies and threats sets in faster.<br>Panic recovery is slower."

KH.Descriptions.traits["Dextrous"] = "Inventory transfers and reloading ~30% faster.<br>Slightly quieter steps.<br>+1 Climbing."

KH.Descriptions.traits["Disorganized"] = "Containers (worn and held) carry ~30% less weight."

KH.Descriptions.traits["EagleEyed"] = "Faster visibility fade-in.<br>Wider visibility arc.<br>Long-range weapon sights more effective.<br>Forage vision +1.0."

KH.Descriptions.traits["FastHealer"] = "Wounds heal ~30% faster.<br>Bandages soil at a slower rate."

KH.Descriptions.traits["FastLearner"] = "+30% XP gain across all skills."

KH.Descriptions.traits["FastReader"] = "Reads books and magazines ~30% faster."

KH.Descriptions.traits["Feeble"] = "Starts with Strength 2.<br>Reduced melee damage and inventory weight capacity."

KH.Descriptions.traits["Fit"] = "Starts with Fitness 6, Strength 5."

KH.Descriptions.traits["Gardener"] = "+1 Farming.<br>Granted recipes: fly/mildew/aphid cures, scarecrow, growing-season knowledge for most crops and herbs (carrots, broccoli, radishes, strawberries, tomatoes, potatoes, cabbage, corn, kale, sweet potato, peas, onion, garlic, soybean, basil, chives, cilantro, oregano, parsley, sage, rosemary, thyme, hops, sugar beet, bell pepper, cauliflower, cucumber, habanero, jalapeno, leek, lettuce, pumpkin, spinach, sunflower, turnip, watermelon, zucchini, plus medicinal plants), and jar prep for most vegetables.<br>Forage: +3% MedicinalPlants, +5% Crops, Fruits, Vegetables.<br>Vision +0.4."

KH.Descriptions.traits["Graceful"] = "Quieter movement; zombies are less likely to hear you walking."

KH.Descriptions.traits["Gymnast"] = "+2 Climbing.<br>+1 Strength.<br>Faster fence vaulting and trellis climbing."

KH.Descriptions.traits["Handy"] = "+1 Maintenance, +1 Carpentry.<br>Constructed objects gain ~25% more starting health and degrade ~25% slower."

KH.Descriptions.traits["HardOfHearing"] = "Reduced hearing range; less warning before nearby zombies are visible."

KH.Descriptions.traits["HeartyAppetite"] = "Hunger increases ~20% faster."

KH.Descriptions.traits["Hemophobic"] = "Stress and unhappiness rise on contact with blood, wounds, or corpses."

KH.Descriptions.traits["Herbalist"] = "Identifies medicinal plants in foraging.<br>Granted recipes for several herbal remedies.<br>Forage: +15% MedicinalPlants, +5% WildPlants, WildHerbs."

KH.Descriptions.traits["Hiker"] = "Faster outdoor walking.<br>Reduced endurance drain when walking.<br>Forage bonuses in forest zones."

KH.Descriptions.traits["HighThirst"] = "Thirst increases ~20% faster."

KH.Descriptions.traits["Hunter"] = "+2 Aiming, +2 Trapping.<br>Knows trap recipes.<br>Forage: bonuses to Animals and Tracks."

KH.Descriptions.traits["Illiterate"] = "Cannot read books or magazines.<br>Cannot gain XP from reading."

KH.Descriptions.traits["Inconspicuous"] = "Zombies less likely to spot you from a distance."

KH.Descriptions.traits["Insomniac"] = "Sleep is slower to take effect.<br>Tiredness recovers more slowly per hour slept."

KH.Descriptions.traits["IronGut"] = "Reduced sickness from rotten/unsafe food.<br>Less likely to vomit."

KH.Descriptions.traits["KeenHearing"] = "Wider rear visibility cone (you 'hear' approach from behind better)."

KH.Descriptions.traits["LightEater"] = "Hunger increases ~15% slower."

KH.Descriptions.traits["LowThirst"] = "Thirst increases ~15% slower."

KH.Descriptions.traits["Marksman"] = "+2 Aiming, +1 Reloading."

KH.Descriptions.traits["Mechanics"] = "+2 Mechanics, +1 Electrical."

KH.Descriptions.traits["NeedsLessSleep"] = "Tiredness builds more slowly."

KH.Descriptions.traits["NeedsMoreSleep"] = "Tiredness builds faster and recovers slower."

KH.Descriptions.traits["NightOwl"] = "Less tiredness gain at night.<br>More tiredness gain during the day."

KH.Descriptions.traits["NightVision"] = "Better vision at night - minimum ambient light is raised by ~10%.<br>Vision arc bonus while foraging.<br>[KH] +10% chance per item in any container you open to spawn a bonus duplicate, and to improve item condition or food freshness."

KH.Descriptions.traits["Nutritionist"] = "Reveals nutritional values on food items (calories, carbs, proteins, fats).<br>Forage: +5% JunkFood, MedicinalPlants, WildPlants, WildHerbs.<br>[KH] Adds a Nutrition section to the Character Info panel showing your current calorie / carb / protein / fat / weight totals."

KH.Descriptions.traits["Outdoorsman"] = "Resistant to weather effects (cold, scratches from foliage).<br>Faster outdoor endurance recovery.<br>Forage: +5% Animals, Berries, Mushrooms, MedicinalPlants, WildPlants, WildHerbs.<br>Vision +0.4."

KH.Descriptions.traits["Pacifist"] = "-30% combat XP gain (Aiming, Reloading, all melee).<br>Slightly higher panic from combat."

KH.Descriptions.traits["ProneToIllness"] = "Catches colds and flu more readily; symptoms last longer."

KH.Descriptions.traits["Resilient"] = "Recovers from infection-style illnesses faster (excluding zombification)."

KH.Descriptions.traits["ShortSighted"] = "Reduced visible distance arc.<br>Closer items in inventory still readable."

KH.Descriptions.traits["SlowHealer"] = "Wounds heal ~30% slower."

KH.Descriptions.traits["SlowLearner"] = "-30% XP gain."

KH.Descriptions.traits["SlowReader"] = "Reads books and magazines ~30% slower."

KH.Descriptions.traits["Smoker"] = "Cigarettes reduce stress.<br>Without nicotine for too long, unhappiness rises."

KH.Descriptions.traits["SpeedDemon"] = "Drives ~30% faster.<br>Better recovery from spinouts."

KH.Descriptions.traits["Stout"] = "Starts with Strength 7.<br>+4 inventory weight capacity.<br>Increased melee damage."

KH.Descriptions.traits["Strong"] = "Starts with Strength 10.<br>+8 inventory weight capacity.<br>Significantly increased melee damage."

KH.Descriptions.traits["SundayDriver"] = "Drives ~30% slower.<br>Cars handle as if sluggish."

KH.Descriptions.traits["ThickSkinned"] = "Resistant to scratches and bites; some chance to mitigate damage from a hostile attack."

KH.Descriptions.traits["ThinSkinned"] = "More vulnerable to scratches and bites."

KH.Descriptions.traits["Unfit"] = "Starts with Fitness 2.<br>Lower max endurance and slower recovery."

KH.Descriptions.traits["Weak"] = "Starts with Strength 1.<br>-8 inventory weight capacity.<br>Reduced melee damage."

KH.Descriptions.traits["WeakStomach"] = "Sickens more easily from old or contaminated food."

-- KH-added traits already have descriptions via UI.json; skip to avoid double work.

-- Vanilla professions ======================================================
KH.Descriptions.professions["unemployed"] = "No starting profession bonuses.<br>Free to spend trait points anywhere."

KH.Descriptions.professions["burglar"] = "+1 Sneaking, +1 Long Blade.<br>Starts with the Burglar trait (hotwires cars, fast window-climb).<br>Forage: +5% Trash, Junk."

KH.Descriptions.professions["carpenter"] = "+2 Carpentry.<br>Starts knowing common carpentry recipes."

KH.Descriptions.professions["chef"] = "+1 Cooking, +1 Maintenance.<br>Starts with the Cook trait (extra Cooking and Butchering, all dough/baking recipes)."

KH.Descriptions.professions["constructionworker"] = "+1 Carpentry.<br>Starts with hardhat and a few core tools."

KH.Descriptions.professions["doctor"] = "+1 First Aid, +2 Doctor.<br>Identifies most ailments at higher fidelity than base."

KH.Descriptions.professions["engineer"] = "+1 Electrical, +1 Metalworking.<br>Knows several explosive/electrical assembly recipes."

KH.Descriptions.professions["farmer"] = "+2 Farming.<br>Forage: +5% Crops, +50% specialised plant categories.<br>Knows growing-season info for most vanilla crops."

KH.Descriptions.professions["fireofficer"] = "+1 Fitness, +1 Strength, +1 Axe.<br>Starts with axe and fire gear."

KH.Descriptions.professions["fisherman"] = "+2 Fishing.<br>Starts with fishing gear and a small kit."

KH.Descriptions.professions["lumberjack"] = "+2 Axe.<br>Faster tree-felling.<br>Slightly more wood per tree."

KH.Descriptions.professions["mechanic"] = "+2 Mechanics.<br>Reads cars and engines at higher fidelity than base."

KH.Descriptions.professions["metalworker"] = "+2 Welding.<br>Knows metal-fabrication recipes."

KH.Descriptions.professions["nurse"] = "+2 First Aid.<br>Identifies most ailments at higher fidelity than base."

KH.Descriptions.professions["officeworker"] = "+1 Electrical.<br>Starts with a small clerical kit."

KH.Descriptions.professions["parkranger"] = "+1 Aiming, +1 Trapping.<br>Forage: +75% MedicinalPlants, +50% WildPlants/WildHerbs, plus minor bonuses to Animals, Berries, Mushrooms, ForestRarities, Trash, Junk.<br>Vision +2.0 while foraging."

KH.Descriptions.professions["policeofficer"] = "+1 Aiming, +1 Reloading, +1 Nightstick.<br>Starts with police gear."

KH.Descriptions.professions["securityguard"] = "+1 Aiming, +1 Reloading."

KH.Descriptions.professions["veteran"] = "+1 Aiming, +1 Reloading.<br>Starts with the Desensitized trait (immune to most panic from zombies and corpses).<br>Forage: +5% Animals, +50% Ammunition, +20% MedicinalPlants, +10% WildPlants/WildHerbs, +5% ForestRarities.<br>Vision +1.75."

return KH.Descriptions
