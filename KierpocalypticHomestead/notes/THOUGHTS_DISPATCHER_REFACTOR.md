# Thoughts Dispatcher Refactor — Implementation Note

**Status: implemented** in `KH_Thoughts.lua` v0.0.3.

## Problem solved

Pre-v0.0.3 `KH.Thoughts.emit()` had a single 30-minute cooldown applied
across *all* categories. When multiple categories fired in the same
minute (e.g., filthy room AND high bath need AND a milestone), only the
first emit got through. The rest vanished. Kierstal missed meaningful
flavor lines.

## What changed

1. **Per-category cooldown.** Each category (or category + key pair) has
   its own cooldown timer in `player:getModData().KH_thoughtCooldownsByCategory`.
   Different categories no longer block each other.
2. **Queue with bounded depth.** When emissions land back-to-back, they
   are queued in module-local memory. A drain function runs on
   `Events.EveryOneSecond` and displays one line every `HALO_GAP_SECONDS`
   (4.5s — chosen because PZ halo display is ~4s, with a brief gap so the
   next line doesn't visually stack).
3. **Overflow drops with warn-log.** Queue depth cap is 6. If exceeded,
   excess lines `print` a warning and are dropped — better than runaway.
4. **Cooldown key uses `category/key` composite.** This means
   `filth/becameFilthy` and `filth/becameClean` are tracked separately,
   so re-entering and leaving a filthy room within 30 min still fires
   both transition lines. (Category-only cooldown would have dropped the
   "becameClean" line.)
5. **Real-time pacing, not game-time.** Drain interval uses real seconds
   (via `getTimestampMs()` with `os.clock()` fallback), so queue drain
   doesn't pause when game time is paused.

## API surface unchanged

`KH.Thoughts.emit(player, category, key)` and
`KH.Thoughts.emitForce(player, category, key)` are the same external
signatures. Existing call sites (filth, dirt, bath, toilet, time, weather,
moodle triggers, etc.) all work without modification.

## Edge cases handled

- **Save/load:** queue is module-local and lost across reloads. That's
  fine — queued lines were "about to fire" but hadn't yet; losing them
  on a reload is acceptable.
- **MP:** queue is per-client. Each client drains its own.
- **Player death mid-queue:** `showLine` no-ops on missing player.

## What I considered and rejected

- **Coroutines:** would have given prettier timing but PZ Lua coroutine
  support is shaky in B42. `EveryOneSecond` polling is dumber and works.
- **Persistent queue (modData):** the queue is short-lived UI state, not
  worth survival-save serialization overhead. Lost on reload is fine.
- **Per-key cooldown only (no category-level):** would have spammed if
  many keys exist in a category. Category-level dedup is the sane default,
  composite `category/key` is the actual implementation.

## When this might break

- If PZ changes the halo text display duration, `HALO_GAP_SECONDS` (4.5)
  could feel wrong. Easy to retune.
- If a new system fires emits much faster than 1/sec, the queue cap may
  routinely overflow; consider raising `KH_QUEUE_MAX`.
