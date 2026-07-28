local ADDON_NAME, ns = ...

local ICON_SIZE = 40
local BOX_FADE_DUR = 0.3   -- seconds for the backdrop to fade out once the box goes empty
local ICON_FADE_IN = 0.25  -- icon alpha fade-in on pop, so it surfaces softly instead of snapping in
local TAG_REFRESH = 0.1    -- live-tag re-resolve cadence - the render OnUpdate is far too fast to gsub on

-- Built-in ready sounds (SOUNDKIT + one bundled click), listed before LibSharedMedia sounds.
local READY_BUILTIN_SOUNDS = {
	{ name = "CDM: Ready Check",  kit = "READY_CHECK"            },
	{ name = "CDM: Quest Ding",   kit = "IG_QUEST_LIST_COMPLETE" },
	{ name = "CDM: Raid Warning", kit = "RAID_WARNING"           },
}
ns.READY_BUILTIN_SOUNDS = READY_BUILTIN_SOUNDS

do
	local ok, LSM = pcall(LibStub, "LibSharedMedia-3.0")
	if ok and LSM then
		LSM:Register("sound", "CDM: Ready Click", [[Interface\AddOns\CooldownMaster\media\ready-click.ogg]])
	end
end

local function PlayReadySound(name)
	if not name or name == "None" then return end
	for _, s in ipairs(READY_BUILTIN_SOUNDS) do
		if s.name == name then
			local kit = _G.SOUNDKIT and _G.SOUNDKIT[s.kit]
			if kit then pcall(PlaySound, kit, "SFX") end
			return
		end
	end
	local ok, LSM = pcall(LibStub, "LibSharedMedia-3.0")
	if ok and LSM then
		local path = LSM:Fetch("sound", name)
		if path then pcall(PlaySoundFile, path, "SFX") end
	end
end
ns.ReadyFrames_PreviewSound = PlayReadySound

local function AcquireReadyIcon(f, index)
	local pool = f.iconPool
	local btn  = pool[index]
	if btn then return btn end

	btn = CreateFrame("Frame", "CooldownMaster_Ready_"..f.index.."_Btn_"..index, f)
	btn:SetSize(ICON_SIZE, ICON_SIZE)

	-- Per-box icon border (off by default): a solid backing that extends a few px beyond the
	-- icon so a clean ring shows around it; sized/colored/toggled per box via ns.ApplyIconBorder.
	btn.border = btn:CreateTexture(nil, "BACKGROUND")
	btn.border:Hide()

	btn.tex = btn:CreateTexture(nil, "ARTWORK")
	btn.tex:SetAllPoints(btn)
	btn.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- One-shot pop-in pulse: a visual Scale transform (origin CENTER) so the icon
	-- bounces in place without disturbing its layout anchor. Guarded + API-detected
	-- because the Classic flavors ship an older Scale-animation API.
	local okPulse, pulse = pcall(function()
		local ag = btn:CreateAnimationGroup()
		local up = ag:CreateAnimation("Scale")
		up:SetOrder(1)
		up:SetDuration(0.12)
		up:SetOrigin("CENTER", 0, 0)
		local down = ag:CreateAnimation("Scale")
		down:SetOrder(2)
		down:SetDuration(0.18)
		down:SetOrigin("CENTER", 0, 0)
		if up.SetScaleFrom then
			up:SetScaleFrom(0.5, 0.5);   up:SetScaleTo(1.3, 1.3)
			down:SetScaleFrom(1.3, 1.3); down:SetScaleTo(1.0, 1.0)
		elseif up.SetFromScale then
			up:SetFromScale(0.5, 0.5);   up:SetToScale(1.3, 1.3)
			down:SetFromScale(1.3, 1.3); down:SetToScale(1.0, 1.0)
		end
		return ag
	end)
	if okPulse then btn.pulse = pulse end

	-- Highlight overlay for "important" spells (Border / Glow / Flash). An additive
	-- glow border anchored a few px outside the icon so it auto-tracks icon size.
	btn.hl = btn:CreateTexture(nil, "OVERLAY")
	btn.hl:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	btn.hl:SetBlendMode("ADD")
	btn.hl:SetPoint("TOPLEFT", btn, "TOPLEFT", -6, 6)
	btn.hl:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 6, -6)
	btn.hl:Hide()

	-- Full-icon glow so the highlight fills the icon, not just its edge (the border texture
	-- alone leaves the center empty). Additive, colored to match; the border carries the flash.
	btn.hlFill = btn:CreateTexture(nil, "OVERLAY")
	btn.hlFill:SetTexture("Interface\\Buttons\\WHITE8x8")
	btn.hlFill:SetBlendMode("ADD")
	btn.hlFill:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
	btn.hlFill:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
	btn.hlFill:Hide()

	local okFlash, flash = pcall(function()
		local ag = btn.hl:CreateAnimationGroup()
		ag:SetLooping("BOUNCE")
		local a = ag:CreateAnimation("Alpha")
		a:SetDuration(0.5)
		if a.SetFromAlpha then a:SetFromAlpha(1.0); a:SetToAlpha(0.2)
		elseif a.SetChange then a:SetChange(-0.8) end
		return ag
	end)
	if okFlash then btn.hlFlash = flash end

	btn.tagText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	btn.tagText:Hide()

	ns.Masque_Add("ready", btn)

	btn:Hide()
	pool[index] = btn
	return btn
