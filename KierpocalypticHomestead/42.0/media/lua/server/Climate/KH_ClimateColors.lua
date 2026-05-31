-- Kierpocalyptic Homestead - climate color overrides
--
-- Pushes vanilla's day/dawn/dusk EXTERIOR color cells more dramatically:
--   - Sharper golden hour (dawn/dusk saturation + alpha bumped)
--   - Winter exterior desaturated (washed-out look)
--   - Summer exterior slight saturation push
--   - Fall exterior warm tint push
--   - Spring exterior subtle green push on Day
--
-- INTENTIONALLY UNTOUCHED:
--   - All INTERIOR cells (your indoor lighting stays as vanilla intends)
--   - All Night / NightMoon / NightNoMoon cells (already dark per design)
--   - Storm/fog/cloud tints (separate system, fine as is)
--
-- The engine still controls transition TIMING (lerp window between dawn->
-- day, dusk->night). Pushing the start-color and end-color further apart
-- visually extends the FELT duration of dawn/dusk, even if game-time is
-- unchanged.
--
-- COMPAT: Here Goes the Sun (mod id "HereGoesTheSun") owns this same domain
-- and does it much more thoroughly (per-weather-state, dynamically applied
-- on a timer). If HGTS is loaded we DEFER to it - calling setSeasonColor*
-- after HGTS's hook just clobbers their work until their next tick. Our
-- override only runs when HGTS is NOT installed.
--
-- API recap (from vanilla ClimateMain.lua):
--   _clim:setSeasonColorDawn(weather, season, r, g, b, alpha, isExterior)
--   _clim:setSeasonColorDay (weather, season, r, g, b, alpha, isExterior)
--   _clim:setSeasonColorDusk(weather, season, r, g, b, alpha, isExterior)
-- Weather enum:  0 = WARM   1 = NORMAL   2 = CLOUDY
-- Season enum:   0 = SUMMER 1 = FALL     2 = WINTER  3 = SPRING

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ClimateColors = "0.0.2"

-- Detect Here Goes the Sun. getActivatedMods() returns the ArrayList of
-- active mod IDs (each id is the mod.info `id=` value).
local function _hgtsActive()
    local ok, list = pcall(function() return getActivatedMods() end)
    if not ok or not list or not list.size then return false end
    for i = 0, list:size() - 1 do
        local id; pcall(function() id = list:get(i) end)
        if id and tostring(id) == "HereGoesTheSun" then return true end
    end
    return false
end

local WARM,NORMAL,CLOUDY = 0,1,2
local SUMMER,FALL,WINTER,SPRING = 0,1,2,3

local function applyKHColors(_clim)
    -- ============= DAWN (WARM) - cool blue-hour, more saturated =============
    -- vanilla SUMMER  0.57,0.69,0.75 a0.75  -> deeper blue, stronger
    _clim:setSeasonColorDawn(WARM, SUMMER, 0.50, 0.70, 0.88, 0.92, true)
    -- vanilla FALL    0.61,0.5,0.72  a0.75  -> dustier mauve dawn
    _clim:setSeasonColorDawn(WARM, FALL,   0.66, 0.46, 0.74, 0.92, true)
    -- vanilla WINTER  0.48,0.57,0.63 a0.75  -> bleak steel-blue dawn
    _clim:setSeasonColorDawn(WARM, WINTER, 0.40, 0.54, 0.66, 0.88, true)
    -- vanilla SPRING  0.57,0.66,0.64 a0.75  -> slight cool-green
    _clim:setSeasonColorDawn(WARM, SPRING, 0.52, 0.70, 0.62, 0.92, true)

    -- ============= DAY (WARM) - season-tinted exterior =============
    -- SUMMER: warmer haze, brighter
    _clim:setSeasonColorDay(WARM, SUMMER, 0.94, 0.88, 0.68, 0.82, true)
    -- FALL: more orange tint
    _clim:setSeasonColorDay(WARM, FALL,   0.88, 0.66, 0.40, 0.82, true)
    -- WINTER: desaturated (RGB pulled toward mean ~0.58) - washed-out
    _clim:setSeasonColorDay(WARM, WINTER, 0.62, 0.59, 0.56, 0.78, true)
    -- SPRING: subtle green push
    _clim:setSeasonColorDay(WARM, SPRING, 0.66, 0.78, 0.60, 0.72, true)

    -- ============= DAY (CLOUDY) - winter much bleaker =============
    -- WINTER cloudy: nearly gray with cool tint
    _clim:setSeasonColorDay(CLOUDY, WINTER, 0.30, 0.32, 0.38, 0.85, true)
    -- FALL cloudy: dustier, slight warm
    _clim:setSeasonColorDay(CLOUDY, FALL,   0.56, 0.46, 0.42, 0.82, true)
    -- SUMMER and SPRING cloudy left at vanilla (already reasonable)

    -- ============= DUSK (WARM) - sharper golden hour =============
    -- vanilla SUMMER  0.9,0.45,0.2  a0.8   -> deeper, longer-feeling sunset
    _clim:setSeasonColorDusk(WARM, SUMMER, 0.98, 0.40, 0.10, 0.95, true)
    -- vanilla FALL    0.8,0.39,0.28 a0.85  -> burnt-orange autumn evening
    _clim:setSeasonColorDusk(WARM, FALL,   0.92, 0.32, 0.18, 0.95, true)
    -- vanilla WINTER  0.52,0.4,0.32 a0.93  -> bleaker warm sunset
    _clim:setSeasonColorDusk(WARM, WINTER, 0.58, 0.40, 0.30, 0.95, true)
    -- vanilla SPRING  0.64,0.4,0.3  a0.88  -> warmer, more golden
    _clim:setSeasonColorDusk(WARM, SPRING, 0.78, 0.48, 0.28, 0.95, true)

    -- Interior cells, Night cells, fog/cloud tints all left untouched.
end

local function maybeApply(_clim)
    if _hgtsActive() then
        print("[KH] Climate color overrides SKIPPED - Here Goes the Sun is active.")
        return
    end
    applyKHColors(_clim)
end

Events.OnClimateManagerInit.Add(maybeApply)

print("[KH] Climate color overrides registered (defers to Here Goes the Sun when present)")
