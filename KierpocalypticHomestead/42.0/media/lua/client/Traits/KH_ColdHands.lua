-- Kierpocalyptic Homestead - Cold Hands
--
-- If the player has KH:ColdHands and the ambient temperature where they're
-- standing is below the cold threshold, timed actions for crafting categories
-- take 25% longer. We hook ISBaseTimedAction:getDuration via a chain on
-- adjustMaxTime for the specific action subclasses we care about.
--
-- Lightweight approach: instead of patching every craft action class, we
-- patch ISInventoryTransferAction (no - that's too broad) ... actually, the
-- cleanest path is to multiply self.maxTime AT the start of each timed
-- action, only when the action is a known crafting type. We wrap
-- ISBaseTimedAction:start() and bump maxTime by 1.25 for matching subclasses
-- when the trait + cold gate are both active.

require "TimedActions/ISBaseTimedAction"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ColdHands = "0.0.1"

local COLD_THRESHOLD_C = 5  -- ambient °C below which hands stiffen
local SLOWDOWN_FACTOR  = 1.25

-- Class-name substrings that count as "fine motor crafting" actions.
-- We match on ISBaseTimedAction subclass type so we don't have to know
-- every class by hand. The check is `class name contains any substring`.
local CRAFT_ACTION_NEEDLES = {
    "ISCraftAction",          -- vanilla generic crafting
    "ISSew",                  -- tailoring (sew, repair, hem, etc.)
    "ISFitClothing",          -- tailoring fit
    "ISRepairClothing",       -- patch / repair
    "ISCleanClothing",        -- handwash
    "ISCookFood",             -- prep food
    "ISCutOpen",              -- can opener actions
    "ISGutAnimal",
    "ISDisassemble",
    "ISTakeApart",
    "ISRepairElectronic",
    "ISDismantleElectronic",
}

local function isColdAtPlayer(p)
    local cm = getClimateManager(); if not cm then return false end
    -- B42 climate exposes getTemperature (current world temp in °C)
    local temp
    pcall(function()
        if cm.getTemperature then temp = cm:getTemperature() end
    end)
    if not temp then return false end
    return temp < COLD_THRESHOLD_C
end

local function actionIsCraftLike(action)
    if not action or not action.Type then return false end
    -- action.Type is the string class name. Match against our needles.
    local t = tostring(action.Type)
    for _, needle in ipairs(CRAFT_ACTION_NEEDLES) do
        if t:find(needle, 1, true) then return true end
    end
    return false
end

-- Wrap start() to bump maxTime when the gates pass. We don't replace start
-- entirely - we wrap so vanilla logic still runs.
local _origStart = ISBaseTimedAction.start
function ISBaseTimedAction:start()
    local result
    pcall(function()
        local char = self.character
        if char and self.maxTime and self.maxTime > 0
           and KH.hasTrait(char, "KH:ColdHands")
           and actionIsCraftLike(self)
           and isColdAtPlayer(char)
        then
            self.maxTime = self.maxTime * SLOWDOWN_FACTOR
        end
    end)
    -- Always call vanilla start (whether our adjustment happened or not)
    if _origStart then result = _origStart(self) end
    return result
end

print("[KH] ColdHands trait behavior loaded (cold-temp craft slowdown)")
