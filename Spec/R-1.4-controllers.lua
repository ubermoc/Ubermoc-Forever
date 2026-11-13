-- R-1.4: works with Steam Deck and Steam Controller first, also Xbox, PlayStation and Switch
-- controllers; button names and icons shown match the connected controller.
--
-- What is testable OFFLINE: the layout uses Blizzard's own PAD key names (the game maps every
-- controller to those names itself - GamepadConstants.lua), so no code branches on controller kind,
-- and nothing in Phase 1 draws a button name or icon that could show the wrong one.
-- What is NOT testable offline: whether the icons/names shown later match the connected pad -
-- needs the user's real controllers (R-1.4 is then checked by the user).

local RECORDED_KEYS = {
    "PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN", "PAD3", "PAD4", "PAD2", "PAD1",
    "PADFORWARD", "PADBACK", "PADRSTICK", "PADLTRIGGER", "PADRTRIGGER",
    "PADLSHOULDER", "PADRSHOULDER",
}

test("layout-has-no-controller-specific-code", "R-1.4", "the layout table only uses Blizzard's PAD key names, which every controller maps to", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true); g.acceptPopup()
    for key in pairs(g.overrides) do
        truthy(key:match("^PAD"), "key " .. key .. " must be a Blizzard PAD key name")
    end
end)

test("same-layout-with-any-pad-count", "R-1.4", "the applied layout is identical with one pad, several pads or none reported yet", function()
    for _, pads in ipairs({ {5}, {5, 6}, {} }) do
        local g = World{ saved = nil, pads = pads, commands = {}, bindings = {} }
        g.login(true); g.acceptPopup()
        eq(count(g.overrides), 15, "layout must be applied regardless of how many pads the game reports")
    end
end)

test("no-icons-shown-yet", "R-1.4", "Phase 1 draws no button names or icons, so it cannot show a wrong one (guard against early regressions)", function()
    local g = World{ saved = nil, pads = {5}, commands = {}, bindings = {} }
    g.login(true); g.acceptPopup()
    for _, fr in ipairs(g.frames) do
        if fr.__name and fr.__name:find("Ubermoc") then
            falsy(fr.__scripts.OnGamePadButtonDown, "frame " .. fr.__name .. " must not draw pad art before Phase 2")
        end
    end
end)
