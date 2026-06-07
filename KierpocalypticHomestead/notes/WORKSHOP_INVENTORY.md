# Workshop Subscription Inventory

**Pass date:** 2026-05-27
**Source:** `C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\`
**Subscriptions:** 14 mods

## Full list

| Workshop ID | Mod name | mod.info id | Detected in KH_ModCompat? |
|---|---|---|---|
| 2896041179 | errorMagnifier | `errorMagnifier` | no — debug utility, no integration needed |
| 2966610350 | The Sims Zomboid | `The Sims Zomboid` | yes (`simsmap` flag) |
| 3040033876 | SimsMenuAndLogo | `SimsMenuAndLogo` | yes (`simsmenu` flag) |
| 3077900375 | Mod Update and Alert System | `ChuckleberryFinnAlertSystem` | no — generic utility |
| 3268487204 | Bandits | `Bandits2` | yes (`bandits` flag) |
| 3403180543 | Bandits Week One | `BanditsWeekOne` | yes (`banditsweekone` flag) |
| 3403870858 | Lifestyle: Hobbies | `LifestyleHobbies` | yes (`lifestyle` flag) |
| 3409143790 | Sapph's Cooking | `SapphCooking_B42` | yes (`saph` flag) |
| 3535295548 | UNOFFICIAL Fools New Containers B42 | `foolcontainers42` | yes (`foolcontainers` flag) |
| 3618557184 | Here Goes the Sun | `HereGoesTheSun` | yes (`heregoesthesun` flag) |
| 3640592525 | Pawject Meowboid | `KITTYOWO` | yes (`meowboid` flag) |
| 3640602763 | Animal Essentials | `Animal_Essentials` | yes (`animalessentials` flag) |
| 3656507478 | Cyber Doggie Mod - Animal Template | `CYBERDOGTEMPLATE` | yes (`cyberdog` flag) |
| 3687609677 | Sims Plumbob | `simsPlumbob` | yes (`simsplumbob` flag) |

**Every single subscribed mod that KH could conceivably integrate with
is already tracked in `KH_ModCompat.lua`.** The only un-tracked subs
are the two pure-utility ones (`errorMagnifier`, the alert system) and
those don't need integration.

## Clusters by intent

### Sims crossover (3 mods)
- The Sims Zomboid — Sims map / theme overlay
- SimsMenuAndLogo — Sims-style title screen
- Sims Plumbob — animated mood indicator over the player's head

The Sims trio means **she likes Sims-flavored apocalypse** — soft
aesthetic over the dark survival mechanics. Tonal anchor: domestic,
character-driven, your house matters, your feelings matter, the music
should be cute.

### Animal expansion (3 mods + her own Pet system)
- Animal Essentials — framework for animal behaviors
- Pawject Meowboid — cats specifically
- Cyber Doggie Animal Template — generic animal modding scaffold

She's already declared (in the `kh-pets-ae-sibling` decision) that KH
Pets will become a plugin on Animal Essentials' framework, parallel to
Meowboid. Cats = Meowboid's domain; everything else = KH-on-AE. **Pet
gameplay is central to her vision.**

### Survival realism / domestic depth (3 mods)
- Lifestyle: Hobbies — hobby tracking, mood, hygiene/toilet (overlaps
  KH's needs system; KH defers via compat toggles)
- Sapph's Cooking — expanded cooking recipes (overlaps
  `KH_uncraftable_recipes.txt`; defer via compat)
- UNOFFICIAL Fools New Containers — more storage options

She wants the moment-to-moment domestic life to have texture. Not
combat optimization — what's for dinner, can I keep the milk cold,
does this room feel like home.

### Atmosphere (1 mod)
- Here Goes the Sun — seasonal sunrise/sunset color overlays

She wants the world to feel alive even when nothing is happening.
KH_ClimateColors defers to HGTS when present (already wired).

### NPCs as ambient pressure (2 mods)
- Bandits (Bandits2) — full NPC framework, B42-compatible
- Bandits Week One — Week-one extension: civilians, military, services,
  disaster events

She has both subscribed but **explicitly complained the defaults are
too chaotic** — pivoted to "tame them" not "remove them." She wants
NPCs as backdrop, not the foreground game. See `BANDITS_TAMING.md`.

### Utility (2 mods)
- errorMagnifier — in-game error popups (debug-only, would turn off in a
  shipped playthrough but useful while iterating)
- Mod Update and Alert System — notifies when modders push updates

## Style profile

**Kierstal's overhaul style appears to favor:**

1. **Domestic over combat.** The center of gravity is "my homestead,
   my pets, my routine." Combat is a thing that interrupts the real
   game (cooking, decorating, animal care, foraging), not the point.

2. **Soft aesthetic over hardcore survival.** Sims-themed trio + HGTS
   atmospheric overlay + Cyber Doggie animal template. She accepts
   PZ's darkness but wants the moment-to-moment look-and-feel kinder.

3. **Animals as more than livestock or food.** Three different animal
   mods subscribed, plus the entire KH Pet system, plus the
   `KH_ADOPTABLE_WILD` table. Animals are companions, atmosphere,
   relational depth. Not utility objects.

4. **Texture over difficulty.** Lifestyle: Hobbies for hobby variety,
   Sapph's Cooking for recipe depth, Fools Containers for storage
   nuance. None of these make the game harder; they make the survival
   loop have more **shape**.

5. **NPCs as worldbuilding, not gameplay challenge.** The Bandits +
   Week One subscriptions are about there being other humans alive in
   her world — but at conservative populations and without constant
   raid pressure. The fact that she keeps them subscribed despite the
   chaos says: she wants the *presence*, not the *combat*.

6. **Compatibility-first integration.** Every detected mod has a
   "defer to mod" toggle defaulted to TRUE in `KH_ModCompat`. KH steps
   aside rather than competing. Same pattern continues with the new
   Bandits taming (KH adjusts the third-party mod's values rather than
   replacing it).

## Implications for future KH passes

- **Don't add features that overlap subscribed mods.** Sapph for
  cooking, Lifestyle Hobbies for hygiene/toilet, etc. Build COMPAT
  layers when overlap is unavoidable, with defer-toggles defaulting
  TRUE.
- **Lean into the homestead / atmosphere side.** Things like
  `KH_FreshnessTooltip`, `KH_ColdStorage`, `KH_HomeTerritory`,
  `KH_FilthMoodlet`, `KH_BathNeed` are bullseye for her style. Combat
  / weapon mods are not.
- **Pet system is core.** Anything that touches animal interaction or
  pet behavior is high-value direction.
- **NPC integration should be quiet.** Background presence, occasional
  encounter, no waves. Already baked into the bandit taming defaults.
