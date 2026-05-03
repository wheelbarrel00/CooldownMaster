--[[
	Cooldown Master - UI/BarFrames.lua
	Status-bar style cooldown frames (Bar Frame 1/2/3).
	v0.1 status: stub. Builds disabled-by-default frames; renderer follows.
--]]

local ADDON_NAME, ns = ...


function ns.BarFrames_Build(addon)
	for i = 1, 3 do
		local cfg = addon.db.profile.barFrames[i]
		if cfg.enabled and not addon.barFrames[i] then
			ns.BarFrames_CreateFrame(addon, i, cfg)
		end
	end
end


function ns.BarFrames_CreateFrame(addon, index, cfg)
	local f = CreateFrame("Frame", "CooldownMaster_BarFrame_"..index, UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(200, 100)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

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

	addon.barFrames[index] = f

	-- TODO: status bar pool, transition animation, indicator line/texture.
end
