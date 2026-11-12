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

-- Buttons Blizzard's gamepad UI already uses in core contexts (stick clicks,
-- Start/Back). They stay bindable by hand; the defaults avoid them.

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
	-- still be bound manually.
	--
	-- Deliberately NOT defaulted onto:
	--  * PADRTRIGGER / PADLTRIGGER / PADRSHOULDER / PADLSHOULDER - while the
	--    game's controller cursor mode is on, the client itself uses these
	--    for mouse clicks and Ctrl/Shift emulation (the GamePadCursor* and
	--    GamePadEmulate* settings), so a default there fights the client.
	--  * PADPADDLE1/2 - only pads that physically have paddles report those
	--    buttons; on most pads a default would bind a button that does not
	--    exist. Bind them by hand if your pad has them.
	return {
		TARGET_ENEMY = "PAD3",
		TARGET_FRIEND = "PAD4",
		INTERACT = "PADDRIGHT",
		JUMP = "PAD2",
		AUTO_RUN = "PAD1",
		MOUNT_DISMOUNT = "PADLSTICK",
		BAGS = "PADRSTICK",
		CHARACTER = "PADDUP",
		SPELLBOOK = "PADDDOWN",
		MAP = "PADDLEFT",
		PING_TARGET = "PADPADDLE1",
	}
end

local function GetBindingTable()
	if type(ns.db.bindings) ~= "table" then
		ns.db.bindings = {}
	end
	return ns.db.bindings
end

