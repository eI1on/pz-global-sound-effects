local GlobalSoundEffects = require("GlobalSoundEffects_Main")
local GSE_Config = require("GSE_Config")
local GSE_AudioEngine = require("GSE_AudioEngine")

GlobalSoundEffects_Panel = ISPanel:derive("GlobalSoundEffects_Menu")
GlobalSoundEffects_Panel.instance = nil

local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

--************************************************************************--
--** GlobalSoundEffects_Panel:new
--**
--************************************************************************--
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
	o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
	o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
	o.width = width
	o.height = height
	o.playerObj = playerObj
	o.moveWithMouse = true

	o.playButtonTex = getTexture("media/ui/GSE_play_button.png")
	o.playButtonPadX = 5
	o.playButtonWidth = o.playButtonTex and o.playButtonTex:getWidth() or 13

	o.isSoundGlobal = true

	o.selectX = square:getX()
	o.selectY = square:getY()
	o.selectZ = square:getZ()
	-- Epicenter selection is opt-in; don't add markers until enabled.
	o.useEpicenter = false

	return o
end

function GlobalSoundEffects_Panel:initialise()
	ISPanel.initialise(self)
	local btnWid = 80
	local btnHgt = FONT_HGT_LARGE + 2

	local y = 10 + FONT_HGT_LARGE + 10

	-- Category dropdown (list 1)
	_, self.categoryLbl = ISDebugUtils.addLabel(self, "CategoryLbl", 10, y, "Category", UIFont.Small, true)
	self.categoryCombo =
		ISComboBox:new(85, y - 2, self.width - 95, 20, self, GlobalSoundEffects_Panel.onCategoryChanged)
	self.categoryCombo:initialise()
	self:addChild(self.categoryCombo)
	for _, cat in ipairs(GSE_Config.getCategoriesSorted()) do
		self.categoryCombo:addOption(cat)
	end
	self.categoryCombo.selected = 1
	y = y + 30

	_, self.volumeSliderTitle = ISDebugUtils.addLabel(self, "Volume", 10, y, "Volume", UIFont.Small, true)
	_, self.volumeSliderLabel = ISDebugUtils.addLabel(self, "Volume", 80, y, "1", UIFont.Small, false)
	_, self.volumeSlider =
		ISDebugUtils.addSlider(self, "Volume", 85, y, 150, 20, GlobalSoundEffects_Panel.onSliderChange)
	self.volumeSlider.pretext = "Volume: "
	self.volumeSlider.valueLabel = self.volumeSliderLabel
	self.volumeSlider:setValues(0, 5, 0.05, 0.05, true)
	self.volumeSlider.currentValue = 1.0
	y = y + 40

	-- Epicenter toggle (must be enabled before picking square/radius is used)
	self.epicenterTick = ISTickBox:new(10, y - 5, 200, 20, "", self, GlobalSoundEffects_Panel.onEpicenterToggle)
	self.epicenterTick:initialise()
	self:addChild(self.epicenterTick)
	self.epicenterTick:addOption("Use Epicenter")
	self.epicenterTick.selected[1] = false

	self.radiusNbrLbl = ISLabel:new(10, y + 15, 10, "Radius", 1, 1, 1, 1, UIFont.Small, true)
	self:addChild(self.radiusNbrLbl)

	self.boolOptions = ISTickBox:new(
		self.width - (btnWid + 20),
		y - 5,
		200,
		20,
		"",
		self,
		GlobalSoundEffects_Panel.onBoolOptionsChange
	)
	self.boolOptions:initialise()
	self:addChild(self.boolOptions)
	self.boolOptions:addOption("Make Global")
	self.boolOptions.selected[1] = true
	self.boolOptions:addOption("Loop")
	self.boolOptions.selected[2] = false
	self.boolOptions:addOption("Queue")
	self.boolOptions.selected[3] = false

	y = y + 30

	self.radiusNbr = ISTextEntryBox:new("1", self.radiusNbrLbl.x, y, 100, 20)
	self.radiusNbr:initialise()
	self.radiusNbr:instantiate()
	self.radiusNbr:setOnlyNumbers(true)
	self:addChild(self.radiusNbr)

	self.pickNewSq = ISButton:new(
		self.width - (btnWid + 20),
		y,
		btnWid,
		20,
		"Pick new square",
		self,
		GlobalSoundEffects_Panel.onSelectNewSquare
	)
	self.pickNewSq.anchorTop = false
	self.pickNewSq.anchorBottom = true
	self.pickNewSq:initialise()
	self.pickNewSq:instantiate()
	self.pickNewSq.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
	self:addChild(self.pickNewSq)
	y = y + 30

	-- Sounds list
	local bottomButtonsH = (5 + btnHgt + 5)
	local queueListH = 90
	local soundsListH = self.height - bottomButtonsH - y - queueListH - 10
	self.titlesList = ISScrollingListBox:new(10, y, self.width - 20, soundsListH)
	self.titlesList:initialise()
	self.titlesList:instantiate()
	self.titlesList.itemheight = FONT_HGT_LARGE + 2 * 2
	self.titlesList.selected = 0
	self.titlesList.joypadParent = self
	self.titlesList.font = UIFont.NewSmall
	self.titlesList.doDrawItem = self.doDrawListItem
	self.titlesList.onMouseDown = self.onMouseDown_List
	self.titlesList.drawBorder = true
	self:addChild(self.titlesList)

	-- Queue list (visual feedback for queued sounds)
	self.queueLbl =
		ISLabel:new(10, self.titlesList.y + self.titlesList.height + 5, 10, "Queue", 1, 1, 1, 1, UIFont.Small, true)
	self:addChild(self.queueLbl)

	self.queueList = ISScrollingListBox:new(10, self.queueLbl.y + 15, self.width - 20, queueListH - 15)
	self.queueList:initialise()
	self.queueList:instantiate()
	self.queueList.itemheight = FONT_HGT_LARGE + 2
	self.queueList.font = UIFont.NewSmall
	self.queueList.drawBorder = true
	self:addChild(self.queueList)

	self.stopBtn = ISButton:new(
		self.titlesList.x,
		self.queueList.y + self.queueList.height + 5,
		btnWid,
		btnHgt,
		getText("UI_btn_stop"),
		self,
		GlobalSoundEffects_Panel.onClick
	)
	self.stopBtn.internal = "STOP"
	self.stopBtn.anchorTop = false
	self.stopBtn.anchorBottom = true
	self.stopBtn:initialise()
	self.stopBtn:instantiate()
	self.stopBtn.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.9 }
	self:addChild(self.stopBtn)

	self.closeBtn = ISButton:new(
		self.titlesList.x + self.titlesList.width - btnWid,
		self.queueList.y + self.queueList.height + 5,
		btnWid,
		btnHgt,
		getText("UI_btn_close"),
		self,
		GlobalSoundEffects_Panel.onClick
	)
	self.closeBtn.internal = "CLOSE"
	self.closeBtn.anchorTop = false
	self.closeBtn.anchorBottom = true
	self.closeBtn:initialise()
	self.closeBtn:instantiate()
	self.closeBtn.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.9 }
	self:addChild(self.closeBtn)

	self:populateList()
	self:refreshQueueList()
	self:updateEpicenterControls()
