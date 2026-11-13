-- Layout.lua: the controller layout (REQUIREMENTS.md line 3) and the code that applies it.
--
-- HOW IT IS APPLIED (changed 2026-11-13 after the user's in-game test): SetBinding + SaveBindings into the
-- player's CURRENT binding set - the same way the game's own Key Bindings UI writes bindings. Evidence this
-- is the only mechanism that FIRES with Blizzard's gamepad UI off: the user's own saved binding file
-- WTF/Account/FAQJOO/bindings-cache.wtf (68 bind lines, timestamped 2026-11-13 08:55) carries PAD-key binds
-- to normal-context actions and those buttons work in game; our override claims on our own frame never
-- reached the engine (the user's dump 3: keyProbe plain count=0, contextActive=false). SetBinding is
-- restricted /nocombat and needs an explicit SaveBindings to persist (warcraft.wiki.gg/wiki/API_SetBinding:
-- "bindings are not saved without an explicit SaveBindings() call"; two binding sets - account/character -
-- one loaded, GetCurrentBindingSet()). Never LoadBindings(DEFAULT_BINDINGS) - all-or-nothing wipe.
--
-- WHAT THE LAYOUT IS NOW (2026-11-13): the user's own proven working binds, copied VERBATIM from their
-- bindings-cache.wtf for every button they listed (d-pad, face, shoulders, triggers, stick clicks, Start,
-- Select, back paddle 4) - plain AND SHIFT-/CTRL-/CTRL-SHIFT- chords. The user asked to "check how [the
-- reference mod] does it as a reference": that mod writes the same saved bindings (SetBinding on modifier+
-- button names + SaveBindings) and gets its chord actions from Blizzard's MULTIACTIONBAR1/2/3BUTTONn
-- actions; our layout adopts exactly those action names, all read from shipped binding bodies. We do NOT
-- copy anything else from it and never name it (harness rule).
--
-- CHORDS ARE REAL, PROVEN IN THE USER'S GAME: the chords in their file fire because of the engine's own
-- modifier-emulation CVars (warcraft.wiki.gg/wiki/CVar_GamePadEmulateShift: "GamePad button that should
-- emulate the Shift key", default PADLTRIGGER; GamePadEmulateCtrl default PADLSHOULDER; the user's
-- WTF/Config.wtf sets GamePadEmulateShift=PADPADDLE1, GamePadEmulateCtrl=PADPADDLE3). The addon never
-- touches those CVars - whatever button the player (or the CVar defaults) emulates, the chords follow.
-- PADPADDLE4 reports as a real key on the user's pad (their file binds it to JUMP).
--
-- THE EARLIER ATTEMPTS AND WHY THEY FAILED (kept so they never come back):
-- 1) Override claims of GamepadModeInGameCore actions (dump-1 recorded pairs): context inactive with the
--    gamepad UI off, buttons dead (dump 2: contextActive=false, count=0). "A SET binding is not a FIRE."
-- 2) Override claims of normal-context actions on our own claimFrame (version 0.1.0): the user's press
--    test 2026-11-13 - buttons did nothing; dump 3 keyProbe count=0 for plain PAD keys. Overrides on an
--    addon frame never reached the engine in plain mode. claimFrame is GONE.
-- 3) The 0.1.0 d-pad order contradicted Blizzard's own dump 1 (dump 1 recorded PADDLEFT -> ACTIONBUTTON5,
--    we shipped ACTIONBUTTON1). Fixed: the d-pad now follows dump 1 / the user's file exactly.
local addonName, ns = ...

