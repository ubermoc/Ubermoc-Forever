-- R-1.7: changing one binding never changes any other binding; /reload and a new login keep exactly
-- what the player set.

local function acceptedLogin()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true); g.acceptPopup()
    return g
end

local function press(g, key)
    local l = g.env["UbermocForeverBindListener"]
    l.__scripts.OnGamePadButtonDown(l, key)
end

local function snap(t) local c = {} for k, v in pairs(t or {}) do c[k] = type(v) == "table" and snap(v) or v end return c end

test("rebind-touches-nothing-else", "R-1.7", "moving one row to a free key leaves every other binding identical", function()
    local g = acceptedLogin()
    local snapshot = snap(g.bindings)
    g.ns.BindListen("PAD4")
    g.ns.ClearOne("PADPADDLE2")
    press(g, "PADPADDLE2")    -- its own button, freed first
    -- everything that was NOT on the PAD4 row or its old key stays byte-identical
    for k, action in pairs(snapshot) do
        if k ~= "PAD4" and k ~= "PADPADDLE2" then
            eq(g.bindings[k], action, "action changed on an untouched row: " .. k)
        end
    end
end)

test("rebind-frees-the-old-key", "R-1.7", "the row's previous key stops carrying its action after a rebind (no ghost bindings)", function()
    local g = acceptedLogin()
    -- PAD4 default: key PAD4 -> ACTIONBUTTON4 (dump 1 order). Rebind onto a free key.
    g.ns.ClearOne("PADPADDLE2")   -- free the target key first
    g.ns.BindListen("PAD4")
    press(g, "PADPADDLE2")
    -- ApplyLayout writes exactly the live set and ClearLayout frees keys no row holds anymore, so a moved
    -- row leaves NO entry behind on its old key.
    falsy(g.bindings["PAD4"], "ghost binding: PAD4 must carry nothing after the row moved")
    eq((g.ns.claims["PAD4"] or ""), "PADPADDLE2", "the row is claimed on its new key")
    eq(g.bindings["PADPADDLE2"], g.ns.DefaultLayout["PAD4"], "the new key carries the row's action")
end)

test("reload-keeps-exactly-what-the-player-set", "R-1.7", "after a simulated reload: custom rows on their pressed keys, cleared rows still unbound, untouched rows on their defaults", function()
    local g = acceptedLogin()
    g.ns.BindListen("PAD4")
    g.ns.ClearOne("PADPADDLE2")
    press(g, "PADPADDLE2")     -- custom, onto the player's own paddle button
    g.ns.ClearOne("PAD1")      -- cleared
    local saved = snap(g.saved)
    local bindings = snap(g.bindings)   -- the game persisted what we wrote (SaveBindings)
    local g2 = World{ saved = saved, pads = {5}, commands = {}, bindings = bindings }
    g2.login(true)
    eq(g2.bindings["PADPADDLE2"], g2.ns.DefaultLayout["PAD4"], "custom binding kept on the pressed key")
    falsy(g2.bindings["PAD1"], "cleared row stays cleared")
    eq(g2.bindings["PAD3"], g2.ns.DefaultLayout["PAD3"], "untouched row back on its default key")
end)
