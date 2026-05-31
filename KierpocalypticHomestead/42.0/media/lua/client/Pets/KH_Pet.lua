-- Kierpocalyptic Homestead - Pet system
--
-- Right-click any pickupable animal -> "Take as Pet". Pickupable includes
-- wild animals (mice, rats, raccoons) AND the babies of large livestock
-- (calves, lambs, piglets, fawns). The pet flag persists through maturation,
-- so a calf you adopt stays a pet as a cow even though adult cows are not
-- normally pickupable. Mod also marks rabbit stages adoptable (vanilla
-- doesn't flag them) since they're standing in for cats until art is ready.
--
-- Pet provides Therapy-Animals-equivalent stress + happiness boost when
-- within 20 tiles. Fighter species (dog, bull, boar, pig, rooster, plus
-- grown-up cow/sheep/deer/raccoon/rat) auto-engage zombies within 8 tiles
-- via vanilla animal:getBehavior():goAttack(target).
--
-- Feeding uses vanilla items: WaterDish (fluid container) and CatFoodBag/
-- DogFoodBag/PetFood. Pet auto-consumes from these when in adjacent tiles
-- and hunger/thirst is above 40%.
--
-- One pet at a time. Pet death = +40 unhappiness immediate + 14-day cooldown
-- before adopting again (grief floor).
--
-- Pet is tracked by name in modData rather than online ID, so the entity
-- can be re-identified across stage transitions / save-load cycles.

require "ISUI/ISWorldObjectContextMenu"

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.Pet = "0.1.25"
print("[KH] Pet module loading v" .. KH.modules.Pet)


-- ---------- Place / Pick-up / Transfer tag bookkeeping ----------
-- KH_Placed = true is stamped on an item's modData when it was put into the
-- world via right-click -> Place Item (NOT regular Drop). The Rummage trick
-- respects this flag, and the happiness scan gives placed pet objects double
-- weight. The flag is cleared whenever the item leaves the world, so the
-- next interaction starts fresh.

require "TimedActions/ISDropWorldItemAction"
require "TimedActions/ISInventoryTransferAction"
require "TimedActions/ISGrabItemAction"

-- DISABLED 2026-05-12 for weekend playtest. These three monkey-patches
-- wrap vanilla timed-action methods to maintain a KH_Placed modData flag
-- on items the player intentionally placed (so the Rummage trick respects
-- placement). Suspected of contributing to a "Pick Up Animal" CTD via
-- ReturnValues.put NPE inside ISBaseTimedAction:begin. Re-enable once
-- pickup chain is debugged. Without them: Rummage will still work, it
-- just won't differentiate "placed" items from random-drop items.
if false then  -- KH_PLACE_TRACKING_DISABLED
    -- Stamp on Place Item.
    local _origDropComplete = ISDropWorldItemAction.complete
    function ISDropWorldItemAction:complete()
        local ok, result = pcall(_origDropComplete, self)
        if self.isPlaceItem and self.item and self.item.getModData then
            pcall(function() self.item:getModData().KH_Placed = true end)
        end
        if ok then return result end
        return true
    end

    -- Clear on direct pickup from world (right-click "Pick up").
    local _origGrabTransfer = ISGrabItemAction.transferItem
    function ISGrabItemAction:transferItem(item)
        pcall(function()
            local invItem = self.item and self.item.getItem and self.item:getItem()
            if invItem and invItem.getModData then
                invItem:getModData().KH_Placed = nil
            end
        end)
        return _origGrabTransfer(self, item)
    end

    -- Clear on inventory transfer when the source is the floor.
    local _origTransferItem = ISInventoryTransferAction.transferItem
    function ISInventoryTransferAction:transferItem(item)
        pcall(function()
            if self.srcContainer and self.srcContainer.getType
               and self.srcContainer:getType() == "floor"
               and item and item.getModData then
                item:getModData().KH_Placed = nil
            end
        end)
        return _origTransferItem(self, item)
    end
end

local PLAYER_KEY = "KH_Pet"
local PET_KEY    = "KH_Pet"

-- ---------- Names + species recognition ----------
local PET_NAMES = {
    "Biscuit","Mochi","Tofu","Pepper","Sage","Ash","Juniper","Clover","Pickle","Olive",
    "Mango","Pancake","Waffles","Pudding","Beans","Wren","Sparrow","Hazel","Cricket","Moss",
    "Echo","Rune","Cinder","Fern","Goose","Pebble","River","Bramble","Comet","Bean",
    "Penny","Boop","Noodle","Marble","Sprout","Honey","Maple","Tinker","Patches","Smudge",
}

-- Adoptable species (post-scope-pivot): wildlife only. Livestock (chicken,
-- cow, pig, sheep) intentionally excluded. Strings must match canonical
-- animal:getAnimalType() values from B42 vanilla
-- (media/lua/shared/Definitions/animal/AnimalAvatarDefinition.lua).
local KH_ADOPTABLE_WILD = {
    -- Rodents (vanilla eatTypeTrough = "All" - eat anything)
    mouse=true, mousefemale=true, mousepups=true,
    rat=true, ratfemale=true, ratbaby=true,
    -- Raccoons (eatTypeTrough = "AnimalFeed,Grass,Hay,Vegetables,Fruits")
    raccoonboar=true, raccoonsow=true, raccoonkit=true,
    -- Rabbits (rabkitten can't be hand-fed - eatType commented out in vanilla;
    --  adoption still allowed since they'll grow up)
    rabkitten=true, rabdoe=true, rabbuck=true,
    -- Wild turkeys (all stages small enough to handle)
    turkeyhen=true, gobblers=true, turkeypoult=true,
    -- Large wild animals: BABIES ONLY. Adult deer and wild pigs are too
    -- socialized against humans to tame from scratch. If a fawn/piglet is
    -- adopted as a baby and then grows up, the adoption flag persists
    -- (modData PET_KEY stays, st.petId tracks the same online ID across
    -- growth stages, reevalFighter promotes them to fighter status). But
    -- the Adopt OPTION only appears on the baby stage.
    fawn=true,    -- deer baby (adult = doe/buck, NOT adoptable)
    piglet=true,  -- pig baby (adult = sow/boar, NOT adoptable)
}

-- Fighter species: wildlife pets that can credibly engage a zombie. Limited
-- to adult wild species - kits/pups/poults don't fight, but their flag
-- becomes effective when reevalFighter detects growth.
local FIGHTER_SPECIES = {
    raccoonboar = true, raccoonsow = true,  -- adult raccoons
    rat = true, ratfemale = true,           -- big rats
    rabbuck = true,                         -- territorial buck
    gobblers = true,                        -- adult wild turkey
    buck = true, doe = true,                -- adult deer (kick like mules)
    boar = true, sow = true,                -- wild pigs are MEAN
}

-- Reevaluate isFighter every tick based on current species - so a calf that
-- grows into a cow gains defender behavior automatically.
local function reevalFighter(animal, st)
    if not animal or not st then return end
    local sp; pcall(function() sp = animal.getAnimalType and string.lower(animal:getAnimalType() or "") end)
    if sp and sp ~= "" and sp ~= st.petSpecies then
        st.petSpecies = sp
    end
    st.isFighter = FIGHTER_SPECIES[st.petSpecies or ""] or false
end

-- ---------- Helpers ----------
local function pickRand(list) return list[ZombRand(#list) + 1] end

local function petState(player)
    if not player or not player:getModData() then return nil end
    local md = player:getModData()
    if not md[PLAYER_KEY] then
        md[PLAYER_KEY] = {
            petId = nil,        -- animal:getOnlineID() (or persistentID)
            petName = nil,
            petSpecies = nil,
            adoptedHour = nil,
            lastHunger = 0,
            lastThirst = 0,
            isFighter = false,
            grief = 0,
            diedAtHour = nil,
            hasCollar = false,
            playedFetchHour = -1e9,
            chewToyHour = -1e9,
            brushedHour = -1e9,
            -- Happiness 0..100. Bumps from proximity, play, feed, water, brush.
            -- Decays when neglected (no interaction + no nearby pet objects).
            happiness = 60,
            -- Trick training: container online id this pet rummages floor items into
            trickContainerId = nil,
            lastTrickHour = -1e9,
            -- Stay mode flag (already used by onToggleStay)
            stayMode = false,
            -- Follow mode flag - when true, pet teleports adjacent to player
            -- and is "shielded" from nearby zombies via teleport-to-player
            followMode = false,
            -- Assigned-homestead id - when set, pet returns here on stayMode
            -- if it wanders outside. Defaults to nil (no zone binding).
            assignedHomestead = nil,
        }
    end
    return md[PLAYER_KEY]
end

local function nameOf(state) return (state and state.petName) or "your pet" end

local function emit(target, line)
    if not target or not line then return end
    if HaloTextHelper and HaloTextHelper.addText then
        pcall(function() HaloTextHelper.addText(target, line) end)
    end
end

-- Flavor halo lines via the Thoughts dispatcher. {NAME} token in the line
-- template is substituted with the pet's name before display. We monkey-
-- patch a one-shot pickLine substitution by reading the line, applying
-- the token, and queuing through HaloTextHelper directly so the queue
-- pacing still applies via the dispatcher. Simpler approach: emit a key,
-- and the dispatcher reads from KH.ThoughtLines.pet[key] - we do the
-- token swap on the LINE after the dispatcher picks it, by patching the
-- dispatcher's pickLine return. Implemented as: emit -> dispatcher picks
-- a line -> we sub via a thin wrapper here.
local function petThought(player, key, name, force)
    if not player or not key then return end
    if not (KH and KH.ThoughtLines and KH.ThoughtLines.pet and KH.ThoughtLines.pet[key]) then return end
    if not (KH and KH.Thoughts) then return end
    -- Temporarily monkey-patch the lines so {NAME} is substituted for this
    -- call only, then restore. The dispatcher reads KH.ThoughtLines fresh
    -- on each call so a transient swap is safe in single-player.
    local group = KH.ThoughtLines.pet[key]
    local origDefault = group.default
    if origDefault and name then
        local subbed = {}
        for i = 1, #origDefault do
            subbed[i] = (origDefault[i] or ""):gsub("{NAME}", name)
        end
        group.default = subbed
    end
    local fn = force and KH.Thoughts.emitForce or KH.Thoughts.emit
    pcall(function() fn(player, "pet", key) end)
    group.default = origDefault
end

-- Locate the current pet animal entity. Two strategies:
--  1) Direct lookup by online ID via global getAnimal(id) - fastest when valid
--  2) Cell scan via getCell():getObjectListForLua() filtering by IsoAnimal
--     and matching our modData flag + name. This catches the case where the
--     animal got a new ID at a stage transition (calf->cow) or save reload.
local function findPet(state)
    if not state or not state.petName then return nil end

    -- Strategy 1: direct ID lookup
    if state.petId and type(state.petId) == "number" and getAnimal then
        local a
        pcall(function() a = getAnimal(state.petId) end)
        if a and instanceof(a, "IsoAnimal") then
            local amd = a:getModData()
            if amd and amd[PET_KEY] and amd.KH_PetName == state.petName then
                return a
            end
        end
    end

    -- Strategy 2: cell scan by modData flag + name
    local cell = getCell(); if not cell then return nil end
    local objs = cell:getObjectListForLua()
    if not objs then return nil end
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        if o and instanceof(o, "IsoAnimal") then
            local amd = o:getModData()
            if amd and amd[PET_KEY] and amd.KH_PetName == state.petName then
                -- Refresh ID for next-time fast lookup
                pcall(function() state.petId = o:getOnlineID() end)
                return o
            end
        end
    end
    return nil
end

local function speciesOf(animal)
    local t; pcall(function() t = animal.getAnimalType and animal:getAnimalType() end)
    if type(t) == "string" then return string.lower(t) end
    -- Fallback: try getAnimalSubName or breed name
    pcall(function() t = animal.getBreed and animal:getBreed() and animal:getBreed():getName() end)
    return type(t) == "string" and string.lower(t) or "unknown"
end

-- ---------- Adoption / Release ----------
-- Commit adoption with a chosen name. Called by onAdoptAnimal after the
-- naming dialog confirms.
local function commitAdoption(p, animal, name)
    if not p or not animal then return end
    local st = petState(p)
    if st.petId then return end  -- guard against double-confirm
    if not name or name == "" then name = pickRand(PET_NAMES) end
    local species = speciesOf(animal)
    local oid
    pcall(function() oid = animal:getOnlineID() end)
    if not oid then
        emit(p, "Couldn't identify this animal.")
        return
    end
    st.petId       = oid or name
    st.petName     = name
    st.petSpecies  = species
    st.isFighter   = FIGHTER_SPECIES[species] or false
    st.adoptedHour = getGameTime():getWorldAgeHours()
    st.grief       = 0
    st.diedAtHour  = nil

    local amd = animal:getModData()
    amd[PET_KEY] = true
    amd.KH_PetName = name
    amd.KH_PetOwnerOnlineID = p.getOnlineID and p:getOnlineID() or 0

    -- TAMING. Wild animals have AI behaviors that flee from the player.
    -- setBlockMovement alone isn't enough - the wild flee state can override
    -- our block. setWild(false) is the canonical "this animal is tame now"
    -- call vanilla uses in trap-catch (STrapGlobalObject.lua:223) and
    -- pickup (ISPickupAnimal.lua:48). After this, the animal stops fleeing
    -- and treats the player as non-threat.
    pcall(function() animal:setWild(false) end)
    -- Stress reset. Wild animals captured/cornered are high-stress, and
    -- stress >40 blocks vanilla interactions like milking/shearing and
    -- generally makes the animal skittish. Drop to 0 - we just adopted
    -- them and they should be calm.
    pcall(function() if animal.setStress then animal:setStress(0) end end)

    -- Freeze pet AI movement. Pets that wander away the moment they're
    -- teleported to the player feel wrong (and are hard to click). Per
    -- user request: just keep them idle, move only when WE teleport them.
    -- Re-applied each AI tick in case state gets cleared elsewhere.
    pcall(function() animal:getBehavior():setBlockMovement(true) end)

    -- Tell the animal its new name (engine accepts as Say text)
    if animal.Say then pcall(function() animal:Say(name) end) end

    -- Flavor line via Thoughts (force-fire: adoption is a milestone)
    petThought(p, "adopt", name, true)
end

-- ISTextBox callback. button.internal == "OK" means Confirm pressed.
local function onAdoptionDialogResult(target, button, playerArg, animal)
    if button.internal ~= "OK" then return end  -- Cancel: abort cleanly
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    if not p or not animal then return end
    local name = button.parent and button.parent.entry and button.parent.entry:getText() or nil
    if not name or name:gsub("%s","") == "" then
        name = pickRand(PET_NAMES)
    end
    -- Trim and cap length (sanity)
    name = name:gsub("^%s+",""):gsub("%s+$",""):sub(1, 24)
    commitAdoption(p, animal, name)
end

local function onAdoptAnimal(worldobjects, playerArg, animal)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    if not p or not animal then return end
    local st = petState(p)
    -- Only block adoption if the player has a LIVE pet (modData petId resolves
    -- to a real, findable IsoAnimal in the world). A stale petId from a pet
    -- that died/despawned should NOT block. If we detect a stale petId here,
    -- clear it so the player can adopt fresh.
    if st.petId then
        local liveOwnedPet = nil
        pcall(function() liveOwnedPet = findPet(st) end)
        if liveOwnedPet then
            emit(p, string.format("Already have a pet (%s). Disown them first.", nameOf(st)))
            petThought(p, "alreadyHave", nameOf(st), false)
            return
        end
        -- Stale petId - clear it. The previous pet is gone.
        print("[KH][pet] Clearing stale petId/petName (previous pet not findable) before new adoption.")
        st.petId = nil
        st.petName = nil
        st.petSpecies = nil
        st.adoptedHour = nil
    end
    -- Show a name-prompt modal pre-filled with a random suggestion.
    -- ISTextBox: x, y, w, h, title, defaultText, target, onclick, playerNum, ...
    local suggested = pickRand(PET_NAMES)
    local title = "Name your new companion"
    -- ISTextBox callback signature is (target, button, ...extraArgs).
    -- The playerNum slot is consumed by the dialog itself (keyboard focus)
    -- and is NOT forwarded, so we forward playerArg explicitly as an extra
    -- positional argument alongside animal.
    local playerNum = (type(playerArg) == "number") and playerArg or 0
    local modal = ISTextBox:new(
        getCore():getScreenWidth()/2 - 175,
        getCore():getScreenHeight()/2 - 75,
        350, 150,
        title,
        suggested,
        nil,                       -- target
        onAdoptionDialogResult,    -- onclick
        playerNum,                 -- playerNum (engine-internal focus)
        playerArg,                 -- forwarded extra arg 1 -> callback's playerArg
        animal                     -- forwarded extra arg 2 -> callback's animal
    )
    modal:initialise()
    modal:addToUIManager()
    -- Pre-select the suggested name so user can type to replace
    if modal.entry and modal.entry.selectAll then pcall(function() modal.entry:selectAll() end) end
end

local function onReleasePet(worldobjects, playerArg)
    -- "Release" used to mean "drop the held animal back into the world"
    -- (the inverse of Pick up). Disown is now the separate action that
    -- ends the pet relationship.
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    local st = petState(p)
    if not st or not st.petId then
        emit(p, "You don't have a pet.")
        return
    end
    petThought(p, "release", nameOf(st), false)
    -- Vanilla drop happens via standard inventory drop; here we just emit
    -- the flavor line. The actual "drop the held animal" is handled by
    -- the engine when the player drops the InventoryAnimalItem.
end

-- Disown: end the pet relationship. Animal stays in the world (if alive
-- and present) and reverts to wild behavior.
local function onDisownPet(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    local st = petState(p)
    if not st or not st.petId then
        emit(p, "You don't have a pet.")
        return
    end
    local who = st.petName or "your pet"
    petThought(p, "disown", who, true)  -- force: emotional milestone
    local animal = findPet(st)
    if animal then
        local amd = animal:getModData()
        amd[PET_KEY] = nil
        amd.KH_PetName = nil
        amd.KH_PetOwnerOnlineID = nil
        pcall(function() animal:setWild(true) end)
        -- Un-freeze: pet can wander/flee normally now that it's wild again.
        pcall(function() animal:getBehavior():setBlockMovement(false) end)
    end
    -- Clear all pet state including homestead binding, follow, stay, training
    st.petId = nil
    st.petName = nil
    st.petSpecies = nil
    st.isFighter = false
    st.assignedHomestead = nil
    st.followMode = false
    st.stayMode = false
    st.trickContainerId = nil
    st.hasCollar = false
end

local function onPetStatus(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    local st = petState(p)
    if not st or not st.petId then
        emit(p, "You don't have a pet.")
        return
    end
    local animal = findPet(st)
    if not animal then
        emit(p, string.format("%s is somewhere... you can't see them.", nameOf(st)))
        return
    end
    local hung, thir = 0, 0
    pcall(function() hung = animal:getStats():get(CharacterStat.HUNGER) or 0 end)
    pcall(function() thir = animal:getStats():get(CharacterStat.THIRST) or 0 end)
    local fighter = st.isFighter and " (defender)" or ""
    local happy = math.floor(st.happiness or 50)
    local trick = st.trickContainerId and " trained:rummage" or ""
    emit(p, string.format("%s the %s%s. Hunger %d%% Thirst %d%% Happy %d%%%s",
        st.petName, st.petSpecies or "animal", fighter,
        math.floor(hung*100), math.floor(thir*100), happy, trick))
end


-- ---------- Vanilla-item-based interactions ----------

-- Find any item in player's inventory matching one of the types.
local function findInvItem(p, types)
    if not p or not p.getInventory then return nil end
    local inv = p:getInventory()
    if not inv or not inv.getItems then return nil end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it.getType then
            local t = it:getType()
            for _, want in ipairs(types) do
                if t == want then return it end
            end
        end
    end
    return nil
end

-- Give chew toy: reduces boredom on pet. Doesn't consume the toy.
local function onGiveChewToy(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    pcall(function()
        local _st = petState(p); local _nm = _st and _st.petName
        if _nm then petThought(p, "chewToy", _nm, false) end
    end)
    local st = petState(p); if not st or not st.petId then return end
    local toy = findInvItem(p, {"DogChew"})
    if not toy then
        emit(p, "Need a Dog Chew Toy to give.")
        return
    end
    local animal = findPet(st)
    local target = animal or p
    -- Reduce pet stress; chew toy isn't consumed
    pcall(function()
        local stats = animal and animal:getStats()
        if stats and stats.remove then stats:remove(CharacterStat.STRESS, 0.2) end
    end)
    st.chewToyHour = getGameTime():getWorldAgeHours()
    emit(target, string.format("%s plays with the chew toy.", nameOf(st)))
    emit(p, string.format("Gave %s the chew toy.", nameOf(st)))
end

-- Play fetch: requires tennis ball, reduces pet stress + tiredness, gives small player happiness
local function onPlayFetch(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    pcall(function()
        local _st = petState(p); local _nm = _st and _st.petName
        if _nm then petThought(p, "fetch", _nm, false) end
    end)
    local st = petState(p); if not st or not st.petId then return end
    local ball = findInvItem(p, {"TennisBall"})
    if not ball then
        emit(p, "Need a Tennis Ball to play fetch.")
        return
    end
    local animal = findPet(st)
    local target = animal or p
    pcall(function()
        local stats = animal and animal:getStats()
        if stats and stats.remove then
            stats:remove(CharacterStat.STRESS, 0.3)
        end
    end)
    -- Player gets a small happiness bump too
    pcall(function()
        local pstats = p:getStats()
        if pstats and pstats.remove then
            pstats:remove(CharacterStat.UNHAPPINESS, 5)
            pstats:remove(CharacterStat.BOREDOM, 8)
        end
    end)
    st.playedFetchHour = getGameTime():getWorldAgeHours()
    emit(target, string.format("%s chases the ball back and forth.", nameOf(st)))
    emit(p, string.format("Played fetch with %s.", nameOf(st)))
end

-- Brush them: requires Brush or Comb. Cleanliness + morale.
local function onBrushPet(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    pcall(function()
        local _st = petState(p); local _nm = _st and _st.petName
        if _nm then petThought(p, "brush", _nm, false) end
    end)
    local st = petState(p); if not st or not st.petId then return end
    local brush = findInvItem(p, {"Brush", "Comb"})
    if not brush then
        emit(p, "Need a Brush or Comb to groom them.")
        return
    end
    local animal = findPet(st)
    local target = animal or p
    pcall(function()
        local stats = animal and animal:getStats()
        if stats and stats.remove then stats:remove(CharacterStat.STRESS, 0.15) end
    end)
    st.brushedHour = getGameTime():getWorldAgeHours()
    emit(target, string.format("%s leans into the brushing.", nameOf(st)))
    emit(p, string.format("Brushed %s. They look better.", nameOf(st)))
end

-- Put on collar: requires DogTag_Bone or DogTag_Circle. Consumes the tag,
-- sets hasCollar=true on the pet state. Permanent.
local function onPutCollar(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    local st = petState(p); if not st or not st.petId then return end
    if st.hasCollar then
        emit(p, string.format("%s already has a collar.", nameOf(st)))
        return
    end
    local tag = findInvItem(p, {"DogTag_Bone", "DogTag_Circle"})
    if not tag then
        emit(p, "Need a pet tag (DogTag_Bone or DogTag_Circle) for the collar.")
        return
    end
    -- Consume the tag
    pcall(function() p:getInventory():Remove(tag) end)
    st.hasCollar = true
    local animal = findPet(st)
    local target = animal or p
    emit(target, string.format("%s wears the collar proudly.", nameOf(st)))
    emit(p, string.format("Put a collar on %s.", nameOf(st)))
end



-- ---------- Vanilla petting + luring + pickup + stay ----------

-- Pet them: vanilla ISPetAnimal sets the player+animal variables and runs the
-- full stroking animation. Calls animal:petAnimal() on complete which applies
-- trust/stress effect.
local function onPetThem(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    pcall(function()
        local _st = petState(p); local _nm = _st and _st.petName
        if _nm then petThought(p, "pet", _nm, false) end
    end)
    local st = petState(p); if not st or not st.petId then return end
    local animal = findPet(st); if not animal then
        emit(p, string.format("%s isn't here to pet.", nameOf(st)))
        return
    end
    if luautils and luautils.walkAdj and luautils.walkAdj(p, animal:getSquare()) then
        pcall(function() ISTimedActionQueue.add(ISPetAnimal:new(p, animal)) end)
    end
end

-- Come here: vanilla ISLureAnimal needs a food item in primary hand. We pull
-- ANY food the pet can eat (per getEatTypePossibleFromHand) and lure with it.
local function onComeHere(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    pcall(function()
        local _st = petState(p); local _nm = _st and _st.petName
        if _nm then petThought(p, "come", _nm, false) end
    end)
    local st = petState(p); if not st or not st.petId then return end
    local animal = findPet(st); if not animal then
        emit(p, string.format("%s is too far to hear you.", nameOf(st)))
        return
    end
    local foods = buildEatableFoodList(p, animal)
    if #foods == 0 then
        emit(p, "Need food they like to call them over.")
        return
    end
    local item = foods[1]
    pcall(function() ISWorldObjectContextMenu.transferIfNeeded(p, item) end)
    pcall(function()
        ISWorldObjectContextMenu.equip(p, p:getPrimaryHandItem(), item, true, false)
    end)
    pcall(function() ISTimedActionQueue.add(ISLureAnimal:new(p, animal, item)) end)
end

-- Pick up: vanilla ISPickupAnimal carries the animal as inventory item.
-- Only enabled for species small enough for vanilla canBePicked.
local function onPickupPet(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    pcall(function()
        local _st = petState(p); local _nm = _st and _st.petName
        if _nm then petThought(p, "pickup", _nm, false) end
    end)
    local st = petState(p); if not st or not st.petId then return end
    local animal = findPet(st); if not animal then
        emit(p, string.format("%s isn't here.", nameOf(st)))
        return
    end
    local canPick = false
    pcall(function() canPick = animal:canBePicked(p) end)
    if not canPick then
        emit(p, string.format("%s is too big to pick up.", nameOf(st)))
        return
    end
    if luautils and luautils.walkAdj and luautils.walkAdj(p, animal:getSquare()) then
        pcall(function() ISTimedActionQueue.add(ISPickupAnimal:new(p, animal)) end)
    end
end

-- Stay / Free toggle: setBlockMovement freezes/unfreezes the animal.
-- We persist the state in player modData so the submenu label shows current state.
local function onToggleStay(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    local st = petState(p); if not st or not st.petId then return end
    local animal = findPet(st); if not animal then
        emit(p, string.format("%s isn't here.", nameOf(st)))
        return
    end
    st.stayMode = not st.stayMode
    if st.stayMode then st.followMode = false end  -- mutually exclusive
    pcall(function() animal:getBehavior():setBlockMovement(st.stayMode and true or false) end)
    if st.stayMode then
        emit(p, string.format("%s sits down to wait.", nameOf(st)))
    else
        emit(p, string.format("%s is free to roam.", nameOf(st)))
    end
    pcall(function()
        local _st = petState(p); local _nm = _st and _st.petName
        if _nm then petThought(p, _st.stayMode and "stay" or "free", _nm, false) end
    end)
end

-- ---------- Vanilla-based feed + water (uses built-in animations) ----------
-- Vanilla ISFeedAnimalFromHand triggers the animal's getFeedByHandAnim()
-- so they play their own eating animation. We just queue the action with
-- a food item the animal is willing to eat (per getEatTypePossibleFromHand).

local function buildEatableFoodList(p, animal)
    -- Returns list of inventory items the animal can eat from hand.
    local out = {}
    if not p or not animal then return out end
    local inv = p:getInventory()
    if not inv or not inv.getItems then return out end
    local eatList = nil
    pcall(function() eatList = animal:getEatTypePossibleFromHand() end)
    if not eatList then return out end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it then
            local match = false
            -- AnimalFeed items match by getAnimalFeedType
            pcall(function()
                if it.isAnimalFeed and it:isAnimalFeed() then
                    if eatList:contains(it:getAnimalFeedType()) then match = true end
                end
            end)
            -- Food items match by getFoodType
            if not match then
                pcall(function()
                    if instanceof(it, "Food") and it.getFoodType then
                        if eatList:contains(it:getFoodType()) then match = true end
                    end
                end)
            end
            -- Full-type match as a last resort (e.g. "DogChew" specific)
            if not match then
                pcall(function()
                    if it.getFullType and eatList:contains(it:getFullType()) then match = true end
                end)
            end
            if match then table.insert(out, it) end
        end
    end
    return out
end

local function onFeedSpecificFood(playerArg, animal, food)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    if not p or not animal or not food then return end
    if not animal:isExistInTheWorld() then return end
    -- Mirror vanilla onFeedAnimalFood path: walk adjacent, equip food, queue feed action
    pcall(function() animal:getBehavior():setBlockMovement(true) end)
    if luautils and luautils.walkAdj and luautils.walkAdj(p, animal:getSquare()) then
        pcall(function()
            local vec = animal:getAttachmentWorldPos("head")
            ISTimedActionQueue.add(ISWalkToTimedActionF:new(p, vec))
        end)
        pcall(function()
            ISWorldObjectContextMenu.equip(p, p:getPrimaryHandItem(), food, true, false)
        end)
        pcall(function()
            ISTimedActionQueue.add(ISFeedAnimalFromHand:new(p, animal, food))
        end)
    end
end

-- Build a "Feed" submenu listing each eatable food item
local function addFeedSubMenu(context, sub, playerArg, animal, st)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    if not animal then return end
    local foods = buildEatableFoodList(p, animal)
    if #foods == 0 then
        local opt = sub:addOption("Feed " .. nameOf(st) .. " (no compatible food)", worldobjects, nil)
        if opt and opt.notAvailable ~= nil then opt.notAvailable = true end
        return
    end
    local feedOpt = sub:addOption("Feed " .. nameOf(st), worldobjects, nil)
    local feedSub = ISContextMenu:getNew(sub)
    sub:addSubMenu(feedOpt, feedSub)
    local seen = {}
    for _, food in ipairs(foods) do
        local name; pcall(function() name = food:getDisplayName() end)
        if name and not seen[name] then
            seen[name] = true
            feedSub:addOption(name, playerArg, onFeedSpecificFood, animal, food)
        end
    end
end

-- Give water: vanilla ISGiveWaterToAnimal handles animation + sound
local function onGiveWaterToPet(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    pcall(function()
        local _st = petState(p); local _nm = _st and _st.petName
        if _nm then petThought(p, "water", _nm, false) end
    end)
    local st = petState(p); if not st or not st.petId then return end
    local animal = findPet(st)
    if not animal then
        emit(p, string.format("%s is somewhere... you can't see them.", nameOf(st)))
        return
    end
    -- Find any fluid container with water in it
    local container = nil
    local inv = p:getInventory()
    if inv and inv.getItems then
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local fc; pcall(function() fc = it:getFluidContainer() end)
            if fc and fc:getAmount() > 0.05 then
                container = it; break
            end
        end
    end
    if not container then
        emit(p, "Need a water container with fluid in your inventory.")
        return
    end
    pcall(function() animal:getBehavior():setBlockMovement(true) end)
    if luautils and luautils.walkAdj and luautils.walkAdj(p, animal:getSquare()) then
        pcall(function()
            ISWorldObjectContextMenu.equip(p, p:getPrimaryHandItem(), container, true, false)
        end)
        pcall(function()
            ISTimedActionQueue.add(ISGiveWaterToAnimal:new(p, animal, container))
        end)
    end
end


-- ---------- Rummage trick (training) ----------

-- Find any container object on tiles within radius of the pet, return Java IsoObject.
-- We match against a saved online id.
local function findContainerByOnlineId(animal, onlineId, radius)
    if not onlineId or not animal then return nil end
    local sq = animal:getSquare(); if not sq then return nil end
    local cell = getCell(); if not cell then return nil end
    local r = radius or 8
    local bx, by, bz = sq:getX(), sq:getY(), sq:getZ()
    for dy = -r, r do for dx = -r, r do
        local s = cell:getGridSquare(bx + dx, by + dy, bz)
        if s and s.getObjects then
            local objs = s:getObjects()
            if objs then
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    if o and o.getContainer then
                        local c = o:getContainer()
                        if c then
                            local oid; pcall(function() oid = o.getObjectIndex and o:getObjectIndex() end)
                            -- IsoObject has no getOnlineID for general; we use object index + sq xyz hash
                            local key = string.format("%d:%d:%d:%d", bx+dx, by+dy, bz, oid or 0)
                            if key == onlineId then return o end
                        end
                    end
                end
            end
        end
    end end
    return nil
end

-- Build a stable identifier for a world container so we can find it later.
local function containerKey(obj)
    if not obj or not obj.getSquare then return nil end
    local sq = obj:getSquare(); if not sq then return nil end
    local oid; pcall(function() oid = obj.getObjectIndex and obj:getObjectIndex() end)
    return string.format("%d:%d:%d:%d", sq:getX(), sq:getY(), sq:getZ(), oid or 0)
end

-- Try to move one floor-item near the pet INTO the trick container.
-- Called periodically from the AI tick when a trick container is set.
function doRummageTrick(p, st, animal)
    if not st.trickContainerId or not animal then return end
    local container = findContainerByOnlineId(animal, st.trickContainerId, 12)
    if not container then return end
    local containerInv = container.getContainer and container:getContainer()
    if not containerInv then return end
    -- Find a floor item within 4 tiles of pet
    local sq = animal:getSquare(); if not sq then return end
    local cell = getCell(); if not cell then return end
    local bx, by, bz = sq:getX(), sq:getY(), sq:getZ()
    for dy = -4, 4 do for dx = -4, 4 do
        local s = cell:getGridSquare(bx + dx, by + dy, bz)
        if s and s.getObjects then
            local objs = s:getObjects()
            if objs then
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    if o and instanceof(o, "IsoWorldInventoryObject") then
                        local item; pcall(function() item = o:getItem() end)
                        if item then
                            -- Skip pet objects so the pet doesn't put its own toys away
                            local t; pcall(function() t = item:getType() end)
                            local skip = (t == "TennisBall" or t == "DogChew"
                                or t == "WaterDish" or t == "CatFoodBag"
                                or t == "DogFoodBag" or t == "Dogfood" or t == "DogfoodOpen")
                            -- Skip Place-Item-flagged objects (intentional placements)
                            if not skip then
                                local imd; pcall(function() imd = item:getModData() end)
                                if imd and imd.KH_Placed then skip = true end
                            end
                            if not skip then
                                pcall(function() containerInv:AddItem(item) end)
                                pcall(function() o:removeFromWorld() end)
                                pcall(function() o:removeFromSquare() end)
                                st.lastTrickHour = getGameTime():getWorldAgeHours()
                                st.happiness = math.min(100, (st.happiness or 50) + 2)
                                local dn; pcall(function() dn = item:getDisplayName() end)
                                emit(p, string.format("%s puts %s away.", nameOf(st), dn or "an item"))
                                return  -- one per tick
                            end
                        end
                    end
                end
            end
        end
    end end
end

local function onTrainRummage(worldobjects, playerArg, container)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    local st = petState(p); if not st or not st.petId then return end
    if not container then return end
    local key = containerKey(container)
    if not key then
        emit(p, "Can't pin this container as a trick target.")
        return
    end
    st.trickContainerId = key
    emit(p, string.format("%s will rummage floor items into this container.", nameOf(st)))
end

local function onUntrainRummage(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    local st = petState(p); if not st or not st.petId then return end
    st.trickContainerId = nil
    emit(p, string.format("%s no longer has a rummage target.", nameOf(st)))
end


-- ---------- Send pet to a homestead ----------

local function onSendPetToHomestead(worldobjects, playerArg, targetId)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    if not p then return end
    local st = petState(p); if not st or not st.petId then return end
    local animal = findPet(st)
    if not animal then
        emit(p, "Can't find your pet to send.")
        return
    end
    if not KH.Home or not KH.Home.findSquareForBuildingId then
        emit(p, "Home Territory not loaded; can't teleport.")
        return
    end
    local sq = KH.Home.findSquareForBuildingId(p, targetId)
    if not sq then
        emit(p, "That homestead's not loaded right now. Try when you're closer.")
        return
    end
    -- Direct teleport. Animal pathfinding across loaded/unloaded chunks is
    -- unreliable, so we just place it on the target square.
    pcall(function() animal:setX(sq:getX()) end)
    pcall(function() animal:setY(sq:getY()) end)
    pcall(function() animal:setZ(sq:getZ()) end)
    pcall(function() animal:setSquare(sq) end)
    pcall(function() animal:setCurrentSquare(sq) end)
    emit(p, string.format("Sent %s to a homestead.", nameOf(st)))
end

local function addSendToHomesteadOption(sub, playerArg, st)
    if not KH.Home or not KH.Home.listAll then return end
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    local terrs = KH.Home.listAll(p)
    local homesteads = {}
    for _, t in ipairs(terrs) do
        if t.kind == "homestead" then table.insert(homesteads, t.id) end
    end
    if #homesteads == 0 then return end
    local opt = sub:addOption("Send " .. nameOf(st) .. " home", worldobjects, nil)
    local sub2 = ISContextMenu:getNew(sub)
    sub:addSubMenu(opt, sub2)
    for _, id in ipairs(homesteads) do
        -- Display the building id; PZ doesn't expose human names for buildings.
        sub2:addOption(tostring(id), worldobjects, onSendPetToHomestead, playerArg, id)
    end
end


-- ---------- Follow + zone-bind handlers ----------

local function onToggleFollow(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    if not p then return end
    local st = petState(p); if not st or not st.petId then return end
    st.followMode = not st.followMode
    -- Follow and stay are mutually exclusive
    if st.followMode then
        st.stayMode = false
        local animal = findPet(st)
        if animal then
            pcall(function() animal:getBehavior():setBlockMovement(false) end)
        end
        emit(p, string.format("%s falls in behind you.", nameOf(st)))
    else
        emit(p, string.format("%s stops following.", nameOf(st)))
    end
    pcall(function()
        local _st = petState(p); local _nm = _st and _st.petName
        if _nm then petThought(p, _st.followMode and "follow" or "unfollow", _nm, false) end
    end)
end

-- Assign current homestead as the pet's zone-bound area
local function onAssignZone(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    pcall(function()
        local _st = petState(p); local _nm = _st and _st.petName
        if _nm then petThought(p, "bindHome", _nm, false) end
    end)
    if not p then return end
    local st = petState(p); if not st or not st.petId then return end
    if not KH.Home or not KH.Home.currentType then
        emit(p, "Home Territory not available.")
        return
    end
    local sq = p:getCurrentSquare()
    local hereId = sq and KH.Home and KH.Home.typeAt and KH.Home.typeAt(p, sq) and (function()
        local b; pcall(function() b = sq:getBuilding() end)
        local d; pcall(function() d = b and b:getDef() end)
        local i; pcall(function() i = d and d.getIDString and d:getIDString() end)
        return i
    end)() or nil
    if hereId then
        st.assignedHomestead = hereId
        emit(p, string.format("%s will stay in this homestead.", nameOf(st)))
    else
        emit(p, "Need to be in a claimed homestead to bind pet here.")
    end
end

local function onUnassignZone(worldobjects, playerArg)
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    pcall(function()
        local _st = petState(p); local _nm = _st and _st.petName
        if _nm then petThought(p, "freeHome", _nm, false) end
    end)
    if not p then return end
    local st = petState(p); if not st or not st.petId then return end
    st.assignedHomestead = nil
    emit(p, string.format("%s is free to wander anywhere.", nameOf(st)))
end

-- ---------- Pet submenu builder ----------
-- Adds the "[Name]" parent option with all pet-action sub-options to the
-- given context. Shared between OnFillWorldObjectContextMenu (right-click
-- on world objects while owning a pet) and OnClickedAnimalForContext
-- (right-click directly on the pet animal). worldObjOrAnimals is the
-- usual "the thing your callback gets handed" - usually worldobjects or
-- the animals list; we pass it through to each addOption.
-- Quick inventory probe: returns true if the player has at least one item
-- whose Type matches one of the given names. Used to gate menu options on
-- "do you actually have the item this action needs?".
local function hasInvItem(p, types)
    return findInvItem(p, types) ~= nil
end

-- True if the player carries any fluid container with at least a sip of
-- water in it (used to gate the Give-Water option).
local function hasAnyWaterContainer(p)
    if not p or not p.getInventory then return false end
    local inv = p:getInventory()
    if not inv or not inv.getItems then return false end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        local fc
        pcall(function() fc = it.getFluidContainer and it:getFluidContainer() end)
        if fc then
            local amt = 0
            pcall(function() amt = fc:getAmount() end)
            if amt and amt > 0.05 then return true end
        end
    end
    return false
end

local function addPetSubMenu(context, worldObjOrAnimals, playerArg, st)
    if not (st and st.petId) then return end
    -- Dedup guard. Right-clicking the pet animal fires BOTH
    -- OnClickedAnimalForContext AND OnFillWorldObjectContextMenu against the
    -- SAME context object in B42.18, and each handler calls addPetSubMenu ->
    -- two identical pet submenus in one menu. Whichever handler runs first
    -- adds the submenu and stamps the context; the second one bails here.
    -- The flag lives on the per-right-click context, so it resets every click.
    if context.KH_petSubMenuAdded then return end
    context.KH_petSubMenuAdded = true
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    local label = nameOf(st)
    local petOpt = KH.UI.markOption(context:addOption(label, worldObjOrAnimals, nil))
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(petOpt, sub)
    sub:addOption("Check on " .. nameOf(st), worldObjOrAnimals, onPetStatus, playerArg)
    local _animal = findPet(st)
    sub:addOption("Pet " .. nameOf(st),      worldObjOrAnimals, onPetThem, playerArg)
    sub:addOption("Come here, " .. nameOf(st), worldObjOrAnimals, onComeHere, playerArg)
    if _animal then
        addFeedSubMenu(context, sub, playerArg, _animal, st)
    end
    -- Item-gated options: only show when the player has the required item.
    -- Each action checks inventory at execution too, but hiding the option
    -- entirely is cleaner UX than showing options that emit "Need X" when
    -- clicked.
    if hasAnyWaterContainer(p) then
        sub:addOption("Give water",          worldObjOrAnimals, onGiveWaterToPet, playerArg)
    end
    if hasInvItem(p, {"DogChew"}) then
        sub:addOption("Give chew toy",       worldObjOrAnimals, onGiveChewToy, playerArg)
    end
    if hasInvItem(p, {"TennisBall"}) then
        sub:addOption("Play fetch",          worldObjOrAnimals, onPlayFetch, playerArg)
    end
    if hasInvItem(p, {"Brush", "Comb"}) then
        sub:addOption("Brush " .. nameOf(st), worldObjOrAnimals, onBrushPet, playerArg)
    end
    if not st.hasCollar and hasInvItem(p, {"DogTag_Bone", "DogTag_Circle"}) then
        sub:addOption("Put on collar",       worldObjOrAnimals, onPutCollar, playerArg)
    end
    local stayLabel = st.stayMode and ("Free " .. nameOf(st)) or ("Tell " .. nameOf(st) .. " to stay")
    sub:addOption(stayLabel,                 worldObjOrAnimals, onToggleStay, playerArg)
    local followLabel = st.followMode and ("Stop following, " .. nameOf(st)) or ("Follow me, " .. nameOf(st))
    sub:addOption(followLabel,               worldObjOrAnimals, onToggleFollow, playerArg)
    if st.assignedHomestead then
        sub:addOption("Free " .. nameOf(st) .. " from homestead zone", worldObjOrAnimals, onUnassignZone, playerArg)
    else
        sub:addOption("Bind " .. nameOf(st) .. " to this homestead", worldObjOrAnimals, onAssignZone, playerArg)
    end
    addSendToHomesteadOption(sub, playerArg, st)
    sub:addOption("Pick up " .. nameOf(st),  worldObjOrAnimals, onPickupPet, playerArg)
    sub:addOption("Disown " .. nameOf(st),  worldObjOrAnimals, onDisownPet, playerArg)
end

-- ---------- Context menu hook ----------
local function onFillContextMenu(playerArg, context, worldobjects, test)
    if test then return end
    -- Wrap the whole body in pcall. This handler shares Events.
    -- OnFillWorldObjectContextMenu with later-registered KH handlers (e.g.
    -- KH_UseToiletAction's "Use Toilet" option). An unguarded error here
    -- aborted the event chain and silently dropped those later options -
    -- which is why the toilet menu sometimes failed to appear. Failing soft
    -- keeps the rest of the menu intact.
    local ok, err = pcall(function()
    local p = (type(playerArg) == "number") and getSpecificPlayer(playerArg) or getPlayer()
    if not p then return end

    -- Capture option count before we add anything so we can move our KH
    -- options to the top at the end of this handler.
    local _kh_before = (context and context.options and #context.options) or 0

    -- Find an animal among the world objects
    local animal = nil
    for _, obj in ipairs(worldobjects) do
        if obj and instanceof(obj, "IsoAnimal") then
            animal = obj; break
        end
    end

    local st = petState(p)

    -- "Live pet" check - same logic as onClickedAnimalForContext.
    local liveOwnedPet = nil
    if st and st.petId then pcall(function() liveOwnedPet = findPet(st) end) end
    local hasLivePet = liveOwnedPet and true or false

    if animal then
        local amd = animal:getModData()
        local sp; pcall(function() sp = string.lower(animal:getAnimalType() or "") end)
        local adoptable = sp and KH_ADOPTABLE_WILD[sp]
        local alreadyPet = amd and amd[PET_KEY]
        print(string.format("[KH][pet-debug] worldobj click animal type=%s adoptable=%s alreadyPet=%s hasLivePet=%s",
            tostring(sp), tostring(adoptable and true or false),
            tostring(alreadyPet and true or false),
            tostring(hasLivePet)))
        -- Adoption rule: species in KH_ADOPTABLE_WILD AND this specific animal
        -- isn't already someone's pet. We do NOT gate on the player's existing
        -- pet state - the option appears, and the adopt handler can warn/swap.
        if adoptable and not alreadyPet then
            KH.UI.markOption(context:addOption("Adopt as Pet", worldobjects, onAdoptAnimal, playerArg, animal))
        end
    end

    -- If a container is in worldobjects and player has a live pet, offer training.
    if hasLivePet then
        for _, obj in ipairs(worldobjects) do
            if obj and obj.getContainer and obj:getContainer() then
                if st.trickContainerId == containerKey(obj) then
                    KH.UI.markOption(context:addOption("Untrain rummage (" .. nameOf(st) .. ")",
                        worldobjects, onUntrainRummage, playerArg))
                else
                    KH.UI.markOption(context:addOption("Train " .. nameOf(st) .. " to rummage here",
                        worldobjects, onTrainRummage, playerArg, obj))
                end
                break
            end
        end
    end

    -- Always offer pet status / release if we have a live pet
    if hasLivePet then
        addPetSubMenu(context, worldobjects, playerArg, st)
    end

    -- Reorder: KH options to the top of the context menu
    local _kh_after = (context and context.options and #context.options) or 0
    if KH and KH.UI and KH.UI.moveLastAddedToTop then
        KH.UI.moveLastAddedToTop(context, _kh_after - _kh_before)
    end
    end)
    if not ok then
        print("[KH][pet] onFillContextMenu error (suppressed): " .. tostring(err))
    end
end
Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

-- ---------- Animal-click context menu (OnClickedAnimalForContext) ----------
-- IMPORTANT: PZ fires Events.OnClickedAnimalForContext (NOT
-- OnFillWorldObjectContextMenu) when the right-click target is an IsoAnimal.
-- Vanilla's AnimalContextMenu.clickedAnimals handles the standard menu
-- (Pet/Pick Up/Kill/Feed/Water), and we hook the same event to:
--   1) Add "Adopt as Pet" on adoptable wildlife
--   2) Suppress "Kill Animal" inside the per-animal submenu when the
--      animal is an adopted KH pet
-- Vanilla registers first, so by the time we run the animal-name parent
-- option (with its submenu) is already in context.options.
-- Capitalize first letter of a string (for menu labels like "Adopt Rat...")
local function _cap(s) return (s and s ~= "" and (s:sub(1,1):upper() .. s:sub(2))) or s end

-- Friendly common name from animal:getAnimalType(). Maps "raccoonsow" -> "raccoon".
local function _commonName(sp)
    if not sp or sp == "" then return "animal" end
    sp = string.lower(sp)
    -- Strip baby/age suffixes and sex markers down to the base species
    if sp:find("^raccoon")  then return "raccoon" end
    if sp:find("^rabbit") or sp:find("^rabdoe") or sp:find("^rabbuck") or sp:find("^rabkit") then return "rabbit" end
    if sp:find("^mouse")    then return "mouse" end
    if sp:find("^rat")      then return "rat" end
    if sp:find("^turkey") or sp:find("^gobbler") then return "turkey" end
    if sp:find("^fawn")     then return "fawn" end
    return sp
end

local function onClickedAnimalForContext(playerArg, context, animals, test)
    if test then return end
    if not animals or not context then return end
    -- Wrap the whole body in pcall - if anything in here blows up we want the
    -- vanilla menu to still render rather than crashing the JVM.
    local ok, err = pcall(function()
        local p
        if type(playerArg) == "number" then
            p = getSpecificPlayer(playerArg)
        elseif playerArg and playerArg.getInventory then
            p = playerArg
        else
            p = getPlayer()
        end
        if not p then return end
        local pNum = (type(playerArg) == "number") and playerArg
            or (p.getPlayerNum and p:getPlayerNum())
            or 0

        local st = petState(p)
        local _kh_before = (context.options and #context.options) or 0

        -- "Has a live pet" check: if st.petId is set AND the actual animal is
        -- findable, the player is currently a pet owner. Used to decide whether
        -- to render the pet-action submenu - NOT to gate adoption. Per design:
        -- "Adopt as Pet" should always be available on adoptable wildlife;
        -- if the player tries to adopt while already owning, the adopt handler
        -- handles the swap. Otherwise stale modData blocks the Adopt option
        -- forever, which is exactly the bug we're fighting.
        local liveOwnedPet = nil
        if st and st.petId then pcall(function() liveOwnedPet = findPet(st) end) end
        local hasLivePet = liveOwnedPet and true or false

        -- Top-of-handler diagnostic. Wrapped in pcall - if `animals` is a
        -- Java ArrayList that doesn't expose __len, #animals could throw,
        -- and we want the print to be best-effort rather than blocking
        -- the rest of the handler.
        local animalCount = 0
        pcall(function()
            if animals.size then animalCount = animals:size()
            else animalCount = #animals end
        end)
        pcall(function()
            print(string.format("[KH][pet-debug] onClickedAnimalForContext fired: animals=%d, st.petId=%s, st.petName=%s, hasLivePet=%s",
                animalCount, tostring(st and st.petId or "nil"),
                tostring(st and st.petName or "nil"), tostring(hasLivePet)))
        end)

        -- Single-pass scan: collect species the player can adopt + flag if any
        -- of the clicked animals is already this player's pet.
        local adoptCandidates = {}  -- list of {animal, species, common}
        local petAnimalRefs   = {}  -- animals that are our pet (for kill-suppress)
        local hasPetAnimal    = false  -- explicit flag avoids next() inside pcall
        for i = 1, #animals do
            local animal = animals[i]
            local isAnimal = animal and instanceof(animal, "IsoAnimal") or false
            if not isAnimal then
                print(string.format("[KH][pet-debug]   animal[%d] is not IsoAnimal: %s", i, tostring(animal)))
            else
                local amd; pcall(function() amd = animal:getModData() end)
                local sp; pcall(function() sp = animal.getAnimalType and string.lower(animal:getAnimalType() or "") end)
                local adoptable = sp and KH_ADOPTABLE_WILD[sp] or false
                local alreadyPet = (amd and amd[PET_KEY]) and true or false
                print(string.format("[KH][pet-debug]   animal[%d] type=%s adoptable=%s alreadyPet=%s",
                    i, tostring(sp), tostring(adoptable), tostring(alreadyPet)))
                -- Adoption rule: species in KH_ADOPTABLE_WILD AND this specific
                -- animal isn't already someone's pet. We do NOT gate on the
                -- player's existing-pet state - the option appears, and the
                -- adopt handler can warn/swap as needed.
                if adoptable and not alreadyPet then
                    table.insert(adoptCandidates, {animal = animal, sp = sp, common = _commonName(sp)})
                end
                if alreadyPet then
                    petAnimalRefs[animal] = true
                    hasPetAnimal = true
                end
            end
        end
        print(string.format("[KH][pet-debug]   -> adoptCandidates=%d, hasPetAnimal=%s",
            #adoptCandidates, tostring(hasPetAnimal)))

        -- Adoption options: one per UNIQUE common-species in the clicked set.
        -- If three rats are clustered, we only show "Adopt rat" once (using the
        -- first rat in the list as the target). This avoids the 3-duplicates
        -- bug when right-clicking on stacked debug-spawn animals.
        local seenSpecies = {}
        for _, c in ipairs(adoptCandidates) do
            if not seenSpecies[c.common] then
                seenSpecies[c.common] = true
                local label
                if #adoptCandidates == 1 then
                    label = "Adopt as Pet"
                else
                    label = "Adopt " .. c.common .. " as Pet"
                end
                KH.UI.markOption(context:addOption(label, animals, onAdoptAnimal, pNum, c.animal))
            end
        end

        -- If the player has a LIVE pet (animal still resolvable in the world),
        -- show the pet submenu here too. Right-clicking the pet itself goes
        -- through OnClickedAnimalForContext, not the world-object hook, so
        -- without this the pet-action submenu would only appear when right-
        -- clicking non-animal world objects. Gated on hasLivePet to avoid
        -- showing a broken submenu when modData has a stale petId.
        if hasLivePet then
            pcall(function() addPetSubMenu(context, animals, pNum, st) end)
        end

        -- Capture KH-added option count BEFORE the suppression scrub. We
        -- need this for moveLastAddedToTop; the scrub may remove vanilla
        -- entries from earlier in the options array, which would otherwise
        -- corrupt the (after - before) delta.
        local _kh_after = (context.options and #context.options) or 0
        local _kh_added = _kh_after - _kh_before

        -- Full vanilla menu suppression for adopted pets: scrub any top-level
        -- option whose highlight-target IS the pet animal (vanilla's
        -- AnimalContextMenu sets onHighlightParams[1] = animal on its parent
        -- option, which exposes Kill/Pet/Pick Up/Feed/Water/etc). The user's
        -- own KH pet submenu (added by addPetSubMenu above) uses the animals
        -- list as its target, not a single animal, so it survives this scrub.
        --
        -- PZ tracks context.numOptions separately from #context.options and
        -- uses numOptions for height calculation (see ISContextMenu:calcHeight,
        -- line 602: itemsHgt = (numOptions - 1) * itemHgt). Just doing
        -- table.remove leaves numOptions stale and the menu draws blank rows
        -- where the removed options were - hence the "empty space at bottom"
        -- bug. So after each removal we also decrement numOptions, and at the
        -- end we re-id remaining options so internal lookups (mouseOver index,
        -- submenu pointers) stay coherent.
        if hasPetAnimal then
            pcall(function()
                local options = context.options or {}
                local removed = 0
                for j = #options, 1, -1 do
                    local opt = options[j]
                    local hl = opt and opt.onHighlightParams
                    local animal = hl and hl[1]
                    if animal and petAnimalRefs[animal] then
                        table.remove(options, j)
                        removed = removed + 1
                    end
                end
                if removed > 0 then
                    -- Keep numOptions in sync with the shortened array
                    if context.numOptions and context.numOptions > removed then
                        context.numOptions = context.numOptions - removed
                    end
                    -- Re-id remaining options for internal lookups
                    for k, opt in ipairs(options) do
                        if opt then opt.id = k end
                    end
                end
            end)
        end

        -- Reorder KH options to top
        if KH and KH.UI and KH.UI.moveLastAddedToTop then
            pcall(function() KH.UI.moveLastAddedToTop(context, _kh_added) end)
        end
    end)
    if not ok then
        print("[KH][pet] onClickedAnimalForContext error (suppressed): " .. tostring(err))
    end
end
Events.OnClickedAnimalForContext.Add(onClickedAnimalForContext)
print("[KH] Pet animal-click handler registered on OnClickedAnimalForContext.")


-- ---------- Pet AI tick (defender + therapy) ----------
local _aiCounter = 0
local AI_TICK_INTERVAL = 60      -- ~1 game second
local DEFEND_RANGE = 8           -- tiles
local THERAPY_RANGE = 20         -- tiles
local THERAPY_STRESS_TICK = 0.001
local THERAPY_HAPPY_TICK = 0.5

local function findZombieNear(animal, range)
    if not animal or not animal.getSquare then return nil end
    local sq = animal:getSquare(); if not sq then return nil end
    local cell = getCell(); if not cell then return nil end
    local ax, ay, az = sq:getX(), sq:getY(), sq:getZ()
    local best, bestDist = nil, range * range + 1
    for dy = -range, range do
        for dx = -range, range do
            local s = cell:getGridSquare(ax + dx, ay + dy, az)
            if s and s.getMovingObjects then
                local mv = s:getMovingObjects()
                if mv then
                    for i = 0, mv:size() - 1 do
                        local o = mv:get(i)
                        if o and instanceof(o, "IsoZombie") then
                            local skip = false
                            pcall(function() if o:isUseless() then skip = true end end)
                            if not skip then
                                local d = dx*dx + dy*dy
                                if d < bestDist then
                                    bestDist = d
                                    best = o
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function petAITick()
    _aiCounter = _aiCounter + 1
    if _aiCounter < AI_TICK_INTERVAL then return end
    _aiCounter = 0

    local p = getPlayer(); if not p or p:isDead() then return end
    local st = petState(p); if not st or not st.petId then return end
    local animal = findPet(st); if not animal then return end

    -- Re-apply tame state (idempotent). setWild(false) ensures already-
    -- adopted pets from before the taming fix retroactively calm down on
    -- the next AI tick; for newly-adopted pets this is a no-op.
    pcall(function() animal:setWild(false) end)

    -- Re-apply movement freeze (idempotent). Adopted pets stay put except
    -- when WE move them via teleport-based follow / come-here / send-home.
    pcall(function() animal:getBehavior():setBlockMovement(true) end)

    -- Death detection
    local dead = false
    pcall(function() if animal:isDead() then dead = true end end)
    if dead then
        if not st.diedAtHour then
            st.diedAtHour = getGameTime():getWorldAgeHours()
            emit(p, string.format("%s is gone.", st.petName))
            -- Grief: spike unhappiness
            local body = p:getBodyDamage()
            if stats and stats.set then
                pcall(function()
                    stats:set(CharacterStat.UNHAPPINESS, math.min(100, (stats:get(CharacterStat.UNHAPPINESS) or 0) + 40))
                end)
            end
        end
        return
    end

    -- Therapy boost: pet near player calms stress + raises happiness
    local px, py = p:getX(), p:getY()
    local ax, ay = animal:getX(), animal:getY()
    local d2 = (ax-px)^2 + (ay-py)^2
    local nearPlayer = d2 < THERAPY_RANGE * THERAPY_RANGE
    if nearPlayer then
        local body = p:getBodyDamage()
        local stats = p:getStats()
        pcall(function()
            if stats and stats.set then
                stats:set(CharacterStat.STRESS, math.max(0, (stats:get(CharacterStat.STRESS) or 0) - THERAPY_STRESS_TICK))
            end
        end)
        pcall(function()
            if stats and stats.set then
                stats:set(CharacterStat.UNHAPPINESS, math.max(0, (stats:get(CharacterStat.UNHAPPINESS) or 0) - THERAPY_HAPPY_TICK))
            end
        end)
    end

    -- Pet happiness: baseline slow decay, bumps from player proximity + nearby pet objects
    local happy = st.happiness or 50
    local happyDelta = -0.02
    if nearPlayer then happyDelta = happyDelta + 0.04 end
    local petSq = animal:getSquare()
    if petSq then
        local cell2 = getCell()
        if cell2 then
            local bx, by, bz = petSq:getX(), petSq:getY(), petSq:getZ()
            local PET_OBJECT_TYPES = {
                TennisBall=true, DogChew=true, WaterDish=true,
                CatFoodBag=true, DogFoodBag=true,
                Dogfood=true, DogfoodOpen=true,
            }
            local objHits = 0
            for dy = -4, 4 do for dx = -4, 4 do
                local s2 = cell2:getGridSquare(bx + dx, by + dy, bz)
                if s2 and s2.getObjects then
                    local objs = s2:getObjects()
                    if objs then
                        for i = 0, objs:size() - 1 do
                            local o = objs:get(i)
                            if o and instanceof(o, "IsoWorldInventoryObject") then
                                local it; pcall(function() it = o:getItem() end)
                                local t; pcall(function() if it then t = it:getType() end end)
                                if t and PET_OBJECT_TYPES[t] then
                                    -- Placed pet objects count double - intentional pet-home setup
                                    local imd; pcall(function() imd = it:getModData() end)
                                    objHits = objHits + ((imd and imd.KH_Placed) and 2 or 1)
                                end
                            end
                        end
                    end
                end
            end end
            if objHits > 0 then
                happyDelta = happyDelta + math.min(0.05, objHits * 0.015)
            end
        end
    end
    -- Pet is happier when inside one of the player's claimed homesteads
    -- (waystations don't count - those are workshops, not pet homes)
    if KH and KH.Home and KH.Home.isPetAtHomestead and KH.Home.isPetAtHomestead(p, animal) then
        happyDelta = happyDelta + 0.03
    end
    st.happiness = math.max(0, math.min(100, happy + happyDelta))

    -- Rummage trick: if container target set + cooldown ok, attempt one move
    if st.trickContainerId and (getGameTime():getWorldAgeHours() - (st.lastTrickHour or -1e9)) > 0.25 then
        pcall(function() doRummageTrick(p, st, animal) end)
    end

    -- Re-evaluate species + fighter status (catches calf-to-cow growth)
    reevalFighter(animal, st)

    -- Skip ALL teleport logic if pet is in player's hands (Pick Up active).
    -- isHeld() is the vanilla check for AnimalInventoryItem-held animals.
    local inWorld = true
    pcall(function() inWorld = animal:isExistInTheWorld() end)
    local held = false
    pcall(function() held = animal.isHeld and animal:isHeld() end)
    local mobile = inWorld and (not held)

    -- Helper: is this zombie up + capable of attacking right now?
    -- Filters out crawlers, fake-dead, and on-ground zombies.
    local function isStandingThreat(z)
        if not z then return false end
        local onGround = false
        pcall(function() onGround = z.isOnGround and z:isOnGround() end)
        if onGround then return false end
        local crawling = false
        pcall(function() crawling = z.isCrawling and z:isCrawling() end)
        if crawling then return false end
        local fake = false
        pcall(function() fake = z.isFakeDead and z:isFakeDead() end)
        if fake then return false end
        return true
    end

    -- Helper: is this zombie in ACTIVE PURSUIT mode (sprinting/running)?
    -- This is the "reaching-walk thing they do when attacking" anim state
    -- the user identified. Zombies that have spotted prey and are closing
    -- in switch to sprint or run; just-shambling zombies do neither.
    --
    -- 42.18 added getSpeedType(). A standing sprinter (or fast-shambler)
    -- within 2 tiles is effectively already on us - they close before our
    -- next intent check fires. Promote those speed classes to "active
    -- hunter" regardless of current motion. Fakeshamblers stay on the
    -- motion-only check because they intentionally LOOK passive most of
    -- the time - flagging them on classification alone would false-
    -- positive every fakeshambler we walked past.
    local function isActivelyHunting(z)
        if not isStandingThreat(z) then return false end
        local speedType = nil
        pcall(function() speedType = z.getSpeedType and z:getSpeedType() end)
        if speedType then
            local s = tostring(speedType):lower()
            if s:find("sprint") or s:find("fastshambler") or s:find("fast_shambler") then
                return true
            end
        end
        local sprinting = false
        pcall(function() sprinting = z.isSprinting and z:isSprinting() end)
        if sprinting then return true end
        local running = false
        pcall(function() running = z.isRunning and z:isRunning() end)
        return running
    end

    -- Follow mode: teleport pet adjacent to player when out of range
    if st.followMode and mobile then
        local pSq = p:getCurrentSquare()
        if pSq then
            local pdx = animal:getX() - p:getX()
            local pdy = animal:getY() - p:getY()
            if (pdx*pdx + pdy*pdy) > 4 then  -- >2 tiles away
                pcall(function() animal:setX(p:getX() + 1) end)
                pcall(function() animal:setY(p:getY()) end)
                pcall(function() animal:setZ(p:getZ()) end)
                pcall(function() animal:setSquare(pSq) end)
                pcall(function() animal:setCurrentSquare(pSq) end)
            end
        end

        -- Defender: scan 2-tile Manhattan around player. Prefer an actively-
        -- hunting zombie (sprint/run), fall back to nearest standing zombie
        -- if no hunters present. So pet engages threats first but still
        -- helps with shamblers at melee distance.
        if st.isFighter and pSq then
            local pX, pY, pZ = p:getX(), p:getY(), p:getZ()
            local cell = getCell()
            local hunter, fallback = nil, nil
            local hunterDist, fbDist = 999, 999
            if cell then
                for dx = -2, 2 do for dy = -2, 2 do
                    if not (dx == 0 and dy == 0) then
                        local s2 = cell:getGridSquare(math.floor(pX + dx), math.floor(pY + dy), math.floor(pZ))
                        if s2 and s2.getMovingObjects then
                            local mv = s2:getMovingObjects()
                            if mv then
                                for i = 0, mv:size() - 1 do
                                    local o = mv:get(i)
                                    if o and instanceof(o, "IsoZombie") then
                                        local d = math.abs(dx) + math.abs(dy)
                                        if isActivelyHunting(o) and d < hunterDist then
                                            hunter = o; hunterDist = d
                                        elseif isStandingThreat(o) and d < fbDist then
                                            fallback = o; fbDist = d
                                        end
                                    end
                                end
                            end
                        end
                    end
                end end
            end
            local zomb = hunter or fallback
            if zomb then
                pcall(function()
                    if animal.getBehavior and animal:getBehavior() and animal:getBehavior().goAttack then
                        animal:getBehavior():goAttack(zomb)
                    end
                end)
            end
        end

        -- Teleport-shield: only fires when a zombie within 2 tiles of the
        -- pet is in ACTIVE PURSUIT mode (sprinting/running). A passive
        -- shambler nearby doesn't yank the pet around. This is the
        -- engine-exposed "is this zombie attacking" signal we have access
        -- to, since zombie:getTarget() isn't exposed.
        if pSq then
            local aSq = animal:getSquare()
            if aSq then
                local cell = getCell()
                local hunter = nil
                if cell then
                    local ax, ay, az = aSq:getX(), aSq:getY(), aSq:getZ()
                    for dx = -2, 2 do for dy = -2, 2 do
                        if not hunter and (dx ~= 0 or dy ~= 0) then
                            local s2 = cell:getGridSquare(ax + dx, ay + dy, az)
                            if s2 and s2.getMovingObjects then
                                local mv = s2:getMovingObjects()
                                if mv then
                                    for i = 0, mv:size() - 1 do
                                        local o = mv:get(i)
                                        if o and instanceof(o, "IsoZombie") and isActivelyHunting(o) then
                                            hunter = o; break
                                        end
                                    end
                                end
                            end
                        end
                    end end
                end
                if hunter then
                    pcall(function() animal:setX(p:getX()) end)
                    pcall(function() animal:setY(p:getY()) end)
                    pcall(function() animal:setZ(p:getZ()) end)
                    pcall(function() animal:setSquare(pSq) end)
                    pcall(function() animal:setCurrentSquare(pSq) end)
                end
            end
        end
    end

    -- Zone bind: only if pet is in the world AND not held. Skips when the
    -- player is carrying the pet to a new location.
    if st.assignedHomestead and mobile then
        local petSq2 = animal:getSquare()
        local petBuildId = nil
        pcall(function()
            local b = petSq2 and petSq2:getBuilding()
            local d = b and b:getDef()
            petBuildId = d and d.getIDString and d:getIDString()
        end)
        if petBuildId ~= st.assignedHomestead then
            if KH.Home and KH.Home.findSquareForBuildingId then
                local homeSq = KH.Home.findSquareForBuildingId(p, st.assignedHomestead)
                if homeSq then
                    pcall(function() animal:setX(homeSq:getX()) end)
                    pcall(function() animal:setY(homeSq:getY()) end)
                    pcall(function() animal:setZ(homeSq:getZ()) end)
                    pcall(function() animal:setSquare(homeSq) end)
                    pcall(function() animal:setCurrentSquare(homeSq) end)
                end
            end
        end
    end
end
Events.OnTick.Add(petAITick)

-- ---------- Pet hunger/thirst gentle drain + bowl-consumption ----------
-- Animals already have hunger/thirst stats. We just look for nearby pet bowls
-- and "feed" the pet by pulling from them when the animal is in adjacent tile.
-- Checks two sources: (a) items dropped on the ground (IsoWorldInventoryObject),
-- and (b) items inside furniture containers (fridges, cabinets, etc.) on the
-- same tile. Returns the InventoryItem on hit, or nil.
local function _itemMatches(it, fluidContainer)
    if not it then return false end
    if fluidContainer then
        local fc; pcall(function() fc = it:getFluidContainer() end)
        if fc and fc:getAmount() > 0.05 then return true end
    else
        local t; pcall(function() t = it:getType() end)
        if t == "CatFoodBag" or t == "DogFoodBag" or t == "PetFood"
           or t == "Dogfood" or t == "DogfoodOpen"
           or t == "WaterDish" then
            return true
        end
    end
    return false
end

local function findNearbyBowl(animal, fluidContainer)
    if not animal or not animal.getSquare then return nil end
    local sq = animal:getSquare(); if not sq then return nil end
    local cell = getCell(); if not cell then return nil end
    local ax, ay, az = sq:getX(), sq:getY(), sq:getZ()
    for dy = -1, 1 do
        for dx = -1, 1 do
            local s = cell:getGridSquare(ax + dx, ay + dy, az)
            if s then
                local objs = s:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local o = objs:get(i)
                        -- (a) Ground items dropped on this tile
                        if o and instanceof(o, "IsoWorldInventoryObject") then
                            local it; pcall(function() it = o:getItem() end)
                            if _itemMatches(it, fluidContainer) then return it end
                        end
                        -- (b) Items inside furniture containers (fridges etc.)
                        if o and o.getContainer then
                            local cont = o:getContainer()
                            if cont and cont.getItems then
                                local items = cont:getItems()
                                for j = 0, items:size() - 1 do
                                    local it = items:get(j)
                                    if _itemMatches(it, fluidContainer) then return it end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

Events.EveryHours.Add(function()
    local p = getPlayer(); if not p or p:isDead() then return end
    local st = petState(p); if not st or not st.petId then return end
    local animal = findPet(st); if not animal then return end
    -- TODO: restore pet hunger/thirst gentle-drain from nearby bowls. The
    -- original body of this block was lost during an editing pass that
    -- truncated the file at line 1750 (caught when PZ refused to load with
    -- "'end' expected near <eof>"). Animals have vanilla hunger/thirst
    -- stats already, so the pet survives without us topping it up - this
    -- is purely the QoL "auto-feed from bowls within 1 tile" feature.
    -- Stub keeps the file compiling; rebuild from the design comment above.
end)
