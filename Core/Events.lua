-- Cooldown data is poll-based (Engine:Tick); only combat/group-state events live here.
local ADDON_NAME, ns = ...

ns.Events = {}

function ns.Events.Register(addon)
	addon:RegisterEvent("PLAYER_REGEN_DISABLED", function()
		addon.combat = true
		if ns.Lanes_OnCombatChange then ns.Lanes_OnCombatChange(true) end
		-- Drag tags are a positioning aid, not combat chrome, so re-hide the ready-box tags too.
		if ns.ReadyFrames_RefreshVisibility then ns.ReadyFrames_RefreshVisibility() end
		if ns.Bars_RefreshVisibility then ns.Bars_RefreshVisibility() end
	end)
	addon:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		addon.combat = false
		if ns.Lanes_OnCombatChange then ns.Lanes_OnCombatChange(false) end
		if ns.ReadyFrames_RefreshVisibility then ns.ReadyFrames_RefreshVisibility() end
		if ns.Bars_RefreshVisibility then ns.Bars_RefreshVisibility() end
	end)

	addon:RegisterEvent("GROUP_ROSTER_UPDATE", function()
		if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
	end)
end
