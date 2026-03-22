local GlobalSoundEffects = require("GlobalSoundEffects_Main")
local GSE_Config = require("GSE_Config")
local GSE_AudioEngine = require("GSE_AudioEngine")
local GSE_Triggers_Client = require("GSE_Triggers_Client")
local GSE_TriggerShared = require("GSE_TriggerShared")

GlobalSoundEffects_Panel = ISPanel:derive("GlobalSoundEffects_Menu")
GlobalSoundEffects_Panel.instance = nil

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

local UI_LAYOUT = {
	OUTER_PAD = 10,
	COLUMN_GAP = 10,
	SECTION_GAP = 8,
	ROW_GAP = 6,
	LABEL_GAP = 4,
	CONTROL_GAP = 8,
	BUTTON_PAD_X = 12,
	BUTTON_PAD_Y = 4,
	FIELD_PAD_X = 10,
	LIST_ROWS = 8,
	QUEUE_ROWS = 4,
	TRIGGER_ROWS = 10,
	MIN_PANEL_WIDTH = 780,
	MIN_PANEL_HEIGHT = 600,
	SCREEN_PAD = 20,
	DEFAULT_RADIUS = 5,
	NUMBER_SAMPLE = "00000",
	SLIDER_VALUE_SAMPLE = "5.00",
	SLIDER_WIDTH_SAMPLE = "0000000000",
	LONG_FIELD_SAMPLE = "WWWWWWWWWWWWWWWWWW",
}

local function uiText(key)
	return getText("IGUI_GSE_" .. key)
end

local function measureText(font, text)
	return getTextManager():MeasureStringX(font, tostring(text or ""))
end

local function maxTextWidth(font, texts)
	local maxWidth = 0
	for _, text in ipairs(texts) do
		maxWidth = math.max(maxWidth, measureText(font, text))
	end
	return maxWidth
end

local function controlHeight(font)
	return getTextManager():getFontHeight(font) + UI_LAYOUT.BUTTON_PAD_Y * 2
end

local function buttonWidth(font, text, minWidth)
	return math.max(minWidth or 0, measureText(font, text) + UI_LAYOUT.BUTTON_PAD_X * 2)
end

local function fieldWidth(font, sampleText, minWidth)
	return math.max(minWidth or 0, measureText(font, sampleText) + UI_LAYOUT.FIELD_PAD_X * 2)
end

local function listHeight(itemHeight, visibleRows)
	return (itemHeight * visibleRows) + 2
end

local function rowLabelY(rowY, controlHgt, font)
	return rowY + math.floor((controlHgt - getTextManager():getFontHeight(font)) / 2)
end

local function tickBoxWidth(font, text)
	return measureText(font, text) + controlHeight(font) + UI_LAYOUT.CONTROL_GAP
end

local function getSoundLabel(sound)
	if not sound or sound == "" then
		return uiText("None")
	end

	local key = "IGUI_" .. tostring(sound)
	local text = getText(key)
	if text == key then
		return tostring(sound)
	end
	return text
end

local function makeLabel(panel, x, y, text, font, color)
	color = color or { r = 1, g = 1, b = 1, a = 1 }
	font = font or UIFont.Small
	local label = ISLabel:new(x, y, getTextManager():getFontHeight(font), text, color.r, color.g, color.b, color.a, font,
		true)
	panel:addChild(label)
	return label
end

local function makeEntry(panel, x, y, w, h, text, onlyNumbers)
	local entry = ISTextEntryBox:new(text or "", x, y, w, h)
	entry:initialise()
	entry:instantiate()
	if onlyNumbers then
		entry:setOnlyNumbers(true)
	end
	panel:addChild(entry)
	return entry
end

local function makeTickBox(panel, x, y, width, label, selected, callback)
	local tick = ISTickBox:new(x, y, width, controlHeight(UIFont.Small), "", panel, callback)
	tick:initialise()
	panel:addChild(tick)
	tick:addOption(label)
	tick.selected[1] = selected == true
	return tick
end

local function cloneTable(source)
	local out = {}
	for k, v in pairs(source or {}) do
		out[k] = v
	end
	return out
end

local function doDrawCenteredListItem(self, y, item, alt)
	if not item.height then
		item.height = self.itemheight
	end

	if self.selected == item.index then
		self:drawRect(0, y, self:getWidth(), item.height - 1, 0.3, 0.7, 0.35, 0.15)
	end

	self:drawRectBorder(0, y, self:getWidth(), item.height, 0.5, self.borderColor.r, self.borderColor.g,
		self.borderColor.b)

	local fontHgt = getTextManager():getFontHeight(self.font)
	local itemPadY = math.max(0, math.floor((item.height - fontHgt) / 2))
	self:drawText(tostring(item.text or ""), UI_LAYOUT.OUTER_PAD, y + itemPadY, 0.9, 0.9, 0.9, 0.95, self.font)

	return y + item.height
end

function GlobalSoundEffects_Panel:new(x, y, width, height, playerObj, square)
	local o = {}
	o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self

	if y == 0 then
		o.y = o:getMouseY() - (height / 2)
		o:setY(o.y)
	end
	if x == 0 then
		o.x = o:getMouseX() - (width / 2)
		o:setX(o.x)
	end

	o.borderColor = { r = 0.45, g = 0.45, b = 0.45, a = 1 }
	o.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.92 }
	o.width = width
	o.height = height
	o.playerObj = playerObj
	o.moveWithMouse = true

	o.manualX = square:getX()
	o.manualY = square:getY()
	o.manualZ = square:getZ()

	o.triggerCenterX = square:getX()
	o.triggerCenterY = square:getY()
	o.triggerCenterZ = square:getZ()
	o.triggerCorner1X = square:getX()
	o.triggerCorner1Y = square:getY()
	o.triggerCorner1Z = square:getZ()
	o.triggerCorner2X = square:getX()
	o.triggerCorner2Y = square:getY()
	o.triggerCorner2Z = square:getZ()

	o.previewMarkers = {}
	o.selectedTriggerId = nil
	o.pickMode = nil
	o._lastPlaybackSignature = nil
	o._lastTriggerSignature = nil

	return o
end