-- The layout, copied verbatim from the user's proven bindings-cache.wtf (2026-11-13) for every button they
-- listed. Action bodies (Blizzard_FrameXML/Bindings_Camelot.xml):
--   ACTIONBUTTONn        :155-207 runOnUp (ActionButtonDown(n)/ActionButtonUp(n))
--   MULTIACTIONBAR1BTNn  :396-407 runOnUp MultiActionButtonDown("MultiBarBottomLeft", n)  [page 1 = SHIFT]
--   MULTIACTIONBAR2BTNn  (same body, bar 2) [page 2 = CTRL]   MULTIACTIONBAR3BTNn (bar 3) [page 3 = CTRL-SHIFT]
--   JUMP                 :53-57    JumpOrAscendStart()
--   INTERACTTARGET       :1140-1141 C_PlayerInteractionManager.InteractUnit("anyinteract")
--   TARGETNEARESTENEMY   :989-995  TargetNearestEnemy()
--   TARGETNEARESTFRIEND  (same category block, normal context)
--   TOGGLEAUTORUN / TOGGLEWORLDMAP - Blizzard's shipped normal-context actions (their bodies read in the
--   same file). PADFORWARD's CLICK UbermocMenu:LeftButton line belongs to ANOTHER addon of the user's and
--   is deliberately NOT copied.
ns.DefaultLayout = {
	-- d-pad (dump 1 recorded these exact pairs; dump-1 order kept)
	PADDLEFT     = "ACTIONBUTTON5",
	PADDUP       = "ACTIONBUTTON8",
	PADDRIGHT    = "ACTIONBUTTON7",
	PADDDOWN     = "ACTIONBUTTON6",
	-- face buttons: PAD1 = bottom, PAD2 = right, PAD3 = left, PAD4 = top (GamepadConstants.lua GAMEPAD_FACE_*)
	PAD3         = "ACTIONBUTTON1",
	PAD4         = "ACTIONBUTTON4",
	PAD2         = "ACTIONBUTTON3",
	PAD1         = "ACTIONBUTTON2",
	-- middle buttons: PADBACK = Select; PADFORWARD left alone (the user's other addon owns it - see above)
	PADBACK      = "TOGGLEWORLDMAP",
	-- stick clicks
	PADLSTICK    = "TOGGLEAUTORUN",
	PADRSTICK    = "MULTIACTIONBAR4BUTTON1",
	-- shoulders and triggers (their chords repeat the target actions exactly as in the user's file)
	PADLSHOULDER = "TARGETNEARESTFRIEND",
	PADRSHOULDER = "TARGETNEARESTENEMY",
	PADLTRIGGER  = "ACTIONBUTTON12",
	PADRTRIGGER  = "ACTIONBUTTON10",
	-- back paddle 4 (Steam Deck R5): PROVEN reporting on the user's pad (their file binds it to JUMP).
	-- PADPADDLE1/3 are the user's Shift/Ctrl emulation buttons (Config.wtf) - binding them would fight that,
	-- so they stay unbound; PADPADDLE2 has no proven line in the user's file and stays unbound too.
	PADPADDLE4   = "JUMP",
	-- chord pages: SHIFT- = action bar page 1, CTRL- = page 2, CTRL-SHIFT- = page 3 (the user's proven scheme)
	["SHIFT-PADDLEFT"]     = "MULTIACTIONBAR1BUTTON5",
	["SHIFT-PADDUP"]       = "MULTIACTIONBAR1BUTTON8",
	["SHIFT-PADDRIGHT"]    = "MULTIACTIONBAR1BUTTON7",
	["SHIFT-PADDDOWN"]     = "MULTIACTIONBAR1BUTTON6",
	["SHIFT-PAD3"]         = "MULTIACTIONBAR1BUTTON1",
	["SHIFT-PAD4"]         = "MULTIACTIONBAR1BUTTON4",
	["SHIFT-PAD2"]         = "MULTIACTIONBAR1BUTTON3",
	["SHIFT-PAD1"]         = "MULTIACTIONBAR1BUTTON2",
	-- chord copies of the target/jump actions, exactly as in the user's working file (one action may hold
	-- many keys: their live bindings-cache.wtf binds JUMP to 7 keys and it works)
	["SHIFT-PADLSHOULDER"] = "TARGETNEARESTFRIEND",
	["SHIFT-PADRSHOULDER"] = "TARGETNEARESTENEMY",
	["SHIFT-PADLTRIGGER"]  = "MULTIACTIONBAR1BUTTON12",
	["SHIFT-PADRTRIGGER"]  = "MULTIACTIONBAR1BUTTON10",
	["SHIFT-PADRSTICK"]    = "MULTIACTIONBAR4BUTTON2",
	["SHIFT-PADPADDLE4"]   = "JUMP",
	["CTRL-PADDLEFT"]      = "MULTIACTIONBAR2BUTTON5",
	["CTRL-PADDUP"]        = "MULTIACTIONBAR2BUTTON8",
	["CTRL-PADDRIGHT"]     = "MULTIACTIONBAR2BUTTON7",
	["CTRL-PADDDOWN"]      = "MULTIACTIONBAR2BUTTON6",
	["CTRL-PAD3"]          = "MULTIACTIONBAR2BUTTON1",
	["CTRL-PAD4"]          = "MULTIACTIONBAR2BUTTON4",
	["CTRL-PAD2"]          = "MULTIACTIONBAR2BUTTON3",
	["CTRL-PAD1"]          = "MULTIACTIONBAR2BUTTON2",
	["CTRL-PADLSHOULDER"]  = "TARGETNEARESTFRIEND",
	["CTRL-PADRSHOULDER"]  = "TARGETNEARESTENEMY",
	["CTRL-PADLTRIGGER"]   = "MULTIACTIONBAR2BUTTON12",
	["CTRL-PADRTRIGGER"]   = "MULTIACTIONBAR2BUTTON10",
	["CTRL-PADRSTICK"]     = "MULTIACTIONBAR4BUTTON3",
	["CTRL-PADPADDLE4"]    = "JUMP",
	["CTRL-SHIFT-PADDLEFT"]     = "MULTIACTIONBAR3BUTTON5",
	["CTRL-SHIFT-PADDUP"]       = "MULTIACTIONBAR3BUTTON8",
	["CTRL-SHIFT-PADDRIGHT"]    = "MULTIACTIONBAR3BUTTON7",
	["CTRL-SHIFT-PADDDOWN"]     = "MULTIACTIONBAR3BUTTON6",
	["CTRL-SHIFT-PAD3"]         = "MULTIACTIONBAR3BUTTON1",
	["CTRL-SHIFT-PAD4"]         = "MULTIACTIONBAR3BUTTON4",
	["CTRL-SHIFT-PAD2"]         = "MULTIACTIONBAR3BUTTON3",
	["CTRL-SHIFT-PAD1"]         = "MULTIACTIONBAR3BUTTON2",
	["CTRL-SHIFT-PADLSHOULDER"] = "TARGETNEARESTFRIEND",
	["CTRL-SHIFT-PADRSHOULDER"] = "TARGETNEARESTENEMY",
	["CTRL-SHIFT-PADLTRIGGER"]  = "MULTIACTIONBAR3BUTTON12",
	["CTRL-SHIFT-PADRTRIGGER"]  = "MULTIACTIONBAR3BUTTON10",
	["CTRL-SHIFT-PADRSTICK"]    = "MULTIACTIONBAR4BUTTON4",
	["CTRL-SHIFT-PADPADDLE4"]   = "JUMP",
}

-- Every row the rebinder shows: exactly the keys of the layout. Chord rows are part of DefaultLayout now
-- (they are proven in the user's game), so there is no separate ChordRows table anymore.
function ns.AllDefaultKeys()
	local keys = {}
	for key in pairs(ns.DefaultLayout) do keys[#keys + 1] = key end
	table.sort(keys)
	return keys
end

-- The rows whose action name the addon may write. Click-binding actions (CLICK ...) are never written by
-- us; everything here is a normal-context action name read from Blizzard's shipped binding bodies.
ns.LayoutActions = {}
for _, action in pairs(ns.DefaultLayout) do ns.LayoutActions[action] = true end

-- Apply the layout with SAVED bindings: SetBinding(key, action) + one SaveBindings(GetCurrentBindingSet())
-- (the wiki's documented pattern; the reference mod does the same). Only rows the player has not cleared
-- are written. A key no live row holds anymore is freed FIRST - an action may hold at most two keys, so
-- writing a moved row before freeing its old key would silently push ANOTHER row's binding off (the fake
-- world models that rule exactly, behavior.lua:61-65). Returns true when everything was written.
function ns.ApplyLayout()
	if InCombatLockdown() then return false end   -- SetBinding is restricted /nocombat
	local live = ns.RebuildClaims()               -- row -> key, from db.binds (single source of truth)
	local keep = {}
	for _, key in pairs(live) do keep[key] = true end
	for key in pairs(ns.DefaultLayout) do         -- free our keys no row holds anymore (cleared/moved rows)
		if not keep[key] and GetBindingAction(key) ~= "" then
			SetBinding(key)   -- nil action = unbind this key only
		end
	end
	local saved = true
	for row, key in pairs(live) do
		local action = ns.DefaultLayout[row]
		if action and not SetBinding(key, action) then saved = false end   -- refused write: report below
	end
	SaveBindings(GetCurrentBindingSet())          -- persist to the loaded set (account or character)
	return saved
end

-- Remove OUR layout's keys only (never LoadBindings/DEFAULT_BINDINGS - all-or-nothing).
function ns.ClearLayout()
	if InCombatLockdown() then return false end
	for key in pairs(ns.DefaultLayout) do
		if GetBindingAction(key) ~= "" then
			SetBinding(key)   -- nil action = unbind this key only
		end
	end
	SaveBindings(GetCurrentBindingSet())
	return true
end

-- R-1.2: one popup on the first login; nothing bound before the player says yes; after "No" the
-- popup never returns (db.bindsAsked); /ubermoc binds asks again. The wording now tells the truth: this
-- writes the game's saved key bindings (the same file the Key Bindings UI edits).
local POPUP = addonName .. "_ASK_BINDS"
StaticPopupDialogs[POPUP] = {
	text = "UbermocForever can put Blizzard's controller layout on your gamepad buttons now. This changes your SAVED key bindings for the controller buttons listed (like the Key Bindings screen does). Nothing is changed until you press Accept.",
	button1 = ACCEPT,   -- Blizzard's own popup button strings (used by Blizzard at Blizzard_AuctionHouseFrame.lua:28)
	button2 = CANCEL,
	OnAccept = function()
		ns.db.bindsAsked = "yes"
		if ns.ApplyLayout() then
			ns:Print("controller layout applied to your saved bindings. /ubermoc unbind removes it.")
		else
			ns:Print("could not write some bindings - nothing else was changed.")
		end
	end,
	OnCancel = function()
		ns.db.bindsAsked = "no"
		ns:Print("not applied. /ubermoc binds asks again.")
	end,
	timeout = 0,
	whileDead = 1,
	showAlert = 1,
}

ns:RegisterEvent("PLAYER_LOGIN", function()
	if not ns.db then return end
	if ns.db.bindsAsked == "yes" then
		ns.ApplyLayout()   -- idempotent: re-writing the same saved bindings changes nothing
	elseif ns.db.bindsAsked ~= "no" then
		StaticPopup_Show(POPUP)   -- the popup's handlers record yes/no; unanswered = asked, not decided
	end
end)

ns.SlashSubcommands = ns.SlashSubcommands or {}
ns.SlashSubcommands["binds"] = function()
	if InCombatLockdown() then
		ns:Print("in combat - bindings unchanged.")
		return
	end
	ns.db.bindsAsked = nil           -- ask again, whatever was answered before
	StaticPopup_Show(POPUP)
end
ns.SlashSubcommands["unbind"] = function()
	if InCombatLockdown() then   -- SetBinding/SaveBindings are restricted /nocombat (wiki API_SetBinding)
		ns:Print("in combat - bindings unchanged.")
		return
	end
	if ns.ClearLayout() then
		ns.db.bindsAsked = "no"
		ns:Print("controller layout removed from your saved bindings (until you accept again).")
	else
		ns:Print("could not remove the layout - bindings unchanged.")
	end
end
