-- Kierpocalyptic Homestead - core boot hook
-- Smoke-test entry point. Prints to console so we can confirm the mod loads.
-- Other modules will register themselves on the KH table this file creates.

KH = KH or {}
KH.MODVERSION = "0.0.1"
KH.modules = KH.modules or {}

-- Global debug switch. Modules check `KH.DEBUG` for whether to enable
-- their debug behaviors (test-animal spawn, verbose pickup logs, etc.).
-- Flip to false before shipping a release version.
KH.DEBUG = true

local function onBoot()
    print("[KH] Kierpocalyptic Homestead "..KH.MODVERSION.." loaded. DEBUG=" .. tostring(KH.DEBUG))
    for name, _ in pairs(KH.modules) do
        print("[KH]   module: "..name)
    end
end

Events.OnGameBoot.Add(onBoot)
