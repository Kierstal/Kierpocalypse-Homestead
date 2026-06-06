# Homestead Residents — Design Note

Status: **DESIGN / not yet implemented**
Author intent (Kierstal, 2026-06-06): a Bandits-free, SSR-Quests-free way to
make it *look* like you're tending a small village. Static mannequin "residents"
you place from a bedroll, feed, and check on. No walking, no AI, no idle
animation — purely a placed presence with right-click interactions and a
tracking panel. Dialogue is just a halo phrase acknowledging what you did.

This is explicitly an **illusion-of-population** feature. The residents are not
alive in code; they are dressed `IsoMannequin` objects projected from a
player-modData registry that is the real source of truth.

--------------------------------------------------------------------------------

## What already exists that this builds on

| Existing piece | Reused for |
|---|---|
| `shared/Core/KH_NPCRegistry.lua` | recognize/forget/count residents; already mod-agnostic, modData-persisted, keyed by string id. `KH_Loner` already excludes recognized NPCs from stress, and `recognizedNPCCount()` already gates the "village layer." Residents mirror into here for free integration. |
| `shared/Home/KH_HomeTerritory.lua` | `KH.Home.isAtHomestead(player)`, `KH.Home.typeAt(player, sq)`, `KH.Home.listAll(player)`, `buildingIdOfSquare`. Gates where bedrolls/residents are valid. |
| `client/Pets/KH_DebugSpawnPet.lua` | the spawn pattern: construct world object → `addToWorld()` → stamp identity in player modData → reconcile on a tick. Mannequin spawn is the direct analog of `IsoAnimal.new + addToWorld`. |
| `client/UI/KH_HomesteadTab.lua` | the UI patterns: `drawBar(label, value, max, y)` with green→red lerp is exactly the "supplies current/max" widget; the `createChildren` wrap is the template for adding our sidebar button. |
| `client/Compat/KH_BanditCommands.lua` | the `OnFillWorldObjectContextMenu` detect-object-under-cursor → add submenu pattern, reused for the floor-tile "Place Resident" option and the resident right-click menu. |
| `client/Thoughts/KH_Thoughts.lua` (`KH.Thoughts.emit`) | flavor reactions ("my people are fed"). |
| `HaloTextHelper.addText` (used in HomeTerritory) | the resident's acknowledgement halo phrase. |

So the **registry, territory, spawn, UI-bar, and context-menu patterns are all
already in the mod.** The new work is mostly wiring + the mannequin visual + the
panel + (Phase 3) the combat illusion.

--------------------------------------------------------------------------------

## Source of truth: the resident registry

All resident state lives in **player modData** (chunk-independent, survives
save/load, MP-safe). The mannequin and bedroll world objects are disposable
*projections* of this record. Proposed schema, stored under a new key
`KH_Residents` (parallel to `KH_recognizedNPCs`):

```lua
md.KH_Residents[residentId] = {
    name      = "Martha",
    role      = "Cook",                 -- cosmetic in v1 (see Open Q4)
    bedroll   = { x=, y=, z=, buildingId= },  -- the bedroll it's bound to
    pos       = { x=, y=, z= },               -- where the mannequin stands
    supplies  = { food = 8, maxFood = 12 },   -- shown as current/max bar
    gifts     = { ["Base.Foo"] = 2 },         -- non-food stored items (flavor)
    hp        = 100, maxHp = 100, alive = true,
    want      = { day = 1234, itemType = "Base.X", rewarded = false },
    createdHour     = <worldAgeHours>,
    lastConsumeHour = <worldAgeHours>,
}
```

`residentId` = e.g. `"KHres_" .. getTimestampMs() .. "_" .. ZombRand(1e6)`.

- The bedroll object stores `modData.KH_residentId` (its bound resident).
- The mannequin object stores `modData.KH_residentId` (back-ref) + `KH_isResident=true`.
- On creation we also call `KH.recognizeNPC(residentId, "resident", name)` so the
  existing Loner exemption / village-activation logic lights up with no changes.

