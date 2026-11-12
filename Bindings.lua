-- UbermocForever: controller key bindings.
-- Binds controller buttons to addon actions through the game's own binding
-- system (override click bindings on secure buttons), so no synthetic input
-- is ever produced. Button labels follow the connected device: the client
-- reports a labelStyle per pad (Generic / Letters / Shapes / Reverse) and
-- Blizzard already defines matching icon strings for every button token.

local ADDON, ns = ...

local PRIORITY = 1000

-- Actions this addon exposes to the binding system.
-- The window toggles below call exactly the functions Blizzard's own key
-- bindings run for the matching keyboard binding - every body here was read
-- from Interface/AddOns/Blizzard_FrameXML/Bindings_Camelot.xml (the game's
-- binding table), so a bound pad button does precisely what the stock key
-- does. Those functions are UI-package globals, not in the API index, so each
-- one is reached through _G with a nil guard (see the dispatch below).
ns.ACTIONS = {
	-- Targeting
	{ id = "TARGET_ENEMY",    name = "Ubermoc: Target Next Enemy" },
	{ id = "TARGET_FRIEND",   name = "Ubermoc: Target Next Friend" },
	{ id = "TARGET_PARTY",    name = "Ubermoc: Target Next Party Member" },
	{ id = "TARGET_PLAYER",   name = "Ubermoc: Target Nearest Enemy Player" },
	{ id = "CLEAR_TARGET",    name = "Ubermoc: Clear Target" },
	{ id = "FOCUS_TARGET",    name = "Ubermoc: Focus Target" },
	{ id = "INTERACT",        name = "Ubermoc: Interact With Target" },
	-- Combat
	{ id = "ATTACK",          name = "Ubermoc: Attack / Stop Attack" },
	{ id = "STOP_CASTING",    name = "Ubermoc: Stop Casting" },
	{ id = "READY_CHECK",     name = "Ubermoc: Ready Check" },
	{ id = "PING_TARGET",     name = "Ubermoc: Ping Target" },
	-- Movement
	{ id = "JUMP",            name = "Ubermoc: Jump" },
	{ id = "AUTO_RUN",        name = "Ubermoc: Toggle Auto Run" },
	{ id = "MOUNT_DISMOUNT",  name = "Ubermoc: Mount / Dismount" },
	{ id = "ZOOM_IN",         name = "Ubermoc: Zoom Camera In" },
	{ id = "ZOOM_OUT",        name = "Ubermoc: Zoom Camera Out" },
	-- Windows
	{ id = "BAGS",            name = "Ubermoc: Open All Bags" },
	{ id = "CHARACTER",       name = "Ubermoc: Character Sheet" },
	{ id = "SPELLBOOK",       name = "Ubermoc: Spell Book" },
	{ id = "TALENTS",         name = "Ubermoc: Talents" },
	{ id = "MAP",             name = "Ubermoc: World Map" },
	{ id = "QUEST_LOG",       name = "Ubermoc: Quest Log" },
	{ id = "SOCIAL",          name = "Ubermoc: Friends & Communities" },
	{ id = "MOUNT_JOURNAL",   name = "Ubermoc: Mount Journal" },
	{ id = "GROUP_FINDER",    name = "Ubermoc: Group Finder" },
	-- Addon + free slots
	{ id = "MENU",            name = "Ubermoc: Open Settings" },
	{ id = "SLICE1",          name = "Ubermoc: Action 1" },
	{ id = "SLICE2",          name = "Ubermoc: Action 2" },
	{ id = "SLICE3",          name = "Ubermoc: Action 3" },
	{ id = "SLICE4",          name = "Ubermoc: Action 4" },
	{ id = "SLICE5",          name = "Ubermoc: Action 5" },
	{ id = "SLICE6",          name = "Ubermoc: Action 6" },
}

