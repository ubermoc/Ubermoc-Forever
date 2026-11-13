-- Spec tests for REQUIREMENTS.md line 1, the Step A diagnostic - FIRST attempt (key-probing).
-- SUPERSEDED on 2026-11-12: probing KEY -> action with GetBindingAction(key) returned NOTHING in the real game
-- (recorded SavedVariables UbermocForever.lua: count 0, all 64 probes unbound), because Blizzard's gamepad
-- actions live in binding context GamepadModeInGameCore. See Spec/R-1.1-dump-context.lua for the fixed dump
-- tests; this file keeps only the coverage that still holds (the slash command is wired and read-only).

test("dump-command-exists", "R-1.1", "/ubermoc dumpdefaults is a real subcommand (no 'unknown command' reply)", function()
  local g = World{ saved = nil, pads = {5}, commands = { "JUMP", "ACTIONBUTTON1" }, bindings = { PAD1 = "JUMP" } }
  g.login()
  g.slash("/ubermoc dumpdefaults")
  falsy(g.say("commands:"), "the slash handler fell through to its unknown-command help, so dumpdefaults is not wired up")
end)
