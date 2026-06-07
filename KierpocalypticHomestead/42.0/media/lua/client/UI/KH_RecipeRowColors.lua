-- Kierpocalyptic Homestead - color-coded craft recipe rows
--
-- Patches ISRecipeScrollingListBox to draw a colored left-edge stripe on
-- each recipe row based on the recipe's tool/workstation requirement.
--
-- Classification (from craftRecipe `Tags` field):
--   contains "InHandCraft"        -> green   (can craft anywhere with hands)
--   contains "AnySurfaceCraft"    -> yellow  (needs any surface/table/ground)
--   contains a known workstation  -> orange  (specific bench/forge needed)
--   anything else / unknown       -> red     (probably tag-gated or special)
--
-- The Tags accessor is the one place we expect breakage on B42 patch
-- updates. Everything is wrapped in pcall; on accessor failure we just
-- skip coloring and fall through to vanilla rendering (no crash).
--
-- NOTE: needs in-game verification. The exact getRecipe() accessor on
-- ISRecipeScrollingListBox items is best-effort here.

require "Entity/ISUI/CraftRecipe/ISRecipeScrollingListBox"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.RecipeRowColors = "0.0.1"

local STRIPE_WIDTH = 3
local COLORS = {
    inhand     = { 0.85, 0.30, 0.85, 0.30 },  -- a,r,g,b -- green
    surface    = { 0.85, 0.90, 0.85, 0.20 },  -- yellow
    workstation= { 0.85, 0.95, 0.60, 0.10 },  -- orange
    unknown    = { 0.55, 0.85, 0.25, 0.25 },  -- red (dim)
}

-- A best-effort list of workstation/bench tags found in B42 recipes.
local WORKSTATION_TAGS = {
    "Forge", "Furnace", "PrimitiveFurnace", "PrimitiveForge",
    "Bellows", "Anvil", "Loom", "SpinningWheel", "Kiln", "PotteryWheel",
    "ButterChurn", "DryLeather", "Drying", "BellowsAndForge",
    "CookingPit", "HerbDrying", "StoneMill", "StoneQuern",
    "TanninBarrel",
}

local function tagsString(recipe)
    -- Try several plausible accessors. Lupa-side these are getters on
    -- the Java CraftRecipe instance.
    if not recipe then return "" end
    for _, m in ipairs({ "getTags", "getCategory", "getRecipeTags" }) do
        if recipe[m] then
            local ok, val = pcall(function() return recipe[m](recipe) end)
            if ok and val and tostring(val) ~= "" then
                return tostring(val)
            end
        end
    end
    return ""
end

local function classifyRecipe(recipe)
    local tags = tagsString(recipe)
    if tags == "" then return "unknown" end
    -- InHandCraft is the most permissive; check it first.
    if string.find(tags, "InHandCraft", 1, true) then return "inhand" end
    if string.find(tags, "AnySurfaceCraft", 1, true) then return "surface" end
    for _, w in ipairs(WORKSTATION_TAGS) do
        if string.find(tags, w, 1, true) then return "workstation" end
    end
    return "unknown"
end

-- Wrap doDrawItem so we paint the stripe BEFORE vanilla draws icons/text.
if ISRecipeScrollingListBox and ISRecipeScrollingListBox.doDrawItem and not ISRecipeScrollingListBox._kh_patched then
    local _orig = ISRecipeScrollingListBox.doDrawItem
    function ISRecipeScrollingListBox:doDrawItem(y, item, alt)
        local recipe = item and item.item
        if recipe then
            local ok, cls = pcall(classifyRecipe, recipe)
            if ok and cls then
                local c = COLORS[cls]
                if c then
                    self:drawRect(0, y, STRIPE_WIDTH, item.height, c[1], c[2], c[3], c[4])
                end
            end
        end
        return _orig(self, y, item, alt)
    end
    ISRecipeScrollingListBox._kh_patched = true
    print("[KH] Recipe row color stripe installed on ISRecipeScrollingListBox.doDrawItem")
end
