-- UbermocForever: controller key bindings.
-- Binds controller buttons to addon actions through the game's own binding
-- system (override click bindings on secure buttons), so no synthetic input
-- is ever produced. Button labels follow the connected device: the client
-- reports a labelStyle per pad (Generic / Letters / Shapes / Reverse) and
-- Blizzard already defines matching icon strings for every button token.

local ADDON, ns = ...

local PRIORITY = 1000

-- Actions this addon exposes to the binding system.
ns.ACTIONS = {
	{ id = "MODE",   name = "Ubermoc: Toggle Controller Mode" },
	{ id = "MENU",   name = "Ubermoc: Open Settings" },
	{ id = "SLICE1", name = "Ubermoc: Action 1" },
	{ id = "SLICE2", name = "Ubermoc: Action 2" },
	{ id = "SLICE3", name = "Ubermoc: Action 3" },
	{ id = "SLICE4", name = "Ubermoc: Action 4" },
	{ id = "SLICE5", name = "Ubermoc: Action 5" },
	{ id = "SLICE6", name = "Ubermoc: Action 6" },
}

-- Controller buttons offered for binding, in physical layout order.
ns.PAD_BUTTONS = {
	"PADDUP", "PADDLEFT", "PADDDOWN", "PADDRIGHT",
	"PAD1", "PAD2", "PAD3", "PAD4",
	"PADLSTICK", "PADRSTICK",
	"PADLSHOULDER", "PADRSHOULDER",
	"PADLTRIGGER", "PADRTRIGGER",
	"PADFORWARD", "PADBACK",
}

-- Buttons that Blizzard's gamepad UI already uses in core contexts.
-- They stay bindable, but the row is marked so conflicts are expected.
local SHARED_BUTTONS = {
	PADLSTICK = true, PADRSTICK = true,
	PADFORWARD = true, PADBACK = true,
}

local STYLE_SUFFIX = {
	Generic = "",
	Letters = "_LTR",
	Shapes = "_SHP",
	Reverse = "_REV",
}

-- A manual "Controller Type" choice (db.controllerType, shared with the
-- settings dropdown) also decides which button icons to show: the label
-- families map 1:1 onto console styles. 0 = auto-detect keeps whatever the
-- connected device reports.
local typeToLabelStyle = {
	[1] = "Shapes",   -- PlayStation (DualShock)
	[2] = "Letters", -- Xbox
	[3] = "Reverse", -- Nintendo Switch
}

ns.bindingsActive = false
ns.capturingAction = nil

local actionByID = {}
for _, action in ipairs(ns.ACTIONS) do
	actionByID[action.id] = action
end

ns.actionByID = actionByID

------------------------------------------------------------------------
-- Defaults and persistence
------------------------------------------------------------------------

function ns:BindingDefaults()
	return {
		MODE = "PADLSHOULDER",
		MENU = "PADRSHOULDER",
		SLICE1 = "PAD1",
		SLICE2 = "PAD2",
		SLICE3 = "PAD3",
		SLICE4 = "PAD4",
		SLICE5 = "PADLTRIGGER",
		SLICE6 = "PADRTRIGGER",
	}
end

local function GetBindingTable()
	if type(ns.db.bindings) ~= "table" then
		ns.db.bindings = {}
	end
	return ns.db.bindings
end

------------------------------------------------------------------------
-- Device state
------------------------------------------------------------------------

function ns:GetLabelStyle()
	local override = tonumber(self.db and self.db.controllerType)
	if override and typeToLabelStyle[override] then
		return typeToLabelStyle[override]
	end

	if C_GamePad and C_GamePad.GetDeviceMappedState then
		local ok, mapped = pcall(C_GamePad.GetDeviceMappedState, self.controllerDeviceID)
		if ok and mapped and STYLE_SUFFIX[mapped.labelStyle] then
			return mapped.labelStyle
		end
	end
	return "Generic"
end

-- Icon string for a button token in the current device style, falling back
-- to the generic icon when that style has no specialization for it.
function ns:GetButtonLabel(button, abbr)
	local suffix = STYLE_SUFFIX[self:GetLabelStyle()] or ""
	local prefix = abbr and "KEY_ABBR_" or "KEY_"
	local label = _G[prefix .. button .. suffix]
	if not label then
		label = _G[prefix .. button]
	end
	return label or button
end

function ns:GetDeviceSummary()
	local name = nil
	if C_GamePad and C_GamePad.GetDeviceRawState then
		local ok, raw = pcall(C_GamePad.GetDeviceRawState, self.controllerDeviceID)
		if ok and raw and raw.name then
			name = raw.name
		end
	end
	if not name then
		name = self.controllerName or "Controller"
	end
	return ("%s (%s)"):format(name, self:GetLabelStyle())
end

------------------------------------------------------------------------
-- Secure click targets + override bindings
------------------------------------------------------------------------