end

function GlobalSoundEffects_Panel:onBoolOptionsChange(index, selected)
	if index == 1 then
		if selected then
			self.isSoundGlobal = true
		else
			self.isSoundGlobal = false
		end
	end
	-- Queue toggle: turning it off clears any existing queue and disables visuals.
	if index == 3 and (selected == false) then
		GSE_AudioEngine.clearQueue()
		self:refreshQueueList()
	end
end

function GlobalSoundEffects_Panel:onCategoryChanged()
	self:populateList()
end

function GlobalSoundEffects_Panel:onEpicenterToggle(index, selected)
	if index ~= 1 then
		return
	end
	self.useEpicenter = selected == true
	if not self.useEpicenter then
		self:removeMarker()
	end
	self:updateEpicenterControls()
end

function GlobalSoundEffects_Panel:updateEpicenterControls()
	local enabled = self.useEpicenter == true
	if self.radiusNbrLbl then
		self.radiusNbrLbl:setVisible(enabled)
	end
	if self.radiusNbr then
		self.radiusNbr:setVisible(enabled)
	end
	if self.pickNewSq then
		self.pickNewSq:setVisible(enabled)
	end
end

function GlobalSoundEffects_Panel:addMarker(square, radius)
	self.marker = getWorldMarkers():addGridSquareMarker(square, 0.0, 0.45, 1.0, true, radius)
	self.marker:setScaleCircleTexture(true)
	local texName = nil
	self.arrow = getWorldMarkers():addDirectionArrow(
		self.playerObj,
		self.selectX,
		self.selectY,
		self.selectZ,
		texName,
		0.0,
		0.45,
		1.0,
		1.0
	)
