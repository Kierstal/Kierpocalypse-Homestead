# Halo Text + BWO Events - Design Sketch

**Goal in Kierstal's words:** *"The halo text we use for flavor in KH could also trigger on BWO events. We should check our current flavor to fit BWO's VOriginal storyline."*

Two pieces here. First, integrate KH's halo dispatcher with BWO's scheduled event triggers so the character reacts to world events in flavor. Second, audit KH's existing thought lines against VOriginal's specific storyline (which is "the beginning of the outbreak in a town still partially functional") to make sure nothing assumes "everything is already over" when in fact day 0-7 is more "something is wrong but life still tries to continue."

## What VOriginal's schedule provides as trigger points

From `Variants/VOriginal.lua`, the scheduled BWOEvents:

| Day | Hour | Event | What it is in-fiction |
|---|---|---|---|
| 0 | 0 | Start + BuildingHome + StartDay(friday) | She arrives. Home is registered. Friday morning. |
| 2 | 22 | SpawnGroup Army Patrol (d=30) | Army convoy passes through, evening |
| 4 | 15 | Entertainer | Someone performs in the street, mid-afternoon |
| 5 | 44 | SpawnGroup Army Patrol | More army movement |
| 8 | 5 | Arson by Fire Officer profession | Pre-dawn fire |
| 11 | 12 | BuildingParty in bedroom | A party at midday in a nearby house |
| 12 | 30 | BuildingParty | Another party |
| 13 | 5, 25 | BuildingParty x2 | Two parties same day |
| 15 | 5, 25 | BuildingParty x2 | More parties |
| 16+ | (continues) | More patrols, parties, eventually parties get sparser | |

Reading this as a narrative: days 0-4 the world is normal but tense. Day 5+ army presence increases. Day 8 fire (arson, set by fire personnel - desperate or intentional). Days 11-15 are when parties INCREASE in frequency - end-of-the-world celebrations? Last-night-on-earth dances? That's a striking creative choice by BWO. After that, escalation toward whatever's coming.

## Integration design

KH's existing halo dispatcher (`KH_Thoughts.lua` per the implementation log) fires lines from `KH_ThoughtLines.lua` based on triggers in `KH_ThoughtTriggers.lua`. To add BWO event reactions, we need:

1. A way to detect when a BWO event has fired near the player
2. A thought-line category for "BWO event reaction" with day/phase-aware variants
3. The trigger registration

### Detection: hooking BWO events

BWO doesn't expose a "this event just fired" callback directly. Two paths:

**Path A: Wrap the event functions.** At OnGameStart, monkey-patch `BWOEvents.Arson`, `BWOEvents.BuildingParty`, `BWOEvents.SpawnGroup`, etc. so each call ALSO fires a KH callback before delegating to the original.

**Path B: Detect side effects.** Watch for the visible markers - a BuildingParty leaves a party building modData, an Arson creates a fire, an Army SpawnGroup adds Army-clan bandits nearby. Periodically scan for these markers and react when one appears.

Path A is cleaner (deterministic, no missed events) but couples us to BWO's function names. Path B is more resilient to BWO changes but noisier and harder to time correctly. **Recommendation: Path A** with pcall safety nets.

### Thought-line categories to add to KH_ThoughtLines

| Trigger | Phase variants | Example lines |
|---|---|---|
| BWO ArmyPatrol detected | day 1-5 (curiosity), day 6-10 (unease), day 11+ (dread) | Early: "Why are there soldiers? Did something happen?" Late: "Another patrol. They aren't slowing down anymore." |
| BWO Entertainer detected | day 1-7 (charming), day 8+ (unsettling) | Early: "Someone's playing music in the street. The world hasn't ended yet." Late: "Music in the middle of all this. She doesn't know whether to feel grateful or afraid." |
| BWO Arson detected (nearby fire) | always serious | "Smoke. The wind brings it from the south. Someone is burning something they shouldn't." |
| BWO BuildingParty detected | day 11+ specifically | "A party. At this hour, on this day. They know it's ending, don't they?" |
| BWO Helicopter/Chopper events | always | "Choppers. She hears them before she sees them, and then she doesn't see them at all." |
| First Bandit encounter | always | "He's armed and he's not military. The world breaks faster than she thought." |

The `phase` parameter is computed from the in-game day count. Early phase is the days where life still feels close to normal. Late phase is after the apocalypse has clearly settled in.

### Existing KH thought lines to audit

The implementation log lists current categories:

```
time milestones, elec/water off, weather, season, moodle-rising,
animal-encounter, first-zombie events, location-aware, alone/memory,
trait-ambient, profession-ambient, filth, dirtiness, bath, toilet,
filthSleep, hygiene, game, hungry/parched/tired/exhausted/dropping/
bored/veryBored
```

Audit lens for VOriginal fit: do any lines assume the world is ALREADY POST-APOCALYPSE in a way that breaks for day 0-4? Examples of phrasings that would feel off:

- "She hasn't seen another person in weeks." (Day 0 has BWO NPCs around, this would be wrong)
- "The world ended X days ago and..." (assumes a definitive "it ended" event)
- "Nobody's coming." (army patrols ARE coming, on schedule)

What FITS VOriginal:

- "Something is wrong."
- "The radio isn't saying what they're not saying."
- "She thought it would feel more like a war movie."
- "The town doesn't look any different. That's the worst part."

These work across phases because they describe a creeping uncertainty rather than a confirmed apocalypse.

**Audit action item:** read `shared/Thoughts/KH_ThoughtLines.lua` and flag any line that assumes post-apocalypse certainty when the variant places her in day 0-7. Replace with phase-aware variants where the line lands differently at different days. Kierstal's voice review matters most here - the lines should sound like HER inner monologue, not generic survival flavor.

## Implementation order

1. **Read KH_ThoughtLines and surface lines that need audit.** Document which ones feel pre-apocalypse-flavored and shouldn't fire in VOriginal early days.
2. **Add the phase computation helper** to KH_Thoughts (`KH.getStoryPhase()` returns "early" / "mid" / "late" based on day count and active variant).
3. **Wrap the BWO event functions** with KH-side dispatch so reactions can fire on Arson / BuildingParty / Entertainer / Army patrols.
4. **Add new categories to KH_ThoughtLines** with phase variants for BWO reactions.
5. **Register triggers** so the new category fires when the corresponding event wrap is invoked.

## Open questions for Kierstal

1. **Voice review.** Want to walk through the existing KH thought lines together and flag any that don't fit, OR have me do a first-pass audit and then you review just the flagged ones?
2. **Phase boundaries.** Day 0-4 = early, 5-10 = mid, 11+ = late (recommendation). Adjust?
3. **Reaction frequency.** When BWO fires an event nearby, should the halo react EVERY time, or with a per-event cooldown so she doesn't comment on every patrol? Recommendation: once per event-type per in-game day max.
4. **Lines about specific BWO NPC types.** Bandits, army patrols, entertainers, party-goers - want unique reactions per type, or treat as a generic "people are out there doing things" category?
