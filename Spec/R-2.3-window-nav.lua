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
-- The fake world creates the Blizzard frame BEFORE login: in the real game that frame comes from XML.
local function opened(window, shownIds)
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    if not rawget(g.env, window) then
        local f = g.env.CreateFrame("Frame", window)
        f.IsShown = function() return rawget(f, "__shown") and true or false end
    end
    g.login(true)
    local f = g.env[window]
    truthy(f and f.__scripts and f.__scripts.OnShow, "Nav attached an OnShow handler to " .. window .. " at login")
    local shown = {}
    for _, id in ipairs(shownIds or {}) do shown[id] = true end
    g.env.UbermocForeverNavProbe = function(id) return shown[id] and true or false end
    g.show(f)   -- the game opening the window: IsShown true, OnShow hooks fire -> NavOpen runs
    return g
end

-- The vendor map NOW has item slots too (the user's in-game test 2026-11-13: the d-pad only circled the
-- two tabs, "it doesn't go into the actual inventory"). In the fake world EVERY named global exists as a
-- truthy stub, so all twelve MerchantItem<i>ItemButton names are in the map; which ones are pressable is
-- the injected probe's answer.
-- In the fake world EVERY named global exists as a truthy stub, so ALL twelve item slots are in the map;
-- MERCHANT_IDS is what the probe reports pressable. Item 1 and item 3 share a row (slot 2 sits right of
-- slot 1, slot 3 below slot 1), so with this set a RIGHT step from item 1 has no cell to move to - that
-- is what grid-step refuses at the edge of the shown items.
local MERCHANT_IDS = { "MerchantItem1ItemButton", "MerchantItem2ItemButton", "MerchantItem3ItemButton", "MerchantFrameTab1", "MerchantFrameTab2", "MerchantFrameCloseButton" }

test("dpad-moves-and-wraps", "R-2.3", "d-pad down moves the highlight, wrapping past the end; up wraps back", function()
    local g = opened("MerchantFrame", MERCHANT_IDS)
    eq(g.ns.NavFocus("MerchantFrame"), 1, "opening starts on the first pressable control")
    -- walk by CONTROL ID, not index: the map now lists all twelve item slots (the fake world has every
    -- name), and the highlight only stops where the probe says a control is pressable.
    local id = function() return g.ns.NAV_MAPS["MerchantFrame"].controls[g.ns.NavFocus("MerchantFrame")].id end
    eq(id(), "MerchantItem1ItemButton", "opens on the first item, not a tab (user 2026-11-13)")
    eq(g.ns.NavMove("MerchantFrame", "down"), 2); eq(id(), "MerchantItem2ItemButton")
    g.ns.NavMove("MerchantFrame", "down"); eq(id(), "MerchantItem3ItemButton")
    g.ns.NavMove("MerchantFrame", "down"); eq(id(), "MerchantFrameTab1")
    g.ns.NavMove("MerchantFrame", "down"); eq(id(), "MerchantFrameTab2")
    g.ns.NavMove("MerchantFrame", "down"); eq(id(), "MerchantFrameCloseButton")
    g.ns.NavMove("MerchantFrame", "down"); eq(id(), "MerchantItem1ItemButton", "wraps to the first pressable control")
    g.ns.NavMove("MerchantFrame", "up");   eq(id(), "MerchantFrameCloseButton", "and up wraps to the last")
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
    local byid = {}
    for _, c in ipairs(map.controls) do byid[c.id] = c end
    eq(g.ns.NavActivate("MerchantFrame", byid["MerchantItem1ItemButton"]), "press")
    eq(g.ns.NavActivate("MerchantFrame", byid["MerchantFrameCloseButton"]), "close")
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
    -- the inventory itself (probe 2026-11-13: the map had ONLY tabs+close):
    truthy(ids["MerchantItem1ItemButton"], "item slot 1")
    truthy(ids["MerchantItem12ItemButton"], "item slot 12")
    truthy(ids["MerchantBuyBackItemItemButton"], "the single buyback slot")
    local grid, order = {}, {}
    for i, c in ipairs(map.controls) do
        order[c.id] = i
        if c.grid then grid[c.id] = c.grid end
    end
    truthy(grid["MerchantItem1ItemButton"], "slot 1 carries a grid cell")
    eq(grid["MerchantItem2ItemButton"].col, grid["MerchantItem1ItemButton"].col + 1, "slot 2 sits right of slot 1 (xml :149)")
    eq(grid["MerchantItem3ItemButton"].row, grid["MerchantItem1ItemButton"].row + 1, "slot 3 sits below slot 1 (xml :154)")
    truthy(order["MerchantItem1ItemButton"] < order["MerchantFrameTab1"], "items come BEFORE the tabs (open highlights the first control: inventory first, user 2026-11-13)")
end)

