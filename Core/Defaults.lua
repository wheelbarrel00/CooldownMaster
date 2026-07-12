local ADDON_NAME, ns = ...

local function lane(frameName, y, enabled)
	return {
		enabled        = enabled ~= false,
		frameName      = frameName,
		reversed       = false,
		vertical       = false,
		mode           = "LINEAR",
		maxTime        = 120,
		split          = {
			count  = 1,
			points = { { t = 30, p = 0.70 }, { t = 60, p = 0.85 }, { t = 90, p = 0.95 } },
		},
		hideLongTimers = true,
		overrideAutohide = false,
		primaryTracking   = "NONE",
		primaryReverse    = false,
		secondaryTracking = "NONE",
		secondaryReverse  = false,
		stWidth        = 7,
		stHeight       = 24,
		stTexture      = "CDM Smooth",
		stColor        = { r = 0.99, g = 0.99, b = 0.99, a = 0.85 },

		width          = 575,
		height         = 10,
		x              = 0,
		y              = y or -175,
		anchor         = "CENTER",
		bgTexture      = "CDM Smooth",
		bgColor        = { r = 0.196, g = 0.196, b = 0.196, a = 0.58 },
		bgClassColor   = false,
		alpha          = 1.0,
		borderTexture  = "CDM Shadow",
		borderEnabled  = true,
		borderColor    = { r = 0,   g = 0,   b = 0,   a = 0.48 },
		borderPadding  = 0,
		borderSize     = 1,

		iconSize       = 35,
		iconAlpha      = 1.0,
		iconOffset     = 0,
		swipeAlpha     = 0,   -- cooldown-swipe darkness; 0 = no tint (spell art fully visible)
		iconBorder      = true,
		iconBorderSize  = 1,
		iconBorderColor = { r = 0, g = 0, b = 0, a = 1 },
		iconText       = {
			{ enabled = true,  text = "[cd.stacks]" },
			{ enabled = true,  text = "[cd.time]"   },
			{ enabled = false, text = ""            },
		},
		iconFont       = "Friz Quadrata TT",
		iconFontSize   = 0,   -- 0 = auto (scales with iconSize, matching the native count)
		iconFontFlags  = "OUTLINE",
		iconFontColor  = { r = 1, g = 1, b = 1, a = 1 },


		laneTextFont   = "Friz Quadrata TT",
		laneTextSize   = 9,
		laneTextFlags  = "NONE",
		laneTextColor  = { r = 1, g = 1, b = 1, a = 0.53 },

		labelFont      = "Friz Quadrata TT",
		labelSize      = 10,
		labelFlags     = "OUTLINE",
		labelColor     = { r = 1, g = 1, b = 1, a = 1 },

		highlight      = { style = "NONE", color = { r = 1, g = 0.82, b = 0, a = 0.8 } },

		laneText = {
			{ enabled = true, text = "Ready", pos = 0    },
			{ enabled = true, text = "25%",   pos = 0.25 },
			{ enabled = true, text = "50%",   pos = 0.50 },
			{ enabled = true, text = "75%",   pos = 0.75 },
			{ enabled = true, text = "100%",  pos = 1    },
		},

		stackEnabled       = false,
		stackRaiseHover    = false,
		stackStyle         = "GROUPED",
		stackGrowDirection = "UP",
		stackHeight        = 150,
	}
end

local function readyFrame(frameName, x, y, enabled)
	return {
		enabled        = enabled,
		frameName      = frameName,
		anchor         = "CENTER",
		x              = x,
		y              = y,
		alpha          = 1.0,
		growDirection  = "DOWN",
		normalDuration = 5,
		normalSound    = "CDM: Ready Click",
		pTime          = 0,    -- post-combat linger seconds; 0 = off (icons clear on their own hold)
		maxIcons       = 10,   -- cap on simultaneously-visible ready icons in this box (1-10)

		-- "Important" spells (per-spell override) use these instead of the normal hold/sound.
		highlightDuration = 10,
		highlightSound    = "None",
		highlight = { style = "BORDER", color = { r = 1, g = 0.82, b = 0, a = 0.8 } },

		iconSize       = 40,
		iconAlpha      = 1.0,
		iconOffset     = 0,
		xPadding       = 0,
		yPadding       = 4,
		iconBorder      = true,
		iconBorderSize  = 1,
		iconBorderColor = { r = 0, g = 0, b = 0, a = 1 },

		bgTexture      = "CDM Smooth",
		bgColor        = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 },
		borderTexture  = "CDM Shadow",
		borderEnabled  = true,
		borderColor    = { r = 0, g = 0, b = 0, a = 0.59 },
		borderSize     = 1,
		borderPadding  = 1,

		iconText       = {
			{ enabled = true,  text = "[cd.stacks]" },
			{ enabled = true,  text = "[cd.time]"   },
			{ enabled = false, text = ""            },
		},


		labelFont      = "Friz Quadrata TT",
		labelSize      = 10,
		labelFlags     = "OUTLINE",
		labelColor     = { r = 1, g = 1, b = 1, a = 1 },
	}
end

