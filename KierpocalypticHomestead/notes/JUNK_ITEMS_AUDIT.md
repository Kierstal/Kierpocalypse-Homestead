# Junk Items Audit — B42 Vanilla

**Generated:** 2026-05-11 from PZ B42 install at
`Steam/steamapps/common/ProjectZomboid/media/`.

**Definition:** An item qualifies as "junk" if it spawns in vanilla loot
tables but has no gameplay-functional use. It is not a recipe input, not
named in any functional Lua action (excluding loot/foraging/translation
tables), has no `BodyLocation`/`WorldObjectSprite`/functional tag,
and lacks every functional-knob field (`OnUse`, `CustomContextMenu`,
`UseWhileEquipped`, `MechanicsItem`, etc.) listed in the audit script.

**Methodology** (lives in `outputs/junk_audit.py`):

1. Parse all `media/scripts/generated/items/*.txt` → 5088 items.
2. Parse all `media/scripts/generated/recipes/*.txt` AND
   `media/scripts/generated/entities/**/*.txt` for `inputs { ... }` blocks
   → 1812 unique item-name inputs + 148 tag inputs.
3. Resolve quoted item strings in `media/lua/server/Items/Distribution*.lua`
   + `Procedural*` + `Suburbs*` to known item IDs → 3210 lootable items.
4. Grep all `.lua` files for `"Module.ItemName"` quoted strings,
   **excluding** loot/foraging/translation paths
   (`/RandomizedWorldContent`, `/Foraging/Categories`, `/Translate`, and
   any `Distribution*` / `Procedural*` / `Suburbs*` / `ItemPicker*` /
   `LootLog*` / `VehicleDistributions*` basenames).
5. Cross-reference. Verified by sanity check — Nails, Hammer, Saucepan,
   Twine, Bleach, Soap2, Screwdriver, Wire, SheetMetal, DeerHide, CowHide,
   Wallpaper variants, and movable furniture all correctly **filtered
   out** as functional.

**Result: 47 strict-junk candidates** plus honorable mentions.

A few false-positive risks remain — flagged inline. The audit script
errs on the side of inclusion when functional usage is ambiguous (e.g.
items with `FluidContainer` components but no recipes/Lua refs); see
notes below.

---

## Hygiene & personal care (4)

Highest reuse potential per the cologne→disinfectant precedent.

| ID | Name | Weight | Top spawn tables | Suggested use |
|---|---|---|---|---|
| `Base.Perfume` | Perfume | 0.1 | Procedural, BagsAndContainers, base Distributions | Wound disinfectant. Scent-mask from zombies (lower sound-detection while equipped, like the cologne mod precedent). 0.1L FluidContainer is intentional scaffolding only. |
| `Base.Cologne` | Cologne | 0.2 | Procedural, base Distributions, BagsAndContainers | Same as perfume — disinfectant OR scent-mask. Twin item. |
| `Base.Toothpaste` | Toothpaste | 0.3 | Procedural, BagsAndContainers, BinJunk | Wound-care foam (1-time disinfectant per tube), or boredom-relief flavor item ("brushed teeth, felt civilized"). |
| `Base.Comb` | Comb | 0.2 | Procedural, base Distributions, BagsAndContainers | Hair-grooming action → small unhappiness reduction. Pairs naturally with KH's filth/dirt system. |

**Honorable mentions** (filtered out but functionally trivial — still
candidates for repurposing if you want):

- **`Base.Toothbrush`** — *researchable into a Shiv weapon*. That's the
  only vanilla use. Could overlay a hygiene action on top (brushing teeth
  for boredom/unhappiness relief).
- **`Base.Razor`** — *tagged `base:smeltableironsmall;base:hasmetal`* (one
  iron-bar worth at a forge). Otherwise inert. Could become a shaving
  action with mood effects.
- **`Base.Hairgel`** — *tagged `base:dohairdo`*. Already functional for
  hair-style menu in B42.
- **`Base.Lipstick` / `Base.MakeupEyeshadow`** — have `MakeUpType`, fully
  functional makeup in B42.

---

## Toys, games & sports (16)

Classic boredom/morale potential.