function GlobalSoundEffects_Panel:initialise()
	ISPanel.initialise(self)

	local manualTitleText = uiText("ManualTitle")
	local manualHintText = uiText("ManualHint")
	local categoryTitleText = uiText("CategoryTitle")
	local soundsTitleText = uiText("SoundsTitle")
	local playSelectedText = uiText("PlaySelected")
	local stopText = getText("UI_btn_stop")
	local closeText = getText("UI_btn_close")
	local nowPlayingPrefixText = uiText("NowPlayingPrefix")
	local nowPlayingIdleText = uiText("NowPlayingIdle")
	local manualPriorityHintText = uiText("ManualPriorityHint")
	local queueTitleText = uiText("QueueTitle")
	local manualControlsTitleText = uiText("ManualControlsTitle")
	local manualControlsHintText = uiText("ManualControlsHint")
	local targetText = uiText("Target")
	local manualTargetGlobalText = uiText("ManualTargetGlobal")
	local shapeRadiusText = uiText("ShapeRadius")
	local volumeText = uiText("Volume")
	local loopText = uiText("Loop")
	local queueText = uiText("Queue")
	local manualCoordsGlobalText = uiText("ManualCoordsGlobal")
	local radiusText = uiText("Radius")
	local pickEpicenterText = uiText("PickEpicenter")
	local manualPlayHintText = uiText("ManualPlayHint")
	local triggerTitleText = uiText("TriggerTitle")
	local triggerHintText = uiText("TriggerHint")
	local shapeText = uiText("Shape")
	local shapeRectText = uiText("ShapeRect")
	local labelText = uiText("Label")
	local priorityText = uiText("Priority")
	local enabledText = uiText("Enabled")
	local centerPlaceholderText = uiText("CenterPlaceholder")
	local pickCenterText = uiText("PickCenter")
	local corner1PlaceholderText = uiText("Corner1Placeholder")
	local corner2PlaceholderText = uiText("Corner2Placeholder")
	local pickCorner1Text = uiText("PickCorner1")
	local pickCorner2Text = uiText("PickCorner2")
	local saveTriggerText = uiText("SaveTrigger")
	local newTriggerText = uiText("NewTrigger")
	local triggerListTitleText = uiText("TriggerListTitle")
	local deleteTriggerText = uiText("DeleteTrigger")
	local statusDefaultText = uiText("StatusDefault")
	local statusEditingText = uiText("StatusEditing")
	local statusNeedSoundText = uiText("StatusNeedSound")
	local statusSavedText = uiText("StatusSaved")
	local statusSelectSavedText = uiText("StatusSelectSaved")
	local statusDeletedText = uiText("StatusDeleted")
	local statusCreatingText = uiText("StatusCreating")
	local titleText = getText("IGUI_GlobalSoundEffects")

	local btnHgt = controlHeight(UIFont.Small)
	local comboHgt = controlHeight(UIFont.Small)
	local entryHgt = comboHgt
	local listItemHgt = FONT_HGT_SMALL + UI_LAYOUT.LABEL_GAP * 2
	local numberFieldW = fieldWidth(UIFont.Small, UI_LAYOUT.NUMBER_SAMPLE)
	local sliderValueW = fieldWidth(UIFont.Small, UI_LAYOUT.SLIDER_VALUE_SAMPLE)
	local playSelectedW = buttonWidth(UIFont.Small, playSelectedText)
	local stopW = buttonWidth(UIFont.Small, stopText)
	local closeW = buttonWidth(UIFont.Small, closeText)
	local pickManualW = buttonWidth(UIFont.Small, pickEpicenterText)
	local pickCenterW = buttonWidth(UIFont.Small, pickCenterText)
	local pickCorner1W = buttonWidth(UIFont.Small, pickCorner1Text)
	local pickCorner2W = buttonWidth(UIFont.Small, pickCorner2Text)
	local saveW = buttonWidth(UIFont.Small, saveTriggerText)
	local newW = buttonWidth(UIFont.Small, newTriggerText)
	local deleteW = buttonWidth(UIFont.Small, deleteTriggerText)
	local manualLabelColW = maxTextWidth(UIFont.Small, { targetText, volumeText, radiusText })
	local triggerLabelColW = maxTextWidth(UIFont.Small, { shapeText, labelText, priorityText, volumeText, radiusText })
	local manualTargetComboMinW = fieldWidth(UIFont.Small, manualTargetGlobalText,
		fieldWidth(UIFont.Small, shapeRadiusText))
	local triggerShapeComboMinW = fieldWidth(UIFont.Small, shapeRectText, fieldWidth(UIFont.Small, shapeRadiusText))
	local minSliderW = fieldWidth(UIFont.Small, UI_LAYOUT.SLIDER_WIDTH_SAMPLE)
	local leftMinWidth = math.max(
		measureText(UIFont.Medium, manualTitleText),
		measureText(UIFont.Small, manualHintText),
		measureText(UIFont.Small, manualControlsHintText),
		measureText(UIFont.Small, manualPriorityHintText),
		measureText(UIFont.Small, manualPlayHintText),
		measureText(UIFont.Small, manualCoordsGlobalText),
		playSelectedW + UI_LAYOUT.CONTROL_GAP + stopW,
		manualLabelColW + UI_LAYOUT.CONTROL_GAP + manualTargetComboMinW,
		manualLabelColW + UI_LAYOUT.CONTROL_GAP + minSliderW + UI_LAYOUT.CONTROL_GAP + sliderValueW,
		manualLabelColW + UI_LAYOUT.CONTROL_GAP + numberFieldW + UI_LAYOUT.CONTROL_GAP + pickManualW
	)
	local rightMinWidth = math.max(
		measureText(UIFont.Medium, triggerTitleText),
		measureText(UIFont.Small, triggerHintText),
		measureText(UIFont.Small, centerPlaceholderText),
		measureText(UIFont.Small, corner1PlaceholderText),
		measureText(UIFont.Small, corner2PlaceholderText),
		maxTextWidth(UIFont.Small, {
			statusDefaultText,
			statusEditingText,
			statusNeedSoundText,
			statusSavedText,
			statusSelectSavedText,
			statusDeletedText,
			statusCreatingText,
		}) + UI_LAYOUT.CONTROL_GAP + deleteW,
		triggerLabelColW + UI_LAYOUT.CONTROL_GAP + triggerShapeComboMinW,
		triggerLabelColW + UI_LAYOUT.CONTROL_GAP + fieldWidth(UIFont.Small, UI_LAYOUT.LONG_FIELD_SAMPLE),
		triggerLabelColW + UI_LAYOUT.CONTROL_GAP + minSliderW + UI_LAYOUT.CONTROL_GAP + sliderValueW,
		triggerLabelColW + UI_LAYOUT.CONTROL_GAP + numberFieldW + UI_LAYOUT.CONTROL_GAP + pickCenterW,
		pickCorner1W,
		pickCorner2W,
		saveW + UI_LAYOUT.CONTROL_GAP + newW
	)

	local requiredWidth = math.max(
		self.width,
		UI_LAYOUT.MIN_PANEL_WIDTH,
		UI_LAYOUT.OUTER_PAD * 3 + closeW + measureText(UIFont.Large, titleText),
		(UI_LAYOUT.OUTER_PAD * 2) + leftMinWidth + UI_LAYOUT.COLUMN_GAP + rightMinWidth
	)
	self:setWidth(requiredWidth)
	self.width = requiredWidth

	local margin = UI_LAYOUT.OUTER_PAD
	local gutter = UI_LAYOUT.COLUMN_GAP
	local leftWidth = math.floor((self.width - margin - margin - gutter) / 2)
	local rightX = margin + leftWidth + gutter
	local rightWidth = self.width - rightX - margin
	local titleY = UI_LAYOUT.OUTER_PAD
	local headerHgt = math.max(FONT_HGT_LARGE, btnHgt)
	local topInset = titleY + headerHgt + UI_LAYOUT.SECTION_GAP

	self.titleLabel = makeLabel(self, math.floor((self.width - measureText(UIFont.Large, titleText)) / 2), titleY,
		titleText,
		UIFont.Large, { r = 1, g = 1, b = 1, a = 1 })

	self.closeBtn = ISButton:new(self.width - margin - closeW, titleY, closeW, btnHgt, closeText, self,
		GlobalSoundEffects_Panel.onClick)
	self.closeBtn.internal = "CLOSE"
	self.closeBtn:initialise()
	self.closeBtn:instantiate()
	self:addChild(self.closeBtn)

	local leftControlX = margin + manualLabelColW + UI_LAYOUT.CONTROL_GAP
	local leftControlW = leftWidth - manualLabelColW - UI_LAYOUT.CONTROL_GAP
	local manualSliderW = math.max(minSliderW, leftControlW - sliderValueW - UI_LAYOUT.CONTROL_GAP)
	local manualValueX = leftControlX + manualSliderW + UI_LAYOUT.CONTROL_GAP
	local manualRadiusX = leftControlX
	local manualPickX = manualRadiusX + numberFieldW + UI_LAYOUT.CONTROL_GAP
	local manualToggleLoopW = tickBoxWidth(UIFont.Small, loopText)
	local manualToggleQueueW = tickBoxWidth(UIFont.Small, queueText)
	local listW = leftWidth
	local soundsListH = listHeight(listItemHgt, UI_LAYOUT.LIST_ROWS)
	local queueListH = listHeight(listItemHgt, UI_LAYOUT.QUEUE_ROWS)

	local leftY = topInset
	self.manualTitle = makeLabel(self, margin, leftY, manualTitleText, UIFont.Medium)
	leftY = leftY + FONT_HGT_MEDIUM + UI_LAYOUT.LABEL_GAP
	self.manualHint = makeLabel(self, margin, leftY, manualHintText, UIFont.Small, { r = 0.86, g = 0.86, b = 0.7, a = 1 })
	leftY = leftY + FONT_HGT_SMALL + UI_LAYOUT.SECTION_GAP

	self.categoryTitle = makeLabel(self, margin, leftY, categoryTitleText, UIFont.Small)
	leftY = leftY + FONT_HGT_SMALL + UI_LAYOUT.LABEL_GAP
	self.categoryCombo = ISComboBox:new(margin, leftY, listW, comboHgt, self, GlobalSoundEffects_Panel.onCategoryChanged)
	self.categoryCombo:initialise()
	self:addChild(self.categoryCombo)
	for _, cat in ipairs(GSE_Config.getCategoriesSorted()) do
		self.categoryCombo:addOption(cat)
	end
	self.categoryCombo.selected = 1
	leftY = leftY + comboHgt + UI_LAYOUT.SECTION_GAP

	self.soundListTitle = makeLabel(self, margin, leftY, soundsTitleText, UIFont.Small)
	leftY = leftY + FONT_HGT_SMALL + UI_LAYOUT.LABEL_GAP
	self.titlesList = ISScrollingListBox:new(margin, leftY, listW, soundsListH)
	self.titlesList:initialise()
	self.titlesList:instantiate()
	self.titlesList.itemheight = listItemHgt
	self.titlesList.font = UIFont.Small
	self.titlesList.drawBorder = true
	self.titlesList.doDrawItem = doDrawCenteredListItem
	self.titlesList.onMouseDown = self.onMouseDown_SoundList
	self.titlesList.onMouseDoubleClick = self.onMouseDoubleClick_SoundList
	self:addChild(self.titlesList)
	leftY = leftY + soundsListH + UI_LAYOUT.ROW_GAP

	self.playSelectedBtn = ISButton:new(margin, leftY, playSelectedW, btnHgt, playSelectedText, self,
		GlobalSoundEffects_Panel.onClick)
	self.playSelectedBtn.internal = "PLAY_SELECTED"
	self.playSelectedBtn:initialise()
	self.playSelectedBtn:instantiate()
	self:addChild(self.playSelectedBtn)

	self.stopBtn = ISButton:new(margin + playSelectedW + UI_LAYOUT.CONTROL_GAP, leftY, stopW, btnHgt, stopText, self,
		GlobalSoundEffects_Panel.onClick)
	self.stopBtn.internal = "STOP"
	self.stopBtn:initialise()
	self.stopBtn:instantiate()
	self:addChild(self.stopBtn)
	leftY = leftY + btnHgt + UI_LAYOUT.ROW_GAP

	self.currentSoundLabel = makeLabel(self, margin, leftY, nowPlayingPrefixText .. nowPlayingIdleText, UIFont.Small)
	leftY = leftY + FONT_HGT_SMALL + UI_LAYOUT.LABEL_GAP
	self.currentModeLabel = makeLabel(self, margin, leftY, manualPriorityHintText, UIFont.Small,
		{ r = 0.8, g = 0.85, b = 0.95, a = 1 })
	leftY = leftY + FONT_HGT_SMALL + UI_LAYOUT.SECTION_GAP

	self.queueTitle = makeLabel(self, margin, leftY, queueTitleText, UIFont.Small)
	leftY = leftY + FONT_HGT_SMALL + UI_LAYOUT.LABEL_GAP
	self.queueList = ISScrollingListBox:new(margin, leftY, listW, queueListH)
	self.queueList:initialise()
	self.queueList:instantiate()
	self.queueList.itemheight = listItemHgt
	self.queueList.font = UIFont.Small
	self.queueList.drawBorder = true
	self.queueList.doDrawItem = doDrawCenteredListItem
	self:addChild(self.queueList)
	leftY = leftY + queueListH + UI_LAYOUT.SECTION_GAP

	self.manualControlsTitle = makeLabel(self, margin, leftY, manualControlsTitleText, UIFont.Small)
	leftY = leftY + FONT_HGT_SMALL + UI_LAYOUT.LABEL_GAP
	self.manualControlsHint = makeLabel(self, margin, leftY, manualControlsHintText, UIFont.Small,
		{ r = 0.86, g = 0.86, b = 0.7, a = 1 })
	leftY = leftY + FONT_HGT_SMALL + UI_LAYOUT.SECTION_GAP

	self.manualTargetLabel = makeLabel(self, margin, rowLabelY(leftY, comboHgt, UIFont.Small), targetText, UIFont.Small)
	self.manualTargetCombo = ISComboBox:new(leftControlX, leftY, leftControlW, comboHgt, self,
		GlobalSoundEffects_Panel.onManualTargetChanged)
	self.manualTargetCombo:initialise()
	self.manualTargetCombo:addOption(manualTargetGlobalText)
	self.manualTargetCombo:addOption(shapeRadiusText)
	self.manualTargetCombo.selected = 1
	self:addChild(self.manualTargetCombo)
	leftY = leftY + comboHgt + UI_LAYOUT.ROW_GAP

	self.manualVolumeLabel = makeLabel(self, margin, rowLabelY(leftY, comboHgt, UIFont.Small), volumeText, UIFont.Small)
	self.manualVolumeValue = makeLabel(self, manualValueX, rowLabelY(leftY, comboHgt, UIFont.Small), "1.0", UIFont.Small)
	_, self.manualVolumeSlider = ISDebugUtils.addSlider(self, "ManualVolume", leftControlX, leftY, manualSliderW,
		comboHgt,
		GlobalSoundEffects_Panel.onSliderChange)
	self.manualVolumeSlider.valueLabel = self.manualVolumeValue
	self.manualVolumeSlider:setValues(0, 5, 0.05, 0.05, true)
	self.manualVolumeSlider.currentValue = 1.0
	leftY = leftY + comboHgt + UI_LAYOUT.ROW_GAP

	self.manualLoopTick = makeTickBox(self, margin, leftY, manualToggleLoopW, loopText, false,
		GlobalSoundEffects_Panel.onManualFlagsChanged)
	self.manualQueueTick = makeTickBox(self, margin + manualToggleLoopW + UI_LAYOUT.CONTROL_GAP, leftY,
		manualToggleQueueW,
		queueText, false, GlobalSoundEffects_Panel.onManualFlagsChanged)
	leftY = leftY + comboHgt + UI_LAYOUT.ROW_GAP

	self.manualCoordsLabel = makeLabel(self, margin, leftY, manualCoordsGlobalText, UIFont.Small)
	leftY = leftY + FONT_HGT_SMALL + UI_LAYOUT.ROW_GAP
	self.manualRadiusLabel = makeLabel(self, margin, rowLabelY(leftY, entryHgt, UIFont.Small), radiusText, UIFont.Small)
	self.manualRadiusEntry = makeEntry(self, manualRadiusX, leftY, numberFieldW, entryHgt,
		tostring(UI_LAYOUT.DEFAULT_RADIUS),
		true)
	self.pickManualBtn = ISButton:new(manualPickX, leftY, pickManualW, btnHgt, pickEpicenterText, self,
		GlobalSoundEffects_Panel.onClick)
	self.pickManualBtn.internal = "PICK_MANUAL"
	self.pickManualBtn:initialise()
	self.pickManualBtn:instantiate()
	self:addChild(self.pickManualBtn)
	leftY = leftY + entryHgt + UI_LAYOUT.ROW_GAP

	self.manualPlayHint = makeLabel(self, margin, leftY, manualPlayHintText, UIFont.Small,
		{ r = 0.7, g = 0.86, b = 0.72, a = 1 })
	local leftContentBottom = leftY + FONT_HGT_SMALL

	local rightControlX = rightX + triggerLabelColW + UI_LAYOUT.CONTROL_GAP
	local rightControlW = rightWidth - triggerLabelColW - UI_LAYOUT.CONTROL_GAP
	local triggerSliderW = math.max(minSliderW, rightControlW - sliderValueW - UI_LAYOUT.CONTROL_GAP)
	local triggerValueX = rightControlX + triggerSliderW + UI_LAYOUT.CONTROL_GAP
	local triggerToggleEnabledW = tickBoxWidth(UIFont.Small, enabledText)
	local triggerToggleLoopW = tickBoxWidth(UIFont.Small, loopText)
	local triggerListH = listHeight(listItemHgt, UI_LAYOUT.TRIGGER_ROWS)
	local rightY = topInset

	self.triggerTitle = makeLabel(self, rightX, rightY, triggerTitleText, UIFont.Medium)
	rightY = rightY + FONT_HGT_MEDIUM + UI_LAYOUT.LABEL_GAP
	self.triggerHint = makeLabel(self, rightX, rightY, triggerHintText, UIFont.Small,
		{ r = 0.86, g = 0.86, b = 0.7, a = 1 })
	rightY = rightY + FONT_HGT_SMALL + UI_LAYOUT.SECTION_GAP

	self.triggerShapeLabel = makeLabel(self, rightX, rowLabelY(rightY, comboHgt, UIFont.Small), shapeText, UIFont.Small)
	self.triggerShapeCombo = ISComboBox:new(rightControlX, rightY, rightControlW, comboHgt, self,
		GlobalSoundEffects_Panel.onTriggerShapeChanged)
	self.triggerShapeCombo:initialise()
	self.triggerShapeCombo:addOption(shapeRadiusText)
	self.triggerShapeCombo:addOption(shapeRectText)
	self.triggerShapeCombo.selected = 1
	self:addChild(self.triggerShapeCombo)
	rightY = rightY + comboHgt + UI_LAYOUT.ROW_GAP

	self.triggerLabelLabel = makeLabel(self, rightX, rowLabelY(rightY, entryHgt, UIFont.Small), labelText, UIFont.Small)
	self.triggerLabelEntry = makeEntry(self, rightControlX, rightY, rightControlW, entryHgt, "", false)
	rightY = rightY + entryHgt + UI_LAYOUT.ROW_GAP

	self.triggerPriorityLabel = makeLabel(self, rightX, rowLabelY(rightY, entryHgt, UIFont.Small), priorityText,
		UIFont.Small)
	self.triggerPriorityEntry = makeEntry(self, rightControlX, rightY, rightControlW, entryHgt, "0", true)
	rightY = rightY + entryHgt + UI_LAYOUT.ROW_GAP

	self.triggerVolumeLabel = makeLabel(self, rightX, rowLabelY(rightY, comboHgt, UIFont.Small), volumeText, UIFont
		.Small)
	self.triggerVolumeValue = makeLabel(self, triggerValueX, rowLabelY(rightY, comboHgt, UIFont.Small), "1.0",
		UIFont.Small)
	_, self.triggerVolumeSlider = ISDebugUtils.addSlider(self, "TriggerVolume", rightControlX, rightY, triggerSliderW,
		comboHgt, GlobalSoundEffects_Panel.onSliderChange)
	self.triggerVolumeSlider.valueLabel = self.triggerVolumeValue
	self.triggerVolumeSlider:setValues(0, 5, 0.05, 0.05, true)
	self.triggerVolumeSlider.currentValue = 1.0
	rightY = rightY + comboHgt + UI_LAYOUT.ROW_GAP

	self.triggerEnabledTick = makeTickBox(self, rightX, rightY, triggerToggleEnabledW, enabledText, true,
		GlobalSoundEffects_Panel.onTriggerFlagsChanged)
	self.triggerLoopTick = makeTickBox(self, rightX + triggerToggleEnabledW + UI_LAYOUT.CONTROL_GAP, rightY,
		triggerToggleLoopW, loopText, true, GlobalSoundEffects_Panel.onTriggerFlagsChanged)
	rightY = rightY + comboHgt + UI_LAYOUT.ROW_GAP

	self.triggerCenterLabel = makeLabel(self, rightX, rightY, centerPlaceholderText, UIFont.Small)
	rightY = rightY + FONT_HGT_SMALL + UI_LAYOUT.ROW_GAP
	self.triggerRadiusLabel = makeLabel(self, rightX, rowLabelY(rightY, entryHgt, UIFont.Small), radiusText, UIFont
		.Small)
	self.triggerRadiusEntry = makeEntry(self, rightControlX, rightY, numberFieldW, entryHgt,
		tostring(UI_LAYOUT.DEFAULT_RADIUS),
		true)
	self.pickTriggerCenterBtn = ISButton:new(rightControlX + numberFieldW + UI_LAYOUT.CONTROL_GAP, rightY, pickCenterW,
		btnHgt, pickCenterText, self, GlobalSoundEffects_Panel.onClick)
	self.pickTriggerCenterBtn.internal = "PICK_TRIGGER_CENTER"
	self.pickTriggerCenterBtn:initialise()
	self.pickTriggerCenterBtn:instantiate()
	self:addChild(self.pickTriggerCenterBtn)
	rightY = rightY + entryHgt + UI_LAYOUT.ROW_GAP

	self.triggerCorner1Label = makeLabel(self, rightX, rightY, corner1PlaceholderText, UIFont.Small)
	rightY = rightY + FONT_HGT_SMALL + UI_LAYOUT.LABEL_GAP
	self.pickTriggerCorner1Btn = ISButton:new(rightX, rightY, pickCorner1W, btnHgt, pickCorner1Text, self,
		GlobalSoundEffects_Panel.onClick)
	self.pickTriggerCorner1Btn.internal = "PICK_TRIGGER_CORNER1"
	self.pickTriggerCorner1Btn:initialise()
	self.pickTriggerCorner1Btn:instantiate()
	self:addChild(self.pickTriggerCorner1Btn)
	rightY = rightY + btnHgt + UI_LAYOUT.ROW_GAP

	self.triggerCorner2Label = makeLabel(self, rightX, rightY, corner2PlaceholderText, UIFont.Small)
	rightY = rightY + FONT_HGT_SMALL + UI_LAYOUT.LABEL_GAP
	self.pickTriggerCorner2Btn = ISButton:new(rightX, rightY, pickCorner2W, btnHgt, pickCorner2Text, self,
		GlobalSoundEffects_Panel.onClick)
	self.pickTriggerCorner2Btn.internal = "PICK_TRIGGER_CORNER2"
	self.pickTriggerCorner2Btn:initialise()
	self.pickTriggerCorner2Btn:instantiate()
	self:addChild(self.pickTriggerCorner2Btn)
	rightY = rightY + btnHgt + UI_LAYOUT.ROW_GAP

	self.saveTriggerBtn = ISButton:new(rightX, rightY, saveW, btnHgt, saveTriggerText, self,
		GlobalSoundEffects_Panel.onClick)
	self.saveTriggerBtn.internal = "SAVE_TRIGGER"
	self.saveTriggerBtn:initialise()
	self.saveTriggerBtn:instantiate()
	self:addChild(self.saveTriggerBtn)

	self.newTriggerBtn = ISButton:new(rightX + saveW + UI_LAYOUT.CONTROL_GAP, rightY, newW, btnHgt, newTriggerText, self,
		GlobalSoundEffects_Panel.onClick)
	self.newTriggerBtn.internal = "NEW_TRIGGER"
	self.newTriggerBtn:initialise()
	self.newTriggerBtn:instantiate()
	self:addChild(self.newTriggerBtn)
	rightY = rightY + btnHgt + UI_LAYOUT.SECTION_GAP

	self.triggerListTitle = makeLabel(self, rightX, rightY, triggerListTitleText, UIFont.Small)
	rightY = rightY + FONT_HGT_SMALL + UI_LAYOUT.LABEL_GAP
	self.triggerList = ISScrollingListBox:new(rightX, rightY, rightWidth, triggerListH)
	self.triggerList:initialise()
	self.triggerList:instantiate()
	self.triggerList.itemheight = listItemHgt
	self.triggerList.font = UIFont.Small
	self.triggerList.drawBorder = true
	self.triggerList.doDrawItem = doDrawCenteredListItem
	self.triggerList.onMouseDown = self.onMouseDown_TriggerList
	self:addChild(self.triggerList)
	rightY = rightY + triggerListH + UI_LAYOUT.SECTION_GAP

	self.deleteTriggerBtn = ISButton:new(rightX, rightY, deleteW, btnHgt, deleteTriggerText, self,
		GlobalSoundEffects_Panel.onClick)
	self.deleteTriggerBtn.internal = "DELETE_TRIGGER"
	self.deleteTriggerBtn:initialise()
	self.deleteTriggerBtn:instantiate()
	self:addChild(self.deleteTriggerBtn)

	self.triggerStatusLabel = makeLabel(self, rightX + deleteW + UI_LAYOUT.CONTROL_GAP,
		rowLabelY(rightY, btnHgt, UIFont.Small),
		statusDefaultText, UIFont.Small, { r = 0.8, g = 0.84, b = 0.88, a = 1 })
	local rightContentBottom = rightY + btnHgt

	local requiredHeight = math.max(self.height, UI_LAYOUT.MIN_PANEL_HEIGHT,
		math.max(leftContentBottom, rightContentBottom) + UI_LAYOUT.OUTER_PAD)
	self:setHeight(requiredHeight)
	self.height = requiredHeight

	self:populateList()
	self:ensureSoundSelection()
	self:onSliderChange(self.manualVolumeSlider:getCurrentValue(), self.manualVolumeSlider)
	self:onSliderChange(self.triggerVolumeSlider:getCurrentValue(), self.triggerVolumeSlider)
	self:updateManualControls()
	self:updateTriggerShapeControls()
	self:updateCoordinateLabels()
	self:updateMarkers()
	self:refreshPlaybackList(true)
	self:refreshTriggerList(true)
