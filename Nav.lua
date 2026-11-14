-- Nav.lua: moving around the game's windows with the controller only (REQUIREMENTS.md R-2.3).
--
-- WHAT IT DOES: while a window we know how to navigate is open, the d-pad moves a visible highlight
-- between its controls, PAD1 activates the highlighted control, PAD2 closes or backs out, and a small
-- legend at the bottom of the window says which button does what (Blizzard's own strings, fonts and
-- atlas art only). This works in the vendor and NPC gossip windows too - Blizzard's own gamepad UI does
-- not navigate those (the user's request 2026-11-13: navigation "when you're looking at a vendor or
-- talking to an NPC").
--
-- HOW A BUTTON IS PRESSED WITHOUT FAKING INPUT (hard limit R-2.4: never automated keyboard/mouse input):
-- every navigation key is claimed with SetOverrideBindingClick(owner, true, KEY, buttonName) - the game's
-- own secure mechanism: pressing the key makes the ENGINE itself click that named Button. The d-pad keys
-- point at our own invisible mover Buttons (their OnClick moves the highlight); PAD1 points at whichever
-- control is highlighted right now and is re-pointed whenever the highlight moves; PAD2 points at the
-- window's close/back control. No mouse move, no injected click, no keyboard event: the engine performs
-- the click from a real button press.
-- (WHY NOT override ACTIONS: the Phase 1 in-game test proved SetOverrideBinding of plain actions on an
-- addon frame never fires in plain mode - Layout.lua header. CLICK claims are a different, engine-secure
-- path; whether they fire for PAD keys is proven by the user's in-game press test - Tests.lua.)
--
-- PURE LOGIC (kept apart from the glue so the Spec tests can drive it with the fake world):
--   ns.NavMap(window)                    -> { title, controls = { {id,label}... }, close = id }
--   ns.NavEnabled(window, control)       -> is that control pressable right now?
--   ns.NavMove(window, "up"|"down")      -> new highlight index (wraps; only enabled controls stoppable)
--   ns.NavActivate(window, control)      -> "press" | "close" | "none"
--   ns.NavFocus(window) / ns.NavForget(window)
-- The maps and the window watchers below are glue: they read real Blizzard frame names (verified in
-- Forever's shipped XML/Lua - see each cite) and draw the highlight/legend.
local addonName, ns = ...

-- The fake world's Blizzard frames are STUBS: any field read on them is a truthy stub, so scripts
-- recorded with HookScript land inside the stub and never fire. In the real game _G[window] is a Frame
-- the game created from XML BEFORE addons load - addon code never creates it; this branch exists ONLY
-- for tests, which set g.env.X = g.env.CreateFrame("Frame", "X") before PLAYER_LOGIN (see
-- Spec/R-2.3-window-nav.lua). The fake world's g.show/g.hide fire scripts recorded via SetScript, so
-- the hook below is a plain SetScript; the real game keeps its own OnShow handler untouched.
local function ensureTestFrame(name)
	if rawget(_G, name) ~= nil then return end   -- a real Frame (or one the test created): leave it alone
	if _G[name] ~= _G.stub then return end       -- the fake world exposes its stub; the real game has no such global
	local f = CreateFrame("Frame", name)         -- replace the fake world's stub with a real test frame
	f.IsShown = function() return rawget(f, "__shown") and true or false end
end

--------------------------------------------------------------
-- Pure model
--------------------------------------------------------------

local focus = {}   -- window -> index
-- (defined below with the glue): re-points the navigation keys of a navigated window at its current
-- highlight. NavMove calls it through this forward declaration when the window is being navigated.
local claim


function ns.NavMap(window) return ns.NAV_MAPS and ns.NAV_MAPS[window] end

-- A control is pressable when its Button exists, is shown and not disabled. Our OWN frames (the bind
-- screen) are real in every world, so asking them works everywhere. Blizzard's windows in the FAKE world
-- are stubs that cannot answer honestly, so tests inject their truth via a FUNCTION
-- g.env.UbermocForeverNavProbe = function(id) ... end (see Spec/R-2.3-window-nav.lua); in the real game
-- nothing ever sets that global and the frame question below is used.
-- Enabled state comes from IsEnabled (a documented Button method, SimpleButtonAPIDocumentation.lua:257
-- "IsEnabled" returns isEnabled bool; Blizzard's own SmartNavigation checks the same way -
-- Blizzard_GamepadSmartNavigation/Utility.lua:222-223 "if (currentButton.IsEnabled) then
-- isEnabled = currentButton:IsEnabled(); end"). A control with no callable answer counts as enabled, like them.
local function frameEnabled(x)
	if not x then return false end
	local fn = x.IsEnabled
	if type(fn) ~= "function" then return true end   -- the fake world's stub answers a stub, not callable
	return fn(x) and true or false
end

local ourOwnFrames = {}   -- window -> true for windows WE create (the bind screen)

local proxies = {}   -- window -> our proxy Button (one per navigated window)
local function proxyFor(window)
	-- A test may pre-create the proxy (the fake world's CreateFrame cannot model SetAttribute on a
	-- SecureActionButtonTemplate); in the game nothing sets this global.
	local b = _G[addonName .. "NavProxy_" .. window] or proxies[window]
	if not b then
		b = CreateFrame("Button", addonName .. "NavProxy_" .. window, UIParent, "SecureActionButtonTemplate")
		b:SetSize(1, 1); b:Hide()
	end
	proxies[window] = b
	return b
end

function ns.NavEnabled(window, control)
	local map = ns.NavMap(window)
	if not map or not control then return false end
	-- A control that carries its frame directly (an UNNAMED Blizzard frame: gossip options/Goodbye):
	-- ask the frame itself; there is no global name to look up.
	local b = control.secure or _G[control.id]
	-- Our own window's controls (the bind screen rows/buttons) are real frames in every world: ask them.
	if ourOwnFrames[window] and b ~= nil and b ~= _G.stub then
		return (b.IsShown and b:IsShown() and frameEnabled(b)) and true or false
	end
	local probe = _G[addonName .. "NavProbe"]
	if type(probe) == "function" then return probe(control.id) and true or false end
	return (b and b.IsShown and b:IsShown() and frameEnabled(b)) and true or false
end

function ns.NavFocus(window)
	local f = focus[window]
	return f and f.index or 1
end

function ns.NavSetFocus(window, index)
	focus[window] = { index = index }
	return index
end

-- Move the highlight: walk in direction (wrapping), skipping controls that cannot be pressed. If none is
-- enabled the highlight stays where it is. Returns the new index. Re-pointing PAD1 at the NEW control is
-- done by whoever acts on the move (the mover Button's OnClick calls claim right after this) - keeping
function ns.NavMove(window, direction)
	local map = ns.NavMap(window)
	if not map or not map.controls or #map.controls == 0 then return ns.NavFocus(window) end
	local n = #map.controls
	local i = ns.NavFocus(window)
	for _ = 1, n do
		i = i + (direction == "down" and 1 or -1)
		if i > n then i = 1 elseif i < 1 then i = n end
		if ns.NavEnabled(window, map.controls[i]) then
			focus[window] = { index = i }
			return i
		end
	end
	return ns.NavFocus(window)
end

-- PAD1 decision for the highlighted control.
function ns.NavActivate(window, control)
	local map = ns.NavMap(window)
	if not map or not control then return "none" end
	if not ns.NavEnabled(window, control) then return "none" end
	if map.close and control.id == map.close then return "close" end
	return "press"
end

function ns.NavForget(window) focus[window] = nil end

--------------------------------------------------------------
-- The maps (glue). Only windows listed here are navigated; an unmapped window changes nothing.
-- Every button name below was read from Blizzard's shipped Forever source (cite on each map).
--------------------------------------------------------------

ns.NAV_MAPS = {}     -- window -> current map, rebuilt when the window opens
ns.NAV_MAKERS = {}   -- window -> function building its map (filled at PLAYER_LOGIN)

-- The vendor window. Names from Blizzard_UIPanels_Game/Vanilla/MerchantFrame.xml:
--   :488 MerchantFrameTab1 (MERCHANT), :505 MerchantFrameTab2 (BUYBACK);
--   the frame inherits ButtonFrameTemplate, whose close button is "<FrameName>CloseButton"
--   (Blizzard_SharedXML/ButtonFrameTemplates - verified at runtime by looking the name up).
-- ITEM SLOTS were missing from the first map: the user's in-game test 2026-11-13 ("the d-pad goes left
-- and right through the two tabs, it doesn't go into the actual inventory"). The slots are named frames
-- MerchantItem1..MerchantItem12 (Vanilla/MerchantFrame.xml:142-207), each with a Button child
-- "<slot>ItemButton" (:28 parentKey="ItemButton") - that Button is what gets clicked. Buyback has ONE
-- slot: MerchantBuyBackItemItemButton (:344 + the same :372 parentKey ItemButton). NavEnabled skips
-- hidden and disabled frames, so each tab offers exactly the slots on screen right now.
-- Grid: slot i sits at row = ceil(i/2), column = 1 for odd i, 2 for even (xml anchors: :149 places
-- MerchantItem2 to the RIGHT of MerchantItem1, :154 places MerchantItem3 BELOW MerchantItem1).
local function merchantMap()
	local controls = {}
	-- one control per item slot: the slot's ItemButton (the click target). The window is TWO columns of
	-- six (xml anchors :149/:154); listing them in number order gives a sane serpentine walk. The probe
	-- proved the real game clicks these names.
	for i = 1, 12 do
		local btn = "MerchantItem" .. i .. "ItemButton"
		if _G[btn] then
			local nameText = _G["MerchantItem" .. i .. "Name"]
			controls[#controls + 1] = { id = btn, label = nameText and nameText:GetText() or nil, grid = { row = math.ceil(i / 2), col = (i % 2 == 1) and 1 or 2 } }
		end
	end
	if _G["MerchantBuyBackItemItemButton"] then
		controls[#controls + 1] = { id = "MerchantBuyBackItemItemButton", label = BUYBACK or "Buyback" }
	end
	-- tabs LAST (user 2026-11-13: the walk used to circle only the two tabs and never reach the
	-- inventory): opening a window highlights its FIRST enabled control, so items come first now.
	for _, name in ipairs({ "MerchantFrameTab1", "MerchantFrameTab2" }) do
		if _G[name] then controls[#controls + 1] = { id = name, label = _G[name].text } end
	end
	local closeName = "MerchantFrameCloseButton"
	if _G[closeName] then controls[#controls + 1] = { id = closeName, label = CLOSE or "Close" } end
	return { title = MERCHANT_NAME or "Merchant", controls = controls, close = closeName }
end

-- The NPC gossip window. Blizzard_UIPanels_Game/Shared/GossipFrameShared.lua:150-157 shows the option
-- rows are scrollbox elements created from GossipTitleOptionButtonTemplate / ...ActiveQuest... /
-- ...AvailableQuest... templates - they have NO stable global names, so we read them live from
-- GossipFrame.GreetingPanel.ScrollBox:GetFrames() (the game's own call, used the same way at
-- Blizzard_UIPanels_Game/Mainline/GossipFrame.lua:78). Each element is a Button.
-- GOODBYE (the window's back/close control) is GossipFrame.GreetingPanel.GoodbyeButton
-- (Blizzard_UIPanels_Game/Mainline/GossipFrame.xml:51).
-- WHY THE OLD MAP CRASHED (probe 2026-11-13, the exact error from the user's game):
--   Nav.lua:177: table index is nil - GoodbyeButton is an UNNAMED frame (parentKey="GoodbyeButton",
--   xml :51), so GetName() returned nil and gossipElements[nil] blew up; the map never existed, so the
--   gossip window had no navigation at all. The same is likely true of the scrollbox elements.
-- FIX: unnamed frames are keyed by a lightuserdata key (tostring(frame)) instead of their name, and
-- PAD1/PAD2 point at our OWN SecureActionButton which carries the frame in its "clickbutton" attribute
-- (Blizzard's own pattern: Blizzard_FrameXML/SecureTemplates.lua:557-562 "SECURE_ACTIONS.click = ...
-- SecureButton_GetModifiedAttribute(self, \"clickbutton\", button); ... delegate:Click(button);" - the
-- engine clicks the frame we hand it). Named controls keep SetOverrideBindingClick.
-- The scrollbox whose option rows we read, and the Goodbye button. A test may replace this function to
-- hand us its own fake scrollbox (Spec/R-2.3-window-nav.lua); in the game it always resolves to Blizzard's.
ns.NavGossipScrollBox = function()
	-- A test may hand us its own scrollbox through this global (the fake world's Blizzard frames are
	-- stubs that cannot host a real scrollbox); in the game nothing ever sets it.
	local override = _G[addonName .. "GossipScrollBox"]
	if type(override) == "function" then return override() end
	local f = _G.GossipFrame
	return f and f.GreetingPanel and f.GreetingPanel.ScrollBox
end
local function gossipMap()
	gossipElements = {}
	local controls = {}
	local closeID
	local box = ns.NavGossipScrollBox()
	local frames = (box and type(box.GetFrames) == "function") and box:GetFrames() or nil
	if frames then
		for _, el in ipairs(frames) do
			if el.IsShown and el:IsShown() and frameEnabled(el) then
				local name = el.GetName and el:GetName()
				if name and name ~= "" then
					gossipElements[name] = el
					controls[#controls + 1] = { id = name, label = el.GetText and el:GetText() or nil }
				else
					local key = tostring(el)   -- lightuserdata key: unique, never nil
					gossipElements[key] = el
					controls[#controls + 1] = { id = key, secure = el, label = el.GetText and el:GetText() or nil }
				end
			end
		end
	end
	-- The Goodbye control: on the scrollbox's OWN parent when one was supplied (a test's fake can put it
	-- there), defaulting to Blizzard's path.
	local goodbye = (box and type(box.GetParent) == "function" and box:GetParent() and box:GetParent().GoodbyeButton)
		or (_G.GossipFrame and _G.GossipFrame.GreetingPanel and _G.GossipFrame.GreetingPanel.GoodbyeButton)
	if goodbye then
		local name = goodbye.GetName and goodbye:GetName()
		if name and name ~= "" then
			gossipElements[name] = goodbye
			controls[#controls + 1] = { id = name, label = GOODBYE or "Goodbye" }
			closeID = name
		else
			local key = tostring(goodbye)
			gossipElements[key] = goodbye
			controls[#controls + 1] = { id = key, secure = goodbye, label = GOODBYE or "Goodbye" }
			closeID = key
		end
	end
	return { title = GOSSIP_HEADER or "Gossip", controls = controls, close = closeID }
end

ns.RegisterNavWindow = function(window, maker) ns.NAV_MAKERS[window] = maker end   -- replaced below by the version that also attaches watchers

-- Attach our open/close watchers to one window frame. HookScript in the real game (never replace
-- Blizzard's own handler); plain SetScript on frames WE created (our bind screen, test frames) whose
-- show/hide fire recorded scripts. Returns false when the frame does not exist (yet).
-- A window frame that does not exist YET (our bind screen before it is first created; also the fake
-- world's truthy stubs) must be refused: writing scripts into a stub "succeeds" but never fires, and
-- marking such a window as ours would poison NavEnabled. The owner registers again when the real frame
-- is created (Bind.CreateBindUI calls ns.NavWatchOwn).
local function validOwner(window)
	local f = _G[window]
	return f ~= nil and type(f.HookScript) == "function"   -- the fake world's stub answers every method with the SAME universal stub: `f.HookScript` is not a function there, so stubs are refused.
end

local function attachWatchers(window)
	if not validOwner(window) then return false end
	local f = _G[window]
	-- A frame WE created (our bind screen, or a test frame) answers GetName with its own name; the
	-- fake world's stub answers "<stub>" for everything, and Blizzard's real XML frames answer their
	-- name but already have Blizzard's OnShow handler we must not replace. Only our own frames get a
	-- plain SetScript (their show/hide fire recorded scripts in every world).
	if f.GetName and f:GetName() == window then
		f:SetScript("OnShow", function() ns.NavOpen(window) end)
		f:SetScript("OnHide", function() ns.NavClose(window) end)
	else
		f:HookScript("OnShow", function() ns.NavOpen(window) end)
		f:HookScript("OnHide", function() ns.NavClose(window) end)
	end
	return true
end

ns.RegisterNavWindow = function(window, maker)
	ns.NAV_MAKERS[window] = maker
	attachWatchers(window)   -- covers frames that appear AFTER PLAYER_LOGIN (our bind screen)
end

--------------------------------------------------------------
-- The glue: claims, highlight, legend, watchers
--------------------------------------------------------------

local navigating = {}          -- window -> map currently navigated
-- Probe support (Probe.lua reads these; they change nothing): how often our NavOpen ran for a window,
-- and whether that window is being navigated right now.
ns.NavOpenCount = ns.NavOpenCount or {}
function ns.NavIsNavigating(window) return navigating[window] ~= nil end
local topOrder = {}            -- insertion order of opened windows (the last shown one is on top)

local function topOrderSeen(name)
	for i, n in ipairs(topOrder) do if n == name then table.remove(topOrder, i) return true end end
	return false
end

-- Invisible mover Buttons: the d-pad keys CLICK these (secure path), their OnClick moves the highlight.
local movers = {}
-- One invisible mover PER WINDOW AND DIRECTION: a shared Button would report topWindow() at click time,
-- which is not necessarily the window being navigated when several are open (the game clicks the NAMED
-- button). LEFT/RIGHT movers exist too: inside a grid of controls (vendor item slots) left/right step
-- between columns - see ns.NavGridMove. A window without a grid hands left/right back to the game
-- (SetPropagateKeyboardInput(true), Blizzard's own pass-through method, used the same way by our bind
-- capture listener in Bind.lua).
local function makeMover(window, dir)
	if movers[window] and movers[window][dir] then return movers[window][dir] end
	local b = CreateFrame("Button", addonName .. "NavMover_" .. window .. "_" .. dir)
	b:SetSize(1, 1); b:Hide()
	-- ONE move per press (user 2026-11-13 round 4: the d-pad "goes up down left right left right" - one
	-- press moved the highlight several times). The OLD mover had TWO handlers, OnKeyDown AND OnClick, and
	-- a single key press could fire BOTH paths = two moves. Now there is exactly ONE handler: OnClick.
	b:SetScript("OnClick", function()
		if not navigating[window] then return end
		if dir == "left" or dir == "right" then
			-- Inside a grid of controls (vendor item slots) left/right step BETWEEN COLUMNS; everywhere
			-- else they move the list highlight like up/down do. NavMove only stops on enabled controls,
			-- so an edge never strands the highlight and no key is ever "wasted".
			if not ns.NavGridMove(window, dir == "left" and -1 or 1) then
				ns.NavMove(window, dir)
			end
		else
			ns.NavMove(window, dir)
		end
		claim(window, navigating[window])   -- PAD1 must now point at the NEW highlighted control
		ns.NavDraw(window)
	end)
	movers[window] = movers[window] or {}
	movers[window][dir] = b
	return b
end

-- Grid navigation (vendor item slots): controls carry grid = { row, col } - see merchantMap. While the
-- highlight sits on a grid control, each d-pad direction steps one cell IN THAT DIRECTION inside the
-- grid: the walk stays in the item area and never wanders over the tabs while you browse items (user
-- 2026-11-13: "it doesn't go into the actual inventory"). Outside a grid control, up/down use the plain
-- list walk and left/right stay the game's own keys. PAD2 always clicks the window's close control.
local function gridStep(map, i, drow, dcol)
	local c = map.controls[i]
	if not c or not c.grid then return nil end
	for j = 1, #map.controls do
		local o = map.controls[j]
		if o.grid and o.grid.row == c.grid.row + drow and o.grid.col == c.grid.col + dcol then return j end
	end
	return nil
end

function ns.NavGridMove(window, dcol)
	local map = navigating[window]
	if not map then return false end
	local i = ns.NavFocus(window)
	local j = gridStep(map, i, 0, dcol)
	if not j then return false end
	ns.NavSetFocus(window, j)
	claim(window, map)
	ns.NavDraw(window)
	return true
end

-- Our own secure click proxy: PAD1/PAD2 normally point at a NAMED control through
-- SetOverrideBindingClick. An UNNAMED frame (gossip options, GoodbyeButton) has no name to point at, so
-- the key points at THIS Button instead and we hand it the frame in its "clickbutton" attribute -
-- Blizzard's own secure pattern (Blizzard_FrameXML/SecureTemplates.lua:557-562: SECURE_ACTIONS.click
-- reads the "clickbutton" attribute and calls delegate:Click(button)). The engine performs the click;
-- we never fake input.
claim = function(window, map)
	if not validOwner(window) then return end   -- no real frame (or the fake world's stub): nothing to claim on
	local owner = _G[window]
	local proxy = proxyFor(window)
	proxy:SetAttribute("type", nil)   -- idle until a secure control is highlighted
	local i = ns.NavFocus(window)
	local c = map.controls[i]
	if c and c.secure then
		SetOverrideBindingClick(owner, true, "PAD1", proxy:GetName())
		proxy:SetAttribute("type", "clickbutton")
		proxy:SetAttribute("clickbutton", c.secure)
	elseif c and _G[c.id] then
		SetOverrideBindingClick(owner, true, "PAD1", c.id)
	end
	for _, dir in ipairs({ "up", "down", "left", "right" }) do
		local key = ({ up = "PADDUP", down = "PADDDOWN", left = "PADDLEFT", right = "PADDRIGHT" })[dir]
		local mover = makeMover(window, dir)
		-- The mover STEERS the highlight for every navigated window now (left/right fall back to the list
		-- walk when there is no grid), so it must never ALSO let the game run its own binding for that key:
		-- one key press = exactly one move (user 2026-11-13 round 4). SetPropagateKeyboardInput(false) keeps
		-- the click ours only - Blizzard's own pass-through method (SimpleFrameAPIDocumentation.lua:1426).
		if mover.SetPropagateKeyboardInput then   -- real-game method; the fake world's frames do not have it
			mover:SetPropagateKeyboardInput(false)
		end
		SetOverrideBindingClick(owner, true, key, mover:GetName())
	end
	if map.close then
		local cc
		for _, o in ipairs(map.controls) do if o.id == map.close then cc = o break end end
		if cc and cc.secure then
			-- PAD2 on an unnamed close control: a SECOND proxy (PAD1's proxy points at the highlight).
			local p2 = proxyFor(window .. "_close")   -- same lookup as PAD1's proxy, incl. the test hook
			p2:SetAttribute("type", "clickbutton")
			p2:SetAttribute("clickbutton", cc.secure)
			SetOverrideBindingClick(owner, true, "PAD2", p2:GetName())
		elseif _G[map.close] then
			SetOverrideBindingClick(owner, true, "PAD2", map.close)
		end
	end
end

function ns.ClearNavClaims(window)
	local owner = _G[window]
	if owner and not InCombatLockdown() then ClearOverrideBindings(owner) end
	-- idle our proxies too: a key that is no longer claimed must never click an old frame.
	if proxies[window] then proxies[window]:SetAttribute("type", nil) end
	if proxies[window .. "_close"] then proxies[window .. "_close"]:SetAttribute("type", nil) end
end

-- Which window is navigated right now: the last opened that is still shown.
local function topWindow()
	local best
	for _, name in ipairs(topOrder) do
		local f = _G[name]
		if navigating[name] and f and f:IsShown() then best = name end
	end
	return best
end
ns.NavTopWindow = topWindow

function ns.NavOpen(window, options)
	-- Navigation in windows is ALWAYS on (user 2026-11-13: "that should happen automatically"): there is
	-- no navWindows setting any more; a stale saved value is deleted by Options.lua on load.
	local maker = ns.NAV_MAKERS[window]
	if not maker or InCombatLockdown() then return end   -- unmapped window / combat: change nothing
	-- The probe wraps maker calls in pcall to record the game's real errors; our own call is wrapped too,
	-- so a failing map can never leave the watcher half-done or spam the error log.
	local ok, map = pcall(maker)
	if not ok then
		ns:Debug("nav map failed for", window, tostring(map))
		ns.NAV_MAPS[window] = nil
		navigating[window] = nil
		ns.ClearNavClaims(window)
		return
	end
	if not map then
		ns.NAV_MAPS[window] = nil
		navigating[window] = nil
		ns.ClearNavClaims(window)
		return   -- the maker declined to map this window right now: change nothing
	end
	ns.NavOpenCount[window] = (ns.NavOpenCount[window] or 0) + 1
	ns.NAV_MAPS[window] = map
	navigating[window] = map
	topOrderSeen(window)              -- remove any stale entry, then re-add at the top
	topOrder[#topOrder + 1] = window
	-- start on the first ENABLED control (line 12-style snap comes in a later phase); a grid caller may
	-- ask for a specific index (options.index - see ns.NavGridMove) and we keep it when pressable.
	local idx = 1
	if options and options.index and ns.NavEnabled(window, map.controls[options.index]) then
		idx = options.index
	else
		for i, c in ipairs(map.controls) do if ns.NavEnabled(window, c) then idx = i break end end
	end
	ns.NavSetFocus(window, idx)
	claim(window, map)
	ns.NavDraw(window)
end

function ns.NavClose(window)
	if not navigating[window] then return end
	navigating[window] = nil
	ns.NAV_MAPS[window] = nil
	ns.NavForget(window)
	ns.ClearNavClaims(window)
	ns.NavErase(window)
	for i, n in ipairs(topOrder) do if n == window then table.remove(topOrder, i) break end end
end

-- (The per-window mover Buttons do the move themselves; their OnClick is above, next to claim().)

-- A GOSSIP_UPDATE-style refresh: gossip content changed while the window stayed open. The NEW list of
-- options starts highlighted at the TOP (index 1): after picking an option the old highlight index would
-- point at a different or missing row (the user's in-game flow 2026-11-13: pressing A inside gossip).
ns.NavRefresh = function(window)
	if navigating[window] then ns.NavOpen(window, { index = 1 }) end
end

--------------------------------------------------------------
-- The highlight + legend (glue, Blizzard art only)
--------------------------------------------------------------

local overlays = {}   -- window -> our overlay frame

-- The frame a control addresses: secure controls carry it directly (unnamed Blizzard frames); named
-- controls are globals.
local function controlFrame(c)
	return c.secure or _G[c.id]
end

-- What a control is CALLED, for the highlight's label/narration: our own label from the map maker first
-- (merchant item names, gossip option text), else the frame's own text. A control with no name returns
-- nil - narration says nothing rather than guessing. Defined right after controlFrame because NavDraw
-- below calls it. The makers fill c.label: merchantMap reads MerchantItem<N>Name, gossipMap reads each
-- option's GetText (Blizzard_UIPanels_Game/Shared/GossipFrameShared.lua builds those rows).
local function labelFor(c)
	if c.label and c.label ~= "" then return c.label end
	local b = controlFrame(c)
	if b and b.GetText and type(b.GetText) == "function" then
		local ok, t = pcall(b.GetText, b)
		if ok and type(t) == "string" and t ~= "" then return t end
	end
end
ns.NavLabelFor = labelFor

function ns.NavDraw(window)
	local map = ns.NAV_MAPS[window]
	if not map then return end
	local host = _G[window]
	if not host then return end
	local ov = overlays[window]
	if not ov then
		ov = CreateFrame("Frame", addonName .. "NavOverlay_" .. window, host)
		ov:EnableMouse(false)
		overlays[window] = ov
	end
	ov:ClearAllPoints()
	ov:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
	ov:SetSize(1, 1)   -- children do the drawing; a 1x1 frame never blocks mouse

	if not ov.lines then
		ov.lines = {}
		local legend = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		legend:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 10, 6)
		ov.legend = legend
	end
	-- one highlight per control (Blizzard's own button-highlight texture), only the focused one shown.
	-- Pressability comes from the model (NavEnabled), NOT from IsShown: a tab that is already on the
	-- shown page is drawn even though the real map only lists pressable controls at open time.
	local focusName
	for i, c in ipairs(map.controls) do
		local line = ov.lines[i]
		if not line then
			line = ov:CreateTexture(nil, "OVERLAY")
			line:SetTexture("Interface\\Buttons\\ButtonHilight-Square")   -- Blizzard's own highlight art
			line:SetBlendMode("ADD")
			ov.lines[i] = line
		end
		local b = controlFrame(c)   -- a secure control carries its frame; named controls look up the global
		if b and ns.NavEnabled(window, c) then
			line:ClearAllPoints()
			line:SetPoint("CENTER", b, "CENTER", 0, 0)
			line:SetSize((b.GetWidth and b:GetWidth() or 20) + 6, (b.GetHeight and b:GetHeight() or 16) + 6)
			line:SetShown(i == ns.NavFocus(window))
			if i == ns.NavFocus(window) then focusName = labelFor(c) end
		else
			line:SetShown(false)
		end
	end
	ov.legend:SetText((PAD1 or "PAD1") .. ": select   " .. (PAD2 or "PAD2") .. ": close   d-pad: move")
	if focusName and ns.Speak then ns.Speak(focusName) end   -- narration of what is highlighted (see below)
end

-- NARRATION (user 2026-11-13 round 4: "narrating in menus doesn't work"). Blizzard's own screen
-- narration CANNOT run here at all: NarrationUtil.ShouldBeEnabled() is TRUE ONLY on glue screens -
-- Blizzard_Narration/Blizzard_NarrationUtil.lua:122 "return CVarCallbackRegistry:GetCVarValueBool(\"accessibilityScreenNarrationEnabled\") and C_Glue.IsOnGlueScreen();" - so in
-- the game its Narration.Speak event has no listener and nothing is ever said. We speak the highlighted
-- control OURSELVES through C_VoiceChat.SpeakText, with the player's own narration settings (the same
-- CVars Blizzard's NarrationManager reads, Blizzard_Narration/Blizzard_NarrationManager.lua:26-28), but
-- only when the "Enable Screen Reader" accessibility setting is on. SpeakText's exact shape comes from
-- Blizzard's own call at NarrationManager.lua:28 "C_VoiceChat.SpeakText(voiceID, text, speechRate,
-- speechVolume);". Everything is pcall-guarded: if a name or call does not exist in this build, we say
-- nothing and change nothing else.
-- Read a narration CVar as a NUMBER. Blizzard's own way is GetCVarNumberOrDefault (used at
-- Blizzard_NarrationManager.lua:26-28 and AccessibilityTemplates.lua:42); we wrap it so a missing global
-- or a missing setting falls back to the default instead of erroring.
local function cvarNumber(name, default)
	local ok, v = pcall(GetCVarNumberOrDefault, name)
	if not ok or type(v) ~= "number" then return default end
	return v
end

function ns.NarrateEnabled()
	-- the CVar Blizzard gates narration on (Blizzard_NarrationUtil.lua:122 reads it with GetCVarValueBool;
	-- the same setting is the "Enable Screen Reader" checkbox, AudioAssist.lua:64). GetCVar returns "1"/"0".
	local ok, on = pcall(GetCVar, "accessibilityScreenNarrationEnabled")
	return ok and (on == 1 or on == "1" or on == true)
end

local lastSpoken
function ns.Speak(text)
	if not text or text == "" then return end
	if not ns.NarrateEnabled() then return end
	-- the player's own voice/rate/volume settings - the same three CVars Blizzard reads at
	-- Blizzard_NarrationManager.lua:26-27 before its SpeakText call (:28). Defaults 0,0,0 if one is missing.
	local voice = cvarNumber("accessibilityScreenNarrationVoice", 0)
	local rate = cvarNumber("accessibilityScreenNarrationSpeechRate", 0)
	local volume = cvarNumber("accessibilityScreenNarrationSpeechVolume", 0)
	text = tostring(text):gsub("|c%x+", ""):gsub("|r", "")   -- strip colour codes so the voice never reads them
	if text == lastSpoken then return end   -- a held d-pad key may fire fast; never repeat the same word twice in a row
	lastSpoken = text
	pcall(C_VoiceChat.StopSpeakingText)    -- interrupt what was being said, exactly like Blizzard_NarrationManager.lua:105
	pcall(C_VoiceChat.SpeakText, voice, text, rate, volume)   -- the documented 4-arg shape (VoiceChatDocumentation.lua:871-874; overlap defaults false)
end

function ns.NavErase(window)
	local ov = overlays[window]
	if ov then
		for _, line in ipairs(ov.lines or {}) do line:SetShown(false) end
		if ov.legend then ov.legend:SetText("") end
	end
end

--------------------------------------------------------------
-- Window watchers (glue): open/close of the windows we map.
--------------------------------------------------------------

ns:RegisterEvent("PLAYER_LOGIN", function()
	ns.RegisterNavWindow("MerchantFrame", merchantMap)
	ns.RegisterNavWindow("GossipFrame", gossipMap)
	-- our own bind screen (R-2.2): registered later than this event handler (Bind.lua loads after Nav.lua),
	-- so it registers itself from Bind's own PLAYER_LOGIN handler via ns.RegisterNavWindow.
	for window in pairs(ns.NAV_MAKERS) do
		ensureTestFrame(window)   -- no-op in the real game; makes the fake world's stub a real frame
		attachWatchers(window)    -- windows whose frames already exist at login (vendor, gossip)
	end
end)

-- A window WE create later than PLAYER_LOGIN (our bind screen) registers itself with us at creation:
-- NavWatchOwn attaches the watchers and marks the frame as ours, so NavEnabled asks its buttons
-- directly instead of through a test probe. (Blizzard's own windows exist before addons load; they are
-- watched by the PLAYER_LOGIN loop above and never marked own.)
function ns.NavWatchOwn(window)
	local f = _G[window]
	if not f then return false end
	ourOwnFrames[window] = true
	return attachWatchers(window)
end
-- Gossip content changes without the window closing (option picked, quest turned in): rebuild.
-- The event names come from Blizzard's own documentation: GOSSIP_SHOW and GOSSIP_OPTIONS_REFRESHED
-- (Blizzard_APIDocumentationGenerated/GossipInfoDocumentation.lua:271, :277).
ns.GOSSIP_EVENTS = { "GOSSIP_SHOW", "GOSSIP_OPTIONS_REFRESHED" }
for _, event in ipairs(ns.GOSSIP_EVENTS) do
	ns:RegisterEvent(event, function() if navigating.GossipFrame then ns.NavRefresh("GossipFrame") end end)
end

-- The vendor tab changed (MERCHANT <-> BUYBACK): which item slots are SHOWN differs per tab, so the map
-- is rebuilt and the highlight starts at the top of the new list. A tab click fires no event we can see,
-- so we hook the tab buttons' OnClick directly (their names: Vanilla/MerchantFrame.xml:488,:505) and
-- rebuild one frame later, when the game has shown the new slots. MERCHANT_SHOW re-maps when the window
-- opens again.
ns:RegisterEvent("MERCHANT_SHOW", function() if navigating.MerchantFrame then ns.NavRefresh("MerchantFrame") end end)

local function watchTabs()
	for _, name in ipairs({ "MerchantFrameTab1", "MerchantFrameTab2" }) do
		local b = _G[name]
		if b and b.HookScript then
			b:HookScript("OnClick", function()
				C_Timer.After(0, function()
					if navigating.MerchantFrame then ns.NavOpen("MerchantFrame", { index = 1 }) end
				end)
			end)
		end
	end
end
ns:RegisterEvent("PLAYER_LOGIN", watchTabs)
