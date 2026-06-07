# Rip Clothing for Underwear + Tailoring XP Rebalance — Scope

**Status:** scoped, not implemented.

## Part 1 — Why socks / underwear / boxers can't be ripped

### Investigation

The Rip Clothing system migrated from B41's context-menu Lua action to
B42's `craftRecipe` system. The old `ISInventoryPaneContextMenu.canRipItem`
function still exists in vanilla but **is dead code — never called from
anywhere else.**

The live system is a craftRecipe in `media/scripts/generated/recipes/recipes.txt`:

```
craftRecipe RipClothing
{
    timedAction = RipClothing,
    time = 40,
    Tags = InHandCraft;CanBeDoneInDark;RemoveResultItems,
    OnCreate = RecipeCodeOnCreate.ripClothing,
    inputs
    {
        item 1 tags[base:ripclothingcotton] flags[AllowDestroyedItem;IsNotWorn;ItemCount],
    }
    outputs { item 1 Base.RippedSheets, }
}
```

Two variants exist: `RipDenimClothing` (`base:ripclothingdenim`) and
`RipClothing` for cotton. Plus `CutTarp` and `RipSheets` for non-clothing
fabric sources. **None grant Tailoring XP** — see Part 2.

### The gating mechanism

The recipe input requires the **`base:ripclothingcotton`** (or denim/
leather) tag. Items with `FabricType = Cotton` but **without the
`base:ripclothingcotton` tag** are not accepted.

### Items missing the tag

Verified via awk over `clothing.txt`. Items with `FabricType = Cotton`
that are **missing the rippable tag:**

**Socks:**
- `Socks_Ankle`, `Socks_Ankle_White`, `Socks_Ankle_Black`
- `Socks_Long`, `Socks_Long_White`, `Socks_Long_Black`
- `Socks_Heavy`
- `Socks_LegWarmers`

**Underwear / undergarments:**
- `Underpants_Black`, `Underpants_RedSpots`, `Underpants_White`
- `Boxers_Hearts`, and other `Boxers_*` variants
- `Briefs_*` variants (likely; not all enumerated above)
- `Bra_*` and `Bandeau_*` variants (likely)

**Other minor accessories also missing it:**
- `Gloves_*` (most cotton gloves), `Hat_Bandana*`, `Hat_RagBandana*`,
  `Hat_RagBandanaMask`, `ShemaghScarf*`, `Shorts_HockeyPants*`,
  `Tshirt_EMD`, `Tshirt_IndieStoneDECAL` (probably promo/event items)

### The fix

**Per-item tag override**, not a context-menu patch. The mod adds an
item-script override file (e.g. `42.0/media/scripts/items/KH_rip_overrides.txt`)
that re-declares these items with extended `Tags` including
`base:ripclothingcotton`.

Example override:
```
module Base
{
    item Socks_Ankle
    {
        Tags = base:ripclothingcotton;<existing tags>,
    }
}
```

If `Tags` line already exists in vanilla, the override REPLACES the
whole Tags string — so the existing tags must be re-included. Need to
read each item's existing `Tags` field from `clothing.txt` and append.

**Caveat:** I haven't fully audited which of these items have *other*
existing tags that would need to be preserved. Some bandanas may have
`base:rag` or similar combat tags. Pre-implementation step: dump every
target item's vanilla `Tags` field, then build the override list.

**Alternative approach (riskier, broader effect):** patch the recipe
itself to accept any item with `FabricType = Cotton` instead of the tag.
That would also rip every cotton item including ones with intentional
exclusions (the `_DECAL` event shirts probably). Not recommended.

---

## Part 2 — Tailoring XP audit & rebalance

### Every action that grants Tailoring XP (B42 vanilla)

Audited from `media/scripts/generated/recipes/**.txt` + Lua action
files. Numbers are the `Tailoring:N` xp award per recipe completion.

#### Lua-coded actions (legacy hooks, still live)

| Action | File | XP | Notes |
|---|---|---|---|
| Repair clothing (patch on) | `ISRepairClothing.lua` | **2** | Per patch placed |
| Remove patch | `ISRemovePatch.lua` | **2** | Per patch removed |
| (rip via Lua) | (none active) | n/a | Migrated to craftRecipe |

#### craftRecipe XP grants — histogram

