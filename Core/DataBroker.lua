local ADDON_NAME, ns = ...
local L = ns.L

local LDB     = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0",     true)


function ns.DataBroker_Init(addon)
	if not LDB then return end

	local launcher = LDB:NewDataObject(ns.CONST.ADDON_NAME, {
		type    = "launcher",
		text    = ns.CONST.ADDON_DISPLAY,
		icon    = "Interface\\AddOns\\CooldownMaster\\media\\minimap",
		label   = ns.CONST.ADDON_DISPLAY,

		OnClick = function(_, button)
			if button == "LeftButton" then
				if ns.Options_Toggle then ns.Options_Toggle() end
			elseif button == "RightButton" then
				addon.db.profile.global.unlockFrames = not addon.db.profile.global.unlockFrames
				addon:Print(addon.db.profile.global.unlockFrames
					and L["Frames unlocked."] or L["Frames locked."])
				-- No per-tick config apply repaints lane drag-labels anymore, so refresh them here.
				ns.ForEachSurface("RefreshUnlockState", addon)
			elseif button == "MiddleButton" then
				addon:ToggleTestMode()
			end
		end,

		OnTooltipShow = function(tt)
			tt:AddLine(ns.Colorize(ns.CONST.HEX.YELLOW, ns.CONST.ADDON_DISPLAY))
			tt:AddLine(string.format(L["Version %s"], ns.CONST.VERSION), 1, 1, 1)
			tt:AddLine(" ")
			tt:AddLine(string.format(L["%s to open options."],
				ns.Colorize(ns.CONST.HEX.YELLOW, L["Left-click"])),   1, 1, 1)
			tt:AddLine(string.format(L["%s to lock/unlock."],
				ns.Colorize(ns.CONST.HEX.YELLOW, L["Right-click"])),  1, 1, 1)
			tt:AddLine(string.format(L["%s to toggle test."],
				ns.Colorize(ns.CONST.HEX.YELLOW, L["Middle-click"])), 1, 1, 1)
		end,
	})

	if LDBIcon then
		LDBIcon:Register(ns.CONST.ADDON_NAME, launcher, addon.db.profile.dataBroker.minimap)
	end

	addon.dataBroker = launcher
end


function ns.DataBroker_ApplyProfile(addon)
	if not LDBIcon then return end
	-- A profile switch swaps db.profile to a new table; Register captured the old
	-- profile's minimap table, so re-bind to the new one or hide-state/angle won't follow.
	LDBIcon:Refresh(ns.CONST.ADDON_NAME, addon.db.profile.dataBroker.minimap)
end


function ns.DataBroker_ToggleMinimap(addon)
	if not LDBIcon then return end
	local hidden = addon.db.profile.dataBroker.minimap.hide
	addon.db.profile.dataBroker.minimap.hide = not hidden
	if hidden then
		LDBIcon:Show(ns.CONST.ADDON_NAME)
	else
		LDBIcon:Hide(ns.CONST.ADDON_NAME)
	end
end