end

function GlobalSoundEffects_Panel:ensureSoundSelection()
	if self.titlesList and #self.titlesList.items > 0 and self.titlesList.selected <= 0 then
		self.titlesList.selected = 1
	end
end

function GlobalSoundEffects_Panel:isManualGlobal()
	return self.manualTargetCombo and self.manualTargetCombo.selected == 1
end

function GlobalSoundEffects_Panel:isTriggerRadius()
	return self.triggerShapeCombo and self.triggerShapeCombo.selected == 1
end

function GlobalSoundEffects_Panel:populateList()
	self.titlesList:clear()
	local category = self.categoryCombo and self.categoryCombo:getOptionText(self.categoryCombo.selected) or
		GSE_Config.DEFAULT_CATEGORY
	for _, sound in ipairs(GSE_Config.getSoundsForCategory(category)) do
		self.titlesList:addItem(getSoundLabel(sound), sound)
	end
	self:ensureSoundSelection()
end

function GlobalSoundEffects_Panel:onCategoryChanged()
	self:populateList()
end

function GlobalSoundEffects_Panel:onMouseDown_SoundList(x, y)
	local row = self:rowAt(x, y)
	if row == -1 then
		return
	end
	self.selected = row
end

function GlobalSoundEffects_Panel:onMouseDoubleClick_SoundList(x, y)
	local row = self:rowAt(x, y)
	if row == -1 then
		return
	end
	self.selected = row
	self.parent:playSelectedSound()
