-- Kierpocalyptic Homestead - Play a board game / dice for boredom relief
--
-- Inventory right-click on a chess piece, checkerboard, backgammon board,
-- or game piece offers a "Play a game" timed action. Reduces boredom and
-- unhappiness; emits the game/played thought line.
--
-- Solo play -- effect is meaningful but not OP. Future: bonus if a
-- companion / NPC is adjacent (deferred to companion system work).

require "TimedActions/ISBaseTimedAction"
require "Thoughts/KH_Thoughts"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.PlayGame = "0.0.1"

local GAME_ITEMS = {
    "ChessBlack", "ChessWhite",
    "CheckerBoard", "BackgammonBoard",
    "GamePieceBlack", "GamePieceRed", "GamePieceWhite",
    "Dart",  -- darts as a solo throwing game
}

KH_PlayGameAction = ISBaseTimedAction:derive("KH_PlayGameAction")

function KH_PlayGameAction:isValid() return self.character ~= nil end

function KH_PlayGameAction:start()
    self:setActionAnim("Loot")  -- placeholder; sit anim would be nicer
end

function KH_PlayGameAction:perform()
    local p = self.character
    if p then
        local stats = p:getStats()
        if stats and CharacterStat then
            if CharacterStat.BOREDOM then
                local b = stats:get(CharacterStat.BOREDOM) or 0
                stats:set(CharacterStat.BOREDOM, math.max(0, b - 20))
            end
            if CharacterStat.UNHAPPINESS then
                local u = stats:get(CharacterStat.UNHAPPINESS) or 0
                stats:set(CharacterStat.UNHAPPINESS, math.max(0, u - 8))
            end
        end
        KH.Thoughts.emit(p, "game", "played")
    end
    ISBaseTimedAction.perform(self)
end

function KH_PlayGameAction:new(character)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.maxTime = 200  -- ~10 in-game minutes
    o.stopOnWalk = true
    return o
end

local function onPlayClicked(worldobjects, playerArg)
    local character = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or (playerArg and playerArg.getInventory and playerArg) or getPlayer()
    if not character then return end
    ISTimedActionQueue.add(KH_PlayGameAction:new(character))
end

local function onFillInventoryContext(playerIndex, context, items)
    local character = getSpecificPlayer(playerIndex)
    if not character then return end
    local foundGame = false
    for _, it in ipairs(items or {}) do
        local item = it
        if type(it) == "table" and it.items and it.items[1] then item = it.items[1] end
        if item and item.getType then
            local t = item:getType()
            for _, g in ipairs(GAME_ITEMS) do
                if t == g then foundGame = true; break end
            end
            if foundGame then break end
        end
    end
    if foundGame then
        local label = (getText and getText("ContextMenu_KH_PlayBoardGame")) or "Play a game"
        context:addOption(label, nil, onPlayClicked, playerIndex)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryContext)

print("[KH] Play game action registered for board games / dice / chess pieces")
