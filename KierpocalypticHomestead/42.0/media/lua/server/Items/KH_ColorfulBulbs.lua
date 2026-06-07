-- Kierpocalyptic Homestead - boost colored light bulb spawn rates
--
-- Vanilla colored bulbs (Red/Blue/Green/Yellow/Cyan/Magenta/Orange/Pink/Purple)
-- are ~10x less common than plain bulbs in junk distributions, and the
-- specialty store pools that contain them attach only 10-60% of the time.
-- That makes themed-color rooms a major grind.
--
-- We mutate the distribution tables at OnDistributionMerge so colored bulbs
-- show up about as often as plain bulbs, and the specialty pools attach
-- more reliably.
--
-- All IsoLightSwitch fixtures already accept any item whose type starts with
-- "LightBulb" so NO fixture patching is needed. Flashlights cannot take
-- colored bulbs - their light is rendered from fixed item-script fields with
-- no LightColor support; doing flashlight color would require engine work.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ColorfulBulbs = "0.1.0"

local COLORS = {
    "LightBulbBlue","LightBulbCyan","LightBulbGreen","LightBulbMagenta",
    "LightBulbOrange","LightBulbPink","LightBulbPurple","LightBulbRed",
    "LightBulbYellow",
}
local IS_COLORED = {}
for _, c in ipairs(COLORS) do IS_COLORED[c] = true end

-- Mutate a key-value-flat junk distribution table in place.
-- Each table is { "ItemName", chance, "ItemName", chance, ... } so we walk
-- pairs and multiply the chance for any colored bulb entry by the factor.
local function boostJunkTable(t, factor)
    if not t then return 0 end
    local n = 0
    for i = 1, #t - 1, 2 do
        if type(t[i]) == "string" and IS_COLORED[t[i]] then
            t[i+1] = (t[i+1] or 0) * factor
            n = n + 1
        end
    end
    return n
end

-- Mutate a procedural-pool items table (same flat-pair format) by multiplier
local function boostProceduralPool(poolName, factor)
    if not ProceduralDistributions or not ProceduralDistributions.list then return 0 end
    local pool = ProceduralDistributions.list[poolName]
    if not pool or not pool.items then return 0 end
    local n = 0
    for i = 1, #pool.items - 1, 2 do
        if type(pool.items[i]) == "string" and IS_COLORED[pool.items[i]] then
            pool.items[i+1] = (pool.items[i+1] or 0) * factor
            n = n + 1
        end
    end
    return n
end

local function applyBoosts()
    -- The Bin/Closet tables are exposed as ClutterTables.BinItems and
    -- ClutterTables.ClosetItems (not Distribution_BinJunk.items as the
    -- filename suggests).
    local junkHits = 0
    if ClutterTables and ClutterTables.BinItems then
        junkHits = junkHits + boostJunkTable(ClutterTables.BinItems, 10)
    end
    if ClutterTables and ClutterTables.ClosetItems then
        junkHits = junkHits + boostJunkTable(ClutterTables.ClosetItems, 10)
    end
    local procHits = 0
    procHits = procHits + boostProceduralPool("GigamartLightbulb", 2)
    procHits = procHits + boostProceduralPool("ElectronicStoreLights", 2)

    print(string.format(
        "[KH] ColorfulBulbs: boosted %d junk-table entries (x10) and %d procedural-pool entries (x2)",
        junkHits, procHits))
end

-- OnDistributionMerge fires after vanilla distributions are loaded but before
-- containers start using them, which is when our mutations need to land.
if Events and Events.OnDistributionMerge then
    Events.OnDistributionMerge.Add(applyBoosts)
else
    Events.OnGameBoot.Add(applyBoosts)
end

print("[KH] ColorfulBulbs registered.")