end

function GlobalSoundEffects_Panel:getSelectedSound()
	local row = self.titlesList.selected
	if row and row > 0 and self.titlesList.items[row] then
		return self.titlesList.items[row].item
	end
	return nil
end

function GlobalSoundEffects_Panel:getRadius(entry, fallback)
	local value = tonumber(entry and entry:getInternalText()) or fallback or UI_LAYOUT.DEFAULT_RADIUS
	if value < 1 then
		value = 1
	end
	return math.floor(value)
end

function GlobalSoundEffects_Panel:getManualLabel(sound)
	local base = getSoundLabel(sound)
	if self:isManualGlobal() then
		return base .. " [" .. uiText("GlobalTag") .. "]"
	end
	return base
		.. string.format(
			" [%d,%d,%d r=%d]",
			self.manualX or 0,
			self.manualY or 0,
			self.manualZ or 0,
			self:getRadius(self.manualRadiusEntry, UI_LAYOUT.DEFAULT_RADIUS)
		)
end

function GlobalSoundEffects_Panel:playSelectedSound()
	local sound = self:getSelectedSound()
	if not sound then
		return
	end
	self:onCommand(sound, "PLAYSFX")
end

function GlobalSoundEffects_Panel:onCommand(effect, command)
	if command ~= "PLAYSFX" or not self.playerObj or self.playerObj ~= getPlayer() then
		return
	end

	local args = {
		cmd = (effect == "GSE_stop") and "stop" or "play",
		sound = effect,
		label = self:getManualLabel(effect),
		volume = self.manualVolumeSlider:getCurrentValue(),
		soundGlobal = self:isManualGlobal(),
		loop = self.manualLoopTick.selected[1] == true,
		queue = (self.manualQueueTick.selected[1] == true) and "enqueue" or nil,
		x = nil,
		y = nil,
		z = nil,
		radius = nil,
	}

	if not self:isManualGlobal() then
		args.x = self.manualX
		args.y = self.manualY
		args.z = self.manualZ
		args.radius = self:getRadius(self.manualRadiusEntry, UI_LAYOUT.DEFAULT_RADIUS)
	end

	if args.loop == true then
		args.queue = nil
	end

	if isClient() then
		sendClientCommand(getPlayer(), "GlobalSoundEffects", "SendAudio", args)
	else
		GlobalSoundEffects.ReceiveAudio(args)
	end
