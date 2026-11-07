local _, ns = ...

-- Runs checks inside the game and stores the results in the saved variables,
-- so they can be read from disk after /reload without a screenshot.
-- Runs checks inside the game and stores results in saved variables for disk read
-- after /reload. Atlas names in ATLASES must exist in this build (verified against
-- in-game self test results); the legend does its own existence check at runtime.
local ATLASES = {
    "gamepad-xbox1-trigger-lt-normal",
    "gamepad-symbols-plus",
    "Gamepad_Gen_1_32",
    "Gamepad_Ltr_A_32",
    "Gamepad_Ltr_A_64",
    "Gamepad_Ltr_B_64", "Gamepad_Ltr_X_64", "Gamepad_Ltr_Y_64",
    "Gamepad_Ltr_LShoulder_64", "Gamepad_Ltr_RShoulder_64", "Gamepad_Ltr_RTrigger_64",
    "Gamepad_Ltr_Up_64", "Gamepad_Ltr_Menu_64",
    "gamepad-xbox1-buttona-normal", "gamepad-xbox1-dpadall-normal", "gamepad-footer-slot-bg",
}

local function add(results, name, ok, detail)
    results[#results + 1] = { name = name, ok = ok and true or false, detail = detail and tostring(detail) or "" }
end

function ns.RunSelfTest()
    local results = {}
    local _, build, _, toc = GetBuildInfo()

    for _, fn in ipairs({ "IsEnabled", "GetActiveDeviceID", "GetAllDeviceIDs", "GetDeviceMappedState",
        "ButtonIndexToBinding", "AxisIndexToConfigName", "StickIndexToConfigName" }) do
        add(results, "C_GamePad." .. fn, type(C_GamePad[fn]) == "function")
    end
    add(results, "SetOverrideBinding", type(SetOverrideBinding) == "function")
    add(results, "ClearOverrideBindings", type(ClearOverrideBindings) == "function")
    add(results, "GetBindingAction", type(GetBindingAction) == "function")

    add(results, "button 0 is PADDUP", C_GamePad.ButtonIndexToBinding(0) == "PADDUP", C_GamePad.ButtonIndexToBinding(0))
    add(results, "button 31 is PADSOCIAL", C_GamePad.ButtonIndexToBinding(31) == "PADSOCIAL", C_GamePad.ButtonIndexToBinding(31))

    for _, name in ipairs({ "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" }) do
        local value = C_CVar.GetCVar(name)
        add(results, "cvar " .. name .. " exists", value ~= nil, value)
    end

    -- The game's own gamepad cursor: the right stick moves it, and it turns on when windows open.
    for _, fn in ipairs({ "IsGamePadCursorControlEnabled", "SetGamePadCursorControl", "CanAutoSetGamePadCursorControl" }) do
        add(results, fn, type(_G[fn]) == "function")
    end
    if type(IsGamePadCursorControlEnabled) == "function" then
        add(results, "cursor control is on right now", true, tostring(IsGamePadCursorControlEnabled()))
    end
    -- Only cvars confirmed to exist in this build (build 70790); GamePadEmulateEsc is not one of them.
    for _, name in ipairs({ "GamePadCursorLeftClick", "GamePadCursorRightClick", "GamePadCursorCentering",
        "GamePadCursorForTargeting" }) do
        local value = C_CVar.GetCVar(name)
        add(results, "cvar " .. name .. " exists", value ~= nil, value)
    end

    -- Forever has its own gamepad interface; these show which game build this is.
    add(results, "info: Blizzard_Gamepad loaded", true, tostring(ns.HasNativeGamepad()))
    local contexts = Enum and Enum.BindingContext
    add(results, "info: GamepadModeInGameCore binding context", true, tostring(contexts and contexts.GamepadModeInGameCore ~= nil))
    add(results, "info: GamePadCursorAutoEnable", true, tostring(C_CVar.GetCVar("GamePadCursorAutoEnable")))
    add(results, "info: GamePadCursorAutoDisableSticks", true, tostring(C_CVar.GetCVar("GamePadCursorAutoDisableSticks")))

    local atlasApi = C_Texture and C_Texture.GetAtlasInfo
    for _, atlas in ipairs(ATLASES) do
        add(results, "atlas " .. atlas, atlasApi and atlasApi(atlas) ~= nil)
    end

    if ns.db and ns.db.layout and ns.db.layout.enabled then
        local c = ns.db.layout
        local ok = 0
        for slot = 1, 12 do
            if GetBindingAction(c.slots[slot], true) == "ACTIONBUTTON" .. slot then
                ok = ok + 1
            end
        end
        -- Phase 06: while a rotated context is live (spellbook/bags/NPC/menu
        -- with transitions on) the plain keys intentionally reach the
        -- utility bar, so a live mismatch is the designed state — report it
        -- the way v1.0.1 reports the hotkey display, instead of failing.
        -- In base contexts (COMBAT/NONE) the base profile must be live.
        local ctx = ns.Context and ns.Context.Current() or "NONE"
        local rotated = ns.Transitions ~= nil
            and ns.Transitions.Enabled()
            and ctx ~= "COMBAT" and ctx ~= "NONE"
        if rotated then
            add(results, "layout main bar bound (rotated profile live in " .. ctx .. ")", true,
                ok .. " of 12 under base profile; expected while context is " .. ctx)
        else
            add(results, "layout main bar bound", ok == 12, ok .. " of 12")
        end
        local extraOk, extraTotal = 0, 0
        for key, command in pairs(c.extras or {}) do
            if command ~= "NONE" then
                extraTotal = extraTotal + 1
                if GetBindingAction(key, true) == ns.Layout.BindingFor(command) then
                    extraOk = extraOk + 1
                end
            end
        end
        add(results, "layout other buttons bound", extraOk == extraTotal, extraOk .. " of " .. extraTotal)
    end

    -- What the action bar hotkey display actually sees. The bar computes exactly
    -- this (Blizzard_ActionBar/Shared/ActionButton.lua, UpdateHotkeys):
    --   key = GetBindingKey("ACTIONBUTTONn"); text = GetBindingText(key, 1)
    -- and shows the pad glyph only when IsBindingForGamePad(key).
    -- Which key the engine reports is engine slot priority, not registration:
    -- right after login the keyboard default ("1") is reported, and once the
    -- gamepad is engaged the pad key is reported (an in-game session with the
    -- identical binding set reported the pad key). The pad binding registration
    -- itself — what we control — is asserted above in "layout main bar bound".
    -- So report what the bar currently shows, but do not fail on it.
    if type(IsBindingForGamePad) == "function" then
        local key1 = GetBindingKey("ACTIONBUTTON1") or ""
        add(results, "display: ACTIONBUTTON1 key", key1 ~= "", key1)
        local ok, text = pcall(GetBindingText, key1, 1)
        add(results, "display: ACTIONBUTTON1 hotkey text non-empty", ok and text ~= "", ok and text or "error")
        add(results, "info: main bar slot 1 currently shows", true,
            (IsBindingForGamePad(key1) and "pad " or "keyboard ") .. key1)
        if C_KeyBindings and C_KeyBindings.IsBindingContextActive then
            add(results, "info: GamepadModeInGameCore context active", true,
                tostring(C_KeyBindings.IsBindingContextActive("GamepadModeInGameCore")))
        end
    end

    -- Checkpoint 5: the class layout (Layouts/<Class>/default.lua) loaded for this
    -- character, with the spells it keeps after the "does the character know it" filter.
    local layoutDb = ns.db and ns.db.layout
    local spells = layoutDb and layoutDb.spells
    if spells then
        local total = #spells.primary + #spells.secondary + #spells.tertiary
        add(results, "class layout loaded (" .. tostring(spells.spec_label) .. ")", total > 0,
            ("spec %s: %d primary, %d secondary, %d tertiary"):format(
                tostring(spells.spec_id), #spells.primary, #spells.secondary, #spells.tertiary))
    else
        add(results, "class layout loaded", false,
            "ns.db.layout.spells missing - check the log for a 'layout loaded for' line")
    end

    -- Phase 06: context transitions module started (bar profile switching +
    -- hint fade-in). Enabled by default; /ubf transitions off switches it off.
    if ns.Transitions then
        add(results, "transitions module started", ns.Transitions.Enabled(),
            "enabled=" .. tostring(ns.Transitions.Enabled()))
        add(results, "transitions FadeIn available", type(ns.Transitions.FadeIn) == "function")
    else
        add(results, "transitions module started", false, "ns.Transitions missing")
    end

    for _, id in ipairs({ {}, { vendorID = 10462, productID = 4607 } }) do
        local ok, config = pcall(C_GamePad.GetConfig, id)
        add(results, "info: label style " .. tostring(id.vendorID or "all devices"), true,
            ok and config and tostring(config.labelStyle) or "no config")
    end

    local failed = 0
    for _, r in ipairs(results) do
        if not r.ok then failed = failed + 1 end
    end
    ns.db.selftest = {
        time = date("%Y-%m-%d %H:%M:%S"),
        game = ns.gameType,
        toc = toc,
        build = build,
        passed = #results - failed,
        failed = failed,
        results = results,
    }
    print(ns.L.SELFTEST_DONE:format(#results - failed, failed))
    for _, r in ipairs(results) do
        if not r.ok then
            print("  - " .. r.name .. (r.detail ~= "" and (" (" .. r.detail .. ")") or ""))
        end
    end
end
