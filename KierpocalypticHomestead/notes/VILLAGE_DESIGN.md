# KH "Feed a Village" - Design Spec

**Heart-of-vision feature.** Kierstal's stated goal in her own words: *"I always make more food than I can eat, and I want to feed a village."* Her cooking and farming exist to feed people who depend on her. The mechanics are the vessel for housekeeper/LTC-care energy in game form.

**Last design pass:** 2026-05-29
**Dependencies:** BWO + Bandits (installed) + SSR Core (workshop 1178769629, delisted from search but downloadable via direct link, installed) + SSR Quest System (workshop 2793385743, with extensions e1 FurnitureFolks + e2 Mannequin NPCs + e3 Trade Plugin) + KH_HomeTerritory (existing). SSR Core provides utility libs (SSRTimer, crc32, serpent serialization), SyncClient/SyncServer for MP, SSRChat helper (pushes lines into vanilla ISChat, no BWOChat conflict), and vanilla UI patches (ISImageMod, ISLabelMod, ISModalDialogMod). Non-invasive at the layers KH cares about. The Trade Plugin (e3) gives merchant mechanics out of the box, opening a "resident can also be a shopkeeper" role.

## The emotional engine (the actual point)

The mod isn't really about feeding NPCs. It's about Kierstal's stockpile having a destination.

She overfarms in every survival game she plays. She cooks more than she can eat. Her food usually spoils before she gets to it, and watching that waste frustrates her even though she knows it's pixels. That tendency is a feature, not a bug - it's how she relates to food and care. The mod's job is to give her stockpile somewhere to go.

The crate of beef jerky in her basement isn't hoarding anymore - it's the multi-day reserve for the family across town. The pumpkin patch isn't overproduction - it's the buffer that keeps three safehouses fed through winter. Her tendency to overgrow becomes the resource the village runs on. Her frustration at wasted pixels becomes the answer to why anything she grows matters.

The win condition for the loop: she heads out on a multi-day generator-scouting trip with the calm certainty that the family in the shed across town will be alive when she gets back because she dropped off enough jerky before leaving.

If the implementation drifts from that feeling - if it becomes Tamagotchi or chore-game - we've missed the point.

## Three territory types

KH_HomeTerritory currently supports two types (Homestead, Waystation). We add a third for the village layer:

| Type | What it is | Resident count source | Food mechanic |
|---|---|---|---|
| **Homestead** | Where the player lives. SSR FNPCs can be placed here as residents. | Count of SSR FNPCs in the building | Food consumed daily by residents (and pets) |
| **Safehouse** | NPCs live here, player visits to deliver supplies. Player does not live here. | Declared at registration time ("there are 4 people in this house") | Food consumed daily by declared residents |
| **Waystation** | Workshop. No residents. | Always 0 | No food logic |

A player has one Homestead, multiple Waystations, multiple Safehouses. Total scope target is 3-5 buildings under care, 1-4 residents each.

## Layered architecture

| Layer | What it does | Mod | Status |
|---|---|---|---|
| Town life | Wandering NPCs, scenarios, BWOEvents (BuildingParty, Arson, Entertainer, etc.) | BWO + Bandits | Existing |
| Homestead residents | Static placed NPCs (FNPC), persistent, dialogue-driven, right-click "Talk" | SSR Quest System + ssr_quests-e1 (FurnitureFolks) or e2 (Mannequin NPCs) | Existing |
| Territory | Which buildings are claimed Homesteads / Safehouses / Waystations | KH_HomeTerritory v0.2.1 (needs Safehouse type added) | Existing, extend |
| Recruitment | BWO bandit → SSR FurnitureFolk transition (recruit) OR Safehouse declaration (delivery) | KH | To build |
| Daily food pass | Per-territory food consumption with four-pass hierarchy | KH | To build |
| Hunger debt + starvation | Accumulating debt when fed insufficient; resident death after N days | KH | To build |
| Recognized NPC registry | Centralized "your people" list, gates KH_Loner and feeds these systems | KH_NPCRegistry v0.0.1 | Shipping |

## SSR API surface (verified by code read)