end

function GlobalSoundEffects_Panel:onSliderChange(newval, slider)
	if slider and slider.valueLabel then
		slider.valueLabel:setName(string.format("%.2f", newval))
	end
end

function GlobalSoundEffects_Panel:onManualFlagsChanged(index, selected)
	if self.manualLoopTick and self.manualQueueTick and self.manualLoopTick.selected[1] == true and self.manualQueueTick.selected[1] == true then
		self.manualQueueTick.selected[1] = false
	end
end

function GlobalSoundEffects_Panel:onTriggerFlagsChanged(index, selected)
end

function GlobalSoundEffects_Panel:onManualTargetChanged()
	self:updateManualControls()
	self:updateCoordinateLabels()
	self:updateMarkers()
end

function GlobalSoundEffects_Panel:onTriggerShapeChanged()
	self:updateTriggerShapeControls()
	self:updateCoordinateLabels()
	self:updateMarkers()
end

function GlobalSoundEffects_Panel:updateManualControls()
	local useEpicenter = not self:isManualGlobal()
	self.manualCoordsLabel:setVisible(true)
	self.manualRadiusLabel:setVisible(useEpicenter)
	self.manualRadiusEntry:setVisible(useEpicenter)
	self.pickManualBtn:setVisible(useEpicenter)
