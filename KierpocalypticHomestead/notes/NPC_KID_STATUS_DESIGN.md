# NPC Kid-Status System - Design Sketch

**Premise.** BWO VOriginal days 0-7 populate homes with living NPCs. Some of those NPCs are parents whose children are gone. The procedural notes system (`PROCEDURAL_NOTES_DESIGN.md`) detects child-evidence in their homes. The kid-status system gives those NPCs psychological reality - they react to their loss in one of four distinct ways, and Wilda's encounter with them is informed by which way.

**Goal in Kierstal's words (paraphrased).** *"NPCs that live in child-evidence homes should be looking for their kids, at ease because they believed something they were told, paranoid because they didn't believe what they were told, or suspicious because they were personally responsible for something that happened to a kid."*

This is the heavier emotional material in the village layer. Handled with care, it makes Wilda's deliveries to families meaningful in a way that "feeding NPCs" can't be on its own. Handled badly, it's preachy or exploitative. The design has to walk that line.

## The four states

Each NPC living in a child-evidence home gets exactly one kid-status assigned when the home is first scanned by KH (at game start or first claim/visit, whichever comes first). The status doesn't change unless something pushes it - usually Wilda's actions.

### Looking

The parent is actively searching. They believe the children are out there somewhere and could be found. Possibly checking with neighbors, listening to the radio, leaving notes.

