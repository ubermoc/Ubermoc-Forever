-- R-2.3 (the model + the real maps): with a window open, the d-pad moves a visible highlight between
-- its controls, PAD1 activates the highlighted control, PAD2 closes or backs out.
--
-- The fake world models show/hide (behavior.lua: g.show(f)/g.hide(f) flip IsShown and fire OnShow /
-- OnHide scripts INCLUDING HookScript handlers - exactly how Nav.lua attaches). Unknown globals are
-- truthy stubs, so Blizzard frames exist in the fake world; frame pressability is injected through
-- g.env.UbermocForeverNavProbe (a FUNCTION id -> pressable?, which NavEnabled prefers over asking
-- frames). Key claims land in g.overrides as { owner, priority, action = "CLICK <name>" } (the fake's
-- SetOverrideBindingClick) - the tests assert the exact button each key points at.

-- login + open a Blizzard window through its real OnShow hook (Nav attaches hooks at PLAYER_LOGIN).
local function opened(window, shownIds)
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true)
    local f = g.env[window]
    truthy(f and f.__scripts and f.__scripts.OnShow, "Nav attached an OnShow handler to " .. window .. " at login")
    local shown = {}
    for _, id in ipairs(shownIds or {}) do shown[id] = true end
    g.env.UbermocForeverNavProbe = function(id) return shown[id] and true or false end
    g.show(f)   -- the game opening the window: IsShown true, OnShow hooks fire -> NavOpen runs
    return g
end

local MERCHANT_IDS = { "MerchantFrameTab1", "MerchantFrameTab2", "MerchantFrameCloseButton" }

test("dpad-moves-and-wraps", "R-2.3", "d-pad down moves the highlight, wrapping past the end; up wraps back", function()
    local g = opened("MerchantFrame", MERCHANT_IDS)
    eq(g.ns.NavFocus("MerchantFrame"), 1, "opening starts on the first pressable control")
    eq(g.ns.NavMove("MerchantFrame", "down"), 2)
    eq(g.ns.NavMove("MerchantFrame", "down"), 3)
    eq(g.ns.NavMove("MerchantFrame", "down"), 1, "wraps to the first control")
    eq(g.ns.NavMove("MerchantFrame", "up"), 3, "and up wraps to the last")
end)

test("skips-unpressable", "R-2.3", "the highlight never stops on a control that cannot be pressed (hidden or disabled)", function()
    -- gossip: two options and a Goodbye; the middle option is not pressable right now
    local g = opened("GossipFrame")   -- map built from the fake scrollbox: see real-gossip-map test; here use model directly
    local map = { title = "Gossip", controls = { { id = "A" }, { id = "B" }, { id = "C" } }, close = "C" }
    g.ns.NAV_MAPS["Model"] = map
    local shown = { A = true, C = true }   -- B not pressable
    g.env.UbermocForeverNavProbe = function(id) return shown[id] and true or false end
    eq(g.ns.NavMove("Model", "down"), 3, "skips the hidden B going down")
    eq(g.ns.NavMove("Model", "up"), 1, "and going up")
end)

test("nothing-enabled-stays", "R-2.3", "if no control can be pressed the highlight does not move", function()
    local g = opened("MerchantFrame", {})   -- nothing pressable
    eq(g.ns.NavFocus("MerchantFrame"), 1)
    eq(g.ns.NavMove("MerchantFrame", "down"), 1)
end)

test("activate-decisions", "R-2.3", "PAD1 on a normal control presses it; on the close control it closes; on an unpressable one nothing happens", function()
    local g = opened("MerchantFrame", MERCHANT_IDS)
    local map = g.ns.NAV_MAPS["MerchantFrame"]
    eq(g.ns.NavActivate("MerchantFrame", map.controls[1]), "press")
    eq(g.ns.NavActivate("MerchantFrame", map.controls[3]), "close")
    -- an unpressable control: probe says no
    local keep = g.env.UbermocForeverNavProbe
    g.env.UbermocForeverNavProbe = function(id) return false end
    eq(g.ns.NavActivate("MerchantFrame", map.controls[1]), "none")
    g.env.UbermocForeverNavProbe = keep
end)