- **`FNPC` class** (in ssr_quests-e1) - derives from `ISBuildingObject`. Methods: `:spawn()`, `:despawn()`, `:setAnimation()`. Java object name is `NPC_<character_name>` - this is what FurnitureFolks looks for on right-click to attach the "Talk" option.
- **`CharacterManager.instance`** - registry of characters. `.items[char_id]` has `.spawned`, `.displayName`, `.file` (dialogue script path), `.isAlive()`, `:getStat(name)`.
- **`FFManager.instance`** - registry of FNPC entities placed in the world. `.items[]` and `.items_size`. Iterable for counting residents per building.
- **`DialoguePanel.create`** - opens the dialogue UI when right-click "Talk" is clicked. Driven by quest scripts in SSR's scripting language.
- **`QSystem.validate("mod-id")`** - permissive plugin registration, always returns true.
- **Quest commands** in `CommandList_a.lua` (105KB) - the scripting language. Tags like `<SIZE:large>`, `<BR>`, char/stat refs. Conditional rendering.
- **e2 Mannequin NPCs** - alternative to e1 FurnitureFolks. Higher-fidelity (full character model with clothing). Real upgrade option for residents that should look like people, not flat sprites.
- **e3 Trade Plugin** - `MerchantManager`, `MerchantPanel`, `MerchantCommands`. A resident can also be a merchant; right-click → Trade opens a barter UI.

## Daily food consumption (the model)

Kierstal's framing: NPCs don't tick hunger as a tracked stat - that's wasteful. Instead, food in their building decreases each day by an amount equal to what residents would eat. When the pantry runs dry, residents go hungry. When it stays dry, they accumulate debt. When the debt hits the threshold, a resident dies.

**Daily consumption budget:** 100 hunger points per person per day, flat. No trait-aware adjustment (too much complexity for too little payoff). Pets eat their own budget separately.

**Eat order: rot-first.** When a building has multiple food sources, the daily pass uses food closest to spoilage first. Fresh-cooked meals get saved, stale cans get eaten. This makes Kierstal's fresh cooking feel valuable - she brings the good stuff and they save it for last like real people would.

**Four-pass hierarchy per building per day:**

1. **Pet bowls on ground.** Pet residents eat first from any food bowl on the ground (vanilla water dish, KH bowl items). Closest to "real pets" behavior.
2. **Petfood containers.** Pet residents still hungry → eat from petfood items in any container (CatFoodBag, DogFoodBag, PetFood). 
3. **Human food, rot-first.** Person residents eat human-edible cooked or ready-to-eat food, sorted by spoilage timer ascending (most-spoiled first). 
4. **Last-resort petfood.** Person residents still in deficit → fall back to petfood containers. Maps to Kierstal's "shouldn't die with cans in the basement" instinct. Means you can't deliberately feed pet food as a strategy (it'll only get eaten if literally nothing else is available).

**Per-portion math (the careful part):** PZ items declare `HungerChange` (the hunger reduction value when eaten whole) and B42 supports 1/4 and 1/2 portion eats. For a pot of stew with HungerChange -100, a 1/4 consumption closes -25 of the daily need and leaves -75 still in the pot. The mechanics already exist in vanilla `ISInventoryPaneContextMenu` and the EatFood timed action - we replicate the same math: walk the building's containers, take portions matching today's need, leave partials in place, move to the next item.

**What counts as edible-without-prep:** cooked meals, bread, jars of peanut butter, canned food that's been opened (or has a no-opener flag), fruit, ready-to-eat snacks. Excluded: raw meat, raw vegetables, items requiring a heat source, items requiring a separate utensil (uncooked rice etc).

**Empty container return:** vanilla items declare `ReplaceOnUse = Pan_Dirty` or `Bowl_Empty`. When a multi-portion food is fully consumed, the empty replacement gets left in the building's inventory. The player picks it up on her next visit naturally because she's the one going there.

## Hunger debt + starvation

When supplies don't cover the daily need, the building accumulates **hunger debt** equal to the unmet portion. Debt is per-building, not per-resident.

| Toggle | Default | Effect |
|---|---|---|
| `KHCompat.HungerDebtEnabled` | ON | Debt accumulates when daily need unmet |
| `KHCompat.HungerDebtStarveDays` | 5 | Days of zero-food / full-debt before a resident dies |
| `KHCompat.HungerDebtSoftMode` | OFF | If ON, "starvation" instead removes residents (they leave to find food elsewhere) rather than killing them |

**Default behavior is harsh:** five days of empty pantry kills a resident. Long enough that "I'll be back from the generator scouting trip" works. Short enough that a forgotten safehouse becomes a real loss. Kierstal explicitly chose this over the gentler "just bark again tomorrow" version because consequences are part of the point.

**Resident death** at a Homestead = vanilla zombification (the FNPC despawns, a zombie spawns in their tile). At a Safehouse = same, but the building is also un-flagged as a Safehouse since the family it represented is gone.