local function EnsureActionButtons()
	if InCombatLockdown() then
		return false
	end

	for _, action in ipairs(ns.ACTIONS) do
		local buttonName = "UbermocForeverButton" .. action.id
		if not _G[buttonName] then
			local button = CreateFrame("Button", buttonName, nil, "SecureActionButtonTemplate")
			button:Hide()
			button:RegisterForClicks("AnyUp", "AnyDown")
			button:SetAttribute("type", "macro")
			button:SetAttribute("macrotext", "/ubermoc click " .. action.id)
		end
	end
	return true
end

local function ClearAllOverrideBindings()
	if UIParent and ClearOverrideBindings then
		ClearOverrideBindings(UIParent)
	end
end

-- Changes attempted during combat lockdown are remembered and replayed when
-- the player leaves combat: secure buttons cannot be created or rebound
-- mid-fight.
local pendingApply = false

function ns:GetBoundButton(actionID)
	local bindings = GetBindingTable()
	return bindings[actionID]
end

function ns:ApplyBindings()
	if not self.bindingsActive then
		return
	end

	if InCombatLockdown() then
		pendingApply = true
		return
	end
	pendingApply = false

	ClearAllOverrideBindings()

	if self.db.controllerEnabled == false then
		return
	end

	if not EnsureActionButtons() then
		return
	end

	local bindings = GetBindingTable()
	for _, action in ipairs(ns.ACTIONS) do
		local button = bindings[action.id]
		if button and (not self.controllerConnected or self:IsButtonSupported(button)) then
			SetOverrideBindingClick(UIParent, PRIORITY, button, "UbermocForeverButton" .. action.id, "LeftButton")
		end
	end
end

ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if pendingApply then
		ns:ApplyBindings()
	end
end)

-- Whether the active pad reports this button token. Falls back to allowing
-- every listed token when the client gives no mapped state.
function ns:IsButtonSupported(button)
	if not C_GamePad or not C_GamePad.GetDeviceMappedState or not C_GamePad.ButtonBindingToIndex then
		return true
	end

	local ok, mapped = pcall(C_GamePad.GetDeviceMappedState)
	if not ok or not mapped or type(mapped.buttons) ~= "table" then
		return true
	end

	local ok2, index = pcall(C_GamePad.ButtonBindingToIndex, button)
	if not ok2 or not index then
		return true
	end

	return mapped.buttons[index] ~= nil
end

------------------------------------------------------------------------
-- Capturing a button for an action (same pattern as the stock keybind
-- listener: enable OnGamePadButtonDown while listening, then store the token)
------------------------------------------------------------------------

local captureFrame = nil

local function StopCapture()
	if not ns.capturingAction then
		return
	end

	ns.capturingAction = nil
	if captureFrame then
		captureFrame:SetScript("OnKeyDown", nil)
		captureFrame:SetScript("OnGamePadButtonDown", nil)
		captureFrame:EnableKeyboard(false)
		captureFrame:EnableGamePadButton(false)
	end

	if ns.RefreshBindingRows then
		ns:RefreshBindingRows()
	end
end

ns.StopCapture = StopCapture

local function CommitCapturedButton(button)
	local actionID = ns.capturingAction
	if not actionID then
		return
	end

	local bindings = GetBindingTable()
	for _, action in ipairs(ns.ACTIONS) do
		if action.id ~= actionID and bindings[action.id] == button then
			bindings[action.id] = nil
		end
	end

	bindings[actionID] = button
	ns:ApplyBindings()
	StopCapture()
end

-- Gamepad tokens only: keyboard capture would collide with the stock
-- keybinding UI, so anything that is not a PAD* token is ignored.
local function OnCapturedInput(self, input)
	local button = input

	if type(button) ~= "string" or button:find("^PAD") == nil then
		return
	end

	CommitCapturedButton(button)
end

function ns:StartCapture(actionID)
	if not actionByID[actionID] then
		return
	end

	if not captureFrame then
		captureFrame = CreateFrame("Button", "UbermocForeverCaptureListener")
		captureFrame:SetPropagateKeyboardInput(true)
	end

	ns.capturingAction = actionID
	captureFrame:SetScript("OnGamePadButtonDown", OnCapturedInput)
	captureFrame:SetScript("OnKeyDown", OnCapturedInput)
	-- Input scripts only fire on frames explicitly enabled for that input
	-- (both default to false). Blizzard does the same before relying on them
	-- (Blizzard_GamepadSharedUtility CustomBindingButtonMixin).
	captureFrame:EnableKeyboard(true)
	captureFrame:EnableGamePadButton(true)

	if ns.RefreshBindingRows then
		ns:RefreshBindingRows()
	end
end

function ns:ClearBinding(actionID)
	if not actionByID[actionID] then
		return
	end

	GetBindingTable()[actionID] = nil
	ns:ApplyBindings()

	if ns.RefreshBindingRows then
		ns:RefreshBindingRows()
	end
