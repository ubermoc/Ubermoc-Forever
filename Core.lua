-- Core.lua: shared state, saved settings, event dispatch, slash command. Loaded first (it is first in the .toc).
-- Every file gets (addonName, ns): ns is one table shared by all of this addon's files.
local addonName, ns = ...

ns.name = addonName
local DB_NAME = "UbermocForeverDB"   -- must match "## SavedVariables:" in the .toc

local defaults = {
    enabled = true,
    debug = false,
}

local function ApplyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

-- Event dispatch: ANY number of files can listen to the same event. (A single "handlers[event] = fn" would let the
-- second file replace the first one.)
local frame = CreateFrame("Frame")
local handlers = {}

function ns:RegisterEvent(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        frame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for _, fn in ipairs(list) do fn(...) end
end)

function ns:Print(...)
    print("|cff33ff99" .. addonName .. "|r:", ...)
end

function ns:Debug(...)
    if ns.db and ns.db.debug then print("|cffff9900" .. addonName .. " debug|r:", ...) end
end

-- ns.db exists from ADDON_LOADED on. Anything that needs it must run on or after PLAYER_LOGIN, or inside this handler.
ns:RegisterEvent("ADDON_LOADED", function(loadedAddon)
    if loadedAddon ~= addonName then return end
    _G[DB_NAME] = ApplyDefaults(_G[DB_NAME] or {}, defaults)
    ns.db = _G[DB_NAME]
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
    if ns.db and ns.db.enabled then ns:Print("loaded. Type /ubermoc for options.") end
end)

SLASH_UBERMOC1 = "/ubermoc"
SlashCmdList["UBERMOC"] = function(msg)
    if not ns.db then ns:Print("not ready yet."); return end
    local command = (msg or ""):match("^(%S*)"):lower()
    if command == "" or command == "config" then
        if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()) end
    elseif command == "toggle" then
        ns.db.enabled = not ns.db.enabled
        ns:Print(ns.db.enabled and "enabled" or "disabled")
    elseif command == "debug" then
        ns.db.debug = not ns.db.debug
        ns:Print("debug " .. (ns.db.debug and "on" or "off"))
    else
        ns:Print("commands: config, toggle, debug")
    end
end
