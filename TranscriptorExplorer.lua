--local addonName, Private = ...

local MinPanelWidth = 715
local MinPanelHeight = 210

--TranscriptExplorerDB = TranscriptExplorerDB or {}
--Private.db = TranscriptExplorerDB
--Private.tdb = TranscriptDB

local co
local coroutineFrame = CreateFrame("Frame")
coroutineFrame:Hide()

coroutineFrame:SetScript("OnUpdate", function()
	local start = debugprofilestop()
	while debugprofilestop() - start < 500 and coroutine.status(co) ~= "dead" do
		coroutine.resume(co)
	end
	if coroutine.status(co) == "dead" then
		coroutineFrame:Hide()
	end
end)

TranscriptorButtonBehaviorMixin = {}

function TranscriptorButtonBehaviorMixin:OnEnter()
	self.MouseoverOverlay:Show()
end

function TranscriptorButtonBehaviorMixin:OnLeave()
	self.MouseoverOverlay:Hide()
end

function TranscriptorButtonBehaviorMixin:SetAlternateOverlayShown(alternate)
	self.Alternate:SetShown(alternate)
end

TranscriptorScrollBoxButtonMixin = {}

function TranscriptorScrollBoxButtonMixin:Flash()
	self.FlashOverlay.Anim:Play()
end

TranscriptorExplorerPanelMixin = {}

function TranscriptorExplorerPanelMixin:OnLoad()
	ButtonFrameTemplate_HidePortrait(self)

	self.logDataProvider = CreateDataProvider()

	self.filterDataProvider = CreateDataProvider()
	self.filterDataProvider:SetSortComparator(function(lhs, rhs)
		return lhs.event < rhs.event
	end)
	--self.filterDataProvider:RegisterCallback(DataProviderMixin.Event.OnSizeChanged, self.OnFilterDataProviderChanged, self)

	self.idCounter = CreateCounter()

	self:InitializeSubtitleBar()
	self:InitializeLog()
	self:InitializeFilter()
	self:InitializeOptions()
	self.TitleBar:Init(self)
	self.ResizeButton:Init(self, MinPanelWidth, MinPanelHeight)
	self:SetTitle("Transcriptor Explorer")
	self.Log.Bar.Label:SetText("Log")
end

function TranscriptorExplorerPanelMixin:OnShow() end

function TranscriptorExplorerPanelMixin:OnHide() end

function TranscriptorExplorerPanelMixin:OnEvent() end

function TranscriptorExplorerPanelMixin:InitializeSubtitleBar()
	self.SubtitleBar.ViewLog.Label:SetText(EVENTTRACE_LOG_HEADER)
	self.SubtitleBar.ViewLog:SetScript("OnClick", function()
		self:ViewLog()
	end)

	self.SubtitleBar.ViewFilter.Label:SetText(EVENTTRACE_FILTER_HEADER)
	self.SubtitleBar.ViewFilter:SetScript("OnClick", function()
		self:ViewFilter()
	end)
end

function TranscriptorExplorerPanelMixin:ViewLog()
	self.Log:Show()
	self.Filter:Hide()
end

function TranscriptorExplorerPanelMixin:ViewFilter()
	--self.Log.Bar.SearchBox:SetText("")
	self.Log:Hide()
	self.Filter:Show()
end

function TranscriptorExplorerPanelMixin:LoadLog(logName, logData)
	-- logData.WIDGET => table
	-- logData.COMBAT => <><231.50 23:18:18> [event] .....
	-- logData.total => same
	-- logData.BigWigs => same
	-- logData.TIMERS
	-- logData.TIMERS.SPELL_CAST_START => guid = pull:x, x, x
	-- logData.TIMERS.SPELL_CAST_SUCCESS => guid = pull:x, x, x
	-- logData.TIMERS.UNIT_SPELLCAST_SUCCEEDED => guid = pull:x, x, x
	-- logData.TIMERS.SPELL_AURA_APPLIED => guid = pull:x, x, x
	-- logData.TIMERS.HIDDEN_AURAS => ???? todo
	-- logData.TIMERS.PLAYER_AURAS => ???
	-- logData.TIMERS.PLAYER_SPELLS => ???
	-- logData.MONSTER => <><231.50 23:18:18> [event] .....
	-- logData.UNIT_POWER_UPDATE => <><231.50 23:18:18> [event] .....
	-- logData.UNIT_SPELLCAST => <><231.50 23:18:18> [event] .....
	-- logData.WIDGET
	self:SetTitle(logName)
	self.logDataProvider:Flush()
	self.logData = logData
	self.Log:Show()
	self.Log.Events:Show()
	self:InitializeLogViewDropdown()
	self.Log.Bar.ViewDropdown:Show()
	--self:SelectLogView("total")
