local _, ns = ...

ns.Theme = {}
local Theme = ns.Theme


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
