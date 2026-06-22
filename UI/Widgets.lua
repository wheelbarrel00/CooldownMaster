local ADDON_NAME, ns = ...

ns.Widgets = {}
local Widgets = ns.Widgets


local RGB     = ns.CONST.RGB
local YELLOW  = RGB.YELLOW
local RED     = RGB.RED
local RED_DIM = RGB.RED_DIM
local PANEL_BG     = RGB.PANEL_BG
local PANEL_BORDER = RGB.PANEL_BORDER


-- Duplicates Theme.ApplyBackdrop to avoid a load-time circular file dependency.
local function applyBackdrop(frame, fillColor, borderColor)
	frame:SetBackdrop({
		bgFile   = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets   = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	local bg = fillColor   or PANEL_BG
	local bd = borderColor or PANEL_BORDER
	frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
	frame:SetBackdropBorderColor(bd.r, bd.g, bd.b, bd.a)
end


function Widgets.CreateSectionHeader(parent, labelText)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(18)

	local left = f:CreateTexture(nil, "ARTWORK")
	left:SetColorTexture(YELLOW.r, YELLOW.g, YELLOW.b, 0.9)
	left:SetHeight(1)
	left:SetPoint("LEFT", f, "LEFT", 0, 0)

	local right = f:CreateTexture(nil, "ARTWORK")
	right:SetColorTexture(YELLOW.r, YELLOW.g, YELLOW.b, 0.9)
	right:SetHeight(1)
	right:SetPoint("RIGHT", f, "RIGHT", 0, 0)

	local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("CENTER")
	label:SetText(labelText or "")
	label:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)

	left:SetPoint("RIGHT", label, "LEFT", -6, 0)
	right:SetPoint("LEFT", label, "RIGHT", 6, 0)

	f.label = label
	return f
end


function Widgets.CreateCheckbox(parent, cfg)
	cfg = cfg or {}
	local root = CreateFrame("Frame", nil, parent)
	root:SetSize(220, 24)

	local cb = CreateFrame("CheckButton", nil, root, "UICheckButtonTemplate")
	cb:SetPoint("LEFT", root, "LEFT", 0, 0)
	cb:SetSize(24, 24)

	local fs = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	fs:SetText(cfg.label or "")

	cb:SetChecked(cfg.checked and true or false)
	cb:SetScript("OnClick", function(self)
		local v = self:GetChecked() and true or false
		if root._onChange then root._onChange(v) end
	end)

	root._cb       = cb
	root._onChange = cfg.onChange

	function root:GetValue() return cb:GetChecked() and true or false end
	function root:SetValue(v) cb:SetChecked(v and true or false) end

	return root
end


function Widgets.CreateSlider(parent, cfg)
	cfg = cfg or {}
	local width = cfg.width or 220
	local minV  = cfg.min or 0
	local maxV  = cfg.max or 100
	local step  = cfg.step or 1

	local root = CreateFrame("Frame", nil, parent)
	root:SetSize(width, 56)

	local label = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOP", root, "TOP", 0, 0)
	label:SetText(cfg.label or "")
	label:SetTextColor(1, 1, 1)

	local track = CreateFrame("Frame", nil, root,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	track:SetPoint("TOP", label, "BOTTOM", 0, -4)
	track:SetSize(width, 8)
	applyBackdrop(track, { r = 0.08, g = 0.08, b = 0.08, a = 1 }, PANEL_BORDER)

	local minLabel = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	minLabel:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, -1)
	minLabel:SetText(tostring(minV))
	minLabel:SetTextColor(1, 1, 1)

	local maxLabel = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	maxLabel:SetPoint("TOPRIGHT", track, "BOTTOMRIGHT", 0, -1)
	maxLabel:SetText(tostring(maxV))
	maxLabel:SetTextColor(1, 1, 1)

	local slider = CreateFrame("Slider", nil, track, "OptionsSliderTemplate")
	slider:SetOrientation("HORIZONTAL")
	slider:SetMinMaxValues(minV, maxV)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	slider:SetAllPoints(track)
	if slider.Low  then slider.Low:Hide()  end
	if slider.High then slider.High:Hide() end
	if slider.Text then slider.Text:Hide() end

	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetColorTexture(RED.r, RED.g, RED.b, 1)
	thumb:SetSize(10, 16)
	slider:SetThumbTexture(thumb)

	local edit = CreateFrame("EditBox", nil, root,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	edit:SetPoint("TOP", track, "BOTTOM", 0, -2)
	edit:SetSize(70, 18)
	edit:SetAutoFocus(false)
	edit:SetFontObject("GameFontHighlightSmall")
	edit:SetJustifyH("CENTER")
	edit:SetTextInsets(2, 2, 1, 1)
	applyBackdrop(edit, { r = 0.05, g = 0.05, b = 0.05, a = 1 }, PANEL_BORDER)

	-- Guards against slider<->edit<->onChange feedback recursion.
	local syncing = false

	local function fmt(v)
		if step >= 1 then
			return string.format("%d", math.floor(v + 0.5))
		end
		return string.format("%.2f", v)
	end

	local function fire(v)
		if root._onChange then root._onChange(v) end
	end

	slider:SetScript("OnValueChanged", function(self, value)
		if syncing then return end
		syncing = true
		edit:SetText(fmt(value))
		syncing = false
		fire(value)
	end)

	edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEditFocusLost", function(self)
		local v = tonumber(self:GetText())
		if v then
			if v < minV then v = minV end
			if v > maxV then v = maxV end
			if syncing then return end
			syncing = true
			slider:SetValue(v)
			edit:SetText(fmt(v))
			syncing = false
			fire(v)
		else
			edit:SetText(fmt(slider:GetValue()))
		end
	end)

	local initialV = cfg.value
	if type(initialV) ~= "number" then initialV = minV end
	slider:SetValue(initialV)
	edit:SetText(fmt(initialV))

	root._onChange = cfg.onChange
	root._slider   = slider
	root._edit     = edit

	function root:GetValue() return slider:GetValue() end
	function root:SetValue(v)
		if type(v) ~= "number" then return end
		if syncing then return end
		syncing = true
		slider:SetValue(v)
		edit:SetText(fmt(v))
		syncing = false
	end

	return root
end


function Widgets.CreateDropdown(parent, cfg)
	cfg = cfg or {}
	local width = cfg.width or 180
	local options = cfg.options or {}

	local root = CreateFrame("Frame", nil, parent)
	root:SetSize(width, 44)

	local label = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOP", root, "TOP", 0, 0)
	label:SetText(cfg.label or "")
	label:SetTextColor(1, 1, 1)

	local btn = CreateFrame("Button", nil, root,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	btn:SetPoint("TOP", label, "BOTTOM", 0, -2)
	btn:SetSize(width, 22)
	applyBackdrop(btn, RED, PANEL_BORDER)

	local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	btnText:SetPoint("LEFT", btn, "LEFT", 6, 0)
	btnText:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)

	local chev = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	chev:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
	chev:SetText("v")
	chev:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)

	local list = CreateFrame("Frame", nil, root,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	list:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
	list:SetWidth(width)
	list:SetFrameStrata("DIALOG")
	applyBackdrop(list, RED, PANEL_BORDER)
	list:Hide()

	-- Rows live in a content child so a long option list (e.g. many fonts) can scroll
	-- in a capped, clipped viewport instead of running off the screen.
	local content = CreateFrame("Frame", nil, list)
	content:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
	content:SetWidth(width)

	root._currentValue = cfg.value
	root._optionRows   = {}
	root._onChange     = cfg.onChange

	local function findOptionLabel(value)
		for _, opt in ipairs(options) do
			if opt.value == value then return opt.text end
		end
		return tostring(value or "")
	end

	btnText:SetText(findOptionLabel(root._currentValue))

	local function selectValue(value)
		root._currentValue = value
		btnText:SetText(findOptionLabel(value))
		list:Hide()
		if root._onChange then root._onChange(value) end
	end

	local rowH = 20
	for i, opt in ipairs(options) do
		local row = CreateFrame("Button", nil, content,
			BackdropTemplateMixin and "BackdropTemplate" or nil)
		row:SetSize(width, rowH)
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((i - 1) * rowH))
		applyBackdrop(row, RED_DIM, PANEL_BORDER)

		local rt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		rt:SetPoint("LEFT", row, "LEFT", 6, 0)
		rt:SetText(opt.text)
		rt:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)

		row:SetScript("OnEnter", function(self)
			self:SetBackdropColor(YELLOW.r, YELLOW.g, YELLOW.b, 1)
			rt:SetTextColor(RED.r, RED.g, RED.b)
		end)
		row:SetScript("OnLeave", function(self)
			self:SetBackdropColor(RED_DIM.r, RED_DIM.g, RED_DIM.b, RED_DIM.a)
			rt:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)
		end)
		row:SetScript("OnClick", function() selectValue(opt.value) end)

		root._optionRows[i] = row
	end

	local fullH = rowH * math.max(1, #options)
	content:SetHeight(fullH)
	-- Cap the viewport and scroll the content frame only when the list is taller than
	-- the cap; short lists (every other dropdown) keep the exact prior layout.
	local MAX_LIST_H = 280
	local scroll = 0
	if fullH > MAX_LIST_H then
		list:SetHeight(MAX_LIST_H)
		list:SetClipsChildren(true)
		local maxScroll = fullH - MAX_LIST_H
		list:EnableMouseWheel(true)
		list:SetScript("OnMouseWheel", function(_, delta)
			scroll = math.min(maxScroll, math.max(0, scroll - delta * rowH * 3))
			content:SetPoint("TOPLEFT", list, "TOPLEFT", 0, scroll)
		end)
	else
		list:SetHeight(fullH)
	end

	btn:SetScript("OnClick", function()
		if list:IsShown() then
			list:Hide()
		else
			-- Reopen at the top, not wherever it was last scrolled to.
			if scroll ~= 0 then
				scroll = 0
				content:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
			end
			list:Show()
		end
	end)

	function root:SetEnabled(enabled)
		if enabled then
			btn:Enable()
			btn:SetAlpha(1)
		else
			btn:Disable()
			btn:SetAlpha(0.5)
			list:Hide()
		end
	end

	function root:GetValue() return root._currentValue end
	function root:SetValue(v)
		root._currentValue = v
		btnText:SetText(findOptionLabel(v))
	end

	return root
end


function Widgets.CreateColorPicker(parent, cfg)
	cfg = cfg or {}
	local hasAlpha = cfg.hasAlpha ~= false
	local color = cfg.color or { r = 1, g = 1, b = 1, a = 1 }

	local root = CreateFrame("Frame", nil, parent)
	root:SetSize(180, 24)

	local swatch = CreateFrame("Button", nil, root,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	swatch:SetPoint("LEFT", root, "LEFT", 0, 0)
	swatch:SetSize(20, 20)
	applyBackdrop(swatch, color, PANEL_BORDER)

	local label = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("LEFT", swatch, "RIGHT", 6, 0)
	label:SetText(cfg.label or "")
	label:SetTextColor(1, 1, 1)

	root._color    = { r = color.r, g = color.g, b = color.b, a = color.a or 1 }
	root._onChange = cfg.onChange

	local function applySwatchColor(c)
		swatch:SetBackdropColor(c.r, c.g, c.b, c.a or 1)
	end

	local function fire()
		local c = root._color
		if root._onChange then root._onChange(c.r, c.g, c.b, c.a) end
	end

	local function buildPickerInfo()
		local startR, startG, startB, startA =
			root._color.r, root._color.g, root._color.b, root._color.a
		local info = {
			r = startR, g = startG, b = startB,
			opacity = 1 - (startA or 1),
			hasOpacity = hasAlpha,
			swatchFunc = function()
				local r, g, b
				if ColorPickerFrame.GetColorRGB then
					r, g, b = ColorPickerFrame:GetColorRGB()
				else
					r, g, b = _G.ColorPickerFrame:GetColorRGB()
				end
				root._color.r, root._color.g, root._color.b = r, g, b
				applySwatchColor(root._color)
				fire()
			end,
			opacityFunc = function()
				local a
				if ColorPickerFrame.GetColorAlpha then
					a = ColorPickerFrame:GetColorAlpha()
				elseif _G.OpacitySliderFrame and _G.OpacitySliderFrame:GetValue() then
					a = 1 - _G.OpacitySliderFrame:GetValue()
				end
				root._color.a = a or 1
				applySwatchColor(root._color)
				fire()
			end,
			cancelFunc = function(prev)
				if prev then
					root._color.r = prev.r
					root._color.g = prev.g
					root._color.b = prev.b
					if hasAlpha and prev.opacity ~= nil then
						root._color.a = 1 - prev.opacity
					end
					applySwatchColor(root._color)
					fire()
				end
			end,
		}
		return info
	end

	swatch:SetScript("OnClick", function()
		local info = buildPickerInfo()
		-- Prefer modern SetupColorPickerAndShow (12.0+); fall back to legacy OpenColorPicker.
		if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
			local ok = pcall(ColorPickerFrame.SetupColorPickerAndShow, ColorPickerFrame, info)
			if ok then return end
		end
		if _G.OpenColorPicker then
			pcall(_G.OpenColorPicker, info)
		end
	end)

	function root:GetValue()
		local c = root._color
		return c.r, c.g, c.b, c.a
	end
	function root:SetValue(r, g, b, a)
		root._color.r = r or root._color.r
		root._color.g = g or root._color.g
		root._color.b = b or root._color.b
		root._color.a = a or root._color.a
		applySwatchColor(root._color)
	end

	return root
end


function Widgets.CreateEditBox(parent, cfg)
	cfg = cfg or {}
	local width = cfg.width or 200

	local root = CreateFrame("Frame", nil, parent)
	root:SetSize(width, 40)

	local label = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOP", root, "TOP", 0, 0)
	label:SetText(cfg.label or "")
	label:SetTextColor(1, 1, 1)

	local edit = CreateFrame("EditBox", nil, root,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	edit:SetPoint("TOP", label, "BOTTOM", 0, -2)
	edit:SetSize(width, 20)
	edit:SetAutoFocus(false)
	edit:SetFontObject("GameFontHighlight")
	edit:SetTextInsets(4, 4, 1, 1)
	edit:SetMaxLetters(cfg.maxLetters or 64)
	applyBackdrop(edit, { r = 0.05, g = 0.05, b = 0.05, a = 1 }, PANEL_BORDER)

	if cfg.value then edit:SetText(cfg.value) end

	root._onChange = cfg.onChange

	edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEditFocusGained", function()
		edit:SetBackdropBorderColor(YELLOW.r, YELLOW.g, YELLOW.b, 1)
	end)
	edit:SetScript("OnEditFocusLost", function(self)
		edit:SetBackdropBorderColor(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, PANEL_BORDER.a)
		if root._onChange then root._onChange(self:GetText()) end
	end)
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and root._onChange then
			root._onChange(self:GetText())
		end
	end)

	function root:GetValue() return edit:GetText() end
	function root:SetValue(t) edit:SetText(t or "") end

	return root
end
