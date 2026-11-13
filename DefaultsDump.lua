-- DefaultsDump.lua: Step A of Phase 1 (REQUIREMENTS.md line 3's open fact): read from the running game every
-- gamepad key Blizzard assigns an action to by default - every action, every key, every modifier layer - and save
-- it to SavedVariables so the AI can build the real default layout from it. Read-only: this file never calls
-- SetBinding or SaveBindings. /ubermoc dumpdefaults runs it; results land in db.defaultsDump (survive /reload).
local addonName, ns = ...

-- The gamepad key names Blizzard itself defines (Blizzard_SharedXML/Shared/GamepadConstants.lua) plus the
-- modifier layers Blizzard builds as MODIFIER.."-"..KEY (BindingSetFactory.lua:6-8 GetModifiedKeyName,
-- GAMEPAD_MOD_LEFT="SHIFT", GAMEPAD_MOD_RIGHT="CTRL", GAMEPAD_MOD_LEFT_AND_RIGHT="CTRL-SHIFT").
local GAMEPAD_KEYS = {
	"PAD1", "PAD2", "PAD3", "PAD4",            -- face buttons (GAMEPAD_FACE_BOTTOM/RIGHT/LEFT/TOP)
	"PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", -- d-pad (no underscore inside: PADDRIGHT, not PAD_RIGHT)
	"PADLSHOULDER", "PADRSHOULDER",            -- bumpers
	"PADLTRIGGER", "PADRTRIGGER",              -- triggers
	"PADLSTICK", "PADRSTICK",                  -- stick presses
	"PADBACK", "PADFORWARD",                   -- menu buttons
}
local MODIFIERS = { "SHIFT", "CTRL", "CTRL-SHIFT" }

-- Pure logic (testable offline): from the key -> action map the game reports, split it into bound keys and
-- unbound gamepad keys. Keys whose action is "" or nil are unbound (GetBindingAction returns "" for an
-- unbound key - community docs; Blizzard checks `GetBindingAction(key)` truthiness in CoinPickupFrame.lua:181).
function ns.SplitBindings(bindings)
	local bound, unboundKeys = {}, {}
	for _, key in ipairs(GAMEPAD_KEYS) do
		local action = bindings[key]
		if action and action ~= "" then
			bound[key] = action
		else
			unboundKeys[#unboundKeys + 1] = key
		end
		for _, mod in ipairs(MODIFIERS) do
			local mkey = mod .. "-" .. key
			local maction = bindings[mkey]
			if maction and maction ~= "" then
				bound[mkey] = maction
			else
				unboundKeys[#unboundKeys + 1] = mkey
			end
		end
	end
	return bound, unboundKeys
end

-- Read the live key -> action map for every gamepad key and modifier layer. GetBindingAction(key) goes
-- KEY -> action (direction lesson: GetBindingKey/GetBindingByKey go the other way and silently return nothing).
function ns.CaptureBindings()
	local raw = {}
	for _, key in ipairs(GAMEPAD_KEYS) do
		raw[key] = GetBindingAction(key)
		for _, mod in ipairs(MODIFIERS) do
			raw[mod .. "-" .. key] = GetBindingAction(mod .. "-" .. key)
		end
	end
	return raw
end

function ns.DumpDefaults()
	if not GetBindingAction then
		ns:Print("GetBindingAction is not available; cannot dump.")
		return nil
	end
	local raw = ns.CaptureBindings()
	local bound, unboundKeys = ns.SplitBindings(raw)
	ns.db.defaultsDump = {
		time = time and time() or 0,
		count = 0,
		bindings = bound,
		unboundKeys = unboundKeys,
	}
	for _ in pairs(bound) do ns.db.defaultsDump.count = ns.db.defaultsDump.count + 1 end
	ns:Print(("default gamepad bindings dumped: %d bound keys, %d gamepad keys unbound. /reload to save them for the AI."):format(
		ns.db.defaultsDump.count, #unboundKeys))
	return ns.db.defaultsDump
end

ns.SlashSubcommands = ns.SlashSubcommands or {}
ns.SlashSubcommands["dumpdefaults"] = function() ns.DumpDefaults() end
