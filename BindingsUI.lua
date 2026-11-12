-- UbermocForever: controller binding UI inside the Settings panel.
--
-- Rows are real elements of the addon's own vertical settings layout, so they
-- scroll, search and lay out exactly like stock options. Each row hosts a
-- button built from Blizzard's native CustomBindingButtonTemplate through
-- CustomBindingManager/RegisterHandlerAndCreateButton - the sanctioned path
-- for an addon-owned binding UI (see the comment at the top of
-- CustomBindingButtonMixin.lua). Nothing here draws custom chrome: the button
-- art, fonts and selection highlight are all stock.
--
-- Captured input arrives through the manager's completion callback as a list
-- of raw key tokens; we keep PAD* tokens only (chords joined with "-") and
-- apply them via the existing override-binding engine in Bindings.lua.

local ADDON, ns = ...

-- Our own custom binding type. Blizzard ships exactly one registered type
-- (voice push-to-talk), so a private numeric id keeps our pending-binds and
-- handlers separate from voice chat's.
ns.customBindingType = 100

local CUSTOM_BINDING_TYPE = ns.customBindingType
local ROW_EXTENT = 26

-- actionID -> its native binding button (owned by CustomBindingManager)
local rowButtons = {}
-- actionID currently listening for input, if any
local capturingActionID = nil
-- the layout our rows were added to, if any
local bindingLayout = nil
-- initializer of the "Controller Bindings" header row
local sectionHeaderInitializer = nil

local function GetActionName(actionID)
	local action = ns.actionByID[actionID]
	return action and action.name or actionID
end

-- True while the addon's settings page is what the panel is showing. Used to
-- keep our hint/status text off other pages (Blizzard clears OutputText when
-- the category changes, so we only need to guard ours).
local function IsBindingPageActive()
	if not SettingsPanel or not ns.settingsCategory then
		return false
	end
	local current = SettingsPanel:GetCurrentCategory()
	return current == ns.settingsCategory
end

------------------------------------------------------------------------
-- Localized strings (kept here so the page reads like the rest of the UI)
------------------------------------------------------------------------

local L = {
	BINDINGS_HEADER = "Controller Bindings",
	CAPTURE_FOR = "Press a controller button for %s",
	UNBIND_HINT = "Right-click a binding to clear it.",
	BOUND_TO = "Bound %s (%s).",
	CLEARED = "Cleared the binding for %s.",
	NOT_CONTROLLER = "That is not a controller button; press a button on your controller instead.",
}
ns.L = L

------------------------------------------------------------------------
-- Storage helpers (db.bindings lives in Bindings.lua)
------------------------------------------------------------------------

function ns:SetActionBinding(actionID, binding)
	if not ns.actionByID[actionID] then
		return false
	end

	local bindings = ns.db.bindings
	for _, action in ipairs(ns.ACTIONS) do
		if action.id ~= actionID and bindings[action.id] == binding then
			bindings[action.id] = nil
		end
	end

	if binding then
		bindings[actionID] = binding
	else
		bindings[actionID] = nil
	end

	ns:ApplyBindings()
	self:RefreshBindingRows()
	return true
end

function ns:GetActionBinding(actionID)
	return ns.db.bindings and ns.db.bindings[actionID]
end

-- Turns a stored token ("PAD1" or "PADLSHOULDER-PAD1") into the icon markup
-- for the connected device's label style.
function ns:FormatBindingText(binding)
	if not binding then
		return nil
	end
	return (binding:gsub("[A-Z0-9_]+", function(token)
		if token:find("^PAD") then
			return self:GetButtonLabel(token, true) or token
		end
		return token
	end))
end

function ns:GetBindingDisplayText(actionID)
	local text = self:FormatBindingText(self:GetActionBinding(actionID))
	if not text then
		return GRAY_FONT_COLOR:WrapTextInColorCode(NOT_BOUND), false
	end
	return text, true
end

------------------------------------------------------------------------
-- Native binding buttons (CustomBindingManager + our handlers)
------------------------------------------------------------------------

local buttonHost = nil

-- Parked parent for binding buttons whose row is scrolled out of view. The
-- buttons stay registered in CustomBindingManager (so their pending-bind
-- text updates keep working) but hidden inside a 1x1 frame.
local function GetButtonHost()
	if not buttonHost then
		local parent = SettingsPanel or UIParent
		buttonHost = CreateFrame("Frame", nil, parent)
		buttonHost:SetSize(1, 1)
		buttonHost:Hide()
	end
	return buttonHost
end

local function UpdateButtonText(button, actionID)
	local text, bound = ns:GetBindingDisplayText(actionID)
	button:SetText(text)
	if bound then
		button:SetAlpha(1)
	else
		button:SetAlpha(0.8)
	end
