# Implementation Log — Reconciliation Pass

**Pass date:** 2026-05-27
**Method:** Rebuilt from on-disk evidence. No design doc available.
Features inferred from filenames, header comments, and one-line function
purposes. **This log is not gospel.** It's a best-effort honest map of
what's currently on disk.

The previous version of this log was authored 2026-05-13 and covered
only the original lunch-time delegation pass (Phases 1–5). Between then
and now, multiple Claude instances + direct edits by Kierstal extended
the mod substantially. The log was 16 days stale.

**Disk-state headline (2026-05-27):**

- 66 KH Lua modules across `client/`, `shared/`, `server/`
- 11 KH script files (items + recipes)
- 1 sandbox-options.txt
- 1 translation file (`UI.json`)
- 1 preset (`KierpocalypticRising.lua`)
- 6 notes files in `notes/`
- 1 sprite-reference folder (`reference_sprites/`)
- Total ~105 files in the mod tree

---

## Reading guide

Each feature cluster below lists:
- **What it does** (from headers + module names)
- **Where the code lives**
- **Status flags:** ✓ stable / ⚠ flagged uncertainty / ⊗ broken-or-dead
  best-guess. Status comes from header self-disclosure, function calls
  observed in the inventory, and known-uncertainty list at the bottom.

Files cluster by *behavior they implement*, not by directory. Several
features span both `client/` and `shared/` paths.

---

## 1. Trait system

**What it does:** Registers 20 KH-namespaced traits at boot and wires
per-trait behavior modules. Mutex pairs supported. Vanilla trait/
profession integration via `KH.hasTrait`.

**Registry:** `shared/Traits/KH_TraitRegistry.lua` v0.0.3
- Pluviophile / Pluviophobe (mutex), ComicNerd, TherapyAnimals,
  ForageFeast, NeatFreak / Slob (mutex), ToughBladder / WeakBladder
  (mutex), Outdoorsy, CaffeineDependent, ColdHands, Tinnitus,
  EasilyStartled, Sentimental, HighMaintenance, Loner, NeedsAttention,
  HatesAnimals, Vegetarian, Vegan

**Per-trait behavior files** in `client/Traits/`:
- `KH_Pluvio.lua` — periodic stress/unhappiness shift in rain ✓
- `KH_ComicNerd.lua` — doubles boredom/unhappiness relief from comics ✓
- `KH_TherapyAnimals.lua` — animal-proximity calm; mirror of HatesAnimals ✓
- `KH_HatesAnimals.lua` — animal-proximity stress; mirror of Therapy ✓
- `KH_ForageFeast.lua` (client+shared) — fresh forage food = happiness; +bonus forage rolls ✓
- `KH_EagleEyedLoot.lua` — loot vision (header notes "original mistake" — read fully if touching) ⚠
- `KH_CatsEyesLoot.lua` — sister to EagleEyed ✓
- `KH_CaffeineDependent.lua` — withdrawal stress; rewards on coffee ✓
- `KH_ColdHands.lua` — finger pain at cold ambient temperature ✓
- `KH_Tinnitus.lua` — gunfire/explosions aggravate ear-ringing ✓
- `KH_EasilyStartled.lua` — panic spike + endurance drop on loud events ✓
- `KH_Sentimental.lua` — design doc in header (read before touching) ⚠
- `KH_HighMaintenance.lua` — only feels filth penalties at HOME ✓
- `KH_Loner.lua` — stress from other-player proximity (MP-relevant) ✓
- `KH_NeedsAttention.lua` — stress when alone, relief when near others ✓
- `KH_Diet.lua` — Vegetarian/Vegan handling, food-type detection ✓

**Trait tooltips:** `shared/Tooltips/KH_Descriptions.lua` +
`client/UI/KH_TooltipOverride.lua` — adds full effect text to vanilla's
sparse 1-2 line trait descriptions.

**Status:** Stable. Trait list has grown from 5 (May 11) to 20 (current).
No obvious dead modules.

---

## 2. Thoughts system (halo text)

**What it does:** Halo-text dispatcher with per-category cooldown and
bounded queue. Three "lanes": event-flavored (time, weather, locations),
character-flavored (trait/profession ambient), and ADHD-friendly need
reminders.

**Dispatcher:** `client/Thoughts/KH_Thoughts.lua` v0.0.3 — per-category
30-min cooldown + queue depth 6 + 4.5s drain on `EveryOneSecond`. ✓

**Thought lines (data):** `shared/Thoughts/KH_ThoughtLines.lua` —
extensive line database with trait/profession variants. Categories:
time milestones, elec/water off, weather, season, moodle-rising,
animal-encounter, first-zombie events, location-aware, alone/memory,
trait-ambient, profession-ambient, filth, dirtiness, bath, toilet,
filthSleep, hygiene, game, hungry/parched/tired/exhausted/dropping/
bored/veryBored (Lane 3 categories).

**Lane 1 + 2 triggers:** `client/Thoughts/KH_ThoughtTriggers.lua` —
event hooks (EveryDays, EveryHours, EveryOneMinute, EveryTenMinutes)
for milestones, weather, season, location, animal-first-sighting,
rare-item discovery, alone/memory (gated on Bored/Unhappy moodles),
ambient trait/profession lines.

