-- Options.lua: our page in the game's Settings window (REQUIREMENTS.md R-2.1).
--
-- THE PAGE IS A CANVAS CATEGORY holding our own frame (Bind.lua's UbermocForeverBindFrame): Blizzard
-- displays that frame directly when the category is selected - Blizzard_Settings_Shared/
-- Blizzard_ImplementationReadme.lua:11 "local category, layout = Settings.RegisterCanvasLayoutCategory(myFrame,
-- \"My Addon\")" and :26-27 "The settings system will display your frame when the category is selected."
-- WHY NOT THE OLD WAY: a VERTICAL layout category shows one row per REGISTERED setting; we registered no
-- settings at all, so the in-game probe (2026-11-13) showed an EMPTY page - "the settings page shows
-- absolutely nothing". The canvas is exactly what legacy addons used and still works.
-- NO expandable subcategory any more: the user (2026-11-13) said it "doesn't need to be there if there's
-- nothing in the first tab - move the binds in there", so the bind rows live on this one page.
--
-- The page appears in Esc -> Options through Settings.RegisterAddOnCategory (Blizzard_Settings.lua:134);
-- /ubermoc and the Esc-menu button open it with Settings.OpenToCategory (:144).
--
-- NO "Enable UbermocForever" checkbox (user, 2026-11-13: redundant - if the mod is used it is enabled).
-- The old one is removed from the page AND deleted from saved data (db.enabled = nil) so nothing can
-- read it any more. Core's /ubermoc toggle command is gone for the same reason. Same for the navWindows
-- checkbox: navigation in windows happens automatically, a stale saved value is deleted.
local addonName, ns = ...

-- Runs on ADDON_LOADED of this addon, after Core.lua has created ns.db (Core's handler was registered first).
ns:RegisterEvent("ADDON_LOADED", function(loadedAddon)
    if loadedAddon ~= addonName then return end

    -- drop the old redundant enable flag (R-2.1) and the navWindows checkbox (user 2026-11-13: window
    -- navigation happens automatically, no toggle). A stale saved value from an earlier build is deleted.
    if ns.db then
        ns.db.enabled = nil
        ns.db.navWindows = nil
    end

    -- Registration happens at PLAYER_LOGIN, NOT here: the canvas frame is Bind.lua's bind screen and
    -- Bind.lua loads AFTER this file (the .toc order), so its functions do not exist yet while this
    -- handler runs.
    ns:RegisterEvent("PLAYER_LOGIN", function()
        if ns.settingsCategory then return end

        -- The canvas frame is Bind.lua's bind screen. Create it WITHOUT showing: Blizzard's panel shows
        -- and parents the canvas frame itself when the category opens (see below), so at login we only
        -- build the controls and register them.
        if ns.CreateBindUI then ns.CreateBindUI() end
        local page = ns.bindFrame and ns.bindFrame()
        if not page then return end   -- nothing to show without our frame; chat says nothing (no crash)

        local category = Settings.RegisterCanvasLayoutCategory(page, addonName)
        ns.settingsCategory = category
        Settings.RegisterAddOnCategory(category)

        -- No reparenting by us: Blizzard's own panel does it. DisplayLayout for a Canvas layout takes our
        -- frame, sets its parent to the panel's SettingsCanvas, anchors it (no anchor points added =
        -- SetAllPoints) and shows it - Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua:949-950
        -- ("local frame = layout:GetFrame(); frame:SetParent(settingsCanvas); ... frame:Show();"). When the
        -- player leaves the category, ClearCurrentCategoryCanvas (:918-930: frame:SetParent(nil)) hides
        -- our frame again. So the frame simply sits in UIParent until a page opens.

        -- NO Settings.RegisterInitializer here. PROVEN IN GAME 2026-11-13 (user's Lua error):
        -- Blizzard_Settings_Shared/Blizzard_SettingsInbound.lua:153 passes { category, initializer } to
        -- SetAttribute and its OnAttributeChanged (:222) unpacks it with SecureUnpackArgs ->
        -- ErrorIfFunctionArgs (:19-26 "error(\"Function values are not allowed for settings APIs\")"), so a
        -- plain function is REJECTED (Blizzard wraps such functions in GenerateClosure first, :43-56, and
        -- only for the few APIs that opt into UnpackArgs - RegisterInitializer does not).
        -- We do not need it anyway: opening the page shows our frame (the panel parents and shows the
        -- canvas itself) and frame:Show() fires our OnShow watcher -> NavOpen re-arms the claims, at the
        -- moment the player can actually see the highlight.
    end)
end)