Consumption uses **world-age-hours catch-up math** (same `getWorldAgeHours()`
the registry already uses): on visit/tick, `elapsed = now - lastConsumeHour`,
decrement food accordingly, clamp at 0, set `lastConsumeHour = now`. This means
residents in unloaded chunks are accounted for correctly without needing their
chunk loaded every tick.

--------------------------------------------------------------------------------

## The flow (mapped to Kierstal's 5 steps)

### 1. Craft NPC Bedroll  — *trivial*
New script item `KH_ResidentBedroll` + a recipe (follow
`media/scripts/items/KH_trash_item.txt` and
`media/scripts/recipes/KH_uncraftable_recipes.txt` conventions). Reuse a vanilla
bedroll/sleeping-bag world sprite for the placed object.

### 2. Place bedroll in a claimed Homestead  — *easy*
Placed as a world object. Gating is enforced at step 3, not here (simpler), but
we surface a halo warning if placed outside any `homestead` territory.

### 3. Right-click ANY FLOOR TILE → "Place Resident"  — *medium*
`OnFillWorldObjectContextMenu`. Option appears only when **all** of:
- player is currently standing in a `homestead` territory (`KH.Home.isAtHomestead`),
- there is a bedroll within **25 tiles** of the clicked square whose
  `KH_residentId` is unset (one resident per bedroll),
- the clicked square is a valid walkable floor (`getFloor()` present, not solid).

On click → open the **creation dialog** (Phase 1): text field for **name**, a
**role** field/dropdown, and (Phase 2) a starting **supply inventory**. On
commit: spawn the dressed mannequin at the clicked tile, generate `residentId`,
write the registry record, stamp both objects, `recognizeNPC`, fire a halo
("*Martha is settling in.*").

