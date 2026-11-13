-- Options.lua: a page in the game's Settings window (checked against Blizzard's Forever source: Blizzard_Settings.lua).
local addonName, ns = ...

-- Runs on ADDON_LOADED of this addon, after Core.lua has created ns.db (Core's handler was registered first).
ns:RegisterEvent("ADDON_LOADED", function(loadedAddon)
    if loadedAddon ~= addonName or ns.settingsCategory then return end
    local category = Settings.RegisterVerticalLayoutCategory(addonName)
    ns.settingsCategory = category

    -- RegisterAddOnSetting(category, uniqueVariableName, keyInTable, theTable, type, label, default)
    local enabled = Settings.RegisterAddOnSetting(category, addonName .. "_Enabled", "enabled", ns.db,
        Settings.VarType.Boolean, "Enable " .. addonName, true)
    Settings.CreateCheckbox(category, enabled, "Turn the addon on or off.")

    Settings.RegisterAddOnCategory(category)
end)