test("open-claims-point-at-buttons", "R-2.3", "opening a mapped window claims PAD1 at the highlighted control, PADDUP/DOWN at our mover buttons, PAD2 at Close - all secure CLICK claims", function()
    local g = opened("MerchantFrame", MERCHANT_IDS)
    local o = g.overrides
    eq(o.PAD1 and o.PAD1.action, "CLICK MerchantItem1ItemButton", "PAD1 points at the FIRST control - an item slot, not a tab")
    eq(o.PAD1.owner, g.env["MerchantFrame"], "the claim belongs to the window's own frame")
    eq(o.PADDUP and o.PADDUP.action, "CLICK UbermocForeverNavMover_MerchantFrame_up", "d-pad up clicks our mover button (one per window)")
    eq(o.PADDDOWN and o.PADDDOWN.action, "CLICK UbermocForeverNavMover_MerchantFrame_down", "d-pad down clicks our mover button (one per window)")
    eq(o.PAD2 and o.PAD2.action, "CLICK MerchantFrameCloseButton", "PAD2 clicks the window's Close")
end)

test("move-repoints-pad1", "R-2.3", "moving the highlight re-points PAD1 at the NEW highlighted control (never two controls on one key)", function()
    local g = opened("MerchantFrame", MERCHANT_IDS)
    eq(g.overrides.PAD1.action, "CLICK MerchantItem1ItemButton")
    -- the d-pad key clicks the mover; its OnClick moves and re-claims:
    local mover = g.env["UbermocForeverNavMover_MerchantFrame_down"]
    truthy(mover and mover.__scripts.OnClick, "the down mover button exists with an OnClick")
    mover.__scripts.OnClick(mover)
    eq(g.ns.NavFocus("MerchantFrame"), 2, "highlight moved")
    eq(g.overrides.PAD1.action, "CLICK MerchantItem2ItemButton", "PAD1 now points at the second control only")
end)

