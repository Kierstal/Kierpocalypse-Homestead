-- Kierpocalyptic Homestead - shared helpers.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.Util = "0.0.6"

KH.registeredTraits = KH.registeredTraits or {}

-- B42 IsoGameCharacter.hasTrait() takes only a CharacterTrait Java instance.
-- Passing a string throws "No implementation found for function: hasTrait"
-- and floods the log with stack traces even when pcall catches it.
--
-- Strategy:
--   - "KH:..."     -> look up KH.registeredTraits[id] (set when we registered it)
--   - bare id  -> look up CharacterTrait.<UPPER_SNAKE> static field
--                 e.g. "outdoorsman" -> CharacterTrait.OUTDOORSMAN,
--                      "all_thumbs" -> CharacterTrait.ALL_THUMBS,
--                      "ComicNerd" -> CharacterTrait.COMIC_NERD
-- All probes are pcall-protected. Misses return false silently.

-- Cache: lowercase id string -> CharacterTrait Java instance.
-- Built lazily by enumerating CharacterTraitDefinition.getTraits() the first
-- time we need it. That gives us a one-source-of-truth mapping that doesn't
-- depend on guessing the static-field name from the id.
local _javaTraitCache = nil

local function buildJavaTraitCache()
    _javaTraitCache = {}
    if not (CharacterTraitDefinition and CharacterTraitDefinition.getTraits) then return end
    local list
    pcall(function() list = CharacterTraitDefinition.getTraits() end)
    if not list or not list.size then return end
    for i = 0, list:size() - 1 do
        local def
        pcall(function() def = list:get(i) end)
        local trait
        if def and def.getType then pcall(function() trait = def:getType() end) end
        if trait then
            local name
            if trait.getName then pcall(function() name = trait:getName() end) end
            if name then
                _javaTraitCache[name] = trait
                _javaTraitCache[string.lower(name)] = trait
            end
        end
    end
end

local function resolveVanillaTrait(traitId)
    if _javaTraitCache == nil then buildJavaTraitCache() end
    return _javaTraitCache[traitId] or _javaTraitCache[string.lower(traitId)]
end

function KH.hasTrait(character, traitId)
    if not character or not traitId then return false end
    if not character.hasTrait then return false end

    -- KH-namespaced: cached Java instance from our register() result
    if string.sub(traitId, 1, 3) == "KH:" then
        local cached = KH.registeredTraits[traitId]
        if not cached then return false end
        local ok, has = pcall(function() return character:hasTrait(cached) end)
        return (ok and has) or false
    end

    -- Vanilla: resolve string id to CharacterTrait static field, then check.
    local java = resolveVanillaTrait(traitId)
    if not java then return false end
    local ok, has = pcall(function() return character:hasTrait(java) end)
    return (ok and has) or false
end


-- ----------------------------------------------------------------
-- Context menu helpers
-- ----------------------------------------------------------------
KH.UI = KH.UI or {}

-- After a KH OnFillWorldObjectContextMenu hook has called context:addOption()
-- N times, calling this with count=N pulls those last-N options off the end
-- of context.options and reinserts them at the front, preserving their
-- relative order. Each option's .id is rewritten to match the new index.
-- numOptions is unchanged because we're reordering, not adding/removing.
--
-- Usage pattern:
--   local before = (context and context.options and #context.options) or 0
--   -- ...add KH options via context:addOption(...)...
--   local after  = (context and context.options and #context.options) or 0
--   KH.UI.moveLastAddedToTop(context, after - before)
function KH.UI.moveLastAddedToTop(context, count)
    if not context or not context.options then return end
    if not count or count <= 0 then return end
    local total = #context.options
    if count >= total then return end  -- everything is already "at top"
    -- Slice the last `count` items
    local recent = {}
    for i = total - count + 1, total do
        recent[#recent + 1] = context.options[i]
    end
    -- Build new options list: recent first (in original order), then the rest
    local newOpts = {}
    for _, opt in ipairs(recent) do newOpts[#newOpts + 1] = opt end
    for i = 1, total - count do newOpts[#newOpts + 1] = context.options[i] end
    -- Re-id so internal lookups (mouseOver index, etc.) match the new order
    for i, opt in ipairs(newOpts) do
        if opt then opt.id = i end
    end
    context.options = newOpts
end


-- ----------------------------------------------------------------
-- KH context-menu mark icon (small garden trowel; homesteading-themed
-- vanilla texture that distinguishes KH-added options at a glance)
-- ----------------------------------------------------------------
KH.UI._markTexture = nil

function KH.UI.getMarkTexture()
    if KH.UI._markTexture then return KH.UI._markTexture end
    local ok, tex = pcall(function() return getTexture("media/textures/Item_TZ_GardenTrowel.png") end)
    if ok and tex then KH.UI._markTexture = tex end
    return KH.UI._markTexture
end

-- Tag a freshly-added context menu option with the KH mark. Pass-through
-- returns the option so calls can be chained:
--     KH.UI.markOption(context:addOption("Adopt as Pet", ...))
function KH.UI.markOption(opt)
    if not opt then return opt end
    local t = KH.UI.getMarkTexture()
    if t then opt.iconTexture = t end
    return opt
end
