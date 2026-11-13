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

test("clear-clears-only-that-row", "R-1.6", "Clear on one row removes only that row's claim", function()
    local g = acceptedLogin()
    local before = count(g.overrides)   -- harness helper, behavior.lua (not a game API)
    g.ns.ClearOne("PAD2")   -- the screen's Clear button calls exactly this
    -- the fake world records claims in g.overrides; ClearOne clears the CLAIM (override entry) for that row's key
    eq(count(g.ns.RebuildClaims()), before - 1, "exactly one row claim removed")
    falsy(g.ns.claims["PAD2"], "the PAD2 row claim must be gone")
    truthy((g.overrides["PAD2"] and g.overrides["PAD2"].action) ~= "ACTIONBUTTON7" or g.overrides["PAD2"] == nil, "PAD2 key must not carry the cleared row's action (fake world keeps a slot per key)")
    truthy(g.overrides["PAD1"], "every other claim untouched")
end)

test("conflict-shown-not-silent", "R-1.6", "binding a key another row already carries is refused and said in chat", function()
    local g = acceptedLogin()
    -- PADFORWARD's default action OPENALLBAGS lives on key PADFORWARD; try to move the PADBACK row onto it
    g.ns.BindListen("PADBACK")
    press(g, "PADFORWARD")
    truthy(g.say("already used by"), "chat must name the conflict")
    -- PADBACK keeps its old claim; PADFORWARD untouched
    eq(g.overrides["PADBACK"] and g.overrides["PADBACK"].action, "TOGGLEGAMEMENU", "refused bind leaves the row as it was")
    eq(g.overrides["PADFORWARD"] and g.overrides["PADFORWARD"].action, "OPENALLBAGS", "the other row untouched")
end)

test("conflict-resolved-after-clearing", "R-1.6", "after clearing the blocking row, the same press succeeds", function()
    local g = acceptedLogin()
    g.ns.BindListen("PADBACK")
    press(g, "PADFORWARD")                       -- refused
    g.ns.ClearOne("PADFORWARD")                  -- player clears the blocking row
    g.ns.BindListen("PADBACK")
    press(g, "PADFORWARD")                       -- now allowed
    eq(g.overrides["PADFORWARD"] and g.overrides["PADFORWARD"].action, "TOGGLEGAMEMENU",
        "PADBACK's action now lives on the pressed key")
end)

test("reset-restores-blizzard-layout", "R-1.6", "reset to default restores Blizzard's layout exactly (ns.DefaultLayout + ns.DefaultMods)", function()
    local g = acceptedLogin()
    g.ns.BindListen("PAD3")
    press(g, "PADRSTICK")            -- move a row off its default key
    g.ns.ClearOne("PAD1")            -- and clear another
    g.ns.ResetToDefault()
    for key, action in pairs(g.ns.DefaultLayout) do
        local v = g.overrides[key]
        truthy(v, "default claim missing after reset: " .. key)
        eq(v.action, action, "wrong action after reset on " .. key)
    end
    -- chord rows are NOT claimed by default (chords unproven in game - Layout.lua header)
    falsy(g.overrides["SHIFT-PAD3"], "no chord may be claimed by default")
    eq(count(g.overrides), count(g.ns.DefaultLayout), "after reset exactly the default claims exist")
end)
