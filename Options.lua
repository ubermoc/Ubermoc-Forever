-- Options.lua: our page in the game's Settings window (REQUIREMENTS.md R-2.1).
--
-- BUILT ONLY from Blizzard's own settings API and templates, so it looks like a page Blizzard made:
-- Settings.RegisterVerticalLayoutCategory + RegisterAddOnSetting + CreateCheckbox are exactly what
-- Blizzard's own option pages use (Blizzard_Settings_Shared/Blizzard_Settings.lua:154
-- RegisterVerticalLayoutCategory, :174 RegisterAddOnSetting, :388 CreateCheckbox). The page appears in
-- the game's Esc -> Options list by Settings.RegisterAddOnCategory (:134); /ubermoc opens it with
-- Settings.OpenToCategory (:144).
--
-- NO "Enable UbermocForever" checkbox (user, 2026-11-13: redundant - if the mod is used it is enabled).
-- The old one is removed from the page AND deleted from saved data (db.enabled = nil) so nothing can
-- read it any more. Core's /ubermoc toggle command is gone for the same reason.
local addonName, ns = ...

-- Runs on ADDON_LOADED of this addon, after Core.lua has created ns.db (Core's handler was registered first).
ns:RegisterEvent("ADDON_LOADED", function(loadedAddon)
    if loadedAddon ~= addonName or ns.settingsCategory then return end

    -- drop the old redundant enable flag (R-2.1)
    if ns.db then ns.db.enabled = nil end

    local category = Settings.RegisterVerticalLayoutCategory(addonName)
    ns.settingsCategory = category

    -- Controller navigation of windows (R-2.3), a real Blizzard setting row: checkbox + tooltip, saved
    -- in our SavedVariables like every other add-on setting. On by default (plug and play).
    local nav = Settings.RegisterAddOnSetting(category, addonName .. "_NavWindows", "navWindows", ns.db,
        Settings.VarType.Boolean, "Controller navigation in windows", true)
    Settings.CreateCheckbox(category, nav,
        "D-pad moves the highlight between a window's buttons, PAD1 selects, PAD2 closes. Works in vendor and talk-to-NPC windows too.")

    -- The binding rows live on their own subpage of ours (R-2.2): Bind.lua registers its Blizzard-style
    -- setting rows into it when the addon loads.
    local binds = Settings.RegisterVerticalLayoutSubcategory(category, addonName .. " Binds")
    ns.bindsCategory = binds
    Settings.RegisterAddOnCategory(binds)

    Settings.RegisterAddOnCategory(category)
end)
