local _, ns = ...
local L = ns.L

local Settings = ns.Settings
local ui = Settings.ui

local function global()
	return ns.CDM.db.profile.global
end

local function check(key, after)
	return function() return global()[key] end,
		function(v)
			global()[key] = v
			if after then after() end
		end
end

local function number(key, fallback, after)
	return function() return global()[key] or fallback end,
		function(v)
			if type(v) ~= "number" then return end
			global()[key] = v
			if after then after(v) end
		end
end

local function refreshLaneVisibility()
	if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
end

-- A slider reports every drag step, so restarts are batched to one per 0.15 s
local testReseedPending

local function doTestReseed()
	testReseedPending = nil
	if ns.Engine and ns.Engine.testActive then ns.Engine:StartTestMode() end
end

local function requestTestReseed()
	if testReseedPending or not (ns.Engine and ns.Engine.testActive) then return end
	testReseedPending = true
	C_Timer.After(0.15, doTestReseed)
end

local function enabledCard(self, content, stack, deps)
	local card = stack(self:CreateGroup(content, L["Enabled"]))
	local get, set = check("enabledAlways", function()
		refreshLaneVisibility()
		deps.sync()
	end)
	card:Add(self:CreateCheckbox(content, L["Always"], get, set,
		L["Show your lanes at all times, no matter where you are. When on, the In Group and In Instance conditions do not matter."]))
	get, set = check("enabledGroup", refreshLaneVisibility)
	local group = self:CreateCheckbox(content, L["In Group"], get, set,
		L["Show your lanes only while you are in a party or raid. Any ticked visibility box can show them, so this stacks with In Instance."])
	card:Add(group, { dependent = true })
	get, set = check("enabledInstance", refreshLaneVisibility)
	local instance = self:CreateCheckbox(content, L["In Instance"], get, set,
		L["Show your lanes only while you are inside a dungeon, raid, or other instance. Any ticked visibility box can show them."])
	card:Add(instance, { dependent = true })
	local function unlessAlways() return not global().enabledAlways end
	deps[#deps + 1] = { control = group, on = unlessAlways }
	deps[#deps + 1] = { control = instance, on = unlessAlways }
end

local function generalCard(self, content, stack, deps)
	local card = stack(self:CreateGroup(content, L["General"]))
	local get, set = check("autohide", function() ns.ForEachSurface("RefreshVisibility") end)
	card:Add(self:CreateCheckbox(content, L["Auto-hide Frames"], get, set,
		L["Out of combat, hides each lane's background, border, name, and markers, but your tracked cooldown icons stay visible. The chrome returns in combat. Tick a lane's Override Autohide (Lanes > General) to keep its chrome always shown."]))
	get, set = check("enableTooltip")
	card:Add(self:CreateCheckbox(content, L["Enable tooltips"], get, set,
		L["Show the spell or item tooltip when you hover a cooldown icon on a lane. Icons take the mouse only while frames are locked, so this never blocks dragging."]))
	get, set = check("detectSharedCD")
	card:Add(self:CreateCheckbox(content, L["Detect Shared Spell Cooldowns"], get, set,
		L["When one ability is tracked under two spell IDs that share a cooldown (a base spell and its talent override, or the same spell in two categories), show one icon and one ready pop instead of duplicates."]))
	get, set = check("notUsableTint", function() deps.sync() end)
	card:Add(self:CreateCheckbox(content, L["Tint Unusable Icons"], get, set,
		L["While a spell or item cannot be used right now (not enough resources, wrong stance, out of range), tint its icon with the Unusable Tint Color below."]))
	local tint = self:CreateColorPicker(content, L["Unusable Tint Color"],
		function() return global().notUsableColor end,
		function(v)
			local c = global().notUsableColor
			c.r, c.g, c.b = v.r, v.g, v.b
		end)
	card:Add(tint, { dependent = true })
	deps[#deps + 1] = { control = tint, on = function() return global().notUsableTint end }
	get, set = check("notUsableDesaturate")
	card:Add(self:CreateCheckbox(content, L["Desaturate Unusable Icons"], get, set,
		L["While a spell or item cannot be used right now, draw its icon in greyscale. Can be combined with Tint Unusable Icons."]))
	get, set = number("zoom", 1)
	card:Add(self:CreateSlider(content, L["Icon Zoom"], 1, 2, 0.05, get, set).EnableTyping())
	card:Add(self:CreateCheckbox(content, L["Show Minimap Button"],
		function() return not ns.CDM.db.profile.dataBroker.minimap.hide end,
		function(v)
			if v == ns.CDM.db.profile.dataBroker.minimap.hide and ns.DataBroker_ToggleMinimap then
				ns.DataBroker_ToggleMinimap(ns.CDM)
			end
		end))
end

local function testCard(self, content, stack)
	local card = stack(self:CreateGroup(content, L["Test Mode"]))
	local typeLists = {}
	-- A type this client does not offer stays listed while it is the saved one, so the field never shows a value it cannot name
	local function types()
		local saved = global().testType or "mixed"
		local list = typeLists[saved]
		if not list then
			list = {}
			for _, def in ipairs(ns.CONST.TEST_TYPES) do
				if def.value == saved or Settings.CategoryIsOffered(def.value) then
					list[#list + 1] = { value = def.value, label = def.text }
				end
			end
			typeLists[saved] = list
		end
		return list
	end
	card:Add(self:CreateDropdown(content, L["Type"], types,
		function() return global().testType or "mixed" end,
		function(v)
			global().testType = v
			requestTestReseed()
		end,
		L["Which kind of sample cooldowns to create. Mixed uses a spread of your spells, buffs and utility. Each type is routed with that category's Lane, Bar and Ready Box settings, so this previews your own Filters routing."]))
	local get, set = number("testCount", 6, requestTestReseed)
	card:Add(self:CreateSlider(content, L["Number of Cooldowns"], 1, 20, 1, get, set,
		L["How many sample cooldowns to create, from 1 to 20. A ready box only holds as many icons as its Max Ready Icons setting, so extras push the oldest pop out."]).EnableTyping())
	get, set = number("testFirst", 5, requestTestReseed)
	card:Add(self:CreateSlider(content, L["First Cooldown Duration"], 1, 600, 1, get, set,
		L["Length of the first sample cooldown, in seconds. The rest are spread evenly between this and the Last Cooldown Duration."]).EnableTyping())
	get, set = number("testLast", 120, requestTestReseed)
	card:Add(self:CreateSlider(content, L["Last Cooldown Duration"], 1, 600, 1, get, set,
		L["Length of the last sample cooldown, in seconds. A lane only draws cooldowns up to its Max Time unless you turn off Hide Long Timers, so a value above that will not appear on the lane."]).EnableTyping())
	card:Add(self:CreateCheckbox(content, L["Loop"],
		function() return global().testLoop ~= false end,
		function(v)
			global().testLoop = v
			requestTestReseed()
		end,
		L["Keep restarting the sample cooldowns after they pop into the ready box. Turn this off to watch them run once and clear."]))
end

local function rescaleFrames(v)
	local g = global()
	local old = (type(g.frameScale) == "number" and g.frameScale > 0) and g.frameScale or 1
	if v <= 0 then return end
	g.frameScale = v
	-- Offsets are stored in each frame's own scaled units, so rescale them to hold the on-screen position as the scale changes.
	if old ~= v then
		local ratio = old / v
		for _, key in ipairs({ "lanes", "readyFrames", "barFrames" }) do
			local list = ns.CDM.db.profile[key]
			if list then
				for _, c in pairs(list) do
					if type(c.x) == "number" then c.x = c.x * ratio end
					if type(c.y) == "number" then c.y = c.y * ratio end
				end
			end
		end
	end
	for i = 1, 3 do
		if ns.Lanes_ApplyConfig then ns.Lanes_ApplyConfig(i) end
		if ns.ReadyFrames_ApplyConfig then ns.ReadyFrames_ApplyConfig(i) end
		if ns.Bars_ApplyConfig then ns.Bars_ApplyConfig(i) end
	end
end

local function scaleCard(self, content, stack)
	local card = stack(self:CreateGroup(content, L["Scale"]))
	local frames = self:CreateSlider(content, L["Cooldown Frames"], 0.5, 2, 0.05,
		function() return global().frameScale or 1 end,
		function(v) if type(v) == "number" then rescaleFrames(v) end end,
		L["Resize the cooldown display - your lanes, bars and ready boxes - together. 1.00 is the normal size, below shrinks them, above enlarges them. They keep their on-screen position as they scale."]).EnableTyping()
	card:Add(frames)

	local window = self:CreateSlider(content, L["Options Window"], 0.5, 2, 0.05,
		function() return global().optionsScale or 1 end,
		function(v) if type(v) == "number" and v > 0 then global().optionsScale = v end end,
		L["Resize this Cooldown Master settings window itself. 1.00 is the normal size. Applies when you let go of the slider or press Enter."]).EnableTyping()
	card:Add(window)
	-- Applied on release, never live: scaling mid-drag moves the track under the cursor and the value oscillates
	local function apply() self:ApplyWindowScale() end
	window.slider:HookScript("OnMouseUp", apply)
	window.entry:HookScript("OnEnterPressed", apply)
end

local function updatesCard(self, content, stack)
	local card = stack(self:CreateGroup(content, L["Updates"]))
	-- Account-wide (db.global), not per-profile: the update notice is a per-account preference.
	card:Add(self:CreateRadioGroup(content, L["After an update"], {
			{ value = "popup", label = L["Popup window"] },
			{ value = "chat",  label = L["Chat link"] },
			{ value = "none",  label = L["Off"] },
		},
		function() return ns.CDM.db.global.whatsNewMode or "popup" end,
		function(v)
			ns.CDM.db.global.whatsNewMode = v
			if ns.WhatsNew_Refresh then ns.WhatsNew_Refresh() end
		end,
		nil, nil, L["After an update"],
		L["How Cooldown Master tells you about a version that brings new features: a Popup window, a quiet clickable Chat link in your chat, or Off. Releases with only fixes stay quiet, and the next feature release shows them too. Reopen the notes any time with /cm whatsnew."]))
	card:Add(self:CreateButton(content, L["Show What's New"], nil, function()
		if ns.WhatsNew_Show then ns.WhatsNew_Show() end
	end))
end

ui:RegisterTab({
	id     = "global",
	title  = L["Global"],
	order  = 10,
	icon   = ui:Texture("icon-general"),
	footer = Settings.Footer,
	build  = function(self, content)
		local stack = Settings.CardStack()
		local deps = {}
		deps.sync = function()
			for _, d in ipairs(deps) do self:SetDependent(d.control, d.on() and true or false) end
		end
		content._sync = deps.sync
		enabledCard(self, content, stack, deps)
		generalCard(self, content, stack, deps)
		testCard(self, content, stack)
		scaleCard(self, content, stack)
		updatesCard(self, content, stack)
	end,
	refresh = function(_, content)
		if content._sync then content._sync() end
	end,
})
