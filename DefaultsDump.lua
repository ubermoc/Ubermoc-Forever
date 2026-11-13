-- DefaultsDump.lua: Step A of Phase 1 (REQUIREMENTS.md line 3's open fact): read from the running game Blizzard's
-- default controller bindings and save them to SavedVariables so the AI can build the real default layout from it.
-- Read-only: this file never calls SetBinding, SaveBindings, Activate/DeactivateBindingContext or any CVar setter.
-- /ubermoc dumpdefaults runs it; results land in db.defaultsDump (survive /reload).
--
-- FIRST attempt (2026-11-12 22:17, recorded in WTF/.../UbermocForever.lua): asked KEY -> action with
-- GetBindingAction(key) and no context. REAL RESULT: count 0, all 64 probes unbound. Cause: Blizzard's gamepad
-- actions are declared bindingContext="GamepadModeInGameCore" (Blizzard_GamepadActionBars/Bindings.xml:8,
-- Blizzard_Gamepad/Bindings.xml:2) and that context is only active while Blizzard's gamepad UI is on
-- (Blizzard_Gamepad/Core.lua:48-56). So this version asks PER ACTION which keys it has, passing the context,
-- exactly like Blizzard's own binding screen: GetBindingKey(action, nil, bindingContext)
-- (Blizzard_Settings_Shared/Blizzard_Keybindings.lua:101-105).
-- NOTE (what is proven and what is not): GetBindingKey/GetBindingAction are legacy globals with NO documented
-- signature (Blizzard publishes none; warcraft.wiki.gg/wiki/API_GetBindingKey lists only the command argument).
-- The 3-argument form is PROVEN ONLY by Blizzard's own call sites: GetBindingKey(action, nil, bindingContext) at
-- Blizzard_Keybindings.lua:105 and :154, GetBindingAction(newKey, nil, bindingContext) at :127. We copy Blizzard.
-- If the game errors on that form or answers nothing even with the context ACTIVE, this dump records count 0 and
-- contextActive true - that is a finding for the AI, not a silent failure (the read-only key-probe cross-check
-- and pcall-free capture make any error visible in the Lua log).
local addonName, ns = ...

-- The gamepad key names Blizzard itself defines (Blizzard_SharedXML/Shared/GamepadConstants.lua), kept as a
-- second probe so the dump shows BOTH directions. Modifier layers are MODIFIER.."-"..KEY (BindingSetFactory.lua:6
-- GetModifiedKeyName; GAMEPAD_MOD_LEFT="SHIFT", GAMEPAD_MOD_RIGHT="CTRL", GAMEPAD_MOD_LEFT_AND_RIGHT="CTRL-SHIFT").
local GAMEPAD_KEYS = {
	"PAD1", "PAD2", "PAD3", "PAD4",            -- face buttons (GAMEPAD_FACE_BOTTOM/RIGHT/LEFT/TOP)
	"PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", -- d-pad (no underscore inside: PADDRIGHT, not PAD_RIGHT)
	"PADLSHOULDER", "PADRSHOULDER",            -- bumpers
	"PADLTRIGGER", "PADRTRIGGER",              -- triggers
	"PADLSTICK", "PADRSTICK",                  -- stick presses
	"PADBACK", "PADFORWARD",                   -- menu buttons
}
local MODIFIERS = { "SHIFT", "CTRL", "CTRL-SHIFT" }

-- Blizzard's own actions declared with bindingContext="GamepadModeInGameCore" - copied verbatim from
-- Blizzard_GamepadActionBars/Bindings.xml:8-32 and Blizzard_Gamepad/Bindings.xml:2-27. Nothing invented.
local GAMEPAD_ACTIONS = {
	"GAMEPADACTIONBUTTON1", "GAMEPADACTIONBUTTON2", "GAMEPADACTIONBUTTON3", "GAMEPADACTIONBUTTON4",
	"GAMEPADACTIONBUTTON5", "GAMEPADACTIONBUTTON6", "GAMEPADACTIONBUTTON7", "GAMEPADACTIONBUTTON8",
	"OPENRADIAL", "TOGGLEUIFOCUS", "TOGGLEPINGSYSTEM",
	"GAMEPADLEFTMOD", "GAMEPADRIGHTMOD", "GAMEPADLEFTTARGETMODIFIER", "GAMEPADRIGHTTARGETMODIFIER",
}

-- Pure logic (testable offline): from the action -> keys map the game reports, build key -> action.
-- A key can hold only one action; if two actions report the same key the first stays and the clash is recorded.
function ns.SplitActionKeys(actionKeys)
	local bound, unboundKeys, clashes = {}, {}, {}
	for _, action in ipairs(GAMEPAD_ACTIONS) do
		local keys = actionKeys[action]
		if keys and #keys > 0 then
			for _, key in ipairs(keys) do
				if bound[key] and bound[key] ~= action then
					clashes[#clashes + 1] = { key = key, kept = bound[key], also = action }
				else
					bound[key] = action
				end
			end
		end
	end
	-- gamepad keys that no action reported: still worth recording as unbound
	for _, key in ipairs(GAMEPAD_KEYS) do
		if not bound[key] then unboundKeys[#unboundKeys + 1] = key end
		for _, mod in ipairs(MODIFIERS) do
			local mkey = mod .. "-" .. key
			if not bound[mkey] then unboundKeys[#unboundKeys + 1] = mkey end
		end
	end
	return bound, unboundKeys, clashes
end

-- Read the live action -> keys map for Blizzard's own gamepad actions, passing the binding context like
-- Blizzard's binding screen does. The 3-argument form is UNVERIFIED against any documented signature (none
-- exists) - it is copied from Blizzard's shipped calls and pcall-guarded: if the client rejects it we fall back
-- to the 1-argument form every caller uses, and record which form answered (ns.captureForm).
function ns.CaptureBindings()
	local context = Enum and Enum.BindingContext and Enum.BindingContext.GamepadModeInGameCore
	local actionKeys = {}
	ns.captureForm = "context"   -- what the dump recorded; "plain" if the 3-argument call errored
	for _, action in ipairs(GAMEPAD_ACTIONS) do
		local keys = {}
		local ok, k1, k2 = pcall(GetBindingKey, action, nil, context)
		if not ok then
			ns.captureForm = "plain"
			k1, k2 = GetBindingKey(action)   -- 1-argument form: Blizzard_ActionBar/Shared/ActionButton.lua:498
		end
		if k1 then keys[#keys + 1] = k1 end
		if k2 then keys[#keys + 1] = k2 end
		actionKeys[action] = keys
	end
	local keyProbe = {}
	for _, key in ipairs(GAMEPAD_KEYS) do
		keyProbe[key] = GetBindingAction(key)   -- 1-argument form: Blizzard_FrameXML/Mainline/CoinPickupFrame.lua:181
		for _, mod in ipairs(MODIFIERS) do
			keyProbe[mod .. "-" .. key] = GetBindingAction(mod .. "-" .. key)
		end
	end
	return actionKeys, keyProbe
end

function ns.DumpDefaults()
	if not GetBindingKey or not GetBindingAction then
		ns:Print("GetBindingKey/GetBindingAction are not available; cannot dump.")
		return nil
	end
	local context = Enum and Enum.BindingContext and Enum.BindingContext.GamepadModeInGameCore
	-- IsBindingContextActive(context) -> bool (KeyBindingsDocumentation.lua:118); force a real boolean so the
	-- saved dump never stores a non-boolean from an unexpected return.
	local contextActive = false
	if C_KeyBindings and C_KeyBindings.IsBindingContextActive and context then
		contextActive = C_KeyBindings.IsBindingContextActive(context) == true
	end
	local actionKeys, keyProbe = ns.CaptureBindings()
	local bound, unboundKeys, clashes = ns.SplitActionKeys(actionKeys)

	ns.db.defaultsDump = {
		time = time and time() or 0,
		count = 0,
		bindings = bound,
		unboundKeys = unboundKeys,
		clashes = clashes,
		keyProbe = keyProbe,          -- the first attempt's direction, for comparison
		-- store the enum VALUE but label it: if Blizzard ever changes the number, the dump still reads correctly
		context = context,      -- value of BindingContext.GamepadModeInGameCore (== 9 today, KeyBindingsDocumentation.lua:201)
		contextActive = contextActive,
		gamepadUIEnabled = (InputUtil and InputUtil.IsGamepadUIEnabled) and InputUtil.IsGamepadUIEnabled() or false,
		captureForm = ns.captureForm,  -- "context" = the 3-argument call answered; "plain" = it errored, 1-argument fallback used
		queriedActions = GAMEPAD_ACTIONS,
	}
	for _ in pairs(bound) do ns.db.defaultsDump.count = ns.db.defaultsDump.count + 1 end

	ns:Print(("gamepad dump: %d bound keys (action->key), key-probe found %d, context active: %s, Blizzard gamepad UI on: %s. /reload to save for the AI."):format(
		ns.db.defaultsDump.count,
		(function() local n = 0; for _, a in pairs(keyProbe) do if a and a ~= "" then n = n + 1 end end return n end)(),
		tostring(contextActive), tostring(ns.db.defaultsDump.gamepadUIEnabled)))
	if ns.db.defaultsDump.count == 0 then
		ns:Print("nothing found yet - turn Blizzard's gamepad UI ON (Options > Controls or the input-style prompt), /reload, then run /ubermoc dumpdefaults again.")
	end
	return ns.db.defaultsDump
end

ns.SlashSubcommands = ns.SlashSubcommands or {}
ns.SlashSubcommands["dumpdefaults"] = function() return ns.DumpDefaults() end
