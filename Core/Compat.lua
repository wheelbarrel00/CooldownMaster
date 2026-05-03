--[[
	Cooldown Master - Compat.lua
	WoW flavor detection and version-gated API helpers.

	Midnight (retail) restricts certain combat data via "Secret Values" and adds
	Blizzard's native Cooldown Manager. Classic and TBC have looser APIs but no
	Cooldown Manager. This file is the single source of truth for "what can we
	call here?" so the rest of the addon stays clean.
--]]

local ADDON_NAME, ns = ...

ns.Compat = {}

-- Flavor flags (set once at load).
ns.Compat.IS_RETAIL  = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
ns.Compat.IS_CLASSIC = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
ns.Compat.IS_TBC     = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)

-- Numeric tocversion, e.g. 120005 on Midnight 12.0.5.
local _, _, _, tocversion = GetBuildInfo()
ns.Compat.TOC_VERSION = tocversion or 0

-- Convenience: are we on Midnight (12.0+) where the native Cooldown Manager exists?
ns.Compat.HAS_BLIZZ_CDM = ns.Compat.IS_RETAIL and ns.Compat.TOC_VERSION >= 120000

-- Returns spell cooldown info as a 4-tuple regardless of flavor.
-- Wraps the API change between C_Spell.GetSpellCooldown (modern) and
-- the legacy GetSpellCooldown global (Classic).
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

-- Returns true if the addon should attempt to read Blizzard's Cooldown Manager
-- as the data source (only valid on Midnight retail).
function ns.Compat.UseBlizzardCDM()
	return ns.Compat.HAS_BLIZZ_CDM
end

-- Returns a friendly flavor label for display in the Global tab footer.
function ns.Compat.FlavorLabel()
	if ns.Compat.IS_RETAIL  then return "Retail (Midnight)" end
	if ns.Compat.IS_CLASSIC then return "Classic Era"        end
	if ns.Compat.IS_TBC     then return "TBC Classic"        end
	return "Unknown"
end
