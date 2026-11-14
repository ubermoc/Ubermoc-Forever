-- Bind.lua: the press-to-bind rebinder and the binding screen (REQUIREMENTS.md lines 6-8).
--
-- HOW CAPTURE WORKS: Blizzard's own key-binding UI listens for a controller button with a plain Button's
-- OnGamePadButtonDown script (Blizzard_Settings_Shared/Blizzard_Keybindings.lua:1-9 KeybindListener,
-- :26-38 SetListening installs exactly OnKeyDown/OnGamePadButtonDown scripts). We do the same on our own
-- listener button. The pressed key is stored in db.binds[row]; applying uses SAVED bindings -
-- SetBinding(key, action) + SaveBindings(GetCurrentBindingSet()) - exactly like the Key Bindings screen
-- (2026-11-13: the user's in-game test PROVED override claims on an addon frame never fire in plain mode;
-- their own bindings-cache.wtf with SetBinding-style PAD binds is what works). The player's saved binding
-- file IS written on purpose now, and that is also why choices survive /reload even without us.
--
-- A row is UNBOUND until the player binds it: ns.RowAction returns nil for an unbound row; every default
-- Layout.lua ships (ns.DefaultLayout, plain keys AND chord rows) is written on login.
--
-- CONFLICT RULE (Spec line 6, our own rule enforced in code): ns.ApplyOne refuses to claim a
-- key another of our rows already carries and says which row; the player clears that row first.
-- CLEAR RULE: clearing one row clears ONLY that row (line 7).
--
-- FAILURE PATHS (line 8): in combat nothing is touched and chat says so; an unknown row/action is refused;
-- a press while no row is selected does nothing.
--
-- UI LOOK: the page is our own frame shown inside Blizzard's Settings window (Options.lua registers it as
-- a CANVAS category). ROWS ARE NOT BUTTONS ANY MORE (user 2026-11-13 round 4, in game: "it's just red bars
-- everywhere they have no words"): rows are plain Frames carrying two FontStrings - the row NAME and its
-- KEY - drawn with Blizzard's own fonts. A Button's text is a FONTSTRING, so the words were never the
-- problem; what changed is that we now draw them OURSELVES instead of trusting a button template inside
-- someone else's canvas. The row frames are still NAMED (UbermocForeverBindRowN) because Nav.lua claims
-- PAD1 on them with SetOverrideBindingClick - the engine clicks the frame named by the binding (Nav.lua
-- header; SimpleFrameAPIDocumentation.lua:1426 SetPropagateKeyboardInput exists for frames, so a Frame is
-- a legal binding-click target). The three action buttons below keep Blizzard's UIPanelButtonTemplate.
-- Text uses Blizzard's own strings (CLOSE / DEFAULTS / CLEAR - defined in Blizzard_SharedXML/SharedConstants.lua).
local addonName, ns = ...

-- Single source of truth for what the player chose: db.binds[row] = key they pressed (nil = use the
-- default key). Everything else DERIVES from it:
--   claimedKey(row)  - the key a row lives on now (player's choice, or its own name as default; nil if cleared)
--   keyOwner(key)    - which of our rows claims that key right now
-- ns.claims is only a CACHE of claimedKey, rebuilt by RebuildClaims after any change.

function ns.claimedKey(row)
	if not ns.DefaultLayout[row] then return nil end   -- unknown row
	local b = ns.db and ns.db.binds
	if b and b[row] ~= nil then
		if b[row] == "" then return nil end   -- cleared on purpose: no key at all
		return b[row]                         -- the player's pressed key
	end
	return row                                -- default rows live on their own name (chords included)
end

function ns.RebuildClaims()
	local c = {}
	for row in pairs(ns.DefaultLayout) do
		local k = ns.claimedKey(row)
		if k then c[row] = k end
	end
	ns.claims = c
	return c
end

-- which of OUR rows claims a key right now (first found; keys are one-row-each by the conflict rule)
function ns.keyOwner(key, exceptRow)
	for row, claimed in pairs(ns.RebuildClaims()) do
		if row ~= exceptRow and claimed == key then return row end
	end
end

------------------------------------------------------------

------------------------------------------------------------

-- The action a row should carry: the player's own choice if they set one, else Blizzard's default for that
-- row; nil when the row was cleared on purpose. Row names are exactly the keys of ns.DefaultLayout.
function ns.RowAction(row)
	if not ns.claimedKey(row) then return nil end   -- cleared on purpose
	return ns.DefaultLayout[row]
end

-- The key a row currently lives on: the player's choice if set, else its own name (its default key).
function ns.RowKey(row)
	return (ns.db and ns.db.binds and ns.db.binds[row]) or row
end

-- Claim one row's key on our frame. Refuses: combat lockdown, unknown row, a key another of OUR rows
-- already carries (conflict, line 6). Returns true when the claim was written. The check walks every
-- row's effective key, so it never mistakes this row's own old claim for someone else's.
function ns.ApplyOne(row)
	if InCombatLockdown() then
		ns:Print("in combat - bindings unchanged.")
		return false
	end
	local action = ns.RowAction(row)
	if not action then return false end
	local key = ns.claimedKey(row)
	local other = ns.keyOwner(key, row)
	if other then
		ns:Print(("%s is already used by %s - clear that row first."):format(key, other))
		return false
	end
	-- one frame owns all our claims: rewrite the whole set (ApplyLayout clears the frame first), so a
	-- moved row frees its old key and nothing else can shift.
	ns.ApplyLayout()
	return true
end

-- Clear ONLY this row: its claim is removed and the row goes back to unbound (its default key no longer
-- claimed until "reset to default" or rebind). Changes nothing else (line 7).
function ns.ClearOne(row)
	if not ns.DefaultLayout[row] then return false end
	ns.db.binds = ns.db.binds or {}
	ns.db.binds[row] = ""      -- cleared ON PURPOSE: claimedKey returns nil, reload keeps it cleared
	ns.ApplyLayout()           -- re-claims every other row; this row's key is released
	return true
end

-- "Reset to default" (line 6): drop every claim, forget the player's choices, re-claim Blizzard's defaults.
-- ClearOverrideBindings is restricted /nocombat (community docs; Blizzard guards its own use at
-- RestrictedFrames.lua:24,538), so combat refuses like ApplyOne does.
function ns.ResetToDefault()
	if InCombatLockdown() then
		ns:Print("in combat - bindings unchanged.")
		return false
	end
	ns.ClearLayout()
	if ns.db then ns.db.binds = {} end
	ns.ApplyLayout()   -- ApplyLayout records claims again
	return true
end

------------------------------------------------------------
-- Capture (glue): the listener button Blizzard's own UI uses the same way (header).
------------------------------------------------------------

local listener = CreateFrame("Button", addonName .. "BindListener")
ns.bindListener = listener

function ns.BindListen(row)
	if not ns.db then return end
	ns.db.pendingRow = row
	listener:SetScript("OnGamePadButtonDown", function(self, key)   -- Blizzard's capture script (header cite)
		ns.BindPress(key)
	end)
end

function ns.BindStop()
	if ns.db then ns.db.pendingRow = nil end
	listener:SetScript("OnGamePadButtonDown", nil)
end

-- What a press does: record the pressed key for the pending row, then apply it (conflict-checked).
-- On conflict or combat refusal the OLD choice stays (line 8: failure leaves bindings as they were).
function ns.BindPress(key)
	if not ns.db then return end
	local row = ns.db.pendingRow
	ns.BindStop()
	if not row then return end   -- press with no row selected: nothing happens
	if type(key) ~= "string" or not (key:match("^PAD") or key:match("^SHIFT%-PAD") or key:match("^CTRL%-PAD") or key:match("^CTRL%-SHIFT%-PAD")) then
		ns:Print("press a controller button to bind this row.")
		return
	end
	if InCombatLockdown() then
		ns:Print("in combat - bindings unchanged.")
		return false   -- (the OLD choice stays; nothing was written)
	end
	ns.db.binds = ns.db.binds or {}
	local had, oldKey = ns.db.binds[row] ~= nil, ns.db.binds[row]
	ns.db.binds[row] = key
	if not ns.ApplyOne(row) then
		if had then ns.db.binds[row] = oldKey else ns.db.binds[row] = nil end   -- refused: as it was
		return
	end
	ns.UpdateRowLabels()   -- the row shows its new key immediately (R-2.2: "bound and shown")
	ns:Print(("%s -> %s bound."):format(key, row))
end
------------------------------------------------------------
-- The screen (glue): one row per binding we applied (line 6).
------------------------------------------------------------

local frame
ns.bindFrame = function() return frame end

-- Rows are NAMED Frames (UbermocForeverBindRowN) with two FontStrings of Blizzard's own fonts: the row
-- NAME on the left, its KEY on the right. Nav.lua claims PAD1 on the frame itself (the engine clicks the
-- named target; a Frame is a legal click target - see header). A click arms capture for that row.
local function makeRow(parent, index, row)
	local f = CreateFrame("Frame", addonName .. "BindRow" .. index, parent)
	f.__row = row
	f:SetSize(360, 24)
	if index == 1 then
		f:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -50)
	else
		f:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -50 - (index - 1) * 26)
	end
	local name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	name:SetPoint("LEFT", f, "LEFT", 4, 0)
	name:SetText(row)
	f.__nameText = name
	local key = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")   -- the KEY stands out
	key:SetPoint("RIGHT", f, "RIGHT", -4, 0)
	f.__keyText = key
	f:SetScript("OnClick", function()
		ns.BindListen(row)
		ns:Print(("press a button for %s"):format(row))
	end)
	return f
