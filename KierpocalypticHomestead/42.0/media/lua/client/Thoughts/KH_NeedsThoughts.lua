-- Kierpocalyptic Homestead - vanilla need threshold reminders (lane 3)
--
-- Reads vanilla player stats every minute. Fires a thought when the
-- player crosses UP into a new tier on hunger / thirst / fatigue /
-- boredom. The dispatcher's per-(category,key) cooldown means each
-- tier line fires at most once per 30 minutes - so oscillating around
-- a threshold won't spam.
--
-- See project_kh_halo_text_philosophy.md (memory) for the four-lane
-- framework this module serves. This is purely lane 3: ADHD-friendly
-- "you forgot about this" surfacing.

require "Needs/KH_NeedsCore"
require "Thoughts/KH_Thoughts"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.NeedsThoughts = "0.0.1"

-- Synthetic modData keys for crossing tracking (separate from the KH
-- internal need scores; these track tier-state for vanilla stats).
local KEY_HUNGER  = "KH_thoughtTier_hunger"
local KEY_THIRST  = "KH_thoughtTier_thirst"
local KEY_FATIGUE = "KH_thoughtTier_fatigue"
local KEY_BOREDOM = "KH_thoughtTier_boredom"

-- Cutoffs on a 0..100 scale. Vanilla hunger/thirst/fatigue are 0..1, so
-- we scale by 100 before checking. Boredom is already 0..100.
local CUTOFFS_HUNGER  = { 25, 50, 75 }   -- hungry, veryHungry, starving
local CUTOFFS_THIRST  = { 25, 50, 75 }   -- thirsty, veryThirsty, parched
local CUTOFFS_FATIGUE = { 40, 65, 85 }   -- tired, exhausted, dropping
local CUTOFFS_BOREDOM = { 40, 70 }       -- bored, veryBored

-- Tier index -> thought key
local KEYS_HUNGER  = { [1] = "hungry",  [2] = "veryHungry",  [3] = "starving" }
local KEYS_THIRST  = { [1] = "thirsty", [2] = "veryThirsty", [3] = "parched"  }
local KEYS_FATIGUE = { [1] = "tired",   [2] = "exhausted",   [3] = "dropping" }
local KEYS_BOREDOM = { [1] = "bored",   [2] = "veryBored"                     }

local function safeStat(player, getter)
    local v = 0
    pcall(function()
        local stats = player:getStats()
        if stats and stats[getter] then v = stats[getter](stats) or 0 end
    end)
    return v
end

local function safeBodyDamage(player, getter)
    local v = 0
    pcall(function()
        local bd = player:getBodyDamage()
        if bd and bd[getter] then v = bd[getter](bd) or 0 end
    end)
    return v
end

local function checkAndEmit(player, scoreKey, value, cutoffs, keyMap, category)
    if not player or not value then return end
    local crossing = KH.Needs.checkCrossing(player, scoreKey, value, cutoffs)
    if not crossing then return end
    -- Only fire on UPWARD crossings - relief lines could come later if
    -- you want them, but ADHD reminders are specifically about catching
    -- the rise, not celebrating the fall.
    if crossing.direction ~= "up" then return end
    local newTier = crossing.newTier
    local thoughtKey = keyMap[newTier]
    if not thoughtKey then return end
    pcall(function() KH.Thoughts.emit(player, category, thoughtKey) end)
end

local function tick()
    local player = getPlayer()
    if not player or player:isDead() then return end
    if not (KH and KH.Thoughts and KH.Needs and KH.Needs.checkCrossing) then return end

    -- Vanilla stats are 0..1, scale to 0..100 for our cutoffs.
    local hunger  = safeStat(player, "getHunger")  * 100
    local thirst  = safeStat(player, "getThirst")  * 100
    local fatigue = safeStat(player, "getFatigue") * 100
    -- Boredom: BodyDamage already returns 0..100.
    local boredom = safeBodyDamage(player, "getBoredomLevel")

    checkAndEmit(player, KEY_HUNGER,  hunger,  CUTOFFS_HUNGER,  KEYS_HUNGER,  "needs")
    checkAndEmit(player, KEY_THIRST,  thirst,  CUTOFFS_THIRST,  KEYS_THIRST,  "needs")
    checkAndEmit(player, KEY_FATIGUE, fatigue, CUTOFFS_FATIGUE, KEYS_FATIGUE, "needs")
    checkAndEmit(player, KEY_BOREDOM, boredom, CUTOFFS_BOREDOM, KEYS_BOREDOM, "needs")
end

Events.EveryOneMinute.Add(tick)

print("[KH] Needs-thoughts module loaded (lane 3 reminders)")
