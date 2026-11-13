-- Spec tests for REQUIREMENTS.md line 1, the Step A diagnostic: "/ubermoc dumpdefaults reads every gamepad
-- binding Blizzard assigns by default (every action, every key, every modifier layer) and saves it to SavedVariables."
-- Run offline against the fake game (harness wow/behavior.lua). Not listed in the .toc.

local function fresh()
  return World{
    saved = nil, pads = {5},
    commands = { "JUMP", "CAMERACLEARTARGET", "GAMEPADACTIONBUTTON1", "OPENMAP" },
    -- what the running game reports on a default install: PAD keys plus Blizzard's modifier layers
    -- (SHIFT-/CTRL-/CTRL-SHIFT- prefixes, from Blizzard_SharedXML/Shared/GamepadConstants.lua GAMEPAD_MOD_*)
    bindings = {
      PAD1 = "JUMP",
      ["SHIFT-PAD1"] = "CAMERACLEARTARGET",
      PADLSHOULDER = "GAMEPADACTIONBUTTON1",
      ["CTRL-SHIFT-PADRSHOULDER"] = "OPENMAP",
    },
  }
end

local function has(list, want)
  for _, v in ipairs(list) do if v == want then return true end end
  return false
end

test("dump-captures-everything", "R-1.1", "the dump saves every bound key, its action and the modifier layers", function()
  local g = fresh(); g.login(); g.slash("/ubermoc dumpdefaults")
  local d = g.saved and g.saved.defaultsDump
  truthy(d, "db.defaultsDump after the command")
  eq(d.bindings.PAD1, "JUMP", "plain PAD key")
  eq(d.bindings["SHIFT-PAD1"], "CAMERACLEARTARGET", "SHIFT layer")
  eq(d.bindings.PADLSHOULDER, "GAMEPADACTIONBUTTON1", "shoulder key")
  eq(d.bindings["CTRL-SHIFT-PADRSHOULDER"], "OPENMAP", "CTRL-SHIFT layer")
end)

test("dump-unbound-keys", "R-1.1", "gamepad keys with no action are recorded as unbound, not missing", function()
  local g = fresh(); g.login(); g.slash("/ubermoc dumpdefaults")
  local d = g.saved.defaultsDump
  eq(d.bindings.PAD3, nil, "an unbound key must not appear as bound")
  truthy(has(d.unboundKeys, "PAD3"), "PAD3 listed in unboundKeys")
  truthy(has(d.unboundKeys, "PADDRIGHT"), "PADDRIGHT listed in unboundKeys")
end)

test("dump-not-empty", "R-1.1", "the dump is non-empty and counts what it found", function()
  local g = fresh(); g.login(); g.slash("/ubermoc dumpdefaults")
  local d = g.saved.defaultsDump
  truthy(d.count >= 4, "count covers the four bound keys, got " .. tostring(d.count))
  eq(count(d.bindings), 4, "bindings table has exactly the bound keys")
end)

test("dump-survives-reload", "R-1.1", "the dump is in SavedVariables: a new login with that data still has it", function()
  local g = fresh(); g.login(); g.slash("/ubermoc dumpdefaults")
  local saved = g.saved
  local g2 = World{ saved = saved, pads = {5}, commands = { "JUMP" }, bindings = g.bindings }
  g2.login()
  truthy(g2.saved.defaultsDump, "defaultsDump after a reload/login")
  eq(g2.saved.defaultsDump.bindings.PAD1, "JUMP", "the saved dump kept its data")
end)

test("dump-does-not-bind", "R-1.1", "the diagnostic only reads: it changes no binding and saves none", function()
  local g = fresh(); g.login()
  local before = {}
  for k, v in pairs(g.bindings) do before[k] = v end
  g.slash("/ubermoc dumpdefaults")
  for k, v in pairs(before) do eq(g.bindings[k], v, "binding " .. k .. " changed by the dump") end
  eq(count(g.bindings), count(before), "a binding appeared that was not there before")
  eq(g.saves or 0, 0, "SaveBindings must not be called by a read-only diagnostic")
end)
