local _, ns = ...
local L = ns.L

local Settings = ns.Settings
local ui = Settings.ui

local WIDTH, HEIGHT = 600, 560
local PAD_TOP, PAD_SIDE, PAD_BOTTOM = 20, 24, 24
local HEAD_GAP, SECTION_GAP = 6, 16
local FOOTER_H, BAR_ROOM = 56, 10
local GOLD = "|cff" .. ns.CONST.HEX.YELLOW
-- A bare literal, never L[...], because the changelog's heads are English in every client
local FEATURES = "New Features"

-- Seen, announced and mode live in AceDB's account-wide db.global, so the notice fires once per account
local function globalDB()
	return ns.CDM and ns.CDM.db and ns.CDM.db.global
end

local function latest()
	local c = ns.Changelog
	return c and c[1] and c[1].version
end

local function mode()
	local g = globalDB()
	return (g and g.whatsNewMode) or "popup"
end

local function indexOf(version)
	for i, release in ipairs(ns.Changelog) do
		if release.version == version then return i end
	end
end

-- A version this build does not list comes from a newer one rolled back, which had told the player everything
local function toldUpTo(marker)
	if (marker or "") == "" then return math.huge end
	return indexOf(marker) or 1
end

-- A release either notice has covered counts as told, so a switch between popup and chat never repeats or skips one
local function unseen()
	local g = globalDB()
	local stop = math.min(toldUpTo(g.whatsNewSeen), toldUpTo(g.whatsNewAnnounced))
	local out = {}
	for i, release in ipairs(ns.Changelog) do
		if i >= stop then break end
		out[#out + 1] = release
	end
	return out
end

local function hasFeatures(list)
	for _, release in ipairs(list) do
		for _, sec in ipairs(release.sections or {}) do
			if sec.head == FEATURES then return true end
		end
	end
	return false
end

local function colorCode(name)
	local r, g, b = ui:Color(name)
	return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- A block per release, because a block measures all its lines again for every line added
local function fill(content, releases)
	local blocks = {}
	local function block()
		local b = ui:CreateTextBlock(content)
		local prev = blocks[#blocks]
		if prev then
			b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -SECTION_GAP)
			b:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -SECTION_GAP)
		else
			b:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_SIDE, -PAD_TOP)
			b:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_SIDE, -PAD_TOP)
		end
		blocks[#blocks + 1] = b
		return b
	end
	local bright, muted = colorCode("text"), colorCode("muted")
	local function lit(s) return bright .. s .. "|r" end
	local notes = block()
	notes:AddLine(L["Missed an update?"], "title")
	notes:AddLine(L["Every release's full notes live inside the addon - type %1$s, open the %2$s page, and read the Changelog there."]
		:format(lit("/cm"), lit(L["About"])), "label", { gap = HEAD_GAP })
	local several = #releases > 1
	for _, release in ipairs(releases) do
		notes = block()
		if several then
			local date = release.date and ("   " .. muted .. "(" .. release.date .. ")|r") or ""
			notes:AddLine(ns.CONST.ADDON_DISPLAY .. " " .. release.version .. date, "title")
		end
		for _, sec in ipairs(release.sections or {}) do
			notes:AddLine(sec.head or "", "groupLabel", { gap = several and HEAD_GAP or SECTION_GAP })
			for _, item in ipairs(sec.items or {}) do
				if type(item) == "string" then notes:AddLine(item, "label", { bullet = "-", gap = HEAD_GAP }) end
			end
		end
	end
	notes = block()
	notes:AddLine(L["Prefer quiet updates?"], "title")
	notes:AddLine(L["Switch these notices to a clickable chat link, or turn them off, under %1$s > %2$s > %3$s, or tick \"Don't show these again\" below."]
		:format(lit("/cm"), lit(L["Global"]), lit(L["After an update"])), "label", { gap = HEAD_GAP })
	notes:AddLine(L["Thanks for using %s!"]:format(ns.CONST.ADDON_DISPLAY), "title", { gap = SECTION_GAP })
	notes:AddLine(L["Found a bug or have an idea? Use the Discord button at the top of this window."], "label", { gap = HEAD_GAP })
	return blocks
end

local frame, pending, restoreMode

local function build(releases)
	if frame then return frame end
	local f = ui:CreateWindow({ name = "CooldownMasterWhatsNew", title = L["What's New"], width = WIDTH, height = HEIGHT })
	f:SetSection(ns.CONST.ADDON_DISPLAY .. " " .. (latest() or ""))
	f:AddHeaderButton("icon-discord", L["Join our Discord"], L["Click to copy the invite link."],
		function() ns.ShowURL(ns.DISCORD_URL) end)
	-- An ancestor hide (Alt-Z, a cinematic) fires OnHide with the window still shown, and is not a close
	f:HookScript("OnHide", function(self)
		if self:IsShown() then return end
		local g = globalDB()
		if g then g.whatsNewSeen = latest() end
	end)

	local area = ui:CreateScrollArea(f.body, {})
	area:SetPoint("TOPLEFT", f.body, "TOPLEFT")
	area:SetPoint("BOTTOMRIGHT", f.body, "BOTTOMRIGHT", 0, FOOTER_H)
	local blocks = fill(area.content, releases)

	local footer = CreateFrame("Frame", nil, f.body)
	footer:SetPoint("BOTTOMLEFT")
	footer:SetPoint("BOTTOMRIGHT")
	footer:SetHeight(FOOTER_H)
	footer._controls = {}
	ui:Paint(footer, "chrome", "divider", "T")

	f.dontShow = ui:CreateCheckbox(footer, L["Don't show these again"],
		function() return mode() == "none" end,
		function(on)
			local g = globalDB()
			if not g then return end
			-- Unticking puts back the mode the player had this session, so a chat-link player is not moved to the popup
			local m = mode()
			if on and m ~= "none" then restoreMode = m end
			g.whatsNewMode = on and "none" or restoreMode or "popup"
			Settings.Redraw()
		end,
		L["Stops What's New notices entirely. You can turn them back on under /cm > Global > After an update."])
	f.dontShow:SetPoint("LEFT", footer, "LEFT", PAD_SIDE, 0)

	f.gotIt = ui:CreateButton(footer, L["Got it"], nil, function() f:Hide() end, nil, "primary")
	f.gotIt:SetPoint("RIGHT", footer, "RIGHT", -PAD_SIDE, 0)
	f.options = ui:CreateButton(footer, L["Open Options"], nil, function()
		f:Hide()
		if ns.Options_Open then ns.Options_Open() end
	end)
	f.options:SetPoint("RIGHT", f.gotIt, "LEFT", -ui:Spacing("buttonGap"), 0)

	-- Text measured while hidden can be short of the text as drawn, so it is measured again once shown
	local function layout()
		local h = PAD_TOP + PAD_BOTTOM + SECTION_GAP * (#blocks - 1)
		for _, b in ipairs(blocks) do h = h + b:Measure() end
		local w = area.scroll:GetWidth() or 0
		if w <= 0 then w = WIDTH - BAR_ROOM end
		area:SetContentSize(w, h)
		f.gotIt:Fit()
		f.options:Fit()
	end
	layout()
	-- The Global page writes the mode too, so the box is read again on every open
	f:HookScript("OnShow", function()
		f.dontShow:Refresh()
		C_Timer.After(0, layout)
	end)
	frame = f
	return f
end

local function show(releases)
	local f = build(releases)
	f:Show()
	-- Over the settings window, whose Global page opens it
	f:Raise()
end

function ns.WhatsNew_Show()
	if not latest() then return end
	local list = pending or unseen()
	if #list == 0 then list = { ns.Changelog[1] } end
	show(list)
end

function ns.WhatsNew_Refresh()
	if frame and frame:IsShown() then frame.dontShow:Refresh() end
end

local LINK = "addon:" .. ns.CONST.ADDON_NAME .. ":whatsnew"

-- The game hands an addon link to SetItemRef and draws nothing for it, so a click on ours opens the notes here
hooksecurefunc("SetItemRef", function(link)
	if link == LINK then ns.WhatsNew_Show() end
end)

local function announce(list)
	pending = list
	local link = "|H" .. LINK .. "|h" .. GOLD .. L["[See what's new]"] .. "|r|h"
	DEFAULT_CHAT_FRAME:AddMessage(L["%1$s updated to %2$s - %3$s"]:format(GOLD .. ns.CONST.ADDON_DISPLAY .. "|r", latest(), link))
	globalDB().whatsNewAnnounced = latest()
end

function ns.WhatsNew_OnLogin()
	local g, v = globalDB(), latest()
	if not (g and v) then return end
	-- A first install has no notes to catch up on, and the welcome line in chat greets the player
	if (g.whatsNewSeen or "") == "" and (g.whatsNewAnnounced or "") == "" then
		g.whatsNewSeen, g.whatsNewAnnounced = v, v
		return
	end
	C_Timer.After(3, function()
		local m, list = mode(), unseen()
		-- A release with only fixes waits unmarked, so the next one with new features lists it too
		if m == "none" or not hasFeatures(list) then return end
		if m == "chat" then announce(list) else show(list) end
	end)
end