end

function TranscriptorExplorerPanelMixin:InitializeLogViewDropdown()
	UIDropDownMenu_Initialize(self.Log.Bar.ViewDropdown, function()
		local info = UIDropDownMenu_CreateInfo()
		info.func = function(option)
			self:SelectLogView(option.value)
		end
		for k in pairs(self.logData) do
			info.text = k
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info)
		end
	end)
end

function TranscriptorExplorerPanelMixin:SelectLogView(option)
	self.logDataProvider:Flush()
	if self.logData[option] then
		self.selectedview = option
		if not coroutineFrame:IsShown() then
			co = coroutine.create(function()
				local category = self.logData[option]
				for i = 1, #category do
					coroutine.yield()
					self:LogEvent(category, i)
				end
			end)
			coroutineFrame:Show()
		end
		UIDropDownMenu_SetSelectedName(self.Log.Bar.ViewDropdown, option)
	end
end

local function SetScrollBoxButtonAlternateState(scrollBox)
	local index = scrollBox:GetDataIndexBegin()
	scrollBox:ForEachFrame(function(button)
		button:SetAlternateOverlayShown(index % 2 == 1)
		index = index + 1
	end)
end

function TranscriptorExplorerPanelMixin:InitializeFilter()
	self.Filter.Bar.Label:SetText(EVENTTRACE_FILTER_HEADER)

	local function SetEventsEnabled(enabled)
		for index, elementData in self.filterDataProvider:Enumerate() do
			elementData.enabled = enabled
		end

		self.Filter.ScrollBox:ForEachFrame(function(button)
			button:UpdateEnabledState()
		end)
	end

	local function InitializeCheckButton(button, text, enable)
		button.Label:SetText(text)
		button:SetScript("OnClick", function(button, buttonName)
			SetEventsEnabled(enable)
		end)
	end

	InitializeCheckButton(self.Filter.Bar.CheckAllButton, EVENTTRACE_BUTTON_ENABLE_FILTERS, true)
	InitializeCheckButton(self.Filter.Bar.UncheckAllButton, EVENTTRACE_BUTTON_DISABLE_FILTERS, false)

	self.Filter.Bar.DiscardAllButton.Label:SetText(EVENTTRACE_BUTTON_DISCARD_FILTER)
	self.Filter.Bar.DiscardAllButton:SetScript("OnClick", function(button, buttonName)
		self.filterDataProvider:Flush()
	end)

	local function OnDataRangeChanged(sortPending)
		SetScrollBoxButtonAlternateState(self.Filter.ScrollBox)
	end
	self.Filter.ScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnDataRangeChanged, OnDataRangeChanged, self)

	local function RemoveEventFromFilter(elementData)
		self.filterDataProvider:Remove(elementData)
	end

	local view = CreateScrollBoxListLinearView()
	view:SetElementInitializer("TranscriptorFilterButtonTemplate", function(button, elementData)
		button:Init(elementData, RemoveEventFromFilter)
	end)

	local pad = 2
	local spacing = 2
	view:SetPadding(pad, pad, pad, pad, spacing)

	ScrollUtil.InitScrollBoxListWithScrollBar(self.Filter.ScrollBox, self.Filter.ScrollBar, view)

	self.Filter.ScrollBox:SetDataProvider(self.filterDataProvider)
end

function TranscriptorExplorerPanelMixin:InitializeOptions()
	local function Initializer(dropDown, level)
		for logName, logData in pairs(TranscriptDB) do
			local info = UIDropDownMenu_CreateInfo()
			info.notCheckable = true
			info.text = logName
			info.func = function()
				self:LoadLog(logName, logData)
			end
			UIDropDownMenu_AddButton(info)
		end
	end

	local dropDown = self.SubtitleBar.DropDown
	UIDropDownMenu_SetInitializeFunction(dropDown, Initializer)
	UIDropDownMenu_SetDisplayMode(dropDown, "MENU")

	self.SubtitleBar.OptionsDropDown.Text:SetText("Select Log")
	self.SubtitleBar.OptionsDropDown:SetScript("OnMouseDown", function(o, button)
		UIMenuButtonStretchMixin.OnMouseDown(self.SubtitleBar.OptionsDropDown, button)
		ToggleDropDownMenu(1, nil, dropDown, self.SubtitleBar.OptionsDropDown, 130, 20)
	end)
end

