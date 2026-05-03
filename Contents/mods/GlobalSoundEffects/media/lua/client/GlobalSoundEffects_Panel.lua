local GlobalSoundEffects = require("GlobalSoundEffects_Main")
local GSE_Config = require("GSE_Config")
local GSE_AudioEngine = require("GSE_AudioEngine")
local GSE_Triggers_Client = require("GSE_Triggers_Client")
local GSE_TriggerShared = require("GSE_TriggerShared")
local Theme = require("ElyonLib/UI/Theme/Theme")

GlobalSoundEffects_Panel = ISCollapsableWindow:derive("GlobalSoundEffects_Panel")
GlobalSoundEffects_Panel.instance = nil

local T = Theme.colors

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

local C = {
	SIZE = {
		DEFAULT_W = 820,
		DEFAULT_H = 630,
		MIN_W = 780,
		MIN_H = 540,
	},
	LAYOUT = {
		PAD = 10,
		COL_GAP = 10,
		SEC_GAP = 8,
		ROW_GAP = 6,
		LBL_GAP = 4,
	},
	CTRL = {
		BTN_PAD_X = 12,
		BTN_PAD_Y = 4,
		FIELD_PAD_X = 10,
	},
	LIST = {
		ROWS = 8,
		QUEUE_ROWS = 4,
		TRIGGER_ROWS = 10,
	},
	TRIGGER = {
		DEFAULT_RADIUS = 5,
	},
	SAMPLE = {
		NUMBER = "00000",
		SLIDER_VAL = "5.00",
		SLIDER_W = "0000000000",
		LONG_FIELD = "WWWWWWWWWWWWWWWWWW",
	},
}

local function measureText(font, text)
	return getTextManager():MeasureStringX(font, tostring(text or ""))
end

local function maxTextWidth(font, texts)
	local w = 0
	for _, t in ipairs(texts) do
		w = math.max(w, measureText(font, t))
	end
	return w
end

local function ctrlH(font)
	return getTextManager():getFontHeight(font) + C.CTRL.BTN_PAD_Y * 2
end

local function btnW(font, text, minW)
	return math.max(minW or 0, measureText(font, text) + C.CTRL.BTN_PAD_X * 2)
end

local function fieldW(font, sample, minW)
	return math.max(minW or 0, measureText(font, sample) + C.CTRL.FIELD_PAD_X * 2)
end

local function listH(itemH, rows)
	return itemH * rows + 2
end

local function rowLblY(rowY, controlH, font)
	return rowY + math.floor((controlH - getTextManager():getFontHeight(font)) / 2)
end

local function tickW(font, text)
	return measureText(font, text) + ctrlH(font) + C.LAYOUT.ROW_GAP
end

local function getSoundLabel(sound)
	if not sound or sound == "" then
		return getText("IGUI_GSE_None")
	end
	local key = "IGUI_" .. tostring(sound)
	local text = getText(key)
	if text == key then
		return tostring(sound)
	end
	return text
end

local function cloneTable(source)
	local out = {}
	for k, v in pairs(source or {}) do
		out[k] = v
	end
	return out
end

local function setBounds(ctrl, x, y, w, h)
	if not ctrl then
		return
	end
	ctrl:setX(x)
	ctrl:setY(y)
	if w then
		ctrl:setWidth(w)
	end
	if h then
		ctrl:setHeight(h)
	end
end

local function syncListScrollBar(list)
	if not list or not list.vscroll then
		return
	end
	local sw = list.vscroll:getWidth()
	list.vscroll:setX(list:getWidth() - sw)
	list.vscroll:setY(0)
	list.vscroll:setHeight(list:getHeight())
	list.vscroll:recalcSize()
end

local function resizeList(list, x, y, w, h)
	if not list then
		return
	end
	list:setX(x)
	list:setY(y)
	list:setWidth(w)
	list:setHeight(h)
	list:recalcSize()
	syncListScrollBar(list)
end

local function getListStencilBounds(list, y, height)
	local border = list.drawBorder and 1 or 0
	local clipX = border
	local clipY = math.max(border, y + list:getYScroll())
	local clipX2 = list:isVScrollBarVisible() and (list.vscroll.x + 3) or (list:getWidth() - border)
	local clipY2 = math.min(list:getHeight() - border, y + height + list:getYScroll())
	if clipX2 <= clipX or clipY2 <= clipY then
		return nil
	end
	return clipX, clipY, clipX2 - clipX, clipY2 - clipY
end

local function drawClippedListRow(list, y, height, drawFn)
	local clipX, clipY, clipW, clipH = getListStencilBounds(list, y, height)
	if not clipX then
		return
	end
	list:setStencilRect(clipX, clipY, clipW, clipH)
	drawFn()
	list:clearStencilRect()
	list:repaintStencilRect(clipX, clipY, clipW, clipH)
end

local function doDrawCenteredListItem(self, y, item, alt)
	if not item.height then
		item.height = self.itemheight
	end
	drawClippedListRow(self, y, item.height, function()
		if self.selected == item.index then
			self:drawRect(0, y, self:getWidth(), item.height - 1, Theme.d(T.selected))
		end
		self:drawRectBorder(0, y, self:getWidth(), item.height, Theme.d(T.borderDim))
		local fH = getTextManager():getFontHeight(self.font)
		local padY = math.max(0, math.floor((item.height - fH) / 2))
		self:drawText(tostring(item.text or ""), C.LAYOUT.PAD, y + padY, Theme.t(T.textMuted))
	end)
	return y + item.height
