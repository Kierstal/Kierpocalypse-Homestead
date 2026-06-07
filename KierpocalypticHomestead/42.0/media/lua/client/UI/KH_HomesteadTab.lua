-- Kierpocalyptic Homestead - "Homestead" tab in the vanilla CharacterInfo
-- window.
--
-- Adds a new tab next to Info / Skills / Health / Protection / Clothing
-- Insulation. The tab shows current KH-tracked needs: bath, toilet,
-- personal dirt, room filth.
--
-- We follow the vanilla pattern from ISCharacterInfoWindow:createChildren:
--   self.panel:addView(<name>, <view>)
-- by wrapping `createChildren` after vanilla finishes, then appending our
-- view. This is the exact extension pattern other mods use without
-- replacing the whole window.

require "XpSystem/ISUI/ISCharacterInfoWindow"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.HomesteadTab = "0.0.3"

-- ----------------------------------------------------------------
-- Panel view (the body of the new tab)
-- ----------------------------------------------------------------

-- Helper: get a building's ID string from an IsoGridSquare, nil if not in a building.
local function buildingIdOfSq(sq)
    if not sq then return nil end
    local b, def, id
    pcall(function() b = sq:getBuilding() end)
    pcall(function() def = b and b:getDef() end)
    pcall(function() id = def and def:getIDString() end)
    return id
end

KH_HomesteadView = ISPanel:derive("KH_HomesteadView")

local ROW_HEIGHT = 20
local BAR_HEIGHT = 12
local PAD = 10

local function lerpColor(t)
    -- t in 0..1, returns r,g,b -- green at 0, yellow at 0.5, red at 1
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    if t < 0.5 then
        local k = t * 2
        return 0.35 + k * 0.55, 0.85, 0.30
    else
        local k = (t - 0.5) * 2
        return 0.90, 0.85 - k * 0.55, 0.30
    end
end

function KH_HomesteadView:initialise()
    ISPanel.initialise(self)
end

function KH_HomesteadView:drawBar(label, value, max, y)
    local pct = (value or 0) / (max or 100)
    self:drawText(label, PAD, y, 1, 1, 1, 1, UIFont.Small)
    local barLeft = 130
    local barRight = self.width - PAD
    local barWidth = barRight - barLeft
    if barWidth < 80 then barWidth = 80 end
    -- track
    self:drawRect(barLeft, y + 2, barWidth, BAR_HEIGHT, 0.4, 0.1, 0.1, 0.1)
    -- fill
    local fillW = math.floor(barWidth * pct)
    if fillW > 0 then
        local r, g, b = lerpColor(pct)
        self:drawRect(barLeft, y + 2, fillW, BAR_HEIGHT, 0.9, r, g, b)
    end
    -- number
    local txt = string.format("%d / %d", math.floor(value or 0), math.floor(max or 100))
    self:drawText(txt, barRight - getTextManager():MeasureStringX(UIFont.Small, txt), y, 1, 1, 1, 1, UIFont.Small)
end

