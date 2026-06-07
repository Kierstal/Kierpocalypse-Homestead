-- Kierpocalyptic Homestead - Zombies trip while running
--
-- Per-minute tick. Iterates cell zombies within ~20 tiles of the player
-- (squared distance < 400). For each running zombie, rolls a percent
-- chance to trip (knockdown). Rain amplifies the chance.
--
-- Sandbox knobs (see Translate/EN/UI.json):
--   KH_ZombieTrip                  -- base chance per tick (default 2%)
--   KH_ZombieTripRainMultiplier    -- multiplier when raining (default 2.5x)

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ZombieTrip = "0.0.1"

local function getBaseChance()
    local s = getSandboxOptions and getSandboxOptions()
    if not s then return 2 end
    if s.getOptionByName then
        local ok, opt = pcall(function() return s:getOptionByName("KH_ZombieTrip") end)
        if ok and opt and opt.getValue then
            local v = opt:getValue()
            if v then return tonumber(v) or 2 end
        end
    end
    return 2
end

local function getRainMult()
    local s = getSandboxOptions and getSandboxOptions()
    if not s then return 2.5 end
    if s.getOptionByName then
        local ok, opt = pcall(function() return s:getOptionByName("KH_ZombieTripRainMultiplier") end)
        if ok and opt and opt.getValue then
            local v = opt:getValue()
            if v then return tonumber(v) or 2.5 end
        end
    end
    return 2.5
end

local function rainMultiplierNow()
    local cm = getClimateManager and getClimateManager()
    if not cm or not cm.getPrecipitationIntensity then return 1.0 end
    local ok, ri = pcall(function() return cm:getPrecipitationIntensity() or 0 end)
    if ok and ri and ri > 0.5 then
        return getRainMult()
    end
    return 1.0
end

local function tick()
    local p = getPlayer()
    if not p or p:isDead() then return end
    local base = getBaseChance()
    if base <= 0 then return end
    local mult = rainMultiplierNow()
    local chance = math.floor(base * mult + 0.5)
    if chance <= 0 then return end

    local cell = getCell()
    if not cell or not cell.getObjectListForLua then return end
    local objs = cell:getObjectListForLua()
    if not objs or not objs.size then return end

    local px, py = p:getX(), p:getY()
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        if o and instanceof(o, "IsoZombie") then
            local d2 = (o:getX() - px)^2 + (o:getY() - py)^2
            if d2 < 400 then
                local running = false
                if o.isRunning then
                    pcall(function() running = o:isRunning() end)
                end
                -- B42 zombies have a sprint/run distinction; either qualifies
                if not running and o.isSprinting then
                    pcall(function() running = o:isSprinting() end)
                end
                -- Skip already-knocked-down/crawler zombies
                local alreadyDown = false
                -- isCrawling() is the vanilla check for a downed zombie
                if o.isCrawling then
                    pcall(function() alreadyDown = o:isCrawling() end)
                end
                if running and not alreadyDown then
                    if ZombRand(100) < chance then
                        -- Trip it
                        if o.knockDown then
                            -- vanilla: zombie:knockDown(hitFromBehind)
                            pcall(function() o:knockDown(false) end)
                        end
                        -- Falling damage / stumble visuals are engine-handled
                    end
                end
            end
        end
    end
end

Events.EveryOneMinute.Add(tick)

print("[KH] Zombie trip module hooked")