**Lane 3 (need reminders):** `client/Thoughts/KH_NeedsThoughts.lua`
v0.0.1 — reads vanilla hunger/thirst/fatigue/boredom stats per minute,
fires tier-crossing thoughts. Per-(category,key) cooldown means tiers
don't spam when oscillating. ✓

**Status:** Stable, with thoughtful three-lane architecture documented
in `project_kh_halo_text_philosophy.md` (Kierstal's memory file).

---

## 3. Needs / moodlet system (filth, dirt, bath, toilet)

**What it does:** Four ambient need systems with shared scoring core.
Trait-modified mood deltas. Threshold crossings emit thought lines.

**Shared helper:** `shared/Needs/KH_NeedsCore.lua` — `get/set/add`,
`cleanlinessModifiers` (NeatFreak ×1.75 / Slob ×0.4), `tier`,
`checkCrossing`, `applyMoodDelta`, `scaledDelta`,
`isCompoundedFilthDirt` (1.4× when both high). ✓

**Filth (room cleanliness):**
- `shared/Filth/KH_FilthScan.lua` — room-bounded blood+trash scan.
  Outdoors → score 0.
- `client/Filth/KH_FilthMoodlet.lua` — per-minute tick, tiers
  0=clean / 2=filthy / 3=squalor.
- `client/Filth/KH_SleepInFilth.lua` — on wake from filthy room,
  one-shot stress/unhappiness/bath-need bump.

**Personal dirt:**
- `shared/Dirt/KH_DirtScore.lua` — sums `HumanVisual:getDirt/getBlood`
  per body part + worn clothing dirtiness → 0-100.
- `client/Dirtiness/KH_DirtMoodlet.lua` — per-minute tick, tiers
  15=grubby / 35=dirty / 65=reeking.

**Bath need:**
- `client/Bath/KH_BathNeed.lua` — modData float, rises with time/heat/
  sprint. Outdoorsy ×0.9. Resets on `ISWashYourself:perform`.

**Toilet need + accident:**
- `client/Toilet/KH_ToiletNeed.lua` — modData float, rises with
  eat/drink (hunger/thirst delta poll) + baseline. Hard-fail accident
  at 100 with 24h cooldown.
- `client/Toilet/KH_UseToiletAction.lua` — context-menu action on
  toilet sprites (identified via `CustomName = Toilet` property).
  Reuses Rest anim from `ISRestAction`. ⚠ Animation polish unverified.

**Hygiene actions (item-driven):**
- `client/Hygiene/KH_HygieneActions.lua` — Brush teeth (Toothbrush +
  Toothpaste, tube lasts ~8 uses); Apply deodorant (also matches
  Hairspray/Hairgel by name; 4-hour bath-need mask). Public API
  `KH.Hygiene.isMasked` for other modules.

**Status:** Stable. Compounding rule and trait modifiers work cleanly.
Toilet sit animation flagged as one of the open questions.

---

## 4. Home territory

**File:** `shared/Home/KH_HomeTerritory.lua` v0.2.1

**What it does:** Singleplayer territory claim system. Two types:
**Homestead** (primary residence — pets live here, need-dampening 0.6,
therapy +50%) and **Waystation** (workshop — dampening 0.8, +20% craft
XP). Multiple of each allowed. Right-click in any building to add/
remove. Pet integration: "send pet home" via context menu (teleport-
based, because real cross-chunk pathing on IsoAnimal is unreliable).

**Migration:** v0.1.0 used a single building-ID; v0.2.1 supports
multiple territories per-building keyed table. Migration handled in
the module.

**Status:** Substantial feature, well-documented. ✓

---

## 5. Pet system

**File:** `client/Pets/KH_Pet.lua` — large module (~1650 lines)

**What it does:** Right-click adoptable wildlife → "Adopt as Pet". Per-
pet management submenu: check status, pet them, come-here, feed,
give-water, chew-toy, play-fetch, brush, put-on-collar, stay/follow
toggle, assign-to-homestead-zone, send-to-home, pick-up, disown.
Background AI tick: pet eats/drinks from nearby bowls; tracks grief
decay (14-day cooldown after pet death).

**Adoptable species** (`KH_ADOPTABLE_WILD`): mouse, rat, raccoon,
rabbit (all stages), wild turkey, deer fawn. **Livestock is not
adoptable by design** — explicit decision per Kierstal.

**Hooks:** Both `OnFillWorldObjectContextMenu` (legacy path) AND
`OnClickedAnimalForContext` (B42 vanilla animal-click event).

**Debug spawn:** `client/Pets/KH_DebugSpawnPet.lua` — gated on
`KH.DEBUG` global. Picks one random from `{raccoonsow, rat, rabdoe}`
and spawns adjacent on game start. Uses verified `IsoAnimal.new` +
`addToWorld` pattern.

**Status:** ✓ Stable. The May 11 grief-decay code at the tail had a
truncation; restored 2026-05-27.

---

## 6. Tailoring / clothing repair / ripping

**File:** `client/Tailoring/KH_RepairClothingXP.lua` — wraps
`ISRepairClothing:complete` (+3 XP bonus, total 5) and
`ISRemovePatch:complete` (+1, total 3).

**Recipe XP overrides:** `42.0/media/scripts/recipes/KH_rip_xp.txt` —
adds Tailoring XP to RipClothing (3), RipDenimClothing (5), RipSheets
(3), CutTarp (2). Were 0 in vanilla.

**Recipe XP boost (early tier):**
`42.0/media/scripts/recipes/KH_tailoring_xp_boost.txt` — SewShirt 13→20,
SewTrousers 20→25, MakeMattress 13→20, SewClothSatchel 13→20,
SewFootwrap/Handwrap/Sack/ImprovisedBandeau/RagBandana 8→12,
WeaveTwineShoes 9→15.

**Rip-clothing tag fix:** `42.0/media/scripts/items/KH_rip_clothing_tags.txt`
— **66 items now** (was 51 in original pass). Full vanilla bodies +
`base:ripclothingcotton` appended. Includes original 51 (socks,
underwear bottoms, gloves, bandanas, hockey shorts, two promo
t-shirts with vanilla typos fixed) PLUS 15 added later: 10 Bra_*
variants (Straps + Strapless, with Hide variants flagged
ripclothingleather). ⚠ Spot-check needed on the post-pass additions —
see Known Open Questions.

**Empty stub:** `42.0/media/scripts/items/KH_FabricTypeOverrides.txt` —
intentionally empty. Header documents migration to `KH_rip_clothing_tags.txt`
to preserve the "B42 partial overrides break items" lesson.

**Rip extends to non-clothing:** `shared/Definitions/KH_RipOverrides.lua`
— extends vanilla `canRipItem` path-2 to BathTowel, BathTowelWet,
DishCloth, DishTowel, Pillow, PillowCase, Sheet. ✓

**Fanny pack capacity buff:**
`42.0/media/scripts/items/KH_FannyPackOverrides.txt` — 6 fanny pack
variants get Capacity 1→5. Full vanilla bodies (the pattern). ✓

---

## 7. Cooking / food

**Uncraftable cooking recipes:**
`42.0/media/scripts/recipes/KH_uncraftable_recipes.txt` — **34 new
craftRecipes** turning ingredients into vanilla foods that previously
had no crafting path: canned bolognese/chili/peaches/sardines/etc.,
cheese, dried milk powder, cured pork/ham, salami, baloney, hotdogs,
rendered lard, margarine, gravy/pancake mix, marinara, rice vinegar,
yeast culture, cocoa powder, mac and cheese, tortillas, cereal, beef
jerky.

**Junk-item recipes:** `42.0/media/scripts/recipes/KH_junk_item_uses.txt`
— Perfume/Cologne → AlcoholBandage (alcohol disinfectant).

**Food spoil retuning:** `42.0/media/scripts/items/KH_FoodSpoilOverrides.txt`
— full vanilla bodies of items with overly-short DaysFresh /
DaysTotallyRotten (canned veg, apples, cabbage, bacon family, boiled
eggs). Pattern: real-world spoilage timelines. ✓

**Cold storage logic:** `client/Items/KH_ColdStorage.lua` — preservation
bonus when container's tile has no electricity AND ambient temp is
cold enough. ✓

**Freshness UI:** `client/UI/KH_FreshnessTooltip.lua` — color-coded
freshness line under the vanilla tooltip.

---

## 8. UI

**Character info tabs / panels:**
- `client/UI/KH_HomesteadTab.lua` v0.0.2 — new "Homestead" tab in
  vanilla `ISCharacterInfoWindow`. Bars for bath, toilet, dirt, room
  filth. Conditional Nutrition section for Nutritionist trait. ⚠ Tab
  accessor patches via wrap; should be safe.
- `client/UI/KH_NutritionPanel.lua` — HUD overlay nutrition breakdown
  (Nutritionist-trait gate). Coexists with the Homestead tab.

**Craft UI:**
- `client/UI/KH_RecipeRowColors.lua` — 3-pixel colored stripe on
  recipe rows based on `InHandCraft` / `AnySurfaceCraft` / workstation
  tags. ⚠ `recipe:getTags()` accessor is best-guess pcall-wrapped.

**Tooltips:**
- `client/UI/KH_TooltipOverride.lua` — rewrites trait/profession
  tooltips from `KH.Descriptions`.
- `client/UI/KH_FreshnessTooltip.lua` — food freshness color bar.

**Preset / new-game:**
- `client/UI/KH_RegisterPreset.lua` — registers the Kierpocalyptic
  Rising sandbox preset on the New Game screen.

**Starter kits:**
- `client/Player/KH_StarterKits.lua` — profession-based starter gear
  granted on new game. ✓

---

## 9. World-object actions (right-click on world)

- **Crowbar pry:** `client/Doors/KH_PryAction.lua` — locked doors +
  closed windows. Carpentry/Strength scale. ✓
- **Trash pickup:** `client/Items/KH_TrashPickup.lua` v0.0.6 — matches
  `trash_%d` substring (covers both `d_trash_1_*` decals and
  `trash_01_*` floor-rug moveables). Multi-removal-path
  (RemoveTileObject, transmitRemoveItemFromSquare, removeFromSquare,
  removeFromWorld). DEBUG=true currently — log lists sprite names on
  right-click for diagnostics.
- **Tree branches:** `client/Trees/KH_BreakBranches.lua` — "Break
  Branches" action on IsoTrees.
- **Throw corpse out window:** `client/Corpses/KH_ThrowCorpseWindow.lua`
  — same-floor + faked multi-floor variant. Needs in-game verification.
- **Use toilet:** `client/Toilet/KH_UseToiletAction.lua` (see § 3).
- **Vending machines:**
  - `client/Containers/KH_VendingMoney.lua` v0.0.2 — money-gate on
    `ISInventoryTransferAction`. Bypassed when `KH_forcedOpen=true`
    in container modData.
  - `client/Containers/KH_VendingForceOpen.lua` — context-menu action
    with crowbar or blunt weapon. Marks container forced. Plays bash
    sound + world-noise (radius 25 / volume 18). 30% break-random-item
    chance.

---

## 10. Zombies

- **Trip while running:** `client/Zombies/KH_ZombieTrip.lua` —
  per-minute scan, per-zombie roll (default 2%), rain multiplier 2.5×.
  Uses `:knockDown(false)` vanilla method. ⚠ Sandbox knobs not
  registered yet; defaults inline.
- **Kill-zombies toggle (debug):** `client/Player/KH_KillZombiesToggle.lua`
  — right-click self → toggle.

---

## 11. Lighting / climate

- **Colored bulbs:** `server/Items/KH_ColorfulBulbs.lua` — makes
  vanilla colored bulbs actually emit light. ✓
- **Climate colors:** `server/Climate/KH_ClimateColors.lua` — pushes
  vanilla day/dawn/dusk EXTERIOR color cells more dramatic. Defers to
  HereGoesTheSun mod if loaded. ✓

---

## 12. Boredom / play

- `client/Boredom/KH_PlayGame.lua` — inventory right-click on chess /
  checkers / backgammon / dice / dart → "Play a game" action. Boredom
  -20, unhappiness -8. Linter switched the implementation to
  `stats:get(CharacterStat.BOREDOM)` / `CharacterStat.UNHAPPINESS`.

---

## 13. Books / radio / media XP

- `client/Books/KH_BookPerPageXP.lua` — per-page XP. Header notes
  `ISReadABook.checkMultiplier` interaction.
- `client/Media/KH_MediaXPCap.lua` — caps radio XP per session,
  preventing infinite-radio grinds.

---

## 14. Loot

- `client/Loot/KH_LootBoost.lua` — pushes loot multipliers up at game
  start. Lore: Rising-on-day-1 means stuff is still around.

---

## 15. Farming / traps / animals

- `server/Farming/KH_BoltToSeed.lua` — when nbOfGrow exceeds fullGrown,
  plant goes to seed instead of rotting. ✓
- `42.0/media/scripts/recipes/KH_seeds_from_bulbs.txt` — seed
  extraction from Potato/SweetPotato/Onion/Garlic and pod seeds from
  Corn/Greenpeas/Soybeans.
- `server/Traps/KH_TrapNoDistance.lua` — fixes vanilla
  `STrapGlobalObject:checkForAnimal` early-return bug.

---

## 16. Money / wallet

- `server/Items/KH_WalletAccept.lua` — patches vanilla `AcceptItemFunction.Wallet`.

---

## 17. Mod compatibility

**Detection:** `shared/Compat/KH_ModCompat.lua` v0.1.0 — scans loaded
mods at file-load time, populates `KH.compat` with flags. Exposes
`KH.shouldDefer(flag, "KHCompat.OptName")` so call sites check once.

**Sandbox toggles:** `42.0/media/sandbox-options.txt` — page `KH_Compat`.
Default for every defer toggle is **TRUE** (compatibility-first per
Kierstal's preference, per `kh-compatibility-first-not-reinvent` memory).

Detected mods:
- Lifestyle: Hobbies → defer Hygiene + Toilet
- Sapph's Cooking → defer Recipes + BeefJerky
- AnimalEssentials + Pawject Meowboid → `UsePetsOnAE` master switch,
  `DeferToMeowboid_Cats`
- Here Goes The Sun → defer Climate
- FOOL Containers → defer Containers

---

## 18. Core / utility

- `client/Core/KH_Init.lua` — boot announcer. `KH.DEBUG = true`
  currently. Lists loaded modules in console.
- `shared/Core/KH_Util.lua` — `KH.hasTrait` wrapper + cached
  CharacterTrait registry.
- `client/UI/KH_RegisterPreset.lua` — preset registration on New
  Game screen.

---

## 19. Debug / diagnostic (TEMPORARY)

- `client/Debug/KH_ItemSpawnDiag.lua` — header explicitly says
  "TEMPORARY DIAGNOSTIC. Hunts the item that causes the recurring
  [something]." ⊗ Should be removed when the bug is found. Currently
  still in the mod.

---

## Known Open Questions (carried forward + new)

From the previous reconciliation:

1. **B42 partial item overrides — empirically a known issue.** Now
   documented in three files (`KH_FabricTypeOverrides.txt` stub,
   `KH_FoodSpoilOverrides.txt` and `KH_FannyPackOverrides.txt`
   headers). Each one says "use full vanilla bodies because partial
   overrides silently break items." That's promoted from uncertainty
   to documented pattern.

2. **`KH_UseToiletAction` sit animation** — falls back to plain Rest
   anim if `furnitureHasSittingData(toilet)` is false. Polish unverified.

3. **`KH_RecipeRowColors` tag accessor** — `recipe:getTags()` is
   best-guess, pcall-wrapped. Stripes silently disappear if wrong.

4. **`KH_ZombieTrip` sandbox options** — wired to read `KH_ZombieTrip`
   and `KH_ZombieTripRainMultiplier` but NOT registered in
   `sandbox-options.txt`. Defaults are inline (2%, 2.5×). To make
   player-tunable, register the options.

5. **`KH_ThrowCorpseWindow` multi-floor faked-fall** — `square:addCorpse`
   signature is best-guess. Pcall-wrapped no-op on failure.

6. **Halo queue 4.5s drain** — picked from community lore that halo
   display is ~4s. Never measured.

7. **NeatFreak/Slob multipliers** — 1.75/0.4/0.0 picked from feel,
   not playtested.

8. **Eat/drink approximation in `KH_ToiletNeed`** — polls hunger/
   thirst delta because no `OnEat` event. Continuous-meal items may
   bump toilet need multiple times.

New from this reconciliation pass:

9. **KH_rip_clothing_tags.txt grew 51→66.** The 15 new entries are
   the Bra_Strapless_* and Bra_Straps_* variants (10 of them, including
   the Hide sub-variants which use `ripclothingleather` not cotton).
   I didn't write these — they were added later by another instance
   or by Kierstal. Spot-check: are the Hide variants correctly tagged
   `ripclothingleather` vs `ripclothingcotton`? (Looked correct at a
   glance but verify in-game.)

10. **`KH_ItemSpawnDiag.lua` is marked TEMPORARY.** Still in the mod.
    Should be removed when the underlying bug is identified — header
    will tell you which bug if you read it.

11. **`KH_EagleEyedLoot.lua` header explicitly says "original mistake
    was targeting the EagleEyed trait when Kierstal meant ...".** Read
    the full header before touching this module.

12. **`KH_Sentimental.lua` has a "Design:" header section.** Read it
    before changing behavior — module's intent is captured there.

13. **Two rip-clothing approaches coexist:**
    `KH_rip_clothing_tags.txt` (item Tags) + `KH_RipOverrides.lua` (Lua
    `canRipItem` extension for non-Clothing items). They cover different
    item-type paths and don't conflict, but anyone modifying one should
    know about the other.

14. **`KH_VendingForceOpen` world-sound volume** — 18, picked from
    vibes. Could be tuned.

---

## Reversibility Map v2

### Drop-in / drop-out cleanly (no vanilla files touched)

Every file in its own purpose-folder. Delete the file or the entire
folder to revert the feature.

- All trait behavior modules (`client/Traits/KH_*.lua`)
- All needs / moodlet / hygiene modules (`client/Bath/`, `client/Toilet/`,
  `client/Filth/`, `client/Dirtiness/`, `client/Hygiene/`,
  `shared/Needs/`, `shared/Filth/`, `shared/Dirt/`)
- `client/Pets/` (Pet system + Debug spawn)
- `client/Boredom/KH_PlayGame.lua`
- `client/Containers/KH_VendingMoney.lua` + `KH_VendingForceOpen.lua`
- `client/Corpses/KH_ThrowCorpseWindow.lua`
- `client/Doors/KH_PryAction.lua`
- `client/Zombies/KH_ZombieTrip.lua`
- `client/Trees/KH_BreakBranches.lua`
- `client/Tailoring/KH_RepairClothingXP.lua`
- `client/UI/KH_HomesteadTab.lua` (wrap pattern — vanilla untouched)
- `client/UI/KH_RecipeRowColors.lua` (wrap pattern)
- `client/UI/KH_FreshnessTooltip.lua`
- `client/UI/KH_TooltipOverride.lua`
- `client/UI/KH_NutritionPanel.lua`
- `client/UI/KH_RegisterPreset.lua`
- `client/Items/KH_ColdStorage.lua`
- `client/Items/KH_TrashPickup.lua`
- `client/Books/KH_BookPerPageXP.lua`
- `client/Media/KH_MediaXPCap.lua`
- `client/Loot/KH_LootBoost.lua`
- `client/Player/KH_KillZombiesToggle.lua`
- `client/Player/KH_StarterKits.lua`
- `client/Debug/KH_ItemSpawnDiag.lua` (TEMPORARY)
- `server/Climate/KH_ClimateColors.lua`
- `server/Farming/KH_BoltToSeed.lua`
- `server/Traps/KH_TrapNoDistance.lua`
- `server/Items/KH_ColorfulBulbs.lua`
- `server/Items/KH_WalletAccept.lua`
- `shared/Home/KH_HomeTerritory.lua`
- `shared/Compat/KH_ModCompat.lua`
- `shared/Foraging/KH_ForageFeast.lua`
- `shared/Tooltips/KH_Descriptions.lua`
- `shared/Definitions/KH_RipOverrides.lua`
- `client/Thoughts/KH_NeedsThoughts.lua`
- `42.0/media/scripts/recipes/KH_rip_xp.txt`
- `42.0/media/scripts/recipes/KH_tailoring_xp_boost.txt`
- `42.0/media/scripts/recipes/KH_junk_item_uses.txt`
- `42.0/media/scripts/recipes/KH_uncraftable_recipes.txt`
- `42.0/media/scripts/recipes/KH_seeds_from_bulbs.txt`
- `42.0/media/sandbox-options.txt`

### Overwrites vanilla-shaped declarations (deleting restores vanilla)

- `42.0/media/scripts/items/KH_rip_clothing_tags.txt` — 66 full item
  bodies. Delete → vanilla state for those items.
- `42.0/media/scripts/items/KH_FoodSpoilOverrides.txt` — full bodies
  with retuned spoil timers. Delete → vanilla spoil rates.
- `42.0/media/scripts/items/KH_FannyPackOverrides.txt` — fanny pack
  Capacity 1→5. Delete → 1 again.

### Internal-extending (deleting breaks downstream KH callers)

- `shared/Core/KH_Util.lua` — `KH.hasTrait` used everywhere.
- `shared/Needs/KH_NeedsCore.lua` — used by every moodlet/need module.
- `shared/Thoughts/KH_ThoughtLines.lua` — data table used by dispatcher.
- `client/Thoughts/KH_Thoughts.lua` — dispatcher. Many callers.
- `client/Thoughts/KH_ThoughtTriggers.lua` — many event hooks.
- `shared/Traits/KH_TraitRegistry.lua` — central trait registration.
  Removing kills every KH trait behavior.

### Multi-instance edits (touch with care)

These were extended over multiple sessions. Deleting an entry rather
than the whole file is the safer pattern:

- `shared/Traits/KH_TraitRegistry.lua` — TRAITS table (20 entries)
- `shared/Thoughts/KH_ThoughtLines.lua` — many categories
- `42.0/media/lua/shared/Translate/EN/UI.json` — accumulated strings

### Not safe to revert via simple delete

- `client/Core/KH_Init.lua` — boot announcer. Used by other KH modules
  to verify load. Delete only if removing the mod entirely.

---

## What surprised me during this audit

(Things I didn't have in my mental model from the previous log.)

- **34 cooking recipes.** I'd documented zero cooking recipes; the file
  is `KH_uncraftable_recipes.txt` and adds CannedBolognese, Cheese,
  Cured Pork, Salami, Margarine, etc. Substantial cooking expansion.
- **`KH_HomeTerritory` is a fully realized claim system** with
  homestead vs. waystation distinction and pet teleport-home.
- **`KH_ModCompat` exists** with a compat-first design and sandbox
  toggles for 5 third-party mods.
- **`KH_StarterKits` exists** with profession-based starter gear.
- **Climate color tweaks + freshness tooltip + cold storage** — a
  whole environmental-realism cluster I missed.
- **20 traits, not 5.** The trait system tripled.
- **`KH_FoodSpoilOverrides` and `KH_FannyPackOverrides`** both
  explicitly cite the "B42 partial overrides break items" lesson —
  that lesson is now a documented pattern in three files.

---

## What I flagged as potentially broken / dead / contradictory

- ⊗ `client/Debug/KH_ItemSpawnDiag.lua` — header says TEMPORARY. Still
  here. Remove when the bug it's hunting is found.
- ⊗ `42.0/media/scripts/items/KH_FabricTypeOverrides.txt` — explicitly
  empty stub. Intentional, but technically dead code. Could be deleted
  entirely if the migration note is moved into the implementation log
  or another notes file.
- ⚠ `client/Items/KH_TrashPickup.lua` has `DEBUG = true` currently —
  prints sprite names on every right-click. Turn off when stable.
- ⚠ The `KH_DebugSpawnPet.lua` header still says "Flip DEBUG_ENABLED
  to false to disable" but the gating logic now uses `KH.DEBUG`
  (global). Header is mildly stale.
- ⚠ The `KH_Pet.lua` header says 'Right-click any pickupable animal
  -> "Take as Pet"' but the actual menu label is "Adopt as Pet"
  (verified via grep). Header doc-drift.

Nothing in the inventory looked outright broken or contradictory at
the system level. All 49 KH lua files parse with Lua 5.5 (one
spurious "KH_ForageFeast line 52" lupa false positive on a 38-line
file — runs fine in PZ Lua 5.1).
`canRipItem` extension for non-Clothing items). They cover different
    item-type paths and don't conflict, but anyone modifying one should
    know about the other.

14. **`KH_VendingForceOpen` world-sound volume** — 18, picked from
    vibes. Could be tuned.

---

## Reversibility Map v2

### Drop-in / drop-out cleanly (no vanilla files touched)

Every file in its own purpose-folder. Delete the file or folder to
revert. Lists:

- All trait behavior modules (`client/Traits/KH_*.lua`)
- All needs/moodlet/hygiene modules (`client/Bath/`, `client/Toilet/`,
  `client/Filth/`, `client/Dirtiness/`, `client/Hygiene/`,
  `shared/Needs/`, `shared/Filth/`, `shared/Dirt/`)
- `client/Pets/` (Pet system + Debug spawn)
- `client/Boredom/`, `client/Containers/`, `client/Corpses/`,
  `client/Doors/`, `client/Zombies/`, `client/Trees/`,
  `client/Tailoring/`, `client/Debug/`
- `client/UI/KH_HomesteadTab.lua` and other UI files (wrap pattern,
  vanilla untouched)
- `client/Items/KH_ColdStorage.lua` and `KH_TrashPickup.lua`
- `client/Books/`, `client/Media/`, `client/Loot/`, `client/Player/`
- `server/Climate/`, `server/Farming/`, `server/Traps/`, `server/Items/`
- `shared/Home/`, `shared/Compat/`, `shared/Foraging/`,
  `shared/Tooltips/`, `shared/Definitions/`
- `client/Thoughts/KH_NeedsThoughts.lua`
- All recipe scripts under `42.0/media/scripts/recipes/`
- `42.0/media/sandbox-options.txt`

### Overwrites vanilla-shaped declarations (deleting restores vanilla)

- `42.0/media/scripts/items/KH_rip_clothing_tags.txt` — 66 full item
  bodies. Delete → vanilla state for those items (no rip tag).
- `42.0/media/scripts/items/KH_FoodSpoilOverrides.txt` — full bodies
  with retuned spoil timers. Delete → vanilla spoil rates.
- `42.0/media/scripts/items/KH_FannyPackOverrides.txt` — fanny pack
  Capacity 1→5. Delete → vanilla Capacity 1.

### Internal-extending (deleting breaks downstream KH callers)

- `shared/Core/KH_Util.lua` — `KH.hasTrait` used everywhere.
- `shared/Needs/KH_NeedsCore.lua` — used by every moodlet/need module.
- `shared/Thoughts/KH_ThoughtLines.lua` — data table used by dispatcher.
- `client/Thoughts/KH_Thoughts.lua` — dispatcher. Many callers.
- `client/Thoughts/KH_ThoughtTriggers.lua` — many event hooks.
- `shared/Traits/KH_TraitRegistry.lua` — central trait registration.
  Removing kills every KH trait behavior.

### Multi-instance edits (touch with care)

These were extended over multiple sessions. Removing an entry rather
than the whole file is safer:

- `shared/Traits/KH_TraitRegistry.lua` — 20-entry TRAITS table
- `shared/Thoughts/KH_ThoughtLines.lua` — many categories
- `42.0/media/lua/shared/Translate/EN/UI.json` — accumulated strings
rides.txt` — fanny pack
  Capacity 1→5. Delete → vanilla Capacity 1.

### Internal-extending (deleting breaks downstream KH callers)

- `shared/Core/KH_Util.lua` — `KH.hasTrait` used everywhere.
- `shared/Needs/KH_NeedsCore.lua` — used by every moodlet/need module.
- `shared/Thoughts/KH_ThoughtLines.lua` — data table used by dispatcher.
- `client/Thoughts/KH_Thoughts.lua` — dispatcher. Many callers.
- `client/Thoughts/KH_ThoughtTriggers.lua` — many event hooks.
- `shared/Traits/KH_TraitRegistry.lua` — central trait registration.
  Removing kills every KH trait behavior.

### Multi-instance edits (touch with care)

These were extended over multiple sessions. Removing an entry rather
than the whole file is the safer pattern:

- `shared/Traits/KH_TraitRegistry.lua` — 20-entry TRAITS table
- `shared/Thoughts/KH_ThoughtLines.lua` — many categories
- `42.0/media/lua/shared/Translate/EN/UI.json` — accumulated strings
t safe to revert via simple delete

- `client/Core/KH_Init.lua` — boot announcer + `KH.DEBUG` flag.
  Delete only if removing the mod entirely.

---

## What surprised me during this reconciliation

(Things I didn't have in my mental model from the previous log.)

- **34 cooking recipes** in `KH_uncraftable_recipes.txt`. I'd documented
  zero — turns out there's a substantial cooking expansion.
- **`KH_HomeTerritory` is a fully realized claim system** with
  homestead vs. waystation distinction and pet teleport-home.
- **`KH_ModCompat` exists** with compatibility-first design and
  sandbox toggles for 5 third-party mods (Lifestyle Hobbies, Sapph
  Cooking, AnimalEssentials + Meowboid, HereGoesTheSun, FOOL
  Containers).
- **`KH_StarterKits` exists** with profession-based starter gear.
- **`KH_ClimateColors` + `KH_FreshnessTooltip` + `KH_ColdStorage`** —
  a whole environmental-realism cluster.
- **20 traits, not 5.** Trait system quadrupled.
- **`KH_FoodSpoilOverrides` and `KH_FannyPackOverrides`** both
  explicitly cite the "B42 partial overrides break items" lesson. The
  workaround I used (full vanilla bodies) is now a documented pattern
  in three files.
- **Two complementary rip-clothing approaches** — `KH_rip_clothing_tags.txt`
  (item tags, path 1 of vanilla `canRipItem`) plus `KH_RipOverrides.lua`
  (Lua hook into path 2 for non-Clothing items like towels/sheets).

---

## What I flagged as potentially broken / dead / contradictory

- ⊗ `client/Debug/KH_ItemSpawnDiag.lua` — header says TEMPORARY.
  Should be removed when the bug it's hunting is found.
- ⊗ `42.0/media/scripts/items/KH_FabricTypeOverrides.txt` — intentionally
  empty stub. Migration note in header. Could be deleted if the
  migration note is preserved elsewhere.
- ⚠ `client/Items/KH_TrashPickup.lua` has `DEBUG = true` — prints
  sprite names on every right-click. Turn off when stable.
- ⚠ `KH_DebugSpawnPet.lua` header still says "Flip DEBUG_ENABLED to
  false to disable" but gating logic now uses `KH.DEBUG` (global).
  Header is mildly stale.
- ⚠ `KH_Pet.lua` header says 'Right-click any pickupable animal ->
  "Take as Pet"' but the actual menu label is "Adopt as Pet". Header
  doc-drift.

Nothing in the inventory looked outright broken at the system level.

---

## Addendum — 2026-05-27 evening pass

Added two features and two documents.

### 20. Bandits + Bandits Week One taming (NEW cluster)

**Files:**
- `client/Compat/KH_BanditsTame.lua` v0.0.1 — NEW. Runs at
  `OnGameStart`. If Bandits / Week One detected via `KH.compat` AND
  the matching sandbox toggle is ON (default TRUE), writes KH-tamed
  values into the live sandbox options via two-channel write
  (SandboxOption + SandboxVars table mirror).
- `42.0/media/sandbox-options.txt` — appended `KHCompat.TameBandits`
  and `KHCompat.TameBanditsWeekOne` toggles. Both default true.
- `42.0/media/lua/shared/Translate/EN/UI.json` — added strings:
  `Sandbox_KH_Compat`, `KHCompat_TameBandits[_tooltip]`,
  `KHCompat_TameBanditsWeekOne[_tooltip]`.

**Bandits values changed** (full table in `notes/BANDITS_TAMING.md`):
- SpawnMultiplier 1.00 → **0.30** (-70% spawns)
- SizeMultiplier 1.00 → **0.40**
- 9 destructive behaviors disabled (door / window / barricade /
  thumpable destruction, vehicle / crop sabotage, theft, generator
  cutoff, roadblocks)
- OverallAccuracy 3 → 2 (5-tier enum, lower = worse)

**Week One values changed**:
- 4 population multipliers cut to 30–50%
- Pistol-spawn chances halved or thirded
- VehiclesMax 4 → 2
- 5 service cooldowns lengthened ~4×
- 6 disaster events disabled (Final Solution, Boeing, Strafe,
  Bombing, Gas, Arson)

**Status:** ✓ Ships ready-to-test. Three guesses called out in
`BANDITS_TAMING.md`: accuracy direction (assumed lower=worse), cooldown
4× factor (might be too tame), and full-event-off (might remove
world-pulse). Easy dial-back paths documented.

### New notes

- `notes/WORKSHOP_INVENTORY.md` — full inventory of 14 subscribed
  Steam Workshop mods, every one's mod.info id, and a style profile
  inferred from the mix. Five clusters: Sims crossover (3), Animal
  expansion (3), Survival realism (3), Atmosphere (1), NPCs (2),
  plus 2 pure-utility.
- `notes/BANDITS_TAMING.md` — every Bandits / Week One value change
  with vanilla default, KH value, and reasoning. Includes "guessing
  vs knowing" section flagging the three uncertainties.

### Style profile takeaways (from workshop inventory)

Subscribed mods describe Kierstal's vision as: **domestic over combat,
soft aesthetic over hardcore, animals as companions, texture over
difficulty, NPCs as worldbuilding (not gameplay challenge),
compatibility-first integration**. Every detected mod that overlaps
with KH features has a defer-toggle defaulted TRUE — pattern
continues with this Bandits taming pair.

### Open questions added

15. **Bandits OverallAccuracy direction** — enum 1-5 default 3.
    Assumed 2 = worse (less accurate). If she sees bandits become
    snipers, flip to 4.
16. **Service cooldown 4× factor** could be too tame. Try 2× if she
    wants more police/medic encounters.
17. **All 6 disaster events disabled** might remove world-pulse she'd
    enjoy. Recommend turning EventArson and EventStrafe back on first
    if the world feels too quiet.

### File touches this pass

- NEW: `42.0/media/lua/client/Compat/KH_BanditsTame.lua`
- MODIFY: `42.0/media/sandbox-options.txt` (appended 2 toggles)
- MODIFY: `42.0/media/lua/shared/Translate/EN/UI.json` (4 new strings)
- NEW: `notes/WORKSHOP_INVENTORY.md`
- NEW: `notes/BANDITS_TAMING.md`
- MODIFY: this log
