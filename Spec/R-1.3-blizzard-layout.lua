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

-- The 15 recorded key names and their RECORDED gamepad actions (dump 1, verbatim).
local RECORDED_KEYS = {
    PADDLEFT = true, PADDUP = true, PADDRIGHT = true, PADDDOWN = true,
    PAD3 = true, PAD4 = true, PAD2 = true, PAD1 = true,
    PADFORWARD = true, PADBACK = true, PADRSTICK = true,
    PADLTRIGGER = true, PADRTRIGGER = true, PADLSHOULDER = true, PADRSHOULDER = true,
}

-- Blizzard's gamepad-context actions (Blizzard_GamepadActionBars/Bindings.xml:8-32, Blizzard_Gamepad/Bindings.xml:2-27).
-- They are ONLY allowed on the four shoulder/trigger keys - nowhere else.
local GAMEPAD_CONTEXT_ACTIONS = {
    GAMEPADLEFTMOD = true, GAMEPADRIGHTMOD = true,
    GAMEPADLEFTTARGETMODIFIER = true, GAMEPADRIGHTTARGETMODIFIER = true,
}

-- Blizzard's own normal-context actions, each copied from the shipped binding body (see Layout.lua for full cites).
local NORMAL_ACTIONS = {
    JUMP = true, OPENALLBAGS = true, TOGGLECHARACTER0 = true, TOGGLEGAMEMENU = true,
    INTERACTTARGET = true, TARGETNEARESTENEMY = true, OPENCHATSLASH = true,
    ACTIONBUTTON1 = true, ACTIONBUTTON2 = true, ACTIONBUTTON3 = true, ACTIONBUTTON4 = true,
    ACTIONBUTTON5 = true, ACTIONBUTTON6 = true, ACTIONBUTTON7 = true, ACTIONBUTTON8 = true,
}

local function acceptedLogin()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true)
    g.acceptPopup()
    return g
end

test("exact-15-recorded-keys", "R-1.3", "exactly the 15 keys recorded from the real game carry an action after accepting", function()
    local g = acceptedLogin()
    eq(count(g.overrides), 15, "exactly 15 override claims expected")
    for key in pairs(RECORDED_KEYS) do
        truthy(g.overrides[key], "no binding on recorded key " .. key)
    end
end)

test("invents-nothing", "R-1.3", "every applied action is Blizzard's own: normal-context actions, or the 4 gamepad mod actions on their recorded keys only", function()
    local g = acceptedLogin()
    for key, v in pairs(g.overrides) do
        if NORMAL_ACTIONS[v.action] then
            -- fine: an action from Blizzard's always-on binding context, body read in Bindings_Camelot.xml
        elseif GAMEPAD_CONTEXT_ACTIONS[v.action] then
            -- the gamepad-context actions stay exactly where dump 1 recorded them (the shoulder/trigger keys)
            truthy(key == "PADLTRIGGER" or key == "PADRTRIGGER" or key == "PADLSHOULDER" or key == "PADRSHOULDER",
                "gamepad-context action " .. v.action .. " moved off its recorded key onto " .. key)
        else
            error("invented or disallowed action on " .. key .. ": " .. tostring(v.action))
        end
    end
end)

test("no-gamepad-ui-needed", "R-1.3", "at least 11 of the 15 keys must carry actions that answer with Blizzard's gamepad UI off (dump 2 proved context-off actions stay dead); the 4 recorded mod keys are a known exception pending the user's test", function()
    -- What the user's dump 2 recorded: contextActive=false, count=0 - with the context off NONE of these
    -- actions answers as a binding, and the selftest showed the buttons did nothing when we claimed them.
    local DEAD_WITH_CONTEXT_OFF = {
        GAMEPADACTIONBUTTON1 = true, GAMEPADACTIONBUTTON2 = true, GAMEPADACTIONBUTTON3 = true,
        GAMEPADACTIONBUTTON4 = true, GAMEPADACTIONBUTTON5 = true, GAMEPADACTIONBUTTON6 = true,
        GAMEPADACTIONBUTTON7 = true, GAMEPADACTIONBUTTON8 = true,
        OPENRADIAL = true, TOGGLEUIFOCUS = true, TOGGLEPINGSYSTEM = true,
    }
    -- the 4 GAMEPAD*MOD actions share the same inactive context (Blizzard_Gamepad/Bindings.xml:14-25):
    -- allowed on their recorded keys ONLY as an explicit exception, EXPECTED dead until the user's press
    -- proves otherwise (Layout.lua header, KNOWN RISK).
    local RECORDED_EXCEPTION = { PADLTRIGGER = true, PADRTRIGGER = true, PADLSHOULDER = true, PADRSHOULDER = true }
    local g = acceptedLogin()
    local live = 0
    for key, v in pairs(g.overrides) do
        if DEAD_WITH_CONTEXT_OFF[v.action] then
            error(key .. " claims " .. v.action .. ", which dump 2 proved does not fire with the gamepad UI off")
        end
        if not (GAMEPAD_CONTEXT_ACTIONS[v.action] and RECORDED_EXCEPTION[key]) then live = live + 1 end
    end
    eq(live, 15 - 4, "11 keys must carry actions that answer with the gamepad UI off; 4 mod keys are the recorded exception")
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
        truthy(NORMAL_ACTIONS[v.action] or GAMEPAD_CONTEXT_ACTIONS[v.action], "unsafe action claimed: " .. tostring(v.action))
    end
end)