### Board games
| ID | Weight | Spawn |
|---|---|---|
| `Base.BackgammonBoard` | 1.0 | Procedural, BinJunk, ClosetJunk |
| `Base.CheckerBoard` | 1.0 | Procedural, BinJunk, ClosetJunk |
| `Base.ChessBlack` | 0.1 | Procedural, base Distributions, BinJunk |
| `Base.ChessWhite` | 0.1 | Procedural, base Distributions, BinJunk |
| `Base.GamePieceBlack` | 0.1 | Procedural, BinJunk, ClosetJunk |
| `Base.GamePieceRed` | 0.1 | Procedural, base Distributions, BinJunk |
| `Base.GamePieceWhite` | 0.1 | Procedural, base Distributions, BinJunk |

**Suggested use:** group these into "play board game" timed action when
inventoried together (or near a table). Boredom -30, unhappiness -10,
small stress relief. Solo play with -50% effect (sad). Pair with a
"second player" if the homestead supports companions.

### Sport balls
| ID | Weight | Spawn |
|---|---|---|
| `Base.Baseball` | 0.5 | Procedural, base Distributions, BinJunk |
| `Base.Basketball` | 1.0 | Procedural, BinJunk, ClosetJunk |
| `Base.Birdie` | 0.1 (shuttlecock) | Procedural, BinJunk, ClosetJunk |
| `Base.Dart` | 0.1 | Procedural, BinJunk, ClosetJunk |
| `Base.Football` | 1.0 | Procedural, BinJunk, ClosetJunk |
| `Base.GolfBall` | 0.1 | Procedural, base Distributions, BinJunk |
| `Base.GolfTee` | 0.05 | Procedural, base Distributions, BinJunk |
| `Base.PoolBall` | 0.8 | Procedural, BagsAndContainers, BinJunk |
| `Base.SoccerBall` | 1.0 | Procedural, BinJunk, ClosetJunk |
| `Base.TennisBall` | 0.3 | Procedural, base Distributions, BinJunk |

**Suggested use:** "Practice X" timed action — fitness XP at low rate, or
boredom relief. Throwable variant (with companion/pet → fetch). PoolBall
is *almost* weapon-coded in physics; could become a melee Throwable.

---

## Office & desk (5)

Lockpick / writing / utility potential.

| ID | Weight | Suggested use |
|---|---|---|
| `Base.HolePuncher` | 0.3 | Punch holes in cardboard for binding/journaling, or a clumsy improvised weapon (metal — `MetalValue` is on it but no smelt tag). Counterintuitive: in real life punches are heavy; weight 0.3 is light. |
| `Base.Clipboard` | 1.0 | Carryable writing surface (read/write extension). Could enable mobile note-taking. |
| `Base.Book_Prop` / `Base.BookFancy_Prop` | 1.0 ea | *Decorative books with no readable content.* Useful as crafting input (paper source — disassemble for blank pages) or insulation/tinder. |
| `Base.Frame` | 1.0 | Picture frame, empty. Crafting input for art-display action, or disassemble for wood + glass. |

---

## Kitchen, bar & water containers (8)

Cooking, drinking, ambient use.

| ID | Weight | Notes / Suggested use |
|---|---|---|
| `Base.BastingBrush` | 0.3 | Cooking accessory — could grant cooking XP bonus when used in oven recipes. |
| `Base.CocktailUmbrella` | 0.1 | Pure novelty. Decorate any drink for happiness bonus; or fold into a "fancy cocktail" recipe. |
| `Base.Plate` | 1.0 | Surface for "plated meal" (eating-from-plate happiness bonus over eating from container). Surprisingly absent from cooking. |
| `Base.Bitters` | 1.0 | Cocktail bitters bottle. Logical cocktail ingredient — surprising vanilla doesn't use it. |
| `Base.WineBox` | 0.2 | **Caveat:** has `FluidContainer` with wine fluid — may already be drinkable in current B42; verify before repurposing. |
| `Base.Straw2` | 0.1 | Drinking straw variant. Could let you drink from awkward containers (water barrel without lifting it). |
| `Base.FountainCup` / `Base.PlasticCup` | 0.1 ea | **Caveat:** these ARE small water containers (`FluidContainer` 0.3L Capacity). Already functional as drinking cups — likely false positives. Verify with `getFluidContainer()` in-game before assuming junk. |

---

## Workshop & utility (6)

Crafting and improvised-tool potential.