-- Controller buttons offered for binding, in physical layout order.
ns.PAD_BUTTONS = {
	"PADDUP", "PADDLEFT", "PADDDOWN", "PADDRIGHT",
	"PAD1", "PAD2", "PAD3", "PAD4",
	"PADLSTICK", "PADRSTICK",
	"PADLSHOULDER", "PADRSHOULDER",
	"PADLTRIGGER", "PADRTRIGGER",
	"PADFORWARD", "PADBACK",
	-- Extra buttons on pads that have them (back paddles, mouse-style pads).
	"PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4",
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

local actionByID = {}
for _, action in ipairs(ns.ACTIONS) do
	actionByID[action.id] = action
end

ns.actionByID = actionByID

-- Split a stored binding ("PAD1-PAD2") into its button tokens. Local helper,
-- defined before first use (ApplyBindings below).
local function GetBoundTokens(binding)
	if type(binding) ~= "string" then
		return nil
	end
	local tokens = {}
	for token in binding:gmatch("[A-Z0-9_]+") do
		table.insert(tokens, token)
	end
	return #tokens > 0 and tokens or nil
end

------------------------------------------------------------------------
-- Defaults and persistence
------------------------------------------------------------------------

function ns:BindingDefaults()
	-- Only buttons Blizzard's gamepad UI leaves free by default. The left
	-- stick, right stick, Start (PADFORWARD) and Back (PADBACK) are used by
	-- the stock gamepad interface itself, so they stay unbound here and can
	-- still be bound manually. PADPADDLE1/2 exist on pads that have paddles.
	return {
		TARGET_ENEMY = "PADRSHOULDER",
		TARGET_FRIEND = "PADLSHOULDER",
		INTERACT = "PAD3",
		JUMP = "PADPADDLE1",
		AUTO_RUN = "PAD2",
		MOUNT_DISMOUNT = "PADPADDLE2",
		BAGS = "PAD4",
		CHARACTER = "PADDUP",
		SPELLBOOK = "PADDRIGHT",
		MAP = "PADDDOWN",
		QUEST_LOG = "PADDLEFT",
		STOP_CASTING = "PADLTRIGGER",
		ATTACK = "PADRTRIGGER",
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

local pendingApply = false

-- ClearOverrideBindings removes every override set on UIParent, ours included.
-- It must run OUTSIDE combat lockdown, otherwise the old click bindings can be
-- dropped without the new ones being put back (the rows would show a binding
-- that does nothing). Changes attempted mid-fight are remembered and replayed
-- when combat ends.
local function ClearAllOverrideBindings()
	if InCombatLockdown() then
		pendingApply = true
		return
	end
	if UIParent and ClearOverrideBindings then
		ClearOverrideBindings(UIParent)
	end
end

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
	if pendingApply then
		return
	end

	if not EnsureActionButtons() then
		return
	end

	local bindings = GetBindingTable()
	for _, action in ipairs(ns.ACTIONS) do
		local tokens = GetBoundTokens(bindings[action.id])
		if tokens then
			for _, token in ipairs(tokens) do
				if not self.controllerConnected or self:IsButtonSupported(token) then
					SetOverrideBindingClick(UIParent, PRIORITY, token, "UbermocForeverButton" .. action.id, "LeftButton")
				end
			end
		end
	end
end

ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if pendingApply then
		ns:ApplyBindings()
	end
end)

-- A binding row stores one or more "-joined" PAD tokens (Blizzard's capture
-- flow can record a two-button combo); GetBoundTokens above splits them so
-- each token gets its own override binding.

-- Whether any action is already bound to this exact button token.
function ns:IsButtonInUse(buttonToken, exceptActionID)
	local bindings = GetBindingTable()
	for id, binding in pairs(bindings) do
		if id ~= exceptActionID then
			for _, token in (binding or ""):gmatch("[A-Z0-9_]+") do
				if token == buttonToken then
					return true
				end
			end
		end
	end
	return false
end

-- Live preview while a row is capturing: when the player presses a pad
-- button during capture, bind that token to a hidden secure button which
-- runs the capturing action once (so the button visibly "does" the thing it
-- is about to be bound to). The native binding button's own gamepad
-- listener records the token in parallel, so storage still goes through
-- Blizzard's capture flow. The preview override is dropped when the capture
-- ends (ClearPreviewBinding), right before the real binding is applied.
function ns:PreviewBoundAction(buttonToken)
	if not buttonToken or self:IsButtonInUse(buttonToken) then
		return false
	end
	if InCombatLockdown() or not EnsureActionButtons() then
		return false
	end
	if not _G["UbermocForeverButtonPREVIEW"] then
		local button = CreateFrame("Button", "UbermocForeverButtonPREVIEW", nil, "SecureActionButtonTemplate")
		button:Hide()
		button:RegisterForClicks("AnyUp", "AnyDown")
		button:SetAttribute("type", "macro")
		button:SetAttribute("macrotext", "/ubermoc preview")
	end
	SetOverrideBindingClick(UIParent, PRIORITY, buttonToken, "UbermocForeverButtonPREVIEW", "LeftButton")
	self.previewToken = buttonToken
	return true
end

-- Clear the live-preview override. The client has no single-key clear for
-- overrides (only ClearOverrideBindings for a whole owner), so rebuild ours:
-- that drops the preview token and re-asserts every stored binding, which is
-- exactly the state we want when a capture ends or is cancelled.
function ns:ClearPreviewBinding()
	if self.previewToken then
		self.previewToken = nil
		self:ApplyBindings()
	end
end

-- Our own gamepad listener for the capture window (BindingsUI.lua arms and
-- disarms it around every capture). It never stores bindings - it only
-- drives the live preview above. The native button's EnableGamePadButton is
-- turned off while this is armed so exactly one listener sees each press;
-- the press is then replayed into the native button's own OnInput path,
-- which records the key and completes the capture just like keyboard input
-- does. (The native mixin only enables its gamepad listener after the mouse
-- release that opened capture, which for a touch/mouse-driven UI would mean
-- pad presses during capture are silently ignored.)
local captureListener = nil

function ns:ArmCapturePreview(button)
	if InCombatLockdown() then
		return false
	end

	if not captureListener then
		captureListener = CreateFrame("Button", ADDON .. "CaptureListener", UIParent)
		captureListener:SetSize(1, 1)
		captureListener:ClearAllPoints()
		captureListener:SetPoint("CENTER")
		captureListener:EnableMouse(false)
		captureListener:SetScript("OnClick", function(self, key, isDown)
			ns:OnCapturePadInput(key, isDown)
		end)
	end

	ns.captureTargetButton = button
	captureListener:Show()
	captureListener:RegisterForClicks("AnyDown", "AnyUp")
	captureListener:EnableGamePadButton(true)
	if button then
		button:EnableGamePadButton(false)
	end
	return true
end

function ns:DisarmCapturePreview()
	if captureListener then
		captureListener:EnableGamePadButton(false)
		captureListener:RegisterForClicks()
		captureListener:Hide()
	end
	local button = ns.captureTargetButton
	ns.captureTargetButton = nil
	-- The native mixin's method is called IsBindingModeActive with no
	-- arguments (CustomBindingButtonMixin.lua); call it, don't test for it.
	if button and button:IsBindingModeActive() then
		button:EnableGamePadButton(true)
	end
end

-- key arrives as a raw bindable token (the same values the native mixin
-- stores); keep PAD tokens only, like the completion callback does.
function ns:OnCapturePadInput(key, isDown)
	if type(key) ~= "string" or not key:find("^PAD") then
		return
	end

	if isDown then
		self:PreviewBoundAction(key)
	else
		self:ClearPreviewBinding()
	end

	local button = self.captureTargetButton
	if button and button.OnInput then
		-- Native capture path: records the key, updates the pending-bind
		-- glyph through CustomBindingManager:SetPendingBind, and on release
		-- fires our completion callback.
		button:OnInput(key, isDown)
	end
end

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
-- Capturing a button for an action now lives in BindingsUI.lua: the rows
-- use Blizzard's native CustomBindingButtonTemplate capture flow instead of
-- a private listener frame. Storage stays in db.bindings (this file).
------------------------------------------------------------------------

function ns:ResetBindingsToDefault()
	ns.db.bindings = self:BindingDefaults()
	ns:ApplyBindings()

	if ns.RefreshBindingRows then
		ns:RefreshBindingRows()
	end
end

------------------------------------------------------------------------
-- Action handling (invoked from the secure buttons via /slash)
--
-- Window toggles call the same functions Blizzard's own binding table calls
-- for the matching keyboard binding (every body below was read from
-- Interface/AddOns/Blizzard_FrameXML/Bindings_Camelot.xml). Those are
-- UI-package globals rather than documented API, so each is reached through
-- _G and skipped quietly if a build ever moves it. The dispatch runs in our
-- untainted code (the secure buttons only fire "/ubermoc click <ID>"), which
-- is what makes calling them legal at all.
------------------------------------------------------------------------

local function CallGlobal(name, ...)
	local fn = _G[name]
	if fn then
		fn(...)
	end
end

local function ToggleMountOrJournal()
	-- Mounted: dismount, like the DISMOUNT binding in the binding table.
	if IsMounted and IsMounted() then
		CallGlobal("Dismount")
		return
	end
	-- On foot: summon a favourite mount. GetDisplayedMountInfo's 7th return is
	-- isFavorite, 12th its mountID; walk the journal for the first usable
	-- favourite (the list is small and this only runs on a button press).
	if C_MountJournal and C_MountJournal.GetNumDisplayedMounts and C_MountJournal.GetDisplayedMountInfo then
		local fallbackMountID
		for index = 1, C_MountJournal.GetNumDisplayedMounts() do
			local _, _, _, _, isUsable, _, isFavorite, _, _, _, _, mountID = C_MountJournal.GetDisplayedMountInfo(index)
			if isFavorite and mountID then
				if isUsable then
					C_MountJournal.SummonByID(mountID)
					return
				end
				fallbackMountID = fallbackMountID or mountID
			end
		end
		if fallbackMountID then
			-- SummonByID on an unusable mount just fails quietly server-side.
			C_MountJournal.SummonByID(fallbackMountID)
			return
		end
	end
	ns:Print("No favourite mount set. Mark one as a favourite in the Mount Journal, or bind the Mount Journal action instead.")
end

local function PingTarget()
	if UnitExists and UnitExists("target") and C_PingSecure and C_PingSecure.SendUnitPing then
		local guid = UnitGUID and UnitGUID("target")
		if guid then
			C_PingSecure.SendUnitPing(guid)
			return
		end
	end
	-- No target: ping where the crosshair points, like the stock hit-test ping.
	if C_PingSecure and C_PingSecure.SendHitTestPing then
		C_PingSecure.SendHitTestPing()
	end
end

local function ToggleAttack()
	-- ATTACK / STOPATTACK in the binding table. The client has no "is auto
	-- attack running" query, so decide from melee range: if our target can be
	-- reached by Auto Attack (the same spell Blizzard's gamepad action bars
	-- check, see Blizzard_GamepadActionBars/TargetActionBars/HostileTargetingActionBar.lua),
	-- a press stops it; otherwise it starts the attack.
	if UnitExists and UnitExists("target") and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("target"))
		and C_Spell.IsSpellInRange then
		local autoAttackID = 6603 -- Auto Attack (Blizzard's own fallback id, MainActionBarFrame.lua)
		if C_Spell.IsSpellInRange(autoAttackID, "target") then
			CallGlobal("StopAttack")
			return
		end
	end
	StartAttack()
end

-- Run a binding command (the exact string from the game's binding table, e.g.
-- "TARGETNEARESTENEMY") through the client's own binding runner. Targeting
-- functions like TargetNearestEnemy are protected when an addon calls them
-- directly ("Interface action failed because of an AddOn"), but running them
-- as a bind command goes down the same path a stock keypress takes and is
-- allowed. RunBinding exists in this client (verified via the API index;
-- Blizzard's own KeyBindingFrame uses it to preview binds).
local function RunBindCommand(command)
	if RunBinding then
		RunBinding(command)
	end
end

local actionHandlers = {
	TARGET_ENEMY = function() RunBindCommand("TARGETNEARESTENEMY") end,
	TARGET_FRIEND = function() RunBindCommand("TARGETNEARESTFRIEND") end,
	TARGET_PARTY = function() TargetNearestPartyMember() end,
	TARGET_PLAYER = function() TargetNearestEnemyPlayer() end,
	CLEAR_TARGET = function() ClearTarget() end,
	FOCUS_TARGET = function() CallGlobal("FocusUnit", "target") end,
	INTERACT = function()
		if C_PlayerInteractionManager and UnitExists and UnitExists("target") then
			C_PlayerInteractionManager.InteractUnit("target")
		end
	end,

	ATTACK = ToggleAttack,
	STOP_CASTING = function() CallGlobal("SpellStopCasting") end,
	READY_CHECK = function()
		if C_PartyInfo and C_PartyInfo.DoReadyCheck then
			C_PartyInfo.DoReadyCheck()
		end
	end,
	PING_TARGET = PingTarget,

	JUMP = function()
		-- JUMP in the binding table: JumpOrAscendStart(); AscendStop() fires on
		-- key release. Our secure buttons only see clicks, so start and stop
		-- together - a plain jump, no hold-to-ascend.
		CallGlobal("JumpOrAscendStart")
		CallGlobal("AscendStop")
	end,
	AUTO_RUN = function() CallGlobal("ToggleAutoRun") end,
	MOUNT_DISMOUNT = ToggleMountOrJournal,
	ZOOM_IN = function() CallGlobal("CameraZoomIn") end,
	ZOOM_OUT = function() CallGlobal("CameraZoomOut") end,

	BAGS = function() CallGlobal("ToggleAllBags") end,
	CHARACTER = function() CallGlobal("ToggleCharacter", "PaperDollFrame") end,
	SPELLBOOK = function()
		local util = _G.PlayerSpellsUtil
		if util and util.ToggleSpellBookFrame then
			util.ToggleSpellBookFrame()
		end
	end,
	TALENTS = function()
		local util = _G.PlayerSpellsUtil
		if util and util.ToggleClassTalentOrSpecFrame then
			util.ToggleClassTalentOrSpecFrame()
		end
	end,
	MAP = function() CallGlobal("ToggleWorldMap") end,
	QUEST_LOG = function() CallGlobal("ToggleQuestLog") end,
	SOCIAL = function() CallGlobal("ToggleFriendsFrame") end,
	MOUNT_JOURNAL = function() CallGlobal("ToggleCollectionsJournal", _G.COLLECTIONS_JOURNAL_TAB_INDEX_MOUNTS) end,
	GROUP_FINDER = function() CallGlobal("PVEFrame_ToggleFrame", "GroupFinderFrame") end,

	MENU = function() ns:OpenSettings() end,
}

function ns:HandleBoundAction(actionID)
	if not actionByID[actionID] then
		return
	end

	local handler = actionHandlers[actionID]
	if handler then
		handler()
	else
		-- SLICE1-SLICE6: free slots. Until the menu work lands they only log
		-- in debug mode, which proves the binding path works.
		if self.db.debug then
			ns:Print(("UbermocForever: bound action %s pressed."):format(actionID))
		end
	end
end

-- The live-preview button's macrotext ("/ubermoc preview"): while a row is
-- capturing, pressing a pad button runs that action once right away, before
-- the binding is stored.
ns.SlashSubcommands = ns.SlashSubcommands or {}
ns.SlashSubcommands["preview"] = function()
	local actionID = ns.capturingActionID
	if actionID then
		ns:HandleBoundAction(actionID)
	end
end

-- The secure action buttons fire this through their macrotext
-- ("/ubermoc click <ID>"), which is how a bound pad button reaches the addon.
ns.SlashSubcommands["click"] = function(args)
	ns:HandleBoundAction((args or ""):upper())
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
		ns:Print("  /ubermoc bind <action> <button>  set a binding, e.g. /ubermoc bind TARGET_ENEMY PADRTRIGGER")
		ns:Print("  /ubermoc unbind <action>    clear an action's binding")
		ns:Print("  /ubermoc bindlist           show current bindings")
		ns:Print("  /ubermoc bindreset          restore default bindings")
		ns:Print("Actions: TARGET_ENEMY, TARGET_FRIEND, TARGET_PARTY, TARGET_PLAYER, CLEAR_TARGET, FOCUS_TARGET, INTERACT, ATTACK, STOP_CASTING, READY_CHECK, PING_TARGET, JUMP, AUTO_RUN, MOUNT_DISMOUNT, ZOOM_IN, ZOOM_OUT, BAGS, CHARACTER, SPELLBOOK, TALENTS, MAP, QUEST_LOG, SOCIAL, MOUNT_JOURNAL, GROUP_FINDER, MENU, SLICE1-SLICE6")
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

-- /ubermoc bind and /ubermoc unbind are defined in BindingsUI.lua (they go
-- through the same SetActionBinding path as the options UI).

ns.SlashSubcommands["bindlist"] = PrintBindingList
ns.SlashSubcommands["bindreset"] = function()
	ns:ResetBindingsToDefault()
		ns:Print("UbermocForever: bindings reset to defaults.")
end
