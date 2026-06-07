-- Kierpocalyptic Homestead - thought triggers
--
-- Wires event hooks for every category in KH_ThoughtLines. Most categories
-- fire on regular events (EveryHours, EveryTenMinutes, etc). A few hook into
-- specific gameplay actions (zombie kill, item grab, etc.) where PZ exposes
-- the relevant event.

require "Thoughts/KH_Thoughts"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ThoughtTriggers = "0.0.2"

local function md(player) return player and player:getModData() or {} end
local function flag(player, name)
    local d = md(player)
    if d[name] then return true end
    d[name] = true
    return false
end

-- ============ Time milestones ===================================
local DAY_MILESTONES = {
    {day = 1, key = "day1"}, {day = 3, key = "day3"}, {day = 7, key = "day7"},
    {day = 14, key = "day14"}, {day = 30, key = "day30"}, {day = 60, key = "day60"},
    {day = 100, key = "day100"}, {day = 200, key = "day200"},
    {day = 365, key = "day365"}, {day = 730, key = "day730"},
}
Events.EveryDays.Add(function()
    local p = getPlayer(); if not p then return end
    local d = md(p)
    d.KH_milestonesHit = d.KH_milestonesHit or {}
    local age = getGameTime():getWorldAgeHours() / 24
    for _, m in ipairs(DAY_MILESTONES) do
        if age >= m.day and not d.KH_milestonesHit[m.key] then
            d.KH_milestonesHit[m.key] = true
            KH.Thoughts.emitForce(p, "time", m.key)
            return
        end
    end
end)

-- ============ Power / water outage ==============================
Events.EveryHours.Add(function()
    local p = getPlayer(); if not p then return end
    local d = md(p)
    local sand = getSandboxOptions and getSandboxOptions() or nil
    if not sand then return end
    local elecDay  = (SandboxVars and SandboxVars.ElecShutModifier)  or -1
    local waterDay = (SandboxVars and SandboxVars.WaterShutModifier) or -1
    local sinceApo = (SandboxVars and SandboxVars.TimeSinceApo) or 1
    local ageDays  = getGameTime():getWorldAgeHours() / 24 + (sinceApo - 1) * 30
    if elecDay > -1 and ageDays >= elecDay and not d.KH_elecOffSeen then
        d.KH_elecOffSeen = true
        KH.Thoughts.emitForce(p, "elecOff")
    end
    if waterDay > -1 and ageDays >= waterDay and not d.KH_waterOffSeen then
        d.KH_waterOffSeen = true
        KH.Thoughts.emitForce(p, "waterOff")
    end
end)

-- ============ Moodles (rising 0 -> active) ======================
local MOODLES = {"Hungry","Thirsty","Tired","Bored","Unhappy","Stressed","Panic",
                 "Wet","Cold","Sick","HeavyLoad","Pain"}
Events.EveryOneMinute.Add(function()
    local p = getPlayer(); if not p then return end
    local mood = p:getMoodles(); if not mood then return end
    local d = md(p)
    d.KH_lastMoodleLevels = d.KH_lastMoodleLevels or {}
    for _, name in ipairs(MOODLES) do
        local typ = MoodleType and (MoodleType[name:upper()] or MoodleType[name])
        if typ then
            local level = mood:getMoodleLevel(typ) or 0
            local prev = d.KH_lastMoodleLevels[name] or 0
            if level > 0 and prev == 0 then
                KH.Thoughts.emit(p, "moodle_" .. name)
            end
            d.KH_lastMoodleLevels[name] = level
        end
    end
end)

-- ============ Bleeding scan ======================================
-- Vanilla doesn't have a "Bleeding" moodle - bleeding is per-body-part
-- state via bodyPart:getBleedingTime(). Poll every minute and fire
-- moodle_Bleeding when any part has a NOTABLE bleed time. The threshold
-- is > 1.0 (not > 0) to filter trace floating-point residuals that can
-- linger after a bleed is bandaged or that ship with a fresh character.
-- COOLDOWN_OVERRIDES sets this to 1 hour so reminders repeat while the
-- bleed persists.
local BLEED_THRESHOLD = 1.0
Events.EveryOneMinute.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    local body = p:getBodyDamage(); if not body then return end
    local parts; pcall(function() parts = body:getBodyParts() end)
    if not parts or not parts.size then return end
    local bleeding = false
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part and part.getBleedingTime then
            local t = 0
            pcall(function() t = part:getBleedingTime() or 0 end)
            if t > BLEED_THRESHOLD then bleeding = true; break end
        end
    end
    if bleeding then
        KH.Thoughts.emit(p, "moodle_Bleeding")
    end