end


local function ClearIconHighlight(btn)
	if btn.hlFlash then btn.hlFlash:Stop() end
	if btn.hl then btn.hl:Hide() end
	if btn.hlFill then btn.hlFill:Hide() end
end


local function ApplyIconHighlight(btn, cfg, important)
	ClearIconHighlight(btn)
	if not important or not btn.hl then return end

	local hl    = cfg.highlight
	local style = (hl and hl.style) or "BORDER"
	if style == "NONE" then return end

	local c = (hl and hl.color) or { r = 1, g = 0.82, b = 0, a = 0.8 }
	btn.hl:SetVertexColor(c.r or 1, c.g or 1, c.b or 1)
	btn.hl:SetAlpha(c.a or 0.6)
	btn.hl:Show()
	if btn.hlFill then
		btn.hlFill:SetVertexColor(c.r or 1, c.g or 1, c.b or 1)
		btn.hlFill:SetAlpha((c.a or 0.6) * 0.5)
		btn.hlFill:Show()
	end
	-- BORDER is static; GLOW / FLASH / BORDER_FLASH pulse (we deliberately avoid the
	-- deprecated Blizzard ActionButton glow API, which is gone on some flavors).
	if style ~= "BORDER" and btn.hlFlash then
		btn.hlFlash:Play()
	end
end

local function ConfigureReadyTagFont(f, cfg)
	local name = "CDMReadyTagFont" .. (f.index or 1)
	local fontObj = _G[name] or CreateFont(name)
	fontObj:SetFont(ns.ResolveFont(cfg.iconLabelFont, cfg.iconLabelSize, cfg.iconLabelFlags))
	local c = cfg.iconLabelColor
	fontObj:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1, c and c.a or 1)
	f._tagFontObj = fontObj
	local lbl = cfg.iconLabel
	f._tagLive = (lbl and lbl.enabled and ns.TemplateHasLiveTag(lbl.text)) or false
end


local function UpdateReadyIconTag(f, btn, cfg)
	local lbl = cfg.iconLabel
	if not (lbl and lbl.enabled) then
		if btn._tagShown ~= false then
			btn._tagShown = false
			btn.tagText:Hide()
		end
		return
	end

	if btn._tagFontObj ~= f._tagFontObj then
		btn._tagFontObj = f._tagFontObj
		if f._tagFontObj then btn.tagText:SetFontObject(f._tagFontObj) end
	end

	local anch = lbl.anchor or "BOTTOM"
	if btn._tagAnchor ~= anch then
		btn._tagAnchor = anch
		btn.tagText:ClearAllPoints()
		if anch == "TOP" then
			btn.tagText:SetPoint("BOTTOM", btn, "TOP", 0, 1)
		elseif anch == "CENTER" then
			btn.tagText:SetPoint("CENTER", btn, "CENTER", 0, 0)
		else
			btn.tagText:SetPoint("TOP", btn, "BOTTOM", 0, -1)
		end
	end

	local str = ns.RenderTag(lbl.text, btn._tagSnap)
	if btn._tagStr ~= str then
		btn._tagStr = str
		btn.tagText:SetText(str)
	end
	if not btn._tagShown then
		btn._tagShown = true
		btn.tagText:Show()
	end
end


-- A ready box normally hides once it goes empty. Keep it up while test mode runs or when global
-- autohide is OFF (autohide-off means always shown, mirroring the lanes). Unlock no longer keeps
-- it up -- an empty box autohides while unlocked too, and its drag handle keeps it movable.
local function ReadyBoxKeepShown(g)
	if not g then return false end
	if ns.Engine and ns.Engine.testActive then return true end
	if not g.autohide then return true end
	return false