local function SetScrollBoxButtonAlternateState(scrollBox)
	local index = scrollBox:GetDataIndexBegin()
	scrollBox:ForEachFrame(function(button)
		button:SetAlternateOverlayShown(index % 2 == 1)
		index = index + 1
	end)
end

local function GetDisplayEvent(elementData)
	if elementData.subevent then
		return ("%s %s"):format(elementData.event, elementData.subevent)
	else
		return elementData.event
	end
end

function TranscriptorExplorerPanelMixin:InitializeLog()
	local function SetOnDataRangeChanged(scrollBox)
		local function OnDataRangeChanged(sortPending)
			SetScrollBoxButtonAlternateState(scrollBox)
		end
		scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnDataRangeChanged, OnDataRangeChanged, self)
	end

	SetOnDataRangeChanged(self.Log.Events.ScrollBox)

	local function AddEventToFilter(scrollBox, elementData)
		local predicateFn = function(filterData)
			return (filterData.event == elementData.event)
				and (filterData.event ~= "CLEU" or filterData.subevent == elementData.subevent)
		end
		local found = self.filterDataProvider:FindElementDataByPredicate(predicateFn)
		if found then
			found.enabled = true

			local button = scrollBox:FindFrame(elementData)
			if button then
				button:UpdateEnabledState()
			end
		else
			self.filterDataProvider:Insert({
				event = elementData.event,
				subevent = elementData.subevent,
				displayEvent = GetDisplayEvent(elementData),
				predicateFn = predicateFn,
				enabled = true,
			})
		end
		self:RemoveEventFromDataProvider(self.logDataProvider, predicateFn)
		--self:RemoveEventFromDataProvider(self.searchDataProvider, elementData.event)
	end

	do
		local view = CreateScrollBoxListLinearView()
		view:SetElementFactory(function(factory, elementData)
			factory("TranscriptorLogEventButtonTemplate", function(button, elementData)
				button:Init(elementData)

				button.HideButton:SetScript("OnMouseDown", function(button, buttonName)
					AddEventToFilter(self.Filter.ScrollBox, elementData)
				end)

				--[[
				button:SetScript("OnClick", function(button, buttonName)
					if buttonName == "RightButton" then
						CopyToClipboard(elementData.line) -- protected :(
					end
				end)
				]]
			end)
		end)

		local pad = 2
		local spacing = 2
		view:SetPadding(pad, pad, pad, pad, spacing)

		ScrollUtil.InitScrollBoxListWithScrollBar(self.Log.Events.ScrollBox, self.Log.Events.ScrollBar, view)

		self.Log.Events.ScrollBox:SetDataProvider(self.logDataProvider)
	end
end

local function splitargs(args)
	local fake, real = args:match("Fake Args:(.+)Real Args:(.*)$")
	if fake and #fake > 0 then
		return strsplit("#", fake)
	elseif real and #real > 0 then
		return strsplit("#", real)
	else
		return strsplit("#", args)
	end
end

function TranscriptorExplorerPanelMixin:LogEvent(category, index)
	local timeSpent, time, event, args = category[index]:match("^<([0-9%.]+) ([0-9:]+)> %[(.+)%] (.+)$")
	local splitedargs = { splitargs(args) }
	local subevent = splitedargs[1]
	if event == "CLEU" then
		if splitedargs then
			-- skip CLEU with source = player
			if splitedargs[2]:sub(1, 6) == "Player" then
				return
			end
			-- skip periodic damage on player
			if subevent:sub(1, 14) == "SPELL_PERIODIC" and splitedargs[4]:sub(1, 6) == "Player" then
				return
			end
		end
	-- skip play spells
	elseif event:sub(1, 15) == "UNIT_SPELLCAST_" and subevent:sub(1, 12) == "PLAYER_SPELL" then
		return
	end
	local elementData = {
		id = self.idCounter(),
		event = event,
		subevent = event == "CLEU" and subevent or nil,
		args = splitedargs,
		timeSpent = timeSpent,
		time = time,
		line = category[index],
	}
	for _, data in self.filterDataProvider:Enumerate() do
		if data.predicateFn(elementData) then
			return
		end
	end
	self.logDataProvider:Insert(elementData)
end

function TranscriptorExplorerPanelMixin:RemoveEventFromDataProvider(dataProvider, predicateFn)
	local index = dataProvider:GetSize()
	while index >= 1 do
		local elementData = dataProvider:Find(index)
		if predicateFn(elementData) then
			dataProvider:RemoveIndex(index)
		end
		index = index - 1
	end
end

local function FormatLine(id, message)
	return string.format("%s %s", id, message)
end

TranscriptorLogEventButtonMixin = {}

function TranscriptorLogEventButtonMixin:OnLoad()
	self.HideButton:ClearAllPoints()
	self.HideButton:SetPoint("LEFT", self, "LEFT", 3, 0)
end

local ArgumentColors = {
	["string"] = GREEN_FONT_COLOR,
	["number"] = ORANGE_FONT_COLOR,
	["boolean"] = BRIGHTBLUE_FONT_COLOR,
	["table"] = LIGHTYELLOW_FONT_COLOR,
	["nil"] = GRAY_FONT_COLOR,
}

local function GetArgumentColor(arg)
	return ArgumentColors[type(arg)] or HIGHLIGHT_FONT_COLOR
end

local function FormatArgument(arg)
	local color = GetArgumentColor(arg)
	local t = type(arg)
	if t == "string" then
		return color:WrapTextInColorCode(string.format('"%s"', arg))
	elseif t == "nil" then
		return color:WrapTextInColorCode(t)
	end
	return color:WrapTextInColorCode(tostring(arg))
end

local function FormatLogID(id)
	return GRAY_FONT_COLOR:WrapTextInColorCode(("[%.3d]"):format(id))
end

local function AddLineArguments(args)
	local words = {}
	for _, arg in ipairs(args) do
		local number = tonumber(arg)
		if number then
			arg = number
		elseif arg == "nil" then
			arg = nil
		elseif arg == "true" then
			arg = true
		elseif arg == "false" then
			arg = false
		end
		table.insert(words, FormatArgument(arg))
	end

	local wordCount = #words
	if wordCount == 0 then
		return ""
	elseif wordCount == 1 then
		return words[1]
	end
	return table.concat(words, ", ")
end

local eventToSpellIDArg = {
	CLEU = 6,
	BigWigs_StartBar = 2,
	BigWigs_Message = 2,
	UNIT_SPELLCAST_SUCCEEDED = function(args)
		local line = args[1]
		local spellID = line:match("%[%[.-([^:]+)]%]")
		return tonumber(spellID)
	end,
	UNIT_SPELLCAST_START = function(args)
		local line = args[1]
		local spellID = line:match("%[%[.-([^:]+)]%]")
		return tonumber(spellID)
	end,
	UNIT_SPELLCAST_STOP = function(args)
		local line = args[1]
		local spellID = line:match("%[%[.-([^:]+)]%]")
		return tonumber(spellID)
	end,
}

local function AddSpellID(event, args)
	local ret = eventToSpellIDArg[event]
	if type(ret) == "number" then
		local spellID = args[ret]
		return tonumber(spellID)
	elseif type(ret) == "function" then
		return ret(args)
	end
end

function TranscriptorLogEventButtonMixin:Init(elementData)
	local id = FormatLogID(elementData.id)
	local lineWithoutArguments = FormatLine(id, elementData.event)

	local arguments = AddLineArguments(elementData.args)
	local spellID = AddSpellID(elementData.event, elementData.args)
	if spellID then
		self.Icon.IconTexture:SetTexture(GetSpellTexture(spellID))
		self.Icon.spellID = spellID
		self.Icon:Show()
	else
		self.Icon.spellID = nil
		self.Icon:Hide()
	end
	local formattedArguments = GREEN_FONT_COLOR:WrapTextInColorCode(arguments)
	self.LeftLabel:SetText(("%s %s"):format(lineWithoutArguments, formattedArguments))

	local formattedTimestamp = ("%s %s"):format(elementData.timeSpent, elementData.time)
	self.RightLabel:SetText(GRAY_FONT_COLOR:WrapTextInColorCode(formattedTimestamp))
end

TranscriptorFilterButtonMixin = {}

function TranscriptorFilterButtonMixin:Init(elementData, hideCb)
	self.Label:SetText(GetDisplayEvent(elementData))

	self:UpdateEnabledState()

	self.HideButton:SetScript("OnMouseDown", function(button, buttonName)
		hideCb(elementData)
	end)

	self.CheckButton:SetScript("OnClick", function(button, buttonName)
		self:ToggleEnabledState()
	end)
end

function TranscriptorFilterButtonMixin:UpdateEnabledState()
	local elementData = self:GetElementData()
	self.CheckButton:SetChecked(elementData.enabled)
	self:SetAlpha(elementData.enabled and 1 or 0.7)
	self:DesaturateHierarchy(elementData.enabled and 0 or 1)
end

function TranscriptorFilterButtonMixin:OnDoubleClick()
	self:ToggleEnabledState()
end

function TranscriptorFilterButtonMixin:ToggleEnabledState()
	local elementData = self:GetElementData()
	elementData.enabled = not elementData.enabled
	self:UpdateEnabledState()
end
