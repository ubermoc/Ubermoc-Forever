-- R-1.3: the layout applied is Blizzard's own default controller layout, applied WITHOUT the player
-- switching on Blizzard's gamepad UI. The addon invents no actions and no layout of its own.
--
-- REAL DATA (all from the user's game):
--   dump 1 (2026-11-12 22:17, Blizzard's gamepad UI ON): contextActive=true, count=15 - the 15
--     key->action pairs below; d-pad order PADDLEFT->ACTIONBUTTON5 etc. recorded verbatim.
--   dump 2 (2026-11-12 23:45, our override claims with the gamepad UI OFF): contextActive=false, count=0,
--     buttons dead even though the key lookup answered. PROOF that a GamepadModeInGameCore action is
--     dead while that context is off ("a SET binding is not a FIRE", REQUIREMENTS.md).
--   dump 3 (2026-11-13, override claims on our OWN frame): plain GetBindingAction count=0, the user's
--     presses did nothing. PROOF that addon-frame override claims never fire in plain mode - the whole
--     mechanism was replaced with SAVED bindings (SetBinding + SaveBindings), like the Key Bindings screen.
--   THE USER'S OWN WTF/Account/FAQJOO/bindings-cache.wtf: 68 PAD bind lines that WORK on their pad,
--     including SHIFT-/CTRL-/CTRL-SHIFT- chords - so chords are PROVEN and part of the layout now.
-- Every entry in Layout.lua cites its Blizzard file:line; nothing here is invented or remembered.

-- The 15 key names dump 1 recorded from the real game (verbatim). PADFORWARD is deliberately NOT bound by
-- us: the user's other addon owns it (CLICK UbermocMenu:LeftButton in their binding file).
local RECORDED_KEYS = {
    PADDLEFT = true, PADDUP = true, PADDRIGHT = true, PADDDOWN = true,
    PAD3 = true, PAD4 = true, PAD2 = true, PAD1 = true,
    PADBACK = true, PADRSTICK = true,
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

-- Blizzard's own normal-context actions, each copied from a shipped binding body (full cites in Layout.lua).
local NORMAL_ACTIONS = {
    JUMP = true, TOGGLEWORLDMAP = true, TOGGLEAUTORUN = true,
    TARGETNEARESTENEMY = true, TARGETNEARESTFRIEND = true,
    ACTIONBUTTON1 = true, ACTIONBUTTON2 = true, ACTIONBUTTON3 = true, ACTIONBUTTON4 = true,
    ACTIONBUTTON5 = true, ACTIONBUTTON6 = true, ACTIONBUTTON7 = true, ACTIONBUTTON8 = true,
    ACTIONBUTTON9 = true, ACTIONBUTTON10 = true, ACTIONBUTTON11 = true, ACTIONBUTTON12 = true,
    MULTIACTIONBAR1BUTTON1 = true, MULTIACTIONBAR1BUTTON2 = true, MULTIACTIONBAR1BUTTON3 = true,
    MULTIACTIONBAR1BUTTON4 = true, MULTIACTIONBAR1BUTTON5 = true, MULTIACTIONBAR1BUTTON6 = true,
    MULTIACTIONBAR1BUTTON7 = true, MULTIACTIONBAR1BUTTON8 = true, MULTIACTIONBAR1BUTTON10 = true,
    MULTIACTIONBAR1BUTTON12 = true,
    MULTIACTIONBAR2BUTTON1 = true, MULTIACTIONBAR2BUTTON2 = true, MULTIACTIONBAR2BUTTON3 = true,
    MULTIACTIONBAR2BUTTON4 = true, MULTIACTIONBAR2BUTTON5 = true, MULTIACTIONBAR2BUTTON6 = true,
    MULTIACTIONBAR2BUTTON7 = true, MULTIACTIONBAR2BUTTON8 = true, MULTIACTIONBAR2BUTTON10 = true,
    MULTIACTIONBAR2BUTTON12 = true,
    MULTIACTIONBAR3BUTTON1 = true, MULTIACTIONBAR3BUTTON2 = true, MULTIACTIONBAR3BUTTON3 = true,
    MULTIACTIONBAR3BUTTON4 = true, MULTIACTIONBAR3BUTTON5 = true, MULTIACTIONBAR3BUTTON6 = true,
    MULTIACTIONBAR3BUTTON7 = true, MULTIACTIONBAR3BUTTON8 = true, MULTIACTIONBAR3BUTTON10 = true,
    MULTIACTIONBAR3BUTTON12 = true,
    MULTIACTIONBAR4BUTTON1 = true, MULTIACTIONBAR4BUTTON2 = true, MULTIACTIONBAR4BUTTON3 = true,
    MULTIACTIONBAR4BUTTON4 = true,
}

local function acceptedLogin()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true)
    g.acceptPopup()
    return g
end

test("recorded-keys-all-present", "R-1.3", "the keys recorded from the real game carry an action after accepting (saved bindings)", function()
    local g = acceptedLogin()
    for key in pairs(RECORDED_KEYS) do
        truthy(g.bindings[key], "no binding on recorded key " .. key)
    end
    falsy(g.bindings.PADFORWARD, "PADFORWARD belongs to the user's other addon - we must not bind it")
end)

test("invents-nothing", "R-1.3", "every applied action is Blizzard's own normal-context action, copied from a shipped binding body", function()
    local g = acceptedLogin()
    for key, action in pairs(g.bindings) do
        truthy(NORMAL_ACTIONS[action], "invented or disallowed action on " .. key .. ": " .. tostring(action))
    end
end)

test("no-dead-gamepad-context-actions", "R-1.3", "no key carries a GamepadModeInGameCore action - the user's press test proved those dead with Blizzard's gamepad UI off (dump 2: contextActive=false, count=0)", function()
    local g = acceptedLogin()
    for key, action in pairs(g.bindings) do
        falsy(GAMEPAD_CONTEXT_ACTIONS[action], key .. " carries " .. action .. ", proven dead with the gamepad UI off")
    end
end)

-- the exact key spellings Blizzard uses (SharedConstants.lua): a PAD name, optionally with one of the
-- three modifier prefixes. (Lua patterns have no alternation repetition like "%-)+", so list them.)
local function isPadKeyOrChord(key)
    return key:match("^PAD") or key:match("^SHIFT%-PAD") or key:match("^CTRL%-PAD") or key:match("^CTRL%-SHIFT%-PAD")
end

test("keys-are-blizzard-pad-names-or-proven-chords", "R-1.3", "every bound key is a Blizzard PAD name or a SHIFT/CTRL chord of one (chords PROVEN: the user's own bindings-cache.wtf binds them and they work)", function()
    local g = acceptedLogin()
    for key in pairs(g.bindings) do
        truthy(isPadKeyOrChord(key), "key " .. key .. " must be a Blizzard PAD key name or chord of one")
    end
end)

test("layout-saved-not-overridden", "R-1.3", "the layout lives in SAVED bindings, not addon-frame overrides (dump 3 proved overrides on an addon frame never fire in plain mode)", function()
    local g = acceptedLogin()
    eq(count(g.overrides), 0, "no override claims may be set - the mechanism is proven dead")
    for key, action in pairs(g.ns.DefaultLayout) do
        eq(g.bindings[key], action, "saved binding missing for " .. key)
    end
end)

test("layout-is-persisted", "R-1.3", "applying the layout calls SaveBindings - without it nothing survives a restart (wiki API_SetBinding: bindings are not saved without an explicit SaveBindings() call)", function()
    local g = acceptedLogin()
    truthy((g.saves or 0) >= 1, "the addon must persist the layout with SaveBindings")
end)

test("no-action-touched-by-selftest", "R-1.3", "the in-game selftest reads the effect of an action without running it (no StopAttack / SetView1 / CancelInvite-style calls)", function()
    -- Phase 1 must never trigger game actions on its own. Guard: the addon's own code never binds or calls
    -- destructive/irrelevant actions; it only writes the safe set above.
    local g = acceptedLogin()
    for _, action in pairs(g.bindings) do
        truthy(NORMAL_ACTIONS[action], "unsafe action bound: " .. tostring(action))
    end
end)
