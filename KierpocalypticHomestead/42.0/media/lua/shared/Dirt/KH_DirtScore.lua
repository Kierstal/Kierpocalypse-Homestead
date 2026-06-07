-- Kierpocalyptic Homestead - personal dirt + blood scorer
--
-- Reads HumanVisual:getDirt(part) and :getBlood(part) across body parts;
-- also sums clothing dirtiness across worn items. Returns a composite
-- 0..100ish score representing personal filthiness.
--
-- Score model:
--   bodyScore  = sum(getDirt(part) + getBlood(part)) across body parts
--                                       (each part is 0..1 nominally,
--                                        rough cap of 0.5 each in practice)
--   clothScore = sum(item:getDirtiness()) / 4 across worn items
--                (so a single item at 100% dirty -> 25 score)
--   total      = clamp(bodyScore * 20 + clothScore, 0..100)
--
-- The 20x scaling on body is empirical; PZ blood/dirt per part are
-- small floats and we want them to dominate vs. background clothing
-- dirt. Tune in playtest.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.DirtScore = "0.0.1"
KH.DirtScore = KH.DirtScore or {}

-- BloodBodyPartType enum -- we iterate the numeric ToIndex range. The
-- enum is registered globally by Java; we read it safely with pcall.
local function bodyPartIndices()
    if not BloodBodyPartType then return {} end
    local count = 0
    local ok, total = pcall(function() return BloodBodyPartType.MAX:index() end)
    if ok and total then count = total end
    if count == 0 then count = 19 end  -- B42 has ~19 blood parts; safe fallback
    local list = {}
    for i = 0, count - 1 do
        local ok2, part = pcall(function() return BloodBodyPartType.FromIndex(i) end)
        if ok2 and part then table.insert(list, part) end
    end
    return list
end

local CACHED_PARTS = nil

function KH.DirtScore.compute(player)
    local out = { body = 0, clothing = 0, total = 0 }
    if not player or player:isDead() then return out end
    local visual = player.getHumanVisual and player:getHumanVisual()
    if visual then
        if not CACHED_PARTS then CACHED_PARTS = bodyPartIndices() end
        for _, part in ipairs(CACHED_PARTS) do
            local d, b = 0, 0
            pcall(function() d = visual:getDirt(part) or 0 end)
            pcall(function() b = visual:getBlood(part) or 0 end)
            out.body = out.body + d + b
        end
    end
    -- Worn clothing dirtiness
    local wornItems = player.getWornItems and player:getWornItems()
    if wornItems and wornItems.size then
        for i = 0, wornItems:size() - 1 do
            local wi = wornItems:get(i)
            local it = wi and wi.getItem and wi:getItem()
            if it and it.getDirtiness then
                local dty = 0
                pcall(function() dty = it:getDirtiness() or 0 end)
                out.clothing = out.clothing + dty
            end
        end
    end
    out.total = math.min(100, out.body * 20 + out.clothing / 4)
    return out
end
