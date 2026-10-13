local _, ns = ...
local L = ns.L

local EUI = LibStub("EverythingUI-1.0")
local Settings = ns.Settings
local ui = Settings.ui

local SEARCH_H, HEAD_H, ROW_H, NOMATCH_H, EMPTY_MIN = 44, 28, 40, 54, 72
local GAP, SHOW_W, EXTRA_W, ICON_SIZE, BUTTON_SIZE = 8, 44, 52, 20, 26
local OVERVIEW_ON, OVERVIEW_COL = 90, 110
-- A choice field's three 10 px paddings and its 12 px chevron (Dropdown.lua), so the longest choice is never cut
local CHOICE_CHROME, CHOICE_MIN = 42, 88
-- A page of the 720-tall window shows at most 16 of these rows, so 19 is a safe ceiling
local POOL = 19
local FIELDS = { "lane", "bar", "ready", "flags" }
local EMPTY = {}

local function profile() return ns.CDM.db.profile end
local function filterCfg(key) return profile().filters[key] end
local function reroute() if ns.Engine then ns.Engine:ReapplyRouting() end end

local function invalidate()
	Settings.FiltersChanged()
end

local function override(id)
	local so = id and profile().spellOverrides
	return so and so[id]
end

-- Pruned back to nil once it holds nothing, so choosing Default everywhere leaves no empty table behind
local function setOverride(id, field, value)
	local p = profile()
	if value == nil then
		local so = p.spellOverrides
		local ov = so and so[id]
		if not ov then return end
		ov[field] = nil
		if next(ov) == nil then so[id] = nil end
		return
	end
	p.spellOverrides = p.spellOverrides or {}
	local ov = p.spellOverrides[id]
	if not ov then
		ov = {}
		p.spellOverrides[id] = ov
	end
	ov[field] = value
end

local function categoryLabel(key)
	for _, def in ipairs(ns.CONST.FILTER_CATEGORIES) do
		if def.key == key then return def.label end
	end
	return key
end

local function laneLabel(i)
	local c = profile().lanes[i]
	if c and c.enabled == false then return L["Lane %d (off)"]:format(i) end
	return L["Lane %d"]:format(i)
end

local LANES = { { value = 1 }, { value = 2 }, { value = 3 } }
local LANE_ROW = { { value = 0, label = L["Default"] }, LANES[1], LANES[2], LANES[3] }

-- A switched-off lane says so in every list offering it, so the labels are read again each time
local function lanes()
	for i = 1, 3 do LANES[i].label = laneLabel(i) end
	return LANES
end

local function laneRow()
	lanes()
	return LANE_ROW
end

local BOXES = { { value = 0, label = L["Off"] } }
local BARS = { { value = 0, label = L["Off"] } }
local BOX_ROW = { { value = -1, label = L["Default"] }, BOXES[1] }
local BAR_ROW = { { value = -1, label = L["Default"] }, BARS[1] }
for i = 1, 3 do
	BOXES[i + 1] = { value = i, label = L["Box %d"]:format(i) }
	BARS[i + 1] = { value = i, label = L["Bars %d"]:format(i) }
	BOX_ROW[i + 2] = BOXES[i + 1]
	BAR_ROW[i + 2] = BARS[i + 1]
end

local FLAGS = {
	{ value = 0, label = L["Normal"] },
	{ value = 1, label = L["Important"] },
	{ value = 2, label = L["Pinned"] },
	{ value = 3, label = L["Imp + Pin"] },
}

local function foldPair(lead, c)
	local b = c:byte()
	if lead == "\195" then
		if b <= 0x9E and b ~= 0x97 then return lead .. string.char(b + 32) end
		return lead .. c
	end
	if b < 0x90 then return "\209" .. string.char(b + 16) end
	if b < 0xA0 then return "\208" .. string.char(b + 32) end
	return "\209" .. string.char(b - 32)
end

-- string.lower folds only A to Z, so accented Latin and Cyrillic capitals are folded here
local function fold(s)
	return (s:lower():gsub("([\195\208])([\128-\175])", foldPair))
end

local function byName(a, b)
	if a.sort == b.sort then return a.id < b.id end
	return a.sort < b.sort
end

local function gather(list, source, n)
	local engine = ns.Engine
	for id, info in pairs(source or EMPTY) do
		if engine:GetCategoryFilterKey(info.category) == list.key then
			n = n + 1
			local e = list.entries[n]
			if not e then
				e = {}
				list.entries[n] = e
			end
			e.id, e.info, e.sort = id, info, fold(info.name or "")
			list.all[n] = e
		end
	end
	return n
end

local function collect(list)
	local engine, n = ns.Engine, 0
	if engine then
		n = gather(list, engine.trackedSpells, n)
		n = gather(list, engine.trackedItems, n)
		n = gather(list, engine.trackedOffensives, n)
	end
	local all = list.all
	for i = #all, n + 1, -1 do all[i] = nil end
	table.sort(all, byName)
	local shown, m, q = list.shown, 0, list.query
	for i = 1, n do
		local e = all[i]
		if q == "" or e.sort:find(q, 1, true) then
			m = m + 1
			shown[m] = e
		end
	end
	for i = #shown, m + 1, -1 do shown[i] = nil end
	return n, m
end

local function emptyText(key)
	local on = filterCfg(key).enabled ~= false
	-- Offensives explains its own switch in the card above, so a switched-off list says nothing more
	if key == "offensives" then
		return on and L["No harmful effects discovered yet.\nThe effects you put on a target are listed here as you apply them."] or nil
	end
	if not on then
		return L["This category is switched off, so none of its cooldowns show on a lane or a bar, or pop a ready box.\nTick Track this category above to switch it on."]
	end
	return L["No spells discovered yet for this category.\nLog in or /reload to populate the list."]
end

local function gameTip(hit, r)
	if not r.info then return end
	GameTooltip:SetOwner(hit, "ANCHOR_RIGHT")
	if r.info.kind == "item" then
		if r.info.link then GameTooltip:SetHyperlink(r.info.link) else GameTooltip:SetItemByID(r.id) end
	elseif r.info.buffSpellID then
		GameTooltip:SetSpellByID(r.info.buffSpellID)
	else
		GameTooltip:SetSpellByID(r.id)
	end
	GameTooltip:Show()
end

local function shows(r)
	if not r.info then return false end
	local o = override(r.id)
	if o and o.visible ~= nil then return o.visible end
	local key = ns.Engine and ns.Engine:GetCategoryFilterKey(r.info.category)
	local c = key and filterCfg(key)
	return c and c.showByDefault ~= false
end

local function dimRow(r)
	local on = r.show:GetChecked() and true or false
	for _, f in ipairs(FIELDS) do ui:SetDependent(r[f], on) end
