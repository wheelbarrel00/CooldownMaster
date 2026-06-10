--[[
	Cooldown Master - DataBroker.lua

	Registers a LibDataBroker-1.1 launcher so the addon shows up in panel
	addons like Titan Panel, Bazooka, and ChocolateBar. Also creates a
	LibDBIcon-1.0 minimap button as a fallback for users who don't run a
	panel addon.
--]]

local ADDON_NAME, ns = ...

local LDB     = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0",     true)


function ns.DataBroker_Init(addon)
	if not LDB then return end

	local launcher = LDB:NewDataObject(ns.CONST.ADDON_NAME, {
		type    = "launcher",
		text    = ns.CONST.ADDON_DISPLAY,
		icon    = "Interface\\Icons\\Spell_Holy_BorrowedTime",
		label   = ns.CONST.ADDON_DISPLAY,

		OnClick = function(_, button)
			if button == "LeftButton" then
				if ns.Options_Toggle then ns.Options_Toggle() end
			elseif button == "RightButton" then
				addon.db.profile.global.unlockFrames = not addon.db.profile.global.unlockFrames
				addon:Print("Frames " ..
					(addon.db.profile.global.unlockFrames and "unlocked" or "locked"))
				-- Lane drag-labels show/hide off this flag; the per-tick
				-- config apply that used to repaint them is gone.
				if ns.Lanes_RefreshUnlockState then
					ns.Lanes_RefreshUnlockState(addon)
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

	-- Minimap button (only registers if LibDBIcon is available).
	if LDBIcon then
		LDBIcon:Register(ns.CONST.ADDON_NAME, launcher, addon.db.profile.dataBroker.minimap)
	end

	addon.dataBroker = launcher
end


-- Helper to toggle the minimap button from inside the options panel.
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
