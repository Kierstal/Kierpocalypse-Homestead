# Toilet + Bath Needs + Dirtiness Moodlet — Locked Scope

**Status:** scoped, not implemented. This is the agreement to build to.

**Locked decisions** (Kierstal, 2026-05-11):
1. **NeatFreak/Slob unified into a single trait pair** spanning both room-filth
   and personal-cleanliness effects. Costs **+4 / -3** (revisit if it feels
   off in playtest).
2. **Toilet sit animation = the existing Rest animation** (the one used by
   `Mov_Couch`, `Mov_Sofa`, chair sit). Concrete reference: 
   `media/lua/shared/TimedActions/ISRestAction.lua`. See implementation
   notes below.

---

## API surface (verified against B42 install)

### Dirt and blood are per body part — already in vanilla
- `player:getHumanVisual():getDirt(part)` / `:setDirt(part, 0)`
- `player:getHumanVisual():getBlood(part)` / `:setBlood(part, 0)`
- Iterate `BloodBodyPartType` enum, sum across parts → personal dirtiness score.
- Reference: `shared/TimedActions/ISWashYourself.lua` does exactly this.

### Clothing dirtiness (separate, optional)
- `item:getDirtiness()` returns 0..100 on each clothing item.
- `ISGarmentUI.lua` renders it as a bar.
- Decision: fold into personal-dirt score with a weight (e.g. visible/worn
  items count, undergarments don't). Final weight TBD during impl.

### Wash hook
- `shared/TimedActions/ISWashYourself.lua` resets blood + dirt on perform.
- Fires `character:reportEvent("EventWashClothing")` at start (mis-named —
  fires for body-wash too).
- Strategy: wrap `ISWashYourself.perform = function(self) <orig>(self); KH.Bath.onWashed(self.character) end` rather than subscribing
  to the event, for cleaner data flow.

### No native toilet-use action
- Vanilla `Mov_ChemicalToilet` / `Mov_FancyToilet` exist as movable items;
  toilet world objects exist but only as water sources.
- Action must be built from scratch. See Toilet implementation notes.

### No vanilla bath/toilet need stat
- `getStats()` exposes hunger/thirst/stress/boredom/fatigue/endurance/
  drunkenness/panic. **No hygiene or elimination need.**
- Bath need + toilet need must be tracked as **modData floats (0..100)**
  on the player, ticked manually, persisted via `player:getModData()`.
- Visible effects route through existing Stats (stress↑, unhappiness↑) at
  thresholds — KH doesn't need to register a new core stat type.

### No vanilla NeatFreak / Slob / Hygienic trait
- All hygiene-relevant traits register fresh under `KH:` namespace.
- The Pluvio mutex pattern from `shared/Traits/KH_TraitRegistry.lua` is
  the template.

---

## File layout (target)

```
shared/Needs/KH_NeedsCore.lua        -- tick/threshold/delta helpers (NEW)
shared/Filth/KH_FilthScan.lua        -- room-filth scoring (from filth scope)
shared/Dirt/KH_DirtScore.lua         -- HumanVisual + clothing dirt sum (NEW)
shared/Traits/KH_TraitRegistry.lua   -- (extend) add NeatFreak/Slob unified,
                                        ToughBladder/WeakBladder, Outdoorsy
shared/Thoughts/KH_ThoughtLines.lua  -- (extend) "dirtiness", "toilet",
                                        "bath", "toilet_accident" categories

client/Dirtiness/KH_DirtMoodlet.lua  -- tick personal dirt → mood (NEW)
client/Bath/KH_BathNeed.lua          -- tick bath need + sweat/blood input (NEW)
client/Toilet/KH_ToiletNeed.lua      -- tick toilet need + eat/drink input,
                                        accident handler (NEW)
client/Toilet/KH_UseToiletAction.lua -- ISBaseTimedAction (NEW)
client/UI/KH_NutritionPanel.lua      -- (extend) add Bath+Toilet bars

client/Hooks/KH_WashHooks.lua        -- wrap ISWashYourself:perform to
                                        reset bath need + emit thought (NEW)
```

---

## Tick + threshold mechanics

All three (filth, bath, toilet) share the same tick shape. Per-minute
deltas, trait-modified, threshold-driven mood effects.

**Filth moodlet** — already scoped; depends on room scan + trash count.
**Bath need** — rises with time + sweat (heat/exertion) + getting blood
or dirt; relief via wash actions.
**Toilet need** — rises with eating + drinking; relief via toilet-use OR
outdoors-squat (with mood penalty unless Outdoorsy).
**Personal-dirt moodlet** — tied to `HumanVisual:getDirt/getBlood` sums.
Independent of bath need (you can have a "high bath need" without
actually being dirty yet, and vice versa).

**Compounding rule** (interaction with filth moodlet): standing in a
filthy room AND being personally dirty multiplies BOTH penalties by ~1.4.

**Sleeping-while-filthy bump:** on wake event, if sleep room was filthy
OR personal dirtiness was grubby, fire one-shot stress + unhappiness +
bath-need spike + "filth" thought line.

---

## Trait list (unified)

Register under `KH:` namespace (same pattern as existing Pluvio pair):

| Short ID | Cost | Effect | Mutex |
|---|---|---|---|
| `KH:NeatFreak` | **+4** | ×1.75 to both filth/dirt mood penalties AND clean rewards. | `KH:Slob` |
| `KH:Slob` | **-3** | ×0.4 filth/dirt mood penalties, no clean reward at all. | `KH:NeatFreak` |
| `KH:ToughBladder` | +2 | Toilet need rises 0.6×; hard-fail threshold raised. | `KH:WeakBladder` |
| `KH:WeakBladder` | -2 | Toilet need rises 1.5×; hard-fail threshold lowered. | `KH:ToughBladder` |
| `KH:Outdoorsy` | +2 | No mood penalty for going outdoors instead of toilet; bath need rate -10%. | optional mutex with NeatFreak |

Vanilla traits to hook if present in B42 (verify before depending):
- `Smoker` — neutral; stale-smoke could feed dirt slightly. Probably skip.
- `Outdoorsman` (past builds) — if present, prefer over `KH:Outdoorsy`.
- `Hemophobic` (if still there) — extra penalty for blood on body.

---

## Toilet use action — implementation notes

**Decision: reuse the Rest animation.** This means modeling
`KH_UseToiletAction` on `ISRestAction` (`shared/TimedActions/`), not on
`ISBaseTimedAction` directly.

### How `ISRestAction` wires the sit animation
1. `self.bed` is set to the furniture object (couch/bed/chair).
2. In `waitToStart()`: calls `self.bed:setSatChair(true)`,
   `self.character:setSitOnFurnitureObject(self.bed)`,
   `setSitOnFurnitureDirection(sitDir)`.
3. In `start()`: if `furnitureHasSittingData(self.bed)` returns true,
   fires `reportEvent("EventSitOnFurniture")` and the engine plays the
   sit-on-furniture animation aligned to the object.

### Adapting it for toilets
- Set `self.toilet` to the toilet IsoObject. Pass it as `self.bed` to
  the rest pipeline (the param name is internal; it just needs to be a
  valid sittable IsoObject).
- **Gotcha to verify:** `furnitureHasSittingData(toilet)` may return
  false. Toilets aren't in the vanilla "sittable furniture" list. If so,
  options in order of preference:
  - **(a)** Mark toilet objects as sittable via a custom prop attach
    (`MoveableObjectProps` tag or an `attachedanim_*` override).
  - **(b)** Fall through to a non-animated timed action: skip the sit
    pose entirely, just play `setActionAnim("Rest")` directly on the
    character and don't anchor to the object. Cheaper, less polished,
    no risk.
  - **(c)** Use `ISTakeShelterAction` or similar as alternate template
    if Rest doesn't bind to the toilet object's tile properly.
- For v1, recommend **path (b)** unless quick prototype shows path (a)
  works trivially. Animation polish is secondary to need-tracking
  correctness.

### Action lifecycle (whichever animation path)
1. Walk-adjacent (`luautils.walkAdj`).
2. Start the timed action — duration ~80 ticks (a couple seconds).
3. On `perform()`:
   - Reset `player:getModData().KH_toiletNeed = 0`
   - Apply small unhappiness reduction
   - Emit `KH.Thoughts.emit(p, "toilet", "relieved")`
4. On `stop()`: restore character pose, no-op otherwise.

### Detecting toilet objects
- Sprite name match: `^toilet` (vanilla `toilet_01_*` sprites).
- OR check object properties for `IsToilet` flag (verify via TileZed
  against B42 sprite props — likely exists; if not, fall back to sprite
  name match).
- Hook via `OnFillWorldObjectContextMenu` like `KH_TrashPickup.lua` does.

---

## UI

**Hidden meters + moodlet icons** (vanilla philosophy), plus opt-in bars
in the existing `KH_NutritionPanel`.

**New moodles to register via `MF.MoodleFactory:createMoodle()`:**
- `KH_NeedToPee` (4 tiers: mild urge → urgent → desperate → emergency).
- `KH_Filthy` (3 tiers: grubby → dirty → reeking).

Stub icons OK to ship v1; replace with custom art later.

---

## Open design questions — recommendations

**Q1 — Toilet hard fail (wetting pants):** **Yes, ship in v1.** One-shot
unhappiness +25, bath need +20, all worn clothing dirtiness +30, a
humiliated thought line. Locked behind a 24-hr in-game cooldown so it
doesn't doom-spiral.

**Q2 — Bath need at game start:** Scenario-dependent.
- Apocalypse / Survivor: spawn at 0.
- Six Months Later: spawn at 30 (mid-grubby — water's been out).
- Sandbox: configurable.

**Q3 — Multiplayer:** Design MP-safe from the start. All ticks
client-side on local player modData. Wash hook: `EventWashClothing`
fires server-side too — make sure hook doesn't double-fire. Toilet
action uses standard timed-action queue. Mark MP as
"tested in v0.2" since I don't have a local MP test rig.

**Q4 — Water scarcity tie-in:** **Yes, important.** After
`getWaterShutModifier`, sinks require a fluid container with ≥250mL of
fresh water (mirror the bleach-required pattern from B42's Clean Stains).
Lakes and rain barrels keep working — "boiled lake water for a sponge
bath" is the homestead theme.

**Q5 — Bath affects sociability:** Defer to v0.2. B42's NPC system isn't
mature enough. Animal happiness reduction near filthy player could be a
fun side-effect (foraging animals scatter); mark as stretch goal.

**Q6 — Toilet relief outdoors:** Yes, valid path. Small mood penalty
(-3 unhappiness, "Not how I wanted to live"). Removed entirely by
`KH:Outdoorsy`. Detect via `square:getRoom() == nil`.

---

## Won't-do in v1

- Animated "wash hands" sub-action — skip; the existing ISWashYourself
  already covers this conceptually.
- Sewer system / plumbing repair — out of scope.
- Bidet / bathtub special variants — toilet-only for v1.
- Trait-gated unlock mechanics ("learn to shave") — assume traits are
  set at character creation only.
