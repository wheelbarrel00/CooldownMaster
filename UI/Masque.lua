local ADDON_NAME, ns = ...

local MSQ = LibStub and LibStub("Masque", true)

local GROUP_NAME = {
	lane  = "Lane Icons",
	ready = "Ready Icons",
	bar   = "Bar Icons",
}

local groups = {}

local function GetGroup(surface)
	local g = groups[surface]
	if g == nil then
		g = MSQ:Group("CooldownMaster", GROUP_NAME[surface] or surface) or false
		groups[surface] = g
	end
	return g or nil
end


-- Disabling a group in Masque re-skins its buttons with the DEFAULT skin rather than releasing
-- them (Group.lua __Disable), which resets the icon TexCoord and leaves our border zeroed. Nothing
-- re-asserts either, so a disabled group has to read as unskinned or Icon Zoom and the icon border
-- options stay dead for the rest of the session. Disabling the parent cascades this flag to us.
function ns.Masque_IsSkinned(owner)
	if not (owner and owner._msqSkinned) then return false end
	local group = owner._msqGroup
	if group and group.db and group.db.Disabled then return false end
	return true
end


-- A bar keeps its icon on a child iconFrame, so `owner` (which carries tex/border) is not always `frame`.
function ns.Masque_Add(surface, frame, owner)
	if not MSQ then return end
	owner = owner or frame
	if not (frame and owner) or owner._msqSkinned then return end
	local group = GetGroup(surface)
	if not group then return end
	-- No Cooldown region on purpose - a skin re-anchors it, undoing the pixel-snap carrier that keeps the countdown crisp.
	group:AddButton(frame, { Icon = owner.tex, Normal = owner.border }, "Legacy")
	owner._msqSkinned = true
	owner._msqFrame = frame
	owner._msqGroup = group
end


-- A skin caches its scale off the frame size at skin time, so a resized icon needs this or it keeps the stale scale.
function ns.Masque_ReSkin(owner)
	if not (owner and owner._msqSkinned and owner._msqGroup) then return end
	owner._msqGroup:ReSkin(owner._msqFrame)
end


-- Register every group up front so CooldownMaster is listed in Masque even before any icon has been drawn.
-- Masque adds a group's options node the moment the group exists (zero buttons is fine), and creating a
-- group before PLAYER_LOGIN is supported - it self-queues and reskins on its own OnEnable.
local function EnsureGroups()
	if not MSQ then return end
	GetGroup("lane")
	GetGroup("ready")
	GetGroup("bar")
end

pcall(EnsureGroups)


function ns.Masque_Report()
	local out = { hasLib = LibStub ~= nil, hasMasque = MSQ ~= nil, groups = {} }
	if MSQ then
		for surface, name in pairs(GROUP_NAME) do
			local g = groups[surface]
			local count = 0
			if g and g.Buttons then
				for _ in pairs(g.Buttons) do count = count + 1 end
			end
			-- A failed Group() call caches as false, so a nil test would report it as registered -
			-- degrading the one diagnostic that exists for a group failing to register.
			out.groups[surface] = {
				name     = name,
				created  = (g and true) or false,
				disabled = (g and g.db and g.db.Disabled) and true or false,
				buttons  = count,
			}
		end
	end
	return out
end
