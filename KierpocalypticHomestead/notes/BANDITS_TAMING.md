# Bandits + Bandits Week One — Taming

**Pass date:** 2026-05-27
**Implementation:** `42.0/media/lua/client/Compat/KH_BanditsTame.lua`
**Sandbox toggles:** `KHCompat.TameBandits`, `KHCompat.TameBanditsWeekOne`
(both default TRUE, page `KH_Compat`)

## Why

Kierstal kept both mods subscribed but said the defaults produce too
much chaos: too many hostile NPCs, constant pressure that forces her
to keep moving, random aggro. She wants NPCs as **background
worldbuilding presence**, not the foreground combat game. Both mods
are "the only viable NPC framework for B42" so removing them isn't
an option.

## How it works

`KH_BanditsTame.lua` runs on `Events.OnGameStart`. If `KH.compat.bandits`
or `KH.compat.banditsweekone` is true AND the matching sandbox toggle
is ON, the module writes the KH-tamed values into the live sandbox
options.

Two-channel writes for safety: option object via
`SandboxOption:setValue` AND mirror to the `SandboxVars.<Namespace>.<Field>`
table. Bandits internals read from both depending on the file; mirroring
prevents missed updates.

The taming is **per-launch idempotent** — every game start writes the
values fresh. Continuing a save with the toggle OFF won't undo prior
writes (PZ persists sandbox values per-save). To get vanilla Bandits
behavior back: toggle OFF and start a new game, OR open the in-game
Bandits options menu and manually reset.

## Bandits (Workshop 3268487204) — value changes

Source defaults from
`steamapps/workshop/content/108600/3268487204/mods/Bandits/42.18/media/sandbox-options.txt`

| Option | Vanilla default | KH tamed | Reasoning |
|---|---|---|---|
| `Bandits.General_SpawnMultiplier` | 1.00 | **0.30** | -70% spawns. Most direct lever on "too many hostiles." |
| `Bandits.General_SizeMultiplier` | 1.00 | **0.40** | Groups of 1–2 typical, rare 3. -60% group size. |
| `Bandits.General_DestroyDoor` | true | **false** | Bandits don't tear down doors. Homestead survives raids. |
| `Bandits.General_SmashWindow` | true | **false** | No glass-breaking entry. |
| `Bandits.General_RemoveBarricade` | true | **false** | Player barricades stick. |
| `Bandits.General_DestroyThumpable` | true | **false** | No furniture-smashing. |
| `Bandits.General_SabotageVehicles` | true | **false** | Vehicles aren't sabotaged overnight. |
| `Bandits.General_Theft` | true | **false** | Bandits don't loot her containers. |
| `Bandits.General_SabotageCrops` | true | **false** | **Critical for homestead** — crops don't get burned. |
| `Bandits.General_GeneratorCutoff` | true | **false** | No infrastructure attacks. |
| `Bandits.General_BuildRoadblock` | true | **false** | World roads stay clear. |
| `Bandits.General_OverallAccuracy` | 3 (mid) | **2** (poor) | Bandits hit less often when they do fire. Less lethal random encounters. |

**Deliberately kept default TRUE** (these encourage non-combat
resolutions or feel right for a quiet world):

- `Surrender`, `BleedOut`, `Infection`, `LimitedEndurance`, `RunAway`
- `SneakAtNight`, `CarryTorches`, `Speak`, `Captions`, `ArrivalIcon`
- `OriginalBandits`, `KillCounter`, `CorpseSwapper`

**Not touched:**

- `EnterVehicles` (already default false)
- `BuildBridge` (already default false)
- `StunlockHitSpeed` (combat tuning, not pressure tuning)
- `DensityScore`, `DefenderLootAmount` (loot economy)

## Bandits Week One (Workshop 3403180543) — value changes

Source defaults from
`steamapps/workshop/content/108600/3403180543/mods/BanditsWeekOne/42.18/media/sandbox-options.txt`

### Population multipliers (range 0–4, vanilla all 1.0)

| Option | Default | KH tamed | Reasoning |
|---|---|---|---|
| `InhabitantsPopMultiplier` | 1.00 | **0.50** | Half as many "neighbor" survivors. Still has world-presence feel. |
| `StreetsPopMultiplier` | 1.00 | **0.30** | Streets are mostly empty. -70%. |
| `ArmyPopMultiplier` | 1.00 | **0.30** | Military checkpoints are rare. |
| `BanditsPopMultiplier` | 1.00 | **0.30** | Hostile bandit pop matches the Bandits-mod spawn cut. |