end

local GSEScrollingListBox = ISScrollingListBox:derive("GSEScrollingListBox")

function GSEScrollingListBox:prerender()
	self.doRepaintStencil = true
	if self.vscroll then
		self.vscroll.doSetStencil = true
		self.vscroll.doRepaintStencil = true
	end
	syncListScrollBar(self)
	ISScrollingListBox.prerender(self)
end

local function makeLabel(panel, x, y, text, font, color)
	font = font or UIFont.Small
	color = color or T.textMuted
	local lbl =
		ISLabel:new(x, y, getTextManager():getFontHeight(font), text, color.r, color.g, color.b, color.a, font, true)
	panel:addChild(lbl)
	return lbl
end

local function makeEntry(panel, x, y, w, h, text, onlyNumbers)
	local e = ISTextEntryBox:new(text or "", x, y, w, h)
	e:initialise()
	e:instantiate()
	if onlyNumbers then
		e:setOnlyNumbers(true)
	end
	Theme.applyFieldStyle(e)
	panel:addChild(e)
	return e
end

local function makeTickBox(panel, x, y, w, label, selected, callback)
	local tick = ISTickBox:new(x, y, w, ctrlH(UIFont.Small), "", panel, callback)
	tick:initialise()
	panel:addChild(tick)
	tick:addOption(label)
	tick.selected[1] = selected == true
	return tick
end

local function makeList(panel, x, y, w, h)
	local iH = FONT_HGT_SMALL + C.LAYOUT.LBL_GAP * 2
	local list = GSEScrollingListBox:new(x, y, w, h)
	list:initialise()
	list:instantiate()
	list.itemheight = iH
	list.font = UIFont.Small
	list.drawBorder = true
	list.doRepaintStencil = true
	if list.vscroll then
		list.vscroll.doSetStencil = true
		list.vscroll.doRepaintStencil = true
	end
	list.backgroundColor = Theme.copy(T.panel)
	list.borderColor = Theme.copy(T.border)
	list.doDrawItem = doDrawCenteredListItem
	panel:addChild(list)
	return list
end

local function makeButton(panel, x, y, w, h, text, callback, internal, variant)
	local btn = ISButton:new(x, y, w, h, text, panel, callback)
	btn.internal = internal
	btn:initialise()
	btn:instantiate()
	Theme.applyButtonStyle(btn, variant)
	panel:addChild(btn)
	return btn
end

function GlobalSoundEffects_Panel:new(x, y, width, height, playerObj, square)
	local o = ISCollapsableWindow.new(self, x, y, width, height)
	setmetatable(o, self)
	self.__index = self

	o.resizable = true
	o.minimumWidth = C.SIZE.MIN_W
	o.minimumHeight = C.SIZE.MIN_H
	o.moveWithMouse = true
	o.title = getText("IGUI_GlobalSoundEffects")
	o.playerObj = playerObj

	o.manualX, o.manualY, o.manualZ = square:getX(), square:getY(), square:getZ()
	o.triggerCenterX, o.triggerCenterY, o.triggerCenterZ = square:getX(), square:getY(), square:getZ()
	o.triggerCorner1X, o.triggerCorner1Y, o.triggerCorner1Z = square:getX(), square:getY(), square:getZ()
	o.triggerCorner2X, o.triggerCorner2Y, o.triggerCorner2Z = square:getX(), square:getY(), square:getZ()

	o.previewMarkers = {}
	o.selectedTriggerId = nil
	o.pickMode = nil
	o._lastPlaybackSignature = nil
	o._lastTriggerSignature = nil

	return o
end

