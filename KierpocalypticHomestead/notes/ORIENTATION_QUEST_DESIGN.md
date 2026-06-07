# KH Orientation Quest - Design Sketch

**Goal in Kierstal's words:** *"An orientation tutorial that's less 'teaches you how to do things in the world' and more 'remind me of the things I can do now that I can't in vanilla'."*

Not a how-to-walk tutorial. A refresh of capabilities her mod stack adds that vanilla doesn't have. The player character knows how to play PZ - she needs to remember what's new in THIS world.

## Format

SSR Quest System via DialoguePanel. A series of short dialogue cards (one beat each) that the player clicks through. Skippable, dismissable, can be re-triggered.

**Voice (recommendation):** her own internal monologue / field journal entries. Park Ranger keeps notes, has a notebook (we just added one to the starter kit). The orientation reads as her flipping through her own notes on Day 1 of the outbreak, reminding herself what's possible.

> *"Page one. Things I keep forgetting I can do now."*

Each card is a single capability framed as a self-reminder. Short. Not didactic. The player character isn't being lectured by a tutorial NPC, she's reading her own handwriting.

Alternative voices to consider:
- A letter from a sister / friend / mentor character ("Wilda - just in case you forget the basics, here's what we figured out...")
- A radio broadcast playing over and over
- A pamphlet she found

Field-journal voice fits her best because it leverages the notebook we already gave her, matches her Inventive/Crafty/Comic-Nerd-Fast-Reader profile.

## Trigger

Right-click the Notebook in inventory → "Review notes." Always available, on demand, no auto-popup at game start. The notebook is also the home for several other reference pages besides the orientation reminders (see Multi-section notebook below).

## Reminder list (draft content, grouped)

Each line is one dialogue card. Player clicks "Next" to advance. Each card is ~one sentence. Tone: terse self-reminder, not paragraph.

### Combat / Defense
- "The crowbar pries doors and windows. Skip the brute force."
- "Vending machines can be forced open with a crowbar or blunt weapon. Costs noise."
- "Zombies running on rain can trip. Two-and-a-half-times in rain. Use it."

### Homestead / Territory
- "Right-click inside any building to claim it as Homestead or Waystation."
- "Homestead: pets live here, need-dampening, therapy bonus. One primary."
- "Waystation: workshop. Multiple allowed. Craft XP boost."
- "Send pet to Homestead from anywhere via right-click on the pet."
- "Filth at home hits HARDER if you have the High Maintenance trait. Keep it clean."

### Food / Cooking
- "Cold storage works in containers if the tile has no power AND the ambient is cold enough."
- "Tooltips show freshness as a colored bar. Use what's about to spoil first."
- "Forage trait gives bonus rolls AND happiness from fresh forage food."
- "Cooking + Farming + Forage matter more here than vanilla. Overgrow on purpose."

### Animals / Pets
- "Right-click any pickupable wild animal: 'Adopt as Pet'. Mouse, rat, raccoon, rabbit."
- "Pets within 20 tiles give Therapy bonus."
- "Fighter species (dog, bull, pig, etc.) engage zombies within 8 tiles automatically."
- "Feed pets from cat/dog/pet food bags. Water bowl auto-fills."
- "Cat's Eyes trait + Therapy Animals trait - she works with animals."

### NPCs (BWO + KH commands)
- "Right-click any Bandit NPC for KH command submenu: Stay Here, Follow Me, Guard, Come With, Stand Down."
- "Talk to NPCs via the BWO chat panel. Keyword matching, not menu."
- "Park Ranger earns $25 for foraging junk. Wander, pick things up, get paid."
- "Refueling vehicles costs money. Carry enough."

### Hygiene / Needs
- "Brush teeth + apply deodorant masks bath need for 4 hours."
- "Sleeping in filth = stress hit on wake. Make the bed area clean before bed."

### Items / Gear
- "Tailoring: ripping clothes gives XP now. Cotton/denim/leather all count."
- "Repair clothing: +3 XP per patch. Remove patch: +1 XP."
- "Fanny packs hold five items, not one. Use them."
- "Wallets carry Money. Items can be deposited in them properly."

### World / Atmosphere
- "Climate colors are tuned: longer dawn/dusk feel, washed-out winter, warm fall."
- "Pluviophile: rain reduces stress, increases happiness. Stand in it."
- "Comic Nerd: comics give double boredom/unhappiness relief."

### Caffeine / Reading
- "Caffeine Dependent: coffee is mood, withdrawal is stress. Stock up."
- "Fast Reader: books are quicker. Per-page XP - even partial reads count."
- "Media XP capped per session. Radio grinds won't farm forever."

## Multi-section notebook

The orientation isn't the only thing the notebook holds. It's the central player-facing reference UI. Sections:

1. **Page 1: Things I keep forgetting I can do now.** The orientation reminders (this doc's main content).
2. **Page 2: Things to say to people.** The BWO chat keyword reference - what keywords NPCs respond to with unique answers. Extracted from BWO's chat data table (~hundreds of entries) and presented as a browsable list grouped by category (greetings, questions about the world, requests, emotional reactions). See `BWO_CHAT_KEYWORDS.md`.
3. **Page 3: First impressions.** Procedural notes generated at spawn from environmental scan - inferred relationships and history of the building she spawned in. See `PROCEDURAL_NOTES_DESIGN.md`.
4. **Page 4 (future): Field notes.** Her own observations entered over time. Could integrate with halo text history.
5. **Page 5 (future): The recognized list.** Roster of NPCs she's recruited/befriended/committed to deliver for. Reads from KH_NPCRegistry.

The notebook's right-click context menu offers each section as a sub-option, so she can jump directly to "Page 2: Things to say to people" without scrolling through orientation again.

## Length / pacing

Around 30-40 cards if we include the full draft above. That's maybe 2-3 minutes of clicking. Could be split into chapters:

- *Chapter 1: Survival fundamentals* (combat, hygiene, food)
- *Chapter 2: Home and territory* (homestead, pets, hostile/friendly NPCs)
- *Chapter 3: Her character specifically* (her traits, profession, what's tuned for her)

Player can quit between chapters. Or skip ahead. The notebook stays as a re-entry point.

## Implementation in SSR Quest System

SSR has a dialogue scripting language with conditional rendering and stat references. The orientation isn't a "quest" with objectives in the traditional sense - it's a one-way dialogue with no NPC. We use the DialoguePanel directly without a NPC speaker (player-as-narrator).

Each card is a dialogue node with:
- Text body (the reminder)
- A "Next" action button → advances to the next node
- An optional "Skip Chapter" → jumps to the next chapter
- An optional "Close" → exits the panel

Reading SSR's CommandList_a.lua more carefully will tell us the exact syntax. A first-pass implementation could be a single long dialogue file with all cards chained linearly.

## Open questions for Kierstal

1. **Voice preference:** field-journal self-reminders (recommendation) for the orientation page. Notes from other people (randomized) for the First Impressions page per her later note - those would be sister/friend/parent voices interpreted from environmental clues.
2. **Chapter structure:** three chapters with skip-ahead (recommendation), one flat list, or per-category individually selectable?
3. **Content depth:** the draft above is comprehensive. Want to trim to essentials only, expand with more flavor, or keep as drafted?
4. **What's MISSING:** what capabilities do you find yourself forgetting that should be added to this list?