end

local function BoxHasContent(f)
	for i = 1, #f.iconPool do
		local b = f.iconPool[i]
		if b and b:IsShown() then return true end
	end
	return false
end

-- Show a box's drag handle only while unlocked, out of combat, AND the box is (or is fading)
-- hidden -- so it never clutters a visible box, the default autohide-off layout, or a fight (the
-- tag is a positioning aid, matching the lane tags which hide in combat when chrome returns).
local function UpdateReadyHandle(f)
	if not f.dragHandle then return end
	local addon = ns.CDM
	local g = addon and addon.db and addon.db.profile.global
	-- A fading-out box is still IsShown, so gate the tag on that or it draws over the fading backdrop.
	local shown = g and g.unlockFrames and not addon.combat
		and not (BoxHasContent(f) or ReadyBoxKeepShown(g))
		and not f:IsShown()
	ns.RefreshDragHandle(f.dragHandle, f.cfg and f.cfg.frameName, shown)
end

-- Shared across all ready boxes so a relayout (per pop / per expiry) allocates no scratch;
-- fully consumed within the call and Lua is single-threaded, so one table is safe.
local relayoutScratch = {}
local function RelayoutReadyFrame(f)
	local cfg      = f.cfg
	local iconSize = cfg.iconSize or ICON_SIZE
	local spacing  = cfg.yPadding or 0     -- stacking-axis gap (the Icons "Spacing" slider)
	local xPad     = cfg.xPadding or 0
	local xOff     = cfg.iconOffset or 0
	local step     = iconSize + spacing
	local grow     = cfg.growDirection or "DOWN"

	-- Border inset is added to the margin so icons aren't clipped by the border.
	local borderOn  = cfg.borderEnabled == true or cfg.borderEnabled == nil
	local borderIns = borderOn and ((cfg.borderSize or 0) + (cfg.borderPadding or 0)) or 0
	local margin    = borderIns + xPad

	local active = relayoutScratch
	wipe(active)
	for i = 1, #f.iconPool do
		local btn = f.iconPool[i]
		if btn and btn:IsShown() then
			active[#active + 1] = btn
		end
	end
	local count = #active

	local horizontal = grow == "LEFT" or grow == "RIGHT" or grow == "CENTER_H"
	-- Block length along the stacking axis (at least one icon so an empty box is square).
	local blockLen = (math.max(1, count) - 1) * step + iconSize
	local half = (blockLen - iconSize) / 2

	for k, btn in ipairs(active) do
		btn:SetSize(iconSize, iconSize)
		if btn._msqSize ~= iconSize then
			btn._msqSize = iconSize
			ns.Masque_ReSkin(btn)
		end
		if ns.ApplyIconBorder then ns.ApplyIconBorder(btn, cfg) end
		btn:ClearAllPoints()
		local off = step * (k - 1)
		if grow == "UP" then
			btn:SetPoint("BOTTOM", f, "BOTTOM", xOff, margin + off)
		elseif grow == "RIGHT" then
			btn:SetPoint("LEFT", f, "LEFT", margin + off, xOff)
		elseif grow == "LEFT" then
			btn:SetPoint("RIGHT", f, "RIGHT", -margin - off, xOff)
		elseif grow == "CENTER_V" then
			btn:SetPoint("CENTER", f, "CENTER", xOff, half - off)
		elseif grow == "CENTER_H" then
			btn:SetPoint("CENTER", f, "CENTER", -half + off, xOff)
		else  -- DOWN (default)
			btn:SetPoint("TOP", f, "TOP", xOff, -margin - off)
		end
	end

	if horizontal then
		f:SetSize(blockLen + margin * 2, iconSize + margin * 2)
	else
		f:SetSize(iconSize + margin * 2, blockLen + margin * 2)
	end

	-- With icons the box shows at full alpha; when it goes empty it stays shown while unlock,
	-- test, or autohide-off keeps it up (see ReadyBoxKeepShown), otherwise hiding is deferred
	-- to the box-fade pass in the OnUpdate so the backdrop fades out instead of snapping off.
	local cdm = ns.CDM
	local g = cdm and cdm.db and cdm.db.profile.global
	if count > 0 or ReadyBoxKeepShown(g) then
		-- A hidden box runs no OnUpdate, so resolve on the show transition or it flashes the string it froze at.
		if not f:IsShown() and f._statusLive and f.statusText and cfg.statusText then
			local s = ns.RenderTag(cfg.statusText.text, nil)
			f._statusStr = s
			f.statusText:SetText(s)
		end
		f._boxFade = nil
		f:SetAlpha(cfg.alpha or 1)
		f:Show()
	end
	if ns.SnapFrameToPixelGrid then ns.SnapFrameToPixelGrid(f) end
	UpdateReadyHandle(f)
end


-- Reset a pooled box's popped icons so reuse (profile switch) starts empty; the
-- box-fade pass in OnUpdate then hides the now-empty box if it's locked.
local function ClearReadyIcons(f)
	for i = 1, #f.iconPool do
		local btn = f.iconPool[i]
		if btn then
			ClearIconHighlight(btn)
			btn._pinned   = nil
			btn._readyTime = nil
			btn:SetAlpha(1)
			btn:Hide()
		end
	end
	f._boxFade     = nil
	f._combatTimer = nil
	RelayoutReadyFrame(f)
end


function ns.ReadyFrames_ClearAll()
	local addon = ns.CDM
	if not addon then return end
	for i = 1, 3 do
		local f = addon.readyFrames and addon.readyFrames[i]
		if f then ClearReadyIcons(f) end
	end
end


function ns.ReadyFrames_Build(addon)
	-- Repair saved cfg fields corrupted by an older bug (e.g. color tables written as scalars).
	for i = 1, 3 do
		local cfg = addon.db.profile.readyFrames[i]
		if cfg then
			if type(cfg.bgColor) ~= "table" then
				cfg.bgColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.85 }
			end
			if type(cfg.borderColor) ~= "table" then
				cfg.borderColor = { r = 0, g = 0, b = 0, a = 1 }
			end
			if type(cfg.iconSize) ~= "number" then
				cfg.iconSize = 40
			end
			if type(cfg.iconAlpha) ~= "number" then
				cfg.iconAlpha = 1.0
			end
			if type(cfg.iconOffset) ~= "number" then
				cfg.iconOffset = 0
			end
			if type(cfg.iconText) ~= "table" then
				cfg.iconText = {
					{ enabled = true,  text = "[cd.stacks]" },
					{ enabled = true,  text = "[cd.time]"   },
					{ enabled = false, text = ""            },
				}
			end
		end
	end
	for i = 1, 3 do
		local cfg = addon.db.profile.readyFrames[i]
		if cfg.enabled and not addon.readyFrames[i] then
			ns.ReadyFrames_CreateFrame(addon, i, cfg)
			ns.ReadyFrames_ApplyConfig(i)
		end
	end
