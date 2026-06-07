# Starving Zombies — Design Note

Status: **DESIGN / not yet implemented**
Intent (Kierstal, 2026-06-06): zombies are drawn to nearby **dead zombies**
(corpses), with an **indoor/outdoor gate**:
- An **outdoor** zombie is NOT attracted to a corpse that's **indoors**.
- An **indoor** zombie is only attracted to a dead zombie **in its own building**.

The flavor: starving undead scavenging the fallen. Mechanically it concentrates
roamers around kill-sites and makes indoor clears "stick" instead of constantly
pulling the outside horde through your walls.

Built opt-in, sandbox-toggled, default OFF (it changes horde behavior and is
performance-sensitive).

--------------------------------------------------------------------------------

## Core mechanic

PZ zombies are driven by sound/sight targets; they don't natively path to
corpses. So we synthesize attraction:

- **Periodic corpse scan** (throttled, e.g. every few seconds, loaded chunks
  only): find dead-zombie corpses (`IsoDeadBody` with a zombie flag) near the
  player's loaded area.
- For each corpse, **lure nearby living zombies** toward it — the cleanest
  vanilla lever is a small, short-range **world sound / attraction** at the
  corpse tile, OR directly nudging a zombie's target/path toward the corpse when
  it's within range and otherwise idle. Verify which is reliable in B42
  (`zombie:pathToLocation` / setting a movement target vs emitting an
  attraction). Keep the radius small so this is local scavenging, not a
  map-wide magnet.

## The indoor/outdoor gate (the defining rule)

For a (livingZombie, corpse) pair, attraction is allowed only if:

| Living zombie | Corpse | Attracted? |
|---|---|---|
| Outdoor | Outdoor | Yes (range-limited) |
| Outdoor | Indoor  | **No** |
| Indoor  | Indoor, **same building** | Yes |
| Indoor  | Indoor, different building | No |
| Indoor  | Outdoor | No (decide; default No) |

Implementation: classify each via its square — `square:isOutside()` for
indoor/outdoor, and `square:getBuilding():getDef():getIDString()` to compare
buildings (same helper KH_HomeTerritory already uses). A corpse and a zombie are
"same building" when their building ids match.

## Performance

This is the main risk — corpse×zombie pairing can blow up. Mitigations:
- Loaded chunks only; hard cap on corpses and zombies considered per tick.
- Generous throttle (seconds, not every tick); round-robin if needed.
- Small attraction radius (e.g. ≤ 8–10 tiles) so the candidate set per corpse is
  tiny.
- Early-out on the cheap checks (range, then isOutside, then building id) before
  any pathing call.

## Sandbox options (proposed, KHZ namespace)
- `KHZ.StarvingZombies`        (default OFF)
- `KHZ.CorpseAttractRadius`    (default 8)
- `KHZ.IncludeOutdoorToIndoor` (default false — the "outdoor zombie ignores
  indoor corpse" rule; exposed in case Kierstal wants to relax it)

## API items to verify before coding
1. Enumerating **dead zombie corpses** in loaded chunks (`IsoDeadBody`, zombie
   flag) and living zombies near a point.
2. The reliable **attraction** primitive in B42: emit a world sound at a tile
   vs. directly set a zombie's path/target toward the corpse.
3. `square:isOutside()` semantics + building-id comparison (reuse
   KH_HomeTerritory's `buildingIdOfSquare`).

## Open decisions
- Should an indoor zombie ever be pulled to an *outdoor* corpse near its door?
  (Default: no — keeps indoor clears clean.)
- Do corpses "decay" as an attractor over time (older corpses pull less)?
- Visual/audio feedback when zombies are scavenging, or keep it silent/emergent?
