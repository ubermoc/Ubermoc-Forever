-- R-1.5: every controller button can be bound by pressing it: pick a row, press a controller button,
-- that exact button is bound. Rows exist for d-pad, face buttons, shoulders, triggers, stick clicks,
-- Start/Select and the back paddles - all of them Blizzard's own PAD key names (SharedConstants.lua:61-92).

local function acceptedLogin()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true); g.acceptPopup()
    return g
end

-- the exact buttons the user listed, as the PAD key names Blizzard gives every controller:
-- d-pad, A/B/X/Y face, L1/L2/R1/R2, stick clicks (L3/R3), Start/Select. Back paddles = PADPADDLE1-4.
local USER_BUTTONS = {
    "PADDUP", "PADDLEFT", "PADDDOWN", "PADDRIGHT",
    "PAD1", "PAD2", "PAD3", "PAD4",
    "PADLSHOULDER", "PADLTRIGGER", "PADRSHOULDER", "PADRTRIGGER",
    "PADLSTICK", "PADRSTICK",
    "PADBACK", "PADFORWARD",
    "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4",
}

test("rows-for-every-button", "R-1.5", "a bindable row exists for every button the user listed", function()
    local g = acceptedLogin()
    local rows = {}
    for _, row in ipairs(g.ns.AllDefaultKeys()) do rows[row] = true end
    for _, btn in ipairs(USER_BUTTONS) do
        truthy(rows[btn], "no row for button " .. btn)
    end
end)

local function press(g, key)
    local l = g.env["UbermocForeverBindListener"]
    l.__scripts.OnGamePadButtonDown(l, key)
end

test("press-binds-exact-key", "R-1.5", "selecting a row and pressing a controller button claims exactly that key", function()
    local g = acceptedLogin()
    -- Blizzard's own capture mechanism: the listener button carries OnGamePadButtonDown while listening
    -- (Blizzard_Keybindings.lua:29). Simulate the game calling it with the pressed key.
    g.ns.ClearOne("PADPADDLE2")   -- every button is a row of its own, so free the target key first (line 7)
    g.ns.BindListen("PAD2")
    local l = g.env["UbermocForeverBindListener"]
    truthy(l, "capture listener frame exists")
    truthy(l.__scripts.OnGamePadButtonDown, "listener must be listening after BindListen")
    press(g, "PADPADDLE2")
    truthy(g.overrides["PADPADDLE1"], "the pressed key must carry a claim")
    truthy(g.overrides["PADPADDLE2"], "the pressed key must carry a claim")
    eq((g.overrides["PADPADDLE2"] or {}).action, g.ns.DefaultLayout["PAD2"], "the pressed key must carry the PAD2 row's action")
    falsy(g.overrides["PAD2"], "the old default key is released when the row moves")
end)

test("press-while-no-row-selected-does-nothing", "R-1.5", "a press with no row selected changes no binding (line 8 failure path)", function()
    local g = acceptedLogin()
    local before = count(g.overrides)
    local l = g.env["UbermocForeverBindListener"]
    local press = l.__scripts.OnGamePadButtonDown
    falsy(press, "listener must NOT be listening when no row is selected")
    g.ns.BindPress("PADPADDLE1")   -- direct call with nothing pending
    eq(count(g.overrides), before, "no claim may change without a selected row")
end)

test("binding-survives-reload", "R-1.5", "the player's pressed key is saved and re-applied on the next login (line 7)", function()
    local g = acceptedLogin()
    g.ns.BindListen("PAD3")
    g.ns.ClearOne("PADPADDLE4")   -- free the key first: clearing a row makes its button bindable (line 7)
    press(g, "PADPADDLE4")
    -- copy the saved variables like the game would between sessions, then log in again
    local function snap(t) local c = {} for k, v in pairs(t or {}) do c[k] = type(v) == "table" and snap(v) or v end return c end
    local saved = snap(g.saved)
    local g2 = World{ saved = saved, pads = {5}, commands = {}, bindings = {} }
    g2.login(true)
    eq(count(g2.popups), 0, "no popup on a login that already answered")
    truthy(g2.overrides["PADPADDLE4"], "the pressed key must carry a claim after reload")
    eq(g2.ns.claims["PAD3"], "PADPADDLE4", "after reload the PAD3 row must be claimed on the pressed key")
end)
