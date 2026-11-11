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
    Settings.CreateSlider(category, scaleSetting, GetOptions(), "Scale of the UbermocForever window.")

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
