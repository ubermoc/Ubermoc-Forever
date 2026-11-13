-- R-2.1: our page in the game's Settings window is built from Blizzard's settings API, and there is NO
-- "Enable UbermocForever" checkbox anywhere: the old flag is gone from defaults AND deleted from saved
-- data of an upgrading install.
-- The fake world stubs the whole Settings namespace (behavior.lua:158: every unknown Settings function
-- returns a stub). Here we REPLACE it with recorders so the test sees exactly what our page registers.

local function loginWithSaved(saved)
    local g = World{ saved = saved, pads = {5}, commands = {}, bindings = {} }
    -- recorder BEFORE login: Options.lua runs on ADDON_LOADED
    g.env.Settings = {
        VarType = { Boolean = "boolean", Number = "number", String = "string" },
        RegisterVerticalLayoutCategory = function(name) g.settingsCategories = g.settingsCategories or {}; g.settingsCategories[name] = { settings = {} }; return { name = name, GetID = function() return 1 end } end,
        RegisterVerticalLayoutSubcategory = function(parent, name) g.settingsSubs = g.settingsSubs or {}; g.settingsSubs[#g.settingsSubs + 1] = name; return { name = name, GetID = function() return 2 end } end,
        RegisterAddOnCategory = function(cat) g.registered = (g.registered or 0) + 1; return cat end,
        RegisterAddOnSetting = function(cat, uniqueName, keyInTable, tbl, vtype, label, default)
            g.settingsRegistered = g.settingsRegistered or {}
            g.settingsRegistered[#g.settingsRegistered + 1] = { uniqueName = uniqueName, key = keyInTable, label = label }
            return { uniqueName = uniqueName }
        end,
        CreateCheckbox = function(cat, setting, tooltip)
            g.settingsCheckboxes = g.settingsCheckboxes or {}
            g.settingsCheckboxes[#g.settingsCheckboxes + 1] = setting.uniqueName
            return {}
        end,
    }
    g.login(true)
    return g
end

test("no-enable-setting", "R-2.1", "the page registers no Enable checkbox at all", function()
    local g = loginWithSaved(nil)
    for _, s in ipairs(g.settingsRegistered or {}) do
        falsy(s.label:find("Enable"), "a setting labelled Enable must not exist: " .. s.label)
        if s.key == "enabled" then error("no setting may write db.enabled") end
    end
    for _, name in ipairs(g.settingsCheckboxes or {}) do
        falsy(name:find("Enabled"), "checkbox registered for the old enable flag: " .. name)
    end
end)

test("page-uses-blizzard-api", "R-2.1", "the page is registered through Blizzard's own Settings API", function()
    local g = loginWithSaved(nil)
    truthy(g.settingsCategories and g.settingsCategories["UbermocForever"], "category UbermocForever registered via RegisterVerticalLayoutCategory")
    truthy((g.registered or 0) >= 2, "category + subcategory both registered with RegisterAddOnCategory")
end)

test("old-enable-flag-deleted", "R-2.1", "an upgrading install has db.enabled removed from saved data", function()
    local g = loginWithSaved({ enabled = false, bindsAsked = "yes" })   -- old-style saved data
    falsy(g.ns.db.enabled, "db.enabled must be nil after load (redundant flag deleted)")
end)

test("no-nav-toggle-setting", "R-2.1", "there is NO navWindows checkbox: window navigation happens automatically (user 2026-11-13)", function()
    local g = loginWithSaved(nil)
    for _, s in ipairs(g.settingsRegistered or {}) do
        if s.key == "navWindows" then error("a navWindows setting row must not exist") end
        falsy((s.label or ""):find("navigation"), "no navigation toggle row: " .. tostring(s.label))
    end
end)

test("stale-nav-flag-deleted", "R-2.1", "an upgrading install has a stale db.navWindows deleted from saved data", function()
    local g = loginWithSaved({ navWindows = false, bindsAsked = "yes" })   -- saved by an older build
    falsy(g.ns.db.navWindows, "db.navWindows must be nil after load (the toggle is gone for good)")
end)
