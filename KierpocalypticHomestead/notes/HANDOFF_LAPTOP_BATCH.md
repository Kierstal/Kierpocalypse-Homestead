# Hand-off → Laptop Claude instance

You're a **local** Claude Code session on Kierstal's laptop, which has the full
Project Zomboid install + the peripheral mods (Lifestyle: Hobbies, etc.) on
disk. A separate **cloud** session built everything in the repo so far; this doc
is the brief for the work that needs local source access the cloud session
couldn't reach. Read the design notes alongside this (`notes/*_DESIGN.md`).

## Ground rules (learned the hard way)

1. **Branches:** develop on `claude/epic-bohr-64DRp`. `main` is kept identical
   (fast-forwarded) so Kierstal's "Download ZIP from main" workflow stays current.
   **`git pull` before you push** (the cloud session may have pushed) and update
   both branches.
2. **Compile guard:** run `./tools/check_lua.sh` before every commit. A CI
   workflow (`.github/workflows/lua-check.yml`) also luac-checks every file on
   push. This exists because the original upload shipped **4 truncated files**
   that silently broke their systems — never let a non-compiling file through.
3. **Partial overrides break items (B42):** when overriding a vanilla script
   item, restate the **complete** item block, not just the changed field. See
   `media/scripts/items/KH_FannyPackOverrides.txt` for the established pattern.
4. **Do NOT commit vanilla game files or other mods' files** into the repo —
   that's TIS/other-authors' copyrighted code. Read them in place; only commit
   KH's own code.
5. **Style:** match the codebase — heavy `pcall` guards around engine calls,
   `KH.modules.X = version`, `print("[KH] ...")` load lines, `KH.UI.markOption`
   on context options, `getText(...)` for UI strings with English fallback.

## Decisions already locked (don't re-litigate)

- **Cold Winters:** Wisconsin-hard (lows ~ −25 to −30 °C, frequent blizzards) +
  generator cold-failure with manual restart. See `COLD_WINTERS_DESIGN.md`.
- **Starving Zombies:** corpse attraction with indoor/outdoor + same-building
  gate; sandbox-toggled, default OFF. See `STARVING_ZOMBIES_DESIGN.md`.
- **Residents (Phase 1 shipped):** supplies = virtual "give" store; want reward
  = small XP + a role-themed item; zombie danger opt-in/off. See
  `HOMESTEAD_RESIDENTS_DESIGN.md`.
- **Uses bump targets:** lighters, propane/welding torches, and crafting
  consumables (glue, tape, thread, sandpaper, etc.). NOT pills (not Uses-based).

## PRIORITY 0 — verify the one unverified thing already in the repo

`client/Village/KH_ResidentVisual.lua` spawns the resident mannequin with a
**best-effort, unverified** `IsoMannequin` call. Check it against the real B42
API (game source + an in-game test): confirm the constructor, `addToWorld`,
and how to set gender/skin/pose/clothing. Fix that one module; the rest of the
Residents system already works. Watch `console.txt` for `[KH] ResidentVisual`.

## The build queue (each needs local source)

| Feature | Read these (game install / mod) | Approach & gotchas |
|---|---|---|
| **Read While Walking** | `media/lua/client/TimedActions/ISReadABook.lua` | Wrap the action so it doesn't force-stop on movement (likely `stopOnWalk`/a stationary check). Keep XP/turn-page behavior intact. |
| **Exercise With Gear** | the exercise action (find: `…/media/lua` grep `Exercise`) | Skip the unequip/empty-hands gate at action start. Don't break the fitness XP/regen. |
| **Uses bump** | the item scripts holding `Lighter`, `BlowTorch`, `WeldingTorch`, `Glue`, `DuctTape`, `Thread`, `SandPaper` (grep `media/scripts`) | Restate **full** item blocks with a smaller `UseDelta` (uses = 1/UseDelta; torch 10→100 = 0.1→0.01). New file e.g. `media/scripts/items/KH_LowUseOverrides.txt`. |
| **Lifestyle panel** | the Lifestyle: Hobbies mod Lua (its hygiene/toilet need code + modData keys) | In `client/UI/KH_HomesteadTab.lua`: when `KH.deferHygiene()/deferToilet()` is true, read Lifestyle's live values and draw them (Kierstal wants the **Lifestyle numbers duplicated**, not blanked). Guard if Lifestyle absent. |
| **Rain Cleans Blood** | vanilla blood-removal (grep `Blood`, e.g. `ISWashBlood`/clean-blood action, `IsoObject` blood methods) | Periodic sweep: when `isRaining()` and outdoors, clear blood splats on loaded outdoor squares. Throttle + loaded-chunks only. New `server` or `client` module. |
| **Stack All** | drainable/fluid merge helpers (grep `getUsedDelta`/`getCurrentUses`/`Drainable`) | Inventory context option: consolidate partial stacks of the same type, delete empties. |
| **Map symbol size slider** | `media/lua/client/.../ISMap*` symbol render | Add a slider (map UI or sandbox) scaling symbol size. |
| **Loot Requires Light** | container loot UI + light (`square:getLightLevel`/player light) | Block opening/seeing container contents in darkness w/o a light source. Realism QoL. |
| **Playable Games** | console/handheld object or item detection | Right-click usable video-game consoles → timed action: happiness↑ boredom↓. Reuse mood deltas from `KH_NeedsCore`. NOTE: KH already has board-game play in `client/Boredom/KH_PlayGame.lua` — extend, don't duplicate. |
| **Better Generator Info** | generator tooltip + `IsoGenerator` fuel API | Add fuel-time-remaining to the tooltip; add a toggleable green range-circle highlight. |
| **Barricade in Menu** | `media/lua/client/ISUI/ISWorldObjectContextMenu.lua` (barricade submenu) | B42 buried Barricade in a submenu — hoist a Barricade option to the menu root (reuse the vanilla barricade action). |
| **Tanks have Propane** | the Fossoil/Gas2Go tank sprite names + fuel/propane source wiring | Make appropriate vanilla tank sprites act as propane sources. Confirm which sprites. |
| **Barricades Hurt Zombies** | whether B42 exposes a zombie-thump hook (else `OnZombieUpdate` scan) | Zombies take small damage per thump on any barricade; cumulative when a tile has multiple barricades. Sandbox-toggle it. |

## Then: the two big design-noted features

Build per their design notes once the queue is clear: **Cold Winters** (verify
the B42 temperature-write path first — that's the crux) and **Starving
Zombies** (mind the performance caps).

## When done

`./tools/check_lua.sh` → commit with a clear message → `git pull` → push to
`claude/epic-bohr-64DRp` → fast-forward `main` to match → push `main`. Tell
Kierstal to re-download the ZIP.
