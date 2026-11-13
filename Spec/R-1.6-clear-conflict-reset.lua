-- R-1.6: clear one row clears ONLY that row; a button never silently ends up on two actions - the
-- conflict is shown and resolved; "reset to default" restores Blizzard's layout.

local function acceptedLogin()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true); g.acceptPopup()
    return g
end

local function press(g, key)
    local l = g.env["UbermocForeverBindListener"]
    l.__scripts.OnGamePadButtonDown(l, key)
end

test("clear-clears-only-that-row", "R-1.6", "Clear on one row removes only that row's binding", function()
    local g = acceptedLogin()
    local before = count(g.bindings)   -- harness helper, behavior.lua (not a game API)
    g.ns.ClearOne("PAD2")   -- the screen's Clear button calls exactly this
    eq(count(g.ns.RebuildClaims()), count(g.ns.DefaultLayout) - 1, "exactly one row claim removed")
    falsy(g.ns.claims["PAD2"], "the PAD2 row claim must be gone")
    falsy(g.bindings["PAD2"], "the cleared key must carry nothing")
    eq(count(g.bindings), before - 1, "exactly one binding removed")
    truthy(g.bindings["PAD1"], "every other binding untouched")
end)

test("conflict-shown-not-silent", "R-1.6", "binding a key another row already carries is refused and said in chat", function()
    local g = acceptedLogin()
    -- PADFORWARD is not ours; take a key that IS ours: PADBACK's row onto PAD3's key
    g.ns.BindListen("PADBACK")
    press(g, "PAD3")
    truthy(g.say("already used by"), "chat must name the conflict")
    -- PADBACK keeps its old binding; PAD3 untouched
    eq(g.bindings["PADBACK"], "TOGGLEWORLDMAP", "refused bind leaves the row as it was")
    eq(g.bindings["PAD3"], g.ns.DefaultLayout["PAD3"], "the other row untouched")
end)

test("conflict-resolved-after-clearing", "R-1.6", "after clearing the blocking row, the same press succeeds", function()
    local g = acceptedLogin()
    g.ns.BindListen("PADBACK")
    press(g, "PAD3")                       -- refused: PAD3 lives on the PAD3 row
    g.ns.ClearOne("PAD3")                  -- player clears the blocking row
    g.ns.BindListen("PADBACK")
    press(g, "PAD3")                       -- now allowed
    eq(g.bindings["PAD3"], "TOGGLEWORLDMAP", "PADBACK's action now lives on the pressed key")
end)

test("reset-restores-blizzard-layout", "R-1.6", "reset to default restores Blizzard's layout exactly (ns.DefaultLayout)", function()
    local g = acceptedLogin()
    g.ns.BindListen("PAD3")
    press(g, "PADLSTICK")            -- move a row off its default key
    g.ns.ClearOne("PAD1")            -- and clear another
    g.ns.ResetToDefault()
    for key, action in pairs(g.ns.DefaultLayout) do
        eq(g.bindings[key], action, "wrong or missing binding after reset on " .. key)
    end
    eq(count(g.bindings), count(g.ns.DefaultLayout), "after reset exactly the default bindings exist")
end)