function GlobalSoundEffects_Panel:initialise()
	ISCollapsableWindow.initialise(self)

	local sm = UIFont.Small
	local bH = ctrlH(sm)
	local iH = FONT_HGT_SMALL + C.LAYOUT.LBL_GAP * 2

	self._btnH = bH
	self._itemH = iH
	self._numW = fieldW(sm, C.SAMPLE.NUMBER)
	self._slValW = fieldW(sm, C.SAMPLE.SLIDER_VAL)

	local playSelectedText = getText("IGUI_GSE_PlaySelected")
	local stopText = getText("UI_btn_stop")
	local pickEpicenterText = getText("IGUI_GSE_PickEpicenter")
	local pickCenterText = getText("IGUI_GSE_PickCenter")
	local pickCorner1Text = getText("IGUI_GSE_PickCorner1")
	local pickCorner2Text = getText("IGUI_GSE_PickCorner2")
	local saveTriggerText = getText("IGUI_GSE_SaveTrigger")
	local newTriggerText = getText("IGUI_GSE_NewTrigger")
	local deleteTriggerText = getText("IGUI_GSE_DeleteTrigger")
	local loopText = getText("IGUI_GSE_Loop")
	local queueText = getText("IGUI_GSE_Queue")
	local enabledText = getText("IGUI_GSE_Enabled")
	local targetText = getText("IGUI_GSE_Target")
	local volumeText = getText("IGUI_GSE_Volume")
	local radiusText = getText("IGUI_GSE_Radius")
	local shapeText = getText("IGUI_GSE_Shape")
	local labelText = getText("IGUI_GSE_Label")
	local priorityText = getText("IGUI_GSE_Priority")

	self._playSelectedW = btnW(sm, playSelectedText)
	self._stopW = btnW(sm, stopText)
	self._pickManualW = btnW(sm, pickEpicenterText)
	self._pickCenterW = btnW(sm, pickCenterText)
	self._pickCorner1W = btnW(sm, pickCorner1Text)
	self._pickCorner2W = btnW(sm, pickCorner2Text)
	self._saveW = btnW(sm, saveTriggerText)
	self._newW = btnW(sm, newTriggerText)
	self._deleteW = btnW(sm, deleteTriggerText)
	self._loopTickW = tickW(sm, loopText)
	self._queueTickW = tickW(sm, queueText)
	self._enabledTickW = tickW(sm, enabledText)
	self._trigLoopTickW = tickW(sm, loopText)

	self._tgtLblW = measureText(sm, targetText)
	self._volLblW = measureText(sm, volumeText)
	self._radLblW = measureText(sm, radiusText)
	self._shapeLblW = measureText(sm, shapeText)
	self._lbLblW = measureText(sm, labelText)
	self._prioLblW = measureText(sm, priorityText)

	self.manualTitle = makeLabel(self, 0, 0, getText("IGUI_GSE_ManualTitle"), UIFont.Medium, T.text)
	self.manualHint = makeLabel(self, 0, 0, getText("IGUI_GSE_ManualHint"), UIFont.Small, T.warning)

	self.categoryTitle = makeLabel(self, 0, 0, getText("IGUI_GSE_CategoryTitle"), UIFont.Small, T.textMuted)
	self.categoryCombo = ISComboBox:new(0, 0, 100, bH, self, GlobalSoundEffects_Panel.onCategoryChanged)
	self.categoryCombo:initialise()
	self:addChild(self.categoryCombo)
	for _, cat in ipairs(GSE_Config.getCategoriesSorted()) do
		self.categoryCombo:addOption(cat)
	end
	self.categoryCombo.selected = 1

	self.soundListTitle = makeLabel(self, 0, 0, getText("IGUI_GSE_SoundsTitle"), UIFont.Small, T.textMuted)
	self.titlesList = makeList(self, 0, 0, 100, listH(iH, C.LIST.ROWS))
	self.titlesList.onMouseDown = self.onMouseDown_SoundList
	self.titlesList.onMouseDoubleClick = self.onMouseDoubleClick_SoundList

	self.playSelectedBtn = makeButton(
		self,
		0,
		0,
		self._playSelectedW,
		bH,
		playSelectedText,
		GlobalSoundEffects_Panel.onClick,
		"PLAY_SELECTED",
		"primary"
	)
	self.stopBtn = makeButton(self, 0, 0, self._stopW, bH, stopText, GlobalSoundEffects_Panel.onClick, "STOP", "danger")

	self.currentSoundLabel = makeLabel(
		self,
		0,
		0,
		getText("IGUI_GSE_NowPlayingPrefix") .. getText("IGUI_GSE_NowPlayingIdle"),
		UIFont.Small,
		T.textMuted
	)
	self.currentModeLabel = makeLabel(self, 0, 0, getText("IGUI_GSE_ManualPriorityHint"), UIFont.Small, T.accent)

	self.queueTitle = makeLabel(self, 0, 0, getText("IGUI_GSE_QueueTitle"), UIFont.Small, T.textMuted)
	self.queueList = makeList(self, 0, 0, 100, listH(iH, C.LIST.QUEUE_ROWS))

	self.manualControlsTitle = makeLabel(self, 0, 0, getText("IGUI_GSE_ManualControlsTitle"), UIFont.Small, T.text)
	self.manualControlsHint = makeLabel(self, 0, 0, getText("IGUI_GSE_ManualControlsHint"), UIFont.Small, T.warning)

	self.manualTargetLabel = makeLabel(self, 0, 0, targetText, UIFont.Small)
	self.manualTargetCombo = ISComboBox:new(0, 0, 100, bH, self, GlobalSoundEffects_Panel.onManualTargetChanged)
	self.manualTargetCombo:initialise()
	self.manualTargetCombo:addOption(getText("IGUI_GSE_ManualTargetGlobal"))
	self.manualTargetCombo:addOption(getText("IGUI_GSE_ShapeRadius"))
	self.manualTargetCombo.selected = 1
	self:addChild(self.manualTargetCombo)

	self.manualVolumeLabel = makeLabel(self, 0, 0, volumeText, UIFont.Small)
	self.manualVolumeValue = makeLabel(self, 0, 0, "1.0", UIFont.Small)
	_, self.manualVolumeSlider =
		ISDebugUtils.addSlider(self, "ManualVolume", 0, 0, 100, bH, GlobalSoundEffects_Panel.onSliderChange)
	self.manualVolumeSlider.valueLabel = self.manualVolumeValue
	self.manualVolumeSlider:setValues(0, 5, 0.05, 0.05, true)
	self.manualVolumeSlider.currentValue = 1.0

	self.manualLoopTick =
		makeTickBox(self, 0, 0, self._loopTickW, loopText, false, GlobalSoundEffects_Panel.onManualFlagsChanged)
	self.manualQueueTick =
		makeTickBox(self, 0, 0, self._queueTickW, queueText, false, GlobalSoundEffects_Panel.onManualFlagsChanged)

	self.manualCoordsLabel = makeLabel(self, 0, 0, getText("IGUI_GSE_ManualCoordsGlobal"), UIFont.Small, T.info)
	self.manualRadiusLabel = makeLabel(self, 0, 0, radiusText, UIFont.Small)
	self.manualRadiusEntry = makeEntry(self, 0, 0, self._numW, bH, tostring(C.TRIGGER.DEFAULT_RADIUS), true)
	self.pickManualBtn = makeButton(
		self,
		0,
		0,
		self._pickManualW,
		bH,
		pickEpicenterText,
		GlobalSoundEffects_Panel.onClick,
		"PICK_MANUAL"
	)

	self.manualPlayHint = makeLabel(self, 0, 0, getText("IGUI_GSE_ManualPlayHint"), UIFont.Small, T.success)

	self.triggerTitle = makeLabel(self, 0, 0, getText("IGUI_GSE_TriggerTitle"), UIFont.Medium, T.text)
	self.triggerHint = makeLabel(self, 0, 0, getText("IGUI_GSE_TriggerHint"), UIFont.Small, T.warning)

	self.triggerShapeLabel = makeLabel(self, 0, 0, shapeText, UIFont.Small)
	self.triggerShapeCombo = ISComboBox:new(0, 0, 100, bH, self, GlobalSoundEffects_Panel.onTriggerShapeChanged)
	self.triggerShapeCombo:initialise()
	self.triggerShapeCombo:addOption(getText("IGUI_GSE_ShapeRadius"))
	self.triggerShapeCombo:addOption(getText("IGUI_GSE_ShapeRect"))
	self.triggerShapeCombo.selected = 1
	self:addChild(self.triggerShapeCombo)

	self.triggerLabelLabel = makeLabel(self, 0, 0, labelText, UIFont.Small)
	self.triggerLabelEntry = makeEntry(self, 0, 0, 100, bH, "", false)

	self.triggerPriorityLabel = makeLabel(self, 0, 0, priorityText, UIFont.Small)
	self.triggerPriorityEntry = makeEntry(self, 0, 0, 100, bH, "0", true)

	self.triggerVolumeLabel = makeLabel(self, 0, 0, volumeText, UIFont.Small)
	self.triggerVolumeValue = makeLabel(self, 0, 0, "1.0", UIFont.Small)
	_, self.triggerVolumeSlider =
		ISDebugUtils.addSlider(self, "TriggerVolume", 0, 0, 100, bH, GlobalSoundEffects_Panel.onSliderChange)
	self.triggerVolumeSlider.valueLabel = self.triggerVolumeValue
	self.triggerVolumeSlider:setValues(0, 5, 0.05, 0.05, true)
	self.triggerVolumeSlider.currentValue = 1.0

	self.triggerEnabledTick =
		makeTickBox(self, 0, 0, self._enabledTickW, enabledText, true, GlobalSoundEffects_Panel.onTriggerFlagsChanged)
	self.triggerLoopTick =
		makeTickBox(self, 0, 0, self._trigLoopTickW, loopText, true, GlobalSoundEffects_Panel.onTriggerFlagsChanged)

	self.triggerCenterLabel = makeLabel(self, 0, 0, getText("IGUI_GSE_CenterPlaceholder"), UIFont.Small, T.info)
	self.triggerRadiusLabel = makeLabel(self, 0, 0, radiusText, UIFont.Small)
	self.triggerRadiusEntry = makeEntry(self, 0, 0, self._numW, bH, tostring(C.TRIGGER.DEFAULT_RADIUS), true)
	self.pickTriggerCenterBtn = makeButton(
		self,
		0,
		0,
		self._pickCenterW,
		bH,
		pickCenterText,
		GlobalSoundEffects_Panel.onClick,
		"PICK_TRIGGER_CENTER"
	)

	self.triggerCorner1Label = makeLabel(self, 0, 0, getText("IGUI_GSE_Corner1Placeholder"), UIFont.Small, T.info)
	self.pickTriggerCorner1Btn = makeButton(
		self,
		0,
		0,
		self._pickCorner1W,
		bH,
		pickCorner1Text,
		GlobalSoundEffects_Panel.onClick,
		"PICK_TRIGGER_CORNER1"
	)
	self.triggerCorner2Label = makeLabel(self, 0, 0, getText("IGUI_GSE_Corner2Placeholder"), UIFont.Small, T.info)
	self.pickTriggerCorner2Btn = makeButton(
		self,
		0,
		0,
		self._pickCorner2W,
		bH,
		pickCorner2Text,
		GlobalSoundEffects_Panel.onClick,
		"PICK_TRIGGER_CORNER2"
	)

	self.saveTriggerBtn = makeButton(
		self,
		0,
		0,
		self._saveW,
		bH,
		saveTriggerText,
		GlobalSoundEffects_Panel.onClick,
		"SAVE_TRIGGER",
		"primary"
	)
	self.newTriggerBtn =
		makeButton(self, 0, 0, self._newW, bH, newTriggerText, GlobalSoundEffects_Panel.onClick, "NEW_TRIGGER")

	self.triggerListTitle = makeLabel(self, 0, 0, getText("IGUI_GSE_TriggerListTitle"), UIFont.Small, T.textMuted)
	self.triggerList = makeList(self, 0, 0, 100, listH(iH, C.LIST.TRIGGER_ROWS))
	self.triggerList.onMouseDown = self.onMouseDown_TriggerList

	self.deleteTriggerBtn = makeButton(
		self,
		0,
		0,
		self._deleteW,
		bH,
		deleteTriggerText,
		GlobalSoundEffects_Panel.onClick,
		"DELETE_TRIGGER",
		"danger"
	)
	self.triggerStatusLabel = makeLabel(self, 0, 0, getText("IGUI_GSE_StatusDefault"), UIFont.Small, T.info)

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
	self:layoutChildren()