end

-- One handler per action: the manager hands captured keys to whichever
-- button is listening, and each handler knows which action it belongs to.
local function GetActionButton(actionID)
	local button = rowButtons[actionID]
	if button then
		return button
	end

	local host = GetButtonHost()
	if not host then
		return nil
	end

	local handler = CustomBindingHandler:CreateHandler(CUSTOM_BINDING_TYPE)

	handler:SetOnBindingModeActivatedCallback(function(isActive)
		capturingActionID = isActive and actionID or nil

		if SettingsPanel and SettingsPanel.SearchBox then
			SettingsPanel.SearchBox:SetShown(not isActive)
		end

		ns:RefreshCaptureHint()
		ns:UpdatePanelOutputText()
	end)

	handler:SetOnBindingCompletedCallback(function(completedSuccessfully, keys)
		if not completedSuccessfully or type(keys) ~= "table" then
			return
		end

		local padKeys = {}
		for _, key in ipairs(keys) do
			if type(key) == "string" and key:find("^PAD") then
				table.insert(padKeys, key)
			end
		end

		if #padKeys == 0 then
			ns:Print(L.NOT_CONTROLLER)
			return
		end

		local binding = table.concat(padKeys, "-")
		ns:SetActionBinding(actionID, binding)
		ns:Print((L.BOUND_TO):format(GetActionName(actionID), ns:FormatBindingText(binding)))
	end)

	button = CustomBindingManager:RegisterHandlerAndCreateButton(handler, "CustomBindingButtonTemplate", host)
	rowButtons[actionID] = button
	return button
end

function ns:ReleaseBindingButtons()
	for actionID, button in pairs(rowButtons) do
		if button:IsSelected() then
			button:CancelBinding()
		end
		CustomBindingManager:SetHandlerRegistered(button, false)
		button:SetParent(nil)
		button:ClearAllPoints()
		button:Hide()
	end
	rowButtons = {}
end

------------------------------------------------------------------------
-- Row initializer (a settings-list element, like Blizzard's own rows)
------------------------------------------------------------------------

function ns:CreateBindingRowInitializer(action)
	local data = {
		name = action.id,
		actionID = action.id,
		label = action.name,
	}

	local initializer = Settings.CreateElementInitializer("UbermocForeverBindingRowTemplate", data)

	initializer.GetExtent = function() return ROW_EXTENT end

	-- Also match the button token currently bound to the row (same
	-- augmentation pattern Blizzard uses in CreateKeybindingEntryInitializer).
	local oldMatchesSearchTags = initializer.MatchesSearchTags

	initializer.MatchesSearchTags = function(self, words)
		local result = oldMatchesSearchTags(self, words)
		if result then
			return result
		end

		local binding = ns:GetActionBinding(self.data.actionID)
		if not binding then
			return nil
		end

		for _, word in ipairs(words) do
			local first, last = string.find(binding:upper(), word:upper(), nil, true)
			if first and last then
				return last - first
			end
		end
		return nil
	end

	return initializer
end

------------------------------------------------------------------------
-- Row frame mixin (template: UbermocForeverBindingUI.xml)
------------------------------------------------------------------------

-- Gamepad cursor routing. The SmartNavigation helpers are globals from
-- Blizzard's own gamepad-navigation package (defined in
-- Blizzard_GamepadSmartNavigation/Utility.lua, used by the keybinds window at
-- KeyBindingFrameBindingTemplateMixin:Init in Blizzard_Keybindings.lua). They
-- are not part of the documented API index, so reach them through _G and skip
-- quietly if a client build ever drops them.
local function AddRowNavigation(row, button)
	local markFocusable = _G.SmartNavigation_MarkFrameFocusable
	local setCursorAnchor = _G.SmartNavigation_SetCustomCursorAnchorPointForFrame
	local addBidirectional = _G.SmartNavigation_AddBidirectionalJumpNavigationOverride
	local addIgnoreInput = _G.SmartNavigation_AddIgnoreInputNavigationOverride
	local addJumpOverride = _G.SmartNavigation_AddJumpNavigationOverride
	if not (markFocusable and setCursorAnchor and addBidirectional and addIgnoreInput and addJumpOverride) then
		return
	end

	local function SetNavigateCallback(direction)
		addJumpOverride(button, direction, function()
			local next = SmartNavigation:GetButtonInfoInDirection(row, direction)
			return next and next.button
		end)
	end

	markFocusable(row)
	-- The cursor anchor is a plain data table (AnchorUtil's CreateAnchor just
	-- builds {point, relativeTo, relativePoint, x, y}); built inline so the
	-- call stays obvious and lint-checkable.
	setCursorAnchor(row, { point = "RIGHT", relativeTo = row, relativePoint = "LEFT", x = 30, y = 0 })
	addBidirectional(row, SMART_NAV_INPUT_DIRECTION.RIGHT, button)
	addIgnoreInput(button, SMART_NAV_INPUT_DIRECTION.RIGHT)
	SetNavigateCallback(SMART_NAV_INPUT_DIRECTION.UP)
	SetNavigateCallback(SMART_NAV_INPUT_DIRECTION.DOWN)