end

function GlobalSoundEffects_Panel:onSliderChange(newval, slider)
	if slider.valueLabel then
		slider.valueLabel:setName(GlobalSoundEffects_Panel:printAndRound(newval, 3))
	end
end

function GlobalSoundEffects_Panel:printAndRound(v, d)
	local mult = 10 ^ (d or 0)
	return tostring(math.floor(v * mult + 0.5) / mult)
end

function GlobalSoundEffects_Panel:onCommand(effect, command)
	if command == "PLAYSFX" then
		if self.playerObj == getPlayer() then
			local args = {
				cmd = (effect == "GSE_stop") and "stop" or "play",
				sound = effect,
				volume = self.volumeSlider:getCurrentValue(),
				soundGlobal = self.isSoundGlobal,
				loop = self.boolOptions.selected[2] == true,
				queue = (self.boolOptions.selected[3] == true) and "enqueue" or nil,
				-- Epicenter/radius are optional and only sent when enabled.
				x = self.useEpicenter and self.selectX or nil,
				y = self.useEpicenter and self.selectY or nil,
				z = self.useEpicenter and self.selectZ or nil,
				radius = self.useEpicenter and (self:getRadius() + 1) or nil,
			}

			if isClient() then
				sendClientCommand(getPlayer(), "GlobalSoundEffects", "SendAudio", args)
			else
				-- SP: bypass server and play locally using the same payload shape.
				GlobalSoundEffects.ReceiveAudio(args)
			end
		end
	end
end

function GlobalSoundEffects_Panel:onClick(button)
	if button.internal == "CLOSE" then
		self:close()
	elseif button.internal == "STOP" then
		self:onCommand("GSE_stop", "PLAYSFX")
	end
end

function GlobalSoundEffects_Panel:populateList()
	self.titlesList:clear()
	local category = self.categoryCombo and self.categoryCombo:getOptionText(self.categoryCombo.selected)
		or GSE_Config.DEFAULT_CATEGORY
	local titles = GSE_Config.getSoundsForCategory(category)
	for _, title in ipairs(titles) do
		self.titlesList:addItem(getText("IGUI_" .. title), title)
	end
end

function GlobalSoundEffects_Panel:refreshQueueList()
	if not self.queueList then
		return
	end
	self.queueList:clear()

	local q = GSE_AudioEngine.getQueue()
	if not q then
		return
	end
	for i = 1, #q do
		local soundName = q[i] and q[i].sound or "?"
		self.queueList:addItem(tostring(i) .. ". " .. getText("IGUI_" .. tostring(soundName)), soundName)
	end
end

function GlobalSoundEffects_Panel:getPlayButtonX()
	local scrollBarWid = self.titlesList:isVScrollBarVisible() and 13 or 0
	return self.titlesList:getWidth() - scrollBarWid - self.playButtonPadX - self.playButtonWidth - self.playButtonPadX
end

function GlobalSoundEffects_Panel:isMouseOverFavorite(x)
	return (x >= self:getPlayButtonX()) and not self.titlesList:isMouseOverScrollBar()
end

