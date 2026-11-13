-- Selftest.lua: the in-game self-test every Ubermoc addon ships. Copy it into the addon, list it in the .toc AFTER the files it tests,
-- and write the tests in Tests.lua with ns.Selftest.add(). Run in the game:  /<slash> selftest   then  /reload
-- Results go to SavedVariables (ns.db.selftest) so the AI can read them from the WTF folder: version, time, one line per test with the spec
-- line it proves (for example "R-1.3"). It runs inside the addon: it calls the addon's own functions and Blizzard's own handlers, it sends no
-- keyboard or mouse input. Tests that change bindings must restore them (use ns.Selftest.snapshot / restore) and must be safe to run twice.
local ADDON, ns = ...
local T = {}
ns.Selftest = T
T.tests, T.invariants = {}, {}

-- T.add(id, spec, description, fn): fn() returns true, or false/nil plus a message; an error counts as a failure.
function T.add(id, spec, description, fn)
	T.tests[#T.tests + 1] = { id = id, spec = spec, description = description, fn = fn }
end

-- T.invariant(id, description, fn): a rule about the saved data or live state that must ALWAYS hold. fn() returns true or false, message.
-- They run at every selftest and (when ns.db.debug is on) at login.
function T.invariant(id, description, fn)
	T.invariants[#T.invariants + 1] = { id = id, description = description, fn = fn }
end

local function run(list, kind)
	local out = {}
	for _, t in ipairs(list) do
		local ok, a, b = pcall(t.fn)
		local pass = ok and a == true
		local detail = pass and "" or (ok and tostring(b or a or "returned nothing") or ("ERROR: " .. tostring(a)))
		out[#out + 1] = { kind = kind, id = t.id, spec = t.spec or "", description = t.description, pass = pass, detail = detail }
	end
	return out
end

function T.run(print_)
	local results = run(T.tests, "test")
	for _, r in ipairs(run(T.invariants, "invariant")) do results[#results + 1] = r end
	local passed = 0
	for _, r in ipairs(results) do if r.pass then passed = passed + 1 end end
	local version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "?"
	if ns.db then
		ns.db.selftest = { version = version, time = time and time() or 0, passed = passed, total = #results, results = results }
	end
	if print_ ~= false then
		local say = ns.Print or print
		say(("selftest %s: %d of %d passed. /reload to save the results for the AI."):format(version, passed, #results))
		for _, r in ipairs(results) do
			if not r.pass then say(("  FAIL %s [%s] %s - %s"):format(r.id, r.spec, r.description, r.detail)) end
		end
	end
	return passed == #results, results
end

-- snapshot / restore the game's key bindings around a test that changes them (the player's bindings must come out unchanged)
function T.snapshot()
	local snap = {}
	for i = 1, GetNumBindings() do
		local command, _, key1, key2 = GetBinding(i)
		snap[#snap + 1] = { command, key1, key2 }
	end
	return snap
end
function T.restore(snap)
	for _, e in ipairs(snap) do
		for k = 2, 3 do
			if e[k] then SetBinding(e[k], e[1]) end
		end
	end
	if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
end

-- the subcommand: /<slash> selftest
ns.SlashSubcommands = ns.SlashSubcommands or {}
ns.SlashSubcommands["selftest"] = function() T.run(true) end

-- invariants at login when debug is on
if ns.RegisterEvent then
	ns:RegisterEvent("PLAYER_LOGIN", function()
		if ns.db and ns.db.debug then
			for _, r in ipairs(run(T.invariants, "invariant")) do
				if not r.pass then (ns.Print or print)(("INVARIANT BROKEN %s: %s"):format(r.id, r.detail)) end
			end
		end
	end)
end