end

local rows = {}
local owner

local function newRow(list)
	local r = CreateFrame("Frame", nil, list.box)
	r:SetHeight(ROW_H)
	r._controls = {}
	ui:Paint(r, nil, "divider", "T")
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(ICON_SIZE, ICON_SIZE)
	r.icon:SetPoint("LEFT", ui:Spacing("rowPadding"), 0)
	r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	r.name = ui:CreateText(r, "", "label")
	r.name:SetTextColor(ui:Color("text"))
	r.name:SetWordWrap(false)
	r.name:SetPoint("LEFT", r.icon, "RIGHT", GAP, 0)
	local hit = CreateFrame("Frame", nil, r)
	hit:SetPoint("TOPLEFT", r.icon, "TOPLEFT")
	hit:SetPoint("BOTTOMRIGHT", r.name, "BOTTOMRIGHT")
	hit:EnableMouse(true)
	hit:SetScript("OnEnter", function(self) gameTip(self, r) end)
	hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
	r.hit = hit

	r.show = ui:CreateCheckbox(r, nil, function() return shows(r) end, function(v)
		setOverride(r.id, "visible", v)
		dimRow(r)
	end)
	r.lane = ui:CreateDropdown(r, nil, laneRow,
		function()
			local o = override(r.id)
			return (o and o.lane) or 0
		end,
		function(v)
			setOverride(r.id, "lane", v ~= 0 and v or nil)
			reroute()
		end)
	r.bar = ui:CreateDropdown(r, nil, BAR_ROW,
		function()
			local o = override(r.id)
			if o and o.bar ~= nil then return o.bar end
			return -1
		end,
		function(v)
			setOverride(r.id, "bar", v ~= -1 and v or nil)
			reroute()
		end)
	r.ready = ui:CreateDropdown(r, nil, BOX_ROW,
		function()
			local o = override(r.id)
			if o and o.readyBox ~= nil then return o.readyBox end
			return -1
		end,
		function(v) setOverride(r.id, "readyBox", v ~= -1 and v or nil) end)
	r.flags = ui:CreateDropdown(r, nil, FLAGS,
		function()
			local o = override(r.id)
			return ((o and o.important) and 1 or 0) + ((o and o.pinned) and 2 or 0)
		end,
		function(v)
			setOverride(r.id, "important", (v % 2) == 1 or nil)
			setOverride(r.id, "pinned", v >= 2 or nil)
		end)
	r.remove = ui:CreateIconButton(r, "close", BUTTON_SIZE)
	r.remove:SetScript("OnClick", function()
		if ns.Engine and ns.Engine.ForgetOffensive then ns.Engine:ForgetOffensive(r.id) end
	end)
	r.buff = ui:CreateCheckbox(r, nil,
		function()
			local o = override(r.id)
			return o and o.trackBuff
		end,
		function(v)
			setOverride(r.id, "trackBuff", v or nil)
			if ns.Engine and ns.Engine.RefreshBuffTracking then ns.Engine:RefreshBuffTracking(r.id) end
		end)
	r.controls = { r.show, r.lane, r.bar, r.ready, r.flags, r.buff }
	return r
end

local function placeRow(list, r)
	local c = list.cols
	r.show:ClearAllPoints()
	r.show:SetPoint("CENTER", r, "LEFT", c.show + SHOW_W / 2, 0)
	for _, f in ipairs(FIELDS) do
		local dd = r[f]
		dd:ClearAllPoints()
		dd:SetPoint("LEFT", r, "LEFT", c[f], 0)
		dd:SetWidth(c[f .. "W"])
	end
	local x = (c.extra or 0) + EXTRA_W / 2
	r.remove:ClearAllPoints()
	r.remove:SetPoint("CENTER", r, "LEFT", x, 0)
	r.buff:ClearAllPoints()
	r.buff:SetPoint("CENTER", r, "LEFT", x, 0)
	r.name:SetPoint("RIGHT", r, "LEFT", c.show - GAP, 0)
end

-- Every category page shares one pool, so visiting them all never builds more than POOL rows
local function attach(list)
	if owner == list then return false end
	owner = list
	for k = 1, POOL do
		local r = rows[k]
		if r then
			r:SetParent(list.box)
			r.index = nil
			r:Hide()
		end
	end
	return true
end

local function fill(list, r)
	r.icon:SetTexture(r.info.icon)
	r.name:SetText(r.info.name or L["Spell %d"]:format(r.id))
	for _, c in ipairs(r.controls) do c:Refresh() end
	r.remove:SetShown(list.extra == "remove")
	r.buff:SetShown(list.extra == "buff")
	dimRow(r)
	-- A row reused under a still mouse shows its new spell's tooltip, as the library's dropdown list does
	if GameTooltip:IsOwned(r.hit) then gameTip(r.hit, r) end
end

local function bind(list, r, e, i)
	r.index, r.gen = i, list.gen
	r.id, r.info = e.id, e.info
	local y = -(SEARCH_H + HEAD_H + (i - 1) * ROW_H)
	r:ClearAllPoints()
	r:SetPoint("TOPLEFT", list.box, "TOPLEFT", 0, y)
	r:SetPoint("TOPRIGHT", list.box, "TOPRIGHT", 0, y)
	fill(list, r)
end

local function visibleRange(list, m)
	local sf = list.content:GetParent()
	local ctop, btop = list.content:GetTop(), list.box:GetTop()
	local view = (sf and sf.GetHeight and sf:GetHeight()) or 0
	if not (ctop and btop) or view <= 0 then return 1, math.min(m, POOL) end
	local scroll = (sf.GetVerticalScroll and sf:GetVerticalScroll()) or 0
	local top = ctop - btop + SEARCH_H + HEAD_H
	local first = math.max(1, math.floor((scroll - top) / ROW_H) + 1)
	local last = math.min(m, math.floor((scroll + view - top) / ROW_H) + 1, first + POOL - 1)
	return first, last
end

-- A pick in a list that opened on a row would land on whatever the row shows next. Another window's list is left alone
local function closeList()
	local p = EUI.shared and EUI.shared.popup
	if p and p:IsShown() and p.owner == Settings.frame then p:Hide() end
end

-- Row i always sits in pool row (i - 1) % POOL + 1, so a scroll draws only the rows coming into view
local function paintRows(list, refresh)
	if owner ~= list then return end
	local first, last = visibleRange(list, list.count)
	local closed
	for i = first, last do
		local k = (i - 1) % POOL + 1
		local r = rows[k]
		if not r then
			r = newRow(list)
			rows[k] = r
			placeRow(list, r)
		end
		if r.index ~= i or r.gen ~= list.gen then
			if not closed then
				closeList()
				closed = true
			end
			bind(list, r, list.shown[i], i)
		elseif refresh then
			-- The Engine builds its item tables anew on a bag change, so a row that did not move reads its entry again
			r.info = list.shown[i].info
			fill(list, r)
		end
		r:Show()
	end
	for k = 1, POOL do
		local r = rows[k]
		if r and not (r.index and r.index >= first and r.index <= last) then
			r.index = nil
			r:Hide()
		end
	end
