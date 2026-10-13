local _, ns = ...
local L = ns.L

local Settings = ns.Settings
local ui = Settings.ui

local GITHUB_URL   = "https://github.com/wheelbarrel00/CooldownMaster"
local BUG_URL      = "https://github.com/wheelbarrel00/CooldownMaster/issues"
local RELEASES_URL = "https://github.com/wheelbarrel00/CooldownMaster/releases"

local COMMANDS = {
	{ cmd = "/cm",          desc = L["Open or close the options window (or /cdmaster)"] },
	{ cmd = "/cm lock",     desc = L["Lock the lane frames"] },
	{ cmd = "/cm unlock",   desc = L["Unlock the lane frames for moving"] },
	{ cmd = "/cm test",     desc = L["Toggle sample cooldowns (set them up in Global > Test Mode)"] },
	{ cmd = "/cm reset",    desc = L["Reset the current profile to defaults"] },
	{ cmd = "/cm version",  desc = L["Print the version and game flavor"] },
	{ cmd = "/cm whatsnew", desc = L["Reopen the What's New window"] },
}

local OTHER_ADDONS = {
	{ name = "Everything Quests",
	  cf   = "https://www.curseforge.com/wow/addons/everything-quests",
	  gh   = "https://github.com/wheelbarrel00/EverythingQuests" },
	{ name = "EQ Objective Tracker",
	  cf   = "https://www.curseforge.com/wow/addons/eq-objective-tracker",
	  gh   = "https://github.com/wheelbarrel00/EQObjectiveTracker" },
	{ name = "Everything Delves",
	  cf   = "https://www.curseforge.com/wow/addons/everything-delves",
	  gh   = "https://github.com/wheelbarrel00/EverythingDelves" },
	{ name = "Loot Pro",
	  cf   = "https://www.curseforge.com/wow/addons/loot-pro",
	  gh   = "https://github.com/wheelbarrel00/LootPro" },
}

local TRANSLATORS = {
	{ name = "Zox",        line = L["Thanks to %s, who translated my other addons into French."] },
	{ name = "Malevi4",    line = L["Thanks to %s, who translated my other addons into Russian."] },
	{ name = "labrie75",   line = L["Thanks to %s, who translated my other addons into Korean."] },
	{ name = "Keriaovo",   line = L["Thanks to %s, who translated my other addons into Simplified Chinese."] },
	{ name = "BNS333",     line = L["Thanks to %s, who translated my other addons into Traditional Chinese."] },
	{ name = "Stonetwist", line = L["Thanks to %s, who translated my other addons into German."] },
}

local function colorCode(name)
	local r, g, b = ui:Color(name)
	return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- The translated text carries gold color codes, which the window's own colors replace
local function uncolored(s)
	return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function introCard(self, content, push)
	local card = push(self:CreateGroup(content, nil))
	local block = self:CreateTextBlock(content)
	block:AddLine(ns.CONST.ADDON_DISPLAY, "title")
	block:AddLine(ns.CONST.VERSION .. "    " .. L["by %s"]:format("Wheelbarrel00") .. "    -    " .. ns.Compat.FlavorLabel(), "hint")
	block:AddLine(ns.Compat.HAS_BLIZZ_CDM
		and L["A timeline-style lane cooldown tracker that complements Blizzard's built-in Cooldown Manager."]
		or L["A timeline-style lane cooldown tracker for your spells, items, and buffs."])
	card:Add(block, { fitHeight = true })
	Settings.ButtonRow(self, content, card, {
		{ L["Join our Discord"], function() ns.ShowURL(ns.DISCORD_URL) end },
		{ L["GitHub"], function() ns.ShowURL(GITHUB_URL) end },
		{ L["Report a Bug"], function() ns.ShowURL(BUG_URL) end },
	})
end

local function commandsCard(self, content, push)
	local card = push(self:CreateGroup(content, L["Commands"]))
	for _, c in ipairs(COMMANDS) do
		local row = self:CreateTextRow(content, c.cmd, c.desc)
		row.label:SetTextColor(ui:Color("text"))
		card:Add(row, { height = ui:Spacing("listRowHeight") })
	end
	local tip = self:CreateTextBlock(content)
	tip:AddLine(L["Tip: left-click the minimap button to open Options, right-click to lock or unlock frames."], "hint")
	card:Add(tip, { fitHeight = true })
