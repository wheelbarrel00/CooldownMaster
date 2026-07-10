local ADDON_NAME, ns = ...

-- Seen/announced/mode live in AceDB's account-wide `db.global` scope (NOT the addon's
-- per-profile `db.profile.global` table), so the notice fires once per account, not once
-- per alt or profile. Nil is treated as the default the same way XLoot/EverythingQuests do.
local function GlobalDB()
	return ns.CDM and ns.CDM.db and ns.CDM.db.global
end

local function Latest()
	return ns.Changelog and ns.Changelog[1] and ns.Changelog[1].version
end

local function CurrentMode()
	local g = GlobalDB()
	return (g and g.whatsNewMode) or "popup"
end

local function AlreadySeen()
	local g = GlobalDB()
	return g and g.whatsNewSeen == Latest()
end

local function MarkSeen()
	local g = GlobalDB()
	if g then g.whatsNewSeen = Latest() end
end

local function AlreadyAnnounced()
	local g = GlobalDB()
	return g and g.whatsNewAnnounced == Latest()
end

local function MarkAnnounced()
	local g = GlobalDB()
	if g then g.whatsNewAnnounced = Latest() end
end


-- Releases newer than the last one dismissed, newest first. Fresh install (or already
-- caught up but opened by hand) shows just the latest so the popup is never empty.
local function UnseenReleases()
	local seen = GlobalDB() and GlobalDB().whatsNewSeen
	if not seen or seen == "" then
		return { ns.Changelog[1] }
	end
	local out = {}
	for _, release in ipairs(ns.Changelog) do
		if release.version == seen then break end
		out[#out + 1] = release
	end
	if #out == 0 then out[1] = ns.Changelog[1] end
	return out
end


local HEX   = ns.CONST.HEX
local GOLD  = "|cff" .. HEX.YELLOW
local WHITE = "|cff" .. HEX.WHITE
local GREY  = "|cff" .. HEX.GREY
local STOP  = "|r"

local function BuildBody(releases)
	local blocks = {
		GOLD .. "Missed an update?" .. STOP .. "\n"
			.. "Every release's full notes live inside the addon - type " .. WHITE .. "/cm" .. STOP
			.. ", open the " .. WHITE .. "About" .. STOP .. " tab, and read the Changelog there.",
	}
	local showVersions = #releases > 1
	for _, rel in ipairs(releases) do
		if showVersions then
			local head = WHITE .. ns.CONST.ADDON_DISPLAY .. " " .. rel.version .. STOP
			if rel.date then head = head .. "  " .. GREY .. "(" .. rel.date .. ")" .. STOP end
			blocks[#blocks + 1] = head
		end
		for _, sec in ipairs(rel.sections or {}) do
			local lines = { GOLD .. sec.head .. STOP }
			for _, item in ipairs(sec.items or {}) do
				lines[#lines + 1] = WHITE .. "- " .. item .. STOP
			end
			blocks[#blocks + 1] = table.concat(lines, "\n")
		end
	end
	blocks[#blocks + 1] = GOLD .. "Prefer quiet updates?" .. STOP .. "\n"
		.. "Switch these notices to a clickable chat link, or turn them off, under "
		.. WHITE .. "/cm" .. STOP .. " > " .. WHITE .. "Global" .. STOP .. " > "
		.. WHITE .. "After an update" .. STOP .. ", or tick \"Don't show these again\" below."
	blocks[#blocks + 1] = GOLD .. "Thanks for using " .. ns.CONST.ADDON_DISPLAY .. "!" .. STOP .. "\n"
		.. "Found a bug or have an idea? Use the Discord button below."
	return table.concat(blocks, "\n\n")
end


local function AnnounceChat()
	local link = "|Haddon:" .. ns.CONST.ADDON_NAME .. ":whatsnew|h"
		.. GOLD .. "[See what's new]" .. STOP .. "|h"
	DEFAULT_CHAT_FRAME:AddMessage(GOLD .. ns.CONST.ADDON_DISPLAY .. STOP
		.. " updated to " .. (Latest() or "?") .. " - " .. link)
end

-- Custom chat hyperlink (|Haddon:CooldownMaster:whatsnew|h); the client ignores the unknown
-- link type, so we open the popup ourselves when ours is clicked.
local WHATSNEW_LINK = "addon:" .. ns.CONST.ADDON_NAME .. ":whatsnew"
hooksecurefunc("SetItemRef", function(link)
	if link == WHATSNEW_LINK then
		ns.WhatsNew_Show()
	end
end)


local frame
local function Build()
	if frame then return frame end

	local releases = UnseenReleases()

	local f = CreateFrame("Frame", "CooldownMasterWhatsNew", UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(560, 500)
	f:SetPoint("CENTER")
	-- Above the options window's HIGH strata so it isn't hidden behind it.
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)
	f:Hide()
	ns.Theme.ApplyBackdrop(f)

	local YELLOW = ns.CONST.RGB.YELLOW
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)
	title:SetText("What's New in " .. ns.CONST.ADDON_DISPLAY
		.. (#releases == 1 and (" " .. releases[1].version) or ""))

	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 14, -44)
	scroll:SetPoint("BOTTOMRIGHT", -34, 84)
	local body = CreateFrame("Frame", nil, scroll)
	body:SetSize(scroll:GetWidth(), 1)
	scroll:SetScrollChild(body)
	local text = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("TOPLEFT", 0, 0)
	text:SetPoint("TOPRIGHT", 0, 0)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	text:SetSpacing(3)
	text:SetText(BuildBody(releases))
	body:SetHeight(text:GetStringHeight() + 12)

	-- Mark seen on an explicit close (button, X, or Escape) but NOT when an ancestor hide
	-- (cinematic, Alt-Z) fires OnHide while our own shown flag is still set.
	f:SetScript("OnHide", function(self) if not self:IsShown() then MarkSeen() end end)
	table.insert(UISpecialFrames, "CooldownMasterWhatsNew")

	local function dismiss() f:Hide() end

	f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	f.close:SetPoint("TOPRIGHT", -4, -4)
	f.close:SetScript("OnClick", dismiss)

	f.dontShow = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	f.dontShow:SetSize(22, 22)
	f.dontShow:SetPoint("BOTTOMLEFT", 16, 50)
	f.dontShow.text = f.dontShow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.dontShow.text:SetPoint("LEFT", f.dontShow, "RIGHT", 2, 0)
	f.dontShow.text:SetText("Don't show these again")
	f.dontShow.text:SetTextColor(0.7, 0.7, 0.7)
	f.dontShow:SetScript("OnShow", function(self)
		local m = CurrentMode()
		-- Remember the non-"none" mode so unchecking restores it (a chat-link user keeps
		-- "chat" instead of being silently reset to "popup").
		if m ~= "none" then self._prevMode = m end
		self:SetChecked(m == "none")
	end)
	f.dontShow:SetScript("OnClick", function(self)
		local g = GlobalDB()
		if not g then return end
		if self:GetChecked() then
			g.whatsNewMode = "none"
		else
			g.whatsNewMode = (self._prevMode and self._prevMode ~= "none" and self._prevMode) or "popup"
		end
	end)
	f.dontShow:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Stops What's New notices entirely. You can turn them back on under /cm > Global > After an update.", 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	f.dontShow:SetScript("OnLeave", function() GameTooltip:Hide() end)

	f.optBtn = ns.Theme.CreateButton(f, "Open Options", 150, 28)
	f.optBtn:SetPoint("BOTTOMLEFT", 16, 14)
	f.optBtn:SetScript("OnClick", function()
		dismiss()
		if ns.Options_Open then ns.Options_Open() end
	end)

	f.gotBtn = ns.Theme.CreateButton(f, "Got it", 120, 28)
	f.gotBtn:SetPoint("BOTTOMRIGHT", -16, 14)
	f.gotBtn:SetScript("OnClick", dismiss)

	f.discordBtn = ns.Theme.CreateButton(f, "Join our Discord", 150, 28)
	f.discordBtn:SetPoint("BOTTOM", 0, 14)
	f.discordBtn:SetScript("OnClick", function() ns.ShowURL(ns.DISCORD_URL) end)

	frame = f
	return f
end


function ns.WhatsNew_Show()
	Build():Show()
end


-- Called once at login (CDM:OnPlayerLogin). Popup or a quiet chat link on a version bump,
-- unless the player switched it off.
function ns.WhatsNew_OnLogin()
	if not Latest() then return end
	local mode = CurrentMode()
	if mode == "none" then return end
	local isChat = (mode == "chat")
	if (isChat and AlreadyAnnounced()) or (not isChat and AlreadySeen()) then return end
	C_Timer.After(3, function()
		local cur = CurrentMode()
		if cur == "none" then return end
		if cur == "chat" then
			if not AlreadyAnnounced() then
				AnnounceChat()
				MarkAnnounced()
			end
		elseif not AlreadySeen() then
			ns.WhatsNew_Show()
		end
	end)
end
