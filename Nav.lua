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
local ourOwnFrames = {}   -- window -> true for windows WE create (the bind screen)

function ns.NavEnabled(window, control)
	local map = ns.NavMap(window)
	if not map or not control then return false end
	local b = _G[control.id]
	-- Our own window's controls (the bind screen rows/buttons) are real frames in every world: ask them.
	if ourOwnFrames[window] and b ~= nil and b ~= _G.stub then
		-- A real Button answers IsDisabled with a FUNCTION; the fake world's universal stub answers with
		-- another stub (truthy but not callable). Require the answer to be a function before calling it,
		-- otherwise a stubbed method would throw and every control would look unpressable.
		local disabledFn = b.IsDisabled
		local disabled = type(disabledFn) == "function" and b:IsDisabled() or false
		return (b.IsShown and b:IsShown() and not disabled) and true or false
	end
	local probe = _G[addonName .. "NavProbe"]
	if type(probe) == "function" then return probe(control.id) and true or false end
	return (b and b.IsShown and b:IsShown() and not (b.IsDisabled and b:IsDisabled())) and true or false
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
local function merchantMap()
	local controls = {}
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
-- Blizzard_UIPanels_Game/Mainline/GossipFrame.lua:78). Each element is a Button; we address it by its
-- instance name ($parent-numbered), falling back to our index if a frame has no name.
-- GOODBYE (the window's back/close control) is GossipFrame.GreetingPanel.GoodbyeButton
-- (Blizzard_UIPanels_Game/Mainline/GossipFrame.xml:51).
local gossipElements   -- live element frames of the open gossip window (refreshed on GOSSIP_SHOW)

function ns.NavGossipFrames()
	local f = _G.GossipFrame
	local box = f and f.GreetingPanel and f.GreetingPanel.ScrollBox
	if not box or not box.GetFrames then return nil end
	return box:GetFrames()
end

local function gossipMap()
	gossipElements = {}
	local controls = {}
	local frames = ns.NavGossipFrames()
	if frames then
		for _, el in ipairs(frames) do
			if el.IsShown and el:IsShown() and not (el.IsDisabled and el:IsDisabled()) then
				local name = el:GetName()
				if name and name ~= "" then
					gossipElements[name] = el
					controls[#controls + 1] = { id = name, label = el.GetText and el:GetText() or nil }
				end
			end
		end
	end
	local goodbye = _G.GossipFrame and _G.GossipFrame.GreetingPanel and _G.GossipFrame.GreetingPanel.GoodbyeButton
	if goodbye then
		gossipElements[goodbye:GetName()] = goodbye
		controls[#controls + 1] = { id = goodbye:GetName(), label = GOODBYE or "Goodbye" }
	end
	return { title = GOSSIP_HEADER or "Gossip", controls = controls, close = goodbye and goodbye:GetName() }
end

ns.RegisterNavWindow = function(window, maker) ns.NAV_MAKERS[window] = maker end   -- replaced below by the version that also attaches watchers

-- Attach our open/close watchers to one window frame. HookScript in the real game (never replace
-- Blizzard's own handler); plain SetScript on frames WE created (our bind screen, test frames) whose
-- show/hide fire recorded scripts. Returns false when the frame does not exist (yet).
local function attachWatchers(window)
	local f = _G[window]
	-- A window frame that does not exist YET (our bind screen before it is first shown; also the fake
	-- world's truthy stubs) must be refused: writing scripts into a stub "succeeds" but never fires,
	-- and marking such a window as ours would poison NavEnabled. The owner registers again when the
	-- real frame is created (Bind.ShowBindUI calls ns.NavWatchOwn).
	if not f or type(f.HookScript) ~= "function" then return false end   -- the fake world's stub answers every method with the SAME universal stub: `f.HookScript` is not a function there, so stubs are refused. Attaching to a stub would "succeed" but never fire; the owner registers again when its real frame is created (Bind.ShowBindUI calls ns.NavWatchOwn).
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
-- One invisible mover PER WINDOW: a shared Button would report topWindow() at click time, which is not
-- necessarily the window being navigated when several are open (the game clicks the NAMED button).
local function makeMover(window, dir)   -- one invisible mover PER WINDOW: a shared Button would report
	if movers[window] and movers[window][dir] then return movers[window][dir] end   -- topWindow() at click time, which is not necessarily the window being navigated. Created once per window (claim re-points at it by name).
	local b = CreateFrame("Button", addonName .. "NavMover_" .. window .. "_" .. dir)
	b:SetSize(1, 1); b:Hide()
	b:SetScript("OnClick", function()
		if not navigating[window] then return end
		ns.NavMove(window, dir)
		claim(window, navigating[window])   -- PAD1 must now point at the NEW highlighted control
		ns.NavDraw(window)
	end)
	movers[window] = movers[window] or {}
	movers[window][dir] = b
	return b
end

claim = function(window, map)
	local owner = _G[window]
	if not owner then return end
	ns.ClearNavClaims(window)
	local i = ns.NavFocus(window)
	local c = map.controls[i]
	if c and _G[c.id] then
		SetOverrideBindingClick(owner, true, "PAD1", c.id)
	end
	for _, dir in ipairs({ "up", "down" }) do
		SetOverrideBindingClick(owner, true, dir == "up" and "PADDUP" or "PADDDOWN", makeMover(window, dir):GetName())
	end
	if map.close and _G[map.close] then
		SetOverrideBindingClick(owner, true, "PAD2", map.close)
	end
end

function ns.ClearNavClaims(window)
	local owner = _G[window]
	if owner and not InCombatLockdown() then ClearOverrideBindings(owner) end
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

function ns.NavOpen(window)
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
	-- start on the first ENABLED control (line 12-style snap comes in a later phase)
	local idx = 1
	for i, c in ipairs(map.controls) do if ns.NavEnabled(window, c) then idx = i break end end
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

-- A GOSSIP_UPDATE-style refresh: gossip content changed while the window stayed open.
ns.NavRefresh = function(window)
	if navigating[window] then ns.NavOpen(window) end
end

--------------------------------------------------------------
-- The highlight + legend (glue, Blizzard art only)
--------------------------------------------------------------

local overlays = {}   -- window -> our overlay frame

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
	for i, c in ipairs(map.controls) do
		local line = ov.lines[i]
		if not line then
			line = ov:CreateTexture(nil, "OVERLAY")
			line:SetTexture("Interface\\Buttons\\ButtonHilight-Square")   -- Blizzard's own highlight art
			line:SetBlendMode("ADD")
			ov.lines[i] = line
		end
		local b = _G[c.id]
		if b and ns.NavEnabled(window, c) then
			line:ClearAllPoints()
			line:SetPoint("CENTER", b, "CENTER", 0, 0)
			line:SetSize((b.GetWidth and b:GetWidth() or 20) + 6, (b.GetHeight and b:GetHeight() or 16) + 6)
			line:SetShown(i == ns.NavFocus(window))
		else
			line:SetShown(false)
		end
	end
	ov.legend:SetText((PAD1 or "PAD1") .. ": select   " .. (PAD2 or "PAD2") .. ": close   d-pad: move")
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