end)

-- ============ First animal encounter ============================
Events.EveryTenMinutes.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    local d = md(p)
    d.KH_seenAnimals = d.KH_seenAnimals or {}
    local cell = getCell(); if not cell then return end
    local px, py, pz = math.floor(p:getX()), math.floor(p:getY()), math.floor(p:getZ())
    for dx = -2, 2 do for dy = -2, 2 do
        local sq = cell:getGridSquare(px+dx, py+dy, pz)
        if sq then
            local mv = sq:getMovingObjects()
            if mv then
                for i = 0, mv:size() - 1 do
                    local o = mv:get(i)
                    if o and instanceof(o, "IsoAnimal") then
                        local atype = o.getAnimalType and o:getAnimalType() or "animal"
                        local base = string.match(string.lower(tostring(atype or "animal")), "^[%a]+")
                        if base and not d.KH_seenAnimals[base] then
                            d.KH_seenAnimals[base] = true
                            KH.Thoughts.emit(p, "animal", base)
                            return
                        end
                    end
                end
            end
        end
    end end
end)

-- ============ Weather changes ===================================
-- Weather lines should only fire when the player can actually see/feel
-- the weather - i.e., outdoors. We still track state every minute so that
-- when the player steps outside, we don't fire a stale "rainStart" for a
-- rain that began two hours ago while they were inside.
local lastWeatherState = {raining=false, fog=false, snow=false}
Events.EveryOneMinute.Add(function()
    local p = getPlayer(); if not p then return end
    local cm = getClimateManager(); if not cm then return end
    local outside = false
    pcall(function() outside = p.isOutside and p:isOutside() end)

    local raining = (cm.getPrecipitationIntensity and cm:getPrecipitationIntensity() or 0) >= 0.1
    if raining and not lastWeatherState.raining and outside then
        KH.Thoughts.emit(p, "weather", "rainStart")
    end
    lastWeatherState.raining = raining

    -- Thunder is now hooked via Events.OnThunderEvent (per-strike) below,
    -- so we don't poll cm:getThunderStorm() here anymore.

    local fog = (cm.getFogIntensity and cm:getFogIntensity() or 0) >= 0.4
    if fog and not lastWeatherState.fog and outside then
        KH.Thoughts.emit(p, "weather", "fog")
    end
    lastWeatherState.fog = fog
end)

-- Per-strike thunder. The OnThunderEvent fires with (x, y, strike, light,
-- rumble) for every individual thunderclap. Distance-gate so a strike on
-- the other end of the map doesn't trigger a "Windows rattled" thought.
-- The Thoughts dispatcher's 30-min per-(category,key) cooldown already
-- handles spam from repeated strikes - first strike of a storm fires the
-- line, subsequent strikes in the next 30 min stay silent.
local THUNDER_RANGE_TILES = 60  -- ~60 tiles ~= audibly close

if Events and Events.OnThunderEvent and Events.OnThunderEvent.Add then
    Events.OnThunderEvent.Add(function(sx, sy, strike, light, rumble)
        local p = getPlayer()
        if not p or p:isDead() then return end
        if not sx or not sy then return end
        local dx = sx - p:getX()
        local dy = sy - p:getY()
        if (dx*dx + dy*dy) > (THUNDER_RANGE_TILES * THUNDER_RANGE_TILES) then
            return
        end
        KH.Thoughts.emit(p, "weather", "thunder")
    end)
end