end

local function noteCard(self, content, push, title, lines, style)
	local card = push(self:CreateGroup(content, title))
	for _, text in ipairs(lines) do
		local block = self:CreateTextBlock(content)
		block:AddLine(text, style)
		card:Add(block, { fitHeight = true })
	end
end

local function addonsCard(self, content, push)
	local card = push(self:CreateGroup(content, L["More Add-ons by Wheelbarrel00"]))
	for _, a in ipairs(OTHER_ADDONS) do
		local row = self:CreateTextRow(content, a.name, "")
		row.label:SetTextColor(ui:Color("text"))
		card:Add(row)
		-- On the row's text column, which the card moves past its widest name in any client font
		local cf = self:CreateButton(content, L["CurseForge"], nil, function() ns.ShowURL(a.cf) end, nil, "ghost")
		cf:SetPoint("LEFT", row.text, "LEFT", 0, 0)
		local gh = self:CreateButton(content, L["GitHub"], nil, function() ns.ShowURL(a.gh) end, nil, "ghost")
		gh:SetPoint("LEFT", cf, "RIGHT", ui:Spacing("buttonGap"), 0)
	end
end

local function translationLines()
	local bright = colorCode("text")
	local lines = { L["Cooldown Master shares part of its text with my other addons, and those phrases are the work of the translators below. The rest was written in-house in their style and with their permission, so anything wrong in it is my mistake and not theirs. Corrections are very welcome."] }
	-- |r falls back to the line's own color, so only the name needs an escape
	for _, t in ipairs(TRANSLATORS) do lines[#lines + 1] = t.line:format(bright .. t.name .. "|r") end
	return lines
end

local function changelogCard(self, content, push)
	local card = push(self:CreateGroup(content, L["Changelog"]))
	local muted = colorCode("muted")
	-- A raise here would leave the window blank, so an entry or a line the changelog got wrong is skipped
	for _, entry in ipairs(ns.Changelog or {}) do
		if type(entry.version) == "string" then
			local block = self:CreateTextBlock(content)
			block:AddLine(entry.version .. "   " .. muted .. (entry.date or "") .. "|r", "value")
			for _, sec in ipairs(entry.sections or {}) do
				block:AddLine(sec.head or "", "groupLabel", { gap = 10 })
				for _, item in ipairs(sec.items or {}) do
					if type(item) == "string" then block:AddLine(item, "label", { bullet = "-" }) end
				end
			end
			card:Add(block, { fitHeight = true })
		end
	end
	Settings.ButtonRow(self, content, card, { { L["Older versions are on GitHub"], function() ns.ShowURL(RELEASES_URL) end } }, "ghost")
end

ui:RegisterTab({
	id    = "about",
	title = L["About"],
	order = 80,
	icon  = ui:Texture("icon-about"),
	build = function(self, content)
		local push = Settings.CardStack()
		introCard(self, content, push)
		commandsCard(self, content, push)
		noteCard(self, content, push, L["Tutorials"], { L["Video tutorials are coming soon."] }, "hint")
		addonsCard(self, content, push)
		noteCard(self, content, push, L["Credits"], { uncolored(L["Cooldown Master carries forward the idea behind |cffEBB706%1$s|r by |cffEBB706%2$s|r - the timeline-cooldown addon that inspired this one. After Midnight changed how cooldowns work, I rebuilt the concept from the ground up for 12.0 with his blessing. Full credit for the original timeline-cooldown idea goes to him. Thank you, cliffclive."]:format("CooldownTimeline2 (CDTL2)", "cliffclive")) })
		noteCard(self, content, push, L["Translations"], translationLines())
		noteCard(self, content, push, L["Thanks"], { L["Built with feedback, reports, and ideas from the community. Thank you!"] })
		changelogCard(self, content, push)
	end,
})
