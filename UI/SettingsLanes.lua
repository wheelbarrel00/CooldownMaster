local _, ns = ...
local L = ns.L

local Settings = ns.Settings
local ui = Settings.ui

local state = { index = 1 }
Settings.lanes = state

local function lane()
	return ns.CDM.db.profile.lanes[state.index]
end

local function refreshLane()
	if ns.Lanes_ApplyConfig then ns.Lanes_ApplyConfig(state.index) end
	if ns.Lanes_Refresh then ns.Lanes_Refresh(state.index) end
end

local B = Settings.Binder(lane, refreshLane)
local key, sub, color = B.key, B.sub, B.color
local dims, slider, textField = Settings.Dims, Settings.Slider, Settings.TextField
local fontDropdown, textureDropdown = Settings.FontDropdown, Settings.TextureDropdown

local MODES = {
	{ value = "LINEAR",   label = L["Linear"] },
	{ value = "TIMELINE", label = L["Timeline (seconds)"] },
	{ value = "LOG",      label = L["Logarithmic (seconds)"] },
	{ value = "SPLIT",    label = L["Split (seconds)"] },
}

local TRACKING = {
	{ value = "NONE",  label = L["None"] },
	{ value = "GCD",   label = "GCD" },
	{ value = "SWING", label = L["Swing"] },
}

local function splitPoint(i)
	local s = lane().split
	local p = type(s) == "table" and type(s.points) == "table" and s.points[i]
	if type(p) == "table" then return p end
	return { t = 30 * i, p = 0.58 + 0.12 * i }
end

local function ensureSplit()
	local cfg = lane()
	if type(cfg.split) ~= "table" then cfg.split = { count = 1, points = {} } end
	if type(cfg.split.points) ~= "table" then cfg.split.points = {} end
	for i = 1, 3 do
		if type(cfg.split.points[i]) ~= "table" then cfg.split.points[i] = { t = 30 * i, p = 0.58 + 0.12 * i } end
	end
	return cfg.split
end

