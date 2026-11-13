-- Probe.lua: ONE in-game diagnostic, /ubermoc probe (the plan in HANDOFF.md 2026-11-13).
-- The offline fake world proved nothing about real frames, so the next build comes from what the GAME
-- really returns. This file only RECORDS; it changes no binding and no Blizzard frame.
-- Results go to SavedVariables (db.probe) and are written when you /reload or leave the game.
--
-- What it records:
--   settings: is our category registered, its id, how many rows it has, whether navWindows was saved;
--   esc:      the buttons currently in GameMenuFrame and whether AddButton exists;
--   windows:  when the vendor / gossip window opens: did our Nav watcher run (openCount), the map maker's
--             exact error if it failed, every control id (nil = unnamed frame!) and whether it is pressable;
--   pad:      presses that arrive at OUR frames while a window is open (which key, which frame), and what
--             the d-pad / PAD1 / PAD2 keys are bound to at that moment.
local addonName, ns = ...

local function now() return date and date("%Y-%m-%d %H:%M:%S") or 0 end

function ns.ProbeRecord(section, value)
	if not ns.db then return end
	ns.db.probe = ns.db.probe or {}
	ns.db.probe[section] = { time = now(), value = value }
end

-- A small frame of OURS that receives pad presses. It never handles a click and never moves anything:
-- it answers only one question - does the game deliver OnGamePadButtonDown to an addon frame while a
-- window is open? (Our bind-screen listener proves the same for our own window.)
local probeListener

local function listenPad()
	if not probeListener then
		probeListener = CreateFrame("Button", addonName .. "ProbeListener")
		probeListener:SetSize(1, 1); probeListener:Hide()
	end
	probeListener:SetScript("OnGamePadButtonDown", function(self, key)
		local p = ns.db.probe or {}
		local list = p.padPresses or {}
		list[#list + 1] = { time = now(), key = tostring(key) }
		ns.ProbeRecord("padPresses", list)
	end)
end

-- What the d-pad / face keys are bound to right now (GetBindingAction goes KEY -> action; ""/nil = unbound).
local function keyState()
	local out = {}
	for _, key in ipairs({ "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PAD1", "PAD2" }) do
		local ok, a = pcall(GetBindingAction, key)
		out[key] = ok and (a ~= "" and a or "unbound") or ("error: " .. tostring(a))
	end
	return out
end

-- The settings category state, as the game has it right now.
local function recordSettings()
	local cat = ns.settingsCategory
	local v = {
		registered = cat and true or false,
		id = cat and cat:GetID() or nil,
		numSettings = cat and cat.GetNumSettings and cat:GetNumSettings() or nil,
		subcategoryRegistered = ns.bindsCategory and true or false,
		navWindowsSavedValue = ns.db and tostring(ns.db.navWindows) or "no db",
	}
	ns.ProbeRecord("settings", v)
end

-- The Esc menu's current buttons.
local function recordEscMenu()
	local gmf = _G.GameMenuFrame
	local v = { frameExists = gmf and true or false, addButtonExists = type(gmf and gmf.AddButton) == "function" }
	if gmf and gmf.buttons then
		v.buttonTexts = {}
		for _, b in ipairs(gmf.buttons) do
			v.buttonTexts[#v.buttonTexts + 1] = b.GetText and tostring(b:GetText()) or "?"
		end
	end
	ns.ProbeRecord("esc", v)
end

-- One window: did our watcher run, what did the map maker return (or its exact error), and is every
-- control named / pressable in the REAL game.
local function recordWindow(window)
	local f = _G[window]
	if not f or not f:IsShown() then return end
	local v = { shown = true }
	v.openCount = ns.NavOpenCount and ns.NavOpenCount[window] or 0
	v.mapInNav = ns.NavIsNavigating and ns.NavIsNavigating(window) or false
	local maker = ns.NAV_MAKERS[window]
	if not maker then
		v.maker = "none registered"
	else
		local ok, map = pcall(maker)
		if not ok then
			v.makerError = tostring(map)   -- the exact error text from the real game
		else
			v.title = map.title
			v.controls = {}
			for _, c in ipairs(map.controls or {}) do
				local b = _G[c.id]
				v.controls[#v.controls + 1] = {
					id = tostring(c.id),
					exists = b and true or false,
					shown = b and b.IsShown and b:IsShown() or false,
					disabled = b and b.IsDisabled and b:IsDisabled() or false,
				}
			end
			v.closeId = tostring(map.close)
		end
	end
	ns.ProbeRecord("window." .. window, v)
end

ns:RegisterEvent("ADDON_LOADED", function(loadedAddon)
	if loadedAddon ~= addonName then return end
	-- no pad listener at load: it arms only when the player runs /ubermoc probe (see below)
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
	ns.GOSSIP_EVENTS = ns.GOSSIP_EVENTS or {}   -- already set by Nav.lua (loads before this file)
	local hookWindow = function(window)
		local f = _G[window]
		if not f then return end
		f:HookScript("OnShow", function() C_Timer.After(0, function() recordWindow(window) end) end)
	end
	hookWindow("MerchantFrame")
	hookWindow("GossipFrame")
	-- The Esc menu rebuilds its buttons every show (GameMenuFrame.lua:61-72 OnShow -> InitButtons);
	-- hook AddButton once and read the whole list when GAMEMENU_OPTIONS is added.
	local gmf = _G.GameMenuFrame
	if gmf then
		hooksecurefunc(gmf, "AddButton", function(self, text)
			if text ~= GAMEMENU_OPTIONS then return end
			recordEscMenu()
		end)
	end
end)

ns:RegisterEvent("GOSSIP_SHOW", function() C_Timer.After(0, function() recordWindow("GossipFrame") end) end)
ns:RegisterEvent("GOSSIP_OPTIONS_REFRESHED", function() C_Timer.After(0, function() recordWindow("GossipFrame") end) end)
ns:RegisterEvent("MERCHANT_SHOW", function() recordWindow("MerchantFrame") end)

-- A final snapshot at logout/reload so the file always holds the last state seen.
ns:RegisterEvent("PLAYER_LOGOUT", function()
	if not ns.db then return end
	recordSettings()
	ns.ProbeRecord("keyStateAtLogout", keyState())
end)

ns.SlashSubcommands = ns.SlashSubcommands or {}
ns.SlashSubcommands["probe"] = function()
	listenPad()
	recordSettings()
	recordEscMenu()
	recordWindow("MerchantFrame")
	recordWindow("GossipFrame")
	ns.ProbeRecord("keyState", keyState())
	ns:Print("probe recorded. Type /reload to save it for the AI.")
end
