-- Kierpocalyptic Homestead - Dirt Floor Farming Fix
--
-- Vanilla PZ B42 won't let you dig, plow, or place farming-related objects
-- on naturally-occurring dirt floor tiles (sprite blends_natural_01_64).
-- This is a bug - the engine recognizes "dirt" as a soil type, but the
-- canDigHereSquare / canPlaceHere checks reject the same tiles for farming.
--
-- This module patches four vanilla functions to recognize dirt-floor sprites
-- as valid farming surfaces:
--   1. ISFarmingMenu.canDigHereSquare (client) - allow plowing
--   2. ISShovelGroundCursor.GetDirtGravelSand (server) - shovel recognizes dirt
--   3. ISBuildIsoEntity.isValid (server + shared) - placement on shovelled dirt
--   4. BuildRecipeCode.floor.OnIsValid (shared) - floor recipes on shovelled dirt
--
-- Adapted from "Dirt Floor Farming Fix" (DirtFloorFarmingFix, workshop
-- 3733988329). Verbatim patch logic with attribution; absorbed into KH so
-- Kierstal can unsubscribe and still farm on her homestead's dirt floors.
-- Consolidated client/server/shared patches into one shared module that
-- hooks OnGameStart and does each patch defensively. Original mod had four
-- files (client + server + 2 shared); KH ships one.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.DirtFloorFarming = "0.0.1"

local DIRT_FLOOR_SPRITE = "blends_natural_01_64"

-- ----------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------

-- Returns true if the square has a dirt-floor sprite that hasn't been
-- shovelled yet. Shovelled tiles are tracked via modData.shovelled.
local function _hasUnshovelledDirtFloor(square)
    if not square then return false end
    local floor = square:getFloor()
    if floor and floor:getSprite() and floor:getSprite():getName() == DIRT_FLOOR_SPRITE then
        if not (floor:hasModData() and floor:getModData().shovelled) then
            return true
        end
    end
    local objects = square:getObjects()
    if not objects then return false end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj:getSprite() and obj:getSprite():getName() == DIRT_FLOOR_SPRITE then
            if not (obj:hasModData() and obj:getModData().shovelled) then
                return true
            end
        end
    end
    return false
end

-- Returns the dirt-floor object on this square if any (used by shovel patch).
local function _getDirtFloorObject(square)
    if not square then return nil end
    local floor = square:getFloor()
    if floor and floor:getSprite() and floor:getSprite():getName() == DIRT_FLOOR_SPRITE then
        if not (floor:hasModData() and floor:getModData().shovelled) then
            return floor
        end
    end
    local objects = square:getObjects()
    if not objects then return nil end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj:getSprite() and obj:getSprite():getName() == DIRT_FLOOR_SPRITE then
            if not (obj:hasModData() and obj:getModData().shovelled) then
                return obj
            end
        end
    end
    return nil
end

-- Returns true if the square has a shovelled dirt tile (used by placement patch).
local function _hasShovelledDirtTile(square)
    if not square then return false end
    local objects = square:getObjects()
    if not objects then return false end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj:hasModData() and obj:getModData().shovelled == true then
            if obj:getSprite() and obj:getSprite():getName() == DIRT_FLOOR_SPRITE then
                return true
            end
        end
    end
    return false
end

-- ----------------------------------------------------------------
-- Patches
-- ----------------------------------------------------------------

local function patchFarmingMenu()
    if not _G.ISFarmingMenu or not ISFarmingMenu.canDigHereSquare then return false end
    local original = ISFarmingMenu.canDigHereSquare
    ISFarmingMenu.canDigHereSquare = function(square)
        if original(square) then return true end
        if not _hasUnshovelledDirtFloor(square) then return false end
        if square.hasGrave and square:hasGrave() then return false end
        if _G.CFarmingSystem and CFarmingSystem.instance then
            local plant
            pcall(function() plant = CFarmingSystem.instance:getLuaObjectOnSquare(square) end)
            if plant and plant.state ~= "plow" and plant.isAlive and plant:isAlive() then
                return false
            end
        end
        return true
    end
    return true
end

local function patchShovelGround()
    if not _G.ISShovelGroundCursor or not ISShovelGroundCursor.GetDirtGravelSand then return false end
    local original = ISShovelGroundCursor.GetDirtGravelSand
    ISShovelGroundCursor.GetDirtGravelSand = function(square)
        local groundType, obj = original(square)
        if groundType then return groundType, obj end
        local dirtFloorObj = _getDirtFloorObject(square)
        if dirtFloorObj then return "dirt", dirtFloorObj end
        return nil
    end
    return true
end

local function patchBuildIsoEntity()
    if not _G.ISBuildIsoEntity or not ISBuildIsoEntity.isValid then return false end
    local originalIsValid = ISBuildIsoEntity.isValid
    ISBuildIsoEntity.isValid = function(self, square)
        if originalIsValid(self, square) then return true end
        if not square then return false end
        if not _hasShovelledDirtTile(square) then return false end
        if self.blockBuild then return false end
        if not self:haveMaterial(square) then return false end
        if square.HasStairsBelow and square:HasStairsBelow() then return false end
        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local item = objects:get(i)
            if item then
                local texName = item.getTextureName and item:getTextureName()
                local sprName = item.getSpriteName and item:getSpriteName()
                if (texName and luautils.stringStarts(texName, "vegetation_farming")) or
                   (sprName and luautils.stringStarts(sprName, "vegetation_farming")) then
                    return false
                end
            end
        end
        return true
    end
    return true
end

local function patchBuildRecipeCode()
    if not _G.BuildRecipeCode or not BuildRecipeCode.floor or not BuildRecipeCode.floor.OnIsValid then
        return false
    end
    BuildRecipeCode.floor.OnIsValid = function(params)
        if params.square:HasStairsBelow() then return false end
        local tileInfoSprite = params.tileInfo:getSpriteName()
        local placingOnShovelled = false
        local objs = params.square:getObjects()
        for i = 0, objs:size() - 1 do
            local item = objs:get(i)
            local texName = item.getTextureName and item:getTextureName()
            local sprName = item.getSpriteName and item:getSpriteName()
            if (texName and luautils.stringStarts(texName, "vegetation_farming")) or
               (sprName and luautils.stringStarts(sprName, "vegetation_farming")) then
                return false
            end
            local spritesMatch = (texName and texName == tileInfoSprite) or
                                 (sprName and sprName == tileInfoSprite)
            local isShovelled = item:hasModData() and (item:getModData().shovelled == true)
            if spritesMatch then
                if isShovelled then
                    placingOnShovelled = true
                else
                    return false
                end
            end
        end
        if not placingOnShovelled then
            if not params.square:connectedWithFloor() then return false end
        end
        params.testCollisions = false
        return true
    end
    return true
end

-- ----------------------------------------------------------------
-- Apply
-- ----------------------------------------------------------------

local _applied = false

local function applyAll()
    if _applied then return end
    local farming = patchFarmingMenu()
    local shovel  = patchShovelGround()
    local build   = patchBuildIsoEntity()
    local recipe  = patchBuildRecipeCode()
    if farming and shovel and build and recipe then
        _applied = true
        Events.OnTick.Remove(applyAll)
        print("[KH] DirtFloorFarming: all 4 vanilla patches applied (farm + shovel + build + recipe).")
    end
end

Events.OnGameStart.Add(applyAll)
-- Retry on OnTick until ALL four patch targets are available. Some load later
-- than OnGameStart depending on PZ's UI / Build menu init order.
Events.OnTick.Add(applyAll)