| XP per recipe | # of recipes |
|---|---|
| 5 | 14 |
| 6 | 24 |
| 8 | 6 |
| 9 | 28 |
| 11 | 8 |
| 13 | 16 |
| 16 | 5 |
| 20 | 20 |
| 25 | 3 |
| 30 | 16 |
| 38 | 6 |
| 40 | 1 |
| 45 | 12 |
| 55 | 6 |
| 68 | 4 |
| 75 | 1 |
| 80 | 2 |
| 90 | 1 |

Total: ~173 distinct recipes grant Tailoring XP (some are side-grants
from blacksmith/carving/welding recipes — only ~5 XP each).

#### Top-XP "real tailoring" recipes (player will naturally want these)

| XP | Recipe | What it makes |
|---|---|---|
| 90 | `AssembleAdvancedLargeFramepack` | Large frame backpack — endgame |
| 80 | `MakeWesternBoots` | Boots from leather + components |
| 80 | `MakeBoneBodyArmor` | Bone armor torso |
| 75 | `AssembleAdvancedFramepack` | Medium frame backpack |
| 68 | `SewLeatherPants` / `SewLeatherGloves` / `SewFurredHideCoat` / `MakeTireBodyArmor` | Big leather pieces |
| 55 | `SewBandolier` / `SewShellsBandolier` / `SewHolsterDouble` / `AssembleSmallFramepack` / `AssembleLargeFramepack` / `AssembleLargeTarpFramepack` | Mid-tier accessories |
| 45 | `SewLongjohns` / `SewHideHoodie` / `SewFurredHideJacket` / `SewCrudeLeatherBackpack` etc. | Mid-tier garments |
| 38 | `SewLeatherWaterBag` / `SewKneePads` / `SewElbowPads` / `SewHolster` | Useful basics |
| 30 | `SewHideJacket` / `SewHideBoots` / `SewFurHat` / `KnitBalaclavaFull` etc. | Late-survival garments |

#### Core tailoring (`recipes_tailoring.txt`) lower tier

| XP | Recipe | Notes |
|---|---|---|
| 20 | `SewTrousers` | Useful early |
| 13 | `MakeMattress` / `SewClothSatchel` / `SewShirt` | Useful early |
| 9 | `SewDressKnees` / `SewDressLong` / `SewPillow` / `SewShirtSleeveless` / `SewSkirtKnees/Long` / `MakeTireSandals` / `WeaveTwineShoes` / `SewHeadSack` / `SewImprovisedBriefs` / `SewSackGunny` | Mid |
| 8 | `SewFootwrap` / `SewHandwrap` / `SewHeadwrap` / `SewImprovisedBandeau` / `SewRagBandana` / `SewSack` | Improvised rag-based basics |

### The grind problem

Kierstal's complaint: "I have to grind crafts I don't want, just to skill
up tailoring."

**Root cause:** the natural early-game tailoring actions Kierstal does —
ripping for thread/scraps and patching her own clothes — give **2 XP per
patch and 0 XP for ripping**. Even the "small but useful" sewn items
(SewShirt, SewTrousers) cap at 13-20 XP. To level out of the L0-L2
range without grinding, players are pushed toward repetitive sewing of
items they don't need (SewPillow, SewDressLong) or far-off
late-game recipes (SewLeatherPants requires Leather workflow already).

The PZ XP curve roughly: L0→L1 needs ~75 XP, L4→L5 needs ~750, L8→L9
needs ~6000. At 2 XP per patch, that's 3000 patches to reach L9 from
L0 through patching alone — absurd.

### Proposed rebalance

**Goal:** natural play (ripping, patching, sewing small basics) levels
the skill at a reasonable pace; advanced recipes still feel meaningful.

#### 1. Add XP to rip/cut actions

These are zero-XP now and shouldn't be — ripping is a tailoring action.
Add `xpAward = Tailoring:N` to:

| Recipe | Proposed XP | Reasoning |
|---|---|---|
| `RipClothing` (Cotton) | **3** | Quick rip, fabric-shape-recognition |
| `RipDenimClothing` | **5** | Tougher fabric, takes longer |
| `RipLeatherClothing` (verify name) | **5** | Same |
| `RipSheets` (bed/curtain sheet) | **3** | Same as cotton clothes |
| `CutTarp` | **2** | Trivial — already meant to be quick |

