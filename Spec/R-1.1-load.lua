-- Spec tests for REQUIREMENTS.md line 1: "The addon loads on a brand-new install (no saved data, all defaults,
-- no other Ubermoc addon) with no Lua error."
-- Run offline against the fake game (harness wow/behavior.lua). Not listed in the .toc.

test("load-fresh", "R-1.1", "brand-new install: loads, logs in, fires events, zero Lua errors", function()
  local g = World{ saved = nil, pads = {5}, commands = { "JUMP", "ACTIONBUTTON1" }, bindings = {} }
  g.login()
  g.advance(3)
  eq(#g.errors, 0, "Lua errors during login events: " .. tostring(g.errors[1]))
end)

test("load-existing", "R-1.1", "second install with saved data (dump already stored): loads with no Lua error", function()
  local saved = { enabled = true, debug = false, defaultsDump = { time = 1700000000, count = 2, bindings = { PAD1 = "JUMP" }, unboundKeys = {} } }
  local g = World{ saved = saved, pads = {5}, commands = { "JUMP", "ACTIONBUTTON1" }, bindings = { PAD1 = "JUMP" } }
  g.login()
  g.advance(3)
  eq(#g.errors, 0, "Lua errors during login events: " .. tostring(g.errors[1]))
end)

test("dump-command-exists", "R-1.1", "/ubermoc dumpdefaults is a real subcommand (no 'unknown command' reply)", function()
  local g = World{ saved = nil, pads = {5}, commands = { "JUMP", "ACTIONBUTTON1" }, bindings = { PAD1 = "JUMP" } }
  g.login()
  g.slash("/ubermoc dumpdefaults")
  falsy(g.say("commands:"), "the slash handler fell through to its unknown-command help, so dumpdefaults is not wired up")
end)
