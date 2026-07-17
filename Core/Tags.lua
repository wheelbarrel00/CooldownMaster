local ADDON_NAME, ns = ...

local issecret = _G.issecretvalue
local floor = math.floor

-- A hostile target's fields read secret in combat, and tostring returns a secret string rather than
-- throwing, so unit reads route through here and blank out before the secrecy can spread.
local function plainStr(v)
	if v == nil then return "" end
	if issecret and issecret(v) then return "" end
	return tostring(v)
end

local function unitText(getter, unit)
	if not UnitExists(unit) then return "" end
	local ok, v = pcall(getter, unit)
	if not ok then return "" end
	return plainStr(v)
end

local function pct(cur, max)
	if not (cur and max) or max == 0 then return 0 end
	return floor(cur / max * 100 + 0.5)
end

local CATEGORY_LABEL = {
	[0]   = "Spell",   [1]   = "Utility", [2]   = "Buff",     [3]   = "Buff Bar",
	[100] = "Potion",  [101] = "Trinket", [102] = "Custom",   [103] = "Pet",      [104] = "Offensive",
}

local function nextName()
	local eng = ns.Engine
	if not (eng and eng.entries) then return "" end
	local bestEnd, bestName
	for _, e in pairs(eng.entries) do
		local et = e.endTime
		if et and (not bestEnd or et < bestEnd) then bestEnd, bestName = et, e.name end
	end
	return bestName or ""
end

local function activeCount()
	local eng = ns.Engine
	if not (eng and eng.entries) then return 0 end
	local n = 0
	for _ in pairs(eng.entries) do n = n + 1 end
	return n
end

local function fmtTime(sec)
	if sec >= 60 then return string.format("%d:%02d", floor(sec / 60), sec % 60) end
	return tostring(floor(sec))
end

local CLASSIC = not (ns.Compat and ns.Compat.HAS_BLIZZ_CDM)

local TAGS = {
	["cd.name"]         = function(e) return e and e.name or "" end,
	["cd.type"]         = function(e) return e and CATEGORY_LABEL[e.category] or "" end,
	["player.name"]     = function() return unitText(UnitName, "player") end,
	["player.class"]    = function() return unitText(UnitClass, "player") end,
	["target.name"]     = function() return unitText(UnitName, "target") end,
	["target.class"]    = function() return unitText(UnitClass, "target") end,
	["cd.next"]         = function() return nextName() end,
	["cd.count"]        = function() return tostring(activeCount()) end,
}

-- Classic-only. Retail returns UnitHealth/UnitPower SECRET even out of combat (only the Max stays
-- plain), so no addon can read the value to draw it as text. [cd.time] is secret there the same way.
if CLASSIC then
	TAGS["player.hp"]        = function() return tostring(UnitHealth("player") or 0) end
	TAGS["player.hp.pct"]    = function() return tostring(pct(UnitHealth("player"), UnitHealthMax("player"))) end
	TAGS["player.power"]     = function() return tostring(UnitPower("player") or 0) end
	TAGS["player.power.pct"] = function() return tostring(pct(UnitPower("player"), UnitPowerMax("player"))) end
	TAGS["cd.time"] = function(e)
		if not (e and e.endTime) then return "" end
		local rem = e.endTime - GetTime()
		if rem < 0 then rem = 0 end
		return fmtTime(rem)
	end
end

-- The entry rides a file upvalue so the gsub replacer is allocated once, not per call at render cadence.
local curEntry
local function subTag(tag)
	local fn = TAGS[tag]
	if not fn then return "" end
	local ok, v = pcall(fn, curEntry)
	if not ok or v == nil then return "" end
	-- tostring propagates secrecy instead of throwing, and gsub throws on a secret replacement.
	if issecret and issecret(v) then return "" end
	return v
end

function ns.RenderTag(template, e)
	if not template or template == "" then return "" end
	if not template:find("%[") then return template end
	curEntry = e
	local out = (template:gsub("%[([%w%.]+)%]", subTag))
	curEntry = nil
	return out
end

-- A template built only from these entry-fixed tags resolves once per entry. Anything else re-resolves live.
local STATIC_TAGS = {
	["cd.name"] = true, ["cd.type"] = true,
	["player.name"] = true, ["player.class"] = true,
}

