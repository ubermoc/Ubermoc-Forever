-- Spec tests for REQUIREMENTS.md line 3's open fact (Phase 1 Step A, second attempt).
-- The FIRST attempt asked the game "what action is on key PAD1?" with GetBindingAction(key) and no binding
-- context. The REAL result the user recorded in the game (SavedVariables UbermocForever.lua, 2026-11-12 22:17):
--   defaultsDump.count = 0, every one of the 64 key/layer probes unbound.
-- Cause (user-supplied + verified): Blizzard's gamepad actions are declared with bindingContext=
-- "GamepadModeInGameCore" (Blizzard_GamepadActionBars/Bindings.xml:8, Blizzard_Gamepad/Bindings.xml:2), and that
-- context is only active while Blizzard's gamepad UI is on (Blizzard_Gamepad/Core.lua:48-56).
-- So the dump must ask PER ACTION which keys it has, passing the context, the way Blizzard's own binding screen
-- does: GetBindingKey(action, nil, bindingContext) - Blizzard_Keybindings.lua:105.
-- The action list comes from Blizzard's own Bindings.xml for that context, not from memory.
-- This file is anchored to the recorded real result: the old key-probe path fails it (count 0), the new
-- action-probe path can only be proven by a fresh in-game dump (Tests.lua).

-- Exactly what the game returned on 2026-11-12 (real data, not invented): every probe answered ""/nil.
local REAL_EMPTY_RESULT = {
  count = 0,
  bindings = {},
  unboundKeys = (function()
    local out = {}
    for _, key in ipairs({ "PAD1", "PAD2", "PAD3", "PAD4", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
      "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADLSTICK", "PADRSTICK", "PADBACK", "PADFORWARD" }) do
      out[#out + 1] = key
    end
    return out
  end)(),
}

-- Blizzard's own action list for context GamepadModeInGameCore, copied from the two Bindings.xml files
-- (Blizzard_GamepadActionBars/Bindings.xml:8-32 and Blizzard_Gamepad/Bindings.xml:2-27). No invented actions.
local GAMEPAD_ACTIONS = {
  "GAMEPADACTIONBUTTON1", "GAMEPADACTIONBUTTON2", "GAMEPADACTIONBUTTON3", "GAMEPADACTIONBUTTON4",
  "GAMEPADACTIONBUTTON5", "GAMEPADACTIONBUTTON6", "GAMEPADACTIONBUTTON7", "GAMEPADACTIONBUTTON8",
  "OPENRADIAL", "TOGGLEUIFOCUS", "TOGGLEPINGSYSTEM",
  "GAMEPADLEFTMOD", "GAMEPADRIGHTMOD", "GAMEPADLEFTTARGETMODIFIER", "GAMEPADRIGHTTARGETMODIFIER",
}

-- The fake game (behavior.lua) models GetBindingKey(action) -> key1, key2 from its plain bindings table and
-- does not model binding contexts. A world that KNOWS the keys (models: context active in the real game):
local function world_with_keys()
  return World{ saved = nil, pads = {5}, commands = GAMEPAD_ACTIONS, bindings = {
    PAD1 = "GAMEPADACTIONBUTTON1",
    PADLSHOULDER = "OPENRADIAL",
    ["CTRL-PADRSHOULDER"] = "TOGGLEUIFOCUS",
  } }
end

test("dump-nonzero-count", "R-1.1", "the dump must find a nonzero number of default gamepad bindings (the real first attempt found 0)", function()
  local g = world_with_keys(); g.login()
  g.slash("/ubermoc dumpdefaults")
  local d = g.saved and g.saved.defaultsDump
  truthy(d, "db.defaultsDump after the command")
  -- anchored to reality: the recorded real result was count 0; a diagnostic that keeps probing keys fails here
  truthy(d.count > 0, "the dump found " .. tostring(d.count) .. " bound keys - the recorded in-game result was 0, so key-probing does not work")
  eq(d.bindings.PAD1, "GAMEPADACTIONBUTTON1", "action -> key recorded as key -> action")
  eq(d.bindings["CTRL-PADRSHOULDER"], "TOGGLEUIFOCUS", "a modified layer key recorded too")
end)

test("dump-asks-per-action-with-context", "R-1.1", "the dump records the context it read and the actions it asked about", function()
  local g = World{ saved = nil, pads = {5}, commands = GAMEPAD_ACTIONS, bindings = {} }
  g.login()
  g.slash("/ubermoc dumpdefaults")
  local d = g.saved.defaultsDump
  truthy(d.context ~= nil, "dump records the binding context it read (GamepadModeInGameCore)")
  truthy(d.contextActive ~= nil, "dump records whether that context was active at read time")
  truthy(d.queriedActions and #d.queriedActions >= #GAMEPAD_ACTIONS,
    "dump records every Blizzard gamepad action it asked about, got " .. tostring(d.queriedActions and #d.queriedActions))
end)

test("dump-action-list-is-blizzards", "R-1.1", "the actions asked about are exactly Blizzard's own for that context", function()
  local g = World{ saved = nil, pads = {5}, commands = GAMEPAD_ACTIONS, bindings = {} }
  g.login()
  g.slash("/ubermoc dumpdefaults")
  local wanted = {}
  for _, a in ipairs(GAMEPAD_ACTIONS) do wanted[a] = true end
  for _, a in ipairs(g.saved.defaultsDump.queriedActions) do
    truthy(wanted[a], "the dump asked about an action Blizzard does not declare for this context: " .. a)
  end
end)

test("dump-records-empty-honestly", "R-1.1", "if the game still answers nothing, the dump keeps count 0 and says the context was inactive", function()
  -- replay of the real empty result: the fake game knows no keys for these actions (context inactive case)
  local g = World{ saved = nil, pads = {5}, commands = GAMEPAD_ACTIONS, bindings = {} }
  g.login()
  g.slash("/ubermoc dumpdefaults")
  local d = g.saved.defaultsDump
  eq(d.count, 0, "count with nothing bound")
  eq(d.contextActive, false, "the fake game models an inactive context; the dump must record that, not hide it")
end)

test("dump-still-read-only", "R-1.1", "the fixed diagnostic still changes no binding and saves none", function()
  local g = World{ saved = nil, pads = {5}, commands = GAMEPAD_ACTIONS, bindings = { PAD1 = "JUMP" } }
  g.login()
  g.slash("/ubermoc dumpdefaults")
  eq(g.bindings.PAD1, "JUMP", "existing binding untouched")
  eq(count(g.bindings), 1, "no new binding appeared")
  eq(g.saves or 0, 0, "SaveBindings must not be called by a read-only diagnostic")
end)