end


function ns.ReadyFrames_CreateFrame(addon, index, cfg)
	local f = CreateFrame("Frame", "CooldownMaster_Ready_"..index, UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(ICON_SIZE, ICON_SIZE)
	f:SetPoint(cfg.anchor or "CENTER", UIParent, cfg.anchor or "CENTER", cfg.x or 0, cfg.y or -250)
	if ns.GetFrameScale then f:SetScale(ns.GetFrameScale()) end
	f:SetClampedToScreen(true)
	f:EnableMouse(addon.db.profile.global.unlockFrames)   -- drag-only - RefreshUnlockState keeps it in sync
	f.index     = index
	f.cfg       = cfg
	f.iconPool  = {}

	f:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local cdm = _G.CooldownMaster
		if not (cdm and cdm.db and cdm.db.profile.global.unlockFrames) then return end
		local cursorX, cursorY = GetCursorPosition()
		local scale = self:GetEffectiveScale()
		self._dragStartCursorX = cursorX / scale
		self._dragStartCursorY = cursorY / scale
		local point, _, _, x, y = self:GetPoint()
		self._dragStartFrameX = x
		self._dragStartFrameY = y
		self._dragStartPoint  = point
		self._isDragging      = true
	end)

	f:SetScript("OnMouseUp", function(self, button)
		if not self._isDragging then return end
		self._isDragging = false
		local point, _, _, x, y = self:GetPoint()
		local cdm = _G.CooldownMaster
		local rfCfg = cdm and cdm.db.profile.readyFrames[self.index]
		if rfCfg then
			rfCfg.anchor = point
			rfCfg.x = math.floor(x + 0.5)
			rfCfg.y = math.floor(y + 0.5)
		end
	end)

	f:SetScript("OnUpdate", function(self, elapsed)
		if self._isDragging then
			local cursorX, cursorY = GetCursorPosition()
			local scale = self:GetEffectiveScale()
			cursorX = cursorX / scale
			cursorY = cursorY / scale
			local dx = cursorX - self._dragStartCursorX
			local dy = cursorY - self._dragStartCursorY
			self:ClearAllPoints()
			self:SetPoint(
				self._dragStartPoint or "CENTER",
				UIParent,
				self._dragStartPoint or "CENTER",
				self._dragStartFrameX + dx,
				self._dragStartFrameY + dy
			)
			return
		end

		local cfg = self.cfg
		local cfgAlpha = (cfg and cfg.iconAlpha) or 1
		local g = ns.CDM and ns.CDM.db and ns.CDM.db.profile.global

		-- Hold countdown per icon. A pinned icon freezes (cleared only by the user),
		-- otherwise it fades over its last second and is hidden when the hold expires.
		local visible = 0
		local needRelayout = false
		for i = 1, #self.iconPool do
			local btn = self.iconPool[i]
			if btn and btn:IsShown() then
				if not btn._pinned then
					btn._readyTime = (btn._readyTime or 0) - elapsed
				end
				if not btn._pinned and btn._readyTime <= 0 then
					ClearIconHighlight(btn)
					btn:Hide()
					btn:SetAlpha(1)
					needRelayout = true
				else
					visible = visible + 1
					if g then ns.StyleIcon(btn, btn._spellID, btn._itemID, g) end
					if btn._fadeIn then
						btn._fadeIn = btn._fadeIn - elapsed
						if btn._fadeIn <= 0 then
							btn._fadeIn = nil
							btn:SetAlpha(cfgAlpha)
						else
							btn:SetAlpha(cfgAlpha * (1 - btn._fadeIn / ICON_FADE_IN))
						end
					elseif not btn._pinned and btn._readyTime <= 1.0 then
						btn:SetAlpha(cfgAlpha * btn._readyTime)
					else
						btn:SetAlpha(cfgAlpha)
					end
				end
			end
		end

		-- Post-combat linger: out of combat, force a clear once pTime elapses since the
		-- last pop. Reset to 0 while in combat so the clock starts when combat ends.
		-- Runs once per linger (_lingerDone): a surviving pinned icon keeps visible > 0, so without
		-- the guard this re-fires every frame (relayout alloc + backdrop flicker). Recount the pinned
		-- survivors into `visible` so an all-pinned box stays shown and an empty one still fades out.
		local pTime = (cfg and cfg.pTime) or 0
		if pTime > 0 then
			if InCombatLockdown() then
				self._combatTimer = 0
				self._lingerDone  = nil
			elseif visible > 0 and not self._lingerDone then
				self._combatTimer = (self._combatTimer or 0) + elapsed
				if self._combatTimer >= pTime then
					local stillShown = 0
					for i = 1, #self.iconPool do
						local btn = self.iconPool[i]
						if btn and btn:IsShown() then
							if btn._pinned then
								stillShown = stillShown + 1
							else
								ClearIconHighlight(btn)
								btn:Hide()
								btn:SetAlpha(1)
							end
						end
					end
					needRelayout     = true
					visible          = stillShown
					self._lingerDone = true
				end
			end
		end

		if needRelayout then
			RelayoutReadyFrame(self)
		end

		-- Only a live template re-resolves here - a static one is already set by the pop or the apply.
		if cfg and (self._statusLive or self._tagLive) then
			self._tagClock = (self._tagClock or 0) + elapsed
			if self._tagClock >= TAG_REFRESH then
				self._tagClock = 0
				local scfg = cfg.statusText
				if self._statusLive and scfg then
					local s = ns.RenderTag(scfg.text, nil)
					if self._statusStr ~= s then
						self._statusStr = s
						self.statusText:SetText(s)
					end
				end
				if self._tagLive then
					for i = 1, #self.iconPool do
						local btn = self.iconPool[i]
						if btn and btn:IsShown() then UpdateReadyIconTag(self, btn, cfg) end
					end
				end
			end
		end

		-- Box-level fade: when empty and nothing keeps it shown (unlock/test/autohide-off) it
		-- fades the backdrop out over BOX_FADE_DUR then hides; OnUpdate only runs while shown,
		-- so this owns the empty-box hide.
		local boxAlpha = (cfg and cfg.alpha) or 1
		if visible > 0 or ReadyBoxKeepShown(g) then
			if self._boxFade then
				self._boxFade = nil
				self:SetAlpha(boxAlpha)
			end
		else
			self._boxFade = (self._boxFade or 0) + elapsed
			if self._boxFade >= BOX_FADE_DUR then
				self:SetAlpha(boxAlpha)
				self._boxFade = nil
				self:Hide()
				UpdateReadyHandle(self)
			else
				self:SetAlpha(boxAlpha * (1 - self._boxFade / BOX_FADE_DUR))
			end
		end
	end)

	local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	-- Name floats just above the box so the label fits (the box is only icon-sized).
	label:SetPoint("BOTTOM", f, "TOP", 0, 2)
	label:SetText(cfg.frameName)
	label:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
	label:SetAlpha(addon.db.profile.global.unlockFrames and 0.6 or 0)
	f.label = label

	local statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	statusText:Hide()
	f.statusText = statusText

	f.dragHandle = ns.CreateDragHandle(f, "Ready "..index, function(point, x, y)
		local rfCfg = addon.db.profile.readyFrames[index]
		if rfCfg then
			rfCfg.anchor = point
			rfCfg.x = x
			rfCfg.y = y
		end
	end)

	addon.readyFrames[index] = f
	addon.readyFramePool[index] = f   -- free-list entry; reused across profile/enable changes
