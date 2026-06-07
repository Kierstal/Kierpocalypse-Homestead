-- Kierpocalyptic Homestead - room filth scanner
--
-- Scoring function shared by KH_FilthMoodlet (per-tick mood effects) and
-- any future cleaning recipe / context menu.
--
-- Score = bloodSquares + trashCount across the room the player stands in.
-- Outdoors -> score = 0 (effectively disables filth penalty outside).
--
-- API:
--   KH.FilthScan.isTrashObject(obj)       -> bool
--   KH.FilthScan.scoreRoom(player)        -> {blood, trash, total, room}

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.FilthScan = "0.0.1"
KH.FilthScan = KH.FilthScan or {}

local TRASH_PATTERN = "^trash_%d"

function KH.FilthScan.isTrashObject(obj)
    if not obj or not obj.getSprite then return false end
    local sprite = obj:getSprite()
    if not sprite or not sprite.getName then return false end
    local name = sprite:getName()
    if not name then return false end
    return string.find(string.lower(name), TRASH_PATTERN) ~= nil
end

-- Returns {blood, trash, total, room}. If outdoors, room=nil and all 0.
function KH.FilthScan.scoreRoom(player)
    local result = { blood = 0, trash = 0, total = 0, room = nil }
    if not player or player:isDead() then return result end
    local sq = player.getCurrentSquare and player:getCurrentSquare()
    if not sq then return result end
    local room = sq.getRoom and sq:getRoom()
    if not room then return result end  -- outdoors
    result.room = room
    local squares = room.getSquares and room:getSquares()
    if not squares or not squares.size then return result end
    for i = 0, squares:size() - 1 do
        local s = squares:get(i)
        if s then
            -- blood
            if s.haveBloodFloor and s:haveBloodFloor() then
                result.blood = result.blood + 1
            end
            -- trash via static moving objects
            local objs = s.getStaticMovingObjects and s:getStaticMovingObjects()
            if objs and objs.size then
                for j = 0, objs:size() - 1 do
                    if KH.FilthScan.isTrashObject(objs:get(j)) then
                        result.trash = result.trash + 1
                    end
                end
            end
            -- also check world objects layer
            local wobjs = s.getWorldObjects and s:getWorldObjects()
            if wobjs and wobjs.size then
                for j = 0, wobjs:size() - 1 do
                    if KH.FilthScan.isTrashObject(wobjs:get(j)) then
                        result.trash = result.trash + 1
                    end
                end
            end
        end
    end
    result.total = result.blood + result.trash
    return result
end
