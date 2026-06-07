-- Kierpocalyptic Homestead - Comic Nerd
--
-- Doubles the boredom and unhappiness relief from reading comic books.
-- Implementation samples before/after stat values around the vanilla update
-- so the doubling matches whatever delta the vanilla code produced.

require "TimedActions/ISReadABook"
require "Core/KH_Util"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.ComicNerd = "0.0.1"

local function isComicBook(item)
    -- B42's hasTag(String) throws "No implementation found" - same shape as the
    -- trait API and ForageFeast bugs we already fixed. The engine wants an
    -- ItemTag Java instance, not a free string. None of the candidates here
    -- ("Comic", "ComicBook") are real ItemTag constants anyway. Detection
    -- falls back to DisplayCategory + type-name substring, both of which are
    -- reliable for vanilla comic books (DisplayCategory=ComicBook, type names
    -- like ComicBook_Batman / Comicbook_Frank etc.).
    if not item then return false end
    if item.getDisplayCategory then
        local cat = item:getDisplayCategory()
        if cat and string.find(string.lower(tostring(cat)), "comic", 1, true) then
            return true
        end
    end
    if item.getType then
        local t = item:getType()
        if t and string.find(string.lower(tostring(t)), "comic", 1, true) then
            return true
        end
    end
    return false
end

local original_update = ISReadABook.update

function ISReadABook:update()
    local character = self.character
    local item = self.item
    local applyDouble = false
    local prevUnhappy, prevBoredom

    if character and item and KH.hasTrait(character, "KH:ComicNerd") and isComicBook(item) then
        applyDouble = true
        local body = character:getBodyDamage()
        local stats = character:getStats()
        prevUnhappy = body and stats:get(CharacterStat.UNHAPPINESS) or nil
        prevBoredom = stats and stats:get(CharacterStat.BOREDOM) or nil
    end

    original_update(self)

    if applyDouble then
        local body = character:getBodyDamage()
        local stats = character:getStats()
        if body and prevUnhappy ~= nil then
            local newUnhappy = stats:get(CharacterStat.UNHAPPINESS)
            local delta = newUnhappy - prevUnhappy
            if delta < 0 then
                local target = newUnhappy + delta
                if target < 0 then target = 0 end
                stats:set(CharacterStat.UNHAPPINESS, target)
            end
        end
        if stats and prevBoredom ~= nil then
            local newBoredom = stats:get(CharacterStat.BOREDOM)
            local delta = newBoredom - prevBoredom
            if delta < 0 then
                local target = newBoredom + delta
                if target < 0 then target = 0 end
                stats:set(CharacterStat.BOREDOM, target)
            end
        end
    end
end