local function barFrame(frameName, x, y, enabled)
	return {
		enabled        = enabled,
		frameName      = frameName,
		anchor         = "CENTER",
		x              = x,
		y              = y,
		alpha          = 1.0,
		growDirection  = "UP",
		sortDir        = "DESCENDING",
		padding        = 2,
		spacing        = 2,
		maxBars        = 10,

		barWidth       = 200,
		barHeight      = 20,
		fgTexture      = "CDM Smooth",
		fgColor        = { r = 0.20, g = 0.55, b = 0.95, a = 1 },
		fgClassColor   = false,
		barBgTexture   = "CDM Smooth",
		barBgColor     = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 },

		showIcon       = true,
		iconPosition   = "LEFT",
		showName       = true,
		showTime       = true,

		barFont        = "Friz Quadrata TT",
		barFontSize    = 10,
		barFontFlags   = "OUTLINE",
		barFontColor   = { r = 1, g = 1, b = 1, a = 1 },


		barTimeFont    = "Friz Quadrata TT",
		barTimeSize    = 12,
		barTimeFlags   = "OUTLINE",
		barTimeColor   = { r = 1, g = 1, b = 1, a = 1 },

		labelFont      = "Friz Quadrata TT",
		labelSize      = 10,
		labelFlags     = "OUTLINE",
		labelColor     = { r = 1, g = 1, b = 1, a = 1 },


		highlight      = { style = "BORDER", color = { r = 1, g = 0.82, b = 0, a = 0.8 } },

		bgColor        = { r = 0.1, g = 0.1, b = 0.1, a = 0.4 },
		borderEnabled  = true,
		borderColor    = { r = 0, g = 0, b = 0, a = 0.48 },
		borderSize     = 1,
		borderPadding  = 1,
	}
end

ns.DEFAULTS = {
	global = {
		firstRun         = true,
		enabledAlways    = true,
		enabledGroup     = false,
		enabledInstance  = false,
		unlockFrames     = true,
		autohide         = false,
		enableTooltip    = false,
		detectSharedCD   = false,
		zoom             = 1,   -- icon zoom multiplier; 1 = default border-trim look, >1 crops in
		notUsableTint    = false,
		notUsableDesaturate = false,
		notUsableColor   = { r = 0.75, g = 0.1, b = 0.1, a = 1 },

		testType         = "mixed",
		testCount        = 6,
		testFirst        = 5,
		testLast         = 120,
		testLoop         = true,
	},

	classColors = {},  -- populated from CONST.CLASS_COLORS at first run

	lanes = {
		[1] = lane("Lane 1", -175, true),
		[2] = lane("Lane 2", -210, false),
		[3] = lane("Lane 3", -245, false),
	},

	readyFrames = {
		[1] = readyFrame("Ready 1", -200, 30, true),
		[2] = readyFrame("Ready 2",  184,  25, false),
		[3] = readyFrame("Ready 3",    0,  120, false),
	},

	barFrames = {
		[1] = barFrame("Bars 1", -395,  79, true),
		[2] = barFrame("Bars 2",  300,  60, false),
		[3] = barFrame("Bars 3",    0, -300, false),
	},

	-- readyBox routes the category's ready-popup to a box (1/2/3); 0 = off. Defaults to box 1 so every category pops there until the user spreads them across boxes 2/3.
	filters = {
		spells     = { enabled = true,  showByDefault = true,  ignoreThreshold = 1800, defaultLane = 1, readyBox = 1, defaultBar = 1 },
		items      = { enabled = true,  showByDefault = true,  ignoreThreshold = 1800, defaultLane = 1, readyBox = 1, defaultBar = 1 },
		buffs      = { enabled = true,  showByDefault = true,  ignoreThreshold = 1800, defaultLane = 1, readyBox = 1, defaultBar = 1 },
		debuffs    = { enabled = true,  showByDefault = true,  ignoreThreshold = 1800, defaultLane = 1, readyBox = 1, defaultBar = 1 },
		potions    = { enabled = true,  showByDefault = true,  ignoreThreshold = 1800, defaultLane = 1, readyBox = 1, defaultBar = 1 },
		trinkets   = { enabled = true,  showByDefault = true,  ignoreThreshold = 1800, defaultLane = 1, readyBox = 1, defaultBar = 1 },
		offensives = { enabled = false, showByDefault = false, ignoreThreshold = 1800, defaultLane = 1, readyBox = 1, defaultBar = 1 },
		petspells  = { enabled = true,  showByDefault = true,  ignoreThreshold = 1800, defaultLane = 1, readyBox = 1, defaultBar = 1 },
		custom     = { enabled = true,  showByDefault = true,  ignoreThreshold = 1800, defaultLane = 1, readyBox = 1, defaultBar = 1 },
	},

	-- spellOverrides[spellID] = { visible, lane, bar, readyBox, important, pinned }. A nil field falls back to the category default.
	spellOverrides = {},

	-- customCooldowns.defs[id] = { id, name, icon, triggerType = "spell"|"aura", triggerID, durationMs, enabled }. id comes from CONST.CUSTOM_ID_BASE and doubles as the spellOverrides key.
	customCooldowns = { nextId = 1, defs = {} },

	dataBroker = {
		minimap = { hide = false },
	},
}
