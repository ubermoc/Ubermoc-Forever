local ADDON, ns = ...

ns.name = ADDON
ns.L = ns.L or {}

local frame = CreateFrame("Frame")
ns.frame = frame

local function getVersion()
    local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return getMeta(ADDON, "Version") or "?"
end

-- Exposed for other modules (Options, etc.) to display the addon version.
ns.version = getVersion()

local function isLoaded(name)
    local check = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return check(name)
end

local function initDB()
    UbermocForeverDB = UbermocForeverDB or {}
    local db = UbermocForeverDB
    if db.debug == nil then db.debug = false end
    ns.db = db
end

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        initDB()
    elseif event == "PLAYER_LOGIN" then
        ns.Log("login, game type " .. ns.gameType .. ", toc " .. ns.toc)
        local active = ns.Pad.GetActive()
        ns.Log("active controller: " .. (active and active.name or "none"))
        -- Load per-class layout defaults when the player character is available.
        -- UnitClass("player") returns (class name, file token, ID) — verified in the
        -- forever branch (Blizzard_ClassMenu.lua line 7, Blizzard_BoostTutorial.lua line 26).
        local class = UnitClass("player")
        if class then
            ns.Layout.Load(class)
        end
        print(ns.L.LOADED:format(getVersion(), ns.gameType))
        -- Auto-enable layout bindings once combat lock-in is lifted.
        if ns.Context and ns.Context.OnPlayerLogin then
            ns.Context.OnPlayerLogin()
        end
        -- Start the context-driven binding hints (spellbook, NPC, bags, menu).
        if ns.BindingHint and ns.BindingHint.Start then
            local ok, err = pcall(ns.BindingHint.Start)
            if not ok then ns.Log("BindingHint.Start failed: " .. tostring(err)) end
        end
        -- Start context-aware bar transitions (Phase 06: utility bar first
        -- while a game frame is open, instant return to combat bars).
        if ns.Transitions and ns.Transitions.Start then
            local ok, err = pcall(ns.Transitions.Start)
            if not ok then ns.Log("Transitions.Start failed: " .. tostring(err)) end
        end
        if isLoaded("UbermocUI") then
            print(ns.L.CONFLICT)
        end
    end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

SLASH_UBERMOCFOREVER1 = "/ubf"
SlashCmdList["UBERMOCFOREVER"] = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "debug" then
        ns.db.debug = not ns.db.debug
        print(ns.db.debug and ns.L.DEBUG_ON or ns.L.DEBUG_OFF)
    elseif cmd == "pad" then
        ns.Pad.PrintReport()
    elseif cmd == "cursor" then
        ns.Cursor.Command(rest)
    elseif cmd == "labels" then
        ns.Labels.Command(rest)
    elseif cmd == "binds" then
        ns.Binds.Command(rest)
    elseif cmd == "legend" then
        print(ns.Legend.Status())
    elseif cmd == "options" then
        ns.Options.Toggle()
    elseif cmd == "test" then
        if rest:lower() == "stop" then
            ns.Report.Stop()
        else
            ns.Report.Run()
        end
    elseif cmd == "selftest" then
        ns.RunSelfTest()
    elseif cmd == "autotest" then
        ns.AutoTest.Command(rest)
    elseif cmd == "reload" then
        ReloadUI()
    elseif cmd == "layout" then
        ns.Layout.Command(rest)
    elseif cmd == "transitions" then
        if ns.Transitions and ns.Transitions.Command then
            ns.Transitions.Command(rest)
        else
            print("Transitions module not loaded.")
        end
    elseif cmd == "padmap" then
        ns.PrintPadMap()
    elseif cmd == "padtest" then
        ns.TogglePadTest()
    elseif cmd == "log" then
        ns.PrintLog()
    elseif cmd == "version" then
        print(("Ubermoc Forever %s (%s, toc %d)"):format(getVersion(), ns.gameType, ns.toc))
    elseif cmd == "context" then
        if ns.Context and ns.Context.PrintState then
            ns.Context.PrintState()
        else
            print("Context engine not loaded yet.")
        end
    else
        print(ns.L.HELP)
    end
end