function ns.TemplateHasLiveTag(template)
	if not template or not template:find("%[") then return false end
	for tag in template:gmatch("%[([%w%.]+)%]") do
		if TAGS[tag] and not STATIC_TAGS[tag] then return true end
	end
	return false
end

do
	local lines = {
		"Type text and these tags fill in live.",
		"Per cooldown (icon labels only):",
		"[cd.name] - spell or item name",
		"[cd.type] - category (Spell, Buff, Potion...)",
	}
	if CLASSIC then lines[#lines + 1] = "[cd.time] - remaining time" end
	lines[#lines + 1] = "Global (status line, or icons):"
	lines[#lines + 1] = "[cd.next] - name of the next cooldown up"
	lines[#lines + 1] = "[cd.count] - how many are on cooldown"
	if CLASSIC then lines[#lines + 1] = "[player.hp.pct] / [player.power.pct]" end
	lines[#lines + 1] = "[player.class] / [player.name]"
	lines[#lines + 1] = "[target.name] / [target.class] - blank if hidden"
	ns.TAG_HELP = table.concat(lines, "\n")
end

-- Split by context: per-cooldown tags need an entry, so they fill in only on an icon label, not the frame status line.
ns.TAG_PICKER_COOLDOWN = {
	{ "Name", "[cd.name]" },
	{ "Type", "[cd.type]" },
}

-- A ready icon is already up, so no [cd.time] - keep it a separate literal or the Classic append leaks in.
ns.TAG_PICKER_READY = {
	{ "Name", "[cd.name]" },
	{ "Type", "[cd.type]" },
}

if CLASSIC then
	ns.TAG_PICKER_COOLDOWN[#ns.TAG_PICKER_COOLDOWN + 1] = { "Time Left", "[cd.time]" }
end

ns.TAG_PICKER_GLOBAL = {
	{ "Next CD",      "[cd.next]" },
	{ "CD Count",     "[cd.count]" },
	{ "My Class",     "[player.class]" },
	{ "My Name",      "[player.name]" },
	{ "Target",       "[target.name]" },
	{ "Target Class", "[target.class]" },
}

if CLASSIC then
	ns.TAG_PICKER_GLOBAL[#ns.TAG_PICKER_GLOBAL + 1] = { "My HP %",    "[player.hp.pct]" }
	ns.TAG_PICKER_GLOBAL[#ns.TAG_PICKER_GLOBAL + 1] = { "My Power %", "[player.power.pct]" }
end

function ns.RunTagProbe()
	local out = _G.CooldownMaster
	if not out then return end
	local function say(s) out:Print(s) end

	local function describe(v)
		if v == nil then return "nil" end
		if issecret and issecret(v) then return "SECRET" end
		local ok, s = pcall(tostring, v)
		if not ok then return "tostring THREW" end
		return type(v) .. " = " .. s
	end

	say("--- tag probe ---")
	say("issecretvalue exists: " .. tostring(issecret ~= nil) .. " | combat: " .. tostring(InCombatLockdown()))

	local apis = {
		{ "UnitHealth",    function() return UnitHealth("player") end },
		{ "UnitHealthMax", function() return UnitHealthMax("player") end },
		{ "UnitPower",     function() return UnitPower("player") end },
		{ "UnitPowerMax",  function() return UnitPowerMax("player") end },
	}
	for _, a in ipairs(apis) do
		local ok, v = pcall(a[2])
		say(a[1] .. ": " .. (ok and describe(v) or ("THREW " .. describe(v))))
	end

	for _, tag in ipairs({ "player.hp", "player.hp.pct", "player.power", "player.power.pct", "player.class", "cd.count" }) do
		local fn = TAGS[tag]
		if not fn then
			say("[" .. tag .. "]: NOT REGISTERED")
		else
			local ok, v = pcall(fn, nil)
			local rok, r = pcall(ns.RenderTag, "[" .. tag .. "]", nil)
			say("[" .. tag .. "]: fn " .. (ok and ("ok -> " .. describe(v)) or ("THREW " .. describe(v)))
				.. " | render " .. (rok and ("'" .. tostring(r) .. "'") or "THREW"))
		end
	end
end
