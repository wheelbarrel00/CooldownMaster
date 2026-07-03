local ADDON_NAME, ns = ...

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
				addon:Print("Frames " ..
					(addon.db.profile.global.unlockFrames and "unlocked" or "locked"))
				-- No per-tick config apply repaints lane drag-labels anymore, so refresh them here.
				if ns.Lanes_RefreshUnlockState then
					ns.Lanes_RefreshUnlockState(addon)
				end
				if ns.ReadyFrames_RefreshUnlockState then
					ns.ReadyFrames_RefreshUnlockState(addon)
				end
			elseif button == "MiddleButton" then
				addon:ToggleTestMode()
			end
		end,

		OnTooltipShow = function(tt)
			tt:AddLine(ns.Colorize(ns.CONST.HEX.YELLOW, ns.CONST.ADDON_DISPLAY))
			tt:AddLine("Version " .. ns.CONST.VERSION, 1, 1, 1)
			tt:AddLine(" ")
			tt:AddLine(ns.Colorize(ns.CONST.HEX.YELLOW, "Left-click")  .. " to open options.",  1, 1, 1)
			tt:AddLine(ns.Colorize(ns.CONST.HEX.YELLOW, "Right-click") .. " to lock/unlock.",   1, 1, 1)
			tt:AddLine(ns.Colorize(ns.CONST.HEX.YELLOW, "Middle-click").. " to toggle test.",   1, 1, 1)
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