end

function GlobalSoundEffects_Panel:layoutChildren()
	local pad = C.LAYOUT.PAD
	local colGap = C.LAYOUT.COL_GAP
	local rowG = C.LAYOUT.ROW_GAP
	local secG = C.LAYOUT.SEC_GAP
	local lblG = C.LAYOUT.LBL_GAP
	local sm = UIFont.Small

	local bH = self._btnH or ctrlH(sm)
	local iH = self._itemH or (FONT_HGT_SMALL + lblG * 2)
	local numW = self._numW or fieldW(sm, C.SAMPLE.NUMBER)
	local slValW = self._slValW or fieldW(sm, C.SAMPLE.SLIDER_VAL)
	local lTgtW = self._tgtLblW or 0
	local lVolW = self._volLblW or 0
	local lRadW = self._radLblW or 0
	local rShpW = self._shapeLblW or 0
	local rLbW = self._lbLblW or 0
	local rPriW = self._prioLblW or 0
	local rVolW = lVolW

	local topY = (self:titleBarHeight() or 20) + pad
	local leftW = math.floor((self.width - pad * 2 - colGap) / 2)
	local rightX = pad + leftW + colGap
	local rightW = self.width - rightX - pad

	local lTgtX = pad + lTgtW + rowG
	local lVolX = pad + lVolW + rowG
	local lRadX = pad + lRadW + rowG
	local rShpX = rightX + rShpW + rowG
	local rLbX = rightX + rLbW + rowG
	local rPriX = rightX + rPriW + rowG
	local rVolX = rightX + rVolW + rowG
	local rRadX = rightX + lRadW + rowG

	local lVolSlW = math.max(numW, leftW - lVolW - rowG - slValW - rowG)
	local rVolSlW = math.max(numW, rightW - rVolW - rowG - slValW - rowG)

	local belowSoundList = rowG
		+ bH
		+ rowG
		+ FONT_HGT_SMALL
		+ lblG
		+ FONT_HGT_SMALL
		+ secG
		+ FONT_HGT_SMALL
		+ lblG
		+ listH(iH, C.LIST.QUEUE_ROWS)
		+ secG
		+ FONT_HGT_SMALL
		+ lblG
		+ FONT_HGT_SMALL
		+ secG
		+ bH
		+ rowG
		+ bH
		+ rowG
		+ bH
		+ rowG
		+ FONT_HGT_SMALL
		+ rowG
		+ bH
		+ rowG
		+ FONT_HGT_SMALL
		+ pad

	local aboveSoundList = FONT_HGT_MEDIUM
		+ lblG
		+ FONT_HGT_SMALL
		+ secG
		+ FONT_HGT_SMALL
		+ lblG
		+ bH
		+ secG
		+ FONT_HGT_SMALL
		+ lblG

	local soundListH = math.max(iH * 3, self.height - topY - aboveSoundList - belowSoundList)

	local lY = topY

	setBounds(self.manualTitle, pad, lY, leftW, FONT_HGT_MEDIUM)
	lY = lY + FONT_HGT_MEDIUM + lblG
	setBounds(self.manualHint, pad, lY, leftW, FONT_HGT_SMALL)
	lY = lY + FONT_HGT_SMALL + secG

	setBounds(self.categoryTitle, pad, lY, leftW, FONT_HGT_SMALL)
	lY = lY + FONT_HGT_SMALL + lblG
	setBounds(self.categoryCombo, pad, lY, leftW, bH)
	lY = lY + bH + secG

	setBounds(self.soundListTitle, pad, lY, leftW, FONT_HGT_SMALL)
	lY = lY + FONT_HGT_SMALL + lblG
	local lYBeforeList = lY
	resizeList(self.titlesList, pad, lY, leftW, soundListH)
	lY = lY + soundListH + rowG

	setBounds(self.playSelectedBtn, pad, lY, self._playSelectedW, bH)
	setBounds(self.stopBtn, pad + self._playSelectedW + rowG, lY, self._stopW, bH)
	lY = lY + bH + rowG

	setBounds(self.currentSoundLabel, pad, lY, leftW, FONT_HGT_SMALL)
	self.currentSoundLabel.originalX = pad
	lY = lY + FONT_HGT_SMALL + lblG
	setBounds(self.currentModeLabel, pad, lY, leftW, FONT_HGT_SMALL)
	lY = lY + FONT_HGT_SMALL + secG

	setBounds(self.queueTitle, pad, lY, leftW, FONT_HGT_SMALL)
	lY = lY + FONT_HGT_SMALL + lblG
	resizeList(self.queueList, pad, lY, leftW, listH(iH, C.LIST.QUEUE_ROWS))
	lY = lY + listH(iH, C.LIST.QUEUE_ROWS) + secG

	setBounds(self.manualControlsTitle, pad, lY, leftW, FONT_HGT_SMALL)
	lY = lY + FONT_HGT_SMALL + lblG
	setBounds(self.manualControlsHint, pad, lY, leftW, FONT_HGT_SMALL)
	lY = lY + FONT_HGT_SMALL + secG

	setBounds(self.manualTargetLabel, pad, rowLblY(lY, bH, sm), lTgtW, FONT_HGT_SMALL)
	setBounds(self.manualTargetCombo, lTgtX, lY, leftW - lTgtW - rowG, bH)
	lY = lY + bH + rowG

	local lSlValX = lVolX + lVolSlW + rowG
	setBounds(self.manualVolumeLabel, pad, rowLblY(lY, bH, sm), lVolW, FONT_HGT_SMALL)
	setBounds(self.manualVolumeSlider, lVolX, lY, lVolSlW, bH)
	setBounds(self.manualVolumeValue, lSlValX, rowLblY(lY, bH, sm), slValW, FONT_HGT_SMALL)
	self.manualVolumeValue.originalX = lSlValX
	lY = lY + bH + rowG

	setBounds(self.manualLoopTick, pad, lY, self._loopTickW, bH)
	setBounds(self.manualQueueTick, pad + self._loopTickW + rowG, lY, self._queueTickW, bH)
	lY = lY + bH + rowG

	setBounds(self.manualCoordsLabel, pad, lY, leftW, FONT_HGT_SMALL)
	self.manualCoordsLabel.originalX = pad
	lY = lY + FONT_HGT_SMALL + rowG
	setBounds(self.manualRadiusLabel, pad, rowLblY(lY, bH, sm), lRadW, FONT_HGT_SMALL)
	setBounds(self.manualRadiusEntry, lRadX, lY, numW, bH)
	setBounds(self.pickManualBtn, lRadX + numW + rowG, lY, self._pickManualW, bH)
	lY = lY + bH + rowG

	setBounds(self.manualPlayHint, pad, lY, leftW, FONT_HGT_SMALL)

	local rY = topY

	setBounds(self.triggerTitle, rightX, rY, rightW, FONT_HGT_MEDIUM)
	rY = rY + FONT_HGT_MEDIUM + lblG
	setBounds(self.triggerHint, rightX, rY, rightW, FONT_HGT_SMALL)
	rY = rY + FONT_HGT_SMALL + secG

	setBounds(self.triggerShapeLabel, rightX, rowLblY(rY, bH, sm), rShpW, FONT_HGT_SMALL)
	setBounds(self.triggerShapeCombo, rShpX, rY, rightW - rShpW - rowG, bH)
	rY = rY + bH + rowG

	setBounds(self.triggerLabelLabel, rightX, rowLblY(rY, bH, sm), rLbW, FONT_HGT_SMALL)
	setBounds(self.triggerLabelEntry, rLbX, rY, rightW - rLbW - rowG, bH)
	rY = rY + bH + rowG

	setBounds(self.triggerPriorityLabel, rightX, rowLblY(rY, bH, sm), rPriW, FONT_HGT_SMALL)
	setBounds(self.triggerPriorityEntry, rPriX, rY, rightW - rPriW - rowG, bH)
	rY = rY + bH + rowG

	local rSlValX = rVolX + rVolSlW + rowG
	setBounds(self.triggerVolumeLabel, rightX, rowLblY(rY, bH, sm), rVolW, FONT_HGT_SMALL)
	setBounds(self.triggerVolumeSlider, rVolX, rY, rVolSlW, bH)
	setBounds(self.triggerVolumeValue, rSlValX, rowLblY(rY, bH, sm), slValW, FONT_HGT_SMALL)
	self.triggerVolumeValue.originalX = rSlValX
	rY = rY + bH + rowG

	setBounds(self.triggerEnabledTick, rightX, rY, self._enabledTickW, bH)
	setBounds(self.triggerLoopTick, rightX + self._enabledTickW + rowG, rY, self._trigLoopTickW, bH)
	rY = rY + bH + rowG

	setBounds(self.triggerCenterLabel, rightX, rY, rightW, FONT_HGT_SMALL)
	setBounds(self.triggerCorner1Label, rightX, rY, rightW, FONT_HGT_SMALL)
	self.triggerCenterLabel.originalX = rightX
	self.triggerCorner1Label.originalX = rightX
	rY = rY + FONT_HGT_SMALL + rowG

	setBounds(self.triggerRadiusLabel, rightX, rowLblY(rY, bH, sm), lRadW, FONT_HGT_SMALL)
	setBounds(self.triggerRadiusEntry, rRadX, rY, numW, bH)
	setBounds(self.pickTriggerCenterBtn, rRadX + numW + rowG, rY, self._pickCenterW, bH)
	setBounds(self.pickTriggerCorner1Btn, rightX, rY, self._pickCorner1W, bH)
	rY = rY + bH + rowG

	setBounds(self.triggerCorner2Label, rightX, rY, rightW, FONT_HGT_SMALL)
	self.triggerCorner2Label.originalX = rightX
	rY = rY + FONT_HGT_SMALL + lblG
	setBounds(self.pickTriggerCorner2Btn, rightX, rY, self._pickCorner2W, bH)
	rY = rY + bH + rowG

	setBounds(self.saveTriggerBtn, rightX, rY, self._saveW, bH)
	setBounds(self.newTriggerBtn, rightX + self._saveW + rowG, rY, self._newW, bH)
	rY = rY + bH + secG

	setBounds(self.triggerListTitle, rightX, rY, rightW, FONT_HGT_SMALL)
	rY = rY + FONT_HGT_SMALL + lblG
	local rYBeforeList = rY
	local triggerListH = math.max(iH * 3, self.height - rY - rowG - bH - pad)
	resizeList(self.triggerList, rightX, rY, rightW, triggerListH)
	rY = rY + triggerListH + rowG

	setBounds(self.deleteTriggerBtn, rightX, rY, self._deleteW, bH)
	local statusX = rightX + self._deleteW + rowG
	setBounds(self.triggerStatusLabel, statusX, rowLblY(rY, bH, sm), rightW - self._deleteW - rowG, FONT_HGT_SMALL)
	self.triggerStatusLabel.originalX = statusX

	self.minimumHeight = math.max(lYBeforeList + iH * 3 + belowSoundList, rYBeforeList + iH * 3 + rowG + bH + pad)