end

function ns:ResetBindingsToDefault()
	ns.db.bindings = self:BindingDefaults()
	ns:ApplyBindings()

	if ns.RefreshBindingRows then
		ns:RefreshBindingRows()
	end
end

------------------------------------------------------------------------
-- Action handling (invoked from the secure buttons via /slash)
------------------------------------------------------------------------

function ns:HandleBoundAction(actionID)
	if self.db.controllerEnabled == false then
		return
	end

	if not actionByID[actionID] then
		return
	end

	if actionID == "MODE" then
		self.db.controllerEnabled = not self.db.controllerEnabled
		self:ApplyBindings()
		ns:Print(("UbermocForever: controller mode %s."):format(self.db.controllerEnabled and "on" or "off"))
	elseif actionID == "MENU" then
		self:OpenSettings()
	else
		-- SLICE1-SLICE6: placeholder slots. Until the menu work lands they
		-- only log in debug mode, which proves the binding path works.
		if self.db.debug then
			ns:Print(("UbermocForever: bound action %s pressed."):format(actionID))
		end
	end
end

------------------------------------------------------------------------
-- Lifecycle (handlers receive the event payload, matching Core's fan-out)
------------------------------------------------------------------------

ns:RegisterEvent("ADDON_LOADED", function(loadedAddon)
    if loadedAddon ~= ADDON then return end
    if type(ns.db) ~= "table" then return end

    -- First run: seed the default controller bindings. Existing users keep
    -- whatever they configured (only missing actions get a default).
    local bindings = GetBindingTable()
    for id, button in pairs(ns:BindingDefaults()) do
        if bindings[id] == nil then
            bindings[id] = button
        end
    end

    ns:RefreshControllerState()
    ns.bindingsActive = true
    ns:ApplyBindings()
    if ns.RefreshDeviceReadout then
        ns:RefreshDeviceReadout()
    end
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
    ns.bindingsActive = true
    ns:ApplyBindings()
end)

local function OnPadChanged()
    ns:ApplyBindings()
    if ns.RefreshDeviceReadout then
        ns:RefreshDeviceReadout()
    end
    if ns.RefreshBindingRows then
        ns:RefreshBindingRows()
    end
end

ns:RegisterEvent("GAME_PAD_CONNECTED", OnPadChanged)
ns:RegisterEvent("GAME_PAD_DISCONNECTED", OnPadChanged)
ns:RegisterEvent("GAME_PAD_ACTIVE_CHANGED", OnPadChanged)
ns:RegisterEvent("GAME_PAD_CONFIGS_CHANGED", OnPadChanged)

------------------------------------------------------------------------
-- Slash command extension: /ubermoc bind ...
------------------------------------------------------------------------

local function PrintBindingHelp()
		ns:Print("UbermocForever binding commands:")
		ns:Print("  /ubermoc bind <action>      press a controller button to bind it")
		ns:Print("  /ubermoc unbind <action>    clear an action's binding")
		ns:Print("  /ubermoc bindlist           show current bindings")
		ns:Print("  /ubermoc bindreset          restore default bindings")
		ns:Print("Actions: MODE, MENU, SLICE1-SLICE6")
end

local function PrintBindingList()
		ns:Print("UbermocForever bindings for " .. ns:GetDeviceSummary())
	local bindings = GetBindingTable()
	for _, action in ipairs(ns.ACTIONS) do
		local button = bindings[action.id]
		if button then
			ns:Print(("  %s: %s %s"):format(action.id, ns:GetButtonLabel(button, true), button))
		else
			ns:Print(("  %s: not bound"):format(action.id))
		end
	end
end

ns.SlashSubcommands = ns.SlashSubcommands or {}
ns.SlashSubcommands["bind"] = function(args)
	local actionID = args and (args:upper())
	if not actionID or not actionByID[actionID] then
		PrintBindingHelp()
		return
	end
	ns:StartCapture(actionID)
		ns:Print(("UbermocForever: press a controller button for %s."):format(actionID))
end

ns.SlashSubcommands["unbind"] = function(args)
	local actionID = args and (args:upper())
	if not actionID or not actionByID[actionID] then
		PrintBindingHelp()
		return
	end
	ns:ClearBinding(actionID)
		ns:Print(("UbermocForever: cleared %s."):format(actionID))
end

ns.SlashSubcommands["bindlist"] = PrintBindingList
ns.SlashSubcommands["bindreset"] = function()
	ns:ResetBindingsToDefault()
		ns:Print("UbermocForever: bindings reset to defaults.")
end

-- The secure action buttons fire this through their macrotext
-- ("/ubermoc click <ID>"), which is how a bound pad button reaches the addon.
ns.SlashSubcommands["click"] = function(args)
	ns:HandleBoundAction((args or ""):upper())
end
