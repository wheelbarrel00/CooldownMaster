local _, ns = ...
local L = ns.L

local Settings = ns.Settings
local ui = Settings.ui

local state = { index = 1 }
Settings.ready = state

local function box()
	return ns.CDM.db.profile.readyFrames[state.index]
end

local function apply()
	if ns.ReadyFrames_ApplyConfig then ns.ReadyFrames_ApplyConfig(state.index) end
end

local B = Settings.Binder(box, apply)
-- A box reads its timing, sounds and highlight as each icon pops, so those settings push nothing
local Q = Settings.Binder(box)
local key, sub, color = B.key, B.sub, B.color
local dims, slider, textField = Settings.Dims, Settings.Slider, Settings.TextField

local soundCache = {}

-- Built again only when LibSharedMedia's sound list grows, as the other media lists are
local function sounds()
	local LSM = LibStub("LibSharedMedia-3.0", true)
	local list = LSM and LSM:List("sound") or {}
	if soundCache.list ~= list or soundCache.count ~= #list then
		local opts = { { value = "None", label = L["None"] } }
		for _, s in ipairs(ns.READY_BUILTIN_SOUNDS or {}) do opts[#opts + 1] = { value = s.name, label = s.name } end
		for _, name in ipairs(list) do
			if name ~= "None" then opts[#opts + 1] = { value = name, label = name } end
		end
		soundCache.list, soundCache.count, soundCache.opts = list, #list, opts
	end
	return soundCache.opts
end

local function preview(v)
	if ns.ReadyFrames_PreviewSound then ns.ReadyFrames_PreviewSound(v) end
end

local function buildGeneral(self, content)
	local push = Settings.CardStack()
	local card = push(self:CreateGroup(content, nil))
	local get, set = key("frameName")
	card:Add(textField(self, content, L["Frame Name"], get, set, nil, 32))
	card:Add(self:CreateCheckbox(content, L["Enabled"], function() return box().enabled end, function(v)
		box().enabled = v
		if ns.ReadyFrames_RebuildOne then ns.ReadyFrames_RebuildOne(state.index) end
	end))
	get, set = key("growDirection", "DOWN")
	card:Add(self:CreateDropdown(content, L["Grow Direction"], Settings.GROW, get, set))
	get, set = Q.key("normalDuration", 5)
	card:Add(slider(self, content, L["Display Duration (sec)"], 1, 20, 1, get, set,
		L["How long an ordinary icon stays in this box before it fades. An Important one stays for its Highlight Duration instead, and a Pinned one never fades."]))
	get, set = Q.key("pTime", 0)
	card:Add(slider(self, content, L["Post-Combat Hide (sec, 0 = off)"], 0, 30, 1, get, set,
		L["Clears this box this many seconds after combat ends or after the latest pop, whichever comes later, so icons left over from a fight do not sit out their full Display Duration. Pops out of combat count too, so a value shorter than Display Duration cuts those short. Pinned icons stay. 0 turns it off."]))
	get, set = Q.key("maxIcons", 10)
	card:Add(slider(self, content, L["Max Ready Icons"], 1, 10, 1, get, set,
		L["How many icons this box holds at once. When it is full, the icon closest to fading makes room for the new one. A Pinned icon is never the one pushed out, so a box full of Pinned icons drops new pops."]))
	get, set = Q.key("normalSound", "None")
	card:Add(self:CreateDropdown(content, L["Ready Sound"], sounds, get, set, nil, nil, preview))
	content._sync = function() end
end

local function buildAppearance(self, content)
	local push = Settings.CardStack()
	local deps = {}
	local function sync() content._sync() end

	local card = push(self:CreateGroup(content, nil))
	local lim = Settings.OffsetLimit()
	local get, set = key("x", 0)
	local x = slider(self, content, L["X Offset"], -lim, lim, 1, get, set)
	card:Add(x)
	get, set = key("y", 0)
	local y = slider(self, content, L["Y Offset"], -lim, lim, 1, get, set)
	card:Add(y)
	get, set = key("anchor", "CENTER")
	card:Add(self:CreateDropdown(content, L["Anchor"], Settings.ANCHORS, get, set,
		L["Screen point the box is pinned to, then nudged by the X and Y offsets above. Also the point the ready icons grow out from."]))
	get, set = key("alpha", 1)
	card:Add(slider(self, content, L["Box Alpha"], 0, 1, 0.05, get, set,
		L["Fades the whole box, its background, border and icons together. Transparency under Icons fades only the icons."]))

	card = push(self:CreateGroup(content, L["Background"]))
	get, set = key("bgTexture")
	card:Add(Settings.TextureDropdown(self, content, L["Texture"], get, set))
	get, set = color("bgColor")
	card:Add(self:CreateColorPicker(content, L["Background Color"], get, set, nil, true))

	card = push(self:CreateGroup(content, L["Border"]))
	get, set = key("borderEnabled", true, sync)
	card:Add(self:CreateCheckbox(content, L["Show Border"], get, set))
	get, set = key("borderTexture")
	local tex = Settings.EdgeDropdown(self, content, L["Border Texture"], get, set)
	get, set = color("borderColor")
	local col = self:CreateColorPicker(content, L["Border Color"], get, set, nil, true)
	get, set = key("borderPadding", 0)
	local padding = slider(self, content, L["Border Padding"], 0, 40, 1, get, set)
	get, set = key("borderSize", 1)
	local size = slider(self, content, L["Border Size"], 1, 40, 1, get, set)
	for _, c in ipairs({ tex, col, padding, size }) do
		card:Add(c, { dependent = true })
		deps[#deps + 1] = { c, function() return box().borderEnabled ~= false end }
	end

	content._sync = function()
		local l = Settings.OffsetLimit()
		x.SetRange(-l, l)
		y.SetRange(-l, l)
		dims(deps)
	end
end

local function newIconLabel() return { enabled = false, text = "[cd.name]", anchor = "CENTER" } end

local function buildIcons(self, content)
	local push = Settings.CardStack()
	local deps = {}
	local function sync() content._sync() end

	local card = push(self:CreateGroup(content, nil))
	local get, set = key("iconSize", 1)
	card:Add(slider(self, content, L["Size"], 1, 128, 1, get, set))
	get, set = key("iconAlpha", 1)
	card:Add(slider(self, content, L["Transparency"], 0, 1, 0.05, get, set))
	get, set = key("iconOffset", 0)
	card:Add(slider(self, content, L["Icon Offset"], -30, 30, 1, get, set))
	get, set = key("yPadding", 0)
	card:Add(slider(self, content, L["Spacing"], 0, 40, 1, get, set))

	card = push(self:CreateGroup(content, L["Icon Border"]))
	get, set = key("iconBorder", false, sync)
	card:Add(self:CreateCheckbox(content, L["Show Icon Border"], get, set,
		L["Draw a clean solid border around each ready icon in this box. Set per box. On by default."]))
	get, set = key("iconBorderSize", 1)
	local bSize = slider(self, content, L["Border Size"], 1, 6, 1, get, set)
	get, set = color("iconBorderColor", { r = 0, g = 0, b = 0, a = 1 })
	local bColor = self:CreateColorPicker(content, L["Border Color"], get, set, nil, true)
	for _, c in ipairs({ bSize, bColor }) do
		card:Add(c, { dependent = true })
		deps[#deps + 1] = { c, function() return box().iconBorder end }
	end

	card = push(self:CreateGroup(content, L["Icon Label"]))
	get, set = sub("iconLabel", "enabled", false, newIconLabel, sync)
	card:Add(self:CreateCheckbox(content, L["Show Label"], get, set,
		L["Draw a line of text on each ready icon in this box, built from the tags in Label Text below. Off by default - a ready icon is otherwise just art, so this is how you name what came up."]))
	local getText, setText = sub("iconLabel", "text", "", newIconLabel)
	local text = textField(self, content, L["Label Text"], getText, setText, ns.TAG_HELP, 120)
	local tags = Settings.TagRow(self, content, card, ns.TAG_PICKER_READY, text, getText, setText)
	get, set = sub("iconLabel", "anchor", "CENTER", newIconLabel)
	local anchor = self:CreateDropdown(content, L["Label Position"], Settings.LABEL_ANCHORS, get, set,
		L["Where the label sits on the icon. On icon draws it over the art."])
	get, set = key("iconLabelFont")
	local font = Settings.FontDropdown(self, content, L["Label Font"], get, set)
	get, set = key("iconLabelSize", 10)
	local size = slider(self, content, L["Label Size"], 6, 32, 1, get, set)
	get, set = key("iconLabelFlags", "OUTLINE")
	local flags = self:CreateDropdown(content, L["Label Outline"], Settings.FONT_FLAGS, get, set)
	get, set = color("iconLabelColor", { r = 1, g = 1, b = 1, a = 1 })
	local col = self:CreateColorPicker(content, L["Label Color"], get, set, nil, true)
	local on = sub("iconLabel", "enabled", false, newIconLabel)
	for _, c in ipairs({ text, tags, anchor, font, size, flags, col }) do
		card:Add(c, { dependent = true })
		deps[#deps + 1] = { c, on }
	end

	content._sync = function() dims(deps) end
end

local function buildText(self, content)
	local push = Settings.CardStack()
	local deps = {}
	local function sync() content._sync() end
	local gold = { r = 0.9216, g = 0.7176, b = 0.0235, a = 1 }
	Settings.FontCard(self, content, push, B, L["Name Tag Font"], "label", { size = 12, flags = "OUTLINE", color = gold },
		L["Font for this box's name tag (shown above the box while frames are unlocked)."])
	Settings.StatusCard(self, content, push, B, deps, sync)
	content._sync = function() dims(deps) end
end

local function buildHighlight(self, content)
	local push = Settings.CardStack()
	local deps = {}
	local function sync() content._sync() end
	local title = L["Highlight (Important spells)"]
	local card = push(self:CreateGroup(content, title))
	self:AttachTooltip(card.label, title,
		L["Applies to spells flagged Important under Filters. Important spells use the hold and sound below instead of the normal ones."])
	local styleGet, styleSet, colorGet, colorSet, styled = Q.highlight("BORDER", { r = 1, g = 0.82, b = 0, a = 0.6 }, sync)
	card:Add(self:CreateDropdown(content, L["Highlight Style"], Settings.HIGHLIGHTS, styleGet, styleSet,
		L["Visual emphasis drawn on icons flagged Important (per spell, in Filters). Border draws a still outline, Flash makes it pulse, and None turns it off."]))
	local hlColor = self:CreateColorPicker(content, L["Highlight Color"], colorGet, colorSet, nil, true)
	card:Add(hlColor, { dependent = true })
	deps[#deps + 1] = { hlColor, styled }
	local get, set = Q.key("highlightDuration", 10)
	card:Add(slider(self, content, L["Highlight Duration (sec)"], 1, 30, 1, get, set))
	get, set = Q.key("highlightSound", "None")
	card:Add(self:CreateDropdown(content, L["Highlight Sound"], sounds, get, set, nil, nil, preview))
	content._sync = function() dims(deps) end
end

ui:RegisterTab({ id = "ready", title = L["Ready"], order = 30, icon = Settings.Icon("icon-ready"), group = true })

local strip = Settings.Strip(state, L["Box %d"], function(i)
	local c = ns.CDM.db.profile.readyFrames[i]
	return c and c.enabled
end)

for i, page in ipairs({
	{ "general",    L["General"],    buildGeneral },
	{ "appearance", L["Appearance"], buildAppearance },
	{ "icons",      L["Icons"],      buildIcons },
	{ "text",       L["Text"],       buildText },
	{ "highlight",  L["Highlight"],  buildHighlight },
}) do
	ui:RegisterTab({
		id      = "ready." .. page[1],
		parent  = "ready",
		title   = page[2],
		order   = i,
		header  = strip,
		footer  = Settings.Footer,
		build   = page[3],
		refresh = function(_, content) content._sync() end,
	})
end
