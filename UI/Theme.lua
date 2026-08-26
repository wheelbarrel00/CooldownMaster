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


-- Shared across every themed frame. SetBackdrop reads it at call time, so it must stay invariant.
local BACKDROP = {
	bgFile   = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Buttons\\WHITE8x8",
	edgeSize = 1,
	insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

function Theme.ApplyBackdrop(frame, fillColor, borderColor)
	frame:SetBackdrop(BACKDROP)
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

	-- A selected tab (CreateTab sets _selected) keeps its yellow highlight through hover and press.
	-- Without this they repaint it red under the selected red text. Inert for ordinary buttons.
	b:SetScript("OnEnter", function(self)
		if self._selected then return end
		local c = ns.CONST.RGB.RED_HOVER
		self:SetBackdropColor(c.r, c.g, c.b, c.a)
	end)
	b:SetScript("OnLeave", function(self)
		local c = self._selected and ns.CONST.RGB.YELLOW or ns.CONST.RGB.RED
		self:SetBackdropColor(c.r, c.g, c.b, c.a)
	end)
	b:SetScript("OnMouseDown", function(self)
		if self._selected then return end
		local c = ns.CONST.RGB.RED_DIM
		self:SetBackdropColor(c.r, c.g, c.b, c.a)
	end)
	b:SetScript("OnMouseUp", function(self)
		if self._selected then return end
		local c = ns.CONST.RGB.RED_HOVER
		self:SetBackdropColor(c.r, c.g, c.b, c.a)
	end)

	return b
end


function Theme.CreateTab(parent, label, width)
	local b = Theme.CreateButton(parent, label, width or 110, Theme.PANEL.TAB_H)

	function b:SetSelected(isSel)
		self._selected = isSel and true or false
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


local STANDARD_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local fontProbe
local fontPathOK = {}
local fontPathBad = {}
local FONT_RETRY_AFTER = 5

-- An LSM name stays registered after the addon that registered it is uninstalled, so the path can
-- point at a missing file - and SetFont THROWS on a missing asset rather than failing quietly.
function ns.FontPathLoads(path)
	if not path or path == "" then return false end
	if fontPathOK[path] then return true end
	-- A failure is not cached outright (an early probe can fail for a face that loads a moment
	-- later), but StyleBar reaches this on the engine tick, so back off between retries.
	local failedAt = fontPathBad[path]
	if failedAt and (GetTime() - failedAt) < FONT_RETRY_AFTER then return false end
	if not fontProbe then
		fontProbe = UIParent:CreateFontString(nil, "BACKGROUND")
		fontProbe:Hide()
	end
	-- SetFont also fails by returning false, and the probe keeps its previous font when it does,
	-- so a bare GetFont() ~= nil would read the last good path back as this one's success.
	local ok, applied = pcall(fontProbe.SetFont, fontProbe, path, 12, "")
	ok = ok and applied ~= false and fontProbe:GetFont() == path
	if ok then
		fontPathOK[path] = true
		fontPathBad[path] = nil
	else
		fontPathBad[path] = GetTime()
	end
	return ok
end


function ns.FontPath(fontName)
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	local path = LSM and LSM:Fetch("font", fontName, true)
	if path and ns.FontPathLoads(path) then return path end
	return STANDARD_FONT
end
