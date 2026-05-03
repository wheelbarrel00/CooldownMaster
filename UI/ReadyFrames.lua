--[[
	Cooldown Master - UI/ReadyFrames.lua
	"Ready" notification frames that flash an icon when a cooldown finishes.
	v0.1 status: stub.
--]]

local ADDON_NAME, ns = ...


function ns.ReadyFrames_Build(addon)
	for i = 1, 3 do
		local cfg = addon.db.profile.readyFrames[i]
		if cfg.enabled and not addon.readyFrames[i] then
			ns.ReadyFrames_CreateFrame(addon, i, cfg)
		end
	end
end


function ns.ReadyFrames_CreateFrame(addon, index, cfg)
	local f = CreateFrame("Frame", "CooldownMaster_Ready_"..index, UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(200, 50)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, -100)

	if ns.Theme then
		ns.Theme.ApplyBackdrop(f,
			{ r = 0, g = 0, b = 0, a = 0.4 },
			ns.CONST.RGB.PANEL_BORDER)
	end

	local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("CENTER")
	label:SetText(cfg.frameName)
	label:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
	label:SetAlpha(addon.db.profile.global.unlockFrames and 0.6 or 0)

	addon.readyFrames[index] = f

	-- TODO: icon pool, fade animation, sound playback on ready.
end
