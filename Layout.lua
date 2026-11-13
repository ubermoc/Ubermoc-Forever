-- Layout.lua: Blizzard's own default controller layout (REQUIREMENTS.md line 3) and the code that applies it.
--
-- WHAT THE LAYOUT IS: exactly the 15 gamepad keys recorded from the RUNNING game by /ubermoc dumpdefaults
-- on 2026-11-12 (WTF/Account/FAQJOO/SavedVariables/UbermocForever.lua, DefaultsDump.bindings, count=15).
-- The addon invents no key of its own; every action below is copied from Blizzard's shipped binding bodies
-- (cites on each line). No action is remembered or made up.
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
-- WHAT THIS LAYOUT USES INSTEAD: the same 15 keys, bound to Blizzard's own NORMAL-context actions - actions
-- from Blizzard's always-on Bindings.xml whose bodies we READ and verified do something in plain keyboard
-- mode (the user approved using Blizzard's recorded bindings, 2026-11-13; this keeps their keys and Blizzard's
-- own actions, only the context-off-dead ones are replaced by Blizzard's normal equivalents). The four
-- shoulder/trigger keys still carry the gamepad mod actions dump 1 recorded for them - KNOWN RISK: those
-- actions live in the SAME inactive GamepadModeInGameCore context (Blizzard_Gamepad/Bindings.xml:14-25), so by
-- the lesson above they very likely stay dead with Blizzard's gamepad UI off. They are kept only because dump 1
-- recorded exactly these actions on exactly those keys; if the user's button test shows them dead, replace
-- them with normal-context actions in the next change (candidates already looked up: TARGETNEARESTENEMY
-- Bindings_Camelot.xml:989, OPENCHATSLASH :115, INTERACTTARGET :1140).
--
-- HOW IT IS APPLIED: OVERRIDE bindings on an addon-owned frame (the mechanism Blizzard's own gamepad UI uses,
-- InputActionBinding.lua:22 SetOverrideBinding(owner, true, key, action); cleared with
-- SetOverrideBinding(owner, false, key, "") at InputBindingManager.lua:29). Overrides are temporary, need no
-- SaveBindings and work whatever the binding context is. Never UIParent as owner (Blizzard's stack owns that;
-- ClearOverrideBindings wipes ALL of an owner's claims - known-mistakes rule). Re-applied every PLAYER_LOGIN.
local addonName, ns = ...

-- The 15 keys verbatim from dump 1. Action sources are Blizzard's own shipped binding bodies (file:line):
--   ACTIONBUTTONn        Blizzard_FrameXML/Bindings_Camelot.xml:155-207 (ActionButtonDown(n)/ActionButtonUp(n))
--   OPENALLBAGS          Blizzard_FrameXML/Bindings_Camelot.xml:1190-1192 (ToggleAllBags(); defined ContainerFrame.lua:2173)
--   TOGGLECHARACTER0     Blizzard_FrameXML/Bindings_Camelot.xml:1194-1195 (ToggleCharacter("PaperDollFrame"); CharacterFrame.lua:3)
--   JUMP                 Blizzard_FrameXML/Bindings_Camelot.xml:53-57    (JumpOrAscendStart())
--   INTERACTTARGET       Blizzard_FrameXML/Bindings_Camelot.xml:1140-1141 (C_PlayerInteractionManager.InteractUnit("anyinteract"))
--   TARGETNEARESTENEMY   Blizzard_FrameXML/Bindings_Camelot.xml:989-995   (TargetNearestEnemy())
--   OPENCHATSLASH        Blizzard_FrameXML/Bindings_Camelot.xml:115-116   (ChatFrameUtil.OpenChat("/"); ChatFrameUtil.lua:448)
--   TOGGLEGAMEMENU       Blizzard_FrameXML/Bindings_Camelot.xml:1169-1170 (ToggleGameMenu(); Blizzard_GameMenuEsc.lua:109)
--   GAMEPADLEFTMOD / RIGHTMOD / LEFTTARGETMODIFIER / RIGHTTARGETMODIFIER: exactly as recorded in dump 1,
--     declared at Blizzard_Gamepad/Bindings.xml:14,17,21,25 - SAME context as the dead ones above, so these
--     four are EXPECTED DEAD with Blizzard's gamepad UI off (see KNOWN RISK in the header; user's test decides).
ns.BlizzardLayout = {
	PADDLEFT     = "ACTIONBUTTON1",
	PADDUP       = "ACTIONBUTTON2",
	PADDRIGHT    = "ACTIONBUTTON3",
	PADDDOWN     = "ACTIONBUTTON4",
	PAD3         = "ACTIONBUTTON5",
	PAD4         = "ACTIONBUTTON6",
	PAD2         = "ACTIONBUTTON7",
	PAD1         = "ACTIONBUTTON8",
	PADFORWARD   = "OPENALLBAGS",
	PADBACK      = "TOGGLEGAMEMENU",
	PADRSTICK    = "JUMP",
	PADLTRIGGER  = "GAMEPADLEFTMOD",
	PADRTRIGGER  = "GAMEPADRIGHTMOD",
	PADLSHOULDER = "GAMEPADLEFTTARGETMODIFIER",
	PADRSHOULDER = "GAMEPADRIGHTTARGETMODIFIER",
}

-- The frame that OWNS our override claims. Never UIParent (see header).
local claimFrame = CreateFrame("Frame", addonName .. "ClaimFrame")

function ns.ApplyLayout()
	for key, action in pairs(ns.BlizzardLayout) do
		SetOverrideBinding(claimFrame, true, key, action)
	end
end

function ns.ClearLayout()
	for key in pairs(ns.BlizzardLayout) do
		SetOverrideBinding(claimFrame, false, key, "")
	end
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
	ns.ClearLayout()
	ns.db.bindsAsked = "no"
	ns:Print("controller layout removed (until you accept again).")
end