end

-- A row's look comes from HIGHLIGHT TEXTURES we draw ourselves (Blizzard's own highlight art): selected
-- row = full gold bar, highlighted-by-d-pad = outline. The old build drew rows with UIPanelButtonTemplate
-- and the user saw "red bars everywhere... no words" - WHY the template's words went missing is not proven
-- (unverified), so we no longer depend on it: the words are now our own FontStrings on plain Frames.
local function applyRowLook(f)
	if not f.__bg then
		f.__bg = f:CreateTexture(nil, "BACKGROUND")
		f.__bg:SetTexture("Interface\\Buttons\\ButtonHilight-Square")   -- Blizzard's own highlight art
		f.__bg:SetBlendMode("ADD")
		f.__bg:SetAllPoints(f)
	end
	if not f.__outline then
		f.__outline = f:CreateTexture(nil, "BACKGROUND")
		f.__outline:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")   -- Blizzard's own selection art (Blizzard_ChatFrame/Mainline/ChatConfigFrame.xml:22 uses this exact file)
		f.__outline:SetPoint("TOPLEFT", f, "TOPLEFT", -4, 4)
		f.__outline:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 4, -4)
	end
	local selected = ns.db and ns.db.pendingRow == f.__row
	local highlighted = false
	if ns.NavFocus and ns.NAV_MAPS and ns.NAV_MAPS[addonName .. "BindFrame"] then
		local c = ns.NAV_MAPS[addonName .. "BindFrame"].controls[ns.NavFocus(addonName .. "BindFrame")]
		highlighted = c ~= nil and _G[c.id] == f
	end
	f.__bg:SetShown(selected)
	f.__outline:SetShown(highlighted and not selected)
	if highlighted or selected then
		f.__nameText:SetTextColor(1, 1, 1)   -- white on the highlight bar
	else
		f.__nameText:SetTextColor(0.83, 0.83, 0.83)   -- GameFontHighlight's own colour (the font this row inherits; exact RGB is Blizzard's, visual check is the user's)
	end
