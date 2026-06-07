-- Kierpocalyptic Homestead - Nutritionist UI extension
--
-- Shows full nutrition breakdown in the Character Info panel for players with
-- the Nutritionist trait (vanilla "nutritionist" or profession "nutritionist2").
-- Adds a section under the existing trait/hair area showing Calories, Carbs,
-- Proteins, Fats, Weight.
--
-- Approach: monkey-patch ISCharacterScreen:render so we draw after the vanilla
-- render runs. Per Kierstal's prior calibration, content lands well below the
-- trait/hair row to avoid overlapping the main info section.

require "ISUI/ISPanelJoypad"
require "XpSystem/ISUI/ISCharacterScreen"
require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.NutritionPanel = "0.0.1"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local UI_BORDER_SPACING = 10

-- Layout constants. Calibrated from prior session: previous version overlapped
-- the main info section, requiring +120px to fix.
local SECTION_OFFSET_FROM_BOTTOM = 95
local ROW_HEIGHT = FONT_HGT_SMALL + 2
local PANEL_MIN_HEIGHT = 430

local function hasNutritionistTrait(player)
    if not player then return false end
    -- Route through KH.hasTrait which resolves vanilla id -> CharacterTrait
    -- Java instance via CharacterTraitDefinition. Raw player:hasTrait(string)
    -- throws "no implementation found" in B42.
    if KH and KH.hasTrait then
        if KH.hasTrait(player, "nutritionist") then return true end
        if KH.hasTrait(player, "nutritionist2") then return true end
    end
    return false
end

local function safeGet(obj, methodName, default)
    if obj and obj[methodName] then
        local ok, val = pcall(function() return obj[methodName](obj) end)
        if ok then return val end
    end
    return default
end

local original_render = ISCharacterScreen.render

function ISCharacterScreen:render()
    original_render(self)

    local player = getSpecificPlayer(self.playerNum)
    if not hasNutritionistTrait(player) then return end

    local nutrition = player:getNutrition()
    if not nutrition then return end

    -- Grow the panel if needed so our section isn't clipped
    if self:getHeight() < PANEL_MIN_HEIGHT then
        self:setHeight(PANEL_MIN_HEIGHT)
        if self.parent and self.parent.setHeight then
            self.parent:setHeight(PANEL_MIN_HEIGHT)
        end
    end

    local x = self.xOffset or UI_BORDER_SPACING
    local y = self:getHeight() - SECTION_OFFSET_FROM_BOTTOM

    self:drawText(getText("UI_KH_NutritionHeader"), x, y, 1, 1, 1, 1, UIFont.Small)
    y = y + ROW_HEIGHT + 2

    local calories = math.floor(safeGet(nutrition, "getCalories", 0) + 0.5)
    local carbs    = safeGet(nutrition, "getCarbohydrates", 0)
    local proteins = safeGet(nutrition, "getProteins", 0)
    local lipids   = safeGet(nutrition, "getLipids", 0)
    local weight   = safeGet(nutrition, "getWeight", 0)

    local labelW = 90
    local valX   = x + labelW + 6

    self:drawTextRight(getText("UI_KH_Calories")    .. ":", x + labelW, y, 1, 1, 1, 1, UIFont.Small)
    self:drawText(string.format("%d kcal", calories), valX, y, 1, 1, 1, 0.75, UIFont.Small)
    y = y + ROW_HEIGHT

    self:drawTextRight(getText("UI_KH_Carbs")       .. ":", x + labelW, y, 1, 1, 1, 1, UIFont.Small)
    self:drawText(string.format("%.1f g", carbs),    valX, y, 1, 1, 1, 0.75, UIFont.Small)
    y = y + ROW_HEIGHT

    self:drawTextRight(getText("UI_KH_Proteins")    .. ":", x + labelW, y, 1, 1, 1, 1, UIFont.Small)
    self:drawText(string.format("%.1f g", proteins), valX, y, 1, 1, 1, 0.75, UIFont.Small)
    y = y + ROW_HEIGHT

    self:drawTextRight(getText("UI_KH_Fats")        .. ":", x + labelW, y, 1, 1, 1, 1, UIFont.Small)
    self:drawText(string.format("%.1f g", lipids),   valX, y, 1, 1, 1, 0.75, UIFont.Small)
    y = y + ROW_HEIGHT

    self:drawTextRight(getText("UI_KH_Weight")      .. ":", x + labelW, y, 1, 1, 1, 1, UIFont.Small)
    self:drawText(string.format("%.1f kg", weight),  valX, y, 1, 1, 1, 0.75, UIFont.Small)
end
