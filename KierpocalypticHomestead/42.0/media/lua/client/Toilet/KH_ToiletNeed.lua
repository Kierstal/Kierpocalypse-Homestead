-- Kierpocalyptic Homestead - Toilet need + accident handler
--
-- modData float 0..100. Rises with eat/drink events. Relief via the
-- KH_UseToiletAction (separate file) or by going outdoors with optional
-- mood penalty. Hard-fail accident at 100 with cooldown.
--
-- Eat/drink events: vanilla doesn't expose a clean OnEat/OnDrink event
-- for Lua. We approximate by polling hunger/thirst deltas every minute
-- and bumping toilet need when they decrease (i.e. you just ate/drank).

require "Needs/KH_NeedsCore"
require "Thoughts/KH_Thoughts"
require "Compat/KH_ModCompat"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ToiletNeed = "0.0.1"
KH.Toilet = KH.Toilet or {}

local NEED_KEY = "KH_toiletNeed"
local LAST_HUNGER_KEY = "KH_lastHunger"
local LAST_THIRST_KEY = "KH_lastThirst"
local LAST_ACCIDENT_KEY = "KH_lastToiletAccidentHours"

local THRESHOLDS = { 35, 65, 90 }  -- tier 1=urge, 2=urgent, 3=emergency
local ACCIDENT_THRESHOLD = 100     -- when need hits this, accident triggers
local ACCIDENT_COOLDOWN_HOURS = 24

local BASE_RISE = 0.05  -- per minute baseline (~33 hrs to full from 0; eat/drink front-loads)

local DELTAS = {
    [0] = nil,
    [1] = nil,
    [2] = { stress = 0.001, unhappiness = 0.2, stressCap = 0.7, unhappinessCap = 70 },
    [3] = { stress = 0.003, unhappiness = 0.5, stressCap = 0.85, unhappinessCap = 85 },
}

local function getRiseMult(player)
    if KH.hasTrait and KH.hasTrait(player, "KH:ToughBladder") then return 0.6 end
    if KH.hasTrait and KH.hasTrait(player, "KH:WeakBladder") then return 1.5 end
    return 1.0
end

local function hours()
    local gt = getGameTime()
    if not gt then return 0 end
    return gt:getWorldAgeHours() or 0
end

-- Accident handler. Public so KH_UseToiletAction can call into us cleanly.
function KH.Toilet.triggerAccident(player)
    if not player then return end
    local d = player:getModData()
    local last = d[LAST_ACCIDENT_KEY] or -ACCIDENT_COOLDOWN_HOURS * 2
    if (hours() - last) < ACCIDENT_COOLDOWN_HOURS then return end
    d[LAST_ACCIDENT_KEY] = hours()
    -- Effects: +25 unhappiness, +20 bath need, soil worn clothes
    local body = player:getBodyDamage()
    if body then
        local u = stats:get(CharacterStat.UNHAPPINESS) or 0
        stats:set(CharacterStat.UNHAPPINESS, math.min(100, u + 25))
    end
    if KH.Bath and KH.Bath.bump then KH.Bath.bump(player, 20) end
    -- Soil clothing
    local worn = player.getWornItems and player:getWornItems()
    if worn and worn.size then
        for i = 0, worn:size() - 1 do
            local wi = worn:get(i)
            local it = wi and wi.getItem and wi:getItem()
            if it and it.getDirtiness and it.setDirtiness then
                local dty = it:getDirtiness() or 0
                pcall(function() it:setDirtiness(math.min(100, dty + 30)) end)
            end
        end
    end
    -- Reset the need (you just relieved yourself, even if disastrously)
    KH.Needs.set(player, NEED_KEY, 0)
    KH.Thoughts.emitForce(player, "toilet", "accident")
end

local function tick()
    local player = getPlayer()
    if not player or player:isDead() then return end
    -- Lifestyle: Hobbies owns the toilet axis when present + toggle on.
    if KH.deferToilet and KH.deferToilet() then return end
    local d = player:getModData()
    local stats = player:getStats()
    if not stats then return end

    -- Approximate eat/drink via hunger/thirst deltas
    local hunger = 0
    local thirst = 0
    pcall(function() hunger = stats:get(CharacterStat.HUNGER) or 0 end)
    pcall(function() thirst = stats:get(CharacterStat.THIRST) or 0 end)
    local lastH = tonumber(d[LAST_HUNGER_KEY]) or hunger
    local lastT = tonumber(d[LAST_THIRST_KEY]) or thirst
    if hunger < lastH - 0.02 then
        -- ate; bump need by the amount of hunger reduction scaled
        KH.Needs.add(player, NEED_KEY, (lastH - hunger) * 30)
    end
    if thirst < lastT - 0.02 then
        KH.Needs.add(player, NEED_KEY, (lastT - thirst) * 40)
    end
    d[LAST_HUNGER_KEY] = hunger
    d[LAST_THIRST_KEY] = thirst

    -- Baseline rise
    KH.Needs.add(player, NEED_KEY, BASE_RISE * getRiseMult(player))

    local value = KH.Needs.get(player, NEED_KEY)

    -- Accident
    if value >= ACCIDENT_THRESHOLD then
        KH.Toilet.triggerAccident(player)
        return
    end

    local tier = KH.Needs.tier(value, THRESHOLDS)
    local delta = DELTAS[tier]
    if delta then
        KH.Needs.applyMoodDelta(player, delta)
    end

    local crossing = KH.Needs.checkCrossing(player, NEED_KEY, value, THRESHOLDS)
    if crossing then
        if crossing.direction == "up" and crossing.newTier == 1 then
            KH.Thoughts.emit(player, "toilet", "urge")
        elseif crossing.direction == "up" and crossing.newTier == 2 then
            KH.Thoughts.emit(player, "toilet", "urgent")
        elseif crossing.direction == "up" and crossing.newTier == 3 then
            KH.Thoughts.emit(player, "toilet", "emergency")
        elseif crossing.direction == "down" and crossing.newTier == 0 then
            KH.Thoughts.emit(player, "toilet", "relieved")
        end
    end
end

Events.EveryOneMinute.Add(tick)

-- Public API
function KH.Toilet.relieve(player, outdoors)
    if not player then return end
    KH.Needs.set(player, NEED_KEY, 0)
    if outdoors and not (KH.hasTrait and KH.hasTrait(player, "outdoorsman")) then
        -- Small mood penalty for going outside instead of a toilet
        local body = player:getBodyDamage()
        if body then
            local u = stats:get(CharacterStat.UNHAPPINESS) or 0
            stats:set(CharacterStat.UNHAPPINESS, math.min(100, u + 3))
        end
    end
    KH.Thoughts.emit(player, "toilet", "relieved")
end

function KH.Toilet.get(player) return KH.Needs.get(player, NEED_KEY) end

print("[KH] Toilet need module loaded")
