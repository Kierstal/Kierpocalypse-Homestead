-- Kierpocalyptic Homestead - remove the trap distance restriction
--
-- Vanilla STrapGlobalObject:checkForAnimal returns early if called with the
-- "square is streamed" argument (i.e., a player is nearby). That's why traps
-- don't catch animals near your base. We patch the function to keep the
-- wall-exploit check but proceed to the animal-finding logic regardless.

require "Traps/STrapGlobalObject"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.TrapNoDistance = "0.0.1"

local function patchedCheckForAnimal(self, square)
    if square then
        if self.checkForWallExploit and self:checkForWallExploit(square) then
            self:removeAnimal()
            self:removeBait()
            return  -- still bail on actual exploits
        end
        -- Vanilla returns here. We don't.
    end
    if self.destroyed then return end

    local animalsList = {}
    if self.zones then
        for zoneType in pairs(self.zones) do
            self:testForAnimal(zoneType, animalsList)
        end
    else
        self:testForAnimal(self.zone, animalsList)
    end

    if #animalsList > 0 then
        local idx = ZombRand(#animalsList) + 1
        local testAnimal = animalsList[idx]
        if testAnimal then
            self:noise('trapped ' .. testAnimal.type .. ' ' .. self.x .. ',' .. self.y .. ',' .. self.z)
            self:setAnimal(testAnimal)
        end
    end
end

if STrapGlobalObject then
    STrapGlobalObject.checkForAnimal = patchedCheckForAnimal
    print("[KH] Trap distance restriction removed.")
end
