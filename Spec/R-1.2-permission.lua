-- R-1.2: first load on a new install shows ONE popup asking permission to apply the controller
-- layout. Nothing is bound before the player says yes. "No" leaves bindings untouched and the
-- popup does not return; a slash command asks again.
-- The fake game models popups (behavior.lua:80-86) and SAVED bindings (behavior.lua:57-73:
-- SetBinding writes g.bindings, SaveBindings counts into g.saves).

-- The layout Layout.lua applies is read from the addon itself (g.ns.DefaultLayout) so this file can
-- never drift out of sync with it (the user approved the full-button layout 2026-11-13; see Layout.lua
-- header for why each action).

local function loginFresh()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true)
    return g
end

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
    eq(count(g.bindings), 0, "saved bindings must stay empty before the player says yes")
    eq(g.saves or 0, 0, "no SaveBindings call before the player says yes")
end)

test("accept-applies-layout", "R-1.2", "accepting the popup applies Blizzard's recorded layout as saved bindings", function()
    local g = loginFresh()
    g.acceptPopup()
    for key, action in pairs(g.ns.DefaultLayout) do
        eq(g.bindings[key], action, "after accepting, " .. key .. " must carry Blizzard's action")
    end
    truthy((g.saves or 0) >= 1, "the layout must be persisted with SaveBindings (wiki API_SetBinding: bindings are not saved without it)")
end)

test("no-keeps-bindings", "R-1.2", "declining leaves the game's bindings untouched", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = { PAD1 = "INTERACTTARGET" } }
    g.login(true)
    eq(#g.popups, 1)
    g.cancelPopup()
    eq(g.bindings.PAD1, "INTERACTTARGET", "declining must not touch an existing binding")
    eq(count(g.bindings), 1, "declining must add no bindings at all")
    eq(g.saves or 0, 0, "declining must not save anything")
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
    eq(count(g.bindings), 0, "an unanswered popup must bind nothing")
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
    -- the game kept what we wrote: log in again WITH those saved bindings present
    local g2 = World{ saved = saved, pads = {5}, commands = {}, bindings = snapshot(g.bindings) }
    g2.login(false)
    eq(#g2.popups, 0, "already accepted: no popup on later logins")
    -- and the layout is (re-)applied: every row still carries its action
    for key, action in pairs(g2.ns.DefaultLayout) do
        eq(g2.bindings[key], action, "after an earlier Yes, later logins must keep the layout applied")
    end
end)
