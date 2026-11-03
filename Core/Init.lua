local ADDON, ns = ...

ns.name = ADDON
ns.L = ns.L or {}

local frame = CreateFrame("Frame")
ns.frame = frame

local function getVersion()
    local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return getMeta(ADDON, "Version") or "?"
end

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
        print(ns.L.LOADED:format(getVersion(), ns.gameType))
        if isLoaded("UbermocUI") then
            print(ns.L.CONFLICT)
        end
    end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

SLASH_UBERMOCFOREVER1 = "/ubf"
SlashCmdList["UBERMOCFOREVER"] = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "debug" then
        ns.db.debug = not ns.db.debug
        print(ns.db.debug and ns.L.DEBUG_ON or ns.L.DEBUG_OFF)
    elseif cmd == "log" then
        ns.PrintLog()
    elseif cmd == "version" then
        print(("Ubermoc Forever %s (%s, toc %d)"):format(getVersion(), ns.gameType, ns.toc))
    else
        print(ns.L.HELP)
    end
end
