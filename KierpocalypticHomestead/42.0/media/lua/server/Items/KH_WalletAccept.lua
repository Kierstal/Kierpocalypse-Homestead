-- Kierpocalyptic Homestead - permissive wallet accept filter
--
-- Vanilla AcceptItemFunction.Wallet (media/lua/server/Items/AcceptItemFunction.lua)
-- only lets the following items into a wallet:
--   - IsMap()                  (folded maps)
--   - IsLiterature()           (books / magazines - odd but vanilla)
--   - hasTag("FITS_WALLET")    (Money, CreditCard, CreditCard_Stolen)
--
-- That misses ID cards, business cards, photos, and stacked money bundles -
-- all things a real wallet trivially holds. We replace the function with
-- one that ALSO accepts:
--   - items tagged "idcard"        (IDcard, IDcard_Male/Female/Stolen)
--   - items tagged "picture"       (Photo)
--   - MoneyBundle / Coin items     (any item whose name starts with "Money" or "Coin")
--   - items whose name starts with "BusinessCard"
--
-- We deliberately DON'T touch the items themselves with a tag override -
-- partial item overrides break other fields in B42. Patching the Lua
-- function is single-source-of-truth and survives vanilla retunes.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.WalletAccept = "0.0.1"

-- Idempotent guard: if another mod (or a future-us) has already replaced
-- this, leave their version alone unless explicitly told to.
if KH._walletAcceptInstalled then return end
KH._walletAcceptInstalled = true

local function _khStartsWith(s, prefix)
    return type(s) == "string" and s:sub(1, #prefix) == prefix
end

-- Vanilla wallet items use ItemTag.FITS_WALLET. The constant is exposed
-- on the global ItemTag enum at runtime; falling back to the literal
-- string keeps things safe for the early-load case where ItemTag may not
-- be populated yet.
local function _hasTag(item, tag)
    if not item or not item.hasTag then return false end
    local ok, has = pcall(item.hasTag, item, tag)
    return ok and has and true or false
end

local function _accept(container, item)
    if not item then return false end
    -- Vanilla rules
    if item.IsMap and item:IsMap() then return true end
    if item.IsLiterature and item:IsLiterature() then return true end
    if _hasTag(item, "FITS_WALLET") or _hasTag(item, "fitswallet") then return true end
    -- KH additions
    if _hasTag(item, "idcard") then return true end       -- IDcard family
    if _hasTag(item, "picture") then return true end      -- Photo
    -- Name-based checks for items vanilla didn't tag cleanly:
    local name; pcall(function() name = item:getType() end)
    if name then
        if _khStartsWith(name, "BusinessCard") then return true end
        if _khStartsWith(name, "MoneyBundle") then return true end
        if name == "MoneyBundle" or name == "Coin" then return true end
    end
    return false
end

-- Install. Replace whatever AcceptItemFunction.Wallet is (vanilla or
-- another mod's). Wrapped in pcall to survive any load-order edge case.
local function _install()
    local ok, err = pcall(function()
        AcceptItemFunction = AcceptItemFunction or {}
        AcceptItemFunction.Wallet = _accept
    end)
    if ok then
        print("[KH] Wallet accept filter expanded (ID cards, photos, money bundles, business cards)")
    else
        print("[KH] Wallet accept install error (suppressed): " .. tostring(err))
    end
end

-- Defer to OnGameBoot. AcceptItemFunction.lua is in the same folder
-- (server/Items/), but load order between same-folder files isn't always
-- alphabetic across mod combos; deferring guarantees the global is up.
Events.OnGameBoot.Add(_install)