end

-- Forward declaration: BindPress (earlier in this file) calls ns.UpdateRowLabels;
-- declaring it first removes any doubt about definition order. The real body below
-- overwrites it at load time, before anything can run.
function ns.UpdateRowLabels() end

function ns.UpdateRowLabels()
	if not frame or not ns.rowList then return end
	for i, f in ipairs(ns.rowList) do
		local row = f.__row
		local key = ns.claimedKey(row)
		f.__nameText:SetText(row)
		f.__keyText:SetText(key or (CLEAR or "none"))
		f.__keyText:SetTextColor(key and 1 or 0.5, key and 1 or 0.5, key and 0.56 or 0.56)   -- gold when bound (the old |cffffd100), grey when cleared
		if applyRowLook then applyRowLook(f) end
	end
end
ns.ApplyRowLook = applyRowLook

-- The bind screen (R-2.2) IS our settings page now: Options.lua registers our frame as a CANVAS layout
-- category, and Blizzard displays the frame directly when the page opens - the old vertical category had
-- zero setting rows, which is why the in-game probe showed an EMPTY page (user 2026-11-13: "move the
-- binds in there", so the expandable subcategory is gone). The frame itself has no chrome: the Settings
-- window around it is Blizzard's own. Rows are laid out here, below the header.
-- Build the frame and its controls (idempotent). Options.lua calls this at login so the canvas category
-- has a real frame; ShowBindUI shows it.
function ns.CreateBindUI()
	if not ns.db then return end
	if frame then return end
	frame = CreateFrame("Frame", addonName .. "BindFrame", UIParent)
	frame:SetScript("OnHide", function()
		ns.BindStop()
		if ns.NavClose then ns.NavClose(addonName .. "BindFrame") end
		-- The page lives inside the Settings window; hiding our frame alone would leave a blank
		-- panel, so close the whole Settings window. There is NO Settings.Close in this API - the panel
		-- object itself has Close (Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua:256
		-- "function SettingsPanelMixin:Close(skipTransitionBackToOpeningPanel)"), reached as the global
		-- frame SettingsPanel exactly how Blizzard's own escape handler does (:41-42
		-- "if SettingsPanel:IsShown() then ... SettingsPanel:Close();").
		if type(SettingsPanel) == "table" and type(SettingsPanel.Close) == "function" then
			pcall(function() SettingsPanel:Close() end)
		end
	end)

	local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	frame.headerText = header
	header:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -16)
	header:SetText(addonName .. " controller settings")

	local rows = {}
	ns.rowList = rows
	for i, row in ipairs(ns.AllDefaultKeys()) do
		rows[i] = makeRow(frame, i, row)
	end
	local bottom = 60 + (#ns.AllDefaultKeys()) * 26   -- rows stack from -50, 26px each
	local clear = CreateFrame("Button", addonName .. "BindClear", frame, "UIPanelButtonTemplate")
	frame.clearButton = clear
	clear:SetSize(110, 22)
	clear:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -bottom)
	clear:SetText(CLEAR or "Clear")
	clear:SetScript("OnClick", function()
		if ns.db.pendingRow then
			ns.ClearOne(ns.db.pendingRow)
			ns.UpdateRowLabels()
			ns:Print(("cleared %s only."):format(ns.db.pendingRow))
		else
			ns:Print("pick a row first, then press Clear.")
		end
	end)
	local reset = CreateFrame("Button", addonName .. "BindReset", frame, "UIPanelButtonTemplate")
	frame.resetButton = reset
	reset:SetSize(110, 22)
	reset:SetPoint("TOPLEFT", clear, "TOPRIGHT", 8, 0)
	reset:SetText(DEFAULTS or "Defaults")
	reset:SetScript("OnClick", function()
		ns.ResetToDefault()
		ns.UpdateRowLabels()
		ns:Print("reset to Blizzard's default layout.")
	end)
	local close = CreateFrame("Button", addonName .. "BindClose", frame, "UIPanelButtonTemplate")
	frame.closeButton = close
	close:SetSize(110, 22)
	close:SetPoint("TOPLEFT", reset, "TOPRIGHT", 8, 0)
	close:SetText(CLOSE or "Close")
	close:SetScript("OnClick", function() ns.BindStop(); frame:Hide() end)

	if ns.NavWatchOwn then ns.NavWatchOwn(addonName .. "BindFrame") end