**Soft mode** (toggle for less-brutal playthroughs) = the resident packs up and leaves rather than dying. "Sarah set off to find food somewhere else." Building stays flagged but with -1 resident count.

## Recruitment flow (two modes)

The player encounters BWO NPCs in the world. Dialogue gives three choices:

| Choice | Outcome | Mechanism |
|---|---|---|
| *"Come live with me"* | NPC becomes recruit. Bandit switches to Companion program. Follows player home. On arrival at Homestead, converts to SSR FNPC resident. | Bandits ZPCompanion + SSR FNPC.spawn() |
| *"I can bring food sometimes"* | NPC stays in their building. Building is registered as a Safehouse. Player declares resident count. | KH_HomeTerritory.registerSafehouse() |
| *"Stay alive out there"* | No relationship. Walk away. | No-op |

Some NPCs pre-bias the options based on their context. A starving wanderer can be recruited but probably can't sustain a Safehouse (they have no building). A barricaded family with their own stash might not WANT to leave their place. A loner in a shed might be open to either.

**Recruit path internals:**

1. Player chats with BWO bandit (BWOChat - existing keyword match)
2. KH-injected "Come live with me" option triggers
3. NPC's program switches to Companion (Bandits API)
4. NPC follows player back to claimed Homestead
5. On arrival, KH:
   - Reads BWO bandit's identity (name, sex, age, outfit)
   - Creates CharacterManager entry
   - Picks an unoccupied tile in the Homestead
   - Instantiates FNPC, calls `:spawn()`
   - Despawns the BWO bandit
   - Calls `KH.recognizeNPC(id, "resident", displayName)` (registry)
   - Notification: "<name> has moved into your homestead"

**Delivery path internals:**

1. Player chats with BWO bandit
2. KH-injected "I can bring food sometimes" option triggers
3. Player picks declared resident count (1-4)
4. KH:
   - Marks the bandit's current building as a Safehouse via KH_HomeTerritory
   - Stores declared resident count on the building's modData
   - Calls `KH.recognizeNPC(id, "client", displayName)` for the bandit
   - Notification: "You've committed to feeding the people at <building>"

## What this needs from us

In rough order of dependency:

- Extend KH_HomeTerritory with Safehouse type + declared resident count
- BWOChat option injection (the dialogue layer)
- BWO bandit identity reader (name, age, sex, outfit)
- BWO bandit → SSR FNPC conversion
- Safehouse registration flow
- Daily food consumption pass (four-pass hierarchy)
- Hunger debt tracking on each Homestead and Safehouse
- Starvation event + death/leave branch based on soft-mode toggle
- SSR quest definition for "BringFoodTo_<building_id>" for the bark side
- Trade integration via SSR e3 (some residents are also merchants)

## RAM budget reality check

Kierstal's Lenovo Slim has 5GB usable RAM. Current mod stack at boot: BWO + Bandits + AE + Meowboid + CyberDog + Lifestyle + Saph + HGTS + Sims trio + KH + SSR Core + SSR Quests + e1 + e2 + e3. Each is meaningful overhead.

**Mitigations baked into design:**
- Stateless hunger (no per-NPC tick, only daily scan)
- Bounded scope (claimed buildings only, recognized NPCs only)
- 15-NPC ceiling implied by 3-5 buildings × 1-4 residents
- Daily-scan frequency, not per-tick

**Don't slip into:** every house in town has residents. Tempting but would kill performance.

## Inspiration anchor

This feature exists because Kierstal cares for people. Her LTC housekeeping job, her cooking-too-much pattern, her "feed people who need feeding" instinct. The game should let her live that pattern in pixel form.

She's the housekeeper for the apocalypse. The one who shows up at the door. Park Ranger by profession, archer by character (PZ doesn't have archery but the temperament is there), Fear-of-Blood and Reluctant-Fighter and Thin-Skinned but Outdoorsy and Crafty and Keen-Cook and Forage-Feast. She doesn't want to fight - she wants to deliver. Loner with strangers, comfort with her own people. Same instinct as her real work, different uniform.

The repeatable comfort loop the mod is for: she logs in. She checks on her people - the residents at her homestead, the families in the safehouses she's committed to. She brings food. She gets thanked. She leaves. Sometimes she's just delivering, sometimes she's listening to dialogue, sometimes she's bringing home a half-starved stranger she met in a shed. The danger is real (zombies, bandits, the world). The home is actually safe. The cooking actually matters. The stockpile has a destination.
