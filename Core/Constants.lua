local ADDON_NAME, ns = ...

ns.CONST = {
	ADDON_NAME       = "CooldownMaster",
	ADDON_DISPLAY    = "Cooldown Master",
	ADDON_SHORT      = "CDM",
	VERSION          = "0.16.8",

	SLASH_COMMANDS   = { "cdmaster", "cooldownmaster" },

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

	-- Keys are Blizzard's Enum.CooldownViewerCategory (0=Essential, 1=Utility, 2=TrackedBuff, 3=TrackedDebuff);
	-- 100+ are our own synthetic item categories (100 = bag potions/flasks via C_Container.GetItemCooldown;
	-- 101 = equipped on-use trinkets via GetInventoryItemCooldown).
	CATEGORY_TO_FILTER_KEY = {
		[0]   = "spells",
		[1]   = "items",
		[2]   = "buffs",
		[3]   = "debuffs",
		[100] = "potions",
		[101] = "trinkets",
	},

	POTION_CATEGORY  = 100,
	TRINKET_CATEGORY = 101,

	-- Order matters: drives the Filters sub-tab strip order.
	FILTER_CATEGORIES = {
		{ key = "spells",     label = "Spells",     active = true  },
		-- key stays "items" for saved-variable back-compat; label "Utility" is Blizzard's Utility-tagged spells, not inventory items.
		{ key = "items",      label = "Utility",    active = true  },
		{ key = "buffs",      label = "Buffs",      active = true  },
		{ key = "debuffs",    label = "Debuffs",    active = true  },
		{ key = "potions",    label = "Potions",    active = true  },
		{ key = "trinkets",   label = "Trinkets",   active = true  },
		{ key = "offensives", label = "Offensives", active = false },
		{ key = "petspells",  label = "Pet Spells", active = false },
		{ key = "custom",     label = "Custom",     active = false },
	},
}

function ns.Colorize(hex, text)
	return string.format("|cff%s%s|r", hex, tostring(text))
end

function ns.ChatPrefix()
	return string.format("|cff%s[%s]|r ",
		ns.CONST.HEX.YELLOW, ns.CONST.ADDON_DISPLAY)
end