end

local function widest(ruler, opts)
	local w = 0
	for _, o in ipairs(opts) do
		ruler:SetText(o.label)
		w = math.max(w, ruler:GetStringWidth() or 0)
	end
	return math.max(CHOICE_MIN, math.ceil(w) + CHOICE_CHROME)
end

local function measureColumns(list, moved)
	local ruler, c = list.ruler, list.cols
	local laneW, barW = widest(ruler, laneRow()), widest(ruler, BAR_ROW)
	local readyW, flagsW = widest(ruler, BOX_ROW), widest(ruler, FLAGS)
	local w = list.box:GetWidth() or 0
	if w <= 0 then w = list.content:GetWidth() or 0 end
	local x = w - ui:Spacing("rowPadding")
	local extra
	if list.extra then
		x = x - EXTRA_W
		extra = x
	end
	if c.width == w and c.laneW == laneW and c.barW == barW and c.readyW == readyW and c.flagsW == flagsW then
		if moved then
			for k = 1, POOL do
				if rows[k] then placeRow(list, rows[k]) end
			end
		end
		return
	end
	c.width, c.laneW, c.barW, c.readyW, c.flagsW, c.extra = w, laneW, barW, readyW, flagsW, extra
	c.flags = x - flagsW
	c.ready = c.flags - GAP - readyW
	c.bar = c.ready - GAP - barW
	c.lane = c.bar - GAP - laneW
	c.show = c.lane - GAP - SHOW_W
	local h = list.heads
	h.show:ClearAllPoints()
	h.show:SetPoint("CENTER", list.head, "LEFT", c.show + SHOW_W / 2, 0)
	for _, f in ipairs(FIELDS) do
		h[f]:ClearAllPoints()
		h[f]:SetPoint("LEFT", list.head, "LEFT", c[f], 0)
	end
	if h.extra then
		h.extra:ClearAllPoints()
		h.extra:SetPoint("CENTER", list.head, "LEFT", c.extra + EXTRA_W / 2, 0)
	end
	if owner == list then
		for k = 1, POOL do
			if rows[k] then placeRow(list, rows[k]) end
		end
	end
end

-- Rows are bound again only when the list's order changes, so a repaint that moves nothing leaves an open dropdown list open
local function paint(list)
	local n, m = collect(list)
	local ids = list.ids
	local changed = #ids ~= m
	for i = 1, m do
		local id = list.shown[i].id
		if ids[i] ~= id then
			ids[i] = id
			changed = true
		end
	end
	for i = #ids, m + 1, -1 do ids[i] = nil end
	if changed then list.gen = list.gen + 1 end
	list.count = m

	local text = n == 0 and emptyText(list.key) or nil
	local visible = n > 0 or text ~= nil
	local shown = visible ~= list.visible
	if shown then Settings.ShowCard(list.card, visible, list.held) end
	list.search:SetShown(n > 0)
	list.head:SetShown(n > 0)
	list.noMatch:SetShown(n > 0 and m == 0)
	list.empty:SetShown(text ~= nil)
	list.empty:SetText(text or "")
	local h
	if n == 0 then
		h = math.max(EMPTY_MIN, math.ceil(list.empty:GetStringHeight() or 0) + 36)
	else
		h = SEARCH_H + HEAD_H + (m == 0 and NOMATCH_H or m * ROW_H)
	end
	local row = list.box._euiRow
	local grown = math.abs((row:GetHeight() or 0) - h) > 0.5
	if grown then
		row:SetHeight(h)
		list.card:Layout()
	end
	if shown or grown then
		list.visible = visible
		list.restack()
		ui:MeasureContent(list.content)
	end

	measureColumns(list, attach(list))
	paintRows(list, true)
end

local lists = {}

