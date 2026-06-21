local ADDON_NAME, ns = ...

ns.Compat = {}

ns.Compat.IS_RETAIL  = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
ns.Compat.IS_CLASSIC = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
ns.Compat.IS_TBC     = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)

local _, _, _, tocversion = GetBuildInfo()
ns.Compat.TOC_VERSION = tocversion or 0

-- Midnight 12.0+ (tocversion >= 120000) is where Blizzard's native Cooldown Manager exists.
ns.Compat.HAS_BLIZZ_CDM = ns.Compat.IS_RETAIL and ns.Compat.TOC_VERSION >= 120000

-- Normalizes the C_Spell.GetSpellCooldown (modern) vs GetSpellCooldown (Classic) API split.
function ns.Compat.GetSpellCooldown(spellID)
	if C_Spell and C_Spell.GetSpellCooldown then
		local info = C_Spell.GetSpellCooldown(spellID)
		if info then
			return info.startTime, info.duration, info.isEnabled, info.modRate
		end
		return 0, 0, false, 1
	else
		local start, duration, enabled, modRate = GetSpellCooldown(spellID)
		return start, duration, enabled, modRate
	end
end

function ns.Compat.UseBlizzardCDM()
	return ns.Compat.HAS_BLIZZ_CDM
end

function ns.Compat.FlavorLabel()
	if ns.Compat.IS_RETAIL  then return "Retail (Midnight)" end
	if ns.Compat.IS_CLASSIC then return "Classic Era"        end
	if ns.Compat.IS_TBC     then return "TBC Classic"        end
	return "Unknown"
end