end

function GlobalSoundEffects_Panel:updateTriggerShapeControls()
	local isRadius = self:isTriggerRadius()
	self.triggerCenterLabel:setVisible(isRadius)
	self.triggerRadiusLabel:setVisible(isRadius)
	self.triggerRadiusEntry:setVisible(isRadius)
	self.pickTriggerCenterBtn:setVisible(isRadius)

	self.triggerCorner1Label:setVisible(not isRadius)
	self.triggerCorner2Label:setVisible(not isRadius)
	self.pickTriggerCorner1Btn:setVisible(not isRadius)
	self.pickTriggerCorner2Btn:setVisible(not isRadius)
end

function GlobalSoundEffects_Panel:formatCoordLine(prefix, x, y, z)
	return string.format("%s: %d, %d, %d", prefix, x or 0, y or 0, z or 0)
end

function GlobalSoundEffects_Panel:updateCoordinateLabels()
	if self:isManualGlobal() then
		self.manualCoordsLabel:setName(uiText("ManualCoordsGlobal"))
	else
		self.manualCoordsLabel:setName(self:formatCoordLine(uiText("Epicenter"), self.manualX, self.manualY, self
			.manualZ))
	end

	self.triggerCenterLabel:setName(self:formatCoordLine(uiText("Center"), self.triggerCenterX, self.triggerCenterY,
		self.triggerCenterZ))
	self.triggerCorner1Label:setName(self:formatCoordLine(uiText("Corner1"), self.triggerCorner1X, self.triggerCorner1Y,
		self.triggerCorner1Z))
	self.triggerCorner2Label:setName(self:formatCoordLine(uiText("Corner2"), self.triggerCorner2X, self.triggerCorner2Y,
		self.triggerCorner2Z))
end

function GlobalSoundEffects_Panel:removePreviewMarkers()
	for _, marker in ipairs(self.previewMarkers) do
		if marker then
			marker:remove()
		end
	end
	self.previewMarkers = {}
end

function GlobalSoundEffects_Panel:addGridMarker(x, y, z, r, g, b, size, circle)
	local square = getCell():getGridSquare(x, y, z)
	if not square then
		return
	end
	local marker = getWorldMarkers():addGridSquareMarker(square, r, g, b, true, size or 1)
	if circle then
		marker:setScaleCircleTexture(true)
	end
	table.insert(self.previewMarkers, marker)
end

function GlobalSoundEffects_Panel:updateMarkers()
	self:removePreviewMarkers()

	if not self:isManualGlobal() then
		self:addGridMarker(self.manualX, self.manualY, self.manualZ, 0.1, 0.55, 1.0,
			self:getRadius(self.manualRadiusEntry, UI_LAYOUT.DEFAULT_RADIUS), true)
	end
end

function GlobalSoundEffects_Panel:highlightSquare(x, y, z)
	local sq = getCell():getGridSquare(x, y, z)
	if sq and sq:getFloor() then
		sq:getFloor():setHighlighted(true)
	end
end

function GlobalSoundEffects_Panel:highlightRectArea(x1, y1, x2, y2, z)
	local minX = math.min(x1, x2)
	local maxX = math.max(x1, x2)
	local minY = math.min(y1, y2)
	local maxY = math.max(y1, y2)

	for x = minX, maxX do
		for y = minY, maxY do
			self:highlightSquare(x, y, z)
		end
	end
end

function GlobalSoundEffects_Panel:highlightRadiusArea(cx, cy, z, radius)
	for x = cx - radius, cx + radius do
		for y = cy - radius, cy + radius do
			local dx = x - cx
			local dy = y - cy
			if (dx * dx + dy * dy) <= (radius * radius) then
				self:highlightSquare(x, y, z)
			end
		end
	end
end

function GlobalSoundEffects_Panel:renderTriggerHighlights()
	if not self.triggerShapeCombo then
		return
	end

	if not self:isTriggerRadius() then
		local z = self.triggerCorner1Z or self.triggerCorner2Z or 0
		if self.pickMode == "trigger-corner1" then
			local xx, yy = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), z)
			self:highlightSquare(math.floor(xx), math.floor(yy), z)
		elseif self.pickMode == "trigger-corner2" then
			local xx, yy = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), z)
			self:highlightRectArea(self.triggerCorner1X, self.triggerCorner1Y, math.floor(xx), math.floor(yy), z)
		else
			self:highlightRectArea(self.triggerCorner1X, self.triggerCorner1Y, self.triggerCorner2X, self
				.triggerCorner2Y, z)
		end
		return
	end

	local radius = self:getRadius(self.triggerRadiusEntry, UI_LAYOUT.DEFAULT_RADIUS)
	local z = self.triggerCenterZ or 0
	if self.pickMode == "trigger-center" then
		local xx, yy = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), z)
		self:highlightRadiusArea(math.floor(xx), math.floor(yy), z, radius)
	else
		self:highlightRadiusArea(self.triggerCenterX, self.triggerCenterY, z, radius)
	end
end

