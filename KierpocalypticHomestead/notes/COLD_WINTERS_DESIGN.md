# Cold Winters — Design Note

Status: **DESIGN / not yet implemented**
Decisions locked (Kierstal, 2026-06-06): **Wisconsin-hard** winter (lows ≈ −25 to
−30 °C, frequent blizzards/winter storms) + **generator cold-failure with manual
restart**. Vanilla "Cold" tops out around −15 °C (reasonable for Kentucky); this
pushes it to a genuine prepare-or-die season — and makes KH's natural
refrigeration (`KH_ColdStorage`) actually matter.

Built as its own opt-in layer, sandbox-toggled, so a vanilla-temp playthrough is
one switch away.

--------------------------------------------------------------------------------

## Three pillars

### 1. Colder winter temperatures
Target: winter daily lows around −25 to −30 °C, deeper on storm nights.

Approach (NEEDS B42 API VERIFICATION — temperature is simulated, not a simple
setter):
- Investigate `getClimateManager()` for a temperature-modifier hook. B42 exposes
  read paths (`getTemperature`, `getAirTemperatureForSeason`-style); the question
  is the *write*/offset path. Candidate techniques, in order of preference:
  1. A climate **modifier/override** registered with ClimateManager (cleanest if
     it exists in B42).
  2. Per-tick offset: on `OnClimateTick` (or equivalent), read the simulated
     temp and, during winter months, subtract a seasonal delta clamped to the
     target floor. Risk: fighting the simulation each tick; needs care so it
     doesn't oscillate or break thermoregulation.
- Seasonal shaping: only bite hard Dec–Feb; shoulder months (Nov/Mar) get a
  milder offset so the transition feels natural.
- Must verify the player's **body-temperature / hypothermia** system reads the
  modified ambient temp (so warm clothing, fires, and being indoors all still
  matter — the difficulty should come from real cold, not a fake stat).

### 2. More frequent blizzards / winter storms
- Increase winter storm frequency + duration. Verify the B42 weather driver
  (WeatherPeriod / ClimateManager weather stages) and whether storm odds are
  config-exposed or need a nudge via the weather event hook.
- Blizzards should stack with the temperature floor (colder + reduced visibility
  + wind chill) for the signature "don't go out today" days.

### 3. Generator cold-failure + restart  (the prep incentive)
Rule: a generator **exposed to very low temperature** has a small daily chance to
fail (stall) and require a **manual restart**. Sheltered/indoor generators are
safe — this is what rewards building it a shelter.

- Periodic check (e.g. `EveryHours`) over active generators: read the ambient
  temperature at the generator's square; if below a threshold (e.g. < −20 °C)
  roll a small failure chance scaled by how cold it is.
- On failure: `IsoGenerator:setActivated(false)` + stamp modData
  `KH_coldStalled = true` + a notification ("The generator sputtered out in the
  cold."). Player re-activates as normal to restart.
- "Exposed" test: generator is outdoors OR in an unheated/open structure. Use the
  square's room/indoor flag — verify how PZ classifies an attached garage.

**Generator-in-garage / CO note (Kierstal's question):** vanilla CO poisoning
triggers when the generator is *inside* and you're in the connected interior. An
attached garage the game treats as part of the building's interior generally
still gasses you unless it's sealed as its own room. The cold-failure check uses
the same indoor/outdoor classification — so the safe play is a *dedicated,
enclosed but separately-roomed* generator shed: sheltered from cold, not sharing
your air. Confirm the exact room-adjacency rule during implementation.

--------------------------------------------------------------------------------

## Sandbox options (proposed, KHCold namespace)
- `KHCold.Enable`            (default OFF — opt-in layer)
- `KHCold.WinterLowC`        (target low, default −28)
- `KHCold.StormFrequency`    (multiplier, default ~1.8×)
- `KHCold.GeneratorColdFail` (default ON when KHCold.Enable)
- `KHCold.GenFailTempC`      (threshold, default −20)
- `KHCold.GenFailChance`     (per-check %, small)

## Interactions
- **`KH_ColdStorage`**: harder winters = longer/colder natural-refrigeration
  windows. Verify ColdStorage reads the same (modified) ambient temp so the buff
  scales with the new cold.
- **`KH_ClimateColors`** (server/Climate): independent (dawn/dusk tint); no
  conflict expected, but check both don't both hook the same climate tick.
- **Pluvio trait** (`KH_Pluvio`): rain-stress trait — blizzards may want to count
  as "bad weather" for it; decide during build.

## API items to verify before coding
1. The B42 **temperature write/offset** path on ClimateManager (the crux).
2. Winter **storm frequency** config/hook.
3. **Generator** API: enumerate active generators, read ambient temp at a square,
   setActivated, and the indoor/garage room classification.
4. That **hypothermia/body-temp** reads the modified ambient (so difficulty is real).

## Open decisions
- Exact winter low (−28 default; tune in playtest).
- Should blizzards force a visibility/mobility penalty beyond vanilla, or just
  cold + storm frequency for v1?
- Generator failure: flat daily chance, or rises the longer it stays exposed?