end

function GlobalSoundEffects_Panel:onResize()
	self:layoutChildren()
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
	local category = self.categoryCombo and self.categoryCombo:getOptionText(self.categoryCombo.selected)
		or GSE_Config.DEFAULT_CATEGORY
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
	local value = tonumber(entry and entry:getInternalText()) or fallback or C.TRIGGER.DEFAULT_RADIUS
	if value < 1 then
		value = 1
	end
	return math.floor(value)
end

function GlobalSoundEffects_Panel:getManualLabel(sound)
	local base = getSoundLabel(sound)
	if self:isManualGlobal() then
		return base .. " [" .. getText("IGUI_GSE_GlobalTag") .. "]"
	end
	return base
		.. string.format(
			" [%d,%d,%d r=%d]",
			self.manualX or 0,
			self.manualY or 0,
			self.manualZ or 0,
			self:getRadius(self.manualRadiusEntry, C.TRIGGER.DEFAULT_RADIUS)
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
		args.radius = self:getRadius(self.manualRadiusEntry, C.TRIGGER.DEFAULT_RADIUS)
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
	if
		self.manualLoopTick
		and self.manualQueueTick
		and self.manualLoopTick.selected[1] == true
		and self.manualQueueTick.selected[1] == true
	then
		self.manualQueueTick.selected[1] = false
	end
end

function GlobalSoundEffects_Panel:onTriggerFlagsChanged(index, selected) end

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
		self.manualCoordsLabel:setName(getText("IGUI_GSE_ManualCoordsGlobal"))
	else
		self.manualCoordsLabel:setName(
			self:formatCoordLine(getText("IGUI_GSE_Epicenter"), self.manualX, self.manualY, self.manualZ)
		)
	end
	self.triggerCenterLabel:setName(
		self:formatCoordLine(getText("IGUI_GSE_Center"), self.triggerCenterX, self.triggerCenterY, self.triggerCenterZ)
	)
	self.triggerCorner1Label:setName(
		self:formatCoordLine(
			getText("IGUI_GSE_Corner1"),
			self.triggerCorner1X,
			self.triggerCorner1Y,
			self.triggerCorner1Z
		)
	)
	self.triggerCorner2Label:setName(
		self:formatCoordLine(
			getText("IGUI_GSE_Corner2"),
			self.triggerCorner2X,
			self.triggerCorner2Y,
			self.triggerCorner2Z
		)
	)
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
		self:addGridMarker(
			self.manualX,
			self.manualY,
			self.manualZ,
			0.1,
			0.55,
			1.0,
			self:getRadius(self.manualRadiusEntry, C.TRIGGER.DEFAULT_RADIUS),
			true
		)
	end
end

function GlobalSoundEffects_Panel:highlightSquare(x, y, z)
	local sq = getCell():getGridSquare(x, y, z)
	if sq and sq:getFloor() then
		sq:getFloor():setHighlighted(true)
	end
end

function GlobalSoundEffects_Panel:highlightRectArea(x1, y1, x2, y2, z)
	local minX, maxX = math.min(x1, x2), math.max(x1, x2)
	local minY, maxY = math.min(y1, y2), math.max(y1, y2)
	for x = minX, maxX do
		for y = minY, maxY do
			self:highlightSquare(x, y, z)
		end
	end
end

function GlobalSoundEffects_Panel:highlightRadiusArea(cx, cy, z, radius)
	for x = cx - radius, cx + radius do
		for y = cy - radius, cy + radius do
			local dx, dy = x - cx, y - cy
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
			self:highlightRectArea(
				self.triggerCorner1X,
				self.triggerCorner1Y,
				self.triggerCorner2X,
				self.triggerCorner2Y,
				z
			)
		end
		return
	end

	local radius = self:getRadius(self.triggerRadiusEntry, C.TRIGGER.DEFAULT_RADIUS)
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
	local parts = {}
	for i = 1, #entries do
		local r = entries[i]
		parts[#parts + 1] = table.concat({
			r.status or "",
			r.sound or "",
			r.label or "",
			r.source or "",
			tostring(r.loop == true),
			tostring(r.position or 0),
		}, "|")
	end
	local sig = table.concat(parts, ";")
	if not force and sig == self._lastPlaybackSignature then
		return
	end
	self._lastPlaybackSignature = sig

	self.queueList:clear()
	if current then
		self.currentSoundLabel:setName(
			getText("IGUI_GSE_NowPlayingPrefix") .. tostring(current.label or getSoundLabel(current.sound))
		)
	else
		self.currentSoundLabel:setName(getText("IGUI_GSE_NowPlayingPrefix") .. getText("IGUI_GSE_NowPlayingIdle"))
	end

	if #entries == 0 then
		self.queueList:addItem(getText("IGUI_GSE_QueueIdle"), nil)
		return
	end

	for _, row in ipairs(entries) do
		local prefix = getText("IGUI_GSE_QueueStateQueued")
		if row.status == "playing" then
			prefix = getText("IGUI_GSE_QueueStatePlaying")
		elseif row.status == "armed" then
			prefix = getText("IGUI_GSE_QueueStateAreaReady")
		end
		local suffix = row.loop and (" " .. getText("IGUI_GSE_LoopSuffix")) or ""
		local source = row.source == "trigger" and getText("IGUI_GSE_SourceArea") or getText("IGUI_GSE_SourceAdmin")
		self.queueList:addItem(prefix .. " " .. tostring(row.label) .. " [" .. source .. "]" .. suffix, row)
	end
