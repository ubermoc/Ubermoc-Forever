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
-- UI LOOK: rows are plain Buttons, the frame uses Blizzard's ButtonFrameTemplate chrome and Blizzard's own
-- strings (CLOSE / CANCEL / DEFAULTS / OKAY - defined in Blizzard_SharedXML/SharedConstants.lua). A custom
-- binding-row template of Blizzard's was NOT FOUND by lookup in Forever's source, so no Blizzard template
-- is claimed for the rows themselves (Phase 2 spec line 6 says "look and work like" - visual check is the
-- user's).
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
		return
	end
	ns.db.binds = ns.db.binds or {}
	local had, oldKey = ns.db.binds[row] ~= nil, ns.db.binds[row]
	ns.db.binds[row] = key
	if not ns.ApplyOne(row) then
		if had then ns.db.binds[row] = oldKey else ns.db.binds[row] = nil end   -- refused: as it was
		return
	end
	ns:Print(("%s -> %s bound."):format(key, row))
end
------------------------------------------------------------
-- The screen (glue): one row per binding we applied (line 6).
------------------------------------------------------------

local frame
ns.bindFrame = function() return frame end

-- Rows are NAMED Buttons (UbermocForeverBindRowN) so Nav.lua can claim them with
-- SetOverrideBindingClick - the same secure-click path as every other navigated window (R-2.2: the page
-- works with the controller alone). Labels show row + current key, refreshed after every change.
local function makeRow(parent, index, row)
	local button = CreateFrame("Button", addonName .. "BindRow" .. index, parent, "UIPanelButtonTemplate")
	button.__row = row
	button:SetScript("OnClick", function() ns.BindListen(row); ns:Print(("press a button for %s"):format(row)) end)
	return button
end

function ns.UpdateRowLabels()
	if not frame or not ns.rowList then return end
	for i, button in ipairs(ns.rowList) do
		local row = button.__row
		local key = ns.claimedKey(row)
		button:SetText(row .. "  |cffffd100" .. (key or CLEAR or "none") .. "|r")
	end
end

function ns.ShowBindUI()
	if not ns.db then return end
	if not frame then
		frame = CreateFrame("Frame", addonName .. "BindFrame", UIParent)   -- Blizzard chrome template: see header note
		frame:SetScript("OnHide", function() ns.BindStop(); if ns.NavClose then ns.NavClose(addonName .. "BindFrame") end end)
		local rows = {}
		ns.rowList = rows
		for i, row in ipairs(ns.AllDefaultKeys()) do
			rows[i] = makeRow(frame, i, row)
		end
		local clear = CreateFrame("Button", addonName .. "BindClear", frame, "UIPanelButtonTemplate")
		frame.clearButton = clear
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
		reset:SetText(DEFAULTS or "Defaults")
		reset:SetScript("OnClick", function()
			ns.ResetToDefault()
			ns.UpdateRowLabels()
			ns:Print("reset to Blizzard's default layout.")
		end)
		local close = CreateFrame("Button", addonName .. "BindClose", frame, "UIPanelButtonTemplate")
		frame.closeButton = close
		close:SetText(CLOSE or "Close")
		close:SetScript("OnClick", function() ns.BindStop(); frame:Hide() end)
		-- R-2.2: this screen is created AFTER PLAYER_LOGIN, so we hand it to Nav.lua ourselves: the
		-- d-pad/PAD1/PAD2 claims attach and the controls are asked directly (it is our own frame).
		if ns.NavWatchOwn then ns.NavWatchOwn(addonName .. "BindFrame") end
	end
	ns.UpdateRowLabels()
	frame:Show()
	-- R-2.2: opening the screen must arm navigation. In the real game frame:Show() fires the OnShow
	-- watcher Nav attached; here we also call NavOpen directly - it is idempotent (it rebuilds the map
	-- and re-points the claims at the current highlight), so the screen is navigable in both worlds.
	if ns.NavOpen then ns.NavOpen(addonName .. "BindFrame") end
end

-- The map Nav.lua uses for this screen (R-2.2): every row button, then Clear, Defaults, Close.
function ns.BindNavMap()
	local controls = {}
	for i = 1, #ns.AllDefaultKeys() do
		local name = addonName .. "BindRow" .. i
		if _G[name] then controls[#controls + 1] = { id = name } end
	end
	for _, name in ipairs({ addonName .. "BindClear", addonName .. "BindReset", addonName .. "BindClose" }) do
		if _G[name] then controls[#controls + 1] = { id = name } end
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
	if ns.RegisterNavWindow then ns.RegisterNavWindow(addonName .. "BindFrame", ns.BindNavMap) end
end)