test("grid-step-inside-items", "R-2.3", "while the highlight sits on an item slot, left/right step between columns (the walk goes INTO the inventory, user 2026-11-13)", function()
    local g = opened("MerchantFrame", MERCHANT_IDS)
    eq(g.ns.NavFocus("MerchantFrame"), 1, "opens on the first item")
    -- right steps to the next column of the SAME row: slot 2 (col+1). The mover's OnClick drives it -
    -- since round 4 a mover has ONE handler only (two handlers = one press, two moves; user feedback).
    local right = g.env["UbermocForeverNavMover_MerchantFrame_right"]
    truthy(right and right.__scripts.OnClick, "a right mover exists with an OnClick")
    falsy(right.__scripts.OnKeyDown, "and no second key handler (one press = one move)")
    right.__scripts.OnClick(right)
    eq(g.ns.NavFocus("MerchantFrame"), 2, "the click itself moved one cell right (no double move)")
    eq(g.ns.NAV_MAPS["MerchantFrame"].controls[g.ns.NavFocus("MerchantFrame")].id, "MerchantItem2ItemButton", "the highlight moved RIGHT within the item rows")
    -- left steps back:
    local left = g.env["UbermocForeverNavMover_MerchantFrame_left"]
    left.__scripts.OnClick(left)
    eq(g.ns.NAV_MAPS["MerchantFrame"].controls[g.ns.NavFocus("MerchantFrame")].id, "MerchantItem1ItemButton", "and back left")
    -- at the edge of what is shown the move refuses (slot to the LEFT of slot 1 does not exist):
    falsy(g.ns.NavGridMove("MerchantFrame", -1), "no cell left of column 1: the key stays the game's own")
    -- a window with no grid at all refuses the move (the key stays the game's own):
    falsy(g.ns.NavGridMove("Nope", 1), "no navigated window: no grid move")
end)

-- A real SecureActionButton in the fake world: the universal stub would "accept" SetAttribute but keep
-- nothing, so this test frame records attributes and answers GetAttribute honestly - that is what claim()
-- must use to point PAD1 at the right gossip frame.
local function secureProxy(g, name)
    local b = g.env.CreateFrame("Button", name)
    b.__attrs = {}
    -- claim() reads the old value back with GetAttribute before overwriting it (it never re-arms a proxy
    -- that already carries THIS frame), so the fake must answer honestly: real frames do. Instance keys
    -- beat the universal stub, so plain assignments are enough.
    b.SetAttribute = function(self, key, v) self.__attrs[key] = v end
    b.GetAttribute = function(self, key) return self.__attrs[key] end
    -- nothing else needed: CreateFrame already registered the name as a global and Nav's proxyFor()
    -- prefers an existing global over creating its own button
    return b
end

test("gossip-map-no-nil-key-crash", "R-2.3", "gossip with UNNAMED option frames and an unnamed Goodbye builds a map without the crash the probe recorded (Nav.lua:177: table index is nil)", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    -- fake Blizzard scrollbox with three UNNAMED option buttons + unnamed GoodbyeButton. Unnamed in the
    -- fake world = a frame whose GetName returns "" (real gossip elements have no global name at all).
    local function anon(shown)
        local f = g.env.CreateFrame("Button")
        f.GetName = function() return "" end
        f.GetText = function() return "option" end
        f.IsShown = function() return shown and true or false end
        f.IsEnabled = function() return true end   -- unknown fake methods answer a truthy stub; be explicit
        return f
    end
    local box = g.env.CreateFrame("Frame")
    local parent = g.env.CreateFrame("Frame")
    parent.GoodbyeButton = anon(true)
    parent.GoodbyeButton.GetText = function() return "Goodbye" end
    box.GetParent = function() return parent end
    local els = { anon(true), anon(false), anon(true) }   -- the middle one hidden
    box.GetFrames = function() return els end
    g.env.UbermocForeverGossipScrollBox = function() return box end   -- Nav reads this test hook
    g.login(true)
    local map = g.ns.NAV_MAKERS["GossipFrame"]()   -- the exact call that crashed in the user's game
    truthy(map, "the gossip map exists now (no table index is nil)")
    eq(#map.controls, 3, "two shown options + Goodbye; the hidden one is skipped")
    local named = 0
    for _, c in ipairs(map.controls) do if c.secure then named = named + 1 end end
    eq(named, 3, "every control carries its frame directly (none of them has a name)")
    truthy(map.close, "the map knows its close control")
    local cc
    for _, c in ipairs(map.controls) do if c.id == map.close then cc = c end end
    eq(cc.secure, parent.GoodbyeButton, "close is the Goodbye frame itself")
end)

test("gossip-claims-use-secure-proxy", "R-2.3", "PAD1/PAD2 on unnamed gossip controls claim OUR SecureActionButton proxies carrying the frame (Blizzard's clickbutton pattern)", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    local f = g.env.CreateFrame("Frame", "GossipFrame")   -- a real test frame: claims need a valid owner
    f.IsShown = function() return rawget(f, "__shown") and true or false end
    local function anon(text)
        local b = g.env.CreateFrame("Button")
        b.GetName = function() return "" end
        b.GetText = function() return text end
        b.IsShown = function() return true end
        b.IsEnabled = function() return true end   -- the fake world's unknown methods answer a truthy stub: say plainly it is enabled
        return b
    end
    local box = g.env.CreateFrame("Frame")
    local parent = g.env.CreateFrame("Frame")
    parent.GoodbyeButton = anon("Goodbye")
    box.GetParent = function() return parent end
    local els = { anon("Quest"), anon("Trade") }
    box.GetFrames = function() return els end
    g.env.UbermocForeverGossipScrollBox = function() return box end   -- Nav reads this test hook
    -- pre-create our proxies as real frames so claim() can record attributes on them (the fake world's
    -- CreateFrame without the template does not model SetAttribute):
    secureProxy(g, "UbermocForeverNavProxy_GossipFrame")
    secureProxy(g, "UbermocForeverNavProxy_GossipFrame_close")
    g.login(true)
    g.show(f)   -- the game opening gossip: OnShow hook -> NavOpen
    eq(g.overrides.PAD1 and g.overrides.PAD1.action, "CLICK UbermocForeverNavProxy_GossipFrame", "PAD1 clicks our proxy (the option has no name to point at)")
    local proxy = g.env["UbermocForeverNavProxy_GossipFrame"]
    truthy(proxy, "the proxy button exists")
    eq(proxy.__attrs and proxy.__attrs.type, "clickbutton", "the proxy is armed as a secure clickbutton (Blizzard\'s pattern)")
    eq(proxy.__attrs and proxy.__attrs.clickbutton, els[1], "and it carries the highlighted option frame")
    eq(g.overrides.PAD2 and g.overrides.PAD2.action, "CLICK UbermocForeverNavProxy_GossipFrame_close", "PAD2 clicks the close proxy (Goodbye is unnamed too)")
    local p2 = g.env["UbermocForeverNavProxy_GossipFrame_close"]
    eq(p2.__attrs and p2.__attrs.clickbutton, parent.GoodbyeButton, "the close proxy carries the Goodbye frame")
    -- moving the highlight re-points the SAME proxy at the next option (PAD1 keeps pointing at the proxy):
    local mover = g.env["UbermocForeverNavMover_GossipFrame_down"]
    mover.__scripts.OnClick(mover)
    eq(proxy.__attrs.clickbutton, els[2], "the proxy now carries the second option")
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
