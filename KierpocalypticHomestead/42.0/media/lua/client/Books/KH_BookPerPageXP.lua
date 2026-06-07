-- Kierpocalyptic Homestead - Books grant per-page XP
--
-- Vanilla ISReadABook.checkMultiplier grants an XP MULTIPLIER (applied to
-- subsequent skill use), not direct XP from reading. That made books feel
-- "obsolete" once you finished them.
--
-- v0.0.4 - SIMPLIFICATION. The complete()-wrap approach (v0.0.2-3) wasn't
-- reliably crediting XP - user reported reading the Electrical 1 book end
-- to end and getting zero. That implementation depended on complete()
-- firing AND _origComplete being non-nil at install time AND the post-
-- complete XP block running. Too many dependencies; one of them was
-- failing silently.
--
-- This version moves the XP grant into ISReadABook.checkMultiplier itself,
-- which vanilla update() calls EVERY tick while reading. Each call:
--   1) figure out current alreadyReadPages
--   2) compute delta from last tick (kh_lastPages stored on self)
--   3) award XP proportional to delta (totalXp/totalPages * delta)
-- That spreads the XP smoothly across the read action and survives any
-- interruption (kh_lastPages persists per-action so partial reads keep
-- what was earned).
--
-- "totalXp" is the sum of getXpForLevel(L) for each level the book teaches
-- (item:getLvlSkillTrained() ... item:getMaxLevelTrained()). For a
-- beginner tier-1 book that's 75 + 150 = 225, giving the player two skill
-- points for finishing the book.

pcall(function() require "TimedActions/ISReadABook" end)

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.BookPerPageXP = "0.0.4"

-- Sum the per-level XP for the levels the book teaches. PerkFactory's
-- getXpForLevel(L) returns the XP to advance from L-1 to L.
local function totalXpForLevelRange(perk, firstLevel, lastLevel)
    if not PerkFactory then return 0 end
    local p
    local ok = pcall(function() p = PerkFactory.getPerk(perk) end)
    if not ok or not p then return 0 end
    local total = 0
    for L = (firstLevel or 1), (lastLevel or 0) do
        local x = 0
        local ok2 = pcall(function() x = p:getXpForLevel(L) or 0 end)
        if ok2 and x then total = total + x end
    end
    return total
end

local function _installBookHooks()
    if not ISReadABook then
        print("[KH] BookPerPageXP: ISReadABook nil at install time")
        return
    end

    -- Replace checkMultiplier with our per-tick incremental XP grant.
    ISReadABook.checkMultiplier = function(self)
        if not self or not self.item or not self.character then return end
        local item = self.item
        local char = self.character

        local trained = SkillBook and SkillBook[item:getSkillTrained()] or nil
        if not trained or not trained.perk then return end

        local pages = 0
        pcall(function() pages = item:getNumberOfPages() or 0 end)
        if pages <= 0 then return end

        local currentPages = 0
        pcall(function() currentPages = item:getAlreadyReadPages() or 0 end)

        -- First call for this action instance: initialize kh_lastPages from
        -- where we are now and skip awarding. Future ticks will see deltas.
        if self.kh_lastPages == nil then
            self.kh_lastPages = currentPages
            -- One-shot diagnostic: confirms the hook is firing
            print(string.format("[KH] Book reading started: %s (page %d/%d, perk=%s)",
                tostring(item:getType()), currentPages, pages, tostring(trained.perk)))
            return
        end

        local delta = currentPages - self.kh_lastPages
        if delta <= 0 then return end  -- no new pages this tick

        local lvlStart = item:getLvlSkillTrained() or 0
        local lvlEnd   = item:getMaxLevelTrained() or (lvlStart + 2)
        if lvlEnd <= lvlStart then lvlEnd = lvlStart + 2 end

        local totalXp = totalXpForLevelRange(trained.perk, lvlStart, lvlEnd)
        if totalXp <= 0 then return end

        local xpToGive = (totalXp / pages) * delta
        if xpToGive <= 0 then return end

        local xp = char:getXp()
        if xp and xp.AddXP then
            -- Signature mirrors ISPlayerStatsUI.lua usage:
            --   AddXP(perk, amount, doRoll, useMultipliers, hideHud, hideXpGain)
            -- Vanilla debug UI passes all four bools as false. We do too -
            -- if Fast/Slow Learner applies inside the engine call, that's
            -- fine; we don't want to double-apply on our side.
            pcall(function()
                xp:AddXP(trained.perk, xpToGive, false, false, false, false)
            end)
        end

        self.kh_lastPages = currentPages
    end

    print("[KH] BookPerPageXP v" .. KH.modules.BookPerPageXP .. " hooks installed (per-tick incremental).")
end

-- Try the install immediately (require above should have pulled in ISReadABook),
-- AND also on OnGameBoot for any load-order edge case.
_installBookHooks()
Events.OnGameBoot.Add(_installBookHooks)
