# Procedural Notes - Design Sketch

**Goal in Kierstal's words:** *"Scanning all containers in the property for clues to relationships. If the house she spawns in has two bedrooms (indicated by the number of wardrobes) then she's alone in a house currently that someone else live(s/ed) in - are there additional clues about who that person might be? Could a photo of a child in a drawer indicate that she is the child and the other occupant was a parent? That sort of thing."*

The character (Wilda Quick) walks into a house. She doesn't know who lived there. But the place is full of evidence - clothing, photos, books, dishes left out. The player reads those clues and INTERPRETS. The mod doesn't tell her who lived there. It surfaces the evidence and offers possible readings.

This is environmental storytelling generated from existing item data. Nobody has to write 500 hand-crafted backstories. The map already has the props - we just notice them and generate flavor from what's there.

## What gets scanned

When triggered, KH iterates every container in every room of the target building (the player's current building, or a building being claimed as Homestead / Safehouse).

### Quantitative observations

- **Bedroom count.** Count of tall wardrobes (sprite `furniture_wardrobe_high_*` or similar). PZ puts one per bedroom by convention.
- **Bed count + size.** Single vs double vs bunk. Helps infer occupancy.
- **Bathroom count.** Toilets + sinks.
- **Kitchen presence.** Stove + fridge.

### Qualitative tags - what's PRESENT

Each detected tag adds a possibility for generated notes.

| Tag | Detected when... | Suggests |
|---|---|---|
| `has_child` | Toys, kids books, baby formula, school items, kids drawings | A child lived here |
| `has_couple` | Mens AND womens clothing in same wardrobe, two toothbrushes | Two adults shared the space |
| `has_elderly` | Medication bottles, cane, large-print book, dentures | Older resident |
| `religious` | Bible, cross, prayer book, rosary | Faith was present |
| `artistic` | Paintings on walls, sculpture, instruments, art supplies | Creative resident |
| `intellectual` | 10+ books on shelves, reading glasses, magnifier | Reader |
| `party_animal` | 5+ bottles, ashtray, beer cans | Social drinker |
| `gun_owner` | Firearm in house at spawn | Armed resident |
| `gardener` | Seeds, gardening tools, plant pots | Grew food |
| `family_photo` | Picture Frame items present | Documented connections |
| `wedding_ring` | Ring item present | Married, possibly |
| `divorce_papers` | Legal documents | Married, complicated |
| `kids_drawing` | Crayon drawing on fridge | Child made art here |
| `medical_supplies` | Lots of bandages, suturing kit, prescription | Medical professional or chronic illness |
| `military_gear` | Tags, dog tags, fatigues, MREs | Military background |
| `recent_meal` | Fresh food on counters, plate out | They were here recently |
| `signs_of_struggle` | Blood pools, broken furniture | Violence happened |
| `preparation` | Stockpile, hazmat, ammo cache | Someone was getting ready |
| `abandoned_a_while` | Spoiled food, dust patterns | Empty for days |
| `well_kept` | Tidy room states, clean clothes folded | Recently maintained |

### Profession clues

Detected from specific items associated with vanilla professions, surfacing the EQUIVALENT character archetype that the previous occupant might have been:

- Doctor bag → medical professional
- Firefighter helmet → first responder
- Police uniform / badge → law enforcement
- Construction hard hat → trades
- Park Ranger gear → outdoor service (interesting if Wilda is also a ranger - colleagues? successor?)
- Chef apron + knives → restaurant worker
- Teacher items → educator
- Lab coat → science / medical

## How notes are generated

For each detected tag, the template database has 2-5 candidate text fragments. KH picks fragments matching the observed tag combination, varies wording with simple substitution, and assembles them into a journal-style first-impression entry.

### Multiple readings per beat

The character doesn't KNOW. So each beat offers possibilities, not assertions.

**Example with `has_child + kids_drawing + wedding_ring`:**

> *"A child once lived here. Their crayon drawing is still on the fridge - three stick figures, a sun. There's a wedding ring on the nightstand. She doesn't remember any of them. Maybe she was the child grown up; maybe she was the parent come home; maybe this isn't her house at all and she just needs a roof. The story she tells herself is up to her."*

**Example with `has_couple + has_elderly + medical_supplies`:**

> *"Two toothbrushes, one with the handle wrapped in cloth like someone with stiff joints had to grip it harder. Medication on the bathroom counter, prescription expired three months back. The clothes in the bigger wardrobe are folded the way her mother folded clothes. She doesn't know if she's projecting."*

**Example with `gun_owner + signs_of_struggle + preparation`:**

> *"Someone here was ready. Stockpile in the closet, ammunition in the bedroom safe, a pistol on the kitchen counter still loaded. There was a struggle - the chair's overturned, blood on the wall. Whoever they were, they weren't ready enough. Or maybe they got out."*

### Voice

First-person narrator referencing Wilda in third (or first if she prefers). Spare, observational, never naming things she couldn't know. Lots of "she doesn't know" / "maybe" / "the story she tells herself."

This style is from literary fiction tradition - the unreliable inhabitant. The world is full of evidence; meaning is the reader's job.

## Trigger and storage (revised 2026-05-29)

### Storage: Sheets of Paper, one per household

Each building gets its own Sheet of Paper item in Wilda's inventory. The Sheet has KH modData identifying which building it's about, the accumulating list of observation beats, and (once concluded) the summary paragraph. Vanilla PZ Sheets of Paper hold roughly ten-to-twenty lines of writing, enough for a handful of beats plus a closing paragraph.

The Sheet is a real, physical item she carries. If she loses it (drops it, dies, fire), the notes are lost - just like real notes.

### Progressive scanning per container

On the first loot of any container in a building, KH checks: does Wilda have a Sheet of Paper for THIS building? If no, spawn one (assumes Wilda has a Pencil or Pen in inventory - we add both to the starter kit). If yes, scan the container for tag matches and append a new beat if anything notable surfaces.

Each beat is a single line, written in field-journal voice. Examples:

- *"Bathroom: two toothbrushes. Hers is dry. The other one isn't his color."*
- *"Kitchen: fresh bread on the counter. Days old, not weeks. Someone was eating recently."*
- *"Bedroom: tall wardrobe, single bed, mens' clothing only. He lived here alone, or she folded everything before she left."*

Beats are NOT the same as the input tag - the tag system identifies "what's there." The beat is the SENTENCE Wilda writes. Multiple readings can be embedded ("...or she folded everything before she left.").

### Summary trigger - type-based, not percentage (revised 2026-05-29)

Percentage-of-containers is the wrong gauge because building container density varies hugely (small apartment vs farmhouse with three sheds). Better gauge: how many DIFFERENT TYPES of containers Wilda has looted in this building. Each type provides a different information domain (food / clothing / hygiene / interests / health), so five distinct types covers most of what can be inferred.

Container types tracked:

```
Fridge / Freezer
Tall Dresser / Wardrobe
Short Dresser
Kitchen Counter
Kitchen Cabinet / Cupboard
Bathroom Counter / Sink
Medicine Cabinet
Tool Shelf / Workbench
Bookshelf
Washing Machine / Dryer
Cardboard Box
Closet
Desk
Crate
Safe
```

Trigger conditions (any one of three fires first, locks the Sheet, appends summary):

1. **Five distinct container types looted in this building.** Primary trigger. Most houses have enough variety that this fires naturally during normal scavenging without forcing the player to grind every container.
2. **Right-click the Sheet → "Conclude notes."** Manual trigger. For when she's done with the building but the type-count hasn't tripped, or a container is bugged and she can't reach it.
3. **24 in-game hours have passed since the last beat was added to this Sheet.** Time-based catch-all - she's clearly moved on. Sheet auto-concludes whether or not she remembers to manually close it.

Once locked, the Sheet adds no more beats and gains its summary paragraph. The summary interprets the accumulated beats and (if criteria are met) adds a fate-signal contribution to the global ChildLore registry (see below).

### Fourth-wall posture

The Sheets are explicitly the player's reference, not strict in-character writing. Wilda is the narrator but the voice acknowledges the player's act of interpretation. Sentences like *"she doesn't know if she's projecting"* are honest - the player IS projecting, and the notes lean into that.

This is permission to write at literary density. Beats and summaries can be evocative rather than just observational. Not lecture - she's never explaining the world to the player - but the prose can reach.

## ChildLore - the ongoing mystery (expanded 2026-05-29)

PZ ships a world where children clearly existed (toys, drawings, cribs in some maps, kids' bedrooms) but children themselves never APPEAR. No child NPCs, no child zombies. This is a structural silence in the game's fiction, and KH turns it into an ongoing mystery that builds across the campaign.

### How it works at the building level

When a Sheet concludes for a building with strong child-evidence tags, KH evaluates ONE additional aggregate tag: a **fate signal** that suggests what happened to the children of THIS specific house. The fate signal is derived from the combination of other tags surfaced during the scan. Possible signals:

| Signal | Tag combination that triggers it | What the summary suggests |
|---|---|---|
| `evac_military` | child_evidence + military_gear + neat_departure + locked_doors | They were taken by people in uniform, recently, in a hurry but organized |
| `predation` | child_evidence + signs_of_struggle + blood + disturbed_kid_items | Something violent happened here. The summary doesn't have to name it |
| `self_rescue` | child_evidence + missing_kid_shoes_or_coats + back_door_open + parents_things_still_present | They left on their own. Maybe with help, maybe scared |
| `parental_flight` | child_evidence + whole_house_empty + vehicle_zone_empty + no_signs_of_struggle | The family left together. The car is gone too |
| `religious_gathering` | child_evidence + religious_materials + abandoned_mid_meal + mass_neighborhood_empty | Whatever called them, the whole neighborhood went |
| `agency_recovery` | child_evidence + rare_lore_item (gold envelope, evacuation code, unknown organization papers) | An organization moved them. Wilda has never heard of it |
| `unclear` | child_evidence + insufficient other tags | The evidence stops at "they were here, they aren't." No story to tell |

### How it works at the campaign level (revised 2026-05-29)

No aggregate registry. Each Sheet is a complete document in itself - the building's evidence, the fate signal it suggests, the closing summary. The player connects dots across buildings by reading their Sheets, not by KH showing them a tally.

This puts the campaign-level reading entirely on the player. If she finds three houses with `evac_military` signals over a month of play, she'll notice because she's the one reading the Sheets. KH doesn't underline the pattern. She gets to discover it herself or miss it entirely.

### How the mystery stays open

- **Tag distribution is random.** Different campaigns surface different signals at different frequencies.
- **No signal will EVER be definitive.** Even strong patterns are interpretable. "Three military evacuations" could mean the army systematically extracted children, OR that three families happened to include reservists who showed up to help, OR something else entirely.
- **Existing items become lore-bearers via KH_LoreContext.** Rather than adding new KH items for the mystery (gold envelopes, agency codes, etc.), KH adds CONTEXT to existing items already in PZ and other mods. A vanilla TornLetter found in a child's bedroom can surface a one-line beat. A specific photo frame, a specific document type, a specific medication bottle - any of these can become evidence when found in the right context. The item database for KH_LoreContext can grow over time without inventory bloat.
- **Restrained beats.** Each summary makes its observation and stops. Never speculates beyond what the items in THIS building suggest. The campaign-level reading is the player's job.
- **Voice never assumes the player's actions.** The summary describes what the world contains, not what Wilda did or didn't do with that information. "Two small beds, both slept in" - fine. "She found the beds and stopped looking" - assumes she stopped, which she may not have.

### Voice for fate-signal summaries (revised - observation only, no player assumptions)

The summary line in each child-evidence Sheet describes what's observable, never what Wilda has done or will do with the information:

- *Military evac:* "Folded clothes in a duffel by the door. The duffel is empty. Whoever took the children took the bag with them."
- *Predation:* "Two small beds. Both had been slept in recently. Neither was made up after."
- *Self-rescue:* "Back door open. The shoes by it are kid-sized and gone. There's a thermos missing from the kitchen too."
- *Parental flight:* "The driveway shows where a vehicle sat. It isn't sitting there now. The house is set up for a return."
- *Agency recovery:* "A torn letter in the desk drawer mentions an organization Wilda doesn't recognize. The reference is offhand. Whoever wrote it didn't need to explain."
- *Unclear:* "There were children here once. There aren't now. Knox County doesn't talk about that."

The last line is the "default" when the evidence runs out. It's also the most striking, so it's reserved for the cases where there genuinely isn't anything to say.

### Living NPCs change the design (added 2026-05-29)

In BWO VOriginal days 0-7, many homes are still occupied by LIVING NPCs. The parents of these missing children are right there, alive, dealing with the loss in real time. Wilda doesn't walk into an abandoned home and speculate - she walks in and meets the mother or father whose children are gone, and the Sheet she writes is informed by that encounter.

This adds a layer the abandoned-building model didn't have: NPC psychology. The same evidence reads differently when an actual parent is in the kitchen. See `NPC_KID_STATUS_DESIGN.md` for the four-state system (Looking / At ease / Paranoid / Suspicious) and how it integrates with this Sheet mechanic.

## Starter-kit additions

Wilda needs writing materials at spawn for the recording mechanic. KH_StarterKits parkranger entry is being extended to add:

- **Sheet of Paper** - the first Sheet, used for the spawn-building's impressions
- **Pencil** - vanilla writing tool, alongside the Pen already in kit

She can collect more Sheets later from looting (offices, schools, homes). The Pencil and starting Sheet just guarantee Day 0 works.

## Resolved decisions (2026-05-29)

- Trigger by container-type count, not percentage. Five distinct types fires the summary.
- Sheet visibility: quiet, no notification on beat add.
- Leaving the building: stay open indefinitely. RAM cost is negligible.
- ChildLore is an ongoing campaign-level mystery with fate signals per building feeding a registry.

## Open questions for Kierstal (current)

1. **What tags are MISSING from the lists above** that you'd want detected? The current set is a strong starting point but you know your scavenging patterns - what would you notice while looting that the system should also notice?
2. **ChildLore aggregate view.** Read it via a notebook page ("ChildLore") or via a dedicated item Wilda carries ("Wilda's Notes on the Missing")? Dedicated item feels like she's specifically pursuing the question; notebook page makes it more incidental.
3. **Agency recovery items.** Want me to draft specific lore items (a gold envelope, an evacuation code on torn paper, an unmarked letter referencing "the program") as new KH items? These would be rare loot drops that, when found, become the tantalizing-thread evidence for the agency_recovery signal. Or stay with abstract "rare papers found" without naming-via-items?
4. **Predation summary tone.** "She found their beds and stopped looking" is direct but spare. Want to dial it lighter ("She left without searching the smaller rooms") or even more direct? You said tags can go dark; calibrating to your read.

## Implementation notes

This wants its own KH module: `client/Home/KH_FirstImpressions.lua`. Probably 200-400 lines. Heaviest piece is the tag detection - iterating containers efficiently and matching items against tag-criteria tables. The template database is just data; the assembly logic is straightforward.

For inspect-furniture detail, we'd hook `OnFillWorldObjectContextMenu` (like KH_PryAction does) and add the option on relevant furniture types.

Possible dependencies: none external. Pure KH module, uses vanilla PZ APIs. Doesn't need SSR or BWO.
