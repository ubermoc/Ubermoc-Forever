-- R-1.8: every failure path (no controller, in combat, unknown action) leaves the bindings exactly as
-- they were and says so in chat.

local function acceptedLogin()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true); g.acceptPopup()
    return g
end

test("combat-refuses-and-says-so", "R-1.8", "a bind attempt during combat lockdown changes nothing and prints a warning", function()
    local g = acceptedLogin()
    local snapshot = {}
    for k, v in pairs(g.bindings) do snapshot[k] = v end
    local savesBefore = g.saves or 0
    g.combat = true
    g.ns.BindListen("PAD4")
    g.ns.db.pendingRow = "PAD4"
    g.ns.BindPress("PADPADDLE2")     -- the press path must not write anything in combat
    for k, action in pairs(snapshot) do
        eq(g.bindings[k], action, "binding changed during combat: " .. k)
    end
    eq(count(g.bindings), count(snapshot), "no new binding written during combat")
    eq(g.saves or 0, savesBefore, "no SaveBindings call during combat (SetBinding is restricted /nocombat)")
    eq((g.bindings["PAD4"] or ""), g.ns.DefaultLayout["PAD4"], "the selected row keeps its default binding")
    truthy(g.say("in combat"), "chat must say why nothing changed")
end)

test("unknown-row-refused", "R-1.8", "a row name we never defined is refused without touching any binding", function()
    local g = acceptedLogin()
    local before = count(g.bindings)
    falsy(g.ns.ApplyOne("NOT_A_ROW"), "unknown row must be refused")
    eq(count(g.bindings), before, "no binding changed")
end)

test("non-pad-press-ignored", "R-1.8", "a keyboard press during listening binds nothing and says what to do instead", function()
    local g = acceptedLogin()
    local before = count(g.bindings)
    g.ns.BindListen("PAD4")
    g.ns.BindPress("KEY_B")          -- not a controller button
    eq(count(g.bindings), before, "a non-PAD press must change nothing")
    truthy(g.say("press a controller button"), "chat explains what to do")
end)

test("no-controller-still-safe", "R-1.8", "with no pad reported the addon loads, asks, applies bindings and never errors", function()
    local g = World{ saved = nil, pads = {}, commands = {}, bindings = {} }
    g.login(true)
    eq(#g.errors, 0, "no Lua error while loading without a controller")
    eq(#g.popups, 1, "the permission popup still shows (nothing pad-dependent)")
    g.acceptPopup()
    truthy(count(g.bindings) >= 20, "bindings are written; whether they FIRE with no pad is the game's business")
end)
