--[[
	Cooldown Master - Events.lua

	With the SlotMirror engine, cooldown tracking is entirely poll-based —
	Engine:Tick reads Blizzard's slots every 0.1s. There are no
	SPELL_UPDATE_COOLDOWN, UNIT_SPELLCAST_SUCCEEDED, UNIT_AURA, or
	PLAYER_REGEN_* subscriptions for cooldown data anymore.

	The combat-state events still fire here so the UI layer (autohide,
	visibility) can react to combat enter/leave.
--]]

local ADDON_NAME, ns = ...

ns.Events = {}

function ns.Events.Register(addon)
	-- Combat state for autohide.
	addon:RegisterEvent("PLAYER_REGEN_DISABLED", function()
		addon.combat = true
		if ns.Lanes_OnCombatChange then ns.Lanes_OnCombatChange(true) end
	end)
	addon:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		addon.combat = false
		if ns.Lanes_OnCombatChange then ns.Lanes_OnCombatChange(false) end
	end)

	-- Group/instance state for the Always / In Group / In Instance toggles.
	addon:RegisterEvent("GROUP_ROSTER_UPDATE", function()
		if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
	end)
	addon:RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
		if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
	end)
end