### Equipment tier

| Option | Default | KH tamed | Reasoning |
|---|---|---|---|
| `InhabitantsPistolChance` (0–100%) | 7 | **3** | Half as many armed inhabitants. |
| `StreetsPistolChance` | 3 | **1** | Random street encounters rarely armed. |

### Patrol vehicles + speed

| Option | Default | KH tamed | Reasoning |
|---|---|---|---|
| `VehiclesMax` (0–10) | 4 | **2** | Half the max patrol cars. |
| `VehiclesSpeed` | 1.0 | (untouched) | Speed feels fine. |

### Service cooldowns (minutes, lower = more frequent)

| Service | Vanilla | KH tamed | Multiplier |
|---|---|---|---|
| `PoliceCooldown` | 30 | **120** | ×4 (slower) |
| `SWATCooldown` | 120 | **480** | ×4 (slower) |
| `MedicsCooldown` | 45 | **180** | ×4 (slower) |
| `HazmatCooldown` | 50 | **180** | ×3.6 (slower) |
| `FiremanCooldown` | 25 | **120** | ×4.8 (slower) |

### Disaster events (vanilla all TRUE)

| Event | Vanilla | KH tamed | What it is |
|---|---|---|---|
| `EventFinalSolution` | true | **false** | The nuke event. Off because "constant pressure" includes "the world might end on day 6." |
| `EventBoeing` | true | **false** | Plane-crash event. Too loud + chaotic for the homestead aesthetic. |
| `EventStrafe` | true | **false** | Aerial gun strafe. Aggressive sky events break the calm. |
| `EventBombing` | true | **false** | Bombing run. Same reasoning. |
| `EventGas` | true | **false** | Gas attack. Random punishment. |
| `EventArson` | true | **false** | Random fires. Risks the homestead without warning. |

**Not touched:**

- `StartTime`, `StartBabe`, `StartRide` (intro / spawn-config — not pressure)
- `PriceMultiplier`, `PriceInflation` (trade economy)

## Guessing vs knowing

Numbers I'm **confident** about (clear semantics from the option name +
range):

- Spawn / size multipliers (clear "this many" scaling)
- Boolean-flag flips (true/false; effect is binary)
- Population multipliers in Week One

Numbers I'm **guessing**:

- **Bandits accuracy 3 → 2** (5-tier enum; I assumed lower = worse).
  If Kierstal sees bandits become snipers, this might be inverted.
- **Service cooldown ×4 multiplier**. Could be too tame (you never see
  a cop car) or just right. Easy to dial back.
- **Disaster events off entirely**. Could be that disabling all of
  them removes important world-pulse moments she'd actually enjoy.
  Recommend her trying with one or two re-enabled if she wants more
  sky activity.

If you want a quieter homestead than this: drop SpawnMultiplier to
0.15, SizeMultiplier to 0.25, and bump all the BanditsWeekOne pop
multipliers down another 50%.

If you want LOUDER again: turn the disaster events back on one at a
time and bump spawn back to 0.50.

## Reversibility

- **Per-feature toggle:** `KHCompat.TameBandits` /
  `KHCompat.TameBanditsWeekOne` in sandbox options page `KH_Compat`.
  Toggle OFF to disable taming for the next launch.
- **Per-value tuning:** edit `KH_BanditsTame.lua` BANDITS_TAME /
  WEEKONE_TAME tables. Values are clearly labeled with vanilla defaults
  as comments.
- **Complete revert:** delete `KH_BanditsTame.lua` and remove the two
  toggle entries from `sandbox-options.txt`. Vanilla Bandits behavior
  returns on next new game.

## What this does NOT solve

- **Already-spawned bandits in a continued save** keep their existing
  values until they despawn / are killed. Taming applies forward, not
  retroactively.
- **In-game Bandits options menu** can still be opened and may show
  different values from what KH wrote (depending on whether the UI
  reads SandboxOptions or SandboxVars). The actual gameplay should
  follow KH's writes because most internals read SandboxVars.
- **The Bandits mod itself might update** in a future Steam Workshop
  push and rename or restructure these options. KH's
  `setOptionValue` is pcall-wrapped — if an option vanishes, the
  write is a silent no-op rather than a crash. If new options appear
  that should be tamed, add them to the BANDITS_TAME / WEEKONE_TAME
  tables.
