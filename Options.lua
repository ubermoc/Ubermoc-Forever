-- UbermocForever/Options.lua
local addonName, ns = ...

-- Build the Settings UI using the modern Settings API (WoW 10+)
local function BuildSettings()
    if not Settings then return end
    if ns.settingsCategory then return end
    -- RegisterAddOnSetting writes straight into this table, so every setting
    -- must share one instance: the SavedVariables table itself. Never fall
    -- back to a throwaway `{}`, which would silently lose persistence.
    local db = ns.db or UbermocForeverDB
    if not db then return end

    local category, layout = Settings.RegisterVerticalLayoutCategory("UbermocForever")
    ns.settingsCategory = category

    -- Enable toggle
    local enableSetting = Settings.RegisterAddOnSetting(
        category, addonName .. "_Enabled", "enabled", db,
        Settings.VarType.Boolean, "Enable UbermocForever", true)
    Settings.CreateCheckbox(category, enableSetting, "Turn UbermocForever on or off.")

    -- Controller enable toggle
    local ctrlSetting = Settings.RegisterAddOnSetting(
        category, addonName .. "_ControllerEnabled", "controllerEnabled", db,
        Settings.VarType.Boolean, "Enable controller input", true)
    Settings.CreateCheckbox(category, ctrlSetting, "Turn controller input on or off.")

    -- Controller type. The game reports every pad through C_GamePad; we read
    -- its USB vendor id and Blizzard's own button-label family to name it
    -- (Sony / Xbox / Nintendo / Valve pads are recognised automatically).
    -- "Auto-detect" uses that result. Pick a console style manually if the
    -- automatic detection gets it wrong for your pad.
    local function GetControllerTypeValue() return tonumber(db.controllerType) or 0 end
    local function SetControllerTypeValue(value) db.controllerType = tonumber(value) or 0 end
    local typeSetting = Settings.RegisterProxySetting(
        category, addonName .. "_ControllerType",
        Settings.VarType.Number, "Controller Type", 0,
        GetControllerTypeValue, SetControllerTypeValue)
    local function GetTypeOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(0, "Auto-detect")
        container:Add(1, "PlayStation (DualShock)")
        container:Add(2, "Xbox")
        container:Add(3, "Nintendo Switch")
        container:Add(4, "Steam Controller / Steam Deck")
        container:Add(5, "Generic controller")
        return container:GetData()
    end
    Settings.CreateDropdown(category, typeSetting, GetTypeOptions,
        "Which controller layout to use. Auto-detect reads the connected device's vendor id and button-label style.")
    -- Current detection is reported by /ubermoc (chat), since the Settings API
    -- in this client has no per-row live status hook.

    local scaleSetting = Settings.RegisterAddOnSetting(
        category, addonName .. "_Scale", "scale", db,
        Settings.VarType.Number, "Scale", 1.0)
    local function GetOptions()
        local container = Settings.CreateSliderOptions(0.5, 2.0, 0.05)
        container:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(value) return string.format("%.0f%%", value * 100) end)
        return container
    end
    -- Pass the function, not its result: Blizzard accepts either
    -- (Blizzard_Settings.lua CreateSlider), and the function form lets the
    -- options be rebuilt when the row refreshes.
    Settings.CreateSlider(category, scaleSetting, GetOptions, "Scale of the UbermocForever window.")

    -- Blizzard's own Keybindings page is where controller and keyboard binds
    -- live. There is no button widget in the Settings API, so this acts like a
    -- link: a proxy setting whose SetValue runs immediately when you tick it,
    -- jumping to that page. GetValue always reports "off" so it never looks
    -- stuck on.
    local function GetAlwaysOff() return false end
    local function JumpToKeybinds() ns:OpenKeybinds() end
    local jumpSetting = Settings.RegisterProxySetting(
        category, addonName .. "_JumpToKeybinds",
        Settings.VarType.Boolean, "Open the Keybindings page", false,
        GetAlwaysOff, JumpToKeybinds)
    Settings.CreateCheckbox(category, jumpSetting,
        "Opens the game's Keybindings settings, where you can bind keys and controller buttons.")

    -- Controller bindings. Same link trick as above: ticking a row starts
    -- capture for that action (press any controller button to bind it), and
    -- the row never stays checked. The current binding for each action is
    -- shown by /ubermoc bindlist, with icons for the connected pad's buttons.
    local function BindAction(actionID)
        return function()
            if ns.StartCapture then
                ns:StartCapture(actionID)
                ns:Print(("Press a controller button for %s.")
                    :format(ns.actionByID[actionID].name))
            end
        end
    end

    local function ClearAllBindings()
        if ns.ResetBindingsToDefault then
            ns:ResetBindingsToDefault()
            ns:Print("controller bindings reset to defaults.")
        end
    end

    for _, action in ipairs(ns.ACTIONS or {}) do
        local bindSetting = Settings.RegisterProxySetting(
            category, addonName .. "_Bind_" .. action.id,
            Settings.VarType.Boolean, "Bind: " .. action.name, false,
            GetAlwaysOff, BindAction(action.id))
        Settings.CreateCheckbox(category, bindSetting,
            "Tick this row, then press the controller button you want to use for this action.")
    end

    local resetSetting = Settings.RegisterProxySetting(
        category, addonName .. "_BindReset",
        Settings.VarType.Boolean, "Reset controller bindings", false,
        GetAlwaysOff, ClearAllBindings)
    Settings.CreateCheckbox(category, resetSetting,
        "Restores the default controller bindings (shoulder buttons and face/trigger buttons).")

    -- Live device readout. This client's Settings API has no text-label row,
    -- so the current pad is mirrored to a CVar: its value shows as the
    -- dropdown's selection (the options themselves are inert). The CVar is
    -- registered at load time, before the Settings rows are ever built.
    local DEVICE_CVAR = "UBERMOC_DEVICE_INFO"

    function ns:RefreshDeviceReadout()
        if not C_CVar.GetCVarDefault(DEVICE_CVAR) then
            C_CVar.RegisterCVar(DEVICE_CVAR)
        end
        local text
        if ns.controllerConnected then
            text = ns:GetDeviceSummary()
        else
            text = "no gamepad detected"
        end
        if C_CVar.GetCVar(DEVICE_CVAR) ~= text then
            C_CVar.SetCVar(DEVICE_CVAR, text)
        end
    end

    local function GetDeviceInfoValue() return C_CVar.GetCVar(DEVICE_CVAR) or "" end
    local function IgnoreDeviceOption(value)
        -- Informational row: never store a choice, put the live value back.
        C_CVar.SetCVar(DEVICE_CVAR, GetDeviceInfoValue())
    end
    local deviceSetting = Settings.RegisterProxySetting(
        category, addonName .. "_DeviceInfo",
        Settings.VarType.String, "Controller detected", "",
        GetDeviceInfoValue, IgnoreDeviceOption)
    local function GetDeviceOptions()
        local container = Settings.CreateControlTextContainer()
        -- The current pad is the only real entry; the dummy keeps the dropdown
        -- functional so its label can show the live device name.
        local text = C_CVar.GetCVar(DEVICE_CVAR) or "no gamepad detected"
        container:Add(text, text)
        container:Add("UBERMOC_DEVICE_INFO_NONE", "(this row only shows information)")
        return container:GetData()
    end
    Settings.CreateDropdown(category, deviceSetting, GetDeviceOptions,
        "The controller the game currently sees and its button-label style. Also shown by /ubermoc bindlist.")

    ns:RegisterEvent("GAME_PAD_CONNECTED", ns.RefreshDeviceReadout)
    ns:RegisterEvent("GAME_PAD_DISCONNECTED", ns.RefreshDeviceReadout)
    ns:RegisterEvent("GAME_PAD_ACTIVE_CHANGED", ns.RefreshDeviceReadout)

    Settings.RegisterAddOnCategory(category)
end

local function tryBuild()
    if not Settings or not (ns.db or UbermocForeverDB) then return false end
    if ns.settingsCategory then return true end -- already built
    BuildSettings()
    return true
end

-- Build settings when the player logs in (ensures Settings API and SavedVariables are ready)
ns:RegisterEvent("PLAYER_LOGIN", function()
    if not tryBuild() then
        -- Defer until both Settings and ns.db are available
        ns:RegisterEvent("PLAYER_ENTERING_WORLD", tryBuild)
    end
end)