local function buildGeneral(self, content)
	local push, restack = Settings.CardStack()
	local deps = {}
	local function sync() content._sync() end

	local card = push(self:CreateGroup(content, L["General"]))
	card:Add(textField(self, content, L["Frame Name"], function() return lane().frameName end,
		function(v)
			lane().frameName = v
			refreshLane()
		end, nil, 32))
	card:Add(self:CreateCheckbox(content, L["Enabled"], function() return lane().enabled end, function(v)
		lane().enabled = v
		if ns.Lanes_RebuildOne then ns.Lanes_RebuildOne(state.index) end
	end))
	local get, set = key("reversed")
	card:Add(self:CreateCheckbox(content, L["Reversed"], get, set))
	card:Add(self:CreateCheckbox(content, L["Vertical"], function() return lane().vertical end, function(v)
		local cfg = lane()
		cfg.vertical = v
		-- Width runs along the lane, so a horizontal bar turns into a vertical one of the same shape
		cfg.width, cfg.height = cfg.height, cfg.width
		refreshLane()
	end, L["Run this lane top-to-bottom instead of left-to-right. Toggling it swaps the lane's Width and Height (under Appearance) so the bar keeps its shape, just rotated."]))

	card = push(self:CreateGroup(content, L["Mode"]))
	get, set = key("mode", "LINEAR", sync)
	card:Add(self:CreateDropdown(content, L["Mode"], MODES, get, set,
		L["How a cooldown's time left places it on the lane. Linear: each icon crosses the whole lane over its own cooldown, with no shared clock. Timeline: one shared clock, seconds spread evenly up to Max Time. Logarithmic: the same clock with the last seconds spread wide and long timers squeezed together. Split: the same clock bent through your own points below."]))
	get, set = key("maxTime", 120)
	local maxTime = slider(self, content, L["Max Time (seconds)"], 10, 360, 1, get, set,
		L["The far end of the lane's clock, in seconds, on Timeline, Logarithmic and Split. On Linear each icon crosses the lane over its own cooldown, so there it only sets which cooldowns Hide Long Timers keeps off the lane."])
	card:Add(maxTime)
	deps[#deps + 1] = { maxTime, function() local c = lane() return c.mode ~= "LINEAR" or c.hideLongTimers end }
	get, set = key("hideLongTimers", false, sync)
	card:Add(self:CreateCheckbox(content, L["Hide Long Timers"], get, set,
		L["Keeps a cooldown off this lane until it has Max Time or less left. Turned off, a longer cooldown waits at the far end on Timeline, Logarithmic and Split, and travels as usual on Linear."]))

	local split = push(self:CreateGroup(content, L["Split Points (Split mode)"]))
	local count = slider(self, content, L["Split Points"], 1, 3, 1,
		function() local s = lane().split return type(s) == "table" and s.count or 1 end,
		function(v)
			ensureSplit().count = v
			refreshLane()
			sync()
		end)
	split:Add(count)
	local splitControls, points = { count }, {}
	for i = 1, 3 do
		local t = slider(self, content, (L["Point %d Time (sec)"]):format(i), 1, 360, 1,
			function() return splitPoint(i).t end,
			function(v)
				ensureSplit().points[i].t = v
				refreshLane()
			end)
		local p = slider(self, content, (L["Point %d Position (%%)"]):format(i), 1, 99, 1,
			function() return math.floor((splitPoint(i).p or 0.5) * 100 + 0.5) end,
			function(v)
				ensureSplit().points[i].p = v / 100
				refreshLane()
			end)
		split:Add(t, { dependent = true })
		split:Add(p, { dependent = true })
		points[i] = { t, p }
		splitControls[#splitControls + 1] = t
		splitControls[#splitControls + 1] = p
	end

	card = push(self:CreateGroup(content, L["Auto-hide"]))
	local function visibility()
		if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
		sync()
	end
	get, set = key("overrideAutohide", false, visibility)
	local override = self:CreateCheckbox(content, L["Override Autohide"], get, set,
		L["Keeps this lane's background, border, and markers visible even when Auto-hide Frames is on."])
	card:Add(override)
	get, set = key("keepShownWhileRunning", false, visibility)
	local keep = self:CreateCheckbox(content, L["Keep Shown While Running"], get, set,
		L["With Auto-hide Frames on, keeps this lane's background, border, and markers visible out of combat for as long as a cooldown is still traveling on it, then hides them again once the lane empties. Override Autohide wins over this, and this option is ignored while Unlock Frames is on."])
	card:Add(keep)
	local g = function() return ns.CDM.db.profile.global end
	deps[#deps + 1] = { override, function() return g().autohide end }
	deps[#deps + 1] = { keep, function() return g().autohide and not lane().overrideAutohide and not g().unlockFrames end }

	-- Secondary Tracking runs only off the retail engine (Era, TBC, MoP), so retail and Forever do not offer it
	if not ns.Compat.IS_RETAIL then
		card = push(self:CreateGroup(content, L["Secondary Tracking"]))
		get, set = key("primaryTracking", "NONE", sync)
		card:Add(self:CreateDropdown(content, L["Primary Tracking"], TRACKING, get, set,
			L["Fills the whole lane like a progress bar for a recurring timer. GCD follows your global cooldown; Swing follows your main-hand swing timer; None turns it off. Uses the ST color and texture below."]))
		get, set = key("primaryReverse")
		local revP = self:CreateCheckbox(content, L["Reverse Primary"], get, set)
		card:Add(revP, { dependent = true })
		get, set = key("secondaryTracking", "NONE", sync)
		card:Add(self:CreateDropdown(content, L["Secondary Tracking"], TRACKING, get, set,
			L["A second tracking bar, separate from Primary Tracking. GCD or Swing; None turns it off. Its size and color are the ST (Secondary Tracking) options below."]))
		get, set = key("secondaryReverse")
		local revS = self:CreateCheckbox(content, L["Reverse Secondary"], get, set)
		card:Add(revS, { dependent = true })
		get, set = key("stWidth", 7)
		local stW = slider(self, content, L["ST Width"], 1, 60, 1, get, set)
		get, set = key("stHeight", 24)
		local stH = slider(self, content, L["ST Height"], 1, 120, 1, get, set,
			L["ST stands for Secondary Tracking. Sets the height, in pixels, of the Secondary Tracking bar set above."])
		get, set = key("stTexture")
		local stT = textureDropdown(self, content, L["ST Texture"], get, set,
			L["The texture that fills the Secondary Tracking bar. Any statusbar texture from LibSharedMedia is selectable."])
		get, set = color("stColor")
		local stC = self:CreateColorPicker(content, L["ST Color"], get, set, nil, true)
		for _, c in ipairs({ stW, stH, stT, stC }) do card:Add(c) end
		local function tracks(k) return function() return (lane()[k] or "NONE") ~= "NONE" end end
		local primary, secondary = tracks("primaryTracking"), tracks("secondaryTracking")
		local function any() return primary() or secondary() end
		deps[#deps + 1] = { revP, primary }
		deps[#deps + 1] = { revS, secondary }
		for _, c in ipairs({ stW, stH, stT, stC }) do deps[#deps + 1] = { c, any } end
	end

	content._sync = function()
		local cfg = lane()
		local isSplit = cfg.mode == "SPLIT"
		Settings.ShowCard(split, isSplit, splitControls)
		if isSplit then
			local n = type(cfg.split) == "table" and cfg.split.count or 1
			for i = 1, 3 do
				points[i][1]:SetShown(i <= n)
				points[i][2]:SetShown(i <= n)
			end
			split:Layout()
		end
		restack()
		dims(deps)
		self:MeasureContent(content)
	end
end

local function buildAppearance(self, content)
	local push = Settings.CardStack()
	local deps = {}
	local function sync() content._sync() end

	local card = push(self:CreateGroup(content, nil))
	local get, set = key("width", 1)
	card:Add(slider(self, content, L["Width"], 1, 1300, 1, get, set))
	get, set = key("height", 1)
	card:Add(slider(self, content, L["Height"], 1, 1300, 1, get, set))
	local lim = Settings.OffsetLimit()
	get, set = key("x", 0)
	local x = slider(self, content, L["X Offset"], -lim, lim, 1, get, set)
	card:Add(x)
	get, set = key("y", 0)
	local y = slider(self, content, L["Y Offset"], -lim, lim, 1, get, set)
	card:Add(y)
	get, set = key("anchor", "CENTER")
	card:Add(self:CreateDropdown(content, L["Anchor"], Settings.ANCHORS, get, set))

	card = push(self:CreateGroup(content, L["Lane"]))
	get, set = key("bgTexture")
	card:Add(textureDropdown(self, content, L["Lane Texture"], get, set))
	get, set = key("bgClassColor", false, sync)
	card:Add(self:CreateCheckbox(content, L["Use Class Color (Lane)"], get, set))
	get, set = color("bgColor")
	local bg = self:CreateColorPicker(content, L["Lane Color"], get, set, nil, true)
	card:Add(bg, { dependent = true })
	deps[#deps + 1] = { bg, function() return not lane().bgClassColor end }
	get, set = key("alpha", 1)
	card:Add(slider(self, content, L["Lane Alpha"], 0, 1, 0.05, get, set))

	card = push(self:CreateGroup(content, L["Border"]))
	get, set = key("borderEnabled", true, sync)
	card:Add(self:CreateCheckbox(content, L["Show Border"], get, set))
	get, set = key("borderTexture")
	local tex = Settings.EdgeDropdown(self, content, L["Border Texture"], get, set,
		L["The texture drawn around this lane. A soft texture like CDM Soft Edge needs room to fade, so raise Border Size to about 6 or it squashes into a smear."])
	get, set = color("borderColor")
	local col = self:CreateColorPicker(content, L["Border Color"], get, set, nil, true)
	get, set = key("borderPadding", 0)
	local padding = slider(self, content, L["Border Padding"], 0, 40, 1, get, set)
	get, set = key("borderSize", 1)
	local size = slider(self, content, L["Border Size"], 1, 40, 1, get, set)
	for _, c in ipairs({ tex, col, padding, size }) do
		card:Add(c, { dependent = true })
		deps[#deps + 1] = { c, function() return lane().borderEnabled ~= false end }
	end

	content._sync = function()
		local l = Settings.OffsetLimit()
		x.SetRange(-l, l)
		y.SetRange(-l, l)
		dims(deps)
	end
end

local function newIconLabel() return { enabled = false, text = "[cd.name]", anchor = "BOTTOM" } end

local function timerOn()
	local t = lane().iconText
	return t and t[2] and t[2].enabled or false
end

local function buildIcons(self, content)
	local push = Settings.CardStack()
	local deps = {}
	local function sync() content._sync() end
	local function under(list, on)
		for _, c in ipairs(list) do deps[#deps + 1] = { c, on } end
	end

	local card = push(self:CreateGroup(content, nil))
	local get, set = key("iconSize", 1)
	card:Add(slider(self, content, L["Size"], 1, 128, 1, get, set))
	get, set = key("iconAlpha", 1)
	card:Add(slider(self, content, L["Transparency"], 0, 1, 0.05, get, set))
	get, set = key("iconOffset", 0)
	card:Add(slider(self, content, L["Icon Offset"], -30, 30, 1, get, set))
	get, set = key("swipeAlpha", 0)
	card:Add(slider(self, content, L["Cooldown Tint (0 = off)"], 0, 1, 0.05, get, set))
	get, set = key("iconPulse", false, sync)
	card:Add(self:CreateCheckbox(content, L["Pulse"], get, set,
		L["Makes an icon breathe in and out as it travels, so a lane you care about is easier to catch out of the corner of your eye. Masque skins draw their own icon, so the pulse stands down while one is active."]))
	get, set = key("iconPulseWithin", 0)
	local within = slider(self, content, L["Pulse Within (sec)"], 0, 60, 1, get, set,
		L["Start pulsing only once a cooldown is this close to ready. Set it to 0 to pulse the whole way along the lane."])
	get, set = key("iconPulseSize", 1)
	local strength = slider(self, content, L["Pulse Strength"], 1, 20, 1, get, set,
		L["How many pixels the icon grows at the peak of each pulse."])
	card:Add(within, { dependent = true })
	card:Add(strength, { dependent = true })
	under({ within, strength }, function() return lane().iconPulse end)

	card = push(self:CreateGroup(content, L["Icon Border"]))
	get, set = key("iconBorder", false, sync)
	card:Add(self:CreateCheckbox(content, L["Show Icon Border"], get, set,
		L["Draw a clean solid border around every cooldown icon in this lane. Set per lane, so you can border one lane and leave another plain. On by default."]))
	get, set = key("iconBorderSize", 1)
	local bSize = slider(self, content, L["Border Size"], 1, 6, 1, get, set)
	get, set = color("iconBorderColor", { r = 0, g = 0, b = 0, a = 1 })
	local bColor = self:CreateColorPicker(content, L["Border Color"], get, set, nil, true)
	card:Add(bSize, { dependent = true })
	card:Add(bColor, { dependent = true })
	under({ bSize, bColor }, function() return lane().iconBorder end)

	card = push(self:CreateGroup(content, L["Highlight (Important spells)"]))
	local styleGet, styleSet, colorGet, colorSet, styled = B.highlight("NONE", { r = 1, g = 0.82, b = 0, a = 0.6 }, sync)
	card:Add(self:CreateDropdown(content, L["Highlight Style"], Settings.HIGHLIGHTS, styleGet, styleSet,
		L["Visual emphasis drawn on icons flagged Important (per spell, in Filters). Border draws a still outline, Flash makes it pulse, and None turns it off."]))
	local hlColor = self:CreateColorPicker(content, L["Highlight Color"], colorGet, colorSet, nil, true)
	card:Add(hlColor, { dependent = true })
	under({ hlColor }, styled)

	card = push(self:CreateGroup(content, L["Countdown Timer"]))
	-- The lane draws only iconText[2], its timer number
	card:Add(self:CreateCheckbox(content, L["Show Timer"], timerOn, function(v)
		local t = lane().iconText
		if t and t[2] then t[2].enabled = v end
		refreshLane()
		sync()
	end, L["Show the remaining-time number on each cooldown icon in this lane (for example 1:16, then 45, 44...). Style it with the Timer Font options below."]))

	card = push(self:CreateGroup(content, L["Timer Font"]))
	get, set = key("iconFont")
	local font = fontDropdown(self, content, L["Font"], get, set)
	get, set = key("iconFontSize", 0)
	local fSize = slider(self, content, L["Font Size (0 = auto)"], 0, 64, 1, get, set)
	get, set = key("iconFontFlags", "OUTLINE")
	local flags = self:CreateDropdown(content, L["Font Outline"], Settings.FONT_FLAGS, get, set)
	get, set = color("iconFontColor")
	local fColor = self:CreateColorPicker(content, L["Font Color"], get, set, nil, true)
	for _, c in ipairs({ font, fSize, flags, fColor }) do card:Add(c) end
	under({ font, fSize, flags, fColor }, timerOn)

	card = push(self:CreateGroup(content, L["Icon Label"]))
	get, set = sub("iconLabel", "enabled", false, newIconLabel, sync)
	card:Add(self:CreateCheckbox(content, L["Show Label"], get, set,
		L["Draw a line of text on each cooldown icon in this lane, built from the tags in Label Text below. Off by default - lanes otherwise show only the timer number, so this is how you put the ability name on the icon."]))
	local getText, setText = sub("iconLabel", "text", "", newIconLabel)
	local text = textField(self, content, L["Label Text"], getText, setText, ns.TAG_HELP, 120)
	local tags = Settings.TagRow(self, content, card, ns.TAG_PICKER_COOLDOWN, text, getText, setText)
	get, set = sub("iconLabel", "anchor", "BOTTOM", newIconLabel)
	local anchor = self:CreateDropdown(content, L["Label Position"], Settings.LABEL_ANCHORS, get, set,
		L["Where the label sits on the icon. On icon overlaps the timer number."])
	get, set = key("iconLabelFont")
	local lFont = fontDropdown(self, content, L["Label Font"], get, set)
	get, set = key("iconLabelSize", 10)
	local lSize = slider(self, content, L["Label Size"], 6, 32, 1, get, set)
	get, set = key("iconLabelFlags", "OUTLINE")
	local lFlags = self:CreateDropdown(content, L["Label Outline"], Settings.FONT_FLAGS, get, set)
	get, set = color("iconLabelColor", { r = 1, g = 1, b = 1, a = 1 })
	local lColor = self:CreateColorPicker(content, L["Label Color"], get, set, nil, true)
	local labelRows = { text, tags, anchor, lFont, lSize, lFlags, lColor }
	for _, c in ipairs(labelRows) do card:Add(c, { dependent = true }) end
	under(labelRows, function()
		local t = lane().iconLabel
		return type(t) == "table" and t.enabled
	end)

	content._sync = function() dims(deps) end
end

local STACK_STYLES = {
	{ value = "GROUPED", label = L["Grouped"] },
	{ value = "SPREAD",  label = L["Spread"] },
	{ value = "OFFSET",  label = L["Offset"] },
}

local GROW_H = {
	{ value = "UP",     label = L["Up"] },
	{ value = "DOWN",   label = L["Down"] },
	{ value = "CENTER", label = L["Center"] },
}

local GROW_V = {
	{ value = "LEFT",   label = L["Left"] },
	{ value = "RIGHT",  label = L["Right"] },
	{ value = "CENTER", label = L["Center"] },
}

-- The lane reads only a direction's sign, so each choice shows as what the lane draws and nothing is rewritten
local AS_VERTICAL = { UP = "RIGHT", DOWN = "LEFT" }
local AS_HORIZONTAL = { RIGHT = "UP", LEFT = "DOWN" }

local function buildStacking(self, content)
	local push, restack = Settings.CardStack()
	local deps = {}
	local function sync() content._sync() end
	local g = function() return ns.CDM.db.profile.global end

	local card = push(self:CreateGroup(content, nil))
	local get, set = key("stackEnabled", false, sync)
	card:Add(self:CreateCheckbox(content, L["Enabled"], get, set))
	local raise = self:CreateCheckbox(content, L["Raise On Mouseover"],
		function() return lane().stackRaiseHover end,
		-- Nothing to apply: the icons' enter and leave handlers are always attached
		function(v) lane().stackRaiseHover = v end,
		L["Brings the icon under your mouse to the front of a pile of overlapping icons. Icons take the mouse only while Enable tooltips (Global) is on and frames are locked."])
	card:Add(raise)
	deps[#deps + 1] = { raise, function() return g().enableTooltip and not g().unlockFrames end }

	card = push(self:CreateGroup(content, L["Behavior"]))
	get, set = key("stackStyle", "GROUPED", sync)
	local style = self:CreateDropdown(content, L["Stack Style"], STACK_STYLES, get, set,
		L["How cooldowns that pile on the same spot are arranged. Grouped packs them into rows and overlaps them to stay within Height; Offset fans every icon evenly across Height; Spread pushes them apart along the lane so each stays visible."])
	local grow = self:CreateDropdown(content, L["Grow Direction"],
		function() return lane().vertical and GROW_V or GROW_H end,
		function()
			local cfg = lane()
			local v = cfg.stackGrowDirection
			return (cfg.vertical and AS_VERTICAL[v]) or (not cfg.vertical and AS_HORIZONTAL[v]) or v
		end,
		function(v)
			lane().stackGrowDirection = v
			refreshLane()
		end,
		L["Which way a Grouped or Offset stack grows from the lane line. Center straddles the line and grows both ways."])
	get, set = key("stackHeight", 0)
	local height = slider(self, content, L["Height"], 0, 300, 5, get, set,
		L["How much room across the lane the stack may use. When the icons do not all fit, they overlap to stay within it, so raise Height to reduce overlap."])
	for _, c in ipairs({ style, grow, height }) do
		card:Add(c)
		deps[#deps + 1] = { c, function() return lane().stackEnabled end }
	end

	content._sync = function()
		local spread = lane().stackStyle == "SPREAD"
		grow:SetShown(not spread)
		height:SetShown(not spread)
		card:Layout()
		restack()
		dims(deps)
		self:MeasureContent(content)
	end
end

local PLACEMENTS = {
	{ value = "TOP",    label = L["Above lane"] },
	{ value = "CENTER", label = L["On lane"] },
	{ value = "BOTTOM", label = L["Below lane"] },
}

local ANCHOR_BY = {
	{ value = "PERCENT",      label = L["Percent of lane"] },
	{ value = "PERCENT_AUTO", label = L["Percent of lane (auto label)"] },
	{ value = "TIME",         label = L["Time (seconds)"] },
	{ value = "TIME_AUTO",    label = L["Time (auto label)"] },
}

-- Linear gives every icon its own cooldown to span, so there is no shared clock a time anchor could read
local ANCHOR_BY_PERCENT = { ANCHOR_BY[1], ANCHOR_BY[2] }
local AS_PERCENT = { TIME = "PERCENT", TIME_AUTO = "PERCENT_AUTO" }
local AUTO = { PERCENT_AUTO = true, TIME_AUTO = true }
local TIMED = { TIME = true, TIME_AUTO = true }

local function timeAxis()
	return (ns.Lanes_TimeToPos and ns.Lanes_TimeToPos(lane(), 0)) ~= nil
end

local function label(i)
	local t = lane().laneText
	return t and t[i]
end

-- A label missing from the saved list hides its row, and its controls read this until it is back
local NO_LABEL = {}

local function shownAnchor(i)
	local am = (label(i) or NO_LABEL).anchorMode or "PERCENT"
	if timeAxis() then return am end
	return AS_PERCENT[am] or am
end

local TABLE_HEAD, TABLE_ROW, ANCHOR_W, TEXT_W, GAP = 28, 44, 200, 120, 14

local function labelTable(self, content, card, deps)
	local box = CreateFrame("Frame", nil, content)
	box:SetHeight(TABLE_HEAD + 5 * TABLE_ROW)
	box._euiFill = true
	card:Add(box, { height = TABLE_HEAD + 5 * TABLE_ROW })
	-- Across the whole card, so its dividers meet the card's edges as the rows' own do
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", box._euiRow, "TOPLEFT")
	box:SetPoint("BOTTOMRIGHT", box._euiRow, "BOTTOMRIGHT")
	local head = CreateFrame("Frame", nil, box)
	head:SetPoint("TOPLEFT")
	head:SetPoint("TOPRIGHT")
	head:SetHeight(TABLE_HEAD)
	local hAnchor = self:CreateText(head, L["Anchor By"], "groupLabel")
	local hText = self:CreateText(head, L["Text"], "groupLabel")
	local hPos = self:CreateText(head, L["Position"], "groupLabel")
	self:AttachTooltip(hAnchor, L["Anchor By"], L["Percent holds the label at a fixed spot on the bar. Time holds it at a number of seconds and moves the label to match. The auto label choices write the text for you from the lane's current Mode and Max Time, so the label stays true after you change either one - seconds on Timeline, Logarithmic and Split, and a percent on Linear, which has no shared clock to read."])
	self:AttachTooltip(hText, L["Text"], L["What the label reads. The auto label choices ignore this and write the text themselves."])
	ui:AddDivider(card, head)

	local rows = {}
	for i = 1, 5 do
		local r = CreateFrame("Frame", nil, box)
		r:SetPoint("TOPLEFT", 0, -(TABLE_HEAD + (i - 1) * TABLE_ROW))
		r:SetPoint("TOPRIGHT", 0, -(TABLE_HEAD + (i - 1) * TABLE_ROW))
		r:SetHeight(TABLE_ROW)
		if i < 5 then ui:AddDivider(card, r) end
		local on = self:CreateCheckbox(content, (L["Label %d enabled"]):format(i),
			function() local d = label(i) return d and d.enabled end,
			function(v)
				label(i).enabled = v
				refreshLane()
				content._sync()
			end)
		local anchorBy = self:CreateDropdown(content, nil,
			function() return timeAxis() and ANCHOR_BY or ANCHOR_BY_PERCENT end,
			function() return shownAnchor(i) end,
			function(v)
				local d = label(i)
				-- Picking the choice already on show keeps the time mode it stands in for on Linear
				if not timeAxis() and v == AS_PERCENT[d.anchorMode] then return end
				d.anchorMode = v
				refreshLane()
				content._sync()
			end)
		local text = self:CreateTextField(content, nil, function() return (label(i) or NO_LABEL).text or "" end,
			function(v)
				label(i).text = v
				refreshLane()
			end, nil, { maxLetters = 24, live = true })
		local pct = self:CreateSlider(content, nil, 0, 100, 1,
			function() return math.floor(((label(i) or NO_LABEL).pos or 0) * 100 + 0.5) end,
			function(v)
				local cfg, d = lane(), label(i)
				d.pos = v / 100
				-- Stored unrounded, since a Logarithmic lane's first percents round to zero seconds and would pin the label
				local t = ns.Lanes_PosToTime and ns.Lanes_PosToTime(cfg, d.pos)
				if t then d.t = t end
				refreshLane()
			end).EnableTyping()
		self:AttachTooltip(pct, L["Position (percent)"],
			L["Where the label sits, as a percent along the lane. Moving this also updates Position (seconds) to match."])
		local sec = self:CreateSlider(content, nil, 0, 120, 1,
			-- Only the display is held to Max Time, since writing it back would flatten every label when Max Time drops
			function() return math.floor(math.min((label(i) or NO_LABEL).t or 0, lane().maxTime or 120) + 0.5) end,
			function(v)
				local cfg, d = lane(), label(i)
				local p = ns.Lanes_TimeToPos and ns.Lanes_TimeToPos(cfg, v)
				if p then
					d.t, d.pos = v, p
				end
				refreshLane()
			end).EnableTyping()
		self:AttachTooltip(sec, L["Position (seconds)"],
			L["Where the label sits, as seconds left on a cooldown. Moving this also updates Position (percent) to match. Linear has no seconds axis, so this does nothing there."])
		rows[i] = { frame = r, on = on, anchorBy = anchorBy, text = text, pct = pct, sec = sec,
		            controls = { on, anchorBy, text, pct, sec } }
		local function enabled() local d = label(i) return d and d.enabled end
		deps[#deps + 1] = { anchorBy, enabled }
		deps[#deps + 1] = { text, function() return enabled() and not AUTO[shownAnchor(i)] end }
		deps[#deps + 1] = { pct, enabled }
		deps[#deps + 1] = { sec, enabled }
	end

	-- Placed on screen, where the box names measure in the font the player sees
	function box.Fit()
		local first = 0
		for _, r in ipairs(rows) do
			first = math.max(first, (r.on.label:GetStringWidth() or 0) + 16 + ui:Spacing("checkboxGap"))
		end
		local x1 = ui:Spacing("rowPadding")
		local x2 = x1 + first + GAP
		local x3 = x2 + ANCHOR_W + GAP
		local x4 = x3 + TEXT_W + GAP
		hAnchor:ClearAllPoints()
		hAnchor:SetPoint("LEFT", head, "LEFT", x2, 0)
		hText:ClearAllPoints()
		hText:SetPoint("LEFT", head, "LEFT", x3, 0)
		hPos:ClearAllPoints()
		hPos:SetPoint("LEFT", head, "LEFT", x4, 0)
		for _, r in ipairs(rows) do
			r.on:ClearAllPoints()
			r.on:SetPoint("LEFT", r.frame, "LEFT", x1, 0)
			r.anchorBy:ClearAllPoints()
			r.anchorBy:SetPoint("LEFT", r.frame, "LEFT", x2, 0)
			r.anchorBy:SetWidth(ANCHOR_W)
			r.text:ClearAllPoints()
			r.text:SetPoint("LEFT", r.frame, "LEFT", x3, 0)
			r.text:SetWidth(TEXT_W)
			for _, s in ipairs({ r.pct, r.sec }) do
				s:ClearAllPoints()
				s:SetPoint("LEFT", r.frame, "LEFT", x4, 0)
				s:SetPoint("RIGHT", r.frame, "RIGHT", -ui:Spacing("rowPadding"), 0)
			end
		end
	end
	box.Fit()
	local fits = content._euiFit or {}
	content._euiFit = fits
	fits[#fits + 1] = box
	return rows
end

local function buildText(self, content)
	local push = Settings.CardStack()
	local deps = {}
	local function sync() content._sync() end

	local card = push(self:CreateGroup(content, L["Default Text"]))
	local get, set = key("laneTextAnchor", "CENTER")
	card:Add(self:CreateDropdown(content, L["Label Placement"], PLACEMENTS, get, set,
		L["Where the labels sit relative to the lane bar. Move them off the bar when tall icons cover them. On a vertical lane, Above places them to the right of it and Below to the left."]))
	get, set = key("laneTextOffX", 0)
	card:Add(slider(self, content, L["X Offset"], -100, 100, 1, get, set,
		L["Nudges every label sideways from its placement."]))
	get, set = key("laneTextOffY", 0)
	card:Add(slider(self, content, L["Y Offset"], -100, 100, 1, get, set,
		L["Nudges every label up or down from its placement."]))
	local rows = labelTable(self, content, card, deps)

	local gold = { r = 0.9216, g = 0.7176, b = 0.0235, a = 1 }
	Settings.FontCard(self, content, push, B, L["Marker Font"], "laneText", { size = 9, flags = "NONE", color = gold },
		L["Font for the position markers along this lane (Ready, 25, 50, 75, 100 percent)."])
	Settings.FontCard(self, content, push, B, L["Name Tag Font"], "label", { size = 12, flags = "OUTLINE", color = gold },
		L["Font for this lane's name tag (shown above the bar while frames are unlocked)."])

	Settings.StatusCard(self, content, push, B, deps, sync)

	content._sync = function()
		local cfg = lane()
		local maxT = cfg.maxTime or 120
		for i, r in ipairs(rows) do
			local d = label(i)
			r.frame:SetShown(d ~= nil)
			for _, c in ipairs(r.controls) do c:SetShown(d ~= nil) end
			if d then
				-- The field Anchor By does not follow is worked out from the one it does, so a Mode or Max Time change keeps both
				if TIMED[d.anchorMode] then
					local p = ns.Lanes_TimeToPos and ns.Lanes_TimeToPos(cfg, d.t or 0)
					if p then d.pos = p end
				else
					local t = ns.Lanes_PosToTime and ns.Lanes_PosToTime(cfg, d.pos or 0)
					if t then d.t = t end
				end
				local timed = TIMED[shownAnchor(i)] and true or false
				r.sec.SetRange(0, maxT)
				r.pct:SetShown(not timed)
				r.sec:SetShown(timed)
				-- An Anchor By pick from this page shows the other slider without a page view to read it
				r.pct:Refresh()
			end
		end
		dims(deps)
	end
end

ui:RegisterTab({ id = "lanes", title = L["Lanes"], order = 20, icon = Settings.Icon("icon-lanes"), group = true })

local strip = Settings.Strip(state, L["Lane %d"], function(i)
	local c = ns.CDM.db.profile.lanes[i]
	return c and c.enabled
end)

for i, page in ipairs({
	{ "general",    L["General"],    buildGeneral },
	{ "appearance", L["Appearance"], buildAppearance },
	{ "icons",      L["Icons"],      buildIcons },
	{ "stacking",   L["Stacking"],   buildStacking },
	{ "text",       L["Text"],       buildText },
}) do
	ui:RegisterTab({
		id      = "lanes." .. page[1],
		parent  = "lanes",
		title   = page[2],
		order   = i,
		header  = strip,
		footer  = Settings.Footer,
		build   = page[3],
		refresh = function(_, content) content._sync() end,
	})
end