end

UbermocForeverBindingRowMixin = {}

function UbermocForeverBindingRowMixin:Init(initializer)
	self.actionID = initializer.data.actionID

	self.Text:SetText(initializer.data.label)
	self.Text:SetPoint("LEFT", self, "LEFT", 10, 0)

	-- While a binding is being captured the settings list raises an input
	-- blocker; Blizzard's keybind rows reparent their buttons into it so the
	-- button stays visible and clickable. Same trick, same events.
	self.cbrHandles = Settings.CreateCallbackHandleContainer()
	self.cbrHandles:RegisterCallback(EventRegistry, "Settings.ReparentBindingsToInputBlocker",
		self.ReparentButtonToInputBlocker, self)
	self.cbrHandles:RegisterCallback(EventRegistry, "Settings.UnparentBindingsToInputBlocker",
		self.UnparentButtonFromInputBlocker, self)

	local button = GetActionButton(self.actionID)
	if button then
		self.button = button
		CustomBindingManager:SetHandlerRegistered(button, true)
		button:SetParent(self.Button)
		button:ClearAllPoints()
		button:SetPoint("LEFT", self.Button, "LEFT")
		button:SetPoint("RIGHT", self.Button, "RIGHT")
		self:UpdateButtonWidth()
		UpdateButtonText(button, self.actionID)
		AddRowNavigation(self, button)
		button:Show()
	end
end

function UbermocForeverBindingRowMixin:ReparentButtonToInputBlocker(inputBlocker)
	local button = self.button
	if not button or not inputBlocker or not self:IsShown() then
		return
	end
	button:SetParent(inputBlocker)
end

function UbermocForeverBindingRowMixin:UnparentButtonFromInputBlocker()
	local button = self.button
	if not button then
		return
	end
	button:SetParent(self.Button)
	self:UpdateButtonWidth()
end

function UbermocForeverBindingRowMixin:UpdateButtonWidth()
	local button = self.button
	if not button then
		return
	end
	local width = self.Button:GetWidth()
	if button.selectedHighlight and width > 20 then
		button.selectedHighlight:SetWidth(width - 8)
	end
end

function UbermocForeverBindingRowMixin:Release()
	if self.cbrHandles then
		self.cbrHandles:Unregister()
		self.cbrHandles = nil
	end

	local button = self.button
	if button then
		if button:IsSelected() then
			button:CancelBinding()
		end
		CustomBindingManager:SetHandlerRegistered(button, false)
		local host = GetButtonHost()
		if host then
			button:SetParent(host)
		else
			button:SetParent(nil)
		end
		button:ClearAllPoints()
		button:Hide()
		self.button = nil
	end

	self.actionID = nil
end

function UbermocForeverBindingRowMixin:OnMouseUp(buttonName)
	if buttonName ~= "RightButton" then
		return
	end
	local actionID = self.actionID
	if not actionID then
		return
	end
	ns:SetActionBinding(actionID, nil)
	ns:Print((L.CLEARED):format(GetActionName(actionID)))
end

------------------------------------------------------------------------
-- Building the section inside the addon's settings layout
------------------------------------------------------------------------

