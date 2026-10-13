local _, ns = ...
local L = ns.L

local Settings = ns.Settings
local ui = Settings.ui

local CLASSES_RETAIL = {
	"DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER",
	"MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE",
	"SHAMAN", "WARLOCK", "WARRIOR",
}

local CLASSES_CLASSIC = {
	"DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST",
	"ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

local CLASSES_MOP = {
	"DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "MONK", "PALADIN",
	"PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

local ENGLISH = {
	DEATHKNIGHT = "Death Knight", DEMONHUNTER = "Demon Hunter", DRUID = "Druid", EVOKER = "Evoker",
	HUNTER = "Hunter", MAGE = "Mage", MONK = "Monk", PALADIN = "Paladin", PRIEST = "Priest",
	ROGUE = "Rogue", SHAMAN = "Shaman", WARLOCK = "Warlock", WARRIOR = "Warrior",
}

local WHITE = { r = 1, g = 1, b = 1, a = 1 }

-- Blizzard localizes this in every client language, so it wins over our English names and the L[] store.
local function className(token)
	local g = LOCALIZED_CLASS_NAMES_MALE
	return (g and g[token]) or ENGLISH[token] or token
end

-- Only the logged-in character's class is ever drawn, so it leads the list
local function classes(mine)
	local c = ns.Compat
	local list = c.IS_MOP and CLASSES_MOP or ((c.IS_RETAIL and not c.IS_FOREVER) and CLASSES_RETAIL or CLASSES_CLASSIC)
	local out = {}
	for _, token in ipairs(list) do
		if token == mine then table.insert(out, 1, token) else out[#out + 1] = token end
	end
	return out
end

-- Never written through: the setter makes the profile its own table, so the shared default is never edited
local function getter(token)
	return function()
		return ns.CDM.db.profile.classColors[token] or ns.CONST.CLASS_COLORS[token] or WHITE
	end
end

local function setter(token)
	return function(v)
		local colors = ns.CDM.db.profile.classColors
		local c = colors[token]
		if not c then
			c = {}
			colors[token] = c
		end
		c.r, c.g, c.b, c.a = v.r, v.g, v.b, v.a or 1
		-- Lanes draw only the player's class, and read it only when their config is applied
		local _, mine = UnitClass("player")
		if token ~= mine then return end
		for i = 1, 3 do
			if ns.Lanes_ApplyConfig then ns.Lanes_ApplyConfig(i) end
			if ns.Lanes_Refresh then ns.Lanes_Refresh(i) end
		end
	end
end

ui:RegisterTab({
	id     = "colors",
	title  = L["Colors"],
	order  = 60,
	icon   = ui:Texture("icon-appearance"),
	footer = Settings.Footer,
	build  = function(self, content)
		local push = Settings.CardStack()
		local card = push(self:CreateGroup(content, L["Class Colors"]))
		self:AttachTooltip(card.label, L["Class Colors"],
			L["Use Class Color on a lane or a bar frame fills it with your class's color from this list. Only your character's class is drawn. The others apply when an alt shares this profile."])
		local _, mine = UnitClass("player")
		for _, token in ipairs(classes(mine)) do
			local picker = self:CreateColorPicker(content, className(token), getter(token), setter(token), nil, true)
			if token == mine then picker.label:SetTextColor(ui:Color("text")) end
			card:Add(picker)
		end
	end,
})
