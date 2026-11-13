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
-- PADFORWARD is NOT a row of ours: the user's other addon owns that button (CLICK binding in their file).
local USER_BUTTONS = {
    "PADDUP", "PADDLEFT", "PADDDOWN", "PADDRIGHT",
    "PAD1", "PAD2", "PAD3", "PAD4",
    "PADLSHOULDER", "PADLTRIGGER", "PADRSHOULDER", "PADRTRIGGER",
    "PADLSTICK", "PADRSTICK",
    "PADBACK",
    "PADPADDLE2", "PADPADDLE4",   -- PADPADDLE1/3 are the Shift/Ctrl emulation buttons: kept free, not rows
}

local function press(g, key)
    local l = g.env["UbermocForeverBindListener"]
    l.__scripts.OnGamePadButtonDown(l, key)
end

-- PADFORWARD is owned by the user's other addon. PADPADDLE1/3 are the Shift/Ctrl emulation buttons and
-- PADPADDLE2 has no proven line in the user's file: none of them get DEFAULT rows, but a press must still
-- bind any of them (press-to-bind works on any key the game names - R-1.5 is about pressing, not defaults).
test("rows-for-every-button", "R-1.5", "the default layout covers every button except the four proven-free ones; and a press can bind even a button with no default row (PADPADDLE2)", function()
    local g = acceptedLogin()
    local rows = {}
    for _, row in ipairs(g.ns.AllDefaultKeys()) do rows[row] = true end
    local free = { PADFORWARD = true, PADPADDLE1 = true, PADPADDLE2 = true, PADPADDLE3 = true }
    for _, btn in ipairs(USER_BUTTONS) do
        if not free[btn] then truthy(rows[btn], "no row for button " .. btn) end
    end
    for _, btn in ipairs({ "PADFORWARD", "PADPADDLE1", "PADPADDLE2", "PADPADDLE3" }) do
        falsy(rows[btn], btn .. " must NOT have a default row (other addon / modifier emulation / no proven line)")
    end
    -- press-to-bind on a button that has NO default row: pick the PAD4 row, press PADPADDLE2.
    g.ns.BindListen("PAD4")
    press(g, "PADPADDLE2")
    eq(g.bindings["PADPADDLE2"], g.ns.DefaultLayout["PAD4"], "a press must bind even a button with no default row")
end)

test("press-binds-exact-key", "R-1.5", "selecting a row and pressing a controller button claims exactly that key", function()
    local g = acceptedLogin()
    -- Blizzard's own capture mechanism: the listener button carries OnGamePadButtonDown while listening
    -- (Blizzard_Keybindings.lua:29). Simulate the game calling it with the pressed key.
    g.ns.ClearOne("SHIFT-PAD2")   -- free a DEFAULTED row's key first (line 7: clear the row, then bind)
    g.ns.BindListen("PAD2")
    local l = g.env["UbermocForeverBindListener"]
    truthy(l, "capture listener frame exists")
    truthy(l.__scripts.OnGamePadButtonDown, "listener must be listening after BindListen")
    press(g, "SHIFT-PAD2")
    eq(g.bindings["SHIFT-PAD2"], g.ns.DefaultLayout["PAD2"], "the pressed key must carry the PAD2 row's action")
    falsy(g.bindings["PAD2"], "the old default key is released when the row moves")
end)

test("press-while-no-row-selected-does-nothing", "R-1.5", "a press with no row selected changes no binding (line 8 failure path)", function()
    local g = acceptedLogin()
    local before = count(g.bindings)
    local l = g.env["UbermocForeverBindListener"]
    local pressScript = l.__scripts.OnGamePadButtonDown
    falsy(pressScript, "listener must NOT be listening when no row is selected")
    g.ns.BindPress("PADPADDLE1")   -- direct call with nothing pending
    eq(count(g.bindings), before, "no binding may change without a selected row")
end)

test("binding-survives-reload", "R-1.5", "the player's pressed key is saved and re-applied on the next login (line 7)", function()
    local g = acceptedLogin()
    g.ns.BindListen("PAD3")
    g.ns.ClearOne("SHIFT-PAD3")   -- free a DEFAULTED row's key first (line 7: clear the row, then bind)
    press(g, "SHIFT-PAD3")
    truthy(g.bindings["SHIFT-PAD3"], "the pressed key carries the action right after the press")
    -- copy the saved variables like the game would between sessions, then log in again. The game ALSO kept
    -- our written bindings (saved bindings persist - wiki API_SetBinding).
    local function snap(t) local c = {} for k, v in pairs(t or {}) do c[k] = type(v) == "table" and snap(v) or v end return c end
    local saved = snap(g.saved)
    local g2 = World{ saved = saved, pads = {5}, commands = {}, bindings = snap(g.bindings) }
    g2.login(true)
    eq(count(g2.popups), 0, "no popup on a login that already answered")
    eq(g2.bindings["SHIFT-PAD3"], g2.ns.DefaultLayout["PAD3"], "the pressed key must still carry the action after reload")
    eq(g2.ns.claims["PAD3"], "SHIFT-PAD3", "after reload the PAD3 row must be claimed on the pressed key")
end)