**Tag signals that suggest this state:** child_evidence + missing_kid_shoes_or_coats + parents_still_present + notes_or_lists_on_counter + radio_on + recent_meal (they're functioning, focused on the search)

**Behavioral tells when Wilda walks in:**
- Greets her urgently: *"Hey - hey, have you seen anyone out there? A girl, six, blonde, blue jacket?"*
- Hands her a written note with description: *"If you see her, tell her I'm home. Please."*
- May ask follow-up: *"You came from the south road? Anyone there?"*

**Dialogue keywords (additions to BWOChat):**
- "seen child" / "seen kid" / "seen daughter" / "seen son" → They describe their missing child.
- "i'll look" / "i will look" / "keep eye open" → They thank her, give her better detail.
- Other keywords (food, weather, time) → They answer briefly but distractedly.

**Quest hook (light):** Optional SSR quest - "Find Sara, six, blonde, blue jacket." Wilda doesn't have to take it. If she does, completing it (finding a relevant clue elsewhere - matching jacket on a corpse, a note in a school, etc.) lets her bring the information back. The mod doesn't have to deliver a happy ending. Honest information is the reward.

### At ease

The parent received information from some source - military notice, neighbor reassurance, official letter, religious community - that their children are safe somewhere. They believe it. They are calm. They speak about their children in stable, past-tense-but-not-mournful language.

**Tag signals:** child_evidence + paperwork_present (evacuation notice, letter, government document) + tidy_home + functioning_routine + religious_materials_optional

**Behavioral tells:**
- Greets her normally: *"Hey there. Coffee's on if you want some."*
- References the kids casually: *"My boy's safe with the program. Hard to think about but he's somewhere better than here right now."*
- Doesn't ask Wilda to look for them - they don't think she needs to.

**Dialogue keywords:**
- "kids" / "children" / "where children" → They mention the program / the evacuation / the relatives in St. Louis.
- "what program" → They show her the letter / paperwork they trust.
- "you sure" → They're sure. They don't entertain doubt easily.

**The narrative tension:** the player doesn't know if the parent's information was true. Maybe it was. Maybe it was a lie they were told to keep them calm. Maybe it was meant to be true and went wrong. KH never confirms which - it just lets the parent's calm sit in contrast to whatever else Wilda has seen across other Sheets.

### Paranoid

The parent received the same kind of official information as the at-ease ones, but they didn't believe it. They saw something, heard something, knew something that made the story not add up. They're now operating in a fugue state - convinced everyone is lying, possibly hostile to Wilda by default, possibly looking for someone to confirm their suspicions.

**Tag signals:** child_evidence + paperwork_present (same documents as at-ease) + torn_or_crumpled_documents + boarded_windows + weapon_in_easy_reach + unfinished_meals + insomnia_signs (medication, empty coffee)

**Behavioral tells:**
- Doesn't greet warmly. Watches Wilda enter.
- *"You with them?"* as opener.
- May refuse to talk until Wilda answers the right way: *"You from the government? Military? Anyone official?"*
- Once trust is established (or not), launches: *"They took her. They TOOK her. Their letter says she's safe but I haven't heard from her, I haven't heard from anyone who saw her, and that letter doesn't even have a return address. You'd believe it?"*

**Dialogue keywords:**
- "calm down" / "they're safe" → Aggressive rejection. *"You believe that? You actually believe that?"*
- "I don't trust them either" / "i agree" / "you might be right" → Opens up, may share specific suspicions (numbers don't match, story changed, neighbor confirmed something off)
- "what proof" → They share what they have. Crumpled documents, half-overheard conversations, dates that don't line up.

**The narrative tension:** is the paranoid parent right? Maybe. Maybe not. KH gives them specific consistent grievances but never confirms them. Wilda has to decide what to believe.

### Suspicious / guilty

The hardest state. This parent is responsible - directly or by negligence - for something that happened to their own child. The house's evidence implicates them: specific items in specific places that tell a story they don't want told. Their behavior is the most controlled because they have the most to hide.

**Tag signals (overwhelming required):** child_evidence + signs_of_struggle (specific to child-sized items: tiny bloodstain, broken kid-toy mid-scene) + concealment (locked basement, dirt patch in yard, freshly painted wall) + nervous_house (overly tidy, scent items overused, alcohol_present) + isolation (boarded from inside, no incoming letters, abandoned mail)

**Behavioral tells:**
- Greets her professionally polite: *"What can I do for you?"*
- Will not discuss children unprompted. Deflects: *"I don't really want to get into family stuff right now."*
- Reacts to specific topics: tense if Wilda mentions "basement," "yard," "missing," "police."
- Body language: tracks her movement around the house. Anxious if she heads toward specific rooms.

**Dialogue keywords:**
- "what happened to kid" / "your child" / "where children" → Evasion. *"I'd rather not talk about it. Tough times."*
- "show me basement" / "what in basement" → Refusal, possibly hostility. *"No. That's private."*
- The witness-mechanic keywords ("hands up" etc.) - they don't surrender easily. They escalate.

**The hard part: when Wilda has gathered damning evidence**

This is the moment the design has to handle carefully. After Wilda's Sheet for the building has surfaced enough evidence and concluded with a `predation` fate signal AND the NPC's behavioral state is Suspicious, the NPC's modData gets a flag (`KH.kidStatus.guilt_visible = true`). From that moment on:

- The NPC's idle dialogue includes more evasions and tells (mood drops, weapon hand-tightens when topic drifts close).
- KH adds context options when Wilda right-clicks them: "Show what you found" (presents the Sheet beats), "Press them" (escalating dialogue), "Walk away" (no commitment yet).
- The "Press them" option, if chosen, eventually triggers either a confession (the NPC breaks, admits, asks for some kind of mercy) or hostility (the NPC attacks Wilda to silence her).
- Wilda's options after confession or hostility:
  - Kill them (vanilla combat, but KH adds a thought-line acknowledging the weight)
  - Let them live (the Sheet records "she walked away knowing")
  - Refuse to continue feeding them if they were also a Safehouse (their kid_status flips the building from Safehouse to revoked)

This system never auto-kills the NPC. Wilda decides. KH provides the conditions for her decision but not the answer.

## Constraints

- **Per-house assignment.** Each child-evidence house has one parent (most often) with one kid-status. Multi-parent houses (two adults) may both have the same status or split, depending on house complexity. V1: one status per house, applied to whichever NPC is the "head" by BWO's logic.
- **State persistence.** Once assigned, kid-status doesn't randomly change. Wilda's actions (giving them confirmation news, pressing them, befriending them long enough) can shift Looking to At ease or vice versa.
- **No automatic player consequences.** KH never makes Wilda do anything based on the kid-status. The system surfaces possibilities and lets her choose.
- **Minimum hostiles.** Kierstal explicitly wants minimum hostile encounters. The Suspicious state can lead to hostility but only if Wilda chooses to press the issue. A peaceful playthrough can leave guilty parents alone (and the Sheet's record of that choice IS its own commentary).

## Integration with existing systems

- **BWOChat.** New keyword sets get added for each state. Heaviest contribution is to the Looking state (quest-like search), the Paranoid state (long anxious dialogues), and the Suspicious state (evasions and tells).
- **SSR Quest System.** The "find this child" quest from the Looking state uses SSR's quest framework with a TaskPack. The Suspicious-state "press them" path uses SSR's dialogue cards for the confession scene.
- **KH_NPCRegistry.** Kid-status is stored on the NPC's entry in the recognized-NPC registry. So even if Wilda doesn't recruit them, just talking to them in a child-evidence house assigns the status and records it.
- **KH_HomeTerritory Safehouse type.** If Wilda registers a Safehouse for a parent who later turns out to be guilty, she can revoke the Safehouse status. The food-delivery commitment ends.

## Resolved decisions (2026-05-29)

- **Distribution: 40 At ease / 35 Paranoid / 20 Looking / 5 Suspicious.** Locked. Suspicious stays rare. The official-information branches (At ease and Paranoid combined = 75%) make sense in VOriginal's "government is still trying to manage the narrative" early days.
- **Confession is multiple beats delivered as halo text over the NPC.** Not a DialoguePanel UI. The beats float over their head as they say them, fade as halo text does. More cinematic, more haunting - the player can't pause and re-read carefully, the words drift and pass.
  - Sample confession sequence (each line = one halo beat with delay between):
    1. *"She wouldn't stop."*
    2. *"I didn't mean it."*
    3. *"It was supposed to be quiet."*
    4. *"She's in the yard."*
  - The pacing matters. Each beat lands, fades, and the next comes a few seconds later. Reading the WHOLE confession requires Wilda to stand there for that whole time - which is its own form of witness.
- **Discovery is organic - no signposting in the orientation.** Wilda finds the system by encountering it. The orientation Sheet doesn't mention NPC kid-status states. She walks into her first house, meets a Paranoid parent, follows the conversation, and gradually realizes the world has this kind of texture in it. Players who never engage with this side of the system will only ever see the surface behavior.
- **Safehouse revocation is permanent.** Once Wilda revokes a Safehouse from a guilty parent, the building is no longer eligible. In practice this rarely matters because the realistic player response to a guilty parent is to kill them, not to formally cancel a delivery commitment. The revoke mechanic exists as a hook for the rare playthrough where the player chooses confrontation-without-violence (the "she walked away knowing" path). It's a formal endpoint for that path.