-- One-time move off the old defaults: the previous set put actions on the
-- triggers and bumpers, which the client itself uses for cursor clicks and
-- Ctrl/Shift emulation in controller mode. A stored binding that still holds
-- its exact old button is replaced by the new default for that action (the
-- player's own rebinds are left alone).
local OLD_DEFAULTS = {
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

local function MigrateOldDefaults()
	if ns.db.defaultsVersion == 2 then
		return
	end
	ns.db.defaultsVersion = 2

	local bindings = GetBindingTable()
	local newDefaults = ns:BindingDefaults()
	for id, oldButton in pairs(OLD_DEFAULTS) do
		if bindings[id] == oldButton then
			bindings[id] = newDefaults[id]
		end
	end
end

-- True when the client can tell us which buttons the connected pad has.
local function HasButtonSupportProbe()
	return C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.ButtonBindingToIndex
end

-- A stored binding may name a button the currently connected pad does not
-- have (paddles on a pad without paddles, stick clicks when the client has
-- stick buttons switched off). Keep those in storage - they come back when a
-- suitable pad connects - but never hand them to the binding system.
local function IsTokenBindable(token)
	if not ns.controllerConnected or not HasButtonSupportProbe() then
		return true
	end
	return ns:IsButtonSupported(token)
end

-- Drop stored bindings that name buttons this pad cannot produce, so they
-- cannot shadow (or be shadowed by) the client's own uses of those keys.
local function PruneUnsupportedBindings()
	if not ns.controllerConnected or not HasButtonSupportProbe() then
		return false
	end
	local bindings = GetBindingTable()
	local changed = false
	for id, binding in pairs(bindings) do
		local tokens = GetBoundTokens(binding)
		if tokens then
			local kept = {}
			for _, token in ipairs(tokens) do
				if IsTokenBindable(token) then
					table.insert(kept, token)
				else
					changed = true
				end
			end
			bindings[id] = #kept > 0 and table.concat(kept, "-") or nil
		end
	end
	return changed
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
--
-- The override bindings live on an owner frame of our own, not on UIParent.
-- That matters twice over:
--  * ClearOverrideBindings(owner) removes only that owner's bindings, so
--    rebuilding ours never wipes the game's own controller bindings (the
--    stock gamepad interface binds its buttons through UIParent too).
--  * Our claims sit on their own line in the binding stack and are not
--    tangled with the game's claims.
------------------------------------------------------------------------

local bindingOwner = nil

local function GetBindingOwner()
	if not bindingOwner then
		bindingOwner = CreateFrame("Frame", "UbermocForeverBindingOwner", UIParent, "SecureHandlerStateTemplate")
	end
	return bindingOwner
end

-- Re-assert our claims whenever another addon (or the game's own controller
-- interface) overrides a controller button we claimed. The hook sees the
-- call after it ran, so re-setting ours puts it back on top of the stack.
-- Only keys that are actually ours trigger the rebuild, and the rebuild
-- itself sets no new claims, so this cannot loop.
local function ReassertOurBindings(owner, key)
	if owner == bindingOwner or type(key) ~= "string" then
		return
	end
	if InCombatLockdown() then
		return
	end
	key = key:upper()
	local bindings = GetBindingTable()
	for _, binding in pairs(bindings) do
		if type(binding) == "string" then
			for token in (binding .. "-"):gmatch("[A-Z0-9_]+") do
				if token == key then
					ns:ApplyBindings()
					return
				end
			end
		end
	end
	if IsBindingForGamePad and IsBindingForGamePad(key) then
		ns:RefreshBindingRows()
	end
end

hooksecurefunc("SetOverrideBinding", ReassertOurBindings)
hooksecurefunc("SetOverrideBindingClick", ReassertOurBindings)

-- Hidden secure buttons for the few actions whose behaviour is hand-written
-- Lua rather than a client command or macro (currently just mount/dismount).
-- The click runs through Blizzard's own SecureActionButtonTemplate code,
-- which stays legal even when other addons have tainted the execution; it
-- was only OUR lua running inside a press that got blocked.
local function EnsureActionButtons()
	if InCombatLockdown() then
		return false
	end

	GetBindingOwner()

	for _, action in ipairs(ns.ACTIONS) do
		local buttonName = "UbermocForeverButton" .. action.id
		if ns.ExecutionPath and ns.ExecutionPath(action.id) == "button" and not _G[buttonName] then
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

-- ClearOverrideBindings removes every override owned by our owner frame,
-- ours only. It must run OUTSIDE combat lockdown, otherwise the old click
-- bindings can be dropped without the new ones being put back (the rows
-- would show a binding that does nothing). Changes attempted mid-fight are
-- remembered and replayed when combat ends.
local function ClearOurOverrideBindings()
	if InCombatLockdown() then
		pendingApply = true
		return
	end
	if bindingOwner then
		ClearOverrideBindings(bindingOwner)
	end
end

function ns:GetBoundButton(actionID)
	local bindings = GetBindingTable()
	return bindings[actionID]
end

-- Actions the game already has a binding command for (names from Blizzard's
-- Interface/AddOns/Blizzard_FrameXML/Bindings_Camelot.xml). For these the pad
-- button is bound straight to that command, the way Blizzard's own gamepad
-- code binds keys (Blizzard_GamepadSharedUtility/InputBindingStack/
-- InputActionBinding.lua:22: SetOverrideBinding(UIParent, true, key, action)).
-- That keeps addon code out of the press entirely: several of these do things
-- the client restricts when addon code calls them (targeting, jump, stop
-- casting). JUMP also gets its key-release half this way, so holding the
-- button ascends. Actions without a game command keep the click path.

local NATIVE_COMMANDS = {
	TARGET_ENEMY = "TARGETNEARESTENEMY",
	TARGET_FRIEND = "TARGETNEARESTFRIEND",
	TARGET_PLAYER = "TARGETNEARESTENEMYPLAYER",
	FOCUS_TARGET = "FOCUSTARGET",
	INTERACT = "INTERACTTARGET",
	STOP_CASTING = "STOPCASTING",
	JUMP = "JUMP",
	AUTO_RUN = "TOGGLEAUTORUN",
	ZOOM_IN = "CAMERAZOOMIN",
	ZOOM_OUT = "CAMERAZOOMOUT",
	BAGS = "OPENALLBAGS",
	CHARACTER = "TOGGLECHARACTER0",
	SPELLBOOK = "TOGGLESPELLBOOK",
	TALENTS = "TOGGLETALENTS",
	MAP = "TOGGLEWORLDMAP",
	QUEST_LOG = "TOGGLEQUESTLOG",
	SOCIAL = "TOGGLESOCIAL",
	MOUNT_JOURNAL = "TOGGLECOLLECTIONSMOUNTJOURNAL",
	TARGET_PARTY = "TARGETNEARESTFRIENDPLAYER",
}

-- The command to bind for an action, or nil to use the macro path. A command
-- is only used when this client confirms it knows it (GetBindingIndex returns
-- its place in the binding table), so a build that renames one falls back to
-- the macro path instead of binding a button to nothing.
local function NativeCommandFor(actionID)
	local command = NATIVE_COMMANDS[actionID]
	if command and C_KeyBindings and C_KeyBindings.GetBindingIndex and C_KeyBindings.GetBindingIndex(command) then
		return command
	end
	return nil
end

-- The macro text for actions the client has no binding command for (attack,
-- ping, menu, free slots...). A macro is expanded by the CLIENT when the
-- button is pressed and its commands run with normal keybind rights - no
-- addon code executes in the press path at all. That matters: whenever
-- another addon taints an execution (UbermocUI does this constantly on this
-- install), anything our Lua tried to do during a press was rejected
-- ("ADDON_ACTION_FORBIDDEN ... RunBinding()"). A client-expanded macro is not
-- affected by that, the same way a stock keybind bound to a macro always
-- works no matter how many addons are installed.
--
-- Actions with a hand-written Lua body (mount/dismount) instead get a hidden
-- secure button below: the click path runs through Blizzard's own secure
-- template code, which stays legal even while other addons taint everything
-- else - it was only OUR lua inside the press that got blocked.
local MACRO_COMMANDS = {
	CLEAR_TARGET = "/cleartarget",
	ATTACK = "/startattack",
	READY_CHECK = "/readycheck",
	PING_TARGET = "/ping",
	MENU = "/ubermoc click MENU",
	SLICE1 = "/cast ", SLICE2 = "/cast ", SLICE3 = "/cast ",
	SLICE4 = "/cast ", SLICE5 = "/cast ", SLICE6 = "/cast ",
}

-- Free slots: the player types the spell to put on them. The text is
-- whitelisted (letters, digits, space, apostrophe, comma and a leading "/")
-- so a stored string can never inject extra slash commands into the macro.
-- /ubermoc bind SLICE1 Fireball  (or /ubermoc bind SLICE1 Fire Blast)
local function SliceSpellText(actionID)
	if not (ns.db and type(ns.db[actionID]) == "string") then
		return nil
	end
	local spell = ns.db[actionID]:match("^/?(%a[%w%' ,%-]*)$")
	if not spell or spell == "" then
		return nil
	end
	return spell
end

local function MacroTextFor(actionID)
	local base = MACRO_COMMANDS[actionID]
	if base == nil then
		return nil
	end
	if actionID:find("^SLICE") then
		local spell = SliceSpellText(actionID)
		if not spell then
			return nil
		end
		return base .. spell
	end
	return base
end

-- Which execution path an action takes when bound. Mirrors ApplyBindings:
-- native command, else the hidden secure button whose macrotext is the
-- client-expanded macro (a set free slot), else the button runs our click
-- handler (button - only hand-written Lua actions like mount/dismount and
-- unset free slots remain).
local function ExecutionFor(actionID)
	if NativeCommandFor(actionID) then
		return "native"
	end
	if MacroTextFor(actionID) or SliceSpellText(actionID) then
		return "macro"
	end
	return "button"
end

ns.ExecutionPath = ExecutionFor

function ns:ApplyBindings()
	if not self.bindingsActive then
		return
	end

	if InCombatLockdown() then
		pendingApply = true
		return
	end
	pendingApply = false

	ClearOurOverrideBindings()
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
			local command = NativeCommandFor(action.id)
			if command then
				for _, token in ipairs(tokens) do
					if IsTokenBindable(token) then
						-- The game's own binding command: the press runs exactly
						-- as a stock keybind does, with no addon code in between.
						SetOverrideBinding(GetBindingOwner(), PRIORITY, token, command)
					end
				end
			else
				local buttonName = "UbermocForeverButton" .. action.id
				local button = _G[buttonName]
				if button and not InCombatLockdown() then
					-- Set the macro at bind time so a free slot picks up its
					-- spell, and unbound-by-mistake slots fall back to the
					-- click handler rather than firing an empty /cast.
					-- (SetAttribute on a secure button is protected during
					-- combat; ApplyBindings defers mid-fight anyway.)
					local macrotext = MacroTextFor(action.id) or ("/ubermoc click " .. action.id)
					if button:GetAttribute("macrotext") ~= macrotext then
						button:SetAttribute("macrotext", macrotext)
					end
					for _, token in ipairs(tokens) do
						if IsTokenBindable(token) then
							SetOverrideBindingClick(GetBindingOwner(), PRIORITY, token, buttonName, "LeftButton")
						end
					end
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
			-- gmatch yields one value per match here (the pattern has no captures).
			for token in (binding or ""):gmatch("[A-Z0-9_]+") do
				if token == buttonToken then
					return true
				end
			end
		end
	end
	return false
end

-- Live preview while a row is capturing, and the private capture listener,
-- were removed in 0.2.3. The native CustomBindingButtonTemplate already
-- listens for gamepad presses itself (OnGamePadButtonDown), and the old
-- preview had to re-run the pressed action through addon code to show it -
-- which is exactly what got blocked ("ADDON_ACTION_FORBIDDEN ... RunBinding()")
-- whenever another addon had tainted the execution. With macro-based bindings
-- (see below) a press never needs addon code at all, so there is nothing left
-- to preview and no listener to relay presses into.

-- Whether the connected pad reports this button token. (Callers must not
-- ask when no pad is connected or the client gives no mapped state - use
-- IsTokenBindable above, which allows everything in that case.)
function ns:IsButtonSupported(button)
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
-- "TARGETNEARESTENEMY") through the client's own binding runner. Removed in
-- 0.2.3: RunBinding is protected, and calling it from our code during a press
-- was rejected outright ("ADDON_ACTION_FORBIDDEN ... RunBinding()"). Those
-- actions are now bound straight to their commands (NATIVE_COMMANDS) or
-- client-expanded macros (MACRO_COMMANDS), so nothing here needs it.
local actionHandlers = {
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

	MENU = function()
		if ns.OpenSettingsDeferred then
			ns.OpenSettingsDeferred()
		else
			ns:OpenSettings()
		end
	end,
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

-- The live-preview path ("/ubermoc preview") was removed in 0.2.3: re-running
-- the capturing action through addon code during a press is exactly what got
-- blocked by taint, and with command/macro bindings there is nothing to run.

-- The hidden secure buttons fire this through their macrotext
-- ("/ubermoc click <ID>") for the few actions whose behaviour is hand-written
-- Lua (mount/dismount, unset free slots). The click itself goes through
-- Blizzard's own SecureActionButtonTemplate code - legal even when other
-- addons have tainted the execution.
ns.SlashSubcommands = ns.SlashSubcommands or {}
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
    -- whatever they configured (only missing actions get a default); stored
    -- copies of the *old* defaults are migrated once to the new set.
    MigrateOldDefaults()
    local bindings = GetBindingTable()
    for id, button in pairs(ns:BindingDefaults()) do
        if bindings[id] == nil then
            bindings[id] = button
        end
    end

    ns:RefreshControllerState()
    PruneUnsupportedBindings()
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
    -- A different pad may have (or lack) paddles and stick clicks, so drop
    -- bindings for buttons this pad cannot produce before re-asserting.
    PruneUnsupportedBindings()
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
		ns:Print("  /ubermoc bindspell SLICE1 Fireball   put a spell on a free Action slot")
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
