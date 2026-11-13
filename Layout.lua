-- Layout.lua: Blizzard's own default controller layout (REQUIREMENTS.md line 3) and the code that applies it.
--
-- WHAT THE LAYOUT IS: every controller button named by the user (d-pad, face buttons A/B/X/Y, L1 L2 R1 R2,
-- stick clicks, Start, Select, back paddles L3/L4/R3/R4) bound to Blizzard's own NORMAL-context actions.
-- The KEY NAMES are Blizzard's: the game translates every controller (Steam Deck, Steam Controller, Xbox,
-- PlayStation 3/4/5, Switch) into one fixed set of PAD key names and display strings - see
-- Blizzard_SharedXML/SharedConstants.lua:61-92 (KEY_PADPADDLE1..4 = the back paddles, KEY_PADLSTICK/RSTICK
-- = stick clicks, KEY_PADFORWARD = Start/menu, KEY_PADBACK = Select/view, KEY_PADSYSTEM, KEY_PADSOCIAL) and
-- Blizzard_SharedXML/Shared/GamepadConstants.lua (GAMEPAD_FACE_BOTTOM = "PAD1", GAMEPAD_FACE_RIGHT = "PAD2").
-- The addon invents no key names; every one below is spelled in those two files.
--
-- WHY NOT THE RECORDED GAMEPAD ACTIONS (the first attempt, and why it failed): dump 1 recorded actions like
-- GAMEPADACTIONBUTTON1/OPENRADIAL with Blizzard's gamepad UI ON (contextActive=true). With the UI off those
-- actions live in bindingContext "GamepadModeInGameCore", which only Blizzard's own gamepad code activates
-- (Blizzard_Gamepad/Core.lua:48-56). The user then tested our first version (override claims with exactly
-- those recorded actions, gamepad UI OFF): dump 2 at 23:45 recorded contextActive=false and count=0, and the
-- buttons did nothing in game. A binding that merely SETS is not a binding that FIRES - an action whose
-- context is inactive never runs (rule from REQUIREMENTS.md / harness lesson). So claiming those actions on
-- our frame could never work for a player who does not switch Blizzard's gamepad UI on.
--
-- WHAT THIS LAYOUT USES INSTEAD: Blizzard's own NORMAL-context actions - actions from Blizzard's always-on
-- Bindings.xml whose bodies we READ and verified do something in plain mode (cites on each entry below).
-- The user approved (2026-11-13): replace the four dead GAMEPAD*MOD shoulder/trigger entries with working
-- normal-context actions, and cover ALL controller buttons including the back paddles.
--
-- NO CHORD DEFAULTS ON PURPOSE: modifier-prefixed gamepad keys ("SHIFT-PAD1") are NOT claimed anywhere -
-- whether the C++ binding layer matches such chords against gamepad keys is unproven offline, so we do not
-- ship them as defaults (the user's press test in Phase 2 will decide whether chords work at all).
--
-- HOW IT IS APPLIED: OVERRIDE bindings on an addon-owned frame (the mechanism Blizzard's own gamepad UI uses,
-- InputActionBinding.lua:22 SetOverrideBinding(owner, true, key, action); cleared with
-- SetOverrideBinding(owner, false, key, "") at InputBindingManager.lua:29). Overrides are temporary, need no
-- SaveBindings (BindingUtil.lua:66,90) and work whatever the binding context is. Never UIParent as owner
-- (Blizzard's own binding stack sets its overrides on UIParent, InputActionBinding.lua:22;
-- ClearOverrideBindings wipes ALL of an owner's claims - known-mistakes rule). Re-applied every PLAYER_LOGIN.
local addonName, ns = ...

-- The default layout: key -> action. Every key name appears in Blizzard_SharedXML/SharedConstants.lua:61-92
-- or GamepadConstants.lua. Action sources are Blizzard's own shipped binding bodies (file:line):
--   ACTIONBUTTONn        Blizzard_FrameXML/Bindings_Camelot.xml:155-207 (ActionButtonDown(n)/ActionButtonUp(n))
--   MULTIACTIONBAR1BTNn  Blizzard_FrameXML/Bindings_Camelot.xml:396-407 (MultiActionButtonDown("MultiBarBottomLeft", n))
--   OPENALLBAGS          Blizzard_FrameXML/Bindings_Camelot.xml:1190-1192 (ToggleAllBags(); defined ContainerFrame.lua:2173)
--   TOGGLECHARACTER0     Blizzard_FrameXML/Bindings_Camelot.xml:1194-1195 (ToggleCharacter("PaperDollFrame"); CharacterFrame.lua:3)
--   JUMP                 Blizzard_FrameXML/Bindings_Camelot.xml:53-57    (JumpOrAscendStart())
--   INTERACTTARGET       Blizzard_FrameXML/Bindings_Camelot.xml:1140-1141 (C_PlayerInteractionManager.InteractUnit("anyinteract"))
--   TARGETNEARESTENEMY   Blizzard_FrameXML/Bindings_Camelot.xml:989-995   (TargetNearestEnemy())
--   OPENCHATSLASH        Blizzard_FrameXML/Bindings_Camelot.xml:115-116   (ChatFrameUtil.OpenChat("/"); ChatFrameUtil.lua:448)
--   TOGGLEGAMEMENU       Blizzard_FrameXML/Bindings_Camelot.xml:1169-1170 (ToggleGameMenu(); Blizzard_GameMenuEsc.lua:109)
-- The 15 keys the game recorded in dump 1 keep their actions from the previous version; everything else is a
-- new default for a button that previously had none.
ns.DefaultLayout = {
	-- d-pad (the four keys dump 1 recorded)
	PADDLEFT     = "ACTIONBUTTON1",
	PADDUP       = "ACTIONBUTTON2",
	PADDRIGHT    = "ACTIONBUTTON3",
	PADDDOWN     = "ACTIONBUTTON4",
	-- face buttons: PAD1 = bottom, PAD2 = right, PAD3 = left, PAD4 = top (GamepadConstants.lua GAMEPAD_FACE_*)
	PAD3         = "ACTIONBUTTON5",
	PAD4         = "ACTIONBUTTON6",
	PAD2         = "ACTIONBUTTON7",
	PAD1         = "ACTIONBUTTON8",
	-- middle buttons: dump 1 recorded PADFORWARD/PADBACK (Start/Select on every pad)
	PADFORWARD   = "OPENALLBAGS",
	PADBACK      = "TOGGLEGAMEMENU",
	-- stick clicks: PADRSTICK carried JUMP in dump 1; PADLSTICK is new
	PADRSTICK    = "JUMP",
	PADLSTICK    = "INTERACTTARGET",
	-- shoulders and triggers (the four the user's test proved dead as GAMEPAD*MOD - replaced with working
	-- actions, approved 2026-11-13)
	PADLSHOULDER = "INTERACTTARGET",
	PADRSHOULDER = "TARGETNEARESTENEMY",
	PADLTRIGGER  = "OPENCHATSLASH",
	PADRTRIGGER  = "ACTIONBUTTON9",
	-- back paddles (Steam Deck L3/L4/R3/R4, Xbox Elite paddles): key names KEY_PADPADDLE1..4,
	-- SharedConstants.lua:85-88. UNVERIFIED in game whether a plain pad reports them at all - the user's
	-- press test decides; on pads without paddles these overrides simply never trigger.
	PADPADDLE1   = "ACTIONBUTTON10",
	PADPADDLE2   = "ACTIONBUTTON11",
	PADPADDLE3   = "ACTIONBUTTON12",
	PADPADDLE4   = "MULTIACTIONBAR1BUTTON1",
}

-- Chords the player may bind by hand in Phase 2 (rows exist for them), but NOTHING is claimed by default:
-- whether a "CTRL-" / "SHIFT-" prefix ever fires on a gamepad key is unproven offline (see header).
ns.ChordRows = {
	["SHIFT-PAD3"]        = "ACTIONBUTTON6",       -- spare slot for the top face button's action
	["SHIFT-PAD2"]        = "ACTIONBUTTON8",       -- spare slot for the bottom face button's action
	["CTRL-PADLSTICK"]    = "TOGGLECHARACTER0",
	["CTRL-PADRSHOULDER"] = "MULTIACTIONBAR1BUTTON1",
}

-- Every row the rebinder shows: default keys plus the chord rows. Row name == its own key by default.
function ns.AllDefaultKeys()
	local keys = {}
	for key in pairs(ns.DefaultLayout) do keys[#keys + 1] = key end
	for key in pairs(ns.ChordRows) do keys[#keys + 1] = key end
	return keys
end

-- The frame that OWNS our override claims. Never UIParent: Blizzard's binding stack sets overrides on
-- UIParent itself (Blizzard_GamepadSharedUtility/InputBindingStack/InputActionBinding.lua:22), so that owner is taken.
local claimFrame = CreateFrame("Frame", addonName .. "ClaimFrame")
ns.claimFrame = claimFrame

-- What is currently claimed on our frame, row -> key (kept so the rebinder knows the truth without
-- trusting GetBindingAction's override argument).
local claims = {}
ns.claims = claims

-- Re-claim the whole set from what the player chose (Bind.lua:46 RebuildClaims / :35 claimedKey).
-- The claim list is rebuilt from db.binds FIRST, then our frame's overrides are dropped wholesale and
-- rewritten - a moved or cleared row frees its old key automatically, no ghost claims. Only rows that
-- HAVE a key appear in the list, so the action argument is never nil (RebuildClaims skips keyless rows).
function ns.ApplyLayout()
	local live = ns.RebuildClaims()   -- rebuilt from db.binds, independent of the override state
	ClearOverrideBindings(claimFrame)   -- removes every override owned by our frame; Blizzard itself calls it this way on a frame (RestrictedFrames.lua:538); Blizzard's stack owns UIParent (InputActionBinding.lua:22)
	for row, key in pairs(live) do
		local action = ns.DefaultLayout[row] or ns.ChordRows[row]
		if action then   -- belt and braces: a row name never in our tables (stale saved data) is skipped, never passed as a nil action
			SetOverrideBinding(claimFrame, true, key, action)
		end
	end
end

function ns.ClearLayout()
	ClearOverrideBindings(claimFrame)   -- drop every override this frame set (Blizzard calls it on a frame at RestrictedFrames.lua:538)
	ns.claims = {}
end

-- R-1.2: one popup on the first login; nothing bound before the player says yes; after "No" the
-- popup never returns (db.bindsAsked); /ubermoc binds asks again.
local POPUP = addonName .. "_ASK_BINDS"
StaticPopupDialogs[POPUP] = {
	text = "UbermocForever can put Blizzard's controller layout on your gamepad buttons now. Nothing is changed until you press Accept.",
	button1 = ACCEPT,   -- Blizzard's own popup button strings (used by Blizzard at Blizzard_AuctionHouseFrame.lua:28)
	button2 = CANCEL,
	OnAccept = function()
		ns.db.bindsAsked = "yes"
		ns.ApplyLayout()
		ns:Print("controller layout applied. /ubermoc unbind removes it.")
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
		ns.ApplyLayout()   -- overrides are temporary: re-apply every login (harness lesson wow-api-notes.md:10)
	elseif ns.db.bindsAsked ~= "no" then
		StaticPopup_Show(POPUP)   -- the popup's handlers record yes/no; unanswered = asked, not decided
	end
end)

ns.SlashSubcommands = ns.SlashSubcommands or {}
ns.SlashSubcommands["binds"] = function()
	ns.db.bindsAsked = nil           -- ask again, whatever was answered before
	StaticPopup_Show(POPUP)
end
ns.SlashSubcommands["unbind"] = function()
	if InCombatLockdown() then   -- ClearOverrideBindings is restricted /nocombat (community docs; Blizzard guards its own use at RestrictedFrames.lua:24,538)
		ns:Print("in combat - bindings unchanged.")
		return
	end
	ns.ClearLayout()
	ns.db.bindsAsked = "no"
	ns:Print("controller layout removed (until you accept again).")
end