end

function GlobalSoundEffects_Panel:buildTriggerRowText(trigger)
	local shape = trigger.shape == "rect" and getText("IGUI_GSE_TriggerShapeRectShort")
		or getText("IGUI_GSE_TriggerShapeRadiusShort")
	local status = trigger.enabled == true and getText("IGUI_GSE_TriggerEnabledShort")
		or getText("IGUI_GSE_TriggerDisabledShort")
	local loop = trigger.loop == true and getText("IGUI_GSE_TriggerLoopShort") or getText("IGUI_GSE_TriggerOnceShort")
	return string.format(
		"%s%s %s | %s | %s | %s",
		getText("IGUI_GSE_PriorityShort"),
		tostring(trigger.priority or 0),
		status,
		tostring(trigger.label or getSoundLabel(trigger.sound)),
		shape,
		loop
	)
end

function GlobalSoundEffects_Panel:refreshTriggerList(force)
	local triggers = GSE_Triggers_Client.getSortedTriggers()
	local parts = {}
	for i = 1, #triggers do
		local trig = triggers[i]
		parts[#parts + 1] = table.concat({
			tostring(trig.id),
			tostring(trig.label or ""),
			tostring(trig.priority or 0),
			tostring(trig.enabled == true),
			tostring(trig.loop == true),
			tostring(trig.shape or ""),
			tostring(trig.sound or ""),
		}, "|")
	end
	local sig = table.concat(parts, ";")
	if not force and sig == self._lastTriggerSignature then
		return
	end
	self._lastTriggerSignature = sig

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
	self.triggerStatusLabel:setName(getText("IGUI_GSE_StatusEditing") .. tostring(trigger.label or trigger.id))
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
		self.triggerRadiusEntry:setText(tostring(trigger.radius or C.TRIGGER.DEFAULT_RADIUS))
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
		self.triggerStatusLabel:setName(getText("IGUI_GSE_StatusNeedSound"))
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
		trigger.radius = self:getRadius(self.triggerRadiusEntry, C.TRIGGER.DEFAULT_RADIUS)
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

	self.triggerStatusLabel:setName(getText("IGUI_GSE_StatusSaved") .. tostring(trigger.label or trigger.sound))
	self:refreshTriggerList(true)
