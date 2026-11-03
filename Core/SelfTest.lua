local _, ns = ...

-- Runs checks inside the game and stores the results in the saved variables,
-- so they can be read from disk after /reload without a screenshot.
local ATLASES = {
    "gamepad-xbox1-trigger-lt-normal",
    "gamepad-symbols-plus",
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
    for _, name in ipairs({ "GamePadCursorLeftClick", "GamePadCursorRightClick", "GamePadCursorCentering",
        "GamePadCursorForTargeting", "GamePadEmulateEsc" }) do
        local value = C_CVar.GetCVar(name)
        add(results, "cvar " .. name .. " exists", value ~= nil, value)
    end

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
        add(results, "layout main bar bound", ok == 12, ok .. " of 12")
        local extraOk, extraTotal = 0, 0
        for key, command in pairs(c.extras or {}) do
            if command ~= "NONE" then
                extraTotal = extraTotal + 1
                if GetBindingAction(key, true) == command then
                    extraOk = extraOk + 1
                end
            end
        end
        add(results, "layout other buttons bound", extraOk == extraTotal, extraOk .. " of " .. extraTotal)
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
