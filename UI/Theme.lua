--[[
	Cooldown Master - UI/Theme.lua
	Shared visual tokens and small helper widgets that match the Loot Pro look
	(image 12): dark backdrop, red headers/buttons, yellow text.
	Anything in this file is meant to be reused across the options panel and
	any custom frames we build (lanes, bars, ready frames).
--]]

local ADDON_NAME, ns = ...

ns.Theme = {}
local Theme = ns.Theme


-- Visual tokens (sizes, fonts, paddings). RGB values live in CONST.RGB so the
-- whole addon shares one source of truth.
Theme.PANEL = {
	WIDTH         = 1080,
	HEIGHT        = 640,
	HEADER_H      = 38,
	TAB_H         = 28,
	TAB_GAP       = 4,
	CONTENT_PAD   = 12,
	BUTTON_H      = 28,
}

Theme.FONT = {
	HEADER  = "GameFontNormalLarge",
	TAB     = "GameFontNormal",
	BODY    = "GameFontHighlight",
}


-- Apply a flat colored backdrop to a frame. Used everywhere we want a
-- consistent panel look without per-call boilerplate.
function Theme.ApplyBackdrop(frame, fillColor, borderColor)
	frame:SetBackdrop({
		bgFile   = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets   = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	local bg = fillColor or ns.CONST.RGB.PANEL_BG
	local bd = borderColor or ns.CONST.RGB.PANEL_BORDER
	frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
	frame:SetBackdropBorderColor(bd.r, bd.g, bd.b, bd.a)
end


-- Build a red themed button with yellow label text.
-- `parent`     - parent frame
-- `label`      - text to display
-- `width/height` - size in pixels
-- Returns the button so callers can attach OnClick handlers.
function Theme.CreateButton(parent, label, width, height)
	-- Use BackdropTemplate so SetBackdrop works on retail.
	local b = CreateFrame("Button", nil, parent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	b:SetSize(width or 100, height or Theme.PANEL.BUTTON_H)

	Theme.ApplyBackdrop(b, ns.CONST.RGB.RED, ns.CONST.RGB.PANEL_BORDER)

	local text = b:CreateFontString(nil, "OVERLAY", Theme.FONT.TAB)
	text:SetPoint("CENTER")
	text:SetText(label or "")
	text:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
	b.text = text

	-- Hover/press feedback.
	b:SetScript("OnEnter", function(self)
		local c = ns.CONST.RGB.RED_HOVER
		self:SetBackdropColor(c.r, c.g, c.b, c.a)
	end)
	b:SetScript("OnLeave", function(self)
		local c = ns.CONST.RGB.RED
		self:SetBackdropColor(c.r, c.g, c.b, c.a)
	end)
	b:SetScript("OnMouseDown", function(self)
		local c = ns.CONST.RGB.RED_DIM
		self:SetBackdropColor(c.r, c.g, c.b, c.a)
	end)
	b:SetScript("OnMouseUp", function(self)
		local c = ns.CONST.RGB.RED_HOVER
		self:SetBackdropColor(c.r, c.g, c.b, c.a)
	end)

	return b
end


-- Build a tab button. Same look as CreateButton, with a "selected" state hook
-- so the parent tab group can highlight the active tab.
function Theme.CreateTab(parent, label, width)
	local b = Theme.CreateButton(parent, label, width or 110, Theme.PANEL.TAB_H)

	function b:SetSelected(isSel)
		local c = isSel and ns.CONST.RGB.YELLOW or ns.CONST.RGB.RED
		self:SetBackdropColor(c.r, c.g, c.b, c.a)
		if isSel then
			self.text:SetTextColor(ns.CONST.RGB.RED.r, ns.CONST.RGB.RED.g, ns.CONST.RGB.RED.b)
		else
			self.text:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
		end
	end

	b:SetSelected(false)
	return b
end


-- Build a yellow header label. Use for "Cooldown Master", section titles, etc.
function Theme.CreateHeader(parent, text, fontObject)
	local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or Theme.FONT.HEADER)
	fs:SetText(text)
	fs:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
	return fs
end