function GlobalSoundEffects_Panel:refreshPlaybackList(force)
	local entries = GSE_AudioEngine.getPlaybackEntries()
	local current = GSE_AudioEngine.getCurrentRequest()
	local signatureParts = {}
	for i = 1, #entries do
		local row = entries[i]
		signatureParts[#signatureParts + 1] = table.concat({
			row.status or "",
			row.sound or "",
			row.label or "",
			row.source or "",
			tostring(row.loop == true),
			tostring(row.position or 0),
		}, "|")
	end
	local signature = table.concat(signatureParts, ";")
	if not force and signature == self._lastPlaybackSignature then
		return
	end
	self._lastPlaybackSignature = signature

	self.queueList:clear()
	if current then
		self.currentSoundLabel:setName(uiText("NowPlayingPrefix") ..
			tostring(current.label or getSoundLabel(current.sound)))
	else
		self.currentSoundLabel:setName(uiText("NowPlayingPrefix") .. uiText("NowPlayingIdle"))
	end

	if #entries == 0 then
		self.queueList:addItem(uiText("QueueIdle"), nil)
		return
	end

	for _, row in ipairs(entries) do
		local prefix = uiText("QueueStateQueued")
		if row.status == "playing" then
			prefix = uiText("QueueStatePlaying")
		elseif row.status == "armed" then
			prefix = uiText("QueueStateAreaReady")
		end

		local suffix = row.loop and (" " .. uiText("LoopSuffix")) or ""
		local source = row.source == "trigger" and uiText("SourceArea") or uiText("SourceAdmin")
		self.queueList:addItem(prefix .. " " .. tostring(row.label) .. " [" .. source .. "]" .. suffix, row)
	end
end

function GlobalSoundEffects_Panel:buildTriggerRowText(trigger)
	local shape = trigger.shape == "rect" and uiText("TriggerShapeRectShort") or uiText("TriggerShapeRadiusShort")
	local status = trigger.enabled == true and uiText("TriggerEnabledShort") or uiText("TriggerDisabledShort")
	local loop = trigger.loop == true and uiText("TriggerLoopShort") or uiText("TriggerOnceShort")
	return string.format(
		"%s%s %s | %s | %s | %s",
		uiText("PriorityShort"),
		tostring(trigger.priority or 0),
		status,
		tostring(trigger.label or getSoundLabel(trigger.sound)),
		shape,
		loop
	)
end

function GlobalSoundEffects_Panel:refreshTriggerList(force)
	local triggers = GSE_Triggers_Client.getSortedTriggers()
	local signatureParts = {}
	for i = 1, #triggers do
		local trig = triggers[i]
		signatureParts[#signatureParts + 1] = table.concat({
			tostring(trig.id),
			tostring(trig.label or ""),
			tostring(trig.priority or 0),
			tostring(trig.enabled == true),
			tostring(trig.loop == true),
			tostring(trig.shape or ""),
			tostring(trig.sound or ""),
		}, "|")
	end
	local signature = table.concat(signatureParts, ";")
	if not force and signature == self._lastTriggerSignature then
		return
	end
	self._lastTriggerSignature = signature

	self.triggerList:clear()
	local selectedId = self.selectedTriggerId
	local selectedIndex = 0
	for i = 1, #triggers do
		local trigger = triggers[i]
		self.triggerList:addItem(self:buildTriggerRowText(trigger), trigger)
		if trigger.id == selectedId then
			selectedIndex = i
		end
	end
	self.triggerList.selected = selectedIndex
end

function GlobalSoundEffects_Panel:onMouseDown_TriggerList(x, y)
	local row = self:rowAt(x, y)
	if row == -1 then
		return
	end
	self.selected = row
	local item = self.items[row]
	if item and item.item then
		self.parent:loadTriggerIntoEditor(item.item)
	end
end

function GlobalSoundEffects_Panel:loadTriggerIntoEditor(trigger)
	if not trigger then
		return
	end

	self.selectedTriggerId = tostring(trigger.id)
	self.triggerStatusLabel:setName(uiText("StatusEditing") .. tostring(trigger.label or trigger.id))
	self.triggerLabelEntry:setText(tostring(trigger.label or ""))
	self.triggerPriorityEntry:setText(tostring(trigger.priority or 0))
	self.triggerEnabledTick.selected[1] = trigger.enabled == true
	self.triggerLoopTick.selected[1] = trigger.loop == true
	self.triggerVolumeSlider.currentValue = tonumber(trigger.volume) or 1.0
	self:onSliderChange(self.triggerVolumeSlider:getCurrentValue(), self.triggerVolumeSlider)

	if trigger.shape == "rect" then
		self.triggerShapeCombo.selected = 2
		self.triggerCorner1X = tonumber(trigger.x1) or self.triggerCorner1X
		self.triggerCorner1Y = tonumber(trigger.y1) or self.triggerCorner1Y
		self.triggerCorner1Z = tonumber(trigger.z) or self.triggerCorner1Z
		self.triggerCorner2X = tonumber(trigger.x2) or self.triggerCorner2X
		self.triggerCorner2Y = tonumber(trigger.y2) or self.triggerCorner2Y
		self.triggerCorner2Z = tonumber(trigger.z) or self.triggerCorner2Z
	else
		self.triggerShapeCombo.selected = 1
		self.triggerCenterX = tonumber(trigger.x) or self.triggerCenterX
		self.triggerCenterY = tonumber(trigger.y) or self.triggerCenterY
		self.triggerCenterZ = tonumber(trigger.z) or self.triggerCenterZ
		self.triggerRadiusEntry:setText(tostring(trigger.radius or UI_LAYOUT.DEFAULT_RADIUS))
	end

	self:selectSound(trigger.sound)
	self:updateTriggerShapeControls()
	self:updateCoordinateLabels()
	self:updateMarkers()
end

function GlobalSoundEffects_Panel:selectSound(sound)
	if not sound then
		return
	end

	local categories = GSE_Config.getCategoriesSorted()
	for categoryIndex = 1, #categories do
		local category = categories[categoryIndex]
		local sounds = GSE_Config.getSoundsForCategory(category)
		for i = 1, #sounds do
			if sounds[i] == sound then
				self.categoryCombo.selected = categoryIndex
				self:populateList()
				self.titlesList.selected = i
				return
			end
		end
	end
end

function GlobalSoundEffects_Panel:generateTriggerId()
	if self.selectedTriggerId and self.selectedTriggerId ~= "" then
		return self.selectedTriggerId
	end

	local worldAge = 0
	if getGameTime() then
		worldAge = math.floor((getGameTime():getWorldAgeHours() or 0) * 100)
	end
	return string.format("gse_%d_%d", worldAge, ZombRand(1000000))
end

function GlobalSoundEffects_Panel:collectTriggerFromEditor()
	local sound = self:getSelectedSound()
	if not sound then
		self.triggerStatusLabel:setName(uiText("StatusNeedSound"))
		return nil
	end

	local trigger = {
		id = self:generateTriggerId(),
		label = self.triggerLabelEntry:getInternalText(),
		enabled = self.triggerEnabledTick.selected[1] == true,
		shape = self:isTriggerRadius() and "radius" or "rect",
		sound = sound,
		volume = self.triggerVolumeSlider:getCurrentValue(),
		priority = tonumber(self.triggerPriorityEntry:getInternalText()) or 0,
		loop = self.triggerLoopTick.selected[1] == true,
		z = 0,
	}

	if trigger.shape == "rect" then
		trigger.x1 = self.triggerCorner1X
		trigger.y1 = self.triggerCorner1Y
		trigger.x2 = self.triggerCorner2X
		trigger.y2 = self.triggerCorner2Y
		trigger.z = self.triggerCorner1Z or self.triggerCorner2Z or 0
	else
		trigger.x = self.triggerCenterX
		trigger.y = self.triggerCenterY
		trigger.z = self.triggerCenterZ
		trigger.radius = self:getRadius(self.triggerRadiusEntry, UI_LAYOUT.DEFAULT_RADIUS)
	end

	return GSE_TriggerShared.normalizeTrigger(trigger)
end

