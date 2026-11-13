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
		return false, ("0 bound gamepad keys found (context active: %s, Blizzard gamepad UI on: %s) - report this line to the AI")
			:format(tostring(dump.contextActive), tostring(dump.gamepadUIEnabled))
	end
	return true
end)

-- R-1.1: a brand-new login produced no Lua error (ns.db exists and the slash commands are wired).
ns.Selftest.add("loaded-clean", "R-1.1", "the addon is loaded and its dump subcommand is registered", function()
	if not ns.db then return false, "saved variables not loaded" end
	if not (ns.SlashSubcommands and ns.SlashSubcommands["dumpdefaults"]) then return false, "dumpdefaults not registered" end
	return true
end)

-- R-1.3: in the REAL game, after accepting the popup, our override claims answer for the PAD keys.
-- GetBindingAction(key, true) checks overrides (community-documented second argument; if the game
-- errors on it this test says so instead of failing silently). NOTE: answering here only proves the key
-- LOOKUP - dump 2 (2026-11-12 23:45) proved a lookup can answer while the button still does nothing,
-- which is why the actions claimed must be normal-context ones (Layout.lua header).
ns.Selftest.add("overrides-answer-in-game", "R-1.3", "the 15 PAD keys carry our applied actions via overrides", function()
	if not (ns.db and ns.db.bindsAsked == "yes") then return false, "layout not accepted yet: /ubermoc binds, accept, then /ubermoc selftest" end
	local bad = {}
	for key, action in pairs(ns.BlizzardLayout) do
		local ok, got = pcall(GetBindingAction, key, true)
		if not ok then return false, "GetBindingAction(key, true) errored: " .. tostring(got) end
		if got ~= action then bad[#bad + 1] = ("%s=%s"):format(key, tostring(got)) end
	end
	if #bad > 0 then return false, "wrong or missing override on: " .. table.concat(bad, ", ") end
	return true
end)

-- R-1.3 (the real proof): does an override claim FIRE with Blizzard's gamepad UI off? The context-off-dead
-- actions are listed from dump 2's recorded data; we do NOT call them (no automated input). This test only
-- records what the game reports about each claimed action: whether it is declared at all
-- (C_KeyBindings.GetBindingIndex -> index, nil if unknown; KeyBindings namespace, Blizzard uses it at
-- Blizzard_Tutorials_Frame_Tutorials.lua:11) and whether its context answers. The user's button presses
-- remain the final proof.
ns.Selftest.add("actions-declared-in-game", "R-1.3", "every action we claim is declared by this client (GetBindingIndex answers)", function()
	if not (C_KeyBindings and C_KeyBindings.GetBindingIndex) then return false, "C_KeyBindings.GetBindingIndex unavailable" end
	local bad = {}
	for key, action in pairs(ns.BlizzardLayout) do
		local ok, idx = pcall(C_KeyBindings.GetBindingIndex, action)
		if not ok then return false, ("GetBindingIndex(%s) errored: %s"):format(action, tostring(idx)) end
		if not idx then bad[#bad + 1] = key .. "=" .. action end
	end
	if #bad > 0 then return false, "action not declared by the client: " .. table.concat(bad, ", ") end
	return true
end)

-- R-1.2 invariant: the recorded answer is one of the allowed values.
ns.Selftest.invariant("binds-asked-flag", "db.bindsAsked is nil, 'yes' or 'no'", function()
	local v = ns.db and ns.db.bindsAsked
	if v == nil or v == "yes" or v == "no" then return true end
	return false, "unexpected db.bindsAsked: " .. tostring(v)
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
