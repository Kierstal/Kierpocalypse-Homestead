# KH Feature Wishlist

Features Kierstal has expressed interest in that aren't priority right now but should not be lost. Each entry: what it is, why it matters, what it'd take, dependencies.

## Store-theft mechanic + hostile police response

**The vision:** Spawn in a town. Shops have items on shelves and a cash register. Vanilla money in the player's inventory. Taking items WITHOUT first transferring money to the register equal to or exceeding their value = theft. Theft triggers `BWOEvents.CallCops` with hostility flag. Cops arrive and engage. Stay quiet, pay your way, no trouble.

**Why she remembered it:** A "loot from store = theft = hostile police" mechanic she recalls from a previous Project Zomboid mod session. After deep web search (2026-05-28), no B41 or B42 mod ships this exact combination. Closest:
- Immersive Shops (B41 only, B42 rework pending) handles buy/sell mechanics with vanilla money but no theft/police.
- MX-Economy, SimpleShop, ZConomy are working B42 shop frameworks but more game-y (press O for menu, ATM, combat-money), not realistic-store.

She's likely combining memories from multiple mods, or remembering a feature request as a feature.

**Why she likes it:** Makes vanilla money meaningful. Creates risk/reward around looting. Makes the cops a coherent presence rather than just a random spawn group. Lines up with her general "consequences that teach through experience" design DNA.

**What it'd take (KH-side build estimate: 4-6 hours focused):**
1. **Container tagging**: identify shop containers (cash registers, shop-zoned shelves). Vanilla `RoomDef:getName()` lookup for "kitchen", "office" probably has "store" or "shop" room types. Tag all containers in those rooms as `KH_ShopOwned = true`.
2. **Pricing data**: load a JSON of item → base price (FOOL-like JSON config could work). Or per-tag pricing (food = $5/unit, weapons = $50, etc.).
3. **Theft detection**: hook `ISInventoryTransferAction` for any source container with `KH_ShopOwned = true`. If destination is NOT a `KH_CashRegister` AND no money in matching amount was previously transferred TO this register → flag the action as theft.
4. **Cops dispatch**: on theft flag, after grace period (~30 sec for the act of carrying out), call `BWOEvents.CallCops` with `program="Bandit"` + spawn near player position. Hostility comes from the program.
5. **Sandbox toggles**: `KHCompat.StoreTheftDetection` (off by default until tested), `KHCompat.StoreTheftCopsResponse` (cops dispatch separately gated).

**Dependencies:**
- BWO (Bandits Week One) for `CallCops`. Or implement own cop-spawn via vanilla `addZombie` + Bandit clan tagging.
- Could optionally integrate with one of the existing shop mods for the pricing data.

**Why this isn't the priority right now:** The HEART of her vision is feeding NPCs / making her cooking matter / "I want to feed a village." The shop-theft mechanic is a flavor cherry on top, not the centerpiece. We pursue this later or not at all depending on how much shop-feel she still wants once hunger/feeding is in.

**Resume notes for future instance:** This is a clear, well-scoped buildable feature. Estimate is conservative; could be 3 hours if pricing data is tag-based instead of per-item. The hardest part is the pricing data design choice. Ask Kierstal first whether she wants every item priced individually (immersive but tedious) or by category (faster to ship, less granular).
