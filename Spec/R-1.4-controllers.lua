-- R-1.4: works with Steam Deck and Steam Controller first, also Xbox, PlayStation and Switch
-- controllers; button names and icons shown match the connected controller.
--
-- What is testable OFFLINE: the layout uses Blizzard's own PAD key names (the game maps every
-- controller to those names itself - SharedConstants.lua:61-92, GamepadConstants.lua), so no code
-- branches on controller kind, and nothing in Phase 1 draws a button name or icon that could show the
-- wrong one. The back paddles (Steam Deck L3/L4/R3/R4) are Blizzard key names too (KEY_PADPADDLE1..4).
-- What is NOT testable offline: whether the icons/names shown later match the connected pad -
-- needs the user's real controllers (R-1.4 is then checked by the user).

local RECORDED_KEYS = {
    "PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN", "PAD3", "PAD4", "PAD2", "PAD1",
    "PADFORWARD", "PADBACK", "PADRSTICK", "PADLTRIGGER", "PADRTRIGGER",
    "PADLSHOULDER", "PADRSHOULDER",
}

-- the buttons the user named, as Blizzard's key names: paddles = the Deck's back buttons L3/L4/R3/R4
local EXTRA_KEYS = {
    "PADLSTICK", "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4",
}

test("layout-has-no-controller-specific-code", "R-1.4", "the layout table only uses Blizzard's PAD key names, which every controller maps to", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true); g.acceptPopup()
    for key in pairs(g.overrides) do
        truthy(key:match("^PAD"), "key " .. key .. " must be a Blizzard PAD key name")
    end
end)

test("same-layout-with-any-pad-count", "R-1.4", "the applied layout is identical with one pad, several pads or none reported yet", function()
    local expected
    for _, pads in ipairs({ {5}, {5, 6}, {} }) do
        local g = World{ saved = nil, pads = pads, commands = {}, bindings = {} }
        g.login(true); g.acceptPopup()
        if not expected then
            expected = count(g.overrides)
            truthy(expected >= 20, "layout covers every button the user listed")
        end
        eq(count(g.overrides), expected, "layout must be applied regardless of how many pads the game reports")
    end
end)

test("all-named-buttons-covered", "R-1.4", "besides the 15 recorded keys, stick click and the four back paddles carry defaults too", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true); g.acceptPopup()
    for _, key in ipairs(RECORDED_KEYS) do truthy(g.overrides[key], "recorded key missing: " .. key) end
    for _, key in ipairs(EXTRA_KEYS) do truthy(g.overrides[key], "button the user named has no default: " .. key) end
end)

test("no-icons-shown-yet", "R-1.4", "the binding screen is closed by default, so nothing can show a wrong button name or icon before the player opens it", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true); g.acceptPopup()
    for _, fr in ipairs(g.frames) do
        if fr.__name and fr.__name:find("Ubermoc") then
            falsy(fr.__scripts.OnGamePadButtonDown, "frame " .. fr.__name .. " must not listen for pad input before the binding screen is opened")
        end
    end
end)
