# FOOL Containers B42 — Patch Notes & Investigation Status

**Investigation date:** 2026-05-27 evening
**Status:** Partial fix applied; second root cause unidentified
**Mod:** UNOFFICIAL Fools New Containers B42 (workshop 3535295548, id `foolcontainers42`)
**Maintainer:** Mod is labeled UNOFFICIAL B42 port. Original FOOL mod was B41-only.

## Symptom

Every FOOL item fails to instance at game load. 80 unique items in the diag log. Each failure triggers a Java NPE:

```
java.lang.NullPointerException: Cannot invoke
  "zombie.inventory.InventoryItem.setAlcoholPower(float)" because "item" is null
    at zombie.scripting.objects.Item.InstanceItem(Item.java:1849)
```

The NPE means `InventoryItemFactory.CreateItem` returns null for these items. Then `InstanceItem` unconditionally calls `setAlcoholPower` on the null result.

## Cascade

When vehicles spawn, the engine's `BaseVehicle.addToWorld -> createPhysics -> randomizeContainers` chain rolls items from distribution tables. FOOL adds its items to vanilla distribution categories. Each roll that lands on a FOOL item NPEs.

Similarly, `IsoChunk.doLoadGridsquare` NPEs every time a world chunk loads containing a FOOL item in floor/ground loot.

Net effect: 70+ ErrorMagnifier errors per playtest, in two patterns:
- `(MOD:Bandits Week One)).AddVehicle` (during vehicle spawn)
- `IsoChunk.doLoadGridsquare` (during chunk load)

Both have the same underlying cause: FOOL items.

## Root cause #1 — case-sensitive ClothingItem lookup — FIXED 2026-05-27

`42.0/media/scripts/clothing/newcontainers_clothing_bags.txt` had 15 ClothingItem references with lowercase prefix (`container_NCXXX`, `bag_NCXXX`) but the actual XML files on disk are uppercase (`Container_NCXXX.xml`, `Bag_NCXXX.xml`). Java's map lookup is case-sensitive even though NTFS isn't.

**Fix applied:** Edited the script to capitalize all 15 prefix references via two `replace_all` edits plus 4 targeted edits for the `_back/_front` capitalization. Also affected: `Bag_NCforagepouch_Back`, `Bag_NCforagepouch_Front` variants where Back/Front need uppercase too.

**Caveat:** Steam Workshop re-sync will revert this patch. If FOOL receives an update, the fix has to be re-applied. To make it permanent, copy the FOOL workshop folder to `C:\Users\kiers\Zomboid\mods\` and unsubscribe from the Workshop version.

## Root cause #2 — UNKNOWN — under investigation

Items declared in `newcontainers_items.txt` (42 items, includes NCcdbinder, NCbreadbox, NCpiggybank, etc.) still fail despite:
- Correctly-cased `ClothingItem = Container_NCXXX` references
- Matching `Container_NCXXX.xml` files existing on disk
- Matching `WorldStaticModel = NCXXX_ground` model entries existing in `newcontainers_models_items.txt`
- Matching textures, sounds, etc.

Same for `newcontainers_items_food.txt` (20 items: NCbeveragejug, NCdishtub, NCkidsflask, NCpitcher, etc.) which use `Type = Normal` + `component FluidContainer`.

**Suspect leads not yet verified:**

- FOOL icon files are named lowercase `item_NCXXX_NN.png`. Vanilla B42 convention is uppercase `Item_<name>.png` (verified via `Item_Chisel_Forged.png`, `Item_Handsaw_Forged.png` in vanilla). However, icon-resolution failure typically produces a placeholder icon, NOT a null item. So this might be a contributing factor but probably not THE cause.

- `Type = Container` items in FOOL declare no `ContainerName` field. Vanilla B42 container items have ContainerName. If B42.18 made this field required, all FOOL Container items would fail to instance. **This is the most promising hypothesis I didn't get to verify.**

- The `component FluidContainer` schema may have changed between FOOL's port date and B42.18. Items_food.txt could be hitting a renamed required field.

## What hasn't worked

- The case fix in clothing_bags.txt — fixes those items only, doesn't help the systemic failure in items.txt / items_food.txt.
- pcall-wrap in `KH_BanditsFixVehicleNPE.lua` — suppresses the Lua-side error so the game continues, but PZ's Java exception logger still emits the stack trace and ErrorMagnifier reports it.

## Pragmatic alternatives

If full upstream fix proves elusive:

1. **Unsubscribe FOOL.** All errors stop. Loses the containers. Kierstal's KH_ColdStorage handles cold-storage independently, so the main FOOL value-add (cooler bag types) isn't critical to her playstyle.

2. **KH-side distribution filter.** Write a KH module that strips FOOL items from random loot at OnGameStart. Items still exist (so map-placed FOOL containers won't break) but never get rolled randomly. Eliminates the NPE noise from random spawns.

3. **Force-pcall the engine.** Wrap `InventoryItemFactory.CreateItem` from Lua to return a safe stub when null would be returned. Requires reaching into Java-side methods that may not be exposed.

## Files touched by this patch

- MODIFY: `workshop/3535295548/mods/newcontainers_B42/42.0/media/scripts/clothing/newcontainers_clothing_bags.txt` — 15 ClothingItem prefix capitalizations
- NEW (in KH): `42.0/media/lua/client/Compat/KH_BanditsFixVehicleNPE.lua` — Lua-side pcall wrap

## If FOOL Workshop updates

The patch in clothing_bags.txt will be reverted. To re-apply:

1. Open `C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/3535295548/mods/newcontainers_B42/42.0/media/scripts/clothing/newcontainers_clothing_bags.txt`
2. Find/replace `ClothingItem = container_NC` -> `ClothingItem = Container_NC`
3. Find/replace `ClothingItem = bag_NC` -> `ClothingItem = Bag_NC`
4. Find/replace `Bag_NCforagepouch_back` -> `Bag_NCforagepouch_Back` (also `_back_crafted`, `_front`, `_front_crafted`)

Or restore from a backup copy of this patched file before the Steam sync.
