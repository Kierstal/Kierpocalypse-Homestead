# BWO + Lifestyle: Hobbies Overlap Audit

**Date:** 2026-06-01
**Status:** Working notes
**Context:** Kierstal asked for confirmation that Lifestyle takes preference whenever the two mods overlap. Hygiene/bathroom collision was confirmed silently breaking gameplay. This document captures the audit and the KH coexistence pattern.

## The principle

**Lifestyle: Hobbies wins when both mods are loaded.** When their behaviors collide, KH steps aside in favor of Lifestyle. When Lifestyle is silently broken (most commonly by Bandits' interference), KH provides a fallback action so the player isn't stranded. The fallback is gated on the combination "Lifestyle AND Bandits both present" - so the fallback only activates when it's actually needed.

## Overlap matrix

### 1. Hygiene / bathroom system

**Lifestyle owns:** HygieneNeed, ToiletBladderNeed, BathContextMenu, ShowerContextMenu, ToiletContextMenu, ToiletGroundContextMenu, BathTubFunctions, ShowerFunctions, ToiletFunctions, PerfumeContextMenu, MirrorContextMenu, CabinetContextMenu.

**Known BWO interference:** With Bandits loaded, Lifestyle's bathroom context menus stop appearing. Root cause not yet identified - suspected BanditActionInterceptor (hooks OnTimedActionPerform) or a namespace collision in the chain that builds Lifestyle's context menu options.

**KH fallbacks shipped:**
- `KH_UseToiletAction` - sprite-name + room fallback for toilet detection. Activates when CustomName is unset OR the deferral path fails. (2026-06-01)
- `KH_BathAction` - bathtub/shower/sink fallback. Activates when both Lifestyle + Bandits are loaded (the broken combination) OR when Lifestyle isn't loaded at all. Provides "Wash Up" right-click on bathroom fixtures. Resets KH bath need + body dirtiness + modest unhappiness relief. (2026-06-01)
- `KH_HygieneActions` - brush teeth + deodorant. **Always active**, doesn't defer at all (predates the audit). These appear in inventory right-click whenever you have toothbrush+toothpaste or deodorant/hairspray/hairgel.

**Still uncovered:** mirror interaction, cabinet interaction, perfume application beyond the deodorant alias. Lower priority - the core (toilet, bath, teeth) is covered.

### 2. Voice tracks / vocalizations

**Lifestyle owns:** PlayerVoiceTracks.lua (Booing, Frustrated, Woohoo, etc. - vocalization sounds).

**BWO interference (suspected):** BWO's `onEmote` handler translates player emotes to text and feeds them to BWOChat.Say. If Lifestyle's voice tracks trigger an OnEmote event (via radial menu or auto-play), BWO interprets the vocalization as the player "saying" something. Result: NPCs respond as if chatted-at, even when the player didn't type. This matches Kierstal's observation of NPCs responding at ~5 tiles without input.

**Status:** Hypothesis, not confirmed. Investigation requires reading where Lifestyle plays voice tracks and whether any path goes through `triggerEvent("OnEmote", ...)`. Kierstal declined to investigate further at this time.

**If confirmed, KH fix path:** patch BWO's `onEmote` handler to bail out for emote types that originate from Lifestyle's voice list. Or simpler: make BWO's onEmote-to-chat translation a sandbox toggle.

### 3. TimedActions through BanditActionInterceptor

**BWO behavior:** Bandits ships `BanditActionInterceptor` that hooks `Events.OnTimedActionPerform`. It only acts on `ISInventoryTransferAction → fridge/freezer` (for base registration), but the handler runs for every action call.

**Lifestyle exposure:** 92 TimedActions in Lifestyle. The interceptor doesn't directly modify them, but lives on the same hook. If the interceptor throws an error, it COULD short-circuit subsequent handlers.

**Status:** No confirmed breakage. The interceptor is short and well-scoped; unlikely culprit. Worth checking if other Lifestyle features mysteriously fail.

### 4. Disco / Dance / Party / Music

**Lifestyle owns:** DiscoBall, DanceFloor, DJBooth, Jukebox, Dance, Music, JukeboxTracks. Player-initiated equipment-based entertainment.

**BWO has:** BuildingParty scenario events (a party happens in a nearby building at scheduled times), Entertainer event (someone performs in the street).

**Collision risk:** Low. Different mechanics. Lifestyle's parties are equipment the player places and uses; BWO's are world events. They can coexist without interfering.

### 5. MPSocial

**Lifestyle owns:** InteractionManager, plushies, sharing knowledge - multiplayer social interactions.

**BWO has:** Bandit NPCs Wilda can chat with.

**Collision risk:** None in single-player. MPSocial features inactive without other players online.

### 6. Cleaning skill

**Lifestyle owns:** LSCleanRoomContextMenu, cleaning XP, cleaning skill books.

**BWO has:** No cleaning system.

**Collision risk:** None.

### 7. Sandbox option naming

**Lifestyle namespace:** `LSAmbt`, `LSPaint`, `Text`, etc.
**BWO namespace:** `BanditsWeekOne`, `Bandits`.
**KH namespace:** `KHCompat`.

**Collision risk:** None - clean namespace separation.

## KH coexistence pattern (the actual policy)

When KH writes a hygiene/bathroom action:

1. **Check `KH.compat.lifestyle`** - is Lifestyle loaded?
2. **Check `KH.compat.banditsweekone`** - is Bandits loaded?
3. **Apply rule:**
   - **Lifestyle yes, Bandits no** → defer to Lifestyle. KH action does not register.
   - **Lifestyle yes, Bandits yes** → register KH action as fallback. Lifestyle is silently broken; user needs the option.
   - **Lifestyle no** → register KH action as primary. KH owns this domain.

The fallback is silent: it doesn't say "Lifestyle broken, using KH instead." It just appears as an option when no other option exists.

## What this audit does NOT do

- Doesn't fix Lifestyle itself. KH provides a workaround, not a repair.
- Doesn't patch BWO to step aside from Lifestyle. The root cause of the interference is unknown; without it we can't surgically remove the breakage.
- Doesn't address voice → BWO chat suspicion. Hypothesis filed, investigation deferred.

## Open work

- Confirm bath/teeth/deodorant fallbacks actually fire in a new save with both mods active. The toilet fix is verified; the bath/sponge ones are new.
- Add mirror/perfume/cabinet fallbacks if they prove user-visible (low priority).
- Investigate voice → chat path if Kierstal wants the chat-without-typing fixed.
- Watch for other Lifestyle silent failures when BWO is loaded - same fallback pattern applies.
