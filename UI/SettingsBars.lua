local _, ns = ...
local L = ns.L

local Settings = ns.Settings
local ui = Settings.ui

local state = { index = 1 }
Settings.bars = state

local function frame()
	return ns.CDM.db.profile.barFrames[state.index]
end

local function apply()
	if ns.Bars_ApplyConfig then ns.Bars_ApplyConfig(state.index) end
	if ns.Bars_Refresh then ns.Bars_Refresh(state.index) end
end

local B = Settings.Binder(frame, apply)
local key, color = B.key, B.color
local dims, slider = Settings.Dims, Settings.Slider

local SORT = {
	{ value = "DESCENDING", label = L["Longest first"] },
	{ value = "ASCENDING",  label = L["Shortest first"] },
}

local ICON_SIDES = {
	{ value = "LEFT",  label = L["Left"] },
	{ value = "RIGHT", label = L["Right"] },
}

-- Bars.lua restyles the number only where the cooldown widget has SetCountdownFont, so the rows follow the same test.
local function canStyleCountdown()
	if Settings.countdownFont == nil then
		local probe = CreateFrame("Cooldown")
		probe:Hide()
		Settings.countdownFont = probe.SetCountdownFont ~= nil
	end
	return Settings.countdownFont
end

local function buildGeneral(self, content)
	local push = Settings.CardStack()
	local card = push(self:CreateGroup(content, nil))
	local get, set = key("frameName")
	card:Add(Settings.TextField(self, content, L["Frame Name"], get, set, nil, 32))
	card:Add(self:CreateCheckbox(content, L["Enabled"], function() return frame().enabled end, function(v)
		frame().enabled = v
		if ns.Bars_RebuildOne then ns.Bars_RebuildOne(state.index) end
	end))
	get, set = key("growDirection", "UP")
	card:Add(self:CreateDropdown(content, L["Grow Direction"], Settings.GROW, get, set,
		L["Direction the bars stack as more cooldowns become active."]))
	get, set = key("sortDir", "DESCENDING")
	card:Add(self:CreateDropdown(content, L["Sort Order"], SORT, get, set,
		L["Longest first puts the cooldown with the most time left at the start of the grow direction."]))
	get, set = key("maxBars", 10)
	card:Add(slider(self, content, L["Max Bars"], 1, 20, 1, get, set, L["Cap on how many bars this frame shows at once."]))
	get, set = key("showLongCooldowns", false)
	card:Add(self:CreateCheckbox(content, L["Show Extremely Long Cooldowns"], get, set,
		L["Lets this frame show cooldowns up to 60 minutes long, ignoring the Ignore Threshold that keeps them off your lanes. Anything shorter than 60 minutes is covered too, not only the very longest. It applies to this bar frame alone, so your lanes and ready boxes are unaffected, and a cooldown you hid by hand on its Filters row stays hidden. Tick it on the frame your cooldowns actually go to, which is set by Default Bar under Filters, and make sure that frame is enabled under Bars. Bear in mind an hour-long bar keeps its place in the list for the whole hour, so raise Max Bars or give it a frame of its own."]))
	get, set = key("handOffBelow", 0)
	-- Ceiling matches the lane Max Time slider: a hand-off above that has no lane that could catch it
	card:Add(slider(self, content, L["Hand Off Below (sec)"], 0, 360, 5, get, set,
		L["This frame lets go of a cooldown once it has this many seconds left, so a lane can take it the rest of the way. 0 keeps every cooldown on the bar until it is ready.\n\nThis only decides when the BAR lets go. When the lane picks it up is decided by that lane's own Max Time and Hide Long Timers, so set this to the lane's Max Time and make sure Hide Long Timers is on for it. Without that the lane draws the cooldown the whole time instead of waiting its turn, parked at the far end on Timeline, Logarithmic and Split, and crossing the lane slowly on Linear.\n\nA value above the lane's Max Time leaves a stretch where neither one draws it. It applies to everything routed to this frame, not only to long cooldowns."]))
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
		L["Screen point the frame is pinned to, then nudged by the X and Y offsets above."]))
	get, set = key("alpha", 1)
	card:Add(slider(self, content, L["Frame Alpha"], 0, 1, 0.05, get, set,
		L["Fades the whole frame, its background, border and bars together."]))
	get, set = key("padding", 0)
	card:Add(slider(self, content, L["Frame Padding"], 0, 40, 1, get, set))

	card = push(self:CreateGroup(content, L["Background"]))
	get, set = color("bgColor")
	card:Add(self:CreateColorPicker(content, L["Background Color"], get, set, nil, true))

	card = push(self:CreateGroup(content, L["Border"]))
	get, set = key("borderEnabled", true, sync)
	card:Add(self:CreateCheckbox(content, L["Show Border"], get, set))
	get, set = color("borderColor")
	local col = self:CreateColorPicker(content, L["Border Color"], get, set, nil, true)
	get, set = key("borderPadding", 0)
	local padding = slider(self, content, L["Border Padding"], 0, 40, 1, get, set)
	get, set = key("borderSize", 1)
	local size = slider(self, content, L["Border Size"], 1, 40, 1, get, set)
	for _, c in ipairs({ col, padding, size }) do
		card:Add(c, { dependent = true })
		deps[#deps + 1] = { c, function() return frame().borderEnabled ~= false end }
	end

	content._sync = function()
		local l = Settings.OffsetLimit()
		x.SetRange(-l, l)
		y.SetRange(-l, l)
		dims(deps)
	end
end

local function buildBar(self, content)
	local push = Settings.CardStack()
	local deps = {}
	local function sync() content._sync() end

	local card = push(self:CreateGroup(content, nil))
	local get, set = key("barWidth", 200)
	card:Add(slider(self, content, L["Bar Width"], 50, 500, 1, get, set))
	get, set = key("barHeight", 20)
	card:Add(slider(self, content, L["Bar Height"], 4, 60, 1, get, set))
	get, set = key("spacing", 0)
	card:Add(slider(self, content, L["Spacing"], 0, 40, 1, get, set, L["Gap, in pixels, between stacked bars."]))

	card = push(self:CreateGroup(content, L["Foreground"]))
	get, set = key("fgTexture")
	card:Add(Settings.TextureDropdown(self, content, L["Texture"], get, set))
	get, set = key("fgClassColor", false, sync)
	card:Add(self:CreateCheckbox(content, L["Use Class Color"], get, set,
		L["Fill the bar with your class color instead of the color below."]))
	get, set = color("fgColor")
	local fg = self:CreateColorPicker(content, L["Color"], get, set, nil, true)
	card:Add(fg, { dependent = true })
	deps[#deps + 1] = { fg, function() return not frame().fgClassColor end }

	card = push(self:CreateGroup(content, L["Bar Background"]))
	get, set = key("barBgTexture")
	card:Add(Settings.TextureDropdown(self, content, L["Texture"], get, set))
	get, set = color("barBgColor")
	card:Add(self:CreateColorPicker(content, L["Color"], get, set, nil, true))

	card = push(self:CreateGroup(content, L["Icon"]))
	get, set = key("showIcon", true, sync)
	card:Add(self:CreateCheckbox(content, L["Show Icon"], get, set))
	get, set = key("iconPosition", "LEFT")
	local side = self:CreateDropdown(content, L["Icon Position"], ICON_SIDES, get, set)
	card:Add(side, { dependent = true })
	deps[#deps + 1] = { side, function() return frame().showIcon ~= false end }

	card = push(self:CreateGroup(content, L["Highlight (Important spells)"]))
	local styleGet, styleSet, colorGet, colorSet, styled = B.highlight("BORDER", { r = 1, g = 0.82, b = 0, a = 0.8 }, sync)
	card:Add(self:CreateDropdown(content, L["Highlight Style"], Settings.HIGHLIGHTS, styleGet, styleSet,
		L["Emphasis drawn on the bar of a spell flagged Important (per spell, under Filters)."]))
	local hlColor = self:CreateColorPicker(content, L["Highlight Color"], colorGet, colorSet, nil, true)
	card:Add(hlColor, { dependent = true })
	deps[#deps + 1] = { hlColor, styled }

	content._sync = function() dims(deps) end
end

local function buildText(self, content)
	local push = Settings.CardStack()
	local deps = {}
	local function sync() content._sync() end
	local function under(card, list, on)
		for _, c in ipairs(list) do
			card:Add(c, { dependent = true })
			deps[#deps + 1] = { c, on }
		end
	end

	local card = push(self:CreateGroup(content, L["Name"]))
	local get, set = key("showName", true, sync)
	card:Add(self:CreateCheckbox(content, L["Show Name"], get, set))
	get, set = key("barFont")
	local font = Settings.FontDropdown(self, content, L["Font"], get, set)
	get, set = key("barFontSize", 12)
	local size = slider(self, content, L["Font Size"], 6, 32, 1, get, set)
	get, set = key("barFontFlags", "OUTLINE")
	local flags = self:CreateDropdown(content, L["Font Outline"], Settings.FONT_FLAGS, get, set)
	get, set = color("barFontColor")
	local col = self:CreateColorPicker(content, L["Name Color"], get, set, nil, true)
	under(card, { font, size, flags, col }, function() return frame().showName ~= false end)

	card = push(self:CreateGroup(content, L["Time"]))
	get, set = key("showTime", true, sync)
	card:Add(self:CreateCheckbox(content, L["Show Time"], get, set,
		L["Show the countdown number, drawn by the game's own cooldown widget so it stays correct in combat."]))
	if canStyleCountdown() then
		get, set = key("barTimeFont")
		local tFont = Settings.FontDropdown(self, content, L["Time Font"], get, set,
			L["Font for the countdown number, drawn by the game's cooldown widget."])
		get, set = key("barTimeSize", 12)
		local tSize = slider(self, content, L["Time Size"], 6, 32, 1, get, set)
		get, set = key("barTimeFlags", "OUTLINE")
		local tFlags = self:CreateDropdown(content, L["Time Outline"], Settings.FONT_FLAGS, get, set)
		get, set = color("barTimeColor", { r = 1, g = 1, b = 1, a = 1 })
		local tColor = self:CreateColorPicker(content, L["Time Color"], get, set, nil, true)
		under(card, { tFont, tSize, tFlags, tColor }, function() return frame().showTime ~= false end)
	end

	local gold = { r = 0.9216, g = 0.7176, b = 0.0235, a = 1 }
	Settings.FontCard(self, content, push, B, L["Name Tag"], "label", { size = 12, flags = "OUTLINE", color = gold },
		L["Font for this frame's name tag (shown above the frame while frames are unlocked)."])
	Settings.StatusCard(self, content, push, B, deps, sync)

	content._sync = function() dims(deps) end
end

ui:RegisterTab({ id = "bars", title = L["Bars"], order = 40, icon = Settings.Icon("icon-bars"), group = true })

local strip = Settings.Strip(state, L["Bars %d"], function(i)
	local c = ns.CDM.db.profile.barFrames[i]
	return c and c.enabled
end)

for i, page in ipairs({
	{ "general",    L["General"],    buildGeneral },
	{ "appearance", L["Appearance"], buildAppearance },
	{ "bar",        L["Bar"],        buildBar },
	{ "text",       L["Text"],       buildText },
}) do
	ui:RegisterTab({
		id      = "bars." .. page[1],
		parent  = "bars",
		title   = page[2],
		order   = i,
		header  = strip,
		footer  = Settings.Footer,
		build   = page[3],
		refresh = function(_, content) content._sync() end,
	})
end
