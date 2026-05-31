-- Kierpocalyptic Homestead - VHS / TV skill XP cap removal
--
-- Vanilla check (ISRadioInteractions.lua doSkill):
--   if SandboxVars and (_player:getPerkLevel(_perk) >= SandboxVars.LevelForMediaXPCutoff) then return end
--
-- That cap is set to 3 in every vanilla preset, meaning TV/VHS stops giving
-- XP once a skill is at level 3. We push the cap to 11 so it never triggers
-- (max skill level is 10).
--
-- Override at OnGameStart so it applies to existing saves too, not just new
-- games created with our preset. Our sandbox preset also sets 11 explicitly
-- so the value shows correctly in the world's saved settings.

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.MediaXPCap = "0.0.1"

local function liftCap()
    if SandboxVars then
        SandboxVars.LevelForMediaXPCutoff = 11
        print("[KH] Media XP cap lifted: LevelForMediaXPCutoff = 11.")
    end
end

Events.OnGameStart.Add(liftCap)
