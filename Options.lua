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

    -- No on/off toggles: if the addon is installed, it runs. Controller input
    -- is its whole purpose, so a switch to turn it off only creates the kind
    -- of "why is nothing bound" confusion the settings page should prevent.

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
    -- Slider options must be the table itself: the slider row reads
    -- initializer:GetOptions() and indexes it directly
    -- (Blizzard_SettingControls.lua:746-747). Only dropdown rows accept a
    -- function that builds their options.
    local scaleOptions = Settings.CreateSliderOptions(0.5, 2.0, 0.05)
    scaleOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
        function(value) return string.format("%.0f%%", value * 100) end)
    Settings.CreateSlider(category, scaleSetting, scaleOptions, "Scale of the UbermocForever window.")

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

    -- Controller Bindings section: real settings-list rows (native binding
    -- buttons, see BindingsUI.lua), appended below the regular options in the
    -- same vertical layout so they scroll and search like stock settings.
    if ns.AppendBindingSectionToLayout then
        ns:AppendBindingSectionToLayout(layout)
    end

    -- Small hint line under the rows (shown only while our page is open).
    if SettingsPanel and ns.BuildBindingPageExtras then
        ns:BuildBindingPageExtras(SettingsPanel:GetSettingsList())
    end
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