local function newList(self, content, card, key, restack)
	local list = { key = key, content = content, card = card, restack = restack, gen = 0, count = 0,
	               entries = {}, all = {}, shown = {}, ids = {}, query = "", cols = {}, heads = {} }
	if key == "offensives" then
		list.extra = "remove"
	-- A spell that also buffs you can time the buff too, everywhere but retail, whose buffs are secret in combat
	elseif not ns.Compat.HAS_BLIZZ_CDM and (key == "spells" or key == "items") then
		list.extra = "buff"
	end

	local box = CreateFrame("Frame", nil, content)
	box._euiFill = true
	card:Add(box, { height = EMPTY_MIN })
	-- Across the whole card, so the rows' dividers meet its edges
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", box._euiRow, "TOPLEFT")
	box:SetPoint("BOTTOMRIGHT", box._euiRow, "BOTTOMRIGHT")
	list.box, list.held = box, { box }

	local pad = ui:Spacing("rowPadding")
	local inset = (SEARCH_H - ui:Spacing("fieldHeight")) / 2
	local search = self:CreateSearchField(box, L["Find a cooldown"], function() end)
	search:SetPoint("TOPLEFT", box, "TOPLEFT", pad, -inset)
	search:SetPoint("TOPRIGHT", box, "TOPRIGHT", -pad, -inset)
	search.box:HookScript("OnTextChanged", function(b)
		list.query = fold((b:GetText() or ""):match("^%s*(.-)%s*$"))
		paint(list)
	end)
	list.search = search

	local head = CreateFrame("Frame", nil, box)
	head:SetPoint("TOPLEFT", 0, -SEARCH_H)
	head:SetPoint("TOPRIGHT", 0, -SEARCH_H)
	head:SetHeight(HEAD_H)
	ui:Paint(head, nil, "divider", "T")
	list.head = head
	local function heading(field, text, tip)
		local fs = self:CreateText(head, text, "groupLabel")
		self:AttachTooltip(fs, text, tip)
		list.heads[field] = fs
	end
	heading("show", L["Show"], L["Track this cooldown and draw it. Untick to hide it from every lane, bar and ready box. Until you touch it here, it follows this category's Show By Default setting."])
	heading("lane", L["Lane"], L["Which lane this cooldown travels in. Default follows this category's Default Lane, set above."])
	heading("bar", L["Bar"], L["Which bar frame this cooldown shows on. Default follows this category's Default Bar. Off keeps it off the bars without hiding it from your lanes or ready boxes."])
	heading("ready", L["Ready Box"], L["Which ready box this pops into the moment the cooldown comes up. Default follows this category's Ready Box. Off means it never pops."])
	heading("flags", L["Flags"], L["How this one behaves once it pops into a ready box.\n\nNormal - fades after the box's Display Duration.\n\nImportant - highlights the icon and holds it for the box's Highlight Duration instead, and plays the box's Highlight Sound (set to None until you pick one).\n\nPinned - the icon never fades. It stays until you reload, switch profile or start or stop Test Mode, and a box full of pinned icons has no room for new pops.\n\nImp + Pin - both."])
	if list.extra == "remove" then
		heading("extra", L["Remove"], L["Remove this from Offensives. Use it to clear a debuff that leaked in from another player on a shared target. If the spell is actually yours, it relearns the next time you cast it."])
	elseif list.extra == "buff" then
		heading("extra", L["Buff"], L["Also track this spell's buff. Adds a second icon that counts down how long the buff lasts, separate from the cooldown. Off by default - leave it off for spells that do not give you a buff."])
	end

	local tail = CreateFrame("Frame", nil, box)
	tail:SetPoint("TOPLEFT", 0, -(SEARCH_H + HEAD_H))
	tail:SetPoint("TOPRIGHT", 0, -(SEARCH_H + HEAD_H))
	tail:SetHeight(NOMATCH_H)
	self:CreateEmptyState(tail, L["Nothing in this list matches."])
	list.noMatch = tail
	list.empty = self:CreateEmptyState(box, "")

	list.ruler = self:CreateText(box, "", "label")
	list.ruler:SetPoint("TOPLEFT")
	list.ruler:SetAlpha(0)

	local sf = content:GetParent()
	if sf and sf.HookScript then sf:HookScript("OnVerticalScroll", function() paintRows(list) end) end
	-- Measured on screen, where widths are real, and only for the page still shown, or the pool moves onto a hidden page
	box.Fit = function()
		if ui._current == "filters." .. key then paint(list) end
	end
	local fits = content._euiFit or {}
	content._euiFit = fits
	fits[#fits + 1] = box
	lists[key] = list
	return list
end

local function customStore()
	local p = profile()
	p.customCooldowns = p.customCooldowns or { nextId = 1, defs = {} }
	p.customCooldowns.defs = p.customCooldowns.defs or {}
	return p.customCooldowns
end

-- Cleared rather than stamped with the default, so the category default stays live and spellOverrides never grows a row per spell
local function clearField(key, field)
	if key == "custom" then
		for id in pairs(customStore().defs) do setOverride(id, field, nil) end
	else
		local list = lists[key]
		collect(list)
		for _, e in ipairs(list.all) do setOverride(e.id, field, nil) end
	end
	reroute()
	invalidate()
end

local function withSetAll(self, content, dd, key, field, fieldLabel, tooltip, deps, on)
	local btn = self:CreateButton(content, L["Set All"], nil, function()
		ns.ShowDialog({
			text     = L["Set every cooldown in %s to follow the category default for %s? Any per-spell choice for that setting is cleared."]:format(categoryLabel(key), fieldLabel),
			button1  = YES,
			button2  = NO,
			danger   = true,
			onAccept = function() clearField(key, field) end,
		})
	end, tooltip)
	btn:SetPoint("RIGHT", dd._euiRow, "RIGHT", -ui:Spacing("rowPadding"), 0)
	dd:SetPoint("RIGHT", btn, "LEFT", -GAP, 0)
	deps[#deps + 1] = { btn, on }
end

local function defaultsCard(self, content, push, key, deps, afterShowByDefault)
	local function cfg() return filterCfg(key) end
	local function on() return cfg().enabled ~= false end
	local R, Q = Settings.Binder(cfg, reroute), Settings.Binder(cfg)
	local first = #content._controls + 1

	local card = push(self:CreateGroup(content, L["Defaults"]))
	local get, set = Q.key("enabled", true, function() content._sync() end)
	card:Add(self:CreateCheckbox(content, L["Track this category"], get, set,
		L["Untick to stop tracking this whole category. None of its cooldowns show on a lane or a bar, or pop a ready frame."]))
	local function dep(c)
		card:Add(c, { dependent = true })
		deps[#deps + 1] = { c, on }
		return c
	end
	get, set = Q.key("showByDefault", true, afterShowByDefault)
	dep(self:CreateCheckbox(content, L["Show by Default"], get, set,
		L["On: spells in this category show unless you hide one individually. Off: spells stay hidden until you enable each one."]))
	get, set = Q.key("ignoreThreshold", 1800)
	dep(Settings.Slider(self, content, L["Ignore Threshold (sec)"], 60, 3600, 5, get, set,
		L["Stop tracking any cooldown in this category whose full length is longer than this many seconds. Use it to hide very long cooldowns (like 30+ minute abilities) so they never show on a lane or pop ready. A spell you explicitly enable in the list below still shows. Unlike a lane's Max Time, this filters by the ability's total cooldown, not how much of the timeline is drawn."]))
	get, set = R.key("defaultLane", 1)
	local lane = dep(self:CreateDropdown(content, L["Default Lane"], lanes, get, set,
		L["Which lane this category's cooldowns travel along. The chosen lane must also be enabled under Lanes - one marked (off) draws nothing."]))
	get, set = Q.key("readyBox", 0)
	local ready = dep(self:CreateDropdown(content, L["Ready Box"], BOXES, get, set,
		L["Which ready box this category's cooldowns pop into the moment they come up. Off means they never pop."]))
	get, set = R.key("defaultBar", 0)
	local bar = dep(self:CreateDropdown(content, L["Default Bar"], BARS, get, set,
		L["Which bar frame this category's cooldowns appear in. The chosen Bars frame must also be enabled under Bars. Off shows no bar."]))

	withSetAll(self, content, lane, key, "lane", L["Lane"],
		L["Makes every cooldown in this category follow the Default Lane above. Any per-spell Lane you picked in the category's list is cleared. Show, Bar, Ready Box, Important and Pinned choices are left alone."], deps, on)
	withSetAll(self, content, ready, key, "readyBox", L["Ready Box"],
		L["Makes every cooldown in this category follow the Ready Box above. Any per-spell Ready Box you picked in the category's list is cleared. Show, Lane, Bar, Important and Pinned choices are left alone."], deps, on)
	withSetAll(self, content, bar, key, "bar", L["Bar"],
		L["Makes every cooldown in this category follow the Default Bar above. Any per-spell Bar you picked in the category's list is cleared. Show, Lane, Ready Box, Important and Pinned choices are left alone."], deps, on)
	local made = {}
	for i = first, #content._controls do made[#made + 1] = content._controls[i] end
	return on, made
end

local function buildCategory(key)
	return function(self, content)
		local push, restack = Settings.CardStack()
		local deps = {}
		local list, intro
		local on = defaultsCard(self, content, push, key, deps, function() paint(list) end)

		if key == "offensives" then
			local hint = push(self:CreateGroup(content, nil))
			local block = self:CreateTextBlock(content)
			intro = { card = hint, title = block:AddLine("", "value"), body = block:AddLine("", "hint", { gap = 6 }) }
			hint:Add(block, { fitHeight = true })
		end

		list = newList(self, content, push(self:CreateGroup(content, categoryLabel(key))), key, restack)

		content._sync = function()
			Settings.Dims(deps)
			if intro then
				local how = ns.Compat.HAS_COMBAT_LOG
					and L["Harmful effects you put on a target are detected automatically as you apply them - nothing to set up."]
					or L["A target's debuff cannot be identified in combat, so Cooldown Master learns which of your abilities applies which effect out of combat, from what lands just after you cast.\n\nSince 12.1 the game withholds that too, so an effect it has not already learned cannot be picked up at all. /cm offlearn tells you when your client is withholding it rather than leaving you guessing, and where the game still allows learning, it walks you through one ability at a time - type /cm offlearn, cast the ability, let combat end, then /cm offlearn stop. Anything already learned keeps tracking normally."]
				if on() then
					intro.title:SetText(L["Learning your offensives"])
				else
					intro.title:SetText(L["Offensives is turned off"])
					how = L["This category tracks the harmful effects you put on your target - damage-over-time effects, and debuffs like stuns - so each one travels a lane and pops a ready box when it drops. Nothing in this category is tracked while it is switched off - tick Track this category above to switch it on.\n\n"] .. how
				end
				intro.body:SetText(how)
				intro.card:Layout()
			end
			paint(list)
			restack()
			-- The introduction grows and shrinks with the switch, moving the list without changing its own height
			if intro then ui:MeasureContent(content) end
		end
	end
end

local CUSTOM_ROW, ADD_ROW, EDIT_W, CUSTOM_ICON = 40, 48, 74, 134400
local customSelected, customSync

local TRIGGERS = {
	{ value = "spell", label = L["Spell cast"] },
	{ value = "aura",  label = L["Aura gained"] },
}

-- Saved bare and translated only here, since def.name persists and the real-name swap compares it with the bare sentinel
local function customName(def)
	if def.name == "New Custom" then return L["New Custom"] end
	return def.name or L["Custom"]
end

local function resolveCustom(def)
	if not (def.triggerID and C_Spell and C_Spell.GetSpellInfo) then return end
	local info = C_Spell.GetSpellInfo(def.triggerID)
	if info then
		def.icon = info.iconID or def.icon
		if not def.name or def.name == "" or def.name == "New Custom" then def.name = info.name end
	end
end

local function rebuildCustom()
	if ns.Engine and ns.Engine.RebuildCustomTriggers then ns.Engine:RebuildCustomTriggers() end
end

local function newCustom()
	-- Older profiles default the custom category to switched off, so it is forced on or the new cooldown is filtered out
	local p = profile()
	if p.filters and p.filters.custom then
		p.filters.custom.enabled = true
		p.filters.custom.showByDefault = true
	end
	local store = customStore()
	store.nextId = store.nextId or 1
	local id = ns.CONST.CUSTOM_ID_BASE + store.nextId
	store.nextId = store.nextId + 1
	store.defs[id] = { id = id, name = "New Custom", icon = CUSTOM_ICON, triggerType = "spell", triggerID = nil,
	                   durationMs = 30000, enabled = true }
	return id
end

local function deleteCustom(id)
	local p = profile()
	if p.customCooldowns and p.customCooldowns.defs then p.customCooldowns.defs[id] = nil end
	if p.spellOverrides then p.spellOverrides[id] = nil end
	if ns.Engine and ns.Engine.entries then ns.Engine.entries[id] = nil end
end

local function setCustomEnabled(def, v)
	def.enabled = v
	rebuildCustom()
	if not v and ns.Engine and ns.Engine.entries then ns.Engine.entries[def.id] = nil end
end

local function askDelete(id, after)
	ns.ShowDialog({
		text = L["Delete this custom cooldown?"],
		button1 = YES,
		button2 = NO,
		danger = true,
		onAccept = function()
			deleteCustom(id)
			rebuildCustom()
			after()
		end,
	})
end

local paintName = Settings.PaintName

local idList = {}

local function customIDs()
	local defs = customStore().defs
	for i = #idList, 1, -1 do idList[i] = nil end
	for id in pairs(defs) do idList[#idList + 1] = id end
	table.sort(idList)
	return idList, defs
end

local function buildCustom(self, content)
	local push, restack = Settings.CardStack()
	local deps = {}
	local editor
	local pad = ui:Spacing("rowPadding")
	local function sync() content._sync() end
	local function selected() return customSelected and customStore().defs[customSelected] end
	local function routed() local d = selected() return d and override(d.id) end

	local intro = push(self:CreateGroup(content, nil))
	local block = self:CreateTextBlock(content)
	block:AddLine(L["Custom cooldowns run a local timer you define - a fixed duration plus a trigger. They never read a live cooldown, so they behave the same in combat."], "hint")
	intro:Add(block, { fitHeight = true })

	local _, defaults = defaultsCard(self, content, push, "custom", deps)

	local listCard = push(self:CreateGroup(content, L["Custom"]))
	local box = CreateFrame("Frame", nil, content)
	box._euiFill = true
	listCard:Add(box, { height = ADD_ROW })
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", box._euiRow, "TOPLEFT")
	box:SetPoint("BOTTOMRIGHT", box._euiRow, "BOTTOMRIGHT")
	local none = CreateFrame("Frame", nil, box)
	none:SetPoint("TOPLEFT")
	none:SetPoint("TOPRIGHT")
	none:SetHeight(NOMATCH_H)
	self:CreateEmptyState(none, L["No custom cooldowns yet. Add one below."])
	local addRow = CreateFrame("Frame", nil, box)
	addRow:SetHeight(ADD_ROW)
	ui:Paint(addRow, nil, "divider", "T")
	local add = self:CreateButton(addRow, L["Add Custom Cooldown"], nil, function()
		customSelected = newCustom()
		rebuildCustom()
		-- Adding switches the category on, which its Defaults card has to show
		for _, c in ipairs(defaults) do c:Refresh() end
		sync()
		self:ScrollIntoView(editor)
	end, L["Create a new custom cooldown - its editor opens below so you can set its trigger and duration."])
	add:SetPoint("LEFT", pad, 0)
	local pick = self:CreateText(addRow, L["Select a custom cooldown above to edit it."], "hint")
	pick:SetPoint("LEFT", add, "RIGHT", pad, 0)

	local lines = {}
	local function line(i)
		if lines[i] then return lines[i] end
		local r = CreateFrame("Frame", nil, box)
		r:SetHeight(CUSTOM_ROW)
		r._controls = {}
		local _, edges = ui:Paint(r, nil, "divider", "T")
		r.divider = edges[1]
		r.tint = r:CreateTexture(nil, "BACKGROUND")
		r.tint:SetAllPoints()
		r.tint:SetColorTexture(ui:Color("accentSoft"))
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(ICON_SIZE, ICON_SIZE)
		r.icon:SetPoint("LEFT", pad, 0)
		r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		r.del = self:CreateIconButton(r, "close", BUTTON_SIZE)
		r.del:SetPoint("RIGHT", -pad, 0)
		r.del:SetScript("OnClick", function() askDelete(r.id, sync) end)
		self:AttachTooltip(r.del, L["Delete"], L["Remove this custom cooldown."])
		r.edit = self:CreateButton(r, L["Edit"], EDIT_W, function()
			customSelected = (customSelected ~= r.id) and r.id or nil
			sync()
			if customSelected then self:ScrollIntoView(editor) end
		end)
		r.edit:SetPoint("RIGHT", r.del, "LEFT", -6, 0)
		r.on = self:CreateCheckbox(r, nil,
			function()
				local d = customStore().defs[r.id]
				return d and d.enabled ~= false
			end,
			function(v)
				local d = customStore().defs[r.id]
				if d then setCustomEnabled(d, v) end
				sync()
			end)
		r.on:SetPoint("RIGHT", r.edit, "LEFT", -pad, 0)
		self:AttachTooltip(r.on, L["Enabled"], L["Toggle this custom cooldown on or off without opening it."])
		r.name = self:CreateText(r, "", "label")
		r.font = { r.name:GetFont() }
		r.name:SetWordWrap(false)
		r.name:SetPoint("LEFT", r.icon, "RIGHT", GAP, 0)
		r.name:SetPoint("RIGHT", r.on, "LEFT", -GAP, 0)
		lines[i] = r
		return r
	end

	editor = push(self:CreateGroup(content, " "))
	local editorFont = { editor.label:GetFont() }
	local held = {}
	local function row(c, opts)
		editor:Add(c, opts)
		held[#held + 1] = c
		return c
	end
	row(self:CreateTextField(content, L["Name"],
		function() local d = selected() return d and d.name or "" end,
		function(t)
			local d = selected()
			if not d then return end
			if t == "" then
				d.name = nil
				resolveCustom(d)
			else
				d.name = t
			end
			rebuildCustom()
			sync()
		end, L["Shown on the cooldown's icon tooltip and bar. Left blank, it follows the trigger spell's name."], { maxLetters = 40 }))
	row(self:CreateDropdown(content, L["Trigger"], TRIGGERS,
		function() local d = selected() return d and d.triggerType or "spell" end,
		function(v)
			local d = selected()
			if not d then return end
			d.triggerType = v
			rebuildCustom()
			sync()
		end, L["Spell cast starts the timer when you cast the entered spell. On-use trinkets, potions and flasks all count - enter the spell the item casts. This is the reliable choice.\n\nAura gained starts it when you gain the entered buff. On retail, the game hides your buffs from addons while you are in combat, so a buff gained mid-fight cannot be seen and the timer will not start. Prefer Spell cast for anything you cast or use."]))
	local idField = row(self:CreateTextField(content, L["Trigger ID"],
		function() local d = selected() return d and d.triggerID and tostring(d.triggerID) or "" end,
		function(t)
			local d = selected()
			if not d then return end
			d.triggerID = tonumber(t)
			resolveCustom(d)
			rebuildCustom()
			sync()
		end, nil, { maxLetters = 10, numeric = true }))
	-- Its tooltip follows the trigger type, so it is shown by hand rather than fixed once
	local function idTip()
		local d = selected()
		ui:ShowTooltip(idField, L["Trigger ID"], d and d.triggerType == "aura"
			and L["The buff's spell ID (often different from the ability that grants it). Not sure of the ID? Use the Detect button."]
			or L["The spell ID you cast that fires this cooldown. For an on-use item, enter the spell the item casts."])
	end
	for _, f in ipairs({ idField, idField.field, idField.box }) do
		f:EnableMouse(true)
		f:HookScript("OnEnter", idTip)
		f:HookScript("OnLeave", function() ui:HideTooltip() end)
	end
	local icon = content:CreateTexture(nil, "ARTWORK")
	icon:SetSize(22, 22)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	held[#held + 1] = icon
	local detectToken, detectDef
	local detect = self:CreateButton(content, L["Detect"], nil, function()
		local d, engine = selected(), ns.Engine
		if not (d and engine and engine.ArmAuraCapture) then return end
		local armed = engine:ArmAuraCapture(function(spellID, name, iconID, duration)
			detectDef = nil
			-- Called from inside the Engine's aura event, so the page is drawn again a frame later
			C_Timer.After(0, sync)
			-- A capture outlives a trigger change, a delete or a profile switch, so it fills only the cooldown it was armed for
			if customStore().defs[d.id] ~= d or d.triggerType ~= "aura" then return end
			d.triggerID = spellID
			if iconID then d.icon = iconID end
			if name and (not d.name or d.name == "" or d.name == "New Custom") then d.name = name end
			-- 0 is a permanent buff, so only a real timer overrides the default
			if duration and duration > 0 then d.durationMs = math.floor(duration * 1000 + 0.5) end
			rebuildCustom()
		end)
		-- Refused (Forever in combat), a capture already waiting for another cooldown keeps its own timer
		if not armed then
			sync()
			return
		end
		detectDef = d
		local token = {}
		detectToken = token
		sync()
		C_Timer.After(15, function()
			if detectToken ~= token then return end
			detectToken, detectDef = nil, nil
			if engine._auraCaptureArmed then engine:CancelAuraCapture() end
			sync()
		end)
	end, L["Click, then gain the buff in-game within 15 seconds - CDM fills in its ID, name, icon and duration."])
	detect:SetPoint("RIGHT", idField._euiRow, "RIGHT", -pad, 0)
	held[#held + 1] = detect
	idField:SetPoint("RIGHT", icon, "LEFT", -GAP, 0)
	row(Settings.Slider(self, content, L["Duration (sec)"], 1, 3600, 1,
		function() local d = selected() return ((d and d.durationMs) or 30000) / 1000 end,
		function(v)
			local d = selected()
			if d then d.durationMs = v * 1000 end
		end, L["How long the timer runs after the trigger fires. Click the number to type an exact value."]))
	row(self:CreateDropdown(content, L["Lane"], laneRow,
		function() local o = routed() return (o and o.lane) or 0 end,
		function(v)
			local d = selected()
			if not d then return end
			setOverride(d.id, "lane", v ~= 0 and v or nil)
			reroute()
		end, L["Which lane this cooldown travels in. Default follows this category's Default Lane, set above."]))
	row(self:CreateDropdown(content, L["Bar"], BAR_ROW,
		function()
			local o = routed()
			if o and o.bar ~= nil then return o.bar end
			return -1
		end,
		function(v)
			local d = selected()
			if not d then return end
			setOverride(d.id, "bar", v ~= -1 and v or nil)
			reroute()
		end, L["Which bar frame this cooldown shows on. Default follows this category's Default Bar. Off keeps it off the bars without hiding it from your lanes or ready boxes."]))
	row(self:CreateDropdown(content, L["Ready Box"], BOX_ROW,
		function()
			local o = routed()
			if o and o.readyBox ~= nil then return o.readyBox end
			return -1
		end,
		function(v)
			local d = selected()
			if d then setOverride(d.id, "readyBox", v ~= -1 and v or nil) end
		end, L["Which ready box this pops into the moment the cooldown comes up. Default follows this category's Ready Box. Off means it never pops."]))
	row(self:CreateDropdown(content, L["Flags"], FLAGS,
		function()
			local o = routed()
			return ((o and o.important) and 1 or 0) + ((o and o.pinned) and 2 or 0)
		end,
		function(v)
			local d = selected()
			if not d then return end
			setOverride(d.id, "important", (v % 2) == 1 or nil)
			setOverride(d.id, "pinned", v >= 2 or nil)
		end, L["How this one behaves once it pops into a ready box.\n\nNormal - fades after the box's Display Duration.\n\nImportant - highlights the icon and holds it for the box's Highlight Duration instead, and plays the box's Highlight Sound (set to None until you pick one).\n\nPinned - the icon never fades. It stays until you reload, switch profile or start or stop Test Mode, and a box full of pinned icons has no room for new pops.\n\nImp + Pin - both."]))
	row(self:CreateCheckbox(content, L["Enabled"],
		function() local d = selected() return d and d.enabled ~= false end,
		function(v)
			local d = selected()
			if not d then return end
			setCustomEnabled(d, v)
			sync()
		end))
	local delRow = CreateFrame("Frame", nil, content)
	delRow:SetHeight(ui:Spacing("buttonHeight"))
	delRow._euiFill = true
	row(delRow)
	local del = self:CreateButton(delRow, L["Delete"], nil, function()
		local d = selected()
		if d then askDelete(d.id, sync) end
	end, L["Remove this custom cooldown."], "danger")
	del:SetPoint("RIGHT")

	-- Measured on screen, where the buttons' translated labels have their real widths
	function box.Fit()
		add.Fit()
		del.Fit()
		detect.Fit()
	end
	local fits = content._euiFit or {}
	content._euiFit = fits
	fits[#fits + 1] = box

	customSync = sync
	content._sync = function()
		Settings.Dims(deps)
		local ids, defs = customIDs()
		if customSelected and not defs[customSelected] then customSelected = nil end
		for i, id in ipairs(ids) do
			local r, d = line(i), defs[id]
			local y = -(i - 1) * CUSTOM_ROW
			r.id = id
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", box, "TOPLEFT", 0, y)
			r:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, y)
			r.divider:SetShown(i > 1)
			r.tint:SetShown(id == customSelected)
			r.icon:SetTexture(d.icon or CUSTOM_ICON)
			paintName(r.name, r.font, customName(d), d.enabled ~= false and "text" or "muted")
			r.edit:SetText(id == customSelected and L["Editing"] or L["Edit"])
			r.on:Refresh()
			r:Show()
		end
		for i = #ids + 1, #lines do lines[i]:Hide() end
		none:SetShown(#ids == 0)
		local top = #ids == 0 and NOMATCH_H or #ids * CUSTOM_ROW
		addRow:ClearAllPoints()
		addRow:SetPoint("TOPLEFT", 0, -top)
		addRow:SetPoint("TOPRIGHT", 0, -top)
		pick:SetShown(#ids > 0 and not customSelected)
		local h = top + ADD_ROW
		if math.abs((box._euiRow:GetHeight() or 0) - h) > 0.5 then
			box._euiRow:SetHeight(h)
			listCard:Layout()
		end

		local d = selected()
		Settings.ShowCard(editor, d ~= nil, held)
		if d then
			paintName(editor.label, editorFont, customName(d), "muted")
			for _, c in ipairs(held) do
				if c.Refresh then c:Refresh() end
			end
			icon:SetTexture(d.icon or CUSTOM_ICON)
			local canDetect = d.triggerType == "aura" and ns.Engine and ns.Engine.ArmAuraCapture and true or false
			detect:SetShown(canDetect)
			detect:SetText(canDetect and ns.Engine._auraCaptureArmed and detectDef == d and L["Gain a buff..."] or L["Detect"])
			detect.Fit()
			icon:ClearAllPoints()
			if canDetect then
				icon:SetPoint("RIGHT", detect, "LEFT", -GAP, 0)
			else
				icon:SetPoint("RIGHT", idField._euiRow, "RIGHT", -pad, 0)
			end
		end
		restack()
		ui:MeasureContent(content)
	end
end

local overviewBox

local function overview(self, content, card)
	local keys = {}
	for _, def in ipairs(ns.CONST.FILTER_CATEGORIES) do
		if Settings.CategoryIsOffered(def.key) then keys[#keys + 1] = def end
	end
	local box = CreateFrame("Frame", nil, content)
	box._euiFill = true
	card:Add(box, { height = HEAD_H + #keys * ROW_H })
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", box._euiRow, "TOPLEFT")
	box:SetPoint("BOTTOMRIGHT", box._euiRow, "BOTTOMRIGHT")

	local pad = ui:Spacing("rowPadding")
	local xBar = -pad - OVERVIEW_COL
	local xReady = xBar - OVERVIEW_COL
	local xLane = xReady - OVERVIEW_COL
	local xOn = xLane - OVERVIEW_ON
	local function cell(parent, x, w, text, style, center)
		local fs = self:CreateText(parent, text or "", style)
		fs:SetPoint("LEFT", parent, "RIGHT", x, 0)
		fs:SetWidth(w)
		fs:SetWordWrap(false)
		if center then fs:SetJustifyH("CENTER") end
		return fs
	end
	local head = CreateFrame("Frame", nil, box)
	head:SetPoint("TOPLEFT")
	head:SetPoint("TOPRIGHT")
	head:SetHeight(HEAD_H)
	cell(head, xOn, OVERVIEW_ON, L["Enabled"], "groupLabel", true)
	cell(head, xLane, OVERVIEW_COL, L["Lane"], "groupLabel")
	cell(head, xReady, OVERVIEW_COL, L["Ready Box"], "groupLabel")
	cell(head, xBar, OVERVIEW_COL, L["Bar"], "groupLabel")

	local lines = {}
	for i, def in ipairs(keys) do
		local r = CreateFrame("Button", nil, box)
		local y = -(HEAD_H + (i - 1) * ROW_H)
		r:SetPoint("TOPLEFT", 0, y)
		r:SetPoint("TOPRIGHT", 0, y)
		r:SetHeight(ROW_H)
		ui:Paint(r, nil, "divider", "T")
		local hover = r:CreateTexture(nil, "HIGHLIGHT")
		hover:SetAllPoints()
		hover:SetColorTexture(ui:Color("hover"))
		r.name = self:CreateText(r, def.label, "label")
		r.name:SetPoint("LEFT", pad, 0)
		r.check = r:CreateTexture(nil, "ARTWORK")
		r.check:SetSize(14, 14)
		r.check:SetTexture(ui:Texture("check"))
		r.check:SetVertexColor(ui:Color("accentHi"))
		r.check:SetPoint("CENTER", r, "RIGHT", xOn + OVERVIEW_ON / 2, 0)
		r.off = cell(r, xOn, OVERVIEW_ON, L["Off"], "label", true)
		r.lane = cell(r, xLane, OVERVIEW_COL, nil, "label")
		r.ready = cell(r, xReady, OVERVIEW_COL, nil, "label")
		r.bar = cell(r, xBar, OVERVIEW_COL, nil, "label")
		r.key = def.key
		r.cells = { r.off, r.lane, r.ready, r.bar }
		r:SetScript("OnClick", function() self:SelectTab("filters." .. def.key) end)
		lines[i] = r
	end

	function box.Refresh()
		for _, r in ipairs(lines) do
			local c = filterCfg(r.key)
			local on = c.enabled ~= false
			r.check:SetShown(on)
			r.off:SetShown(not on)
			r.name:SetTextColor(ui:Color(on and "text" or "muted"))
			local readyBox, defaultBar = c.readyBox or 0, c.defaultBar or 0
			r.lane:SetText(laneLabel(c.defaultLane or 1))
			r.ready:SetText(readyBox > 0 and L["Box %d"]:format(readyBox) or L["Off"])
			r.bar:SetText(defaultBar > 0 and L["Bars %d"]:format(defaultBar) or L["Off"])
			for _, fs in ipairs(r.cells) do fs:SetTextColor(ui:Color(on and "label" or "muted")) end
		end
	end
	box.Refresh()
	content._controls[#content._controls + 1] = box
	overviewBox = box
	return box
end

local function buildDefaults(self, content)
	local push = Settings.CardStack()
	local deps = {}
	local function sync() content._sync() end
	local function band() return profile().laneByDuration end
	local B = Settings.Binder(band, reroute)

	local card = push(self:CreateGroup(content, L["Route by Cooldown Length"]))
	local get, set = B.key("enabled", false, sync)
	card:Add(self:CreateCheckbox(content, L["Sort cooldowns into lanes by length"], get, set,
		L["Sends a cooldown to a lane based on how long it is rather than what kind it is, so short cooldowns can run a fast lane and long ones a slow lane. A lane you picked for an individual spell still wins over this. A cooldown Cooldown Master has not timed yet goes by the length the game lists for it, and falls back to its category's Default Lane only when neither is known."]))
	local function on() return band().enabled end
	local function dep(c)
		card:Add(c, { dependent = true })
		deps[#deps + 1] = { c, on }
		return c
	end
	get, set = B.key("shortMax", 60, sync)
	dep(Settings.Slider(self, content, L["Short Up To (sec)"], 5, 300, 1, get, set,
		L["A cooldown this long or shorter counts as short."]))
	get, set = B.key("shortLane", 1)
	dep(self:CreateDropdown(content, L["Short Lane"], lanes, get, set))
	get, set = B.key("midMax", 180)
	local mid = dep(Settings.Slider(self, content, L["Medium Up To (sec)"], 5, 600, 1, get, set,
		L["A cooldown longer than Short Up To but no longer than this counts as medium. Anything above it is long."]))
	get, set = B.key("midLane", 2)
	dep(self:CreateDropdown(content, L["Medium Lane"], lanes, get, set))
	get, set = B.key("longLane", 3)
	dep(self:CreateDropdown(content, L["Long Lane"], lanes, get, set))

	local box = overview(self, content, push(self:CreateGroup(content, L["Category Defaults"])))

	content._sync = function()
		-- Medium starts where Short ends, the floor the engine already puts under a lower value
		mid.SetRange(band().shortMax or 60, 600)
		Settings.Dims(deps)
		box.Refresh()
	end
end

local queued

local function repaint()
	queued = nil
	local f = Settings.frame
	if not (f and f:IsShown()) then return end
	local id = ui._current
	if id == "filters.defaults" then
		if overviewBox then overviewBox.Refresh() end
		return
	end
	if id == "filters.custom" then
		if customSync then customSync() end
		return
	end
	local list = id and lists[id:match("^filters%.(.+)$") or ""]
	if list then paint(list) end
end

-- A frame later and once per burst, so a looting spree repaints once and the Engine's own call never runs the page
function Settings.FiltersChanged()
	if queued then return end
	local f = Settings.frame
	if not (f and f:IsShown()) then return end
	queued = true
	C_Timer.After(0, repaint)
end

-- The Engine tells the settings window about new and changed cooldowns by these names
ns.Options_InvalidateFilterLists = Settings.FiltersChanged
ns.Options_UpdateTrackedItemDisplay = Settings.FiltersChanged

ui:RegisterTab({ id = "filters", title = L["Filters"], order = 50, icon = Settings.Icon("icon-filter"), group = true })
ui:RegisterTab({ id = "filters.defaults", parent = "filters", title = L["Defaults"], order = 1, footer = Settings.Footer,
                 build = buildDefaults, refresh = function(_, content) content._sync() end })

local order = 1
for _, def in ipairs(ns.CONST.FILTER_CATEGORIES) do
	if Settings.CategoryIsOffered(def.key) then
		order = order + 1
		ui:RegisterTab({ id = "filters." .. def.key, parent = "filters", title = def.label, order = order,
		                 footer = Settings.Footer, build = def.key == "custom" and buildCustom or buildCategory(def.key),
		                 refresh = function(_, content) content._sync() end })
	end
end