function KH_HomesteadView:render()
    ISPanel.render(self)
    local p = (self.playerNum ~= nil) and getSpecificPlayer(self.playerNum) or getPlayer()
    if not p then return end
    local y = PAD
    -- Header
    self:drawText("Homestead — personal needs", PAD, y, 1.0, 1.0, 1.0, 1.0, UIFont.Medium)
    y = y + ROW_HEIGHT + 4

    -- Bath need
    local bath = (KH.Bath and KH.Bath.get and KH.Bath.get(p)) or 0
    self:drawBar((getText and getText("UI_KH_BathNeed")) or "Bath", bath, 100, y)
    y = y + ROW_HEIGHT

    -- Toilet need
    local toilet = (KH.Toilet and KH.Toilet.get and KH.Toilet.get(p)) or 0
    self:drawBar((getText and getText("UI_KH_ToiletNeed")) or "Toilet", toilet, 100, y)
    y = y + ROW_HEIGHT

    -- Personal dirt score
    local dirtScore = 0
    if KH.DirtScore and KH.DirtScore.compute then
        local ok, r = pcall(function() return KH.DirtScore.compute(p) end)
        if ok and r then dirtScore = r.total or 0 end
    end
    self:drawBar("Dirt (body + clothes)", dirtScore, 100, y)
    y = y + ROW_HEIGHT

    -- Room filth (from last tick cache)
    local filth = (KH.Needs and KH.Needs.get and KH.Needs.get(p, "KH_lastFilthScore")) or 0
    -- Filth uses an integer score, not 0..100. Display raw value with a
    -- nominal 10 cap for the bar fill.
    self:drawBar("Room filth (blood+trash)", filth, 10, y)
    y = y + ROW_HEIGHT + 4

    -- Deodorant mask indicator
    if KH.Hygiene and KH.Hygiene.isMasked and KH.Hygiene.isMasked(p) then
        self:drawText("[deodorant: active]", PAD, y, 0.65, 0.85, 0.50, 1.0, UIFont.Small)
        y = y + ROW_HEIGHT
    end

    -- Nutrition section: only for Nutritionist trait/profession. Same gate
    -- as KH_NutritionPanel uses for its Info-tab overlay - so both views
    -- show the same data when applicable.
    local hasNutritionist = false
    if KH and KH.hasTrait then
        hasNutritionist = KH.hasTrait(p, "nutritionist") or KH.hasTrait(p, "nutritionist2")
    end
    if hasNutritionist then
        local nutrition = p:getNutrition()
        if nutrition then
            y = y + 6
            self:drawText("Nutrition", PAD, y, 1.0, 1.0, 1.0, 1.0, UIFont.Medium)
            y = y + ROW_HEIGHT + 4

            local function safeGet(obj, m, def)
                if obj and obj[m] then
                    local ok, v = pcall(function() return obj[m](obj) end)
                    if ok then return v end
                end
                return def
            end

            local calories = math.floor(safeGet(nutrition, "getCalories", 0) + 0.5)
            local carbs    = safeGet(nutrition, "getCarbohydrates", 0)
            local proteins = safeGet(nutrition, "getProteins", 0)
            local lipids   = safeGet(nutrition, "getLipids", 0)
            local weight   = safeGet(nutrition, "getWeight", 0)

            local labelW = 90
            local valX   = PAD + labelW + 6

            local rows = {
                { "Calories:",   string.format("%d kcal", calories) },
                { "Carbs:",      string.format("%.1f g", carbs)     },
                { "Proteins:",   string.format("%.1f g", proteins)  },
                { "Fats:",       string.format("%.1f g", lipids)    },
                { "Weight:",     string.format("%.1f kg", weight)   },
            }
            for _, row in ipairs(rows) do
                self:drawTextRight(row[1], PAD + labelW, y, 1, 1, 1, 1, UIFont.Small)
                self:drawText(row[2], valX, y, 1, 1, 1, 0.75, UIFont.Small)
                y = y + ROW_HEIGHT
            end
        end
    end

    -- ---- Property info section ----
    y = y + 10
    self:drawRect(PAD, y, self.width - PAD * 2, 1, 0.5, 0.5, 0.5, 0.5)
    y = y + 6

    local kind = KH.Home and KH.Home.currentType and KH.Home.currentType(p)

    -- Property type header
    local kindLabel, hr, hg, hb
    if kind == "homestead" then
        kindLabel = "Homestead"
        hr, hg, hb = 0.55, 0.85, 0.55
    elseif kind == "waystation" then
        kindLabel = "Waystation"
        hr, hg, hb = 0.70, 0.70, 1.00
    elseif kind == "safehouse" then
        kindLabel = "Safehouse"
        hr, hg, hb = 0.95, 0.75, 0.40
    else
        kindLabel = "Unclaimed"
        hr, hg, hb = 0.55, 0.55, 0.55
    end
    self:drawText("Property: " .. kindLabel, PAD, y, hr, hg, hb, 1.0, UIFont.Medium)
    y = y + ROW_HEIGHT + 4

    if kind == "homestead" or kind == "safehouse" then

        -- ---- Residents ----
        self:drawText("Residents", PAD, y, 1.0, 1.0, 1.0, 0.85, UIFont.Small)
        y = y + ROW_HEIGHT

        local _md = p:getModData()
        local beds = KH.Resident and _md["KH_ResidentBeds"]
        local cell = getCell()
        local residentCount = 0
        local curBuildingId = buildingIdOfSq(p:getCurrentSquare())

        if beds and cell then

            for key, entry in pairs(beds) do
                if entry and entry.uuid then
                    -- Find which building this resident belongs to.
                    local checkX, checkY, checkZ
                    if entry.rx then
                        checkX, checkY, checkZ = entry.rx, entry.ry, entry.rz
                    else
                        checkX, checkY, checkZ = string.match(key, "^(%d+):(%d+):(%d+):")
                        checkX = tonumber(checkX)
                        checkY = tonumber(checkY)
                        checkZ = tonumber(checkZ)
                    end

                    if checkX and curBuildingId then
                        local rsq = cell:getGridSquare(checkX, checkY, checkZ or 0)
                        local rbid = buildingIdOfSq(rsq)

                        if rbid == curBuildingId then
                            residentCount = residentCount + 1
                            local name = entry.name or "Resident"
                            local sexTag = (entry.sex == "m") and " [M]" or (entry.sex == "f") and " [F]" or ""
                            local statusTag
                            if entry.rx then
                                statusTag = " - placed"
                            elseif entry.testMode then
                                statusTag = " - test"
                            else
                                statusTag = " - no resident"
                            end
                            local active = KH.Resident and KH.Resident.isActive(entry)
                            local nameR = active and 0.85 or 0.55
                            local nameG = active and 0.95 or 0.55
                            local nameB = active and 0.75 or 0.55
                            self:drawText("  " .. name .. sexTag .. statusTag,
                                PAD, y, nameR, nameG, nameB, 1.0, UIFont.Small)
                            y = y + ROW_HEIGHT
                        end
                    end
                end
            end
        end

        if residentCount == 0 then
            self:drawText("  (none)", PAD, y, 0.5, 0.5, 0.5, 1.0, UIFont.Small)
            y = y + ROW_HEIGHT
        end

        -- ---- Pets ----
        y = y + 4
        self:drawText("Pets", PAD, y, 1.0, 1.0, 1.0, 0.85, UIFont.Small)
        y = y + ROW_HEIGHT

        local petState = p:getModData()["KH_Pet"]
        local petShown = false
        if petState and petState.petName then
            local petName    = petState.petName or "Pet"
            local petSpecies = petState.petSpecies or "unknown"
            local petHappy   = math.floor(petState.happiness or 0)
            local assigned   = petState.assignedHomestead
            -- Only show pet here if it's assigned to this homestead or has no assignment.
            local showPet = (assigned == nil) or (assigned == curBuildingId)
            if showPet then
                petShown = true
                local hr2 = 0.80
                local hg2 = petHappy > 60 and 0.90 or (petHappy > 30 and 0.75 or 0.50)
                local hb2 = 0.60
                self:drawText(string.format("  %s (%s) - happiness %d/100",
                    petName, petSpecies, petHappy),
                    PAD, y, hr2, hg2, hb2, 1.0, UIFont.Small)
                y = y + ROW_HEIGHT
            end
        end
        if not petShown then
            self:drawText("  (none)", PAD, y, 0.5, 0.5, 0.5, 1.0, UIFont.Small)
            y = y + ROW_HEIGHT
        end

        -- ---- Livestock (placeholder) ----
        y = y + 4
        self:drawText("Livestock", PAD, y, 1.0, 1.0, 1.0, 0.85, UIFont.Small)
        y = y + ROW_HEIGHT
        self:drawText("  (not yet tracked)", PAD, y, 0.5, 0.5, 0.5, 1.0, UIFont.Small)
        y = y + ROW_HEIGHT

    elseif kind == "waystation" then
        self:drawText("Waystations don't house residents.", PAD, y, 0.65, 0.65, 0.65, 1.0, UIFont.Small)
        y = y + ROW_HEIGHT
    else
        self:drawText("Mark this building as a Homestead", PAD, y, 0.65, 0.65, 0.65, 1.0, UIFont.Small)
        y = y + ROW_HEIGHT
        self:drawText("or Safehouse to manage residents.", PAD, y, 0.65, 0.65, 0.65, 1.0, UIFont.Small)
        y = y + ROW_HEIGHT
    end

    -- suppress unused-variable warning for y
    _ = y
end

function KH_HomesteadView:new(x, y, w, h, playerNum)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum or 0
    o.background = false
    return o
end

-- ----------------------------------------------------------------
-- Patch ISCharacterInfoWindow:createChildren to append our view
-- ----------------------------------------------------------------

if ISCharacterInfoWindow and ISCharacterInfoWindow.createChildren
   and not ISCharacterInfoWindow._kh_homestead_patched then
    local _orig = ISCharacterInfoWindow.createChildren
    function ISCharacterInfoWindow:createChildren()
        _orig(self)
        if not self.panel or not self.panel.addView then return end
        local tabWidth = (self.charScreen and self.charScreen.width) or (self.width or 400)
        local tabHeight = (self.charScreen and self.charScreen.height) or (self.height - 8)
        local view = KH_HomesteadView:new(0, 8, tabWidth, tabHeight, self.playerNum)
        view:initialise()
        view.infoText = getTextOrNull("UI_KH_HomesteadPanel")
        self.kh_homesteadView = view
        local ok = pcall(function() self.panel:addView("Homestead", view) end)
        if ok then
            print("[KH] Homestead tab added to CharacterInfoWindow")
        end
    end
    ISCharacterInfoWindow._kh_homestead_patched = true
end