This alone makes "loot a closet, rip everything" a real source of
~30-100 XP per house, which scales naturally with playtime.

#### 2. Boost patch-repair XP

`ISRepairClothing.lua` and `ISRemovePatch.lua` should grant **5 XP**
(up from 2). Repairing is THE most natural tailoring action — players
do it for their own gear repeatedly. The current value is so low it
feels like the game doesn't reward you for the action.

Patching condition is currently gated by holes count + skill level, so
"grind by tearing your own pants and re-patching" is naturally rate-
limited — no need to under-tune the reward.

#### 3. Lift the "useful early" tier

These should encourage low-level players to make practical gear:

| Recipe | Current XP | Proposed XP |
|---|---|---|
| `SewShirt` | 13 | **20** |
| `SewTrousers` | 20 | **25** |
| `MakeMattress` | 13 | **20** |
| `SewClothSatchel` | 13 | **20** |
| `SewFootwrap` / `Handwrap` / `Headwrap` / `Bandeau` / `RagBandana` / `Sack` | 8 each | **12** each |
| `WeaveTwineShoes` / `MakeTireSandals` | 9 | **15** |

The "improvised basics" set in particular — these are what a new survivor
makes when they have no money and lots of rags. They should feel like
practical Tailoring progress.

#### 4. Don't change the high tier (keep meaning)

Recipes at 38+ XP already feel rewarding. Leave alone:
- All armor-construction recipes (Bone, Leather, Tire, Sheepskin)
- All framepack assemblies
- Big leather garments

#### 5. Audit the "side-grant" sprinkles

Recipes in `recipes_blacksmith_armor.txt`, `recipes_metalWelding_Armor.txt`,
`recipes_carving.txt`, and `recipes_bone.txt` award 5-10 Tailoring XP as
a side bonus while the primary skill is Blacksmith/MetalWelding/etc.

This is fine in principle (these recipes DO involve sewing fabric pieces
to the armor), but at 5-10 XP each they're individually negligible. Keep
unchanged — they're a nice bonus that already isn't worth grinding.

### Files to change (implementation plan, not implementing here)

- `42.0/media/scripts/recipes/KH_rip_xp.txt` — overrides for the four
  rip/cut recipes with added `xpAward`.
- `42.0/media/scripts/recipes/KH_tailoring_xp_boost.txt` — overrides for
  the SewShirt/Trousers/Mattress/etc. tier.
- `42.0/media/lua/client/Tailoring/KH_RepairClothingXP.lua` — wrap
  `ISRepairClothing:perform` and `ISRemovePatch:perform` to grant an
  extra +3 XP each (additive on top of vanilla's +2 = 5 total).

### Open questions

**Q1 — Should rip XP scale with item size?** Currently the recipe input
is "1 item" regardless of whether it's a sock or a longcoat. Could
either:
- Keep flat (3 XP regardless) — simpler, makes mass-ripping rewarding.
- Tag-derived scale: items with `base:ripclothingcotton` + size hint
  (we'd need to add a per-item XP override in the OnCreate Lua) →
  socks give 1, shirts give 3, longcoats give 6. More realistic but more
  scaffolding.

  Recommend: flat for v1. Revisit if it feels grindy in playtest.

**Q2 — Should we add a rip-XP cap per in-game day?** To prevent
"raid a clothing store at L0 → instant L5 Tailoring" exploit. Recommend
no cap initially; PZ doesn't gate other XP sources this way and adding
one introduces a hidden mechanic.

**Q3 — Knitting recipes worth boosting?** Knitting (`recipes_tailoring_knitting.txt`)
needs verification — likely the smaller XP grants are right but a few
might need lifting. Verify after Q1 ships.

**Q4 — Sock-specific concern.** Once socks are rippable, will players
strip them off zombies for XP-farming? Probably yes. Counter: socks
should only give 1 RippedSheet output (currently the recipe outputs 1
regardless of input size). Confirm the output is 1 by reading the recipe
output section.

### Won't-do

- Removing patches from clothing for free (already exists; not the bug).
- Adding a "scissoring practice" busywork action — would feel like
  exactly the kind of grind Kierstal hates.
- Changing the skill cap or the XP curve itself — those are systemic
  PZ tuning and out of scope for the homestead mod.
