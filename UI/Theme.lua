local ADDON_NAME, ns = ...

ns.Theme = {}
local Theme = ns.Theme


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


function Theme.CreateButton(parent, label, width, height)
	-- BackdropTemplate is required for SetBackdrop to work on retail.
	local b = CreateFrame("Button", nil, parent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	b:SetSize(width or 100, height or Theme.PANEL.BUTTON_H)

	Theme.ApplyBackdrop(b, ns.CONST.RGB.RED, ns.CONST.RGB.PANEL_BORDER)

	local text = b:CreateFontString(nil, "OVERLAY", Theme.FONT.TAB)
	text:SetPoint("CENTER")
	text:SetText(label or "")
	text:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
	b.text = text

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


function Theme.CreateHeader(parent, text, fontObject)
	local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or Theme.FONT.HEADER)
	fs:SetText(text)
	fs:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
	return fs
end