end


-- Resolve which ready box a spell pops into: per-spell override -> category default -> off.
-- Box index 1/2/3; 0 (or an unmapped category) = off.
local function ResolveReadyBox(addon, spellID, category)
	local profile = addon.db and addon.db.profile
	if not profile then return 0 end

	local override = profile.spellOverrides and profile.spellOverrides[spellID]
	if override and override.readyBox ~= nil then
		return override.readyBox
	end

	local key = ns.Engine and ns.Engine.GetCategoryFilterKey and ns.Engine:GetCategoryFilterKey(category)
	local fcfg = key and profile.filters and profile.filters[key]
	if fcfg and fcfg.readyBox ~= nil then
		return fcfg.readyBox
	end

	return 0
end


function ns.ReadyFrames_OnReadyTransition(spellID, entry)
	local addon = ns.CDM
	if not addon then return end

	-- Honor the same Filters visibility as the lanes; don't leak hidden spells back on screen.
	local eng = ns.Engine
	if eng and eng.IsSpellVisible and not eng:IsSpellVisible(spellID, entry.category) then
		return
	end

	local boxIndex = ResolveReadyBox(addon, spellID, entry.category)
	if not boxIndex or boxIndex == 0 then return end

	local target = addon.readyFrames and addon.readyFrames[boxIndex]
	local rcfg   = addon.db.profile.readyFrames[boxIndex]
	if not (target and rcfg and rcfg.enabled) then return end

	target._combatTimer = 0   -- a fresh pop restarts the post-combat linger clock
	target._lingerDone  = nil

	local cfg = target.cfg

	local override  = addon.db.profile.spellOverrides and addon.db.profile.spellOverrides[spellID]
	local important = override and override.important == true
	local pinned    = override and override.pinned == true

	local g = addon.db.profile.global

	-- One icon per cooldown: a charge blip can pop the same spell twice inside the display window (see
	-- CHARGE_TRACK_DELAY in Core/Engine.lua). Before the maxIcons cap, so a repeat pop evicts nobody.
	local sharedName = (g.detectSharedCD and entry._source ~= "test" and entry.itemID == nil)
		and entry.name or nil
	-- Only when shown - a hidden box must fall through so the normal path runs RelayoutReadyFrame.
	if target:IsShown() then
		for i = 1, #target.iconPool do
			local b = target.iconPool[i]
			if b and b:IsShown()
				and (b._spellID == spellID
					or (sharedName and b._itemID == nil
						and b._tagSnap and b._tagSnap.name == sharedName)) then
				b._spellID   = spellID
				b._itemID    = entry.itemID
				b._pinned    = pinned
				b._readyTime = important and (cfg.highlightDuration or 10) or (cfg.normalDuration or 5)
				-- Not ICON_FADE_IN: restarting the fade drops alpha to 0 and reads as a flicker.
				b._fadeIn    = nil
				b.tex:SetTexture(entry.icon or "")
				b:SetAlpha(cfg.iconAlpha or 1)
				ns.StyleIcon(b, spellID, entry.itemID, g)

				local rsnap = b._tagSnap
				if not rsnap then
					rsnap = {}
					b._tagSnap = rsnap
				end
				rsnap.name, rsnap.category = entry.name, entry.category
				rsnap.endTime = nil
				UpdateReadyIconTag(target, b, cfg)

				if b.pulse then
					b.pulse:Stop()
					b.pulse:Play()
				end
				ApplyIconHighlight(b, cfg, important)
				PlayReadySound(important and cfg.highlightSound or cfg.normalSound)
				return
			end
		end
	end

	-- Cap concurrent pops for this box: at the limit, recycle the non-pinned icon closest to
	-- fading so the freshest ready always surfaces; drop the new pop if all slots are pinned.
	local maxIcons = cfg.maxIcons or 10
	if maxIcons > 0 then
		local visible, evict, evictTime = 0, nil, nil
		for i = 1, #target.iconPool do
			local b = target.iconPool[i]
			if b and b:IsShown() then
				visible = visible + 1
				if not b._pinned and (not evict or (b._readyTime or 0) < evictTime) then
					evict, evictTime = b, (b._readyTime or 0)
				end
			end
		end
		if visible >= maxIcons then
			if not evict then return end
			ClearIconHighlight(evict)
			evict:Hide()
			evict:SetAlpha(1)
		end
	end

	local slot = nil
	for i = 1, #target.iconPool do
		local btn = target.iconPool[i]
		if btn and not btn:IsShown() then
			slot = i
			break
		end
	end
	if not slot then
		slot = #target.iconPool + 1
	end

	local btn = AcquireReadyIcon(target, slot)
	btn.tex:SetTexture(entry.icon or "")
	btn._spellID   = spellID
	btn._itemID    = entry.itemID
	btn._pinned    = pinned
	btn._readyTime = important and (cfg.highlightDuration or 10) or (cfg.normalDuration or 5)
	btn._fadeIn = ICON_FADE_IN
	btn:SetAlpha(0)
	ns.StyleIcon(btn, spellID, entry.itemID, addon.db.profile.global)

	-- The Engine prunes the entry once it goes ready, so snapshot the tag fields, never hold the entry.
	local snap = btn._tagSnap
	if not snap then
		snap = {}
		btn._tagSnap = snap
	end
	snap.name, snap.category = entry.name, entry.category
	snap.endTime = nil   -- it is ready, so [cd.time] blanks here rather than counting down from 0
	UpdateReadyIconTag(target, btn, cfg)

	btn:Show()

	if btn.pulse then
		btn.pulse:Stop()
		btn.pulse:Play()
	end

	ApplyIconHighlight(btn, cfg, important)

	RelayoutReadyFrame(target)

	PlayReadySound(important and cfg.highlightSound or cfg.normalSound)