end

function GlobalSoundEffects_Panel:deleteSelectedTrigger()
	if not self.selectedTriggerId or self.selectedTriggerId == "" then
		self.triggerStatusLabel:setName(getText("IGUI_GSE_StatusSelectSaved"))
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
	self.triggerStatusLabel:setName(getText("IGUI_GSE_StatusDeleted") .. tostring(id))
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
	self.triggerRadiusEntry:setText(tostring(C.TRIGGER.DEFAULT_RADIUS))
	self.triggerStatusLabel:setName(getText("IGUI_GSE_StatusCreating"))
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

	local x, y, z = square:getX(), square:getY(), square:getZ()

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

function GlobalSoundEffects_Panel:prerender()
	ISCollapsableWindow.prerender(self)
	self:refreshPlaybackList(false)
	self:refreshTriggerList(false)
end

function GlobalSoundEffects_Panel:render()
	ISCollapsableWindow.render(self)
	self:renderTriggerHighlights()
end

function GlobalSoundEffects_Panel:close()
	self:removePreviewMarkers()
	self:setVisible(false)
	self:removeFromUIManager()
	GlobalSoundEffects_Panel.instance = nil
end

function GlobalSoundEffects_Panel.openPanel(x, y, playerObj, square)
	if GlobalSoundEffects_Panel.instance then
		return
	end

	GSE_Triggers_Client.init()
	local window = GlobalSoundEffects_Panel:new(x, y, C.SIZE.DEFAULT_W, C.SIZE.DEFAULT_H, playerObj, square)
	window:initialise()

	local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
	local pad = C.LAYOUT.PAD
	window:setX(math.max(pad, math.min(x, sw - window.width - pad)))
	window:setY(math.max(pad, math.min(y, sh - window.height - pad)))

	window:addToUIManager()
	GlobalSoundEffects_Panel.instance = window
end

local MenuDock = require("ElyonLib/UI/MenuDock/MenuDock")

MenuDock.registerButton({
	id = "global_sound_effects",
	title = getText("IGUI_GlobalSoundEffects"),
	icon = "media/ui/ui_icon_global_sound_effects.png",
	minimumAccessLevel = "Admin",
	allowSinglePlayer = true,
	onClick = function(playerNum, entry)
		local playerObj = getSpecificPlayer(playerNum)
		local square = playerObj and playerObj:getCurrentSquare()
		local x = (getCore():getScreenWidth() - C.SIZE.DEFAULT_W) / 2
		local y = math.max(C.LAYOUT.PAD, (getCore():getScreenHeight() - C.SIZE.DEFAULT_H) / 2)
		GlobalSoundEffects_Panel.openPanel(x, y, playerObj, square)
	end,
})