function GlobalSoundEffects_Panel:saveTrigger()
	local trigger = self:collectTriggerFromEditor()
	if not trigger then
		return
	end

	self.selectedTriggerId = trigger.id
	if isClient() then
		sendClientCommand(getPlayer(), "GlobalSoundEffects", "AddTrigger", { trigger = trigger })
	else
		local triggers = ModData.getOrCreate(GSE_TriggerShared.MODDATA_KEY)
		triggers[trigger.id] = cloneTable(trigger)
		GSE_Triggers_Client.refreshLocal()
	end

	self.triggerStatusLabel:setName(uiText("StatusSaved") .. tostring(trigger.label or trigger.sound))
	self:refreshTriggerList(true)
end

function GlobalSoundEffects_Panel:deleteSelectedTrigger()
	if not self.selectedTriggerId or self.selectedTriggerId == "" then
		self.triggerStatusLabel:setName(uiText("StatusSelectSaved"))
		return
	end

	local id = self.selectedTriggerId
	if isClient() then
		sendClientCommand(getPlayer(), "GlobalSoundEffects", "RemoveTrigger", { id = id })
	else
		local triggers = ModData.getOrCreate(GSE_TriggerShared.MODDATA_KEY)
		triggers[id] = nil
		GSE_Triggers_Client.refreshLocal()
	end

	self:clearTriggerEditor()
	self.triggerStatusLabel:setName(uiText("StatusDeleted") .. tostring(id))
	self:refreshTriggerList(true)
end

function GlobalSoundEffects_Panel:clearTriggerEditor()
	self.selectedTriggerId = nil
	self.triggerLabelEntry:setText("")
	self.triggerPriorityEntry:setText("0")
	self.triggerEnabledTick.selected[1] = true
	self.triggerLoopTick.selected[1] = true
	self.triggerVolumeSlider.currentValue = 1.0
	self:onSliderChange(self.triggerVolumeSlider:getCurrentValue(), self.triggerVolumeSlider)
	self.triggerShapeCombo.selected = 1
	self.triggerRadiusEntry:setText(tostring(UI_LAYOUT.DEFAULT_RADIUS))
	self.triggerStatusLabel:setName(uiText("StatusCreating"))
	self:updateTriggerShapeControls()
	self:updateCoordinateLabels()
	self:updateMarkers()
end

function GlobalSoundEffects_Panel:requestSquarePick(mode)
	self.pickMode = mode
	self.cursor = ISSelectCursor:new(self.playerObj, self, self.onSquareSelected)
	getCell():setDrag(self.cursor, self.playerObj:getPlayerNum())
end

function GlobalSoundEffects_Panel:onSquareSelected(square)
	self.cursor = nil
	if not square then
		return
	end

	local x = square:getX()
	local y = square:getY()
	local z = square:getZ()

	if self.pickMode == "manual" then
		self.manualX, self.manualY, self.manualZ = x, y, z
	elseif self.pickMode == "trigger-center" then
		self.triggerCenterX, self.triggerCenterY, self.triggerCenterZ = x, y, z
	elseif self.pickMode == "trigger-corner1" then
		self.triggerCorner1X, self.triggerCorner1Y, self.triggerCorner1Z = x, y, z
	elseif self.pickMode == "trigger-corner2" then
		self.triggerCorner2X, self.triggerCorner2Y, self.triggerCorner2Z = x, y, z
	end

	self.pickMode = nil
	self:updateCoordinateLabels()
	self:updateMarkers()
end

function GlobalSoundEffects_Panel:onClick(button)
	if button.internal == "PLAY_SELECTED" then
		self:playSelectedSound()
	elseif button.internal == "STOP" then
		self:onCommand("GSE_stop", "PLAYSFX")
	elseif button.internal == "CLOSE" then
		self:close()
	elseif button.internal == "PICK_MANUAL" then
		self:requestSquarePick("manual")
	elseif button.internal == "PICK_TRIGGER_CENTER" then
		self:requestSquarePick("trigger-center")
	elseif button.internal == "PICK_TRIGGER_CORNER1" then
		self:requestSquarePick("trigger-corner1")
	elseif button.internal == "PICK_TRIGGER_CORNER2" then
		self:requestSquarePick("trigger-corner2")
	elseif button.internal == "SAVE_TRIGGER" then
		self:saveTrigger()
	elseif button.internal == "DELETE_TRIGGER" then
		self:deleteSelectedTrigger()
	elseif button.internal == "NEW_TRIGGER" then
		self:clearTriggerEditor()
	end
end

function GlobalSoundEffects_Panel:render()
	ISPanel.render(self)
	self:renderTriggerHighlights()
end

function GlobalSoundEffects_Panel:prerender()
	self:drawRect(
		0,
		0,
		self.width,
		self.height,
		self.backgroundColor.a,
		self.backgroundColor.r,
		self.backgroundColor.g,
		self.backgroundColor.b
	)
	self:drawRectBorder(
		0,
		0,
		self.width,
		self.height,
		self.borderColor.a,
		self.borderColor.r,
		self.borderColor.g,
		self.borderColor.b
	)

	self:refreshPlaybackList(false)
	self:refreshTriggerList(false)
end

function GlobalSoundEffects_Panel:close()
	self:removePreviewMarkers()
	self:setVisible(false)
	self:removeFromUIManager()
	GlobalSoundEffects_Panel.instance = nil
end

function GlobalSoundEffects_Panel.openPanel(x, y, playerObj, square)
	if GlobalSoundEffects_Panel.instance == nil then
		GSE_Triggers_Client.init()
		local window = GlobalSoundEffects_Panel:new(x, y, UI_LAYOUT.MIN_PANEL_WIDTH, UI_LAYOUT.MIN_PANEL_HEIGHT,
			playerObj,
			square)
		window:initialise()
		local maxX = math.max(UI_LAYOUT.SCREEN_PAD, getCore():getScreenWidth() - window.width - UI_LAYOUT.SCREEN_PAD)
		local maxY = math.max(UI_LAYOUT.SCREEN_PAD, getCore():getScreenHeight() - window.height - UI_LAYOUT.SCREEN_PAD)
		window:setX(math.max(UI_LAYOUT.SCREEN_PAD, math.min(window.x, maxX)))
		window:setY(math.max(UI_LAYOUT.SCREEN_PAD, math.min(window.y, maxY)))
		window:addToUIManager()
		GlobalSoundEffects_Panel.instance = window
	end
end

local function onFillWorldObjectContextMenu(player, context, worldobjects, test)
	if not player then
		return
	end

	local hasAccess = false
	if not isClient() and not isServer() then
		hasAccess = true
	elseif isClient() then
		hasAccess = isAdmin()
	end

	if getCore():getDebug() then
		hasAccess = true
	end

	local square = nil
	for _, v in ipairs(worldobjects) do
		square = v:getSquare()
		break
	end

	if hasAccess and square then
		local playerObj = getSpecificPlayer(player)
		local GSE_contextMenu = context:addOptionOnTop(uiText("ContextMenuOption"), worldobjects, function()
			local x = (getCore():getScreenWidth() - UI_LAYOUT.MIN_PANEL_WIDTH) / 2
			local y = math.max(UI_LAYOUT.SCREEN_PAD, (getCore():getScreenHeight() - UI_LAYOUT.MIN_PANEL_HEIGHT) / 2)
			GlobalSoundEffects_Panel.openPanel(x, y, playerObj, square)
		end)
		GSE_contextMenu.iconTexture = getTexture("media/ui/GSE_volume.png")
	end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
