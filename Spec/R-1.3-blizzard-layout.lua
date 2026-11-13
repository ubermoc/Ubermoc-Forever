-- R-1.3: the layout applied is Blizzard's own default controller layout (the 15 bindings
-- recorded from the real game by dumpdefaults), applied WITHOUT the player switching on
-- Blizzard's gamepad UI. The addon invents no actions and no layout of its own.

-- Real recorded data, verbatim from WTF/Account/FAQJOO/SavedVariables/UbermocForever.lua
-- (Defaults.bindings, count=15, contextActive=true, captureForm="context").
local RECORDED = {
    PADDLEFT    = "GAMEPADACTIONBUTTON1",
    PADDUP      = "GAMEPADACTIONBUTTON2",
    PADDRIGHT   = "GAMEPADACTIONBUTTON3",
    PADDDOWN    = "GAMEPADACTIONBUTTON4",
    PAD3        = "GAMEPADACTIONBUTTON5",
    PAD4        = "GAMEPADACTIONBUTTON6",
    PAD2        = "GAMEPADACTIONBUTTON7",
    PAD1        = "GAMEPADACTIONBUTTON8",
    PADFORWARD  = "OPENRADIAL",
    PADBACK     = "TOGGLEUIFOCUS",
    PADRSTICK   = "TOGGLEPINGSYSTEM",
    PADLTRIGGER = "GAMEPADLEFTMOD",
    PADRTRIGGER = "GAMEPADRIGHTMOD",
    PADLSHOULDER= "GAMEPADLEFTTARGETMODIFIER",
    PADRSHOULDER= "GAMEPADRIGHTTARGETMODIFIER",
}

local function acceptedLogin()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true)
    g.acceptPopup()
    return g
end

test("exact-recorded-set", "R-1.3", "after accepting, exactly the 15 recorded key/action pairs are in effect", function()
    local g = acceptedLogin()
    local applied = {}
    for k, v in pairs(g.overrides) do applied[k] = v.action end
    for k, v in pairs(g.bindings) do applied[k] = v end
    eq(count(applied), 15, "exactly 15 bindings must be in effect")
    for key, action in pairs(RECORDED) do
        eq(applied[key], action, key .. ": Blizzard's recorded action expected")
    end
end)

test("invents-nothing", "R-1.3", "every applied action name is one of the 15 actions Blizzard itself declares for gamepad", function()
    -- These are exactly the actions in Blizzard_GamepadActionBars/Bindings.xml:8-32 and
    -- Blizzard_Gamepad/Bindings.xml:2-27. Nothing else may appear.
    local blizzardActions = {
        GAMEPADACTIONBUTTON1 = true, GAMEPADACTIONBUTTON2 = true, GAMEPADACTIONBUTTON3 = true,
        GAMEPADACTIONBUTTON4 = true, GAMEPADACTIONBUTTON5 = true, GAMEPADACTIONBUTTON6 = true,
        GAMEPADACTIONBUTTON7 = true, GAMEPADACTIONBUTTON8 = true,
        OPENRADIAL = true, TOGGLEUIFOCUS = true, TOGGLEPINGSYSTEM = true,
        GAMEPADLEFTMOD = true, GAMEPADRIGHTMOD = true,
        GAMEPADLEFTTARGETMODIFIER = true, GAMEPADRIGHTTARGETMODIFIER = true,
    }
    local g = acceptedLogin()
    for k, v in pairs(g.overrides) do
        truthy(blizzardActions[v.action], "invented action on " .. k .. ": " .. tostring(v.action))
    end
    for k, v in pairs(g.bindings) do
        truthy(blizzardActions[v], "invented action bound normally on " .. k .. ": " .. tostring(v))
    end
end)

test("no-gamepad-ui-needed", "R-1.3", "the layout is applied with Blizzard's gamepad UI off (plain keyboard-mode world)", function()
    -- What a player without Blizzard's gamepad UI looks like: the GamepadModeInGameCore context is
    -- not active, so NONE of these actions answers as a normal binding (GetBindingKey finds no key).
    -- The layout must still be fully applied. This mirrors our own first dump: count 0 with the
    -- context off, while the gamepad UI's override claims were in effect.
    local g = acceptedLogin()
    for _, action in pairs(RECORDED) do
        local k1 = select(1, g.env.GetBindingKey(action))   -- the game's own lookup, inside this world
        falsy(k1, action .. ": this world must have no NORMAL binding for it (gamepad UI off)")
    end
    eq(count(g.overrides), 15, "layout must be fully applied in this world too")
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
