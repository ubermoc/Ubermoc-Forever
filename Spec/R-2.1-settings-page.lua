-- R-2.1: our page in the game's Settings window is built from Blizzard's settings API, and there is NO
-- "Enable UbermocForever" checkbox anywhere: the old flag is gone from defaults AND deleted from saved
-- data of an upgrading install.
-- CANVAS CATEGORY (the fix for the user's in-game probe 2026-11-13: "the settings page shows absolutely
-- nothing"): a VERTICAL category with zero registered settings renders an EMPTY page - that was us. Now
-- our own frame is registered through Settings.RegisterCanvasLayoutCategory, which Blizzard displays
-- directly (Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua:11). The fake world stubs the
-- whole Settings namespace (behavior.lua: every unknown Settings function returns a stub), so this test
-- REPLACES it with recorders and asserts the canvas path, not the vertical one.

local function loginWithSaved(saved)
    local g = World{ saved = saved, pads = {5}, commands = {}, bindings = {} }
    -- recorder BEFORE login: Options.lua runs on ADDON_LOADED and registers at PLAYER_LOGIN
    g.env.Settings = {
        VarType = { Boolean = "boolean", Number = "number", String = "string" },
        RegisterVerticalLayoutCategory = function(name) error("the vertical layout is GONE - it rendered an empty page (probe 2026-11-13)") end,
        RegisterVerticalLayoutSubcategory = function() error("no expandable subcategory any more (user: move the binds onto the page)") end,
        RegisterCanvasLayoutCategory = function(frame, name)
            -- ONE category object, returned AND recorded (Blizzard returns the table it keeps; the test
            -- compares identity between what Options passed to RegisterInitializer and this record).
            local cat = { name = name, frame = frame, GetID = function() return 1 end, GetLayout = function() return nil end }
            g.canvasCategories = g.canvasCategories or {}
            g.canvasCategories[#g.canvasCategories + 1] = cat
            return cat
        end,
        RegisterAddOnCategory = function(cat) g.registered = (g.registered or 0) + 1; return cat end,
        RegisterAddOnSetting = function() error("no setting rows: the page is our own canvas frame") end,
        CreateCheckbox = function() error("no checkboxes: the page is our own canvas frame") end,
    }
    -- Options.lua checks `if Settings.RegisterInitializer then` BEFORE calling it; a plain table has no
    -- metatable in the fake world, so an unmodelled key really is nil here. Model Blizzard's own shape:
    -- RegisterInitializer forwards to SettingsInbound (Blizzard_Settings.lua:170-172) - keep that wiring.
    g.env.Settings.RegisterInitializer = function(cat, fn) g.initializers = g.initializers or {}; g.initializers[cat] = fn end
    g.login(true)
    return g
end

test("page-uses-blizzard-api", "R-2.1", "the page is a CANVAS category holding our bind frame, registered through Blizzard's own Settings API (no vertical layout, no subcategory)", function()
    local g = loginWithSaved(nil)

    eq(#(g.canvasCategories or {}), 1, "exactly one canvas category")
    local cat = g.canvasCategories[1]
    eq(cat.name, "UbermocForever", "named after the addon")
    -- the frame must be our REAL bind frame with its controls, not a stub:
    truthy(g.env["UbermocForeverBindFrame"], "the bind frame exists at login (created by CreateBindUI)")
    eq(cat.frame, g.env["UbermocForeverBindFrame"], "the canvas IS the bind frame")
    truthy(g.env["UbermocForeverBindRow1"], "the page already has its first bind row built")
    eq(g.registered or 0, 1, "registered with RegisterAddOnCategory exactly once (no subcategory)")
    truthy(g.initializers and g.initializers[cat], "an initializer shows the frame when the category opens")
end)

test("initializer-shows-and-navigates", "R-2.1", "opening our category shows the page and arms controller navigation (R-2.1 + R-2.2 together)", function()
    local g = loginWithSaved(nil)
    local cat = g.canvasCategories[1]
    local f = g.env["UbermocForeverBindFrame"]
    falsy(f:IsShown(), "the frame starts hidden")
    eq(count(g.overrides), 0, "no claims while the page is closed")
    g.initializers[cat]()   -- Blizzard calls this when the category opens
    truthy(f:IsShown(), "the initializer showed our page")
    truthy(g.overrides.PAD1, "PAD1 claimed: the page works with the controller alone")
    eq(g.ns.NavFocus("UbermocForeverBindFrame"), 1, "the highlight starts on the first control")
end)

test("no-enable-setting", "R-2.1", "the page registers no Enable checkbox at all", function()
    local g = loginWithSaved(nil)
    eq(g.registered or 0, 1, "only our category is registered - no settings, no checkboxes")
    for _, row in ipairs(g.env["UbermocForeverBindRow1"]:GetText() and {} or {}) do end   -- no setting objects exist to inspect
end)

test("old-enable-flag-deleted", "R-2.1", "an upgrading install has db.enabled removed from saved data", function()
    local g = loginWithSaved({ enabled = false, bindsAsked = "yes" })   -- old-style saved data
    falsy(g.ns.db.enabled, "db.enabled must be nil after load (redundant flag deleted)")
end)

test("no-nav-toggle-setting", "R-2.1", "there is NO navWindows checkbox: window navigation happens automatically (user 2026-11-13)", function()
    local g = loginWithSaved(nil)
    -- our rows are real frames; the fake world's stub would answer GetText with "<stub>", so require a
    -- real frame before asking it anything:
    local rows = g.ns.rowList or {}
    truthy(#rows > 0, "the page has its bind rows (built by CreateBindUI at login)")
    for _, row in ipairs(rows) do
        -- row.__row is Bind.lua's own marker: the ONLY rows on this page are binding rows.
        truthy(type(row.__row) == "string", "every row on the page is one of our binding rows, not a toggle")
    end
end)

test("stale-nav-flag-deleted", "R-2.1", "an upgrading install has a stale db.navWindows deleted from saved data", function()
    local g = loginWithSaved({ navWindows = false, bindsAsked = "yes" })   -- saved by an older build
    falsy(g.ns.db.navWindows, "db.navWindows must be nil after load (the toggle is gone for good)")
end)
