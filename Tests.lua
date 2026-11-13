-- Tests.lua: the in-game self-test for UbermocForever (run: /ubermoc selftest, then /reload).
-- Step A of Phase 1: prove the dumpdefaults diagnostic reads real gamepad bindings from the running game.
local addonName, ns = ...

-- R-1.1 (Step A): in the real game, every gamepad key and modifier layer we look for answers when asked.
-- GetBindingAction goes KEY -> action; it returns "" or nil for an unbound key, but a Lua error here would mean
-- the game does not know these key names at all (the exact spelling comes from Blizzard's own
-- Blizzard_SharedXML/Shared/GamepadConstants.lua).
ns.Selftest.add("dump-reads-gamepad-keys", "R-1.1", "the game answers for every gamepad key and modifier layer we dump", function()
	local keys = {}
	for _, key in ipairs({
		"PAD1", "PAD2", "PAD3", "PAD4",
		"PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
		"PADLSHOULDER", "PADRSHOULDER",
		"PADLTRIGGER", "PADRTRIGGER",
		"PADLSTICK", "PADRSTICK",
		"PADBACK", "PADFORWARD",
	}) do
		for _, mod in ipairs({ "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }) do
			keys[#keys + 1] = mod .. key
		end
	end
	local bad = {}
	for _, key in ipairs(keys) do
		local ok = pcall(GetBindingAction, key)
		if not ok then bad[#bad + 1] = key end
	end
	if #bad > 0 then return false, "GetBindingAction errored on: " .. table.concat(bad, ", ") end
	return true
end)

-- R-1.1 (Step A): the dump finds at least one default gamepad binding in the running game. If this fails with
-- everything unbound, Blizzard assigns no default PAD bindings and line 3 needs a different source - tell the AI.
ns.Selftest.add("dump-finds-defaults", "R-1.1", "the dump is non-empty: Blizzard assigns defaults to gamepad keys in the live game", function()
	local dump = ns.DumpDefaults()
	if not dump then return false, "DumpDefaults returned nothing" end
	if dump.count < 1 then
		return false, "0 bound gamepad keys found - all unbound; report this to the AI (line 3 needs another source)"
	end
	return true
end)

-- R-1.1: a brand-new login produced no Lua error (ns.db exists and the slash commands are wired).
ns.Selftest.add("loaded-clean", "R-1.1", "the addon is loaded and its dump subcommand is registered", function()
	if not ns.db then return false, "saved variables not loaded" end
	if not (ns.SlashSubcommands and ns.SlashSubcommands["dumpdefaults"]) then return false, "dumpdefaults not registered" end
	return true
end)

-- Invariant: the dump, once stored, is well-formed (a table of key -> non-empty action).
ns.Selftest.invariant("dump-shape", "db.defaultsDump.bindings only holds key = non-empty action strings", function()
	local d = ns.db and ns.db.defaultsDump
	if not d then return true end -- nothing dumped yet, nothing to check
	for k, v in pairs(d.bindings) do
		if type(k) ~= "string" or type(v) ~= "string" or v == "" then
			return false, ("bad entry %s = %s"):format(tostring(k), tostring(v))
		end
	end
	return true
end)
