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


function ns.Masque_IsSkinned(owner)
	return (owner and owner._msqSkinned) == true
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