end

function ns.ShowBindUI()
	ns.CreateBindUI()
	if not frame then return end
	ns.UpdateRowLabels()
	frame:Show()
	-- R-2.2: opening the screen must arm navigation. In the real game frame:Show() fires the watchers Nav
	-- attached; we also call NavOpen directly - it is idempotent (it rebuilds the map and re-points the
	-- claims at the current highlight), so the screen is navigable in both worlds.
	if ns.NavOpen then ns.NavOpen(addonName .. "BindFrame") end
end

-- The map Nav.lua uses for this screen (R-2.2): every row button, then Clear, Defaults, Close.
function ns.BindNavMap()
	local controls = {}
	for i = 1, #ns.AllDefaultKeys() do
		local name = addonName .. "BindRow" .. i
		-- label so NAVIGATION CAN NARRATE the row (round-4 feedback: "narrating in menus doesn't work"):
		-- the row's own name FontString is the source of truth for what it shows on screen.
		if _G[name] then controls[#controls + 1] = { id = name, label = _G[name].__nameText and _G[name].__nameText:GetText() or nil } end
	end
	for _, pair in ipairs({ { addonName .. "BindClear", CLEAR }, { addonName .. "BindReset", DEFAULT }, { addonName .. "BindClose", CLOSE } }) do
		if _G[pair[1]] then controls[#controls + 1] = { id = pair[1], label = pair[2] or "button" } end
	end
	return { title = addonName, controls = controls, close = addonName .. "BindClose" }
end

ns.SlashSubcommands = ns.SlashSubcommands or {}
ns.SlashSubcommands["bind"] = function()
	ns.ShowBindUI()
end

-- Register this screen with Nav.lua (R-2.2). Bind.lua loads AFTER Nav.lua, so Nav's own PLAYER_LOGIN
-- handler has already run; registering here is late but complete: the map only matters once the frame
-- exists, and ShowBindUI shows it. The OnShow/OnHide hooks attach when the frame is first created.
ns:RegisterEvent("PLAYER_LOGIN", function()
	ns.CreateBindUI()   -- idempotent; Options.lua (which loads earlier) may have built it first
	if ns.RegisterNavWindow then ns.RegisterNavWindow(addonName .. "BindFrame", ns.BindNavMap) end
end)
