local ADDON_NAME, ns = ...
local L = ns.L

ns.CONST = {
	ADDON_NAME       = "CooldownMaster",
	ADDON_DISPLAY    = "Cooldown Master",
	ADDON_SHORT      = "CDM",
	VERSION          = "1.14.0",

	SLASH_COMMANDS   = { "cdmaster", "cooldownmaster", "cm" },

	-- Must match ## SavedVariables in the .toc.
	SV_KEY           = "CooldownMasterDB",

	HEX = {
		RED          = "6D0501",
		YELLOW       = "EBB706",
		WHITE        = "FFFFFF",
		GREY         = "888888",
	},

	RGB = {
		RED          = { r = 0.4275, g = 0.0196, b = 0.0039, a = 1 },
		RED_DIM      = { r = 0.2500, g = 0.0150, b = 0.0030, a = 1 },
		RED_HOVER    = { r = 0.5500, g = 0.0500, b = 0.0200, a = 1 },
		YELLOW       = { r = 0.9216, g = 0.7176, b = 0.0235, a = 1 },
		PANEL_BG     = { r = 0.0500, g = 0.0500, b = 0.0500, a = 0.95 },
		PANEL_BORDER = { r = 0.4275, g = 0.0196, b = 0.0039, a = 1 },
		BODY_TEXT    = { r = 1.0000, g = 1.0000, b = 1.0000, a = 1 },
	},

	CLASS_COLORS = {
		DEATHKNIGHT  = { r = 0.77, g = 0.12, b = 0.23 },
		DEMONHUNTER  = { r = 0.64, g = 0.19, b = 0.79 },
		DRUID        = { r = 1.00, g = 0.49, b = 0.04 },
		EVOKER       = { r = 0.20, g = 0.58, b = 0.50 },
		HUNTER       = { r = 0.67, g = 0.83, b = 0.45 },
		MAGE         = { r = 0.25, g = 0.78, b = 0.92 },
		MONK         = { r = 0.00, g = 1.00, b = 0.60 },
		PALADIN      = { r = 0.96, g = 0.55, b = 0.73 },
		PRIEST       = { r = 1.00, g = 1.00, b = 1.00 },
		ROGUE        = { r = 1.00, g = 0.96, b = 0.41 },
		SHAMAN       = { r = 0.00, g = 0.44, b = 0.87 },
		WARLOCK      = { r = 0.53, g = 0.53, b = 0.93 },
		WARRIOR      = { r = 0.78, g = 0.61, b = 0.43 },
	},

	-- Keys 0-3 are Blizzard's Enum.CooldownViewerCategory (3 is TrackedBar, not debuffs). 100+ are our own synthetic ids.
	CATEGORY_TO_FILTER_KEY = {
		[0]   = "spells",
		[1]   = "items",
		[2]   = "buffs",
		[3]   = "debuffs",
		[100] = "potions",
		[101] = "trinkets",
		[102] = "custom",
		[103] = "petspells",
		[104] = "offensives",
	},

	POTION_CATEGORY    = 100,
	TRINKET_CATEGORY   = 101,
	CUSTOM_CATEGORY    = 102,
	PET_CATEGORY       = 103,
	OFFENSIVE_CATEGORY = 104,

	-- Custom cooldowns have no real spellID, so ids come from this reserved range - past real spell/item ids, under 2^31.
	CUSTOM_ID_BASE   = 90000000,

	-- Entries are keyed by spellID, so test entries need their own id range or duplicates would collapse into one.
	TEST_ID_BASE     = 95000000,

	-- A cooldown spell that also grants a buff is tracked twice - the cooldown keeps its real id, its buff rides this offset so both coexist as separate entries. buffKey = BUFF_ID_BASE + spellID.
	BUFF_ID_BASE     = 200000000,

	-- Item entries are keyed by itemID, which overlaps the real spellID range (5512 is both a spellID and an itemID), so a learned item duration rides this offset to stay clear of the spell keyspace.
	ITEM_ID_BASE     = 300000000,

	-- Offensives and Custom are omitted - no donor pool to demo from, and a fake Custom would look like a live timer.
	TEST_TYPES = {
		{ value = "mixed",     text = L["Mixed"],      category = nil },
		{ value = "spells",    text = L["Spells"],     category = 0   },
		{ value = "items",     text = L["Utility"],    category = 1   },
		{ value = "buffs",     text = L["Buffs"],      category = 2   },
		{ value = "debuffs",   text = L["Buff Bars"],  category = 3   },
		{ value = "potions",   text = L["Potions"],    category = 100 },
		{ value = "trinkets",  text = L["Trinkets"],   category = 101 },
		{ value = "petspells", text = L["Pet Spells"], category = 103 },
	},

	-- Classic discovery has no Blizzard category tagging, so these would land in Spells instead of Utility.
	CLASSIC_UTILITY_SPELLS = {
		[50977] = true,  -- Death Gate
	},

	FILTER_CATEGORIES = {
		{ key = "spells",     label = L["Spells"]     },
		-- Key stays "items" for saved-variable back-compat. The label is Blizzard's Utility-tagged spells, not inventory items.
		{ key = "items",      label = L["Utility"]    },
		{ key = "buffs",      label = L["Buffs"]      },
		-- Key stays "debuffs" for saved-variable back-compat. Category 3 is Blizzard's TrackedBar (bar-style tracked buffs), not debuffs - your DoTs on a target are the Offensives category.
		{ key = "debuffs",    label = L["Buff Bars"]  },
		{ key = "potions",    label = L["Potions"]    },
		{ key = "trinkets",   label = L["Trinkets"]   },
		{ key = "offensives", label = L["Offensives"] },
		{ key = "petspells",  label = L["Pet Spells"] },
		{ key = "custom",     label = L["Custom"]     },
	},
}

-- Resolved by name at call time, so the UI files may load after this one.
ns.SURFACES = { "Lanes", "ReadyFrames", "Bars" }

function ns.ForEachSurface(suffix, ...)
	for i = 1, #ns.SURFACES do
		local fn = ns[ns.SURFACES[i] .. "_" .. suffix]
		if fn then fn(...) end
	end
end


function ns.Colorize(hex, text)
	return string.format("|cff%s%s|r", hex, tostring(text))
end

function ns.ChatPrefix()
	return string.format("|cff%s[%s]|r ",
		ns.CONST.HEX.YELLOW, ns.CONST.ADDON_DISPLAY)
end