| ID | Weight | Notes |
|---|---|---|
| `Base.DryFirestarterBlock` | 0.1 | Marketed as a fire starter but **not in any recipe** — likely a vanilla oversight. Add to firestarting recipes. |
| `Base.Bellows` | 1.0 | **Caveat:** likely intended for forge fires; check `entities/blacksmith/`. May be a forge-building tag I missed. Worth verifying before repurposing. |
| `Base.Funnel` | 0.3 | **Caveat:** common in fluid-transfer mods; should reduce spill when pouring fluids between containers. Vanilla may not implement this. |
| `Base.RubberHose` | 0.3 (`base:siphongas`) | The tag suggests siphoning utility, but it's only in `LUA_FUNCTIONAL_TAGS` lookup not recipe_tags. May be already used by `ISSiphonGasoline` Lua. Verify. |
| `Base.MeasuringTape` | 0.2 | Could enable a "measure space" action for building planning, or be required to build precise furniture. Currently zero in-game use. |
| `Base.ScannerModule` | 0.1 | Radio component without a recipe. Likely intended for a deeper radio system that didn't ship. Could become a salvage scrap or part of a custom radio recipe. |

---

## Bathroom & household (1)

| ID | Weight | Notes |
|---|---|---|
| `Base.Pipe` | 1.0 | Plumbing pipe. Could pair with the toilet/bath need feature (DIY plumbing repair). |

---

## Misc / hard to categorize (6)

| ID | Weight | Notes |
|---|---|---|
| `Base.DryerLint` | 0.01 | Highly flammable IRL. Should be added to firestarting tinder recipes (and `base:isfiretinder` tagged). One-line fix. |
| `Base.CameraFilm` | 0.2 | Pairs with a `Camera` item (also probably underutilized). Could enable taking photos that become mementos / journal entries. |
| `Base.String` | 0.2 | Variant of `Twine`. Probably redundant; should be merged into twine recipes or be a sub-tier. |
| `Base.ClayJarGlazed` | 0.3 | Glazed clay jar — has `FluidContainer`. Should function as a pottery storage vessel; absence from recipes is likely a vanilla bug. |
| `Base.Clitter` | 0.2 | Cryptic name — likely a generic "clutter" placeholder item used as decorative randomization. Verify before repurposing; may be a flag rather than real loot. |
| `Base.CorpseFemale` | 20.0 | **Context: not normal loot.** This is the mannequin/dead-body item used in StoryClutter spawns and at least one in ProceduralDistributions. Spawning is intentional set-dressing, not random loot. Probably leave alone. |

---

## False-positive risks (audit limitations)

A few items in the strict list above carry caveats I couldn't fully
auto-verify:

- **`FountainCup`, `PlasticCup`** — have `component FluidContainer` and
  are 0.3L water-bearing. They likely *are* functional as drinkware via
  the B42 fluid system, but no Lua/recipe names them directly. Verify
  in-game by right-clicking and looking for "Drink" — if present, remove
  from your repurpose list.
- **`Bellows`, `Funnel`, `DryFirestarterBlock`** — strongly *imply*
  functional use but my audit found none. Likely either vanilla oversights
  (good news for the mod — add them to recipes) or referenced by sprite
  property / world-object hook rather than item-name. Spot-check.
- **`WineBox`** — fluid container with wine fluid. May already be
  drinkable / a cooking ingredient.
- **`CorpseFemale`** — quest/event spawn, not normal loot. Skip.

## Files

- Raw audit data: `outputs/junk_audit/`
  - `items.json` — full parsed item inventory (5088 items)
  - `recipe_inputs.json` — items + tags used as recipe inputs (1812 + 148)
  - `lootable.json` — items resolved from distribution tables (3210)
  - `lua_refs.json` — items referenced in functional Lua (2497)
  - `junk_candidates.json` — pre-annotation strict-junk list
  - `junk_candidates_final.json` — with spawn-table annotations
- Audit script: `outputs/junk_audit.py` (parses everything in one pass)

## What's NOT covered

- **DLC content:** no DLC content shipped with B42 as of this date; if
  any subfolder gets added later (e.g., `media/scripts/dlc/`), the audit
  needs an extra parse root.
- **Mod-added items:** the audit only covers vanilla; KH-specific items
  are deliberately excluded.
- **Tag-only Lua handlers:** if a Lua module references items only by tag
  (not by ID) and the item has no tags, my audit can't see the link.
  Mitigation: `LUA_FUNCTIONAL_TAGS` list inside the script enumerates
  known Lua-side tags. Extend as new ones are discovered.