-- ============ Season transitions ================================
-- Several season lines reference outdoor observation ("Buds. Smaller things
-- first.", "Leaves turning", etc.) so we gate the trigger on the player
-- being outdoors. If they stay inside the day a season changes, the
-- KH_seasonsHit flag stays unset and the trigger retries each day until
-- they step out and "notice" the new season.
Events.EveryDays.Add(function()
    local p = getPlayer(); if not p then return end
    local outside = false
    pcall(function() outside = p.isOutside and p:isOutside() end)
    if not outside then return end
    local d = md(p)
    local month = (getGameTime() and getGameTime():getMonth() and getGameTime():getMonth() + 1) or 0
    -- PZ getMonth returns 0-11
    d.KH_seasonsHit = d.KH_seasonsHit or {}
    local key = nil
    if month == 12 and not d.KH_seasonsHit.winter then key = "winterStart"; d.KH_seasonsHit.winter = true end
    if month == 3  and not d.KH_seasonsHit.spring then key = "springStart"; d.KH_seasonsHit.spring = true end
    if month == 6  and not d.KH_seasonsHit.summer then key = "summerStart"; d.KH_seasonsHit.summer = true end
    if month == 9  and not d.KH_seasonsHit.fall   then key = "fallStart";   d.KH_seasonsHit.fall   = true end
    if key then KH.Thoughts.emitForce(p, "season", key) end
end)

-- ============ Trait/Profession ambient =========================
-- Every ~4 hours, roll to fire a trait OR profession flavor line. Splits
-- evenly. Cooldown still applies so this rarely overrides moodle/event thoughts.
-- Per-trait/profession context requirements. Traits or professions listed
-- here only fire their ambient lines when the player is in the matching
-- context. Anything not listed has no requirement (fires anywhere).
--   "outside" = only when p:isOutside() is true
--   "inside"  = only when p:isOutside() is false
local TRAIT_CONTEXT = {
    Agoraphobic    = "outside",  -- "Sky is too big" makes no sense indoors
    Claustrophobic = "inside",   -- "Walls too close" makes no sense outdoors
    Hunter         = "outside",  -- "Wind in my face. Always." - outdoor-coupled
}
local PROFESSION_CONTEXT = {
    parkranger = "outside",      -- forest/trails flavor
}

local function contextMatches(required, player)
    if not required then return true end
    if not player then return false end
    local outside = false
    pcall(function() outside = player.isOutside and player:isOutside() end)
    if required == "outside" then return outside end
    if required == "inside"  then return not outside end
    return true
end

local function pickOwnedTraitWithLines(player)
    if not KH.ThoughtLines or not KH.ThoughtLines.traitAmbient then return nil end
    local owned = {}
    -- Try our KH-namespaced traits and vanilla traits
    if player.getCharacterTraits then
        local ct = player:getCharacterTraits()
        local l = ct and ct.getKnownTraits and ct:getKnownTraits() or nil
        if l and l.size then
            for i = 0, l:size() - 1 do
                local t = l:get(i)
                if t then
                    local name = nil
                    if t.getName then
                        local ok = pcall(function() name = t:getName() end)
                        if not ok then name = nil end
                    end
                    if not name then
                        local s = tostring(t)
                        name = string.match(s, "([^:%.]+)$") or s
                    end
                    if name and KH.ThoughtLines.traitAmbient[name]
                       and contextMatches(TRAIT_CONTEXT[name], player) then
                        table.insert(owned, name)
                    end
                end
            end
        end
    end
    if #owned == 0 then return nil end
    return owned[ZombRand(#owned) + 1]
end

local function pickProfessionWithLines(player)
    if not KH.ThoughtLines or not KH.ThoughtLines.professionAmbient then return nil end
    if not (player.getDescriptor and player:getDescriptor()) then return nil end
    local prof = player:getDescriptor():getCharacterProfession()
    if not (prof and prof.getName) then return nil end
    local name = prof:getName()
    if not name then return nil end
    if KH.ThoughtLines.professionAmbient[name]
       and contextMatches(PROFESSION_CONTEXT[name], player) then
        return name
    end
    -- Case-insensitive fallback (vanilla professions are lowercase but be safe)
    local lower = string.lower(name)
    if KH.ThoughtLines.professionAmbient[lower]
       and contextMatches(PROFESSION_CONTEXT[lower], player) then
        return lower
    end
    return nil
end

Events.EveryHours.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    -- ~25% chance per hour to attempt ambient (so average ~4hr between)
    if ZombRand(4) ~= 0 then return end
    -- 50/50 trait vs profession
    if ZombRand(2) == 0 then
        local t = pickOwnedTraitWithLines(p)
        if t then
            local pool = KH.ThoughtLines.traitAmbient[t]
            local line = pool and pool[ZombRand(#pool) + 1]
            if line then
                if HaloTextHelper and HaloTextHelper.addText then
                    -- Inline because the dispatcher's emit needs a category structure
                    if not (p:getModData() and (worldAgeMinutesCoolDownCheck and worldAgeMinutesCoolDownCheck(p))) then
                        HaloTextHelper.addText(p, line)
                    end
                end
            end
        end
    else
        local prof = pickProfessionWithLines(p)
        if prof then
            local pool = KH.ThoughtLines.professionAmbient[prof]
            local line = pool and pool[ZombRand(#pool) + 1]
            if line and HaloTextHelper and HaloTextHelper.addText then
                HaloTextHelper.addText(p, line)
            end
        end
    end
end)

-- ============ Memory / Alone =====================================
-- Gated on mood prerequisites so we don't fire "I talk to walls now" at
-- noon on day 1 when boredom isn't yet meaningful. Vanilla MoodleType is
-- a Java enum -- access via MoodleType.Bored / MoodleType.Unhappy /
-- MoodleType.Stress. getMoodleLevel returns 0..4 (no moodle .. severe).
local function moodlePresent(player, kind, minLevel)
    if not player or not player.getMoodles then return false end
    local moodles = player:getMoodles()
    if not moodles or not moodles.getMoodleLevel then return false end
    local mt = MoodleType and MoodleType[kind]
    if not mt then return false end
    local lvl = 0
    pcall(function() lvl = moodles:getMoodleLevel(mt) or 0 end)
    return lvl >= (minLevel or 1)
end

Events.EveryHours.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    -- About once every 6 hours
    if ZombRand(6) ~= 0 then return end
    -- 50/50 memory vs alone. Memory needs Unhappy>=1 (you have to be IN
    -- the mood to dwell). Alone needs Bored>=1 (talking-to-walls only
    -- makes sense once you've noticed the silence).
    if ZombRand(2) == 0 then
        if moodlePresent(p, "Unhappy", 1) then
            KH.Thoughts.emit(p, "memory")
        end
    else
        if moodlePresent(p, "Bored", 1) then
            KH.Thoughts.emit(p, "alone")
        end
    end
end)

-- ============ First zombie events ===============================
-- "Visible" means: same Z-level AND the zombie's square is currently CanSee
-- to the player (PZ's LOS check that respects walls/floors). A zombie in the
-- upstairs bathroom of the house we're walking past has the same XY proximity
-- but different Z and/or no LOS, so it shouldn't trigger.
local function _zombieVisibleToPlayer(p, z)
    if not p or not z then return false end
    if z:getZ() ~= p:getZ() then return false end
    local sq; pcall(function() sq = z:getSquare() end)
    if not sq then return false end
    local pn = (p.getPlayerNum and p:getPlayerNum()) or 0
    local can = false
    pcall(function() can = sq:isCanSee(pn) end)
    return can
end

Events.EveryOneMinute.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    local d = md(p)

    -- BWO bandits are IsoZombies in code with a bandit flag. They are NOT
    -- zombies thematically - they're alive NPCs. Filter them out of the
    -- first-zombie triggers so "Seen pictures, different in person" doesn't
    -- fire on the first parent Wilda meets in a house.
    --
    -- API-existence preflight: if Bandit or Bandit.IsBandit isn't loaded yet,
    -- treat as "not a bandit" so we just process the zombie normally. Avoids
    -- pcall noise from calling nil that Java logs even when Lua catches it.
    local _BanditAPI = _G.Bandit
    local _BanditIsBandit = _BanditAPI and _BanditAPI.IsBandit
    local function _isLivingBandit(o)
        if not o or not _BanditIsBandit then return false end
        local isB = false
        pcall(function() isB = _BanditIsBandit(o) end)
        if not isB then return false end
        local dead = true
        pcall(function() dead = o:isDead() end)
        return not dead
    end

    -- First sighted: within 8 tiles, same Z, and the zombie's tile is in
    -- the player's actual line of sight (walls block, floors above block).
    if not d.KH_firstZSighted then
        local cell = getCell()
        if cell and cell.getObjectListForLua then
            local objs = cell:getObjectListForLua()
            if objs then
                local px, py = p:getX(), p:getY()
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    if o and instanceof(o, "IsoZombie") and not _isLivingBandit(o) then
                        local d2 = (o:getX() - px)^2 + (o:getY() - py)^2
                        if d2 < 64 and _zombieVisibleToPlayer(p, o) then
                            d.KH_firstZSighted = true
                            KH.Thoughts.emit(p, "firstZombie", "firstSighted")
                            break
                        end
                    end
                end
            end
        end
    end

    -- First horde: >= 15 VISIBLE zombies within ~20 tiles. Same LOS gate -
    -- a horde you can't see is just spooky ambient sound, not "first horde".
    -- Bandits also excluded from the horde count - a crowd of NPCs at a
    -- BWO party is not a horde.
    if not d.KH_firstHorde then
        local cell = getCell()
        if cell and cell.getObjectListForLua then
            local objs = cell:getObjectListForLua()
            if objs then
                local px, py = p:getX(), p:getY()
                local count = 0
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    if o and instanceof(o, "IsoZombie") and not _isLivingBandit(o) then
                        local d2 = (o:getX() - px)^2 + (o:getY() - py)^2
                        if d2 < 400 and _zombieVisibleToPlayer(p, o) then
                            count = count + 1
                        end
                    end
                end
                if count >= 15 then
                    d.KH_firstHorde = true
                    KH.Thoughts.emit(p, "firstZombie", "firstHorde")
                end
            end
        end
    end

    -- First kill: poll zombie kill count
    if p.getZombieKills then
        local kills = p:getZombieKills() or 0
        if kills > 0 and not d.KH_firstKill then
            d.KH_firstKill = true
            KH.Thoughts.emitForce(p, "firstZombie", "firstKill")
        end
    end
end)

-- ============ Rare item discovery ===============================
-- Poll inventory periodically. Fire on first time the player has an item
-- whose Base.id is keyed in KH.ThoughtLines.rareItem.
Events.EveryOneMinute.Add(function()
    local p = getPlayer(); if not p then return end
    if not (KH.ThoughtLines and KH.ThoughtLines.rareItem) then return end
    local inv = p:getInventory(); if not inv then return end
    local d = md(p)
    d.KH_seenRare = d.KH_seenRare or {}
    local items = inv:getItems(); if not items then return end
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it.getFullType then
            local ft = it:getFullType()
            if KH.ThoughtLines.rareItem[ft] and not d.KH_seenRare[ft] then
                d.KH_seenRare[ft] = true
                KH.Thoughts.emit(p, "rareItem", ft)
                return  -- one per check
            end
        end
    end
end)

-- ============ Location-aware thoughts ===========================
-- When the player's current building's room is named like a known category,
-- fire a thought. Two kinds:
--   1) GENERIC location thought (e.g. "Hospital. Smell of disinfectant.")
--      always fires on first entry of that location type.
--   2) ENTITY-SPECIFIC location thought (e.g. "The fridge hums on...") only
--      fires if the entity that line references is actually present + (where
--      relevant) powered. These are stored as "<location>_<entity>" keys
--      in KH.ThoughtLines.location, separately one-shot from the generic
--      version, so the same player can hear both lines over time without
--      either firing inappropriately.
local LOCATION_KEYS = {
    "hospital", "school", "library", "church", "gunstore",
    "police", "fireStation", "warehouse", "garage", "kitchen",
}

-- Tile-scan helper. Returns true if any IsoObject within `radius` tiles of
-- the player satisfies `predicate(obj, square)`. radius defaults to 4 (an
-- 8x8 area around the player, big enough to cover a small room).
local function nearbyHas(p, predicate, radius)
    radius = radius or 4
    local sq = p and p.getCurrentSquare and p:getCurrentSquare()
    if not sq then return false end
    local cell = sq:getCell() or (getCell and getCell())
    if not cell then return false end
    local x0, y0, z0 = sq:getX(), sq:getY(), sq:getZ()
    for dx = -radius, radius do
        for dy = -radius, radius do
            local s
            pcall(function() s = cell:getGridSquare(x0 + dx, y0 + dy, z0) end)
            if s then
                local objs; pcall(function() objs = s:getObjects() end)
                local n = (objs and objs.size) and objs:size() or 0
                for i = 0, n - 1 do
                    local o; pcall(function() o = objs:get(i) end)
                    if o then
                        local ok, hit = pcall(predicate, o, s)
                        if ok and hit then return true end
                    end
                end
            end
        end
    end
    return false
end

-- Predicates for the entity checks each location line cares about.
local function _isPoweredFridge(o, s)
    if not o or not o.getContainer then return false end
    local c; pcall(function() c = o:getContainer() end)
    if not c or not c.getType then return false end
    local t; pcall(function() t = c:getType() end)
    if t ~= "fridge" and t ~= "freezer" then return false end
    if not s or not s.haveElectricity then return false end
    return s:haveElectricity()
end

-- Generic sprite-name substring check for furniture without a clean
-- container/class signal. We can't rely on instanceof since most furniture
-- in PZ is plain IsoObject differentiated only by sprite. Sprite naming
-- is consistent enough across vanilla tilepacks to use as a hint.
local function _hasSpriteContaining(o, needle)
    if not o or not o.getSprite then return false end
    local spr; pcall(function() spr = o:getSprite() end)
    if not spr or not spr.getName then return false end
    local name; pcall(function() name = spr:getName() end)
    if not name then return false end
    return string.find(string.lower(name), needle, 1, true) ~= nil
end

local function _isFireTruck(o)
    -- B42 vehicles aren't IsoObjects on a square - they're BaseVehicles
    -- discovered via getCell():getVehicles(). nearbyHas won't find them.
    -- Always return false here so the generic helper short-circuits; the
    -- caller uses _vehicleNearbyMatches instead.
    return false
end

local function _vehicleNearbyMatches(p, scriptNameSubstr, radius)
    radius = radius or 16
    local sq = p and p:getCurrentSquare(); if not sq then return false end
    local cell = (getCell and getCell()) or sq:getCell()
    if not cell or not cell.getVehicles then return false end
    local list; pcall(function() list = cell:getVehicles() end)
    if not list or not list.size then return false end
    local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
    for i = 0, list:size() - 1 do
        local v; pcall(function() v = list:get(i) end)
        if v then
            local vx, vy, vz
            pcall(function() vx = v:getX(); vy = v:getY(); vz = v:getZ() end)
            if vx and vy and vz and math.abs(vx - px) <= radius and math.abs(vy - py) <= radius and vz == pz then
                local script; pcall(function() script = v:getScript() end)
                local nm; pcall(function() nm = script and script:getName() or v:getScriptName() end)
                if nm and string.find(string.lower(tostring(nm)), scriptNameSubstr, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

-- Entity checks per location. Each returns true if the line should fire.
-- Map: location -> { entityKey -> probeFunction(p) -> boolean }
local LOCATION_ENTITY_PROBES = {
    kitchen = {
        fridge = function(p) return nearbyHas(p, _isPoweredFridge, 4) end,
    },
    library = {
        bookshelf = function(p) return nearbyHas(p, function(o) return _hasSpriteContaining(o, "bookcase") or _hasSpriteContaining(o, "bookshelf") end, 5) end,
    },
    garage = {
        toolwall = function(p) return nearbyHas(p, function(o) return _hasSpriteContaining(o, "shelf") or _hasSpriteContaining(o, "tool") end, 5) end,
    },
    warehouse = {
        pallets = function(p) return nearbyHas(p, function(o) return _hasSpriteContaining(o, "pallet") or _hasSpriteContaining(o, "crate") end, 6) end,
    },
    fireStation = {
        truck = function(p) return _vehicleNearbyMatches(p, "fire", 20) end,
    },
    police = {
        cells = function(p) return nearbyHas(p, function(o) return _hasSpriteContaining(o, "jail") or _hasSpriteContaining(o, "bar_") end, 6) end,
    },
}

Events.EveryTenMinutes.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    local sq = p:getCurrentSquare(); if not sq then return end
    local room = sq:getRoom(); if not room then return end
    local roomDef = room.getRoomDef and room:getRoomDef()
    local roomName = roomDef and roomDef.getName and roomDef:getName() or ""
    if not roomName or roomName == "" then return end
    local lower = string.lower(tostring(roomName))
    local d = md(p)
    d.KH_seenLocations = d.KH_seenLocations or {}
    for _, key in ipairs(LOCATION_KEYS) do
        if string.find(lower, string.lower(key), 1, true) then
            -- 1) Fire generic (entity-agnostic) thought once per location.
            if not d.KH_seenLocations[key] then
                d.KH_seenLocations[key] = true
                KH.Thoughts.emit(p, "location", key)
            end
            -- 2) Fire entity-specific thoughts when their target object is
            -- actually present. Each sub-key is one-shot. Iterate all the
            -- entity probes for this location - the dispatcher queues, so
            -- multiple hits in one tick land sequentially with 3s spacing.
            local probes = LOCATION_ENTITY_PROBES[key]
            if probes then
                for ent, probe in pairs(probes) do
                    local subKey = key .. "_" .. ent
                    if not d.KH_seenLocations[subKey] then
                        if probe(p) then
                            d.KH_seenLocations[subKey] = true
                            KH.Thoughts.emit(p, "location", subKey)
                        end
                    end
                end
            end
            return
        end
    end
end)

-- ============ Abandoned home halo ===============================
-- When player enters a building that's residential but has no living
-- bandits in it (and isn't her own homestead/safehouse), fire a one-shot
-- "abandoned" thought. Building-keyed (one fire per building, ever).
-- Kierstal's framing: "Looks abandoned - finders keepers."

local function _buildingHasLivingBandit(building)
    if not building then return false end
    if not _G.Bandit or not _G.Bandit.IsBandit then return false end
    local def = building.getDef and building:getDef()
    if not def then return false end
    local x1, y1 = def:getX(), def:getY()
    local x2, y2 = def:getX2(), def:getY2()
    local cell = getCell(); if not cell then return false end
    -- Sweep the building's footprint. Buildings can be large but we only
    -- care if ANY bandit is alive in it - return early on first hit.
    for x = x1, x2 do
        for y = y1, y2 do
            for z = 0, 3 do  -- up to 4 floors covers most residential
                local sq
                pcall(function() sq = cell:getGridSquare(x, y, z) end)
                if sq then
                    local movables
                    pcall(function() movables = sq:getMovingObjects() end)
                    if movables and movables.size then
                        for i = 0, movables:size() - 1 do
                            local obj
                            pcall(function() obj = movables:get(i) end)
                            if obj and instanceof(obj, "IsoZombie") then
                                if not obj:isDead() then
                                    local isBandit = false
                                    pcall(function() isBandit = Bandit.IsBandit(obj) end)
                                    if isBandit then return true end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

local function _isOwnClaimedBuilding(building)
    -- Avoid firing the halo in player's own Homestead / Waystation / Safehouse.
    if not building then return false end
    if not KH.HomeTerritory then return false end
    local check = function(fn)
        if not fn then return false end
        local ok, result = pcall(function() return fn(building) end)
        return ok and result == true
    end
    return check(KH.HomeTerritory.isHomestead)
        or check(KH.HomeTerritory.isWaystation)
        or check(KH.HomeTerritory.isSafehouse)
end

Events.EveryOneMinute.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    local building = p:getBuilding(); if not building then return end
    local def = building.getDef and building:getDef(); if not def then return end
    local keyId
    pcall(function() keyId = def:getKeyId() end)
    if not keyId then return end

    local d = md(p)
    d.KH_seenAbandonedBuildings = d.KH_seenAbandonedBuildings or {}
    if d.KH_seenAbandonedBuildings[keyId] then return end  -- already fired here

    -- Skip if it's the player's own claimed property.
    if _isOwnClaimedBuilding(building) then
        d.KH_seenAbandonedBuildings[keyId] = "own"
        return
    end

    -- Skip if any living bandit is in the building (someone lives here).
    if _buildingHasLivingBandit(building) then
        d.KH_seenAbandonedBuildings[keyId] = "occupied"
        return
    end

    -- Empty + not hers = abandoned. One-shot.
    d.KH_seenAbandonedBuildings[keyId] = "abandoned"
    KH.Thoughts.emit(p, "location", "abandonedHome")
end)

print("[KH] Thought triggers registered (full content pass).")
print("[KH] Abandoned-home halo trigger registered (one-shot per building).")
