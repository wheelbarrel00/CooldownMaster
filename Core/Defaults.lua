--[[
	Cooldown Master - Defaults.lua
	Default saved-variables structure (account-wide, single profile).
	Mirrors the option panel layout so each tab maps to a sub-table.
--]]

local ADDON_NAME, ns = ...

local function lane(frameName)
	return {
		enabled        = true,
		frameName      = frameName,
		reversed       = false,
		vertical       = false,
		mode           = "LINEAR",      -- LINEAR | LOG (Linear (%))
		maxTime        = 120,
		hideLongTimers = true,
		overrideAutohide = false,
		primaryTracking   = "NONE",     -- NONE | GCD | SWING (where allowed)
		primaryReverse    = false,
		secondaryTracking = "GCD",
		secondaryReverse  = false,
		stWidth        = 5,
		stHeight       = 44,
		stTexture      = "CDM Smooth",
		stColor        = { r = 1, g = 1, b = 1, a = 1 },

		-- Appearance
		width          = 400,
		height         = 44,
		x              = 0,
		y              = -250,
		anchor         = "CENTER",
		fgTexture      = "CDM Smooth",
		fgColor        = { r = 0.92, g = 0.72, b = 0.02, a = 1 },
		fgClassColor   = false,
		bgTexture      = "CDM Smooth",
		bgColor        = { r = 0.1,  g = 0.1,  b = 0.1,  a = 0.85 },
		bgClassColor   = false,
		alpha          = 1.0,
		borderTexture  = "CDM Shadow",
		borderEnabled  = true,
		borderColor    = { r = 0,   g = 0,   b = 0,   a = 1 },
		borderPadding  = 5,
		borderSize     = 5,

		-- Icons
		iconSize       = 40,
		iconAlpha      = 1.0,
		iconOffset     = 0,
		iconText       = {
			{ enabled = true,  text = "[cd.stacks]" },
			{ enabled = true,  text = "[cd.time]"   },
			{ enabled = false, text = ""            },
		},

		laneText = {
			{ enabled = true, text = "Ready", pos = 0    },
			{ enabled = true, text = "25%",   pos = 0.25 },
			{ enabled = true, text = "50%",   pos = 0.50 },
			{ enabled = true, text = "75%",   pos = 0.75 },
			{ enabled = true, text = "100%",  pos = 1    },
		},

		-- Stacking
		stackEnabled       = false,
		stackRaiseHover    = false,
		stackStyle         = "GROUPED",   -- GROUPED | SPREAD
		stackGrowDirection = "UP",
		stackHeight        = 80,
	}
end

ns.DEFAULTS = {
	-- Top-level toggles (Global tab)
	global = {
		firstRun         = true,
		previousVersion  = "0.0.0",
		enabledAlways    = true,
		enabledGroup     = false,
		enabledInstance  = false,
		unlockFrames     = true,
		autohide         = false,
		enableTooltip    = false,
		detectSharedCD   = false,
		zoom             = 1,
		notUsableTint    = false,
		notUsableDesaturate = false,
		notUsableColor   = { r = 0.75, g = 0.1, b = 0.1, a = 1 },
		hideIgnored      = true,
	},

	-- Class color overrides (Colors tab)
	classColors = {},  -- populated from CONST.CLASS_COLORS at first run

	-- Lanes (3 lanes, configurable independently)
	lanes = {
		[1] = lane("Lane 1"),
		[2] = lane("Lane 2"),
		[3] = lane("Lane 3"),
	},

	-- Filters (Defaults / Spells / Items / Buffs / Debuffs / Offensives / Petspells / Custom)
	filters = {
		spells     = { enabled = true,  showByDefault = true,  ignoreThreshold = 1800, defaultLane = 1 },
		items      = { enabled = true,  showByDefault = true,  ignoreThreshold = 1800, defaultLane = 1 },
		buffs      = { enabled = true,  showByDefault = true,  ignoreThreshold = 1800, defaultLane = 1 },
		debuffs    = { enabled = true,  showByDefault = true,  ignoreThreshold = 1800, defaultLane = 1 },
		offensives = { enabled = false, showByDefault = false, ignoreThreshold = 1800, defaultLane = 1 },
		petspells  = { enabled = true,  showByDefault = true,  ignoreThreshold = 1800, defaultLane = 1 },
		custom     = { enabled = false, showByDefault = false, ignoreThreshold = 1800, defaultLane = 1 },
	},

	-- Per-spell overrides keyed by spellID. Filled in as the user adjusts
	-- entries via the Filters tab. Shape:
	--   spellOverrides[spellID] = {
	--       visible = true|false,    -- per-spell on/off (nil = use category default)
	--       lane    = 1|2|3|nil,     -- per-spell lane override (nil = use category default)
	--   }
	spellOverrides = {},

	-- LibDataBroker / minimap button state
	dataBroker = {
		minimap = { hide = false },
	},
}