-- Appends "Controller Bindings" (header + one row per action) to the
-- vertical layout of the addon's settings category. Called by Options.lua
-- right after the regular options, so the whole page stays in one list and
-- the rows scroll and search like stock options.
function ns:AppendBindingSectionToLayout(layout)
	if not layout or bindingLayout then
		return
	end

	bindingLayout = layout

	-- Native section header (Blizzard's own factory, Blizzard_SettingControls).
	-- Not in the API index, so reach it through _G and skip the header if a
	-- build ever drops it - the rows themselves would still work.
	local createSectionHeader = _G.CreateSettingsListSectionHeaderInitializer
	if createSectionHeader then
		sectionHeaderInitializer = createSectionHeader(L.BINDINGS_HEADER)
		-- The header's own name doubles as the scroll target for the Esc-menu
		-- "Ubermoc Keybinds" button (SettingsPanel scrolls by element data name).
		sectionHeaderInitializer.data.name = L.BINDINGS_HEADER
		layout:AddMirroredInitializer(sectionHeaderInitializer)
	end

	for _, action in ipairs(ns.ACTIONS) do
		layout:AddMirroredInitializer(self:CreateBindingRowInitializer(action))
	end
end

function ns:GetBindingScrollTargetName()
	return L.BINDINGS_HEADER
end

function ns:RefreshBindingRows()
	for actionID, button in pairs(rowButtons) do
		UpdateButtonText(button, actionID)
	end
	self:RefreshCaptureHint()
end

------------------------------------------------------------------------
-- Capture hint line (bottom of the settings list, only while our page shows)
------------------------------------------------------------------------

local hintText = nil

-- The small hint line under the rows ("right-click to clear" / capture
-- prompt), parented to the settings list itself and shown only while our
-- category is displayed. Kept inside the ScrollBox's child frame so it sits
-- in the same column as the rows (the list has 25px of left padding).
function ns:BuildBindingPageExtras(list)
	if hintText then
		return
	end

	local parent = list.ScrollBox or list

	hintText = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hintText:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 30, 12)
	self.hintText = hintText

	-- The list fires OnSettingsUpdated every time it displays a category,
	-- which is when we toggle the hint on/off and set its text.
	if list.RegisterCallback then
		list:RegisterCallback(SettingsListMixin.Event.OnSettingsUpdated, ns.RefreshBindingPageExtras, ns)
	end
	self:RefreshBindingPageExtras()
end

function ns:RefreshBindingPageExtras()
	local active = IsBindingPageActive()
	if hintText then
		hintText:SetShown(active)
	end
	if active then
		self:RefreshCaptureHint()
	end
end

function ns:RefreshCaptureHint()
	if not hintText or not hintText:IsShown() then
		return
	end

	if capturingActionID then
		hintText:SetText((L.CAPTURE_FOR):format(GetActionName(capturingActionID)))
	else
		hintText:SetText(L.UNBIND_HINT)
	end
end

-- The panel's bottom OutputText line is Blizzard's own status spot (the key
-- binding page writes its "press a key..." prompt there). While one of our
-- rows is capturing, show our equivalent prompt; when capture ends, clear it
-- the same way Blizzard does.
function ns:UpdatePanelOutputText()
	if not SettingsPanel or not SettingsPanel.SetOutputText then
		return
	end

	if capturingActionID and IsBindingPageActive() then
		local cancelKey = (GetBindingText and GetBindingText("ESCAPE")) or "Escape"
		SettingsPanel:SetOutputText((L.CAPTURE_FOR):format(GetActionName(capturingActionID))
			.. " (" .. cancelKey .. ")")
	else
		SettingsPanel:ClearOutputText()
	end
end

ns:RegisterEvent("GAME_PAD_CONNECTED", function()
	ns:RefreshBindingRows()
end)
ns:RegisterEvent("GAME_PAD_DISCONNECTED", function()
	ns:RefreshBindingRows()
end)
ns:RegisterEvent("GAME_PAD_ACTIVE_CHANGED", function()
	ns:RefreshBindingRows()
end)

------------------------------------------------------------------------
-- Slash command extension: /ubermoc bind <ACTION> <PADTOKEN...>
------------------------------------------------------------------------

ns.SlashSubcommands = ns.SlashSubcommands or {}

ns.SlashSubcommands["bind"] = function(args)
	local actionID, tokens = args and args:match("^(%S+)%s+(.+)$")
	if not actionID or not tokens then
		ns:Print("Usage: /ubermoc bind <action> <PADBUTTON[-PADBUTTON]>  (see /ubermoc bindlist)")
		return
	end

	actionID = actionID:upper()
	if not ns.actionByID[actionID] then
		ns:Print("Unknown action. Actions: MODE, MENU, SLICE1-SLICE6")
		return
	end

	local padKeys = {}
	for token in (tokens:upper()):gmatch("[A-Z0-9_]+") do
		if not token:find("^PAD") or not ns:IsButtonSupported(token) then
			ns:Print(("Unsupported controller button: %s"):format(token))
			return
		end
		table.insert(padKeys, token)
	end

	ns:SetActionBinding(actionID, table.concat(padKeys, "-"))
	ns:Print((L.BOUND_TO):format(GetActionName(actionID), ns:FormatBindingText(table.concat(padKeys, "-"))))
end

ns.SlashSubcommands["unbind"] = function(args)
	local actionID = args and (args:upper())
	if not actionID or not ns.actionByID[actionID] then
		ns:Print("Usage: /ubermoc unbind <action>")
		return
	end
	ns:SetActionBinding(actionID, nil)
	ns:Print((L.CLEARED):format(GetActionName(actionID)))
end
