-- Kierpocalyptic Homestead - Bath need
--
-- modData float 0..100 on player. Rises with time + sweat (heat + sprint)
-- + visible-dirt events. Relief: wrap ISWashYourself:perform to reset.
--
-- Visible effects route through Stress + Unhappiness at high thresholds.

require "Needs/KH_NeedsCore"
require "Thoughts/KH_Thoughts"
require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.BathNeed = "0.0.1"

local NEED_KEY = "KH_bathNeed"
local THRESHOLDS = { 30, 55, 80 }  -- tier 1=mildly, 2=needs bath, 3=desperate

-- per-minute base rise rate (BEFORE trait modifiers + activity)
local BASE_RISE = 0.07   -- ~14 minutes per percent at rest

-- Effect deltas per tier (per minute)
local DELTAS = {
    [0] = nil,
    [1] = nil,
    [2] = { stress = 0.002, unhappiness = 0.3, stressCap = 0.85, unhappinessCap = 85 },
    [3] = { stress = 0.004, unhappiness = 0.6, stressCap = 0.95, unhappinessCap = 95 },
}

local function getRiseMult(player)
    local mult = 1.0
    -- Outdoorsy: -10%
    if KH.hasTrait and KH.hasTrait(player, "outdoorsman") then
        mult = mult * 0.9
    end
    -- Hot weather: faster
    local cm = getClimateManager and getClimateManager()
    if cm and cm.getTemperature then
        local t = 0
        pcall(function() t = cm:getTemperature() or 0 end)
        if t > 28 then mult = mult * 1.4
        elseif t > 22 then mult = mult * 1.15 end
    end
    -- Sprinting / running raises it faster
    if player.isSprinting and player:isSprinting() then
        mult = mult * 1.5
    elseif player.IsRunning and player:IsRunning() then
        mult = mult * 1.2
    end
    return mult
end

local function tick()
    local player = getPlayer()
    if not player or player:isDead() then return end
    -- Lifestyle: Hobbies owns hygiene when present + toggle on -> stay dormant.
    if KH.deferHygiene and KH.deferHygiene() then return end

    local rise = BASE_RISE * getRiseMult(player)
    KH.Needs.add(player, NEED_KEY, rise)

    local value = KH.Needs.get(player, NEED_KEY)
    local tier = KH.Needs.tier(value, THRESHOLDS)

    -- Bath need also amplifies personal dirtiness accumulation at high tiers
    -- (you stop bothering). We don't directly touch dirt here -- the dirt
    -- moodlet reads its own values. Bath thresholds just unlock thought lines
    -- and stress penalties.

    local delta = DELTAS[tier]
    if delta then
        local penaltyMult = KH.Needs.cleanlinessModifiers(player)
        KH.Needs.applyMoodDelta(player, KH.Needs.scaledDelta(delta, penaltyMult))
    end

    -- Thought line crossings
    local crossing = KH.Needs.checkCrossing(player, NEED_KEY, value, THRESHOLDS)
    if crossing then
        if crossing.direction == "up" and crossing.newTier == 2 then
            KH.Thoughts.emit(player, "bath", "needsBath")
        elseif crossing.direction == "up" and crossing.newTier == 3 then
            KH.Thoughts.emit(player, "bath", "desperateBath")
        elseif crossing.direction == "down" and crossing.newTier == 0 then
            KH.Thoughts.emit(player, "bath", "fresh")
        end
    end
end

Events.EveryOneMinute.Add(tick)

-- Wash hook: wrap ISWashYourself:perform to reset bath need.
Events.OnGameStart.Add(function()
    if not ISWashYourself or ISWashYourself._kh_wrapped then return end
    local _orig = ISWashYourself.perform
    function ISWashYourself:perform()
        local result = _orig(self)
        if self.character and not (KH.deferHygiene and KH.deferHygiene()) then
            local before = KH.Needs.get(self.character, NEED_KEY)
            KH.Needs.set(self.character, NEED_KEY, 0)
            if before >= 30 then
                KH.Thoughts.emit(self.character, "bath", "afterWash")
            end
        end
        return result
    end
    ISWashYourself._kh_wrapped = true
    print("[KH] ISWashYourself:perform wrapped for bath-need reset")
end)

-- Public API for other modules (e.g. accident -> bath need spike)
KH.Bath = KH.Bath or {}
function KH.Bath.bump(player, amount)
    KH.Needs.add(player, NEED_KEY, amount or 5)
end
function KH.Bath.get(player) return KH.Needs.get(player, NEED_KEY) end
function KH.Bath.set(player, v) KH.Needs.set(player, NEED_KEY, v) end

print("[KH] Bath need module loaded")
