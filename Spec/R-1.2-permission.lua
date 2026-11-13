-- R-1.2: first load on a new install shows ONE popup asking permission to apply the controller
-- layout. Nothing is bound before the player says yes. "No" leaves bindings untouched and the
-- popup does not return; a slash command asks again.
-- The fake game models popups (behavior.lua:80-86) and override bindings (behavior.lua:76-78).

-- The layout Layout.lua applies: the 15 keys recorded from the user's game by /ubermoc dumpdefaults,
-- with the actions Layout.lua ships (Blizzard's own; see Layout.lua header for why the context-off-dead
-- ones were replaced). Kept in sync with ns.BlizzardLayout.
BLIZZARD_LAYOUT = {
    PADDLEFT    = "ACTIONBUTTON1",
    PADDRIGHT   = "ACTIONBUTTON3",
    PADDDOWN    = "ACTIONBUTTON4",
    PADDUP      = "ACTIONBUTTON2",
    PAD1        = "ACTIONBUTTON8",
    PAD2        = "ACTIONBUTTON7",
    PAD3        = "ACTIONBUTTON5",
    PAD4        = "ACTIONBUTTON6",
    PADFORWARD  = "OPENALLBAGS",
    PADBACK     = "TOGGLEGAMEMENU",
    PADRSTICK   = "JUMP",
    PADLTRIGGER = "GAMEPADLEFTMOD",
    PADRTRIGGER = "GAMEPADRIGHTMOD",
    PADLSHOULDER= "GAMEPADLEFTTARGETMODIFIER",
    PADRSHOULDER= "GAMEPADRIGHTTARGETMODIFIER",
}

local function loginFresh()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true)
    return g
end

-- the fake world's own UIParent frame (behavior.lua:108), fetched from inside a test
local function uiParent(g) return g.env.UIParent end

-- copy what the game would have written to SavedVariables between logins (deep enough for our flat db)
local function snapshot(t)
    local c = {}
    for k, v in pairs(t or {}) do c[k] = type(v) == "table" and snapshot(v) or v end
    return c
end

test("popup-once", "R-1.2", "first login shows exactly one permission popup", function()
    local g = loginFresh()
    eq(#g.popups, 1, "expected one popup on first login")
end)

test("nothing-bound-before-yes", "R-1.2", "no binding of any kind exists before the player answers", function()
    local g = loginFresh()
    eq(count(g.bindings), 0, "normal bindings must stay empty")
    eq(count(g.overrides), 0, "override bindings must stay empty before the player says yes")
end)

test("accept-applies-layout", "R-1.2", "accepting the popup applies Blizzard's recorded layout", function()
    local g = loginFresh()
    g.acceptPopup()
    for key, action in pairs(BLIZZARD_LAYOUT) do
        local got = (g.overrides[key] and g.overrides[key].action) or g.bindings[key]
        eq(got, action, "after accepting, " .. key .. " must carry Blizzard's action")
    end
end)

test("no-keeps-bindings", "R-1.2", "declining leaves the game's bindings untouched", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = { PAD1 = "INTERACTTARGET" } }
    g.login(true)
    eq(#g.popups, 1)
    g.cancelPopup()
    eq(g.bindings.PAD1, "INTERACTTARGET", "declining must not touch an existing binding")
    eq(count(g.overrides), 0, "declining must not add overrides")
end)

test("no-never-returns", "R-1.2", "after No, later logins show no popup", function()
    local g = loginFresh()
    g.cancelPopup()
    truthy(g.saved, "saved variables must exist after login")
    local saved = snapshot(g.saved)
    local g2 = World{ saved = saved, pads = {5}, commands = {}, bindings = {} }
    g2.login(false)
    eq(#g2.popups, 0, "the popup must not return on a later login after No")
end)

test("unanswered-asked-once", "R-1.2", "if the popup is left up (or dismissed with escape), it is asked once per login and nothing binds", function()
    local g = loginFresh()
    eq(count(g.overrides), 0, "an unanswered popup must bind nothing")
    local saved = snapshot(g.saved)
    local g2 = World{ saved = saved, pads = {5}, commands = {}, bindings = {} }
    g2.login(false)
    eq(#g2.popups, 1, "still undecided: asking again is allowed")
end)

test("slash-asks-again", "R-1.2", "/ubermoc binds asks the popup again after a No", function()
    local g = loginFresh()
    g.cancelPopup()
    g.slash("/ubermoc binds")
    eq(#g.popups, 1, "the slash command must ask again")
end)

test("no-double-ask", "R-1.2", "a second login after Yes does not show the popup again", function()
    local g = loginFresh()
    g.acceptPopup()
    local saved = snapshot(g.saved)
    local g2 = World{ saved = saved, pads = {5}, commands = {}, bindings = {} }
    g2.login(false)
    eq(#g2.popups, 0, "already accepted: no popup on later logins")
    -- and the layout is re-applied automatically (overrides are temporary in the real game)
    for key, action in pairs(BLIZZARD_LAYOUT) do
        local got = (g2.overrides[key] and g2.overrides[key].action) or g2.bindings[key]
        eq(got, action, "after an earlier Yes, later logins must re-apply the layout")
    end
end)