test("real-maps-verified-names", "R-2.3", "the merchant map lists the button names verified in Blizzard's shipped source", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true)   -- PLAYER_LOGIN registers the makers
    truthy(g.ns.NAV_MAKERS["MerchantFrame"], "vendor window is mapped")
    truthy(g.ns.NAV_MAKERS["GossipFrame"], "gossip window is mapped")
    local map = g.ns.NAV_MAKERS["MerchantFrame"]()
    local ids = {}
    for _, c in ipairs(map.controls) do ids[c.id] = true end
    -- names read from Blizzard_UIPanels_Game/Vanilla/MerchantFrame.xml:488,505 and the template's
    -- $parentCloseButton (Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml ButtonFrameBaseTemplate)
    truthy(ids["MerchantFrameTab1"], "MERCHANT tab")
    truthy(ids["MerchantFrameTab2"], "BUYBACK tab")
    truthy(ids["MerchantFrameCloseButton"], "<FrameName>CloseButton")
    eq(map.close, "MerchantFrameCloseButton", "PAD2 maps to the window's Close")
end)

test("open-claims-point-at-buttons", "R-2.3", "opening a mapped window claims PAD1 at the highlighted control, PADDUP/DOWN at our mover buttons, PAD2 at Close - all secure CLICK claims", function()
    local g = opened("MerchantFrame", MERCHANT_IDS)
    local o = g.overrides
    eq(o.PAD1 and o.PAD1.action, "CLICK MerchantFrameTab1", "PAD1 points at the FIRST control (highlight start)")
    eq(o.PAD1.owner, g.env["MerchantFrame"], "the claim belongs to the window's own frame")
    eq(o.PADDUP and o.PADDUP.action, "CLICK UbermocForeverNavMover_MerchantFrame_up", "d-pad up clicks our mover button (one per window)")
    eq(o.PADDDOWN and o.PADDDOWN.action, "CLICK UbermocForeverNavMover_MerchantFrame_down", "d-pad down clicks our mover button (one per window)")
    eq(o.PAD2 and o.PAD2.action, "CLICK MerchantFrameCloseButton", "PAD2 clicks the window's Close")
end)

test("move-repoints-pad1", "R-2.3", "moving the highlight re-points PAD1 at the NEW highlighted control (never two controls on one key)", function()
    local g = opened("MerchantFrame", MERCHANT_IDS)
    eq(g.overrides.PAD1.action, "CLICK MerchantFrameTab1")
    -- the d-pad key clicks the mover; its OnClick moves and re-claims:
    local mover = g.env["UbermocForeverNavMover_MerchantFrame_down"]
    truthy(mover and mover.__scripts.OnClick, "the down mover button exists with an OnClick")
    mover.__scripts.OnClick(mover)
    eq(g.ns.NavFocus("MerchantFrame"), 2, "highlight moved")
    eq(g.overrides.PAD1.action, "CLICK MerchantFrameTab2", "PAD1 now points at the second control only")
end)

test("close-removes-claims", "R-2.3", "closing the window (its OnHide) clears our claims and forgets its highlight", function()
    local g = opened("MerchantFrame", MERCHANT_IDS)
    truthy(g.overrides.PAD1, "claims exist while open")
    g.hide(g.env["MerchantFrame"])   -- the game closing it: OnHide hooks fire -> NavClose runs
    falsy(g.overrides.PAD1, "PAD1 claim gone")
    falsy(g.overrides.PAD2, "PAD2 claim gone")
    falsy(g.overrides.PADDUP, "d-pad claims gone")
    eq(g.ns.NavFocus("MerchantFrame"), 1, "highlight forgotten for the next open")
end)

test("unmapped-window-changes-nothing", "R-2.3", "a window we do not map gets no claims at all (an unmapped window changes nothing)", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true)
    local f = g.env.CreateFrame("Frame", "AuctionHouseFrame")
    falsy(f.__hooks and f.__hooks.OnShow, "no Nav hook on an unmapped window")
    g.show(f)
    eq(count(g.overrides), 0, "no claims on an unmapped window")
end)

test("combat-refuses-nav-changes", "R-2.3", "in combat nothing is claimed or changed (the guard every binding path has)", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true)
    g.combat = true
    g.show(g.env["MerchantFrame"])
    eq(count(g.overrides), 0, "combat lockdown: no claims")
end)