function GlobalSoundEffects_Panel:doDrawListItem(y, item, alt)
	local fontHeight = getTextManager():getFontHeight(self.font)

	local a = 0.9
	self:drawRectBorder(
		0,
		y,
		self:getWidth(),
		self.itemheight - 1,
		a,
		self.borderColor.r,
		self.borderColor.g,
		self.borderColor.b
	)
	if self.selected == item.index then
		self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
	end
	self:drawText(item.text, 10, y + (self.itemheight - fontHeight) / 2, 1, 1, 1, a, self.font)

	local GSEPanel = self.parent
	local playButton = GSEPanel.playButtonTex
	local playButtonAlpha = 0.5

	if item.index == self.mouseoverselected and not self:isMouseOverScrollBar() then
		if self:getMouseX() >= GSEPanel:getPlayButtonX() then
			playButtonAlpha = 1
		end
	end

	if playButton then
		self:drawTexture(
			playButton,
			GSEPanel:getPlayButtonX() + GSEPanel.playButtonPadX,
			y + (item.height / 2 - playButton:getHeight() / 2),
			playButtonAlpha,
			1,
			1,
			1
		)
	end

	return y + self.itemheight
end

function GlobalSoundEffects_Panel:onMouseDown_List(x, y)
	local row = self:rowAt(x, y)
	if row == -1 then
		return
	end
	if self.parent:isMouseOverFavorite(x) then
		self.parent:onCommand(self.items[row].item, "PLAYSFX")
	elseif not self:isMouseOverScrollBar() then
		self.selected = row
	end
end

function GlobalSoundEffects_Panel:prerender()
	local z = 10
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
	self:drawText(
		getText("IGUI_GlobalSoundEffects"),
		self.width / 2 - (getTextManager():MeasureStringX(UIFont.Large, getText("IGUI_GlobalSoundEffects")) / 2),
		z,
		1,
		1,
		1,
		1,
		UIFont.Large
	)
	-- Update marker size only when epicenter is enabled.
	if self.useEpicenter and self.marker then
		local radius = (self:getRadius() + 1)
		if self.marker:getSize() ~= radius then
			self.marker:setSize(radius)
		end
	end

	-- Keep queue list live.
	self:refreshQueueList()

	-- Disabled visuals when Queue is off.
	if self.queueList and (self.boolOptions.selected[3] ~= true) then
		self.queueList:setVisible(true)
		self:drawRect(self.queueList.x, self.queueList.y, self.queueList.width, self.queueList.height, 0.35, 0, 0, 0)
	end
end

function GlobalSoundEffects_Panel:onSelectNewSquare()
	self.cursor = ISSelectCursor:new(self.playerObj, self, self.onSquareSelected)
	getCell():setDrag(self.cursor, self.playerObj:getPlayerNum())
end

function GlobalSoundEffects_Panel:onSquareSelected(square)
	self.cursor = nil
	self:removeMarker()
	self.selectX = square:getX()
	self.selectY = square:getY()
	self.selectZ = square:getZ()
	self:addMarker(square, self:getRadius() + 1)
end

function GlobalSoundEffects_Panel:getRadius()
	local radius = self.radiusNbr:getInternalText()
	return (tonumber(radius) or 1) - 1
end

function GlobalSoundEffects_Panel:removeMarker()
	if self.marker then
		self.marker:remove()
		self.marker = nil
	end
	if self.arrow then
		self.arrow:remove()
		self.arrow = nil
	end
end

function GlobalSoundEffects_Panel:close()
	self:removeMarker()
	self:setVisible(false)
	self:removeFromUIManager()
	GlobalSoundEffects_Panel.instance = nil
end

function GlobalSoundEffects_Panel.openPanel(x, y, playerObj, square)
	if GlobalSoundEffects_Panel.instance == nil then
		local window = GlobalSoundEffects_Panel:new(x, y, 250, 400, playerObj, square)
		window:initialise()
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
	for i, v in ipairs(worldobjects) do
		square = v:getSquare()
		break
	end

	if hasAccess then
		local playerObj = getSpecificPlayer(player)
		local GSE_contextMenu = context:addOptionOnTop("Global Sound Effects Menu", worldobjects, function()
			local x = getCore():getScreenWidth() / 1.5
			local y = getCore():getScreenHeight() / 6
			GlobalSoundEffects_Panel.openPanel(x, y, playerObj, square)
		end)
		GSE_contextMenu.iconTexture = getTexture("media/ui/GSE_volume.png")
	end
end
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
