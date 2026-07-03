local ADDON_NAME, ns = ...

local ICON_SIZE = 40
local BOX_FADE_DUR = 0.3   -- seconds for the backdrop to fade out once the box goes empty
local ICON_FADE_IN = 0.25  -- icon alpha fade-in on pop, so it surfaces softly instead of snapping in

-- Built-in ready sounds via Blizzard SOUNDKIT (no bundled asset files). The Ready
-- Sound dropdown lists these first, then any LibSharedMedia sounds the user has.
local READY_BUILTIN_SOUNDS = {
	{ name = "CDM: Ready Check",  kit = "READY_CHECK"            },
	{ name = "CDM: Quest Ding",   kit = "IG_QUEST_LIST_COMPLETE" },
	{ name = "CDM: Raid Warning", kit = "RAID_WARNING"           },
}
ns.READY_BUILTIN_SOUNDS = READY_BUILTIN_SOUNDS

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

local function AcquireReadyIcon(f, index)
	local pool = f.iconPool
	local btn  = pool[index]
	if btn then return btn end

	btn = CreateFrame("Frame", "CooldownMaster_Ready_"..f.index.."_Btn_"..index, f)
	btn:SetSize(ICON_SIZE, ICON_SIZE)

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

	btn:Hide()
	pool[index] = btn
	return btn
end


local function ClearIconHighlight(btn)
	if btn.hlFlash then btn.hlFlash:Stop() end
	if btn.hl then btn.hl:Hide() end
end


local function ApplyIconHighlight(btn, cfg, important)
	ClearIconHighlight(btn)
	if not important or not btn.hl then return end

	local hl    = cfg.highlight
	local style = (hl and hl.style) or "BORDER"
	if style == "NONE" then return end

	local c = (hl and hl.color) or { r = 1, g = 0.82, b = 0, a = 0.6 }
	btn.hl:SetVertexColor(c.r or 1, c.g or 1, c.b or 1)
	btn.hl:SetAlpha(c.a or 0.6)
	btn.hl:Show()
	-- BORDER is static; GLOW / FLASH / BORDER_FLASH pulse (we deliberately avoid the
	-- deprecated Blizzard ActionButton glow API, which is gone on some flavors).
	if style ~= "BORDER" and btn.hlFlash then
		btn.hlFlash:Play()
	end
end

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

	local active = {}
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

	-- While unlocked the box stays visible (so it can be positioned) and with icons
	-- it shows at full alpha; when it goes empty + locked, hiding is deferred to the
	-- box-fade pass in the OnUpdate so the backdrop fades out instead of snapping off.
	local cdm = ns.CDM
	local unlocked = cdm and cdm.db and cdm.db.profile.global.unlockFrames
	if unlocked or count > 0 then
		f._boxFade = nil
		f:SetAlpha(cfg.alpha or 1)
		f:Show()
	end
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
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f.laneIndex = index  -- kept for parity; used in drag save
	f.index     = index
	f.cfg       = cfg
	f.iconPool  = {}
	f.activeIcons = 0

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
		local pTime = (cfg and cfg.pTime) or 0
		if visible > 0 and pTime > 0 then
			if InCombatLockdown() then
				self._combatTimer = 0
			else
				self._combatTimer = (self._combatTimer or 0) + elapsed
				if self._combatTimer >= pTime then
					for i = 1, #self.iconPool do
						local btn = self.iconPool[i]
						if btn and btn:IsShown() and not btn._pinned then
							ClearIconHighlight(btn)
							btn:Hide()
							btn:SetAlpha(1)
						end
					end
					needRelayout = true
					visible = 0
				end
			end
		end

		if needRelayout then
			RelayoutReadyFrame(self)
		end

		-- Box-level fade: empty + locked fades the backdrop out over BOX_FADE_DUR then
		-- hides; OnUpdate only runs while shown, so this owns the empty-box hide.
		local boxAlpha = (cfg and cfg.alpha) or 1
		local unlocked = ns.CDM and ns.CDM.db and ns.CDM.db.profile.global.unlockFrames
		if unlocked or visible > 0 then
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

	local cfg = target.cfg

	local override  = addon.db.profile.spellOverrides and addon.db.profile.spellOverrides[spellID]
	local important = override and override.important == true
	local pinned    = override and override.pinned == true

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
			if f.label then
				local unlocked = addon.db.profile.global.unlockFrames
				f.label:SetAlpha(unlocked and 0.6 or 0)
			end
			RelayoutReadyFrame(f)
		end
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
			f.label:SetText(cfg.frameName or "")
			f.label:SetAlpha(addon.db.profile.global.unlockFrames and 0.6 or 0)
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
			addon.readyFrames[index] = pooled
			ns.ReadyFrames_ApplyConfig(index)
		else
			ns.ReadyFrames_CreateFrame(addon, index, cfg)
			ns.ReadyFrames_ApplyConfig(index)
		end
	else
		if pooled then pooled:Hide() end
		addon.readyFrames[index] = nil
	end
end
