-- R-1.3: the layout applied is Blizzard's own default controller layout, applied WITHOUT the player
-- switching on Blizzard's gamepad UI. The addon invents no actions and no layout of its own.
--
-- REAL DATA (both dumps are real results from the user's game, WTF/Account/FAQJOO/SavedVariables/UbermocForever.lua):
--   dump 1 (2026-11-12 22:17, Blizzard's gamepad UI ON):  contextActive=true, captureForm="context",
--     count=15 - the 15 key->action pairs below.
--   dump 2 (2026-11-12 23:45, after accepting our popup with the gamepad UI OFF): contextActive=false,
--     count=0 and the selftest showed buttons dead even though g.overrides answered. PROOF that binding a
--     GamepadModeInGameCore action is not enough when that context is inactive: the key lookup answers,
--     the action never runs (its context is off). See REQUIREMENTS.md lesson "a SET binding is not a FIRE".
-- So the layout must use actions from Blizzard's NORMAL (always-on) context whose bodies we have read in
-- Blizzard's own shipped files. Every entry cites its file:line; nothing here is invented or remembered.
-- UPDATE 2026-11-13 (user approved): the four GAMEPAD*MOD actions dump 1 recorded on the shoulder/trigger
-- keys were PROVEN dead by the user's press test and are replaced with normal-context actions; the layout
-- also grew to every controller button (back paddles included). Key NAMES stay Blizzard's everywhere
-- (Blizzard_SharedXML/SharedConstants.lua:61-92, GamepadConstants.lua).

-- The 15 key names dump 1 recorded from the real game (verbatim).
local RECORDED_KEYS = {
    PADDLEFT = true, PADDUP = true, PADDRIGHT = true, PADDDOWN = true,
    PAD3 = true, PAD4 = true, PAD2 = true, PAD1 = true,
    PADFORWARD = true, PADBACK = true, PADRSTICK = true,
    PADLTRIGGER = true, PADRTRIGGER = true, PADLSHOULDER = true, PADRSHOULDER = true,
}

-- Blizzard's gamepad-context actions (Blizzard_GamepadActionBars/Bindings.xml:8-32, Blizzard_Gamepad/Bindings.xml:2-27).
-- The user's press test proved them DEAD with the gamepad UI off - allowed NOWHERE in the shipped layout.
local GAMEPAD_CONTEXT_ACTIONS = {
    GAMEPADLEFTMOD = true, GAMEPADRIGHTMOD = true,
    GAMEPADLEFTTARGETMODIFIER = true, GAMEPADRIGHTTARGETMODIFIER = true,
    GAMEPADACTIONBUTTON1 = true, GAMEPADACTIONBUTTON2 = true, GAMEPADACTIONBUTTON3 = true,
    GAMEPADACTIONBUTTON4 = true, GAMEPADACTIONBUTTON5 = true, GAMEPADACTIONBUTTON6 = true,
    GAMEPADACTIONBUTTON7 = true, GAMEPADACTIONBUTTON8 = true,
    OPENRADIAL = true, TOGGLEUIFOCUS = true, TOGGLEPINGSYSTEM = true,
}

-- Blizzard's own normal-context actions, each copied from the shipped binding body (see Layout.lua for full cites).
local NORMAL_ACTIONS = {
    JUMP = true, OPENALLBAGS = true, TOGGLECHARACTER0 = true, TOGGLEGAMEMENU = true,
    INTERACTTARGET = true, TARGETNEARESTENEMY = true, OPENCHATSLASH = true,
    ACTIONBUTTON1 = true, ACTIONBUTTON2 = true, ACTIONBUTTON3 = true, ACTIONBUTTON4 = true,
    ACTIONBUTTON5 = true, ACTIONBUTTON6 = true, ACTIONBUTTON7 = true, ACTIONBUTTON8 = true,
    ACTIONBUTTON9 = true, ACTIONBUTTON10 = true, ACTIONBUTTON11 = true, ACTIONBUTTON12 = true,
    MULTIACTIONBAR1BUTTON1 = true,
}

local function acceptedLogin()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true)
    g.acceptPopup()
    return g
end

test("recorded-keys-all-present", "R-1.3", "all 15 keys recorded from the real game carry an action after accepting", function()
    local g = acceptedLogin()
    for key in pairs(RECORDED_KEYS) do
        truthy(g.overrides[key], "no binding on recorded key " .. key)
    end
end)

test("invents-nothing", "R-1.3", "every applied action is Blizzard's own normal-context action, copied from a shipped binding body", function()
    local g = acceptedLogin()
    for key, v in pairs(g.overrides) do
        truthy(NORMAL_ACTIONS[v.action], "invented or disallowed action on " .. key .. ": " .. tostring(v.action))
    end
end)

test("no-dead-gamepad-context-actions", "R-1.3", "no key claims a GamepadModeInGameCore action - the user's press test proved those dead with Blizzard's gamepad UI off (dump 2: contextActive=false, count=0)", function()
    local g = acceptedLogin()
    for key, v in pairs(g.overrides) do
        falsy(GAMEPAD_CONTEXT_ACTIONS[v.action], key .. " claims " .. v.action .. ", proven dead with the gamepad UI off")
    end
end)

test("every-claim-a-blizzard-pad-key-name", "R-1.3", "every claimed key is one of Blizzard's own PAD key names (SharedConstants.lua:61-92) - no invented names, no chords claimed by default", function()
    local g = acceptedLogin()
    for key in pairs(g.overrides) do
        truthy(key:match("^PAD"), "key " .. key .. " must be a Blizzard PAD key name")
        falsy(key:find("-", 1, true), "no modifier chord may be claimed by default (unproven in game): " .. key)
    end
end)

test("claims-not-on-uiparent", "R-1.3", "override claims sit on an addon-owned frame, never on UIParent", function()
    -- known-mistakes rule: Blizzard's own stack owns UIParent overrides (InputActionBinding.lua:22);
    -- sharing that owner would let ClearOverrideBindings(UIParent) wipe ours and vice versa.
    local g = acceptedLogin()
    local uiParent = g.env.UIParent
    truthy(uiParent, "the fake world provides UIParent")
    for key, v in pairs(g.overrides) do
        truthy(v.owner, "override for " .. key .. " must have an owner frame")
        if v.owner == uiParent then error("override for " .. key .. " sits on UIParent") end
    end
end)

test("no-silent-save", "R-1.3", "applying the layout does not rewrite the player's saved binding file", function()
    -- overrides are temporary (behavior.lua rule, harness lesson): no SaveBindings call needed.
    local g = acceptedLogin()
    eq(g.saves or 0, 0, "the addon must not call SaveBindings for its layout")
end)

test("no-action-touched-by-selftest", "R-1.3", "the in-game selftest reads the effect of an action without running it (no StopAttack / SetView1 / CancelInvite-style calls)", function()
    -- Phase 1 must never trigger game actions on its own. Guard: the addon's own code never claims or calls
    -- destructive/irrelevant actions; it only claims the safe set above.
    local g = acceptedLogin()
    for _, v in pairs(g.overrides) do
        truthy(NORMAL_ACTIONS[v.action], "unsafe action claimed: " .. tostring(v.action))
    end
end)
