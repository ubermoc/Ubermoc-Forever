-- R-2.2: our bind screen works with the controller only: d-pad moves the highlight over its rows and
-- buttons, PAD1 presses what is highlighted (picking a row starts capture), PAD2 closes the screen.
-- The screen registers itself with Nav.lua AFTER PLAYER_LOGIN (Bind.lua loads after Nav.lua and creates
-- the frame later) - these tests prove that late registration attaches the watchers.

local function bindScreenOpen()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true); g.acceptPopup()
    g.ns.ShowBindUI()   -- the way /ubermoc binds opens it: this ALREADY shows the frame and arms nav
    local f = g.env["UbermocForeverBindFrame"]
    truthy(f, "the bind screen frame exists after ShowBindUI")
    truthy(f.__scripts and f.__scripts.OnShow, "Nav watches the bind screen (late registration attached watchers)")
    -- no second g.show here: ShowBindUI showed it once; showing again would re-open nav mid-test.
    return g
end

test("bind-screen-registered-late", "R-2.2", "the maker registers at login; watchers attach when the frame is created; opening claims the keys", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true); g.acceptPopup()
    eq(count(g.overrides), 0, "no claims while the screen is closed")
    truthy(g.ns.NAV_MAKERS["UbermocForeverBindFrame"], "the maker registered at PLAYER_LOGIN")
    -- in the fake world an unknown Capital name reads as a truthy stub; a REAL frame answers GetName:
    local pre = g.env["UbermocForeverBindFrame"]
    eq(tostring(pre:GetName()), "<stub>", "the frame does not exist before it is first shown (still a stub)")
    g.ns.ShowBindUI()
    local f = g.env["UbermocForeverBindFrame"]
    truthy(f.__scripts and f.__scripts.OnShow, "watchers attached at creation time")
    g.show(f)
    truthy(g.overrides.PAD1, "PAD1 claimed once the screen is open")
    eq(g.overrides.PAD2 and g.overrides.PAD2.action, "CLICK UbermocForeverBindClose", "PAD2 clicks our Close button")
end)

test("bind-screen-dpad-over-rows-and-buttons", "R-2.2", "the map covers every row plus Clear/Defaults/Close; PAD1 always points at the highlighted control only", function()
    local g = bindScreenOpen()
    local map = g.ns.NAV_MAPS["UbermocForeverBindFrame"]
    truthy(map, "the screen has a nav map")
    local rows = #g.ns.AllDefaultKeys()
    eq(#map.controls, rows + 3, "one control per row plus Clear, Defaults, Close")
    eq(g.ns.NavFocus("UbermocForeverBindFrame"), 1, "opens on the first control")
    local mv = g.env["UbermocForeverNavMover_UbermocForeverBindFrame_down"]
    truthy(mv and mv.__scripts.OnClick, "the down mover exists for our screen")
    -- one press = mover click, which moves AND re-claims PAD1; assert both each step:
    for i = 2, rows + 3 do
        mv.__scripts.OnClick(mv)
        eq(g.ns.NavFocus("UbermocForeverBindFrame"), i, "d-pad down step " .. i)
        eq(g.overrides.PAD1.action, "CLICK " .. map.controls[i].id, "PAD1 points at the highlighted control only (step " .. i .. ")")
    end
    -- last control is Close; PAD1 points at it now:
    eq(map.controls[rows + 3].id, "UbermocForeverBindClose")
    eq(g.overrides.PAD1.action, "CLICK UbermocForeverBindClose", "PAD1 re-pointed to the highlighted control only")
end)

test("bind-screen-pad1-presses-row-and-capture-still-works", "R-2.2", "clicking the highlighted row button (what PAD1 makes the engine do) picks the row and a press binds it - controller-only rebinding end to end", function()
    local g = bindScreenOpen()
    -- PAD1's claim names the row button; the engine clicks it. Simulate the engine's click: call OnClick.
    local first = g.ns.NAV_MAPS["UbermocForeverBindFrame"].controls[1]
    eq(g.overrides.PAD1.action, "CLICK " .. first.id)
    local button = g.env[first.id]
    truthy(button and button.__scripts.OnClick, "the row button has an OnClick (the click PAD1 performs)")
    button.__scripts.OnClick(button)
    eq(g.saved.pendingRow, first.id and g.ns.rowList[1].__row, "the click selected that row (capture armed)")
    truthy(g.env["UbermocForeverBindListener"].__scripts.OnGamePadButtonDown, "the listener is listening after the click")
    -- press a controller button on the listener exactly as the game would. PAD3 is one of OUR rows' keys,
    -- so pressing it here would hit the conflict rule (the R-1.5 tests prove that refusal); use a key no
    -- row carries - SHIFT-PADLSTICK is not in Blizzard's default layout:
    g.env["UbermocForeverBindListener"].__scripts.OnGamePadButtonDown(g.env["UbermocForeverBindListener"], "SHIFT-PADLSTICK")
    eq(g.saved.binds[g.ns.rowList[1].__row], "SHIFT-PADLSTICK", "the pressed key landed on the row")
end)

test("bind-screen-close-via-pad2", "R-2.2", "clicking Close (PAD2's target) hides the screen and clears our claims", function()
    local g = bindScreenOpen()
    truthy(g.overrides.PAD1, "claims exist while open")
    local close = g.env["UbermocForeverBindClose"]
    truthy(close and close.__scripts.OnClick, "Close button has OnClick")
    close.__scripts.OnClick(close)   -- its handler calls frame:Hide() -> fake fires OnHide -> NavClose
    falsy(g.overrides.PAD1, "PAD1 claim gone after Close")
    falsy(g.overrides.PAD2, "PAD2 claim gone after Close")
end)

test("nav-automatic-no-toggle", "R-2.3", "window navigation is automatic: a stale saved navWindows=false changes nothing (user 2026-11-13)", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true); g.acceptPopup()
    g.saved.navWindows = false   -- leftover from an older build; the toggle is gone
    g.show(g.env["MerchantFrame"])   -- a Blizzard window opens
    truthy(g.overrides.PAD1, "claims exist in windows regardless of any saved flag")
    g.ns.ShowBindUI()
    g.show(g.env["UbermocForeverBindFrame"])
    truthy(g.overrides.PAD1, "our own bind screen is navigable too")
end)