**Binding & teardown:** bedroll ⇄ resident linked by id. Because PZ has no
reliable "moveable removed" event, a **reconciliation sweep** (every ~10 in-game
minutes, loaded chunks only) verifies each resident's bedroll still exists on its
saved square; if the chunk is loaded and the bedroll is gone (player picked it
up), despawn the mannequin and remove the resident. Unloaded chunks are skipped
(can't tell → leave alone). This mirrors the defensive-scan style already used in
`KH_ThoughtTriggers` / `KH_HomeTerritory`.

### 4. Passive hunger / supplies  — *medium*  (Phase 2)
Two models considered:

- **(A) Virtual supply store (recommended for v1).** The resident has a numeric
  food pool you top up by *giving* items (right-click resident → "Give supplies",
  or via the panel). Daily catch-up consumption decrements it. Robust,
  chunk-independent, drives the panel bar directly. Matches "an inventory I can
  add items to that they consume over time."
- **(B) Designated container pull (the "Bandit fridge" feel).** Optionally link a
  real food container; consumption removes actual food items from it. More
  immersive but only resolvable when that chunk is loaded (needs catch-up
  reconciliation) and more failure-prone.

**Plan:** ship (A) first; add (B) later as an optional "link a pantry" upgrade.
Food → consumed (hunger). Non-food gifts → stored as flavor / could feed a future
"comfort" stat; not consumed in v1.

### 5. Thumpable / zombie-attractable / destructible  — *HARD, experimental* (Phase 3)
Honest assessment — mannequins are `IsoObject`s; vanilla zombies do **not**
natively target or path to them. Achievable as an *illusion* in two parts:

- **Attraction:** periodically emit a small world sound at the resident's tile
  (`addSound`/world sound manager) to lure nearby zombies. Crude but tunable.
- **Damage/death (self-managed, recommended over relying on AI):** on a tick, for
  each *loaded* resident, scan adjacent squares for zombies in an attack/aggro
  state; if present, decrement `hp` (player-like pool), play a hit sound + halo
  ("*Help!*"); at `hp<=0` despawn the mannequin and set `alive=false` →
  player must craft/place a new resident for that bedroll.

Caveats to accept:
- Only resolves while the chunk is **loaded** — i.e., residents are only in danger
  when you're nearby. This is arguably a *feature* ("a horde broke in while I was
  defending the homestead") and prevents silently losing residents while away.
- It will feel scripted, not emergent. Co-locating a real `IsoThumpable` with HP
  to borrow native thumping is possible but less controllable; self-managed HP is
  the more predictable path.

**Recommendation:** sandbox-toggled, **default OFF**, built last. Phases 1–2 are
the solid, shippable core fantasy and don't depend on this.

--------------------------------------------------------------------------------

## The Homestead sidebar panel

Goal: a **House icon button below the health heart** in the bottom-left sidebar,
opening a panel that lists every placed resident with:
- name + role,
- **supplies current / max** bar (reuse `KH_HomesteadView:drawBar`),
- today's **randomized "want"** (item icon + name) with a "give" affordance.

**Daily want:** per resident, seed a deterministic roll by `(residentId,
worldAgeDay)` so it's stable across panel reopen and reload within the same day.
Pick any item from `getScriptManager():getAllItems()` — wants need not be
reasonable or already-discovered. Giving the wanted item → **reward** (see Open
Q2); want refreshes next day. **No penalty** for not fulfilling — it's the
apocalypse, they understand.

**Sidebar host (needs API verification):** the clickable heart that opens the
health window lives in a vanilla HUD object; we'll add our button by wrapping its
`createChildren` the same way `KH_HomesteadTab` wraps `ISCharacterInfoWindow`.
The exact host class for the bottom-left icon strip must be confirmed against the
B42 source. **Fallback** if hooking the strip proves fragile: a standalone
draggable window toggled by a keybind and/or a button on the existing Homestead
character tab — same panel content either way.

--------------------------------------------------------------------------------

## Phasing

- **Phase 1 — Core presence (low risk).** Bedroll item + recipe; place bedroll;
  floor-tile "Place Resident" (range + once gating); name/role dialog; spawn
  dressed mannequin; id-link + registry record + `recognizeNPC`; reconciliation
  sweep (bedroll gone → resident gone); halo acknowledgements.
- **Phase 2 — Care loop (medium).** Per-resident supplies + giving items; daily
  catch-up consumption; Homestead panel (list + supply bars + daily want);
  want roll + reward + thank-you halo.
- **Phase 3 — Danger (experimental, opt-in).** Sound attraction + self-managed
  HP/damage + death → requires replacement. Sandbox toggle, default OFF.

--------------------------------------------------------------------------------

## API items to verify before coding (B42)

1. `IsoMannequin` spawn signature + `addToWorld()` analog, and how to set
   gender / skin tone / **clothing** / pose programmatically (vanilla normally
   dresses mannequins via the "dress mannequin" action; need the Lua path).
2. The host class/object for the bottom-left **health-icon sidebar** to attach the
   House button (else use the fallback window/keybind).
3. World-sound emission call for Phase 3 attraction (`addSound` args / radius).
4. Robust "is this square a placeable floor" check on B42 (`getFloor`,
   solidity, walkability).

--------------------------------------------------------------------------------

## Open decisions (need Kierstal's call)

1. **Supplies UX:** virtual "give item" store (robust) vs. a real drag-drop
   container on the resident (nicer feel, chunk-bound)? — *recommend virtual for v1.*
2. **Want reward:** mood/thought boost only, or also small XP, or an occasional
   item gift back? — *recommend mood + halo, with optional small item.*
3. **Phase 3 danger default:** residents vulnerable to zombies OFF until opted in
   (recommended), or ON by default?
4. **Role:** purely cosmetic flavor in v1, or should it eventually do something?
   *(No-AI constraint means any role effect is passive/statistical.)*
