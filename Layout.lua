-- Layout.lua: Blizzard's own default controller layout (REQUIREMENTS.md line 3) and the code that applies it.
--
-- WHAT THE LAYOUT IS: the 15 key -> action pairs read from the RUNNING game by /ubermoc dumpdefaults on
-- 2026-11-12 (WTF/Account/FAQJOO/SavedVariables/UbermocForever.lua, Defaults.bindings, count=15).
-- The actions are exactly the ones Blizzard declares for gamepad in
-- Blizzard_GamepadActionBars/Bindings.xml:8-32 and Blizzard_Gamepad/Bindings.xml:2-27.
-- The addon invents no action and no key of its own.
--
-- HOW IT IS APPLIED (why not SetBinding): with Blizzard's gamepad UI off, the bindingContext
-- "GamepadModeInGameCore" is inactive (Blizzard_Gamepad/Core.lua:48-56 activates it only from
-- InputUtil.RegisterGamepadInit/Uninit), so those hidden context actions do not answer as bindings at all -
-- proven by our own first dump: count 0 with the context off. The mechanism Blizzard's own gamepad UI uses to
-- put keys on buttons is OVERRIDE bindings (Blizzard_GamepadSharedUtility/InputBindingStack/
-- InputActionBinding.lua:22 SetOverrideBinding(owner, true, key, action); cleared with
-- SetOverrideBinding(owner, false, key, "") at InputBindingManager.lua:29). Overrides are temporary, need no
-- SaveBindings and work whatever the binding context is. We copy that mechanism, but on an ADDON-OWNED frame:
-- Blizzard's stack owns UIParent's overrides (InputActionBinding.lua:22 uses UIParent) and ClearOverrideBindings
-- wipes ALL of an owner's claims, so sharing UIParent would break Blizzard's UI and ours (known-mistakes rules).
local addonName, ns = ...

-- Verbatim from the recorded dump. Key spellings are Blizzard's own (GamepadConstants.lua).
ns.BlizzardLayout = {
	PADDLEFT     = "GAMEPADACTIONBUTTON1",
	PADDUP       = "GAMEPADACTIONBUTTON2",
	PADDRIGHT    = "GAMEPADACTIONBUTTON3",
	PADDDOWN     = "GAMEPADACTIONBUTTON4",
	PAD3         = "GAMEPADACTIONBUTTON5",
	PAD4         = "GAMEPADACTIONBUTTON6",
	PAD2         = "GAMEPADACTIONBUTTON7",
	PAD1         = "GAMEPADACTIONBUTTON8",
	PADFORWARD   = "OPENRADIAL",
	PADBACK      = "TOGGLEUIFOCUS",
	PADRSTICK    = "TOGGLEPINGSYSTEM",
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