end


function ns.ReadyFrames_RefreshUnlockState(addon)
	for i = 1, 3 do
		local f = addon.readyFrames and addon.readyFrames[i]
		if f then
			local unlocked = addon.db.profile.global.unlockFrames
			-- A locked box has no drag to serve, so leaving the mouse on would silently eat world clicks.
			f:EnableMouse(unlocked)
			if f.label then
				local lta = (f.cfg and f.cfg.labelColor and f.cfg.labelColor.a) or 1
				f.label:SetAlpha((unlocked and 0.6 or 0) * lta)
			end
			RelayoutReadyFrame(f)
		end
	end
end


-- Re-evaluate each box's shown state after an autohide toggle. Relayout shows a box that
-- should now stay up (autohide off); one that should now hide when empty is left to the
-- OnUpdate box-fade, which runs while it is still shown.
function ns.ReadyFrames_RefreshVisibility()
	local addon = ns.CDM
	if not addon then return end
	for i = 1, 3 do
		local f = addon.readyFrames and addon.readyFrames[i]
		if f then RelayoutReadyFrame(f) end
	end
end


function ns.ReadyFrames_ApplyConfig(index)
	local ok, err = pcall(function()
		local addon = ns.CDM
		if not addon then return end
		local f = addon.readyFrames and addon.readyFrames[index]
		if not f then return end
		local cfg = addon.db.profile.readyFrames[index]
		if not cfg then return end

		local isMoving = f.IsMoving and f:IsMoving()
		if not isMoving then
			f:ClearAllPoints()
			f:SetPoint(cfg.anchor or "CENTER", UIParent, cfg.anchor or "CENTER", cfg.x or 0, cfg.y or -250)
		end
		if ns.GetFrameScale then f:SetScale(ns.GetFrameScale()) end

		local borderOn = cfg.borderEnabled ~= false
		-- Repair color cfg corrupted by an older bug (scalars instead of tables).
		if type(cfg.bgColor) ~= "table" then
			cfg.bgColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.85 }
		end
		if type(cfg.borderColor) ~= "table" then
			cfg.borderColor = { r = 0, g = 0, b = 0, a = 1 }
		end
		local edgeFile = borderOn and "Interface\\Buttons\\WHITE8x8" or ""
		local edgeSize = borderOn and (cfg.borderSize or 1) or 0
		local bpad     = borderOn and (cfg.borderPadding or 0) or 0
		pcall(f.SetBackdrop, f, {
			bgFile   = "Interface\\Buttons\\WHITE8x8",
			edgeFile = edgeFile,
			edgeSize = edgeSize,
			insets   = { left = bpad, right = bpad, top = bpad, bottom = bpad },
		})
		local bg = cfg.bgColor or { r = 0.1, g = 0.1, b = 0.1, a = 0.85 }
		pcall(f.SetBackdropColor, f, bg.r, bg.g, bg.b, bg.a or 1)
		if borderOn then
			local bc = cfg.borderColor
			if bc then pcall(f.SetBackdropBorderColor, f, bc.r, bc.g, bc.b, bc.a or 1) end
		else
			pcall(f.SetBackdropBorderColor, f, 0, 0, 0, 0)
		end
		f:SetAlpha(cfg.alpha or 1)

		if f.label then
			-- SetAlpha on a FontString overrides its SetTextColor alpha, so carry the tag's opacity on the region.
			local lc = cfg.labelColor or ns.CONST.RGB.YELLOW
			f.label:SetFont(ns.ResolveFont(cfg.labelFont, cfg.labelSize, cfg.labelFlags))
			f.label:SetTextColor(lc.r, lc.g, lc.b, 1)
			f.label:SetText(cfg.frameName or "")
			f.label:SetAlpha((addon.db.profile.global.unlockFrames and 0.6 or 0) * (lc.a or 1))
		end

		ConfigureReadyTagFont(f, cfg)
		for k = 1, #f.iconPool do
			local btn = f.iconPool[k]
			if btn and btn:IsShown() then UpdateReadyIconTag(f, btn, cfg) end
		end

		if f.statusText then
			local scfg = cfg.statusText
			f._statusLive = (scfg and scfg.enabled and ns.TemplateHasLiveTag(scfg.text)) or false
			if scfg and scfg.enabled then
				ns.ApplyStatusTextStyle(f, f.statusText, cfg)
				-- The box itself carries cfg.alpha and the text is its child, so only the picker opacity belongs here.
				f.statusText:SetAlpha((cfg.statusColor and cfg.statusColor.a) or 1)
				local s = ns.RenderTag(scfg.text, nil)
				f._statusStr = s
				f.statusText:SetText(s)
				f.statusText:Show()
			else
				f.statusText:Hide()
			end
		end

		RelayoutReadyFrame(f)
	end)
	if not ok then
		if _G.CooldownMaster then
			_G.CooldownMaster:Print("ReadyFrames_ApplyConfig error: " .. tostring(err))
		end
	end
end


function ns.ReadyFrames_RebuildOne(index)
	local addon = ns.CDM
	if not addon or not addon.db then return end
	local cfg = addon.db.profile.readyFrames[index]
	if not cfg then return end

	-- Same free-list reuse as the lanes: the old destroy-and-recreate orphaned the
	-- box + icon pool on every profile op / enable-toggle (WoW frames never GC).
	local pooled = addon.readyFramePool[index]

	if cfg.enabled then
		if pooled then
			ClearReadyIcons(pooled)
			pooled.cfg = cfg   -- a profile switch swaps in a different box cfg table
			-- RefreshUnlockState skips a disabled box, so a pooled one comes back with a stale mouse state.
			pooled:EnableMouse(addon.db.profile.global.unlockFrames)
			addon.readyFrames[index] = pooled
			ns.ReadyFrames_ApplyConfig(index)
		else
			ns.ReadyFrames_CreateFrame(addon, index, cfg)
			ns.ReadyFrames_ApplyConfig(index)
		end
	else
		if pooled then
			pooled:Hide()
			if pooled.dragHandle then pooled.dragHandle:Hide() end   -- UIParent child, won't hide with the frame
		end
		addon.readyFrames[index] = nil
	end
end
