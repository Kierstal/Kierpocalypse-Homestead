# Junk Items — TODO (held back from this implementation pass)

Items from `JUNK_ITEMS_AUDIT.md` that I did NOT implement in this pass.
Each has a one-line reason for holding back. Pick them up when you have
opinions on the design call.

## Implemented this pass

- **Perfume → disinfect bandage** (`KH_DisinfectBandage_Perfume` recipe)
- **Cologne → disinfect bandage** (`KH_DisinfectBandage_Cologne` recipe)
- **Toothbrush + Toothpaste → Brush teeth** Lua action (small bath-need
  reduction + unhappiness relief + thought line)
- **Deodorant (also matches Hairspray / Hairgel by type-name fallback) →
  Apply** Lua action (4 hours of "mask" period suppressing some bath
  thoughts, small unhappiness relief)
- **Board games (chess, checkers, backgammon, game pieces, darts) → Play
  a game** Lua action (boredom -20, unhappiness -8, thought line)

## Held back

### Razor → shave + harvest blade
**Reason:** spirit-of-mod call. A "shave at mirror" action is good but
needs a "facial hair" model state that B42 doesn't expose via Lua that
I could find. Harvesting the razor blade into a crafting input (cutting
tool? small-blade weapon piece?) is plausible but you might prefer to
keep razors as a smeltable iron-source (`base:hasmetal`, vanilla). Your
call on whether to add a use beyond smelt.

### Comb → hair grooming
**Reason:** same blocker as Razor (no exposed hair-state). Could be a
small unhappiness tick with a flavor line, but it would feel cosmetic
without visible effect. Spirit says skip unless we add a proper
"appearance" mood track.

### CocktailUmbrella / CocktailBitters → cocktail recipes
**Reason:** vanilla B42 doesn't have a "cocktail" item to be an output
of. Could add a `KH:Cocktail` item (small unhappiness + small stress
relief + small drunkenness) but that's a fresh item more than a junk
repurpose. Worth doing IF you want to expand the bar/social side; not
the priority right now.

### Frame (empty picture frame) → place sentimental object
**Reason:** could become a placeable furniture object showing a photo
from another item (a memento system). That's an architectural addition,
not a junk fix. Held for separate scoping.

### HolePuncher → bind notebook / improvised weapon
**Reason:** clean uses are "punch hole in cardboard to bind a journal"
(needs a journal system) or "use as light bludgeon" (weapon stats need
to be defined). Either is doable but neither is one-liner. Hold for
design.

### Book_Prop / BookFancy_Prop (decorative books) → paper salvage
**Reason:** could be inputs to a "tear book for blank pages" recipe.
PZ has the `Tear Book` action for real books already. Adding the props
to the same recipe is straightforward. **Quick win — consider next pass.**

### Sport balls (Baseball, Basketball, Football, GolfBall, GolfTee,
PoolBall, SoccerBall, TennisBall, Birdie, Dart)
**Reason:** Dart is already covered in `KH_PlayGame.lua` as a solo game.
The rest could be "throwable junk" weapons (low damage, distract zombie
horde) — fun spirit-of-mod but requires throwable-action infrastructure
that doesn't exist yet. Hold for a "throwables" pass.

### Bellows, Funnel
**Reason:** these are flagged false-positive in the audit — most likely
vanilla forge-fire / fluid-pour functional via tag we missed. Verify
in-game before repurposing. Don't want to fight vanilla over them.

### DryFirestarterBlock → firestarter recipe
**Reason:** literally a one-line fix — add to the existing firestarting
recipe's accepted-input list. **Quick win for next pass.**

### MeasuringTape → "measure space" build-planning aid
**Reason:** could grant a "blueprint" tooltip on bare squares showing
build options. Cool but UI-heavy.

### Pipe → plumbing repair (toilet/bath system tie-in)
**Reason:** would pair beautifully with the toilet/bath features —
"repair plumbing" recipe to restore a sink/toilet after water shutoff.
Held because it depends on tile-state APIs I haven't fully verified.
**Strong candidate for next pass — flagged as the most promising
held-back item.**

### DryerLint → tinder
**Reason:** real-life flammable. Adding `base:isfiretinder` to its tag
list is a one-line item override. **Quick win for next pass.**

### CameraFilm + Camera → photo / memento
**Reason:** requires building a photo / memento system (capture a
moment, item stores it, can be displayed in a Frame). Big design
swing — definitely scope on its own.

### String, ClayJarGlazed
**Reason:** both are likely vanilla oversights (no recipes use them).
String could be merged into Twine recipe inputs (one-liner). ClayJar
items need pottery-system attention.

### Pipe, ScannerModule, RubberHose
**Reason:** held — see Pipe above. ScannerModule wants a radio rewrite.
RubberHose is probably already functional for siphoning (audit
false-positive).

## Quick-win candidates for next pass (ordered by ROI)

1. **DryerLint → firetinder tag** (one-line item override)
2. **DryFirestarterBlock → firestarting recipe input** (one-line recipe)
3. **String → Twine recipe input substitute** (one-line recipe)
4. **Book_Prop / BookFancy_Prop → paper salvage recipe** (small recipe)
5. **Pipe → plumbing repair recipe** (medium, but pairs with bath/toilet)
